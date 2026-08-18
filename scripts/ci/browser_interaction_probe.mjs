import fs from "node:fs";

const [debugUrl, targetUrl, screenshotPath, visualProjectRoot] = process.argv.slice(2);
if (!debugUrl || !targetUrl || !screenshotPath || !visualProjectRoot) {
  throw new Error("Usage: node browser_interaction_probe.mjs <debug-url> <target-url> <screenshot-path> <project-root>");
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
  versionBadge: document.getElementById('appVersion')?.textContent || '',
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
  const contrastFailures = [...document.querySelectorAll('p, button, a, span, label, h1, h2, h3, h4, h5, h6, input, select, textarea')]
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

await evaluate(`document.getElementById('focusModeBtn')?.focus()`);
const focusButtonBefore = await evaluate(`document.activeElement?.id`);
await key("Enter");
const focusModeEntered = await evaluate(`({ active: document.body.classList.contains('focus-writing'), focused: document.activeElement?.id || (document.activeElement?.classList.contains('ProseMirror') ? 'structuredEditor' : ''), pressed: document.getElementById('focusModeBtn')?.getAttribute('aria-pressed') })`);
await key("Escape");
const focusModeExited = await evaluate(`({ active: document.body.classList.contains('focus-writing'), focused: document.activeElement?.id, pressed: document.getElementById('focusModeBtn')?.getAttribute('aria-pressed') })`);

await evaluate(`document.getElementById('zoomSelect')?.focus()`);
const zoomBefore = await evaluate(`({ value: document.getElementById('zoomSelect')?.value, css: getComputedStyle(document.documentElement).getPropertyValue('--page-zoom').trim() })`);
await key("End");
const zoomAfter = await evaluate(`({ value: document.getElementById('zoomSelect')?.value, css: getComputedStyle(document.documentElement).getPropertyValue('--page-zoom').trim(), focused: document.activeElement?.id })`);

const dirtyState = await evaluate(`(() => {
  const editor = document.getElementById('manuscriptText');
  if (editor) {
    editor.value += '\\nKitHub güvenli editör';
    editor.dispatchEvent(new Event('input', { bubbles: true }));
  }
  return {
    saveState: document.getElementById('saveState')?.textContent?.trim() || '',
    recoveryStored: Object.keys(localStorage).some(key => key.startsWith('kithub-editor-recovery:')),
    spellcheck: editor?.spellcheck || false,
    richSpellcheck: document.querySelector('.ProseMirror')?.getAttribute('spellcheck') === 'true',
    mode: typeof structuredEditorMode !== 'undefined' ? structuredEditorMode : null,
    sourceHidden: editor?.hidden || false,
    schemaVersion: window.KitHubStructuredEditor?.schemaVersion
  };
})()`);
await key("f", "KeyF", 2);
const findShortcut = await evaluate(`(() => {
  const input = document.getElementById('findInput');
  if (input) {
    input.value = 'KitHub';
    input.dispatchEvent(new Event('input', { bubbles: true }));
  }
  return {
    open: document.getElementById('findPanel')?.hidden === false,
    focused: document.activeElement?.id,
    count: document.getElementById('findCount')?.textContent?.trim() || ''
  };
})()`);
await key("Enter");
const findSelection = await evaluate(`(() => {
  const editor = document.getElementById('manuscriptText');
  const mode = typeof structuredEditorMode !== 'undefined' ? structuredEditorMode : null;
  const api = typeof structuredEditorApi !== 'undefined' ? structuredEditorApi : null;
  return {
    selected: mode === 'rich' && api
      ? api.getSelectedText()
      : (editor?.value ? editor.value.slice(editor.selectionStart, editor.selectionEnd) : ''),
    focused: document.activeElement?.id || (document.activeElement?.classList.contains('ProseMirror') ? 'structuredEditor' : '')
  };
})()`);
await key("Escape");
await key("h", "KeyH", 2);
const replaceShortcut = await evaluate(`({
  open: document.getElementById('findPanel')?.hidden === false,
  replaceVisible: document.getElementById('findReplaceRow')?.hidden === false,
  focused: document.activeElement?.id
})`);
await key("Escape");
await key("s", "KeyS", 2);
const saveShortcut = await evaluate(`({
  state: document.getElementById('saveState')?.textContent?.trim() || '',
  recoveryStored: Object.keys(localStorage).some(key => key.startsWith('kithub-editor-recovery:'))
})`);
const editorialRules = await evaluate(`(() => {
  const manuscript = document.getElementById('manuscriptText');
  const currentVal = manuscript?.value || '';
  if (typeof window.setEditorText === 'function') window.setEditorText(currentVal + '\\n\\nçok çok  ,yanlış.... "Söz"');
  else if (typeof setEditorText === 'function') setEditorText(currentVal + '\\n\\nçok çok  ,yanlış.... "Söz"');
  if (typeof window.editorContentChanged === 'function') window.editorContentChanged();
  else if (typeof editorContentChanged === 'function') editorContentChanged();
  if (typeof window.renderEditorialPanel === 'function') window.renderEditorialPanel();
  else if (typeof renderEditorialPanel === 'function') renderEditorialPanel();
  const findings = typeof editorialFindings !== 'undefined' ? editorialFindings : (typeof window.editorialFindings !== 'undefined' ? window.editorialFindings : []);
  return {
    findingCount: Array.isArray(findings) ? findings.length : 0,
    settingsPresent: Boolean(document.getElementById('editorialQuoteStyle') && document.getElementById('editorialStyleNotes')),
    mutatesWithoutApproval: Boolean(manuscript?.value && manuscript.value.includes('çok çok  ,yanlış.... "Söz"') === false)
  };
})()`);
const findSearchOptions = await evaluate(`(() => {
  const editor = document.getElementById('manuscriptText');
  const val = editor?.value || '';
  const setEd = typeof window.setEditorText === 'function' ? window.setEditorText : (typeof setEditorText === 'function' ? setEditorText : null);
  if (setEd) setEd('KitHub KitHub kit hub');
  const getOcc = typeof window.findOccurrences === 'function' ? window.findOccurrences : (typeof findOccurrences === 'function' ? findOccurrences : null);
  const replLit = typeof window.replaceAllLiteral === 'function' ? window.replaceAllLiteral : (typeof replaceAllLiteral === 'function' ? replaceAllLiteral : null);
  const textVal = editor?.value || 'KitHub KitHub kit hub';
  const counts = {
    defaultCount: getOcc ? getOcc(textVal, 'kitHub', { caseSensitive: false, wholeWord: false, regex: false }).length : 0,
    caseCount: getOcc ? getOcc(textVal, 'KitHub', { caseSensitive: true, wholeWord: false, regex: false }).length : 0,
    wholeCount: getOcc ? getOcc(textVal, 'kit', { caseSensitive: false, wholeWord: true, regex: false }).length : 0,
    regexCount: getOcc ? getOcc(textVal, 'Kit.{1}ub', { caseSensitive: false, wholeWord: false, regex: true }).length : 0
  };
  const replaced = replLit ? replLit(textVal, 'kit', 'metin', { caseSensitive: true, wholeWord: true, regex: false }) : { count: 0, text: '' };
  return {
    ...counts,
    wholeReplaceCount: replaced.count,
    wholeReplaceApplied: replaced.text === 'KitHub KitHub metin hub'
  };
})()`);
const quickJump = await evaluate(`(async () => {
  const originalChapters = chapters;
  const originalIndex = currentChapterIndex;
  chapters = [
    { id: 'Bölüm 1', title: 'Defnenin Girişi', text: 'İlk' },
    { id: 'Bölüm 2', title: 'Ormandaki Sır', text: 'İkinci' },
    { id: 'Bölüm 3', title: 'Son Karar', text: 'Üçüncü' }
  ];
  editorDirty = false;
  openQuickJump();
  const opened = quickJumpDialog.open;
  quickJumpInput.value = 'ormandaki';
  renderQuickJumpResults('ormandaki');
  const filteredCount = quickJumpResults.querySelectorAll('[data-quick-jump-index]').length;
  await activateQuickJumpItem();
  const jumpedIndex = currentChapterIndex;
  const closedAfterJump = !quickJumpDialog.open;
  chapters = originalChapters;
  currentChapterIndex = originalIndex;
  editorDirty = false;
  return { opened, filteredCount, jumpedIndex, closedAfterJump };
})()`);
const spellcheck = await evaluate(`(() => {
  const editor = document.getElementById('manuscriptText');
  const originalEnabled = localStorage.getItem('kithub-spellcheck-enabled');
  const originalDictionary = localStorage.getItem('kithub-spell-ignore:studio');
  const text = 'herkez birsey yanlız ve ya şuan';
  manuscriptText.value = text;
  editorContentChanged();
  const enabledFindings = runTurkishEditorialChecks(text).filter(finding => finding.rule === 'spell');
  localStorage.setItem('kithub-spellcheck-enabled', 'off');
  const disabledFindings = runTurkishEditorialChecks(text).filter(finding => finding.rule === 'spell');
  localStorage.setItem('kithub-spellcheck-enabled', 'on');
  addToSpellDictionary('herkez');
  const ignoredFindings = runTurkishEditorialChecks(text).filter(finding => finding.rule === 'spell');
  setEditorMode('source');
  manuscriptText.value = text;
  editorContentChanged();
  renderEditorialPanel();
  editor.selectionStart = 0;
  jumpToNextFinding();
  const jumped = editor.selectionStart > 0;
  if (originalEnabled === null) localStorage.removeItem('kithub-spellcheck-enabled');
  else localStorage.setItem('kithub-spellcheck-enabled', originalEnabled);
  if (originalDictionary === null) localStorage.removeItem('kithub-spell-ignore:studio');
  else localStorage.setItem('kithub-spell-ignore:studio', originalDictionary);
  const dictWords = loadSpellDictionary();
  return {
    enabledFindings: enabledFindings.length,
    enabledLabels: enabledFindings.map(finding => finding.original),
    disabledFindings: disabledFindings.length,
    ignoredFindings: ignoredFindings.length,
    dictionaryHasWord: dictWords.includes('herkez'),
    jumped,
    editorialRender: document.getElementById('editorialSpellcheckToggle') !== null
  };
})()`);
const richRoundTrip = await evaluate(`(() => {
  const editor = document.getElementById('manuscriptText');
  const originalMode = typeof structuredEditorMode !== 'undefined' ? structuredEditorMode : (typeof window.structuredEditorMode !== 'undefined' ? window.structuredEditorMode : 'source');
  const setMode = typeof setEditorMode === 'function' ? setEditorMode : (typeof window.setEditorMode === 'function' ? window.setEditorMode : null);
  const getApi = () => typeof structuredEditorApi !== 'undefined' ? structuredEditorApi : (typeof window.structuredEditorApi !== 'undefined' ? window.structuredEditorApi : null);
  if (setMode) setMode('rich');
  const api = getApi();
  const edChanged = typeof editorContentChanged === 'function' ? editorContentChanged : (typeof window.editorContentChanged === 'function' ? window.editorContentChanged : null);
  const renPrev = typeof renderPreview === 'function' ? renderPreview : (typeof window.renderPreview === 'function' ? window.renderPreview : null);
  const setEditorTextValue = (text) => { if (editor) { editor.value = text; editor.dispatchEvent(new Event('input', { bubbles: true })); } if (edChanged) edChanged(); if (renPrev) renPrev(); };
  setEditorTextValue('Ilk paragraf metni');
  const synced = api ? api.getMarkdown() === 'Ilk paragraf metni' : false;
  const boldSelected = api ? api.selectText('paragraf', 0) : false;
  document.querySelector('[data-format="bold"]')?.click();
  const boldMarkdown = api ? api.getMarkdown() : '';
  const boldActive = api ? api.isActive('strong') : false;
  const italicSelected = api ? api.selectText('paragraf', 0) : false;
  document.querySelector('[data-format="italic"]')?.click();
  const italicMarkdown = api ? api.getMarkdown() : '';
  if (setMode) setMode('source');
  const sourceText = editor?.value || '';
  const sourceHasBold = (editor?.value || '').includes('**');
  if (setMode) setMode('rich');
  const roundtripPreserved = api ? api.getMarkdown() === sourceText : false;
  if (setMode) setMode(originalMode);
  return {
    synced,
    boldSelected,
    italicSelected,
    boldMarkdown,
    boldActive,
    italicMarkdown,
    sourceHasBold,
    roundtripPreserved
  };
})()`);
const structuredNodes = await evaluate(`(() => {
  const editor = document.getElementById('manuscriptText');
  const originalMode = typeof structuredEditorMode !== 'undefined' ? structuredEditorMode : (typeof window.structuredEditorMode !== 'undefined' ? window.structuredEditorMode : 'source');
  const setMode = typeof setEditorMode === 'function' ? setEditorMode : (typeof window.setEditorMode === 'function' ? window.setEditorMode : null);
  const getApi = () => typeof structuredEditorApi !== 'undefined' ? structuredEditorApi : (typeof window.structuredEditorApi !== 'undefined' ? window.structuredEditorApi : null);
  const setEd = typeof window.setEditorText === 'function' ? window.setEditorText : (typeof setEditorText === 'function' ? setEditorText : null);
  if (setMode) setMode('rich');
  const api = getApi();
  const countType = (doc, type) => {
    if (!doc) return 0;
    let c = 0;
    const walk = n => { if (n && n.type === type) c++; (n && n.content || []).forEach(walk); };
    walk(doc);
    return c;
  };
  const tableInput = 'Tanim\\n\\n| A | B |\\n|---|---|\\n| 1 | 2 |';
  if (setEd) setEd(tableInput);
  const tableDoc = api ? api.getJSON() : null;
  const tableNodes = countType(tableDoc, 'table');
  const tableCells = countType(tableDoc, 'table_cell');
  const tableHeaders = countType(tableDoc, 'table_header');
  const tableRoundtrip = api ? api.getMarkdown() : '';
  const tablePreserved = tableRoundtrip.includes('| A | B |') && tableRoundtrip.includes('| 1 | 2 |');

  const footnoteInput = 'metin[^1] cikisi\\n\\n[^1]: dipnot tanimi';
  if (setEd) setEd(footnoteInput);
  const footnoteDoc = api ? api.getJSON() : null;
  const footnoteRefs = countType(footnoteDoc, 'footnote_ref');
  const footnoteDefs = countType(footnoteDoc, 'footnote_def');
  const footnoteRoundtrip = api ? api.getMarkdown() : '';
  const footnotePreserved = footnoteRoundtrip.includes('[^1]') && footnoteRoundtrip.includes('[^1]: dipnot tanimi');

  const imageInput = '![kapak](https://x/y.png "Kapak")';
  if (setEd) setEd(imageInput);
  const imageDoc = api ? api.getJSON() : null;
  const imageNodes = countType(imageDoc, 'image');
  const imageRoundtrip = api ? api.getMarkdown() : '';
  const imagePreserved = imageRoundtrip.includes('![kapak](https://x/y.png "Kapak")');

  const insertTable = api ? api.run('table') : false;
  const insertedTables = countType(api ? api.getJSON() : null, 'table');
  if (api) api.run('footnote');
  const insertedRefs = countType(api ? api.getJSON() : null, 'footnote_ref');

  if (setMode) setMode(originalMode);
  return {
    tableNodes,
    tableCells,
    tableHeaders,
    tablePreserved,
    footnoteRefs,
    footnoteDefs,
    footnotePreserved,
    imageNodes,
    imagePreserved,
    insertTable,
    insertedTables,
    insertedRefs
  };
})()`);
const lineDiff = await evaluate(`(() => {
  const snapshot = 'satır1\\nsatır2\\nsatır3\\nsatır4';
  const current = 'satır1\\nsatır2 DEĞİŞTİ\\nsatır3\\nsatır4\\nsatır5 YENİ';
  const diffFn = typeof computeLineDiff === 'function' ? computeLineDiff : (typeof window.computeLineDiff === 'function' ? window.computeLineDiff : null);
  const rows = diffFn ? diffFn(snapshot, current) : [];
  const added = rows.filter(row => row.type === 'added');
  const removed = rows.filter(row => row.type === 'removed');
  const context = rows.filter(row => row.type === 'context');
  return {
    addedCount: added.length,
    removedCount: removed.length,
    contextCount: context.length,
    addedText: added.map(row => row.text),
    removedText: removed.map(row => row.text),
    lineNumbers: rows.some(row => row.type === 'added' && row.bIndex) && rows.some(row => row.type === 'removed' && row.aIndex)
  };
})()`);
const versionDiffUi = await evaluate(`(() => {
  const originalData = typeof versionDiffData !== 'undefined' ? versionDiffData : null;
  const originalSelected = typeof versionDiffSelected !== 'undefined' ? versionDiffSelected : '';
  const renderFiles = typeof renderVersionDiffFiles === 'function' ? renderVersionDiffFiles : null;
  const showDiff = typeof showVersionFileDiff === 'function' ? showVersionFileDiff : null;
  const closeDiff = typeof closeVersionDiff === 'function' ? closeVersionDiff : null;

  versionDiffData = {
    ok: true,
    versionId: '20260815-120000',
    title: 'Test sürümü',
    created_at: '2026-08-15T12:00:00.000Z',
    files: [
      { relativePath: 'episode/ep001.md', words: 4, content: 'satır1\\nsatır2\\nsatır3\\n', currentExists: true, currentWords: 5, currentContent: 'satır1\\nsatır2 YENİ\\nsatır3\\nsatır4\\n', truncated: false, currentTruncated: false },
      { relativePath: 'runtime/book-request.md', words: 2, content: 'a\\nb\\n', currentExists: true, currentWords: 2, currentContent: 'a\\nb\\n', truncated: false, currentTruncated: false }
    ]
  };
  versionDiffSelected = '';
  if (renderFiles) renderFiles();
  const vDiffFiles = document.getElementById('versionDiffFiles');
  const fileButtons = vDiffFiles ? vDiffFiles.querySelectorAll('[data-diff-file]').length : 0;
  const changedChip = vDiffFiles ? vDiffFiles.querySelectorAll('.diff-chip.added').length : 0;
  const unchangedChip = vDiffFiles ? vDiffFiles.querySelectorAll('.diff-chip.unchanged').length : 0;
  if (showDiff) showDiff('episode/ep001.md');
  const vDiffLines = document.getElementById('versionDiffLines');
  const vDiffMeta = document.getElementById('versionDiffMeta');
  const vDiffDialog = document.getElementById('versionDiffDialog');
  const addedLines = vDiffLines ? vDiffLines.querySelectorAll('.diff-line.added').length : 0;
  const removedLines = vDiffLines ? vDiffLines.querySelectorAll('.diff-line.removed').length : 0;
  const diffMetaFilled = vDiffMeta ? vDiffMeta.textContent.includes('ep001.md') : false;
  const selectedMarked = vDiffFiles ? vDiffFiles.querySelectorAll('[data-diff-file][aria-selected="true"]').length === 1 : false;
  if (vDiffDialog && typeof vDiffDialog.showModal === 'function') vDiffDialog.showModal();
  const opened = vDiffDialog ? vDiffDialog.open : false;
  if (closeDiff) closeDiff();
  const closed = vDiffDialog ? !vDiffDialog.open : true;
  versionDiffData = originalData;
  versionDiffSelected = originalSelected;
  return { fileButtons, changedChip, unchangedChip, addedLines, removedLines, diffMetaFilled, selectedMarked, opened, closed };
})()`);
const sceneParse = await evaluate(`(() => {
  const text = 'İlk sahne metni\\n\\n<!-- scene: İkinci Sahne -->\\n\\nİkinci sahne metni\\n\\n<!-- scene -->\\n\\nÜçüncü sahne\\n';
  const parse = typeof parseScenes === 'function' ? parseScenes : (typeof window.parseScenes === 'function' ? window.parseScenes : null);
  const serialize = typeof serializeScenes === 'function' ? serializeScenes : (typeof window.serializeScenes === 'function' ? window.serializeScenes : null);
  const scenes = parse ? parse(text) : [];
  return {
    count: scenes.length,
    titles: scenes.map(scene => scene.title),
    bodies: scenes.map(scene => scene.body.trim()),
    roundtrip: serialize ? serialize(scenes) === text : false
  };
})()`);
const sceneManagerUi = await evaluate(`(() => {
  const originalChapters = chapters;
  const originalMode = structuredEditorMode;
  const originalText = manuscriptText.value;
  const originalKey = currentChapterIndex;
  structuredEditorMode = 'source';
  chapters = [{ id: 'B01', filename: 'ep001.md', title: 'Birinci Bölüm', words: 0, state: 'wait', heat: { risk: 0, level: 'ok' } }];
  currentChapterIndex = 0;
  manuscriptText.value = 'İlk sahne\\n\\n<!-- scene: İkinci -->\\n\\nİkinci sahne metni\\n';
  openSceneManager();
  const firstOpen = sceneManagerDialog.open;
  const rowsInitial = sceneManagerList.querySelectorAll('.scene-row').length;
  const titlesInitial = [...sceneManagerList.querySelectorAll('.scene-title-input')].map(input => input.value);
  addScene();
  const rowsAfterAdd = sceneManagerList.querySelectorAll('.scene-row').length;
  const summaryAfterAdd = sceneManagerSummary.textContent;
  moveScene(0, 1);
  const titlesAfterMove = [...sceneManagerList.querySelectorAll('.scene-title-input')].map(input => input.value);
  const titleInputs = sceneManagerList.querySelectorAll('.scene-title-input');
  titleInputs[0].value = 'Yeni İsim';
  titleInputs[0].dispatchEvent(new Event('input', { bubbles: true }));
  const targetInputs = sceneManagerList.querySelectorAll('.scene-target-input');
  targetInputs[0].value = '500';
  targetInputs[0].dispatchEvent(new Event('input', { bubbles: true }));
  const progressWidth = sceneManagerList.querySelectorAll('.scene-progress')[0].querySelector('i').style.width;
  applyScenes();
  const appliedText = manuscriptText.value;
  const appliedTargets = JSON.parse(localStorage.getItem('kithub-scene-targets:studio') || '{}');
  const dialogClosed = !sceneManagerDialog.open;
  const appliedSceneCount = parseScenes(appliedText).length;
  manuscriptText.value = originalText;
  chapters = originalChapters;
  currentChapterIndex = originalKey;
  structuredEditorMode = originalMode;
  return {
    firstOpen, rowsInitial, titlesInitial, rowsAfterAdd, summaryAfterAdd,
    titlesAfterMove, progressWidth, appliedSceneCount, appliedTargets, dialogClosed
  };
})()`);
const publishingCompatibility = await evaluate(`(() => {
  const font = document.getElementById('typeFont');
  const pageSize = document.getElementById('pageSize');
  const design = document.getElementById('pageDesign');
  const before = { font: font?.value || '', pageSize: pageSize?.value || '', design: design?.value || '' };
  if (design) {
    design.value = 'artDeco';
    design.dispatchEvent(new Event('change', { bubbles: true }));
  }
  const bookPage = document.getElementById('bookPage');
  const optInApplied = bookPage ? bookPage.dataset.pageDesign === 'artDeco' : false;
  const metricsPreserved = (font?.value || '') === before.font && (pageSize?.value || '') === before.pageSize;
  if (design) {
    design.value = 'classicFrame';
    design.dispatchEvent(new Event('change', { bubbles: true }));
  }
  const profilesElem = document.getElementById('settingsOutputProfile');
  return {
    before,
    optInApplied,
    metricsPreserved,
    classicRestored: bookPage ? bookPage.dataset.pageDesign === 'classicFrame' : false,
    outputProfiles: profilesElem ? [...profilesElem.options].map(option => option.value) : [],
    defaultOutputProfile: profilesElem?.value || ''
  };
})()`);
const typographyVariety = await evaluate(`(() => {
  const typeFont = document.getElementById('typeFont');
  const fontSelect = document.getElementById('fontSelect');
  const ornament = document.getElementById('ornamentStyle');
  const linePreset = document.getElementById('lineHeightPreset');
  const design = document.getElementById('pageDesign');
  const bookPage = document.getElementById('bookPage');
  const fonts = typeFont ? [...typeFont.options].map(option => option.value) : [];
  const ornamentOptions = ornament ? [...ornament.options].map(option => option.value) : [];
  const linePresets = linePreset ? [...linePreset.options].map(option => Number(option.value)) : [];
  const designValues = design ? [...design.options].map(option => option.value) : [];
  const addedFonts = fonts.filter(font => ["Book Antiqua", "Constantia", "Cambria", "Perpetua"].includes(font));
  const fontSync = fontSelect ? fonts.length === [...fontSelect.options].length : false;
  if (design) {
    design.value = 'vintagePrint';
    design.dispatchEvent(new Event('change', { bubbles: true }));
  }
  const vintageApplied = bookPage ? bookPage.dataset.pageDesign === 'vintagePrint' : false;
  if (ornament) {
    ornament.value = 'fleuron';
    ornament.dispatchEvent(new Event('change', { bubbles: true }));
  }
  const ornamentApplied = bookPage ? bookPage.dataset.ornament === 'fleuron' : false;
  const lineHeight = document.getElementById('lineHeight');
  if (linePreset) {
    linePreset.value = '1.4';
    linePreset.dispatchEvent(new Event('change', { bubbles: true }));
  }
  const presetSynced = lineHeight ? Number(lineHeight.value) === 1.4 : false;
  if (design) {
    design.value = 'classicFrame';
    design.dispatchEvent(new Event('change', { bubbles: true }));
  }
  if (ornament) {
    ornament.value = 'diamond';
    ornament.dispatchEvent(new Event('change', { bubbles: true }));
  }
  if (lineHeight) lineHeight.value = '1.15';
  return {
    fonts, addedFonts, fontSync,
    designValues, vintageApplied,
    ornamentOptions, ornamentApplied,
    linePresets, presetSynced
  };
})()`);
const writingFeatures = await evaluate(`(() => {
  const dropCap = document.getElementById('dropCapStyle');
  const sceneBreak = document.getElementById('sceneBreakStyle');
  const device = document.getElementById('deviceMockup');
  const wordFreqToggle = document.getElementById('editorialWordFreqToggle');
  const options = select => select ? [...select.options].map(option => option.value) : [];
  const setValue = (id, value) => {
    const element = document.getElementById(id);
    if (!element) return;
    element.value = value;
    element.dispatchEvent(new Event('change', { bubbles: true }));
  };
  const originalText = manuscriptText.value;
  const setEd = typeof window.setEditorText === 'function' ? window.setEditorText : (typeof setEditorText === 'function' ? setEditorText : null);
  setEd('ilk sahne metni güzel güzel güzel güzel tekrar eden sözcükler\\n\\n<!-- scene: İkinci Sahne -->\\n\\nİkinci sahne metni güzel güzel güzel güzel\\n');
  if (typeof editorContentChanged === 'function') editorContentChanged();
  setValue('dropCapStyle', 'large');
  setValue('sceneBreakStyle', 'fleuron');
  if (wordFreqToggle && !wordFreqToggle.checked) {
    wordFreqToggle.checked = true;
    wordFreqToggle.dispatchEvent(new Event('change', { bubbles: true }));
  }
  if (typeof renderPreview === 'function') renderPreview();
  const firstParagraph = bookPage.querySelector('p.first');
  const hasDropCap = firstParagraph ? firstParagraph.classList.contains('drop-cap') : false;
  const sceneBreakRendered = pageBody.innerHTML.includes('scene-break') && !pageBody.innerHTML.includes('&lt;!-- scene');
  const wordFreqMarked = pageBody.innerHTML.includes('word-freq');
  const pacing = typeof analyzePacing === 'function' ? analyzePacing(manuscriptText.value) : [];
  const overused = typeof analyzeOverusedWords === 'function' ? analyzeOverusedWords(manuscriptText.value) : [];
  setValue('dropCapStyle', 'none');
  setValue('sceneBreakStyle', 'fleuron');
  setValue('deviceMockup', 'kindle');
  const deviceApplied = document.getElementById('previewShell')?.dataset.device === 'kindle';
  setValue('deviceMockup', 'none');
  setEd(originalText);
  if (typeof editorContentChanged === 'function') editorContentChanged();
  return {
    dropCapOptions: options(dropCap),
    sceneBreakOptions: options(sceneBreak),
    deviceOptions: options(device),
    wordFreqTogglePresent: Boolean(wordFreqToggle),
    hasDropCap,
    sceneBreakRendered,
    wordFreqMarked,
    pacingCount: pacing.length,
    pacingLevels: pacing.map(scene => scene.level),
    overusedCount: overused.length,
    deviceApplied
  };
})()`);
const publicationUx = await evaluate(`(() => {
  const workflow = [...document.querySelectorAll('[data-workflow-step]')];
  document.querySelector('[data-workflow-step="publish"]')?.click();
  const publishStepActive = document.querySelector('[data-workflow-step="publish"]')?.hasAttribute('aria-current') === true;
  const prompt = document.getElementById('aiPromptInput');
  const promptMinHeight = prompt ? Number.parseFloat(getComputedStyle(prompt).minHeight || '0') : 0;
  document.getElementById('openMatterManagerBtn')?.click();
  const matterDialog = document.getElementById('matterManagerDialog');
  const matterOpen = matterDialog?.open === true;
  const matterColumns = matterDialog?.querySelectorAll('.matter-column').length || 0;
  matterDialog?.close();
  document.getElementById('openCoverStudioBtn')?.click();
  const coverDialog = document.getElementById('coverStudioDialog');
  const coverOpen = coverDialog?.open === true;
  const pageCount = document.getElementById('coverPageCountInput');
  if (pageCount) {
    pageCount.value = '320';
    pageCount.dispatchEvent(new Event('input', { bubbles: true }));
  }
  const coverSizeCalculated = /mm/.test(document.getElementById('coverSizeSummary')?.textContent || '');
  coverDialog?.close();
  document.querySelector('[data-workflow-step="write"]')?.click();
  return {
    workflowCount: workflow.length,
    workflowLabels: workflow.map(item => item.textContent.trim()),
    publishStepActive,
    promptMinHeight,
    promptMaxLength: prompt?.maxLength || 4000,
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
const professionalUx = await evaluate(`(async () => {
  const pathInput = document.getElementById('projectPathInput');
  if (pathInput) pathInput.value = ${JSON.stringify(visualProjectRoot)};
  if (typeof loadProjectViaBridge === 'function') await loadProjectViaBridge();
  else if (typeof window.loadProjectViaBridge === 'function') await window.loadProjectViaBridge();
  document.getElementById('openProfessionalStudioBtn')?.click();
  const dialog = document.querySelector('.professional-dialog');
  const tabs = dialog?.querySelectorAll('[data-prof-tab]').length || 0;
  const entityKinds = dialog?.querySelectorAll('[data-entity-kind]').length || 0;
  dialog?.querySelector('[data-prof-tab="review"]')?.click();
  const reviewTools = Boolean(dialog?.querySelector('[data-comment-form]') && dialog?.querySelector('[data-change-form]') && dialog?.querySelector('[data-member-form]'));
  dialog?.querySelector('[data-prof-tab="publication"]')?.click();
  const publicationTools = Boolean(dialog?.querySelector('[data-publication-form]') && dialog?.querySelector('[data-cover-file]') && dialog?.querySelector('[data-apply-matter-templates]'));
  return { open: dialog?.open === true, tabs, entityKinds, reviewTools, publicationTools };
})()`);
const auditProfessionalScreenshotPath = screenshotPath.replace(/(\.[^.]+)$/, "-professional$1");
await delay(180);
const auditProfessionalScreenshot = await call("Page.captureScreenshot", { format: "png", captureBeyondViewport: false });
fs.writeFileSync(auditProfessionalScreenshotPath, Buffer.from(auditProfessionalScreenshot.data, "base64"));
await evaluate(`document.querySelector('.professional-dialog')?.close()`);
const controlContracts = await evaluate(`(() => {
  const visible = element => {
    if (!element) return false;
    const style = getComputedStyle(element);
    const rect = element.getBoundingClientRect();
    return style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0;
  };
  const listenerTypes = target => window.__kithubListenerTypes?.(target) || [];
  const handled = button => {
    if (!button) return false;
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
  const editor = document.getElementById('manuscriptText');
  const original = editor?.value || '';
  const sentence = 'KitHub ölçümlü sayfa akışı gerçek satır yüksekliğini ve kullanılabilir sayfa alanını izler.';
  const longParagraph = Array.from({ length: 520 }, (_, index) => sentence + ' ' + (index + 1)).join(' ');
  const tail = Array.from({ length: 70 }, (_, index) => 'Sonraki sahne paragrafı ' + (index + 1) + '.').join(' ');
  previewShowAll = false;
  setEditorText('# Ölçümlü Sayfalama\\n\\n' + longParagraph + '\\n\\n<!-- page-break -->\\n\\n## Yeni Sahne\\n\\n' + tail);
  renderPreview();
  const stage = document.querySelector('.page-stage');
  if (!stage) {
    setEditorText(original);
    renderPreview();
    return { mode: '', totalPages: 0, limitedPages: 0, allRenderedPages: 0, paragraphSplits: 0, hasShowAll: false, repeatedChapterTitles: 0, runningHeaders: 0, overflowPages: 0, strandedHeadings: 0, minimumContinuationLines: 0 };
  }
  const initialPages = [...stage.querySelectorAll(':scope > .page')];
  const pageBodies = initialPages.map(page => page.id === 'bookPage' ? page.querySelector('#pageBody') : page.children[1]);
  const lineCount = element => {
    if (!element) return 0;
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
    mode: stage.dataset.paginationMode || '',
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
  localStorage.clear();
  const editor = document.getElementById('manuscriptText');
  const unsavedText = editor.value;
  chapters = [
    { id: 'Bölüm 1', title: 'Güvenli Taslak', text: unsavedText },
    { id: 'Bölüm 2', title: 'Sonraki Bölüm', text: 'İkinci bölüm' }
  ];
  currentChapterIndex = 0;
  lastSavedContent = 'önceki kayıt';
  editorDirty = true;
  const originalShowChoice = showChoiceDialog;
  let capturedOptions = null;
  showChoiceDialog = ({ options }) => {
    capturedOptions = (options || []).map(option => option.label);
    return Promise.resolve(null);
  };
  const cancelSwitched = await selectChapter(1);
  const cancelBlocked = cancelSwitched === false && currentChapterIndex === 0 && editor.value === unsavedText;
  let discardSwitched = false;
  let discardTextPreserved = false;
  showChoiceDialog = ({ options }) => {
    const chosen = (options || []).find(option => option.label === 'Kaydetmeden Geç') || (options || []).find(option => option.label === 'Taslağı Sil');
    return Promise.resolve(chosen || null);
  };
  editorDirty = true;
  discardSwitched = await selectChapter(1);
  discardTextPreserved = editor.value === 'İkinci bölüm' && currentChapterIndex === 1;
  showChoiceDialog = originalShowChoice;
  return {
    dialogSeen: Array.isArray(capturedOptions) && capturedOptions.length === 3,
    options: capturedOptions || [],
    cancelBlocked,
    discardSwitched,
    discardTextPreserved,
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

const chapterPlanUi = await evaluate(`(() => {
  const realBridgeFetch = window.bridgeFetch;
  window.__kithubRealBridgeFetch = realBridgeFetch;
  let lastSavePayload = null;
  window.bridgeFetch = async (url, init) => {
    if (String(url).endsWith('/api/chapter-plan/save')) {
      lastSavePayload = JSON.parse(init.body || '{}');
      return { ok: true, json: async () => ({ ok: true }) };
    }
    if (String(url).endsWith('/api/manage-chapter')) {
      return { ok: true, json: async () => ({ ok: true }) };
    }
    return realBridgeFetch ? realBridgeFetch(url, init) : ({ ok: false, json: async () => ({ ok: false }) });
  };
  const active = chapters[0];
  active.plan = {
    status: 'draft', target_words: 1200, pov: '3. kişi', setting: 'Eski ev',
    summary: 'Defne içeri girer', scene_goal: 'Karakteri tanıt', conflict: 'Kapı kilitli', outcome: 'İçeri girer'
  };
  renderChapters();
  const chip = document.querySelector('#chapterList li:first-child .chapter-plan-status-chip');
  const chipBefore = {
    present: Boolean(chip),
    status: chip ? chip.dataset.status : null,
    label: chip ? chip.textContent.trim() : null
  };
  document.getElementById('chapterPlanBtn').click();
  const dialogOpen = document.getElementById('chapterPlanDialog').open;
  const prefill = {
    status: document.getElementById('chapterPlanStatus').value,
    target: Number(document.getElementById('chapterPlanTarget').value || 0),
    pov: document.getElementById('chapterPlanPov').value,
    setting: document.getElementById('chapterPlanSetting').value,
    summary: document.getElementById('chapterPlanSummary').value,
    goal: document.getElementById('chapterPlanGoal').value,
    conflict: document.getElementById('chapterPlanConflict').value,
    outcome: document.getElementById('chapterPlanOutcome').value,
    subtitle: document.getElementById('chapterPlanSubtitle').textContent.trim()
  };
  document.getElementById('chapterPlanStatus').value = 'editing';
  document.getElementById('chapterPlanTarget').value = '1800';
  document.getElementById('chapterPlanSummary').value = 'Güncellenen özet';
  document.getElementById('chapterPlanForm').requestSubmit();
  return new Promise(resolve => setTimeout(() => resolve({
    dialogOpen,
    chipPresent: chipBefore.present,
    chipStatus: chipBefore.status,
    chipLabel: chipBefore.label,
    prefill,
    savePayload: lastSavePayload,
    saveStatus: lastSavePayload ? lastSavePayload.status : null,
    saveTarget: lastSavePayload ? lastSavePayload.target_words : null,
    closedAfterSave: !document.getElementById('chapterPlanDialog').open,
    activePlanUpdated: Boolean(chapters[0].plan) && chapters[0].plan.status === 'editing'
  }), 0));
})()`);
await delay(120);

const chapterArchiveUi = await evaluate(`(() => {
  const realBridgeFetch = window.__kithubRealBridgeFetch || null;
  const originalShowChoice = showChoiceDialog;
  let lastAction = null;
  let dialogOptionsSeen = null;
  showChoiceDialog = ({ options }) => {
    dialogOptionsSeen = (options || []).map(option => option.label);
    return Promise.resolve(options.find(option => option.label === 'Arşivle'));
  };
  window.bridgeFetch = async (url, init) => {
    if (String(url).endsWith('/api/manage-chapter')) {
      const body = JSON.parse(init.body || '{}');
      if (body.action === 'archive') lastAction = body;
      return { ok: true, json: async () => ({ ok: true }) };
    }
    return realBridgeFetch ? realBridgeFetch(url, init) : ({ ok: false, json: async () => ({ ok: false }) });
  };
  refreshProject = async () => {
    chapters.splice(0, 1);
    currentChapterIndex = 0;
    renderChapters();
  };
  editorDirty = false;
  const active = chapters[0];
  active.filename = 'ep001.md';
  document.getElementById('archiveChapterBtn').click();
  return new Promise(resolve => setTimeout(() => resolve({
    dialogOptionsSeen,
    archivePayload: lastAction,
    rowsAfter: document.querySelectorAll('#chapterList li').length,
    archiveRemoved: !chapters.some(chapter => chapter.filename === 'ep001.md')
  }), 0));
})()`);
await delay(120);
await evaluate(`window.bridgeFetch = window.__kithubRealBridgeFetch || null; window.showChoiceDialog = window.__kithubShowChoiceOriginal || null;`);

const chapterTreeUi = await evaluate(`(() => {
  chapters = [
    { id: 'Bölüm 1', title: 'Birinci', filename: 'ep001.md', text: '# Birinci\\n\\n<!-- scene: Kapıda -->\\n\\nMetin', plan: { status: 'editing', date: '1989-01-15', setting: 'Eski ev', target_words: 1800 } },
    { id: 'Bölüm 2', title: 'İkinci', filename: 'ep002.md', text: '# İkinci\\n\\nMetin', plan: { status: 'idea', date: '1989-06-01', setting: 'Kasaba' } }
  ];
  currentChapterIndex = 0;
  const renTree = typeof renderChapterTree === 'function' ? renderChapterTree : (typeof window.renderChapterTree === 'function' ? window.renderChapterTree : null);
  if (renTree) renTree();
  const notes = document.getElementById('notesContent');
  const rowButtons = notes ? notes.querySelectorAll('[data-tree-chapter]') : [];
  const chapterRows = notes ? notes.querySelectorAll('.tree-chapter') : [];
  const sceneButtons = notes ? notes.querySelectorAll('.tree-scene') : [];
  const timelineEntries = notes ? notes.querySelectorAll('.timeline-entry') : [];
  const firstRow = chapterRows[0];
  const firstRowTitle = firstRow ? firstRow.querySelector('.tree-chapter-title')?.textContent.trim() : null;
  const firstRowChip = firstRow ? firstRow.querySelector('.chapter-plan-status-chip')?.dataset.status : null;
  const sceneLabel = sceneButtons[0] ? sceneButtons[0].textContent.trim() : null;
  const timelineFirst = timelineEntries[0] ? timelineEntries[0].querySelector('.timeline-title')?.textContent.trim() : null;
  const timelineDates = [...timelineEntries].map(entry => entry.querySelector('.timeline-date')?.textContent.trim());
  const currentMarked = chapterRows[0] ? chapterRows[0].classList.contains('is-current') : false;
  return {
    treeRendered: chapterRows.length === 2,
    firstRowTitle,
    firstRowChip,
    sceneLabel,
    timelineEntries: timelineEntries.length,
    timelineFirst,
    timelineDates,
    currentMarked
  };
})()`);
await delay(100);

await call("Emulation.setDeviceMetricsOverride", { width: 390, height: 844, deviceScaleFactor: 1, mobile: true });
await evaluate(`(() => {
  document.documentElement.style.setProperty('--page-zoom', '1');
  const z = document.getElementById('zoomSelect');
  if (z) z.value = '1';
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
    if (!element) return false;
    const style = getComputedStyle(element);
    const rect = element.getBoundingClientRect();
    return style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0;
  };
  return {
    toolbarOverflow: toolbar ? toolbar.scrollWidth > toolbar.clientWidth + 1 : false,
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
const mobileProfessionalLayout = await evaluate(`(async () => {
  const pathInput = document.getElementById('projectPathInput');
  if (pathInput) pathInput.value = ${JSON.stringify(visualProjectRoot)};
  if (typeof loadProjectViaBridge === 'function') await loadProjectViaBridge();
  else if (typeof window.loadProjectViaBridge === 'function') await window.loadProjectViaBridge();
  document.getElementById('openProfessionalStudioBtn')?.click();
  const dialog = document.querySelector('.professional-dialog');
  const shell = dialog?.querySelector('.professional-shell');
  const rect = dialog?.getBoundingClientRect();
  return {
    open: dialog?.open === true,
    fitsViewport: Boolean(rect && rect.left >= 0 && rect.right <= innerWidth + 1),
    horizontalOverflow: Boolean(shell && shell.scrollWidth > shell.clientWidth + 1),
    railVisible: Boolean(dialog?.querySelector('.professional-rail')?.getBoundingClientRect().height)
  };
})()`);
const mobileProfessionalScreenshotPath = screenshotPath.replace(/(\.[^.]+)$/, "-professional-mobile$1");
await delay(180);
const mobileProfessionalScreenshot = await call("Page.captureScreenshot", { format: "png", captureBeyondViewport: false });
fs.writeFileSync(mobileProfessionalScreenshotPath, Buffer.from(mobileProfessionalScreenshot.data, "base64"));
await evaluate(`document.querySelector('.professional-dialog')?.close()`);
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
    richRoundTrip,
    structuredNodes,
    findShortcut,
    findSelection,
    replaceShortcut,
    saveShortcut,
    editorialRules,
    findSearchOptions,
    quickJump,
    spellcheck,
    lineDiff,
    versionDiffUi,
    sceneParse,
    sceneManagerUi,
    publishingCompatibility,
    typographyVariety,
    writingFeatures,
    publicationUx,
    professionalUx,
    controlContracts,
    paginationFlow,
    chapterSwitchGuard,
    chapterManagerDialog,
    chapterPlanUi,
    chapterArchiveUi,
    chapterTreeUi,
    mobileLayout: mobileEditorLayout,
    mobileProfessionalLayout
  },
  screenshots: {
    desktop: screenshotPath,
    matter: auditMatterScreenshotPath,
    cover: auditCoverScreenshotPath,
    professional: auditProfessionalScreenshotPath,
    mobile: mobileScreenshotPath,
    professionalMobile: mobileProfessionalScreenshotPath
  }
};
process.stdout.write(JSON.stringify(result));
