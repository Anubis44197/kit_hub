import fs from "node:fs";

const [debugUrl, targetUrl, screenshotPath] = process.argv.slice(2);
if (!debugUrl || !targetUrl || !screenshotPath) {
  throw new Error("Usage: node browser_interaction_probe.mjs <debug-url> <target-url> <screenshot-path>");
}

const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
let targets = [];
for (let attempt = 0; attempt < 40; attempt += 1) {
  try {
    targets = await fetch(`${debugUrl}/json/list`).then(response => response.json());
    if (targets.length) break;
  } catch {}
  await delay(250);
}
const target = targets.find(item => item.type === "page") || targets[0];
if (!target?.webSocketDebuggerUrl) throw new Error("Edge DevTools target was not available.");

const socket = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((resolve, reject) => {
  socket.addEventListener("open", resolve, { once: true });
  socket.addEventListener("error", reject, { once: true });
});
let nextId = 0;
const pending = new Map();
const consoleIssues = [];
socket.addEventListener("message", event => {
  const message = JSON.parse(event.data);
  if (message.id && pending.has(message.id)) {
    const { resolve, reject } = pending.get(message.id);
    pending.delete(message.id);
    if (message.error) reject(new Error(message.error.message));
    else resolve(message.result || {});
    return;
  }
  if (message.method === "Runtime.consoleAPICalled" && ["error", "warning"].includes(message.params?.type)) {
    consoleIssues.push(message.params.args.map(arg => arg.value ?? arg.description ?? "").join(" "));
  }
  if (message.method === "Runtime.exceptionThrown") {
    consoleIssues.push(message.params.exceptionDetails?.text || "Runtime exception");
  }
});
const call = (method, params = {}) => new Promise((resolve, reject) => {
  const id = ++nextId;
  pending.set(id, { resolve, reject });
  socket.send(JSON.stringify({ id, method, params }));
});
const evaluate = async expression => {
  const result = await call("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true });
  if (result.exceptionDetails) {
    throw new Error(result.exceptionDetails.exception?.description || result.exceptionDetails.text || "Runtime evaluation failed.");
  }
  return result.result?.value;
};
const key = async (keyName, code = keyName, modifiers = 0) => {
  const virtualKey = keyName === "Enter" ? 13 : keyName === "Escape" ? 27 : keyName === "End" ? 35 : 0;
  await call("Input.dispatchKeyEvent", { type: "rawKeyDown", key: keyName, code, modifiers, windowsVirtualKeyCode: virtualKey, nativeVirtualKeyCode: virtualKey });
  if (keyName === "Enter") {
    await call("Input.dispatchKeyEvent", { type: "char", key: keyName, code, text: "\r", unmodifiedText: "\r", windowsVirtualKeyCode: virtualKey, nativeVirtualKeyCode: virtualKey });
  }
  await call("Input.dispatchKeyEvent", { type: "keyUp", key: keyName, code, modifiers, windowsVirtualKeyCode: virtualKey, nativeVirtualKeyCode: virtualKey });
  await delay(120);
};

await call("Page.enable");
await call("Runtime.enable");
await call("Page.addScriptToEvaluateOnNewDocument", { source: `(() => {
  const listeners = new WeakMap();
  const original = EventTarget.prototype.addEventListener;
  EventTarget.prototype.addEventListener = function(type, handler, options) {
    if (!listeners.has(this)) listeners.set(this, new Set());
    listeners.get(this).add(type);
    return original.call(this, type, handler, options);
  };
  Object.defineProperty(window, '__kithubListenerTypes', { value: target => [...(listeners.get(target) || [])] });
})()` });
await call("Page.navigate", { url: targetUrl });
await delay(1800);

const identity = await evaluate(`({
  url: location.href,
  title: document.title,
  textLength: document.body.innerText.trim().length,
  overlay: Boolean(document.querySelector('[data-nextjs-dialog-overlay], vite-error-overlay, #webpack-dev-server-client-overlay'))
})`);

const accessibilityExpression = `(() => {
  const isVisible = element => {
    const style = getComputedStyle(element);
    const rect = element.getBoundingClientRect();
    return style.display !== 'none' && style.visibility !== 'hidden' && Number(style.opacity) !== 0 && rect.width > 0 && rect.height > 0;
  };
  const accessibleName = element => {
    const labelledBy = element.getAttribute('aria-labelledby');
    const labelledText = labelledBy
      ? labelledBy.split(/\\s+/).map(id => document.getElementById(id)?.textContent || '').join(' ').trim()
      : '';
    const explicitLabel = element.id ? document.querySelector('label[for="' + CSS.escape(element.id) + '"]')?.textContent?.trim() : '';
    const wrappedLabel = element.closest('label')?.textContent?.trim() || '';
    return (element.getAttribute('aria-label') || labelledText || explicitLabel || wrappedLabel || element.getAttribute('title') || element.textContent || element.value || '').trim();
  };
  const parseRgb = value => {
    const match = value.match(/rgba?\\(([^)]+)\\)/);
    if (!match) return null;
    const parts = match[1].split(',').map(part => Number.parseFloat(part.trim()));
    return { r: parts[0], g: parts[1], b: parts[2], a: parts.length > 3 ? parts[3] : 1 };
  };
  const relativeLuminance = color => {
    const channel = value => {
      const normalized = value / 255;
      return normalized <= 0.03928 ? normalized / 12.92 : ((normalized + 0.055) / 1.055) ** 2.4;
    };
    return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
  };
  const contrastRatio = (foreground, background) => {
    const lighter = Math.max(relativeLuminance(foreground), relativeLuminance(background));
    const darker = Math.min(relativeLuminance(foreground), relativeLuminance(background));
    return (lighter + 0.05) / (darker + 0.05);
  };
  const backgroundFor = element => {
    let current = element;
    while (current) {
      const color = parseRgb(getComputedStyle(current).backgroundColor);
      if (color && color.a >= 0.95) return color;
      current = current.parentElement;
    }
    return { r: 255, g: 255, b: 255, a: 1 };
  };
  const selectorFor = element => element.id ? '#' + element.id : element.tagName.toLowerCase() + (element.classList.length ? '.' + [...element.classList].slice(0, 2).join('.') : '');
  const controls = [...document.querySelectorAll('button, a[href], input, select, textarea, summary, [role="button"], [tabindex]:not([tabindex="-1"])')].filter(isVisible);
  const unnamedControls = controls.filter(element => !accessibleName(element)).map(selectorFor);
  const smallTargets = controls
    .map(element => ({ selector: selectorFor(element), rect: element.getBoundingClientRect() }))
    .filter(item => item.rect.width < 24 || item.rect.height < 24)
    .map(item => ({ selector: item.selector, width: Math.round(item.rect.width), height: Math.round(item.rect.height) }));
  const ids = [...document.querySelectorAll('[id]')].map(element => element.id);
  const duplicateIds = [...new Set(ids.filter((id, index) => ids.indexOf(id) !== index))];
  const headings = [...document.querySelectorAll('h1,h2,h3,h4,h5,h6')]
    .filter(isVisible)
    .map(element => ({ level: Number(element.tagName.slice(1)), text: element.textContent.trim().slice(0, 80) }));
  const headingSkips = [];
  for (let index = 1; index < headings.length; index += 1) {
    if (headings[index].level > headings[index - 1].level + 1) {
      headingSkips.push({ from: headings[index - 1], to: headings[index] });
    }
  }
  const contrastFailures = [...document.querySelectorAll('body *')]
    .filter(element => isVisible(element) && [...element.childNodes].some(node => node.nodeType === Node.TEXT_NODE && node.textContent.trim()))
    .map(element => {
      const style = getComputedStyle(element);
      const foreground = parseRgb(style.color);
      if (!foreground || foreground.a < 0.95) return null;
      const ratio = contrastRatio(foreground, backgroundFor(element));
      const fontSize = Number.parseFloat(style.fontSize);
      const fontWeight = Number.parseInt(style.fontWeight, 10) || 400;
      const largeText = fontSize >= 24 || (fontSize >= 18.66 && fontWeight >= 700);
      return ratio + 0.01 < (largeText ? 3 : 4.5)
        ? { selector: selectorFor(element), text: element.textContent.trim().slice(0, 80), ratio: Number(ratio.toFixed(2)), required: largeText ? 3 : 4.5 }
        : null;
    })
    .filter(Boolean)
    .slice(0, 50);
  return {
    lang: document.documentElement.lang,
    mainCount: document.querySelectorAll('main').length,
    h1Count: headings.filter(heading => heading.level === 1).length,
    liveRegionCount: document.querySelectorAll('[role="status"][aria-live]').length,
    skipLinkPresent: Boolean(document.querySelector('a[href="#workspace"]')),
    duplicateIds,
    unnamedControls,
    headingSkips,
    smallTargets,
    contrastFailures,
    horizontalOverflow: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
    reducedMotionRulePresent: [...document.styleSheets].some(sheet => {
      try { return [...sheet.cssRules].some(rule => rule.media?.mediaText?.includes('prefers-reduced-motion')); } catch { return false; }
    }),
    viewport: { width: innerWidth, height: innerHeight }
  };
})()`;
const desktopAccessibility = await evaluate(accessibilityExpression);
const desktopScreenshot = await call("Page.captureScreenshot", { format: "png", captureBeyondViewport: false });
fs.writeFileSync(screenshotPath, Buffer.from(desktopScreenshot.data, "base64"));

await evaluate(`(() => {
  document.activeElement?.blur();
  document.body.setAttribute('tabindex', '-1');
  document.body.focus();
  document.body.removeAttribute('tabindex');
})()`);
await key("Tab");
const skipLinkFocused = await evaluate(`document.activeElement?.id === 'skipToWorkspace'`);
await key("Enter");
const skipTargetFocused = await evaluate(`document.activeElement?.id === 'workspace' && location.hash === '#workspace'`);

await evaluate(`document.getElementById('focusModeBtn').focus()`);
const focusButtonBefore = await evaluate(`document.activeElement?.id`);
await key("Enter");
const focusModeEntered = await evaluate(`({ active: document.body.classList.contains('focus-writing'), focused: document.activeElement?.id || (document.activeElement?.classList.contains('ProseMirror') ? 'structuredEditor' : ''), pressed: document.getElementById('focusModeBtn').getAttribute('aria-pressed') })`);
await key("Escape");
const focusModeExited = await evaluate(`({ active: document.body.classList.contains('focus-writing'), focused: document.activeElement?.id, pressed: document.getElementById('focusModeBtn').getAttribute('aria-pressed') })`);

await evaluate(`document.getElementById('zoomSelect').focus()`);
const zoomBefore = await evaluate(`({ value: document.getElementById('zoomSelect').value, css: getComputedStyle(document.documentElement).getPropertyValue('--page-zoom').trim() })`);
await key("End");
const zoomAfter = await evaluate(`({ value: document.getElementById('zoomSelect').value, css: getComputedStyle(document.documentElement).getPropertyValue('--page-zoom').trim(), focused: document.activeElement?.id })`);

const dirtyState = await evaluate(`(() => {
  const editor = document.getElementById('manuscriptText');
  editor.value += '\\nKitHub güvenli editör';
  editor.dispatchEvent(new Event('input', { bubbles: true }));
  return {
    saveState: document.getElementById('saveState').textContent.trim(),
    recoveryStored: Object.keys(localStorage).some(key => key.startsWith('kithub-editor-recovery:')),
    spellcheck: editor.spellcheck,
    richSpellcheck: document.querySelector('.ProseMirror')?.getAttribute('spellcheck') === 'true',
    mode: structuredEditorMode,
    sourceHidden: editor.hidden,
    schemaVersion: window.KitHubStructuredEditor?.schemaVersion
  };
})()`);
await key("f", "KeyF", 2);
const findShortcut = await evaluate(`(() => {
  const input = document.getElementById('findInput');
  input.value = 'KitHub';
  input.dispatchEvent(new Event('input', { bubbles: true }));
  return {
    open: document.getElementById('findPanel').hidden === false,
    focused: document.activeElement?.id,
    count: document.getElementById('findCount').textContent.trim()
  };
})()`);
await key("Enter");
const findSelection = await evaluate(`(() => {
  const editor = document.getElementById('manuscriptText');
  return {
    selected: structuredEditorMode === 'rich' && structuredEditorApi
      ? structuredEditorApi.getSelectedText()
      : editor.value.slice(editor.selectionStart, editor.selectionEnd),
    focused: document.activeElement?.id || (document.activeElement?.classList.contains('ProseMirror') ? 'structuredEditor' : '')
  };
})()`);
await key("Escape");
await key("h", "KeyH", 2);
const replaceShortcut = await evaluate(`({
  open: document.getElementById('findPanel').hidden === false,
  replaceVisible: document.getElementById('findReplaceRow').hidden === false,
  focused: document.activeElement?.id
})`);
await key("Escape");
await key("s", "KeyS", 2);
const saveShortcut = await evaluate(`({
  state: document.getElementById('saveState').textContent.trim(),
  recoveryStored: Object.keys(localStorage).some(key => key.startsWith('kithub-editor-recovery:'))
})`);
const editorialRules = await evaluate(`(() => {
  setEditorText(document.getElementById('manuscriptText').value + '\\n\\nçok çok  ,yanlış.... "Söz"');
  editorContentChanged();
  renderEditorialPanel();
  return {
    findingCount: editorialFindings.length,
    settingsPresent: Boolean(document.getElementById('editorialQuoteStyle') && document.getElementById('editorialStyleNotes')),
    mutatesWithoutApproval: document.getElementById('manuscriptText').value.includes('çok çok  ,yanlış.... "Söz"') === false
  };
})()`);
const publishingCompatibility = await evaluate(`(() => {
  const font = document.getElementById('typeFont');
  const pageSize = document.getElementById('pageSize');
  const design = document.getElementById('pageDesign');
  const before = { font: font.value, pageSize: pageSize.value, design: design.value };
  design.value = 'artDeco';
  design.dispatchEvent(new Event('change', { bubbles: true }));
  const optInApplied = document.getElementById('bookPage').dataset.pageDesign === 'artDeco';
  const metricsPreserved = font.value === before.font && pageSize.value === before.pageSize;
  design.value = 'classicFrame';
  design.dispatchEvent(new Event('change', { bubbles: true }));
  return {
    before,
    optInApplied,
    metricsPreserved,
    classicRestored: document.getElementById('bookPage').dataset.pageDesign === 'classicFrame',
    outputProfiles: [...document.getElementById('settingsOutputProfile').options].map(option => option.value),
    defaultOutputProfile: document.getElementById('settingsOutputProfile').value
  };
})()`);
const publicationUx = await evaluate(`(() => {
  const workflow = [...document.querySelectorAll('[data-workflow-step]')];
  document.querySelector('[data-workflow-step="publish"]')?.click();
  const publishStepActive = document.querySelector('[data-workflow-step="publish"]')?.hasAttribute('aria-current') === true;
  const prompt = document.getElementById('aiPromptInput');
  const promptMinHeight = Number.parseFloat(getComputedStyle(prompt).minHeight || '0');
  document.getElementById('openMatterManagerBtn')?.click();
  const matterDialog = document.getElementById('matterManagerDialog');
  const matterOpen = matterDialog?.open === true;
  const matterColumns = matterDialog?.querySelectorAll('.matter-column').length || 0;
  matterDialog?.close();
  document.getElementById('openCoverStudioBtn')?.click();
  const coverDialog = document.getElementById('coverStudioDialog');
  const coverOpen = coverDialog?.open === true;
  const pageCount = document.getElementById('coverPageCountInput');
  pageCount.value = '320';
  pageCount.dispatchEvent(new Event('input', { bubbles: true }));
  const coverSizeCalculated = /mm/.test(document.getElementById('coverSizeSummary')?.textContent || '');
  coverDialog?.close();
  document.querySelector('[data-workflow-step="write"]')?.click();
  return {
    workflowCount: workflow.length,
    workflowLabels: workflow.map(item => item.textContent.trim()),
    publishStepActive,
    promptMinHeight,
    promptMaxLength: prompt?.maxLength || 0,
    promptContextCount: document.querySelectorAll('[data-ai-context]').length,
    matterOpen,
    matterColumns,
    coverOpen,
    coverSizeCalculated,
    preflightAvailable: Boolean(document.getElementById('runPreflightBtn')),
    informationalControls: document.querySelectorAll('button[data-control-state="info"]').length,
    blockedControls: document.querySelectorAll('button[data-control-state="blocked"]').length
  };
})()`);
const auditMatterScreenshotPath = screenshotPath.replace(/(\.[^.]+)$/, "-matter$1");
await evaluate(`document.getElementById('openMatterManagerBtn')?.click()`);
await delay(120);
const auditMatterScreenshot = await call("Page.captureScreenshot", { format: "png", captureBeyondViewport: false });
fs.writeFileSync(auditMatterScreenshotPath, Buffer.from(auditMatterScreenshot.data, "base64"));
await evaluate(`document.getElementById('matterManagerDialog')?.close()`);
const auditCoverScreenshotPath = screenshotPath.replace(/(\.[^.]+)$/, "-cover$1");
await evaluate(`document.getElementById('openCoverStudioBtn')?.click()`);
await delay(120);
const auditCoverScreenshot = await call("Page.captureScreenshot", { format: "png", captureBeyondViewport: false });
fs.writeFileSync(auditCoverScreenshotPath, Buffer.from(auditCoverScreenshot.data, "base64"));
await evaluate(`document.getElementById('coverStudioDialog')?.close()`);
const controlContracts = await evaluate(`(() => {
  const visible = element => {
    const style = getComputedStyle(element);
    const rect = element.getBoundingClientRect();
    return style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0;
  };
  const listenerTypes = target => window.__kithubListenerTypes?.(target) || [];
  const handled = button => {
    if (button.matches('[data-control-state="info"], [data-control-state="blocked"]')) return true;
    if (button.closest('form[method="dialog"]') && (button.type || 'submit') === 'submit') return true;
    for (let target = button; target; target = target.parentNode) {
      const types = listenerTypes(target);
      if (types.includes('click')) return true;
      if ((button.type || 'submit') === 'submit' && types.includes('submit')) return true;
    }
    return listenerTypes(document).includes('click') || listenerTypes(window).includes('click');
  };
  const buttons = [...document.querySelectorAll('button')].filter(visible);
  return {
    visibleButtons: buttons.length,
    informational: buttons.filter(button => button.dataset.controlState === 'info').length,
    blocked: buttons.filter(button => button.dataset.controlState === 'blocked').length,
    unhandled: buttons.filter(button => !button.disabled && !handled(button)).map(button => ({ id: button.id, text: button.textContent.trim().slice(0, 80) }))
  };
})()`);
const paginationFlow = await evaluate(`(() => {
  const original = document.getElementById('manuscriptText').value;
  const sentence = 'KitHub ölçümlü sayfa akışı gerçek satır yüksekliğini ve kullanılabilir sayfa alanını izler.';
  const longParagraph = Array.from({ length: 520 }, (_, index) => sentence + ' ' + (index + 1)).join(' ');
  const tail = Array.from({ length: 70 }, (_, index) => 'Sonraki sahne paragrafı ' + (index + 1) + '.').join(' ');
  previewShowAll = false;
  setEditorText('# Ölçümlü Sayfalama\\n\\n' + longParagraph + '\\n\\n<!-- page-break -->\\n\\n## Yeni Sahne\\n\\n' + tail);
  renderPreview();
  const stage = document.querySelector('.page-stage');
  const initialPages = [...stage.querySelectorAll(':scope > .page')];
  const pageBodies = initialPages.map(page => page.id === 'bookPage' ? page.querySelector('#pageBody') : page.children[1]);
  const lineCount = element => {
    const range = document.createRange();
    range.selectNodeContents(element);
    return new Set([...range.getClientRects()].filter(rect => rect.height > 1).map(rect => Math.round(rect.top * 2) / 2)).size;
  };
  const fragmentLineCounts = pageBodies.flatMap(body => [...(body?.querySelectorAll('p.continued') || [])].map(lineCount));
  const totalPages = Number(stage.dataset.pageCount || 0);
  const showAllButton = stage.querySelector('[data-preview-show-all]');
  const limitedPages = initialPages.length;
  if (showAllButton) showAllButton.click();
  const allPages = [...stage.querySelectorAll(':scope > .page')];
  const result = {
    mode: stage.dataset.paginationMode,
    totalPages,
    limitedPages,
    allRenderedPages: allPages.length,
    paragraphSplits: Number(stage.dataset.paragraphSplits || 0),
    hasShowAll: Boolean(showAllButton),
    repeatedChapterTitles: allPages.filter(page => page.querySelector('h2')).length,
    runningHeaders: allPages.filter(page => page.querySelector('.running-head')).length,
    overflowPages: allPages.filter(page => page.scrollHeight > page.clientHeight + 1).length,
    strandedHeadings: allPages.filter(page => {
      const body = page.id === 'bookPage' ? page.querySelector('#pageBody') : page.children[1];
      return body?.lastElementChild?.matches('.preview-subhead');
    }).length,
    minimumContinuationLines: fragmentLineCounts.length ? Math.min(...fragmentLineCounts) : 0
  };
  previewShowAll = false;
  setEditorText(original);
  renderPreview();
  return result;
})()`);
const chapterSwitchGuard = await evaluate(`(async () => {
  const editor = document.getElementById('manuscriptText');
  const unsavedText = editor.value;
  chapters = [
    { id: 'Bölüm 1', title: 'Güvenli Taslak', text: unsavedText },
    { id: 'Bölüm 2', title: 'Sonraki Bölüm', text: 'İkinci bölüm' }
  ];
  currentChapterIndex = 0;
  lastSavedContent = 'önceki kayıt';
  editorDirty = true;
  const switched = await selectChapter(1);
  return {
    switched,
    currentChapterIndex,
    textPreserved: editor.value === unsavedText,
    state: document.getElementById('saveState').textContent.trim()
  };
})()`);
const chapterManagerDialog = await evaluate(`(() => {
  bridgeOnline = true;
  bridgeProjectActive = true;
  currentProjectPathHint = 'C:/kithub-test-project';
  chapters = [
    { id: 'Bölüm 1', title: 'Birinci', filename: 'ep001.md', text: '# Birinci' },
    { id: 'Bölüm 2', title: 'İkinci', filename: 'ep002.md', text: '# İkinci' }
  ];
  currentChapterIndex = 0;
  editorDirty = false;
  renderChapters();
  document.getElementById('addChapterBtn').click();
  return {
    open: document.getElementById('chapterDialog').open,
    title: document.getElementById('chapterDialogTitle').textContent.trim(),
    addEnabled: document.getElementById('addChapterBtn').disabled === false,
    draggableRows: document.querySelectorAll('#chapterList li[draggable="true"]').length
  };
})()`);
await delay(80);
chapterManagerDialog.focused = await evaluate(`document.activeElement?.id`);
await evaluate(`closeChapterDialog()`);

await call("Emulation.setDeviceMetricsOverride", { width: 390, height: 844, deviceScaleFactor: 1, mobile: true });
await evaluate(`(() => {
  document.documentElement.style.setProperty('--page-zoom', '1');
  document.getElementById('zoomSelect').value = '1';
  history.replaceState(null, '', location.pathname + location.search);
  window.scrollTo(0, 0);
})()`);
await delay(350);
const mobileAccessibility = await evaluate(accessibilityExpression);
const mobileEditorLayout = await evaluate(`(() => {
  const toolbar = document.querySelector('.toolbar');
  const settings = document.querySelector('.top-actions');
  const settingsSummary = document.querySelector('#settingsMenu summary');
  const visible = element => {
    const style = getComputedStyle(element);
    const rect = element.getBoundingClientRect();
    return style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0;
  };
  return {
    toolbarOverflow: toolbar.scrollWidth > toolbar.clientWidth + 1,
    settingsVisible: visible(settings) && visible(settingsSummary)
  };
})()`);
const mobileIdentity = await evaluate(`({
  url: location.href,
  title: document.title,
  textLength: document.body.innerText.trim().length,
  overlay: Boolean(document.querySelector('[data-nextjs-dialog-overlay], vite-error-overlay, #webpack-dev-server-client-overlay'))
})`);
const mobileScreenshotPath = screenshotPath.replace(/(\.[^.]+)$/, "-mobile$1");
const mobileScreenshot = await call("Page.captureScreenshot", { format: "png", captureBeyondViewport: false });
fs.writeFileSync(mobileScreenshotPath, Buffer.from(mobileScreenshot.data, "base64"));
socket.close();

const result = {
  identity,
  accessibility: {
    desktop: desktopAccessibility,
    mobile: mobileAccessibility
  },
  mobileIdentity,
  consoleIssues,
  focus: {
    skipLinkFocused,
    skipTargetFocused,
    buttonFocusedBeforeActivation: focusButtonBefore === "focusModeBtn",
    entered: focusModeEntered.active === true && ["manuscriptText", "structuredEditor"].includes(focusModeEntered.focused) && focusModeEntered.pressed === "true",
    escaped: focusModeExited.active === false && focusModeExited.focused === "focusModeBtn" && focusModeExited.pressed === "false",
    enteredState: focusModeEntered,
    escapedState: focusModeExited
  },
  zoom: {
    changedByKeyboard: zoomAfter.value !== zoomBefore.value && zoomAfter.css === zoomAfter.value && zoomAfter.focused === "zoomSelect",
    before: zoomBefore,
    after: zoomAfter
  },
  editorCore: {
    dirtyState,
    findShortcut,
    findSelection,
    replaceShortcut,
    saveShortcut,
    editorialRules,
    publishingCompatibility,
    publicationUx,
    controlContracts,
    paginationFlow,
    chapterSwitchGuard,
    chapterManagerDialog,
    mobileLayout: mobileEditorLayout
  },
  screenshots: {
    desktop: screenshotPath,
    matter: auditMatterScreenshotPath,
    cover: auditCoverScreenshotPath,
    mobile: mobileScreenshotPath
  }
};
process.stdout.write(JSON.stringify(result));
