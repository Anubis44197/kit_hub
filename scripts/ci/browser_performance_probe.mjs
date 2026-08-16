import { promises as fs } from "node:fs";
import { dirname } from "node:path";

const debugPort = Number(process.argv[2]);
const url = process.argv[3];
const reportPath = process.argv[4] || "";

if (!debugPort || !url) {
  console.error("Usage: node browser_performance_probe.mjs <debugPort> <url> [reportPath]");
  process.exit(2);
}

const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

let targets = [];
for (let attempt = 0; attempt < 40; attempt += 1) {
  try {
    targets = await fetch(`http://127.0.0.1:${debugPort}/json/list`).then(response => response.json());
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
const failedRequests = [];
let longTasks = [];

const call = (method, params = {}) => new Promise((resolve, reject) => {
  const id = ++nextId;
  const timer = setTimeout(() => {
    pending.delete(id);
    reject(new Error(`CDP timeout: ${method}`));
  }, 15000);
  pending.set(id, {
    resolve: value => { clearTimeout(timer); resolve(value); },
    reject: error => { clearTimeout(timer); reject(error); }
  });
  socket.send(JSON.stringify({ id, method, params }));
});

socket.addEventListener("message", event => {
  const message = JSON.parse(event.data);
  if (message.id && pending.has(message.id)) {
    const { resolve, reject } = pending.get(message.id);
    pending.delete(message.id);
    if (message.error) reject(new Error(message.error.message));
    else resolve(message.result || {});
    return;
  }
  if (message.method === "Performance.metrics") {
    const metrics = message.params.metrics || [];
    for (const metric of metrics) {
      if (metric.name === "TaskDuration") longTasks.push(metric.value);
    }
  }
  if (message.method === "Network.responseReceived") {
    const status = message.params.response?.status || 0;
    if (status >= 400) {
      const failedUrl = message.params.response?.url || message.params.requestId || "";
      if (/favicon/i.test(failedUrl)) return;
      const text = `Failed resource ${status}: ${failedUrl}`;
      failedRequests.push(text);
      consoleIssues.push(text);
    }
  }
  if (message.method === "Log.entryAdded") {
    const text = message.params.entry?.text || message.params.entry?.level || "";
    if (/Deprecated API for given entry type/i.test(text)) return;
    if (/favicon/i.test(text)) return;
    if (message.params.entry.level === "error" || message.params.entry.level === "warning") {
      consoleIssues.push(text);
    }
  }
  if (message.method === "Runtime.consoleAPICalled" && ["error", "warning"].includes(message.params?.type)) {
    const text = message.params.args.map(arg => arg.value ?? arg.description ?? "").join(" ");
    if (/favicon/i.test(text)) return;
    consoleIssues.push(text);
  }
  if (message.method === "Runtime.exceptionThrown") {
    consoleIssues.push(message.params.exceptionDetails?.text || "Runtime exception");
  }
});

await call("Page.enable");
await call("Runtime.enable");
await call("Performance.enable");
await call("Log.enable");
await call("Network.enable");
await call("Network.setCacheDisabled", { cacheDisabled: true });
await call("Emulation.setDeviceMetricsOverride", { width: 1440, height: 1200, deviceScaleFactor: 1, mobile: false });
await call("Emulation.setCPUThrottlingRate", { rate: 4 });
const baseline = (await call("Performance.getMetrics").catch(() => ({ metrics: [] }))).metrics || {};
const baselineMap = {};
for (const metric of baseline) baselineMap[metric.name] = metric.value;
await call("Page.navigate", { url });
await Promise.race([
  new Promise(resolve => {
    const onNav = event => {
      const message = JSON.parse(event.data);
      if (message.method === "Page.loadEventFired") {
        socket.removeEventListener("message", onNav);
        resolve();
      }
    };
    socket.addEventListener("message", onNav);
  }),
  delay(25000)
]);
await delay(1500);

const after = (await call("Performance.getMetrics").catch(() => ({ metrics: [] }))).metrics || {};
const afterMap = {};
for (const metric of after) afterMap[metric.name] = metric.value;

const evaluate = async expression => {
  const result = await call("Runtime.evaluate", { expression, returnByValue: true });
  if (result.exceptionDetails) {
    throw new Error(result.exceptionDetails.exception?.description || result.exceptionDetails.text || "Runtime evaluation failed.");
  }
  return result.result?.value;
};

const value = await evaluate(`(() => {
  const nav = performance.getEntriesByType('navigation')[0] || {};
  const paint = performance.getEntriesByType('paint') || [];
  const lcp = performance.getEntriesByType('largest-contentful-paint');
  const fcp = paint.find(p => p.name === 'first-contentful-paint');
  let reducedMotion = false;
  for (const sheet of Array.from(document.styleSheets)) {
    try {
      for (const rule of Array.from(sheet.cssRules || [])) {
        if (rule.media && String(rule.media.mediaText).includes('prefers-reduced-motion')) reducedMotion = true;
      }
    } catch (_) {}
  }
  return {
    domNodes: document.querySelectorAll('*').length,
    scripts: document.scripts.length,
    stylesheets: document.styleSheets.length,
    images: document.images.length,
    htmlBytes: document.documentElement.outerHTML.length,
    fcp: fcp ? fcp.startTime : null,
    lcp: lcp.length ? lcp[lcp.length - 1].startTime : null,
    domContentLoaded: nav.domContentLoadedEventEnd || null,
    load: nav.loadEventEnd || null,
    transferSize: nav.transferSize || 0,
    reducedMotion,
    mainArea: !!document.querySelector('main')
  };
})()`);

function metric(name) {
  const b = baselineMap[name] || 0;
  const a = afterMap[name] || 0;
  return { name, baseline: b, after: a, delta: a - b };
}

const layoutCount = metric("LayoutCount");
const reflowCount = metric("RecalcStyleCount");
const layoutDuration = metric("LayoutDuration");
const reflowDuration = metric("RecalcStyleDuration");
const scriptDuration = metric("ScriptDuration");
const taskDuration = metric("TaskDuration");

const longTaskCount = Math.max(0, Math.round(taskDuration.delta / 50));

const scores = {};
scores.fcp = value.fcp !== null && value.fcp < 1800 ? "PASS" : (value.fcp === null ? "NO_DATA" : "FAIL");
scores.lcp = value.lcp !== null && value.lcp < 2500 ? "PASS" : (value.lcp === null ? "NO_DATA" : "FAIL");
scores.domNodes = value.domNodes > 0 && value.domNodes < 8000 ? "PASS" : "FAIL";
scores.layoutDuration = layoutDuration.delta < 200 ? "PASS" : "FAIL";
scores.reflowDuration = reflowDuration.delta < 300 ? "PASS" : "FAIL";
scores.scriptDuration = scriptDuration.delta < 600 ? "PASS" : "FAIL";
scores.longTasks = longTaskCount <= 4 ? "PASS" : "FAIL";
scores.consoleErrors = consoleIssues.length === 0 ? "PASS" : "FAIL";
scores.reducedMotion = value.reducedMotion === true ? "PASS" : "FAIL";
scores.mainLandmark = value.mainArea === true ? "PASS" : "FAIL";

const overallPass = Object.values(scores).every(v => v === "PASS" || v === "NO_DATA");

const report = {
  schema_version: "1.0.0",
  report_type: "browser_performance_probe",
  generated_at: new Date().toISOString(),
  url,
  target: "performance-and-correctness-subset",
  overall: overallPass ? "PASS" : "FAIL",
  scores,
  metrics: {
    fcpMs: value.fcp,
    lcpMs: value.lcp,
    domContentLoadedMs: value.domContentLoaded,
    loadMs: value.load,
    domNodes: value.domNodes,
    scripts: value.scripts,
    stylesheets: value.stylesheets,
    images: value.images,
    transferBytes: value.transferSize,
    layoutCount: layoutCount.delta,
    reflowCount: reflowCount.delta,
    layoutDurationMs: layoutDuration.delta,
    reflowDurationMs: reflowDuration.delta,
    scriptDurationMs: scriptDuration.delta,
    longTaskCount,
    consoleIssues: consoleIssues.length
  },
  consoleIssues,
  failedRequests,
  notes: [
    "Measured under 4x CPU throttling on headless Edge via CDP.",
    "FCP/LCP thresholds: 1800ms / 2500ms; DOM < 8000 nodes; layout/reflow/script budgets and long-task cap enforced.",
    "Reduced-motion and main landmark checks mirror the accessibility subset."
  ]
};

if (reportPath) {
  await fs.mkdir(dirname(reportPath), { recursive: true });
  await fs.writeFile(reportPath, JSON.stringify(report, null, 2), "utf8");
}

console.log(JSON.stringify(report));
process.exit(overallPass ? 0 : 1);