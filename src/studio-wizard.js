(() => {
  "use strict";

  const STORAGE_KEY = "kithub-wizard-state";
  const WIZARD_STEPS = [
    { id: "brief", title: "Künye", nav: "wizard", desc: "Kitap türü, hedef sayfa, okur, konu, karakterler, mekân, anlatıcı, final ve sınırları girin." },
    { id: "template", title: "Şablon", nav: "page", desc: "Roman Klasik, Yayınevi A5, Şiir vb. hazır kitap şablonlarından birini seçin." },
    { id: "design", title: "Tasarım", nav: "page", desc: "Klasik Çerçeve, Editoryal Minimal, Art Deco gibi sayfa tasarımını seçin." },
    { id: "size", title: "Boyut", nav: "page", desc: "Sayfa boyutu, özel ölçü, baskı türü ve ön bölümü ayarlayın." },
    { id: "font", title: "Yazı", nav: "font", desc: "Yazı tipi, punto ve satır aralığını seçin; ön izlemede görün." },
    { id: "ornament", title: "Süsler", nav: "font", desc: "Bölüm süsü, drop cap ve sahne arası süsleri seçin." },
    { id: "margin", title: "Kenar", nav: "margins", desc: "Kenar boşlukları, paragraf girintisi ve dul/yetim korumasını ayarlayın." },
    { id: "header", title: "Başlık/No", nav: "numbering", desc: "Bölüm başlangıcı, üstbilgi, sayfa numarası ve içindekileri ayarlayın." },
    { id: "matter", title: "Ön/Arka", nav: "matter", desc: "Başlık sayfası, künye, ön söz ve arka sayfaları düzenleyin." },
    { id: "cover", title: "Kapak", nav: "cover", desc: "Kapak stüdyosunda ön kapak, sırt ve arka kapağı hazırlayın." },
    { id: "summary", title: "Toplu Onay", nav: "summary", desc: "Tüm seçimleri tek ekranda görün ve hepsini onaylayın." },
    { id: "write", title: "Yazım", nav: "write", desc: "Onaylı plana göre kitap bölümlerini yazın (IDE veya API)." },
    { id: "export", title: "Çıktı", nav: "export", desc: "DOCX, PDF, kapak ve EPUB'ı tek paket olarak masaüstüne aktarın." }
  ];

  const STEP_GROUPS = {
    template: ["layoutProfile", "pageDesign", "pageSize", "customSizeWidth", "customSizeHeight", "printMode", "frontMatter"],
    design: ["pageDesign"],
    size: ["pageSize", "customSizeWidth", "customSizeHeight", "printMode", "frontMatter"],
    font: ["typeFont", "typeSize", "lineHeight", "lineHeightPreset"],
    ornament: ["ornamentStyle", "dropCapStyle", "dropCapRunIn", "dropCapTint", "sceneBreakStyle", "sceneBreakSize"],
    margin: ["marginTop", "marginInside", "marginOutside", "indent", "after", "widowOrphanControl"],
    header: ["chapterStartPolicy", "headingHierarchyPolicy", "runningHeaderPolicy", "pageNumberPosition", "tocDepth", "frontMatterNumbering"],
    brief: ["wizardType", "wizardPages", "wizardReader", "wizardCharacters", "wizardNarrator", "wizardPremise", "wizardSetting", "wizardEnding", "wizardStyle", "wizardBoundaries"]
  };

  const GALLERIES = {
    layoutProfile: { containerId: "wzGalleryTemplate", label: "Kitap Şablonu" },
    pageDesign: { containerId: "wzGalleryDesign", label: "Sayfa Tasarımı" },
    typeFont: { containerId: "wzGalleryFont", label: "Yazı Tipi" }
  };

  const state = {
    current: 0,
    approvals: {},
    allApproved: false,
    wizardCompletedAt: null,
    updatedAt: null,
    bridgeOnline: false
  };

  function el(id) {
    return document.getElementById(id);
  }

  function safe(fn) {
    try { return fn(); } catch (error) { return null; }
  }

  function injectStyles() {
    const css = `
      #kithubWizardBar { border-bottom: 1px solid var(--line-soft); padding: 8px 10px; background: var(--panel); color: var(--text); }
      #kithubWizardBar .wz-head { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; }
      #kithubWizardBar .wz-title { font-weight: 700; font-size: 13px; }
      #kithubWizardBar .wz-progress { font-size: 11px; opacity: 0.8; margin-right: auto; }
      #kithubWizardBar button { font-size: 11px; padding: 3px 8px; }
      #kithubWizardBar .wz-steps { display: flex; flex-wrap: wrap; gap: 3px; margin-top: 6px; }
      #kithubWizardBar .wz-step { border: 1px solid var(--line); background: var(--panel-2); color: var(--muted); border-radius: 999px; padding: 1px 7px; font-size: 10px; cursor: pointer; }
      #kithubWizardBar .wz-step.current { border-color: var(--teal-deep); background: var(--teal-deep); color: #fff; }
      #kithubWizardBar .wz-step.approved { border-color: var(--green); background: rgba(104, 196, 134, 0.14); color: var(--green); }
      #kithubWizardBar .wz-step.approved::after { content: " ✓"; }
      #kithubWizardBar .wz-step.locked { opacity: 0.55; }
      #kithubWizardBar .wz-info { margin-top: 6px; font-size: 11px; display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
      #kithubWizardBar .wz-info .wz-desc { opacity: 0.85; margin-right: auto; }
      #kithubWizardBar .wz-info button { font-size: 12px; }
      #wzSummaryMini { font-size: 11px; padding: 2px 8px; }
      .wz-step-note { margin: 12px 14px; padding: 12px; border: 1px dashed var(--line); border-radius: 8px; color: var(--text); font-size: 13px; background: var(--panel-2); }
      .wz-gallery { display: grid; grid-template-columns: repeat(auto-fill, minmax(112px, 1fr)); gap: 8px; margin: 8px 0 4px; }
      .wz-card { border: 1px solid var(--line); background: var(--panel-2); border-radius: 8px; padding: 8px; cursor: pointer; text-align: left; }
      .wz-card:hover { border-color: var(--green); }
      .wz-card.selected { border-color: var(--green); box-shadow: 0 0 0 2px rgba(104, 196, 134, 0.25); }
      .wz-card .wz-card-mini { display: block; width: 100%; aspect-ratio: 2 / 3; border: 1px solid #4a443a; background: var(--paper); border-radius: 3px; margin-bottom: 6px; padding: 4px; overflow: hidden; position: relative; }
      .wz-card .wz-card-mini .wz-ml { display: block; height: 6px; background: #b9b2a0; border-radius: 2px; margin-bottom: 4px; }
      .wz-card .wz-card-mini .wz-ml.wz-hl { height: 8px; width: 62%; background: #8a8171; }
      .wz-card .wz-card-mini .wz-a { font-size: 15px; line-height: 1; font-weight: 700; color: var(--paper-ink); }
      .wz-card .wz-card-label { font-size: 12px; font-weight: 600; }
      .wz-card .wz-card-sub { font-size: 10px; opacity: 0.7; display: block; }
      .wz-locked { pointer-events: none; opacity: 0.55; filter: saturate(0.5); }
      .wz-banner { margin: 10px 12px; padding: 10px 12px; border: 1px solid var(--green); border-radius: 8px; background: rgba(104, 196, 134, 0.12); font-size: 13px; color: var(--text); }
      .wz-banner.error { border-color: var(--red); background: rgba(216, 109, 98, 0.12); }
      #wzSummaryDialog { border: 1px solid var(--line); border-radius: 12px; padding: 18px; width: min(680px, 92vw); max-height: 84vh; background: var(--shell); color: var(--text); }
      #wzSummaryDialog::backdrop { background: rgba(0, 0, 0, 0.55); }
      #wzSummaryDialog .wz-sum-list { max-height: 46vh; overflow: auto; margin: 10px 0; border: 1px solid var(--line-soft); border-radius: 8px; }
      #wzSummaryDialog .wz-sum-item { display: flex; justify-content: space-between; gap: 12px; padding: 8px 10px; border-bottom: 1px solid var(--line-soft); font-size: 13px; }
      #wzSummaryDialog .wz-sum-item:last-child { border-bottom: 0; }
      #wzSummaryDialog .wz-sum-item.ok::before { content: "✓ "; color: var(--green); font-weight: 700; }
      #wzSummaryDialog .wz-sum-item.pending::before { content: "○ "; color: var(--amber); font-weight: 700; }
      #wzSummaryDialog footer { display: flex; justify-content: flex-end; gap: 8px; margin-top: 12px; }
      .wz-sum-foot { display: flex; justify-content: flex-end; padding: 10px 4px 2px; }
      #wzSummaryDialog .wz-locked-note { font-size: 12px; opacity: 0.8; margin-top: 6px; }
      #wzCoverImageBox { grid-column: 1 / -1; border: 1px dashed var(--line); border-radius: 10px; padding: 12px; }
      #wzCoverImageBox .wz-cover-img { width: 100%; max-height: 220px; object-fit: contain; background: var(--panel-2); border-radius: 6px; }
      #wzCoverImageBox .wz-cover-actions { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 10px; }
      #wzCoverImageBox .wz-cover-note { font-size: 11px; opacity: 0.75; margin-top: 6px; }

      #wzGuidedBar { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; padding: 4px 14px; background: var(--panel); color: var(--text); font-size: 12px; border-bottom: 1px solid var(--line-soft); }
      #wzGuidedBar .wzg-title { font-weight: 700; }
      #wzGuidedBar .wzg-chips { display: flex; gap: 6px; flex-wrap: wrap; }
      #wzGuidedBar .wzg-chip { border: 1px solid var(--line); color: var(--muted); border-radius: 999px; padding: 1px 9px; font-size: 11px; }
      #wzGuidedBar .wzg-chip.current { background: var(--teal-deep); color: #fff; border-color: var(--teal-deep); font-weight: 700; }
      #wzGuidedBar .wzg-chip.done { background: var(--panel-2); border-color: var(--line); }
      #wzGuidedBar .wzg-hint { margin-left: auto; opacity: 0.85; font-size: 12px; }
      #wzGuidedBar .wzg-toggle { margin-left: 4px; background: var(--teal-deep); color: #fff; border: 0; border-radius: 6px; padding: 3px 10px; cursor: pointer; font-size: 11px; }
      #wzGuidedBar .wzg-toggle:hover { background: #15504f; }

      main.app.guided { --type-h: 0px; }
      main.app.guided .typography .type-body { overflow-y: auto; }
      .wz-active-group { outline: 2px solid var(--green); outline-offset: -2px; border-radius: 8px; }
      .wz-active-gallery { box-shadow: 0 0 0 2px rgba(104, 196, 134, 0.35); border-radius: 8px; }
      main.app #exportBtn { display: none !important; }
      main.app #agentList { display: none !important; }
      main.app.guided .sidebar .nav-section { display: none !important; }
      main.app.guided .sidebar .side-footer { display: none !important; }
      main.app.guided .topbar .workflow-rail { display: none !important; }
      main.app.guided .topbar #exportBtn { display: none !important; }
      main.app.guided.stage-1 .workspace .tabs,
      main.app.guided.stage-1 .workspace .toolbar,
      main.app.guided.stage-1 .workspace .editor-grid,
      main.app.guided.stage-1 .workspace .statusbar { display: none !important; }

      main.app.guided .agents { overflow-y: auto; }
      main.app.guided .agents > section.typography {
        flex: 0 0 auto;
        display: flex;
        flex-direction: column;
        max-height: 58vh;
        min-width: 0;
        border-bottom: 1px solid var(--line-soft);
        border-top: 0;
        border-right: 0;
      }
      main.app.guided .agents > section.typography .type-head { display: none; }
      main.app.guided .agents > section.typography .type-body { flex: 1 1 auto; overflow-y: auto; min-height: 0; }

      main.app.guided #wzAdvancedMenus { display: none !important; }

      main.app .topbar .workflow-rail { display: none !important; }
      #wzPhaseList { flex: 1 1 auto; min-width: 0; display: grid; grid-template-columns: repeat(9, minmax(58px, 1fr)); align-items: stretch; height: 100%; }
      .wz-ph-node { position: relative; min-height: 60px; }
      .wz-ph-node::before { content: ""; position: absolute; left: 50%; top: 9px; width: 14px; height: 14px; border: 1px solid var(--quiet); border-radius: 50%; background: var(--shell); transform: translateX(-50%); z-index: 2; }
      .wz-ph-node::after { content: ""; position: absolute; left: 0; right: 0; top: 15px; height: 1px; background: var(--line); z-index: 1; }
      .wz-ph-node:first-child::after { left: 50%; }
      .wz-ph-node:last-child::after { right: 50%; }
      .wz-ph-label { position: absolute; bottom: 3px; left: 0; right: 0; text-align: center; font-size: 10px; color: var(--muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; padding: 0 4px; z-index: 3; }
      .wz-ph-node.done::after { background: var(--green); }
      .wz-ph-node.done::before { border-color: var(--green); background: var(--green); }
      .wz-ph-node.done .wz-ph-label { color: var(--green); }
      .wz-ph-node.running::after { background: var(--teal); }
      .wz-ph-node.running::before { border-color: var(--teal); background: var(--teal); animation: wzPhasePulse 1.2s ease-in-out infinite; }
      .wz-ph-node.running .wz-ph-label { color: var(--teal); }
      @keyframes wzPhasePulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.35; } }

      #wzStartPanel { padding: 44px 24px; }
      #wzStartPanel .wz-start-card { max-width: 660px; margin: 0 auto; border: 1px solid var(--line); border-radius: 14px; background: var(--panel-2); padding: 28px 26px; text-align: center; color: var(--text); }
      #wzStartPanel h2 { margin: 0 0 8px; color: var(--teal); }
      #wzStartPanel .wz-start-lead { margin: 0 0 14px; opacity: 0.85; }
      #wzStartPanel ol.wz-start-steps { text-align: left; max-width: 540px; margin: 0 auto 18px; padding-left: 20px; line-height: 1.7; }
      #wzStartPanel .wz-start-actions { display: flex; gap: 10px; justify-content: center; flex-wrap: wrap; }
      #wzStartPanel .wz-start-status { margin: 14px 0 0; font-size: 13px; color: var(--green); font-weight: 600; }
      #wzStartPanel .wz-start-status.wz-start-error { color: var(--red); }

      #wzDonePanel { padding: 26px 24px; }
      #wzDonePanel .wz-done-card { max-width: 620px; margin: 0 auto; border: 1px solid var(--green); border-radius: 14px; background: var(--panel-2); padding: 26px; text-align: center; color: var(--text); }
      #wzDonePanel h2 { margin: 0 0 8px; color: var(--green); }
      #wzDonePanel .wz-done-path { font-family: Consolas, monospace; font-size: 12px; background: var(--panel); border: 1px solid var(--line); border-radius: 6px; padding: 6px 10px; display: inline-block; }
    `;
    const style = document.createElement("style");
    style.textContent = css;
    document.head.appendChild(style);
  }

  function readState() {
    const stored = safe(() => JSON.parse(localStorage.getItem(STORAGE_KEY)));
    if (stored && stored.approvals) {
      state.approvals = stored.approvals;
      state.allApproved = !!stored.allApproved;
      state.wizardCompletedAt = stored.wizardCompletedAt || null;
    }
  }

  function persistLocal() {
    const snapshot = {
      schema_version: "1.0.0",
      mode: safe(() => getActiveMode()) || "ide",
      approvals: state.approvals,
      all_approved: state.allApproved,
      wizard_completed_at: state.wizardCompletedAt,
      updated_at: new Date().toISOString()
    };
    safe(() => localStorage.setItem(STORAGE_KEY, JSON.stringify(snapshot)));
    return snapshot;
  }

  async function persistBridge(snapshot) {
    const projectRoot = (el("projectPathInput")?.value || "").trim();
    if (!projectRoot || projectRoot === ".") return;
    const result = await safe(() => professionalApi("/api/wizard-state/save", { projectRoot, state: snapshot }));
    if (result && result.ok) state.bridgeOnline = true;
  }

  async function loadBridge() {
    const projectRoot = (el("projectPathInput")?.value || "").trim();
    if (!projectRoot || projectRoot === ".") return;
    const result = await safe(() => professionalApi("/api/wizard-state/read", { projectRoot }));
    if (result && result.ok && result.state && result.state.approvals) {
      state.approvals = result.state.approvals;
      state.allApproved = !!result.state.all_approved;
      state.wizardCompletedAt = result.state.wizard_completed_at || null;
      state.bridgeOnline = true;
    }
  }

  function stepControls(id) {
    return (STEP_GROUPS[id] || []).map(controlId => el(controlId)).filter(Boolean);
  }

  function isApproved(id) {
    return !!state.approvals[id] && state.approvals[id].approved_at;
  }

  function lockControls(id, locked) {
    stepControls(id).forEach(control => { control.disabled = locked; });
  }

  function applyStepLockUi() {
    WIZARD_STEPS.forEach(step => {
      stepControls(step.id).forEach(control => { control.disabled = false; });
    });
    document.querySelectorAll(".wz-gallery").forEach(container => {
      container.classList.remove("wz-locked");
    });
  }

  function renderProgress() {
    const approvedCount = WIZARD_STEPS.filter(step => isApproved(step.id)).length;
    const progress = el("wzProgress");
    if (progress) progress.textContent = `${approvedCount}/${WIZARD_STEPS.length} onaylandı`;
    const steps = el("wzSteps");
    if (steps) {
      steps.innerHTML = "";
      WIZARD_STEPS.forEach((step, index) => {
        const chip = document.createElement("button");
        chip.type = "button";
        chip.className = "wz-step";
        chip.dataset.stepIndex = String(index);
        chip.textContent = `${index + 1}. ${step.title}`;
        if (index === state.current) chip.classList.add("current");
        if (isApproved(step.id)) chip.classList.add("approved");
        chip.title = step.desc;
        chip.addEventListener("click", () => { state.current = index; renderStep(); });
        steps.appendChild(chip);
      });
    }
    const approve = el("wzApprove");
    if (approve) {
      const current = WIZARD_STEPS[state.current];
      const approved = current ? isApproved(current.id) : false;
      approve.disabled = approved;
      approve.textContent = approved ? "Onaylandı ✓" : "Adımı Onayla";
    }
  }

  function describeSelection(stepId) {
    const values = {};
    (STEP_GROUPS[stepId] || []).forEach(id => { values[id] = el(id)?.value ?? ""; });
    const pick = id => values[id];
    switch (stepId) {
      case "brief": {
        const name = (document.querySelector(".book-title")?.textContent || "").trim();
        return `Tür: ${pick("wizardType") || "-"} · Hedef: ${pick("wizardPages") || "-"} sayfa · Okur: ${pick("wizardReader") || "-"}`;
      }
      case "template": return `Şablon: ${pick("layoutProfile") || "-"}`;
      case "design": return `Tasarım: ${pick("pageDesign") || "-"}`;
      case "size": return `Boyut: ${pick("pageSize") || "-"} · ${pick("printMode") || "-"} · ${pick("frontMatter") || "-"}`;
      case "font": return `Yazı: ${pick("typeFont") || "-"} ${pick("typeSize") || "-"} pt · Satır: ${pick("lineHeight") || "-"}`;
      case "ornament": return `Süs: ${pick("ornamentStyle") || "-"} · Drop cap: ${pick("dropCapStyle") || "-"} · Sahne: ${pick("sceneBreakStyle") || "-"}`;
      case "margin": return `Üst/İç/Dış: ${pick("marginTop") || "-"}/${pick("marginInside") || "-"}/${pick("marginOutside") || "-"} · Girinti: ${pick("indent") || "-"}`;
      case "header": return `Sayfa no: ${pick("pageNumberPosition") || "-"} · Üstbilgi: ${pick("runningHeaderPolicy") || "-"} · İçindekiler: ${pick("tocDepth") || "-"}`;
      case "matter": return "Ön/arka sayfalar kapak stüdyosu üzerinden kaydedilir.";
      case "cover": return "Kapak stüdyosu ayarları kaydedilir.";
      case "summary": return "Tüm adımların toplu onayı.";
      case "write": return "Yazım IDE/API modunda ilerler.";
      case "export": return "Tek paket masaüstüne aktarılır.";
      default: return "";
    }
  }

  function stepInfo() {
    const current = WIZARD_STEPS[state.current];
    const info = el("wzStepInfo");
    if (!info) return;
    const desc = el("wzDesc");
    if (desc) desc.textContent = current.desc;
    const sel = el("wzSelection");
    if (sel) sel.textContent = isApproved(current.id) ? `Onaylı: ${describeSelection(current.id)}` : `Seçim: ${describeSelection(current.id)}`;
  }

  function renderStep() {
    const current = WIZARD_STEPS[state.current];
    if (!current) return;
    if (current.nav !== "wizard" && typeof focusTypeSection === "function") {
      safe(() => focusTypeSection(current.nav));
    }
    if (current.nav === "matter") {
      const btn = el("openMatterManagerBtn");
      if (btn) btn.click();
    }
    if (current.nav === "cover") {
      const btn = el("openCoverStudioBtn");
      if (btn) btn.click();
    }
    stepInfo();
    renderProgress();
    applyStepLockUi();
    applyStepVisibility();
  }

  function stepIdForField(fieldId) {
    for (const [stepId, fields] of Object.entries(STEP_GROUPS)) {
      if (fields.includes(fieldId)) return stepId;
    }
    return null;
  }

  function resetApprovalOnChange(fieldId) {
    const stepId = stepIdForField(fieldId);
    if (!stepId || !isApproved(stepId)) return;
    unlockStep(stepId);
    safe(() => setStatus(`Motor olayı: ${stepId} seçimi değişti — onay yeniden alınmalı.`));
  }

  function fieldEl(controlId) {
    const control = el(controlId);
    if (!control) return null;
    return control.closest("label.field") || control.parentElement;
  }

  function galleryForStep(stepId) {
    if (stepId === "template") return "wzGalleryTemplate";
    if (stepId === "design") return "wzGalleryDesign";
    if (stepId === "font") return "wzGalleryFont";
    return null;
  }

  function stepNoteText(stepId) {
    if (stepId === "matter") return "Ön / arka sayfalar düzenleniyor — düzenleme ekranı açıldı. Bitince “Kitap Parçalarını Kaydet”e basın; adım otomatik onaylanır.";
    if (stepId === "cover") return "Kapak stüdyosu açıldı. Kapak ayarlarını yapıp “Kapak Ayarlarını Kaydet”e basın (veya görsel yükleyin/üretin); adım otomatik onaylanır.";
    if (stepId === "write") return "Yazım adımı. Tüm onaylar alındıysa “Adımı Onayla” yazımı başlatır (IDE: komutu kopyalar, API: fazları çalıştırır).";
    if (stepId === "export") return "Çıktı adımı. Yazım onaylandıysa “Adımı Onayla” final DOCX ve paketi masaüstüne üretir.";
    return "";
  }

  function renderInlineSummary() {
    let box = el("wzStepSummary");
    const body = document.querySelector("section.typography .type-body");
    if (!box && body) {
      box = document.createElement("div");
      box.id = "wzStepSummary";
      box.className = "wz-sum-list";
      body.appendChild(box);
    }
    if (!box) return;
    box.replaceChildren();
    WIZARD_STEPS.forEach(step => {
      const approved = isApproved(step.id);
      const row = document.createElement("div");
      row.className = "wz-sum-item " + (approved ? "ok" : "pending");
      const title = document.createElement("span");
      title.textContent = `${step.title}`;
      const value = document.createElement("span");
      value.textContent = approved ? (state.approvals[step.id].selection || describeSelection(step.id)) : "Onay bekliyor";
      row.appendChild(title);
      row.appendChild(value);
      box.appendChild(row);
    });
    const foot = document.createElement("div");
    foot.className = "wz-sum-foot";
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "primary";
    btn.textContent = "Hepsini Onayla";
    btn.addEventListener("click", approveAll);
    foot.appendChild(btn);
    box.appendChild(foot);
  }

  function createStepNote() {
    const body = document.querySelector("section.typography .type-body");
    if (!body) return null;
    const note = document.createElement("div");
    note.id = "wzStepNote";
    note.className = "wz-step-note";
    body.appendChild(note);
    return note;
  }

  function applyStepVisibility() {
    const app = document.querySelector("main.app");
    const guided = app && app.classList.contains("guided");
    const current = WIZARD_STEPS[state.current];
    const body = document.querySelector("section.typography .type-body");
    if (!body || !current) return;
    const noteEl = el("wzStepNote") || createStepNote();
    const sumEl = el("wzStepSummary");
    if (noteEl) noteEl.style.display = "none";
    if (sumEl) sumEl.style.display = "none";
    body.querySelectorAll(".type-group").forEach(g => g.classList.remove("wz-active-group"));
    body.querySelectorAll(".wz-gallery").forEach(g => g.classList.remove("wz-active-gallery"));
    document.querySelectorAll("section.wizard-panel").forEach(p => p.classList.remove("wz-active-group"));
    if (!guided) return;

    if (current.id === "brief") {
      const panel = document.querySelector("section.wizard-panel");
      if (panel) panel.classList.add("wz-active-group");
      return;
    }
    if (["matter", "cover", "write", "export"].includes(current.id)) {
      if (noteEl) {
        noteEl.textContent = stepNoteText(current.id);
        noteEl.style.display = "";
      }
      return;
    }
    if (current.id === "summary") {
      renderInlineSummary();
      if (sumEl) sumEl.style.display = "";
      return;
    }

    const list = STEP_GROUPS[current.id] || [];
    const first = list.map(fieldEl).find(Boolean);
    if (first) {
      const group = first.closest(".type-group");
      if (group) group.classList.add("wz-active-group");
    }
    const galleryId = galleryForStep(current.id);
    const gallery = galleryId && el(galleryId);
    if (gallery) gallery.classList.add("wz-active-gallery");
  }

  function recordApproval(stepId) {
    state.approvals[stepId] = {
      approved_at: new Date().toISOString(),
      selection: describeSelection(stepId)
    };
    state.updatedAt = new Date().toISOString();
    const snapshot = persistLocal();
    persistBridge(snapshot);
    applyStepLockUi();
    renderProgress();
    stepInfo();
    const status = safe(() => setStatus(`Motor olayı: sihirbaz adımı onaylandı (${stepId})`));
  }

  function unlockStep(stepId) {
    delete state.approvals[stepId];
    state.allApproved = false;
    state.updatedAt = new Date().toISOString();
    const snapshot = persistLocal();
    persistBridge(snapshot);
    lockControls(stepId, false);
    applyStepLockUi();
    renderProgress();
    stepInfo();
  }

  function selectGalleryCard(selectId, value) {
    const select = el(selectId);
    if (!select) return;
    select.value = String(value);
    resetApprovalOnChange(selectId);
    if (selectId === "layoutProfile" && typeof applyLayoutProfile === "function") {
      applyLayoutProfile(value);
    } else if (typeof applyTypography === "function") {
      applyTypography();
    }
    syncGallerySelection(selectId);
    if (typeof renderPreview === "function") renderPreview();
  }

  function syncGallerySelection(selectId) {
    const gallery = GALLERIES[selectId];
    if (!gallery) return;
    const container = el(gallery.containerId);
    if (!container) return;
    const currentValue = el(selectId)?.value;
    container.querySelectorAll("[data-wz-gallery-value]").forEach(card => {
      card.classList.toggle("selected", card.dataset.wzGalleryValue === currentValue);
    });
  }

  function buildGallery(selectId) {
    const gallery = GALLERIES[selectId];
    if (!gallery) return;
    const select = el(selectId);
    if (!select || !select.options) return;
    const host = select.closest("label.field") || select.parentElement;
    if (!host || host.querySelector(`[data-wz-gallery-container="${gallery.containerId}"]`)) return;
    const container = document.createElement("div");
    container.className = "wz-gallery";
    container.dataset.wzGalleryContainer = gallery.containerId;
    container.id = gallery.containerId;
    host.parentElement.insertBefore(container, host);
    [...select.options].forEach(option => {
      const value = option.value;
      if (!value) return;
      const card = document.createElement("button");
      card.type = "button";
      card.className = "wz-card";
      card.dataset.wzGalleryValue = value;
      card.dataset.wzGallery = selectId;
      const mini = document.createElement("span");
      mini.className = "wz-card-mini";
      const label = document.createElement("span");
      label.className = "wz-card-label";
      label.textContent = option.textContent.trim();
      if (selectId === "typeFont") {
        mini.innerHTML = `<span class="wz-a" style="font-family: '${value}', serif">Aa</span><span class="wz-ml"></span><span class="wz-ml" style="width:80%"></span><span class="wz-ml" style="width:66%"></span>`;
        const sub = document.createElement("span");
        sub.className = "wz-card-sub";
        sub.textContent = "Edebi metin";
        card.appendChild(mini);
        card.appendChild(label);
        card.appendChild(sub);
      } else {
        mini.innerHTML = `<span class="wz-ml wz-hl"></span><span class="wz-ml"></span><span class="wz-ml" style="width:82%"></span><span class="wz-ml" style="width:60%"></span><span class="wz-ml" style="width:74%"></span>`;
        const sub = document.createElement("span");
        sub.className = "wz-card-sub";
        const pageSize = el("pageSize")?.value || "";
        sub.textContent = selectId === "layoutProfile" ? (pageSize.replace(/\s*\(.*\)/, "") || "A5") : "Sayfa görünümü";
        card.appendChild(mini);
        card.appendChild(label);
        card.appendChild(sub);
      }
      card.addEventListener("click", () => selectGalleryCard(selectId, value));
      container.appendChild(card);
    });
    select.style.display = "none";
    syncGallerySelection(selectId);
  }

  function buildBar() {
    const typography = document.querySelector("section.typography");
    if (!typography) return;
    const bar = document.createElement("div");
    bar.id = "kithubWizardBar";
    bar.innerHTML = `
      <div class="wz-head">
        <span class="wz-title">Kitap Sihirbazı</span>
        <span class="wz-progress" id="wzProgress">0/${WIZARD_STEPS.length} onaylandı</span>
        <button type="button" id="wzPrev" class="ghost">← Önceki</button>
        <button type="button" id="wzApprove" class="primary">Adımı Onayla</button>
        <button type="button" id="wzNext" class="ghost">Sonraki →</button>
        <button type="button" id="wzRunFlow" class="primary" title="Tüm onaylar alındıysa plan, yazım ve çıktıyı tek akışta çalıştırır">Tek Akışta Yaz & Çıkar</button>
      </div>
      <div class="wz-steps" id="wzSteps"></div>
      <div class="wz-info" id="wzStepInfo">
        <span class="wz-desc" id="wzDesc"></span>
        <span id="wzSelection"></span>
        <button type="button" id="wzSummaryMini" class="ghost" title="Tüm adımların özetini gör">Toplu Onay</button>
      </div>
    `;
    typography.insertBefore(bar, typography.firstChild);

    el("wzPrev").addEventListener("click", () => { if (state.current > 0) { state.current -= 1; renderStep(); } });
    el("wzNext").addEventListener("click", () => { if (state.current < WIZARD_STEPS.length - 1) { state.current += 1; renderStep(); } });
    el("wzApprove").addEventListener("click", () => approveCurrent());
    el("wzSummaryMini").addEventListener("click", openSummaryDialog);
    el("wzRunFlow").addEventListener("click", () => runApprovedFlow());

    Object.keys(GALLERIES).forEach(buildGallery);
  }

  async function runApprovedFlow() {
    if (!state.allApproved) {
      setStatus("Motor olayı: tek akış için 13 adımın onayı tamamlanmalı (hızlı yol: Adımı Onayla × 13).");
      openSummaryDialog();
      return;
    }
    if (typeof getActiveMode !== "function") {
      setStatus("Motor olayı: mod algılanamadı; akış başlatılamadı.");
      return;
    }
    const mode = getActiveMode();
    const ranges = [
      { from: "intake", to: "design-big", label: "Plan" },
      { from: "design-small", to: "polish", label: "Yazım" },
      { from: "rewrite", to: "export", label: "Çıktı" }
    ];
    if (mode !== "API") {
      el("fromPhaseSelect").value = "intake";
      el("toPhaseSelect").value = "export";
      if (typeof copyPipelineCommand === "function") {
        await safe(() => copyPipelineCommand());
      }
      setStatus("Motor olayı: tek akış komutu kopyalandı (intake → export). IDE modundasınız — komutu IDE ajanınıza yapıştırın ve çalıştırın; dosyalar runtime/ altına yazılır.");
      return;
    }
    for (const range of ranges) {
      el("fromPhaseSelect").value = range.from;
      el("toPhaseSelect").value = range.to;
      setStatus(`Motor olayı: tek akış → ${range.label} (${range.from} → ${range.to}) çalışıyor...`);
      if (typeof copyPipelineCommand === "function") {
        await safe(() => copyPipelineCommand());
      }
    }
    if (typeof refreshProject === "function") {
      await safe(() => refreshProject());
    }
    setStatus("Motor olayı: tek akış tamamlandı — proje dosyaları yenilendi.");
  }

  function guardBriefComplete() {
    if (typeof validateWizard !== "function") return true;
    const result = validateWizard();
    if (result.complete) return true;
    if (typeof focusFirstMissingWizardField === "function") {
      focusFirstMissingWizardField([...result.missing, ...result.invalid]);
    }
    setStatus(`Motor olayı: künye eksik — ${[...result.missing, ...result.invalid].join(", ")}`);
    return false;
  }

  async function approveCurrent() {
    const current = WIZARD_STEPS[state.current];
    if (!current || isApproved(current.id)) return;
    if (current.id === "brief") {
      if (!guardBriefComplete()) return;
      if (typeof saveWizardRequest === "function") {
        const ok = await safe(() => saveWizardRequest());
        if (ok === false) {
          setStatus("Motor olayı: künye kaydedilemedi, onay kilitlendi.");
          return;
        }
      }
    }
    if (current.id === "matter") {
      if (typeof savePublicationStudioState === "function") {
        const saved = await safe(() => savePublicationStudioState());
        if (saved === false) {
          setStatus("Motor olayı: ön/arka sayfalar kaydedilmedi.");
          return;
        }
      }
    }
    if (current.id === "cover") {
      if (typeof savePublicationStudioState === "function") {
        const saved = await safe(() => savePublicationStudioState());
        if (saved === false) {
          setStatus("Motor olayı: kapak ayarları kaydedilmedi.");
          return;
        }
      }
    }
    if (current.id === "summary") {
      approveAll();
      return;
    }
    if (current.id === "write") {
      if (!state.allApproved) {
        setStatus("Motor olayı: yazım için önce Toplu Onay gerekli.");
        openSummaryDialog();
        return;
      }
      const btn = el("writeBookBtn");
      if (btn) {
        recordApproval("write");
        btn.click();
      }
      return;
    }
    if (current.id === "export") {
      if (!isApproved("write")) {
        setStatus("Motor olayı: çıktı için önce yazım adımının onaylanması gerekli.");
        return;
      }
      const btn = el("finalExportBtn");
      if (btn) {
        recordApproval("export");
        btn.click();
      }
      return;
    }
    recordApproval(current.id);
    if (typeof applyTypography === "function") applyTypography();
    if (typeof renderPreview === "function") renderPreview();
    if (state.current < WIZARD_STEPS.length - 1) {
      state.current += 1;
      renderStep();
    }
  }

  function approveAll() {
    WIZARD_STEPS.forEach(step => {
      if (!state.approvals[step.id]) {
        state.approvals[step.id] = {
          approved_at: new Date().toISOString(),
          selection: describeSelection(step.id)
        };
      }
    });
    state.allApproved = true;
    state.wizardCompletedAt = new Date().toISOString();
    const snapshot = persistLocal();
    persistBridge(snapshot);
    applyStepLockUi();
    renderProgress();
    stepInfo();
    setStatus("Motor olayı: tüm sihirbaz adımları onaylandı — yazım serbest.");
    const dialog = el("wzSummaryDialog");
    if (dialog?.open) dialog.close();
  }

  function buildSummaryDialog() {
    const existing = el("wzSummaryDialog");
    if (existing) return;
    const dialog = document.createElement("dialog");
    dialog.id = "wzSummaryDialog";
    dialog.innerHTML = `
      <form method="dialog">
        <header>
          <strong>Toplu Onay</strong>
          <div class="book-meta">Aşağıdaki seçimleri onaylamadan yazım başlamaz.</div>
        </header>
        <div class="wz-sum-list" id="wzSumList"></div>
        <div class="wz-locked-note" id="wzLockedNote"></div>
        <footer>
          <button type="button" id="wzSumApproveAll" class="primary">Hepsini Onayla</button>
          <button type="button" class="ghost" value="cancel">Vazgeç</button>
        </footer>
      </form>
    `;
    document.body.appendChild(dialog);
    el("wzSumApproveAll").addEventListener("click", approveAll);
  }

  function openSummaryDialog() {
    buildSummaryDialog();
    const list = el("wzSumList");
    list.innerHTML = "";
    WIZARD_STEPS.forEach(step => {
      const row = document.createElement("div");
      row.className = "wz-sum-item";
      const approved = isApproved(step.id);
      row.classList.add(approved ? "ok" : "pending");
      const title = document.createElement("span");
      title.textContent = step.title;
      const value = document.createElement("span");
      value.textContent = approved ? state.approvals[step.id].selection || describeSelection(step.id) : "Onay bekliyor";
      row.appendChild(title);
      row.appendChild(value);
      list.appendChild(row);
    });
    el("wzLockedNote").textContent = `Onaylı adım: ${WIZARD_STEPS.filter(step => isApproved(step.id)).length}/${WIZARD_STEPS.length}`;
    const dialog = el("wzSummaryDialog");
    if (typeof dialog.showModal === "function") dialog.showModal();
  }

  function markCoverApprovedOnSave() {
    const coverSave = el("saveCoverSpecBtn");
    if (coverSave && !coverSave.dataset.wzCoverHook) {
      coverSave.dataset.wzCoverHook = "1";
      coverSave.addEventListener("click", () => {
        if (WIZARD_STEPS.find(step => step.id === "cover")) recordApproval("cover");
      });
    }
    const matterSave = el("saveMatterPlanBtn");
    if (matterSave && !matterSave.dataset.wzMatterHook) {
      matterSave.dataset.wzMatterHook = "1";
      matterSave.addEventListener("click", () => {
        if (WIZARD_STEPS.find(step => step.id === "matter")) recordApproval("matter");
      });
    }
  }

  function coverImageInit() {
    const dialog = el("coverStudioDialog");
    if (!dialog) return;
    if (dialog.dataset.wzCoverInit) return;
    dialog.dataset.wzCoverInit = "1";

    const summary = el("coverSizeSummary");
    const box = document.createElement("div");
    box.id = "wzCoverImageBox";
    box.innerHTML = `
      <strong>Kapak Görseli</strong>
      <div class="wz-cover-note">Yüklenen veya üretilen görsel kapak paketine eklenir.</div>
      <img class="wz-cover-img" id="wzCoverImg" alt="" hidden />
      <div class="wz-cover-actions">
        <button type="button" class="ghost" id="wzCoverUploadBtn">Görsel Yükle</button>
        <button type="button" class="primary" id="wzCoverGenerateBtn">Konu İçin Görsel Üret</button>
        <button type="button" class="ghost" id="wzCoverStatus" disabled style="opacity:0.9"></button>
        <input type="file" id="wzCoverFile" accept=".png,.jpg,.jpeg,image/png,image/jpeg" class="hidden" hidden />
      </div>
    `;
    summary.insertAdjacentElement("afterend", box);

    const img = el("wzCoverImg");
    const status = el("wzCoverStatus");
    const fileInput = el("wzCoverFile");

    function projectRoot() {
      return (el("projectPathInput")?.value || "").trim();
    }

    function showBase64(base64) {
      if (!base64) { img.hidden = true; return; }
      img.src = "data:image/png;base64," + base64;
      img.hidden = false;
    }

    async function readAsset() {
      const root = projectRoot();
      if (!root || root === ".") return;
      const result = await safe(() => professionalApi("/api/cover-asset/read", { projectRoot: root }));
      if (result && result.ok) {
        showBase64(result.contentBase64);
        status.textContent = result.asset ? "Görsel yüklü" : "";
      }
    }

    function approveCoverStep() {
      if (WIZARD_STEPS.find(step => step.id === "cover")) {
        recordApproval("cover");
        if (state.current === 10) stepInfo();
      }
    }

    el("wzCoverUploadBtn").addEventListener("click", () => fileInput.click());
    fileInput.addEventListener("change", async () => {
      const file = fileInput.files && fileInput.files[0];
      if (!file) return;
      const root = projectRoot();
      if (!root || root === ".") { status.textContent = "Proje bağlanmamış."; return; }
      status.textContent = "Yükleniyor...";
      const reader = new FileReader();
      reader.onload = async () => {
        const base64 = String(reader.result).split(",")[1];
        const result = await safe(() => professionalApi("/api/cover-asset/upload", {
          projectRoot: root,
          filename: file.name,
          contentBase64: base64
        }));
        if (result && result.ok) {
          showBase64(base64);
          status.textContent = "Yüklendi ✓";
          approveCoverStep();
        } else {
          status.textContent = (result && result.error) ? result.error : "Yükleme başarısız.";
        }
      };
      reader.readAsDataURL(file);
    });

    el("wzCoverGenerateBtn").addEventListener("click", async () => {
      const root = projectRoot();
      if (!root || root === ".") { status.textContent = "Proje bağlanmamış."; return; }
      const mode = (typeof getActiveMode === "function") ? getActiveMode() : "IDE";
      if (mode !== "API") {
        status.textContent = "Görsel üretimi için API modunu aç (Ayarlar → API Modu).";
        return;
      }
      status.textContent = "Görsel üretiliyor (birkaç saniye sürebilir)...";
      const result = await safe(() => professionalApi("/api/cover-asset/generate", { projectRoot: root }));
      if (result && result.ok) {
        showBase64(result.contentBase64);
        status.textContent = "Üretildi ✓";
        approveCoverStep();
      } else {
        status.textContent = (result && result.error) ? result.error : "Üretim başarısız.";
      }
    });

    if (dialog.open) readAsset();
    const observer = new MutationObserver(() => {
      if (dialog.open) readAsset();
    });
    observer.observe(dialog, { attributes: true, attributeFilter: ["open"] });
  }

  const GUIDED_KEY = "kithub-guided-mode";
  let guidedOn = safe(() => JSON.parse(localStorage.getItem(GUIDED_KEY))) !== false;
  let guidedStage = 0;
  let guidedTimer = null;

  function guidedBound() {
    const v = (el("projectPathInput")?.value || "").trim();
    return !!v && v !== "." && !v.startsWith(".");
  }

  function guidedCurrentStage() {
    if (!guidedBound()) return 1;
    if (state.allApproved) return 3;
    return 2;
  }

  function guidedHint() {
    if (guidedStage === 1) return "Başlamak için bir kitap projesi oluşturun veya mevcut projeyi bağlayın.";
    if (guidedStage === 2) return "Kitap Sihirbazı ile adımları tek tek seçin; her adımda önizleme ortada canlı güncellenir, beğenince “Adımı Onayla” ile ilerleyin.";
    return "Toplu onay tamam. Yazımı ve çıktıyı tek akışta başlatın, paket masaüstüne gelecek.";
  }

  function syncGuidedPanel() {
    const typ = document.querySelector("section.typography");
    const agents = document.querySelector("aside.agents");
    const app = document.querySelector("main.app");
    if (!typ || !agents) return;
    if (guidedOn && typ.parentElement !== agents) {
      agents.insertBefore(typ, agents.firstChild);
    } else if (!guidedOn && typ.parentElement === agents) {
      if (app) app.appendChild(typ);
    }
  }

  function renderGuided() {
    const app = document.querySelector("main.app");
    if (app) {
      app.classList.toggle("guided", guidedOn);
      app.classList.toggle("stage-1", guidedOn && guidedStage === 1);
      app.classList.toggle("stage-2", guidedOn && guidedStage === 2);
      app.classList.toggle("stage-3", guidedOn && guidedStage === 3);
    }
    syncGuidedPanel();
    applyStepVisibility();
    const bar = el("wzGuidedBar");
    if (!bar) return;
    if (!guidedOn) {
      bar.style.display = "none";
      const start = el("wzStartPanel");
      const done = el("wzDonePanel");
      if (start) start.style.display = "none";
      if (done) done.style.display = "none";
      return;
    }
    bar.style.display = "";
    guidedStage = guidedCurrentStage();
    const chips = bar.querySelectorAll(".wzg-chip");
    chips.forEach(chip => {
      const s = parseInt(chip.dataset.wzgStage, 10);
      chip.classList.toggle("current", s === guidedStage);
      chip.classList.toggle("done", s < guidedStage);
    });
    const hint = el("wzGHint");
    if (hint) hint.textContent = guidedHint();
    const start = el("wzStartPanel");
    const done = el("wzDonePanel");
    if (start) start.style.display = guidedStage === 1 ? "" : "none";
    if (done) done.style.display = guidedStage === 3 ? "" : "none";

    if (guidedStage === 2) {
      if (document.body.classList.contains("type-collapsed") && typeof togglePanel === "function") {
        safe(() => togglePanel("type-collapsed", el("toggleType")));
      }
      const previewTab = document.querySelector('.workspace .tabs button[data-tab="preview"]');
      if (previewTab && !previewTab.classList.contains("active")) {
        safe(() => previewTab.click());
      }
    }
  }

  function tickGuided() {
    if (!guidedOn) return;
    const next = guidedCurrentStage();
    if (next !== guidedStage || !el("wzGuidedBar")) renderGuided();
  }

  async function desktopPackagePath(open) {
    const root = (el("projectPathInput")?.value || "").trim();
    if (!root || root === ".") return null;
    const result = await safe(() => professionalApi("/api/desktop-package/open", { projectRoot: root, open: !!open }));
    return (result && result.ok) ? result : null;
  }

  function resetApprovals() {
    state.approvals = {};
    state.allApproved = false;
    state.wizardCompletedAt = null;
    state.current = 0;
    state.updatedAt = new Date().toISOString();
    const snapshot = persistLocal();
    persistBridge(snapshot);
    applyStepLockUi();
    renderProgress();
    stepInfo();
    renderGuided();
    if (typeof refreshProject === "function") safe(() => refreshProject());
  }

  function guidedInit() {
    const app = document.querySelector("main.app");
    if (!app || el("wzGuidedBar")) return;

    const bar = document.createElement("div");
    bar.id = "wzGuidedBar";
    bar.innerHTML = `
      <span class="wzg-title">Rehberli Mod</span>
      <span class="wzg-chips">
        <span class="wzg-chip" data-wzg-stage="1">1 · Proje</span>
        <span class="wzg-chip" data-wzg-stage="2">2 · Kitap Tasarımı</span>
        <span class="wzg-chip" data-wzg-stage="3">3 · Yaz &amp; Çıkar</span>
      </span>
      <span class="wzg-hint" id="wzGHint"></span>
      <button type="button" class="wzg-toggle" id="wzGModeBtn">Gelişmiş Moda Geç</button>
    `;
    const topbar = app.querySelector("header.topbar");
    if (topbar) topbar.insertAdjacentElement("afterend", bar);

    const workspace = el("workspace");
    if (workspace) {
      const start = document.createElement("section");
      start.id = "wzStartPanel";
      start.innerHTML = `
        <div class="wz-start-card">
          <h2>KitHub Studio</h2>
          <p class="wz-start-lead">Kitabınızı adım adım hazırlayın: önce proje, sonra tasarım, sonra yazım ve çıktı.</p>
          <ol class="wz-start-steps">
            <li><b>Proje:</b> Yeni bir kitap projesi oluşturun veya mevcut projeyi bağlayın.</li>
            <li><b>Kitap Tasarımı:</b> 13 adımlık sihirbazla tür, sayfa boyutu, yazı tipi, kapak ve ön/arka sayfaları seçin; her adımı onaylayın.</li>
            <li><b>Yaz &amp; Çıkar:</b> Toplu onaylayın, tek akışta yazdırın; DOCX + PDF + kapak paketi masaüstüne gelir.</li>
          </ol>
          <div class="wz-start-actions">
            <button type="button" class="primary" id="wzStartNewBtn">Yeni Kitap Başlat</button>
            <button type="button" class="ghost" id="wzStartBindBtn">Mevcut Projeyi Bağla</button>
          </div>
          <p class="wz-start-status" id="wzStartStatus" role="status" aria-live="polite"></p>
        </div>
      `;
      workspace.prepend(start);

      const done = document.createElement("section");
      done.id = "wzDonePanel";
      done.style.display = "none";
      done.innerHTML = `
        <div class="wz-done-card">
          <h2>Kitap hazır!</h2>
          <p>Onaylar tamamlandı. Tek akışta yazım ve çıktıyı başlatabilirsiniz.</p>
          <p class="wz-done-path" id="wzDonePath">Paket: Masaüstü\\Kitap-Adı\\</p>
          <div class="wz-start-actions" style="margin-top: 14px;">
            <button type="button" class="primary" id="wzDoneRunBtn">Tek Akışta Yaz &amp; Çıkar</button>
            <button type="button" class="ghost" id="wzDoneOpenBtn">Paketi Aç</button>
            <button type="button" class="ghost" id="wzDoneResetBtn">Sıfırla (Yeni Akış)</button>
          </div>
        </div>
      `;
      start.insertAdjacentElement("afterend", done);

      const startStatus = el("wzStartStatus");
      const report = (ok, text) => {
        if (!startStatus) return;
        startStatus.textContent = text;
        startStatus.classList.toggle("wz-start-error", !ok);
      };

      el("wzStartNewBtn").addEventListener("click", async () => {
        if (startStatus) startStatus.textContent = "Proje oluşturuluyor...";
        if (typeof createProjectViaBridge !== "function") { report(false, "Motor bulunamadı; sayfayı yenileyin."); return; }
        const before = (el("projectPathInput")?.value || "").trim();
        await safe(() => createProjectViaBridge());
        const after = (el("projectPathInput")?.value || "").trim();
        if (after && after !== before) {
          report(true, "Proje oluşturuldu ✓ Sihirbaz açılıyor.");
          renderGuided();
        } else {
          report(false, "Proje oluşturulamadı. Studio Bridge kapalı olabilir — start_studio.ps1'i çalıştırın. Ayrıntı için alt durum çubuğuna bakın.");
        }
      });
      el("wzStartBindBtn").addEventListener("click", async () => {
        if (startStatus) startStatus.textContent = "Proje bağlanıyor...";
        if (typeof bindProject !== "function") { report(false, "Motor bulunamadı; sayfayı yenileyin."); return; }
        const before = (el("projectPathInput")?.value || "").trim();
        await safe(() => bindProject());
        const after = (el("projectPathInput")?.value || "").trim();
        if (after && after !== before) {
          report(true, "Proje bağlandı ✓ Sihirbaz açılıyor.");
          renderGuided();
        } else {
          report(false, "Proje bağlanamadı. Alt durum çubuğundaki mesajı kontrol edin.");
        }
      });
      el("wzDoneRunBtn").addEventListener("click", () => runApprovedFlow());
      el("wzDoneResetBtn").addEventListener("click", () => {
        if (window.confirm("Tüm onaylar sıfırlanıp yeni bir akışa başlansın mı?")) resetApprovals();
      });
      el("wzDoneOpenBtn").addEventListener("click", async () => {
        const result = await desktopPackagePath(true);
        if (!result) {
          setStatus && setStatus("Motor olayı: paket klasörü açılamadı (önce tek akışı çalıştırın).");
        }
      });
    }

    const toggle = el("wzGModeBtn");
    if (toggle) {
      toggle.addEventListener("click", () => {
        guidedOn = !guidedOn;
        localStorage.setItem(GUIDED_KEY, JSON.stringify(guidedOn));
        renderGuided();
      });
    }
  }

  async function refreshDonePath() {
    if (guidedStage !== 3) return;
    const pathEl = el("wzDonePath");
    if (!pathEl) return;
    const result = await desktopPackagePath(false);
    if (result && result.path) {
      pathEl.textContent = `Paket: ${result.path}${result.exists ? " (hazır)" : " (henüz üretilmedi)"}`;
    }
  }

  function initAdvancedMenus() {
    if (el("wzMotorMenu")) return;
    const actions = document.querySelector(".top-actions");
    if (!actions) return;
    const container = document.createElement("div");
    container.id = "wzAdvancedMenus";
    container.style.display = "flex";
    container.style.alignItems = "center";
    container.style.gap = "8px";
    container.innerHTML = `
      <details class="settings-menu" id="wzMotorMenu">
        <summary title="Motor" aria-label="Motor">⚡</summary>
        <div class="settings-panel">
          <h2>Motor</h2>
          <section class="settings-section">
            <label>Tek akış
              <button type="button" class="primary" id="wzMotorFlow">Tek Akışta Yaz &amp; Çıkar</button>
            </label>
            <span class="settings-note">Tüm adımlar onaylıysa plan → yazım → çıktıyı tek akışta çalıştırır.</span>
          </section>
          <section class="settings-section">
            <label>İçerik akışı
              <button type="button" id="wzMotorPipeline">İçerik Akışını Çalıştır</button>
            </label>
            <span class="settings-note">Seçili faz aralığını çalıştırır (komut/API uygun).</span>
          </section>
        </div>
      </details>
      <details class="settings-menu" id="wzPanelsMenu">
        <summary title="Paneller" aria-label="Paneller">▦</summary>
        <div class="settings-panel">
          <h2>Paneller</h2>
          <section class="settings-section">
            <label>Görünüm
              <div class="mode">
                <button type="button" id="wzPanelsNav">Kitap Haritası</button>
                <button type="button" id="wzPanelsAgents">AI ve Yayın</button>
                <button type="button" id="wzPanelsType">Dizgi Paneli</button>
                <button type="button" id="wzPanelsPhase">Faz Şeridi</button>
              </div>
            </label>
            <span class="settings-note">Butonlar paneli açıp kapatır; durum alt panelden izlenir.</span>
          </section>
        </div>
      </details>
      <details class="settings-menu" id="wzToolsMenu">
        <summary title="Araçlar" aria-label="Araçlar">✚</summary>
        <div class="settings-panel">
          <h2>Araçlar</h2>
          <section class="settings-section">
            <label>Yayın araçları
              <div class="mode">
                <button type="button" id="wzToolCover">Kapak Stüdyosu</button>
                <button type="button" id="wzToolMatter">Ön / Arka Sayfalar</button>
                <button type="button" id="wzToolPreflight">Yayın Öncesi Kontrol</button>
                <button type="button" id="wzToolBuild">PDF/EPUB Üret</button>
                <button type="button" id="wzToolExport">Final DOCX'i Kopyala</button>
                <button type="button" id="wzToolBackup">Projeyi Yedekle</button>
              </div>
            </label>
          </section>
        </div>
      </details>
    `;
    const exportBtn = el("exportBtn");
    actions.insertBefore(container, exportBtn || actions.firstChild);

    el("wzMotorFlow").addEventListener("click", () => runApprovedFlow());
    el("wzMotorPipeline").addEventListener("click", () => {
      if (typeof copyPipelineCommand === "function") safe(() => copyPipelineCommand());
    });
    el("wzPanelsNav").addEventListener("click", () => safe(() => togglePanel("nav-collapsed", el("sideCollapseBtn"))));
    el("wzPanelsAgents").addEventListener("click", () => safe(() => togglePanel("agents-collapsed", el("collapseAgents"))));
    el("wzPanelsType").addEventListener("click", () => safe(() => togglePanel("type-collapsed", el("toggleType"))));
    el("wzPanelsPhase").addEventListener("click", () => {
      const wrap = el("wzPhaseList");
      if (wrap) wrap.scrollIntoView({ behavior: "smooth", block: "nearest" });
    });
    el("wzToolCover").addEventListener("click", () => safe(() => el("openCoverStudioBtn")?.click()));
    el("wzToolMatter").addEventListener("click", () => safe(() => el("openMatterManagerBtn")?.click()));
    el("wzToolPreflight").addEventListener("click", () => safe(() => el("runPreflightBtn")?.click()));
    el("wzToolBuild").addEventListener("click", () => safe(() => el("buildPublicationBtn")?.click()));
    el("wzToolExport").addEventListener("click", () => safe(() => el("finalExportBtn")?.click()));
    el("wzToolBackup").addEventListener("click", () => safe(() => el("backupProjectBtn")?.click()));
  }

  function phaseListRender() {
    const wrap = el("wzPhaseList");
    if (!wrap) return;
    const agents = document.querySelectorAll("#agentList .agent");
    const short = ["Fikir", "Yön", "Karakter", "Plan", "Yazım", "Tutarlılık", "Türkçe", "Düzen", "Yayın"];
    wrap.replaceChildren();
    if (!agents.length) {
      const note = document.createElement("span");
      note.className = "book-meta";
      note.textContent = "fazlar beklemede";
      wrap.appendChild(note);
      return;
    }
    agents.forEach((ag, i) => {
      const cls = ag.className || "";
      const running = cls.includes("running") || cls.includes("review");
      const done = cls.includes("done");
      const node = document.createElement("div");
      node.className = "wz-ph-node" + (running ? " running" : (done ? " done" : ""));
      const title = safe(() => ag.querySelector("h3")?.textContent?.trim()) || "";
      const text = safe(() => ag.querySelector("p")?.textContent?.trim()) || "";
      const state = safe(() => ag.querySelector(".state")?.textContent?.trim()) || "Beklemede";
      const tip = `${title} — ${text} (${state})`;
      node.title = tip;
      const label = document.createElement("span");
      label.className = "wz-ph-label";
      label.textContent = short[i] || String(i + 1);
      label.title = tip;
      node.appendChild(label);
      wrap.appendChild(node);
    });
  }

  function syncPhaseList() {
    phaseListRender();
  }

  function phaseListInit() {
    if (el("wzPhaseList")) return;
    const crumbs = document.querySelector("header.topbar .crumbs");
    const controls = document.querySelector("header.topbar .chrome-controls");
    if (!crumbs || !controls) return;
    const wrap = document.createElement("div");
    wrap.id = "wzPhaseList";
    wrap.className = "wz-phase-list";
    controls.insertAdjacentElement("afterend", wrap);
    syncPhaseList();
  }

  function init() {
    injectStyles();
    readState();
    buildBar();
    markCoverApprovedOnSave();
    coverImageInit();
    guidedInit();
    phaseListInit();
    document.addEventListener("change", (ev) => {
      const id = ev.target && ev.target.id;
      if (id) resetApprovalOnChange(id);
    });
    loadBridge().then(() => {
      applyStepLockUi();
      renderProgress();
      stepInfo();
      renderGuided();
    });
    guidedTimer = setInterval(() => {
      tickGuided();
      refreshDonePath();
      syncPhaseList();
    }, 2500);
  }

  window.KitHubWizard = {
    steps: WIZARD_STEPS,
    getState: () => ({ ...state, approvals: { ...state.approvals } }),
    approveCurrent,
    openSummary: openSummaryDialog,
    persist: persistLocal,
    runFlow: runApprovedFlow
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
