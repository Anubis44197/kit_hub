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
  if (result.exceptionDetails) throw new Error(result.exceptionDetails.text || "Runtime evaluation failed.");
  return result.result?.value;
};
const key = async (keyName, code = keyName) => {
  const virtualKey = keyName === "Enter" ? 13 : keyName === "Escape" ? 27 : keyName === "End" ? 35 : 0;
  await call("Input.dispatchKeyEvent", { type: "rawKeyDown", key: keyName, code, windowsVirtualKeyCode: virtualKey, nativeVirtualKeyCode: virtualKey });
  if (keyName === "Enter") {
    await call("Input.dispatchKeyEvent", { type: "char", key: keyName, code, text: "\r", unmodifiedText: "\r", windowsVirtualKeyCode: virtualKey, nativeVirtualKeyCode: virtualKey });
  }
  await call("Input.dispatchKeyEvent", { type: "keyUp", key: keyName, code, windowsVirtualKeyCode: virtualKey, nativeVirtualKeyCode: virtualKey });
  await delay(120);
};

await call("Page.enable");
await call("Runtime.enable");
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

await evaluate(`document.activeElement?.blur()`);
await key("Tab");
const skipLinkFocused = await evaluate(`document.activeElement?.id === 'skipToWorkspace'`);
await key("Enter");
const skipTargetFocused = await evaluate(`document.activeElement?.id === 'workspace' && location.hash === '#workspace'`);

await evaluate(`document.getElementById('focusModeBtn').focus()`);
const focusButtonBefore = await evaluate(`document.activeElement?.id`);
await key("Enter");
const focusModeEntered = await evaluate(`({ active: document.body.classList.contains('focus-writing'), focused: document.activeElement?.id, pressed: document.getElementById('focusModeBtn').getAttribute('aria-pressed') })`);
await key("Escape");
const focusModeExited = await evaluate(`({ active: document.body.classList.contains('focus-writing'), focused: document.activeElement?.id, pressed: document.getElementById('focusModeBtn').getAttribute('aria-pressed') })`);

await evaluate(`document.getElementById('zoomSelect').focus()`);
const zoomBefore = await evaluate(`({ value: document.getElementById('zoomSelect').value, css: getComputedStyle(document.documentElement).getPropertyValue('--page-zoom').trim() })`);
await key("End");
const zoomAfter = await evaluate(`({ value: document.getElementById('zoomSelect').value, css: getComputedStyle(document.documentElement).getPropertyValue('--page-zoom').trim(), focused: document.activeElement?.id })`);

await call("Emulation.setDeviceMetricsOverride", { width: 390, height: 844, deviceScaleFactor: 1, mobile: true });
await evaluate(`(() => {
  document.documentElement.style.setProperty('--page-zoom', '1');
  document.getElementById('zoomSelect').value = '1';
  history.replaceState(null, '', location.pathname + location.search);
  window.scrollTo(0, 0);
})()`);
await delay(350);
const mobileAccessibility = await evaluate(accessibilityExpression);
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
    entered: focusModeEntered.active === true && focusModeEntered.focused === "manuscriptText" && focusModeEntered.pressed === "true",
    escaped: focusModeExited.active === false && focusModeExited.focused === "focusModeBtn" && focusModeExited.pressed === "false",
    enteredState: focusModeEntered,
    escapedState: focusModeExited
  },
  zoom: {
    changedByKeyboard: zoomAfter.value !== zoomBefore.value && zoomAfter.css === zoomAfter.value && zoomAfter.focused === "zoomSelect",
    before: zoomBefore,
    after: zoomAfter
  },
  screenshots: {
    desktop: screenshotPath,
    mobile: mobileScreenshotPath
  }
};
process.stdout.write(JSON.stringify(result));
