var KitHubWizardBundle=(()=>{(()=>{"use strict";let O="kithub-wizard-state",m=[{id:"brief",title:"K\xFCnye",nav:"wizard",desc:"Kitap t\xFCr\xFC, hedef sayfa, okur, konu, karakterler, mek\xE2n, anlat\u0131c\u0131, final ve s\u0131n\u0131rlar\u0131 girin."},{id:"template",title:"\u015Eablon",nav:"page",desc:"Roman Klasik, Yay\u0131nevi A5, \u015Eiir vb. haz\u0131r kitap \u015Fablonlar\u0131ndan birini se\xE7in."},{id:"design",title:"Tasar\u0131m",nav:"page",desc:"Klasik \xC7er\xE7eve, Editoryal Minimal, Art Deco gibi sayfa tasar\u0131m\u0131n\u0131 se\xE7in."},{id:"size",title:"Boyut",nav:"page",desc:"Sayfa boyutu, \xF6zel \xF6l\xE7\xFC, bask\u0131 t\xFCr\xFC ve \xF6n b\xF6l\xFCm\xFC ayarlay\u0131n."},{id:"font",title:"Yaz\u0131",nav:"font",desc:"Yaz\u0131 tipi, punto ve sat\u0131r aral\u0131\u011F\u0131n\u0131 se\xE7in; \xF6n izlemede g\xF6r\xFCn."},{id:"ornament",title:"S\xFCsler",nav:"font",desc:"B\xF6l\xFCm s\xFCs\xFC, drop cap ve sahne aras\u0131 s\xFCsleri se\xE7in."},{id:"margin",title:"Kenar",nav:"margins",desc:"Kenar bo\u015Fluklar\u0131, paragraf girintisi ve dul/yetim korumas\u0131n\u0131 ayarlay\u0131n."},{id:"header",title:"Ba\u015Fl\u0131k/No",nav:"numbering",desc:"B\xF6l\xFCm ba\u015Flang\u0131c\u0131, \xFCstbilgi, sayfa numaras\u0131 ve i\xE7indekileri ayarlay\u0131n."},{id:"matter",title:"\xD6n/Arka",nav:"matter",desc:"Ba\u015Fl\u0131k sayfas\u0131, k\xFCnye, \xF6n s\xF6z ve arka sayfalar\u0131 d\xFCzenleyin."},{id:"cover",title:"Kapak",nav:"cover",desc:"Kapak st\xFCdyosunda \xF6n kapak, s\u0131rt ve arka kapa\u011F\u0131 haz\u0131rlay\u0131n."},{id:"summary",title:"Toplu Onay",nav:"summary",desc:"T\xFCm se\xE7imleri tek ekranda g\xF6r\xFCn ve hepsini onaylay\u0131n."},{id:"write",title:"Yaz\u0131m",nav:"write",desc:"Onayl\u0131 plana g\xF6re kitap b\xF6l\xFCmlerini yaz\u0131n (IDE veya API)."},{id:"export",title:"\xC7\u0131kt\u0131",nav:"export",desc:"DOCX, PDF, kapak ve EPUB'\u0131 tek paket olarak masa\xFCst\xFCne aktar\u0131n."}],A={template:["layoutProfile","pageDesign","pageSize","customSizeWidth","customSizeHeight","printMode","frontMatter"],design:["pageDesign"],size:["pageSize","customSizeWidth","customSizeHeight","printMode","frontMatter"],font:["typeFont","typeSize","lineHeight","lineHeightPreset"],ornament:["ornamentStyle","dropCapStyle","dropCapRunIn","dropCapTint","sceneBreakStyle","sceneBreakSize"],margin:["marginTop","marginInside","marginOutside","indent","after","widowOrphanControl"],header:["chapterStartPolicy","headingHierarchyPolicy","runningHeaderPolicy","pageNumberPosition","tocDepth","frontMatterNumbering"],brief:["wizardType","wizardPages","wizardReader","wizardCharacters","wizardNarrator","wizardPremise","wizardSetting","wizardEnding","wizardStyle","wizardBoundaries"]},j={layoutProfile:{containerId:"wzGalleryTemplate",label:"Kitap \u015Eablonu"},pageDesign:{containerId:"wzGalleryDesign",label:"Sayfa Tasar\u0131m\u0131"},typeFont:{containerId:"wzGalleryFont",label:"Yaz\u0131 Tipi"}},i={current:0,approvals:{},allApproved:!1,wizardCompletedAt:null,updatedAt:null,bridgeOnline:!1};function n(e){return document.getElementById(e)}function p(e){try{return e()}catch{return null}}function U(){let e=`
      #kithubWizardBar { border-bottom: 1px solid var(--line-soft); padding: 8px 10px; background: var(--panel); color: var(--text); }
      #kithubWizardBar .wz-head { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; }
      #kithubWizardBar .wz-title { font-weight: 700; font-size: 13px; }
      #kithubWizardBar .wz-progress { font-size: 11px; opacity: 0.8; margin-right: auto; }
      #kithubWizardBar button { font-size: 11px; padding: 3px 8px; }
      #kithubWizardBar .wz-steps { display: flex; flex-wrap: wrap; gap: 3px; margin-top: 6px; }
      #kithubWizardBar .wz-step { border: 1px solid var(--line); background: var(--panel-2); color: var(--muted); border-radius: 999px; padding: 1px 7px; font-size: 10px; cursor: pointer; }
      #kithubWizardBar .wz-step.current { border-color: var(--teal-deep); background: var(--teal-deep); color: #fff; }
      #kithubWizardBar .wz-step.approved { border-color: var(--green); background: rgba(104, 196, 134, 0.14); color: var(--green); }
      #kithubWizardBar .wz-step.approved::after { content: " \u2713"; }
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
      #wzSummaryDialog .wz-sum-item.ok::before { content: "\u2713 "; color: var(--green); font-weight: 700; }
      #wzSummaryDialog .wz-sum-item.pending::before { content: "\u25CB "; color: var(--amber); font-weight: 700; }
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
    `,t=document.createElement("style");t.textContent=e,document.head.appendChild(t)}function V(){let e=p(()=>JSON.parse(localStorage.getItem(O)));e&&e.approvals&&(i.approvals=e.approvals,i.allApproved=!!e.allApproved,i.wizardCompletedAt=e.wizardCompletedAt||null)}function E(){let e={schema_version:"1.0.0",mode:p(()=>getActiveMode())||"ide",approvals:i.approvals,all_approved:i.allApproved,wizard_completed_at:i.wizardCompletedAt,updated_at:new Date().toISOString()};return p(()=>localStorage.setItem(O,JSON.stringify(e))),e}async function L(e){let t=(n("projectPathInput")?.value||"").trim();if(!t||t===".")return;let a=await p(()=>professionalApi("/api/wizard-state/save",{projectRoot:t,state:e}));a&&a.ok&&(i.bridgeOnline=!0)}async function X(){let e=(n("projectPathInput")?.value||"").trim();if(!e||e===".")return;let t=await p(()=>professionalApi("/api/wizard-state/read",{projectRoot:e}));t&&t.ok&&t.state&&t.state.approvals&&(i.approvals=t.state.approvals,i.allApproved=!!t.state.all_approved,i.wizardCompletedAt=t.state.wizard_completed_at||null,i.bridgeOnline=!0)}function G(e){return(A[e]||[]).map(t=>n(t)).filter(Boolean)}function v(e){return!!i.approvals[e]&&i.approvals[e].approved_at}function J(e,t){G(e).forEach(a=>{a.disabled=t})}function k(){m.forEach(e=>{G(e.id).forEach(t=>{t.disabled=!1})}),document.querySelectorAll(".wz-gallery").forEach(e=>{e.classList.remove("wz-locked")})}function x(){let e=m.filter(o=>v(o.id)).length,t=n("wzProgress");t&&(t.textContent=`${e}/${m.length} onayland\u0131`);let a=n("wzSteps");a&&(a.innerHTML="",m.forEach((o,l)=>{let s=document.createElement("button");s.type="button",s.className="wz-step",s.dataset.stepIndex=String(l),s.textContent=`${l+1}. ${o.title}`,l===i.current&&s.classList.add("current"),v(o.id)&&s.classList.add("approved"),s.title=o.desc,s.addEventListener("click",()=>{i.current=l,M()}),a.appendChild(s)}));let r=n("wzApprove");if(r){let o=m[i.current],l=o?v(o.id):!1;r.disabled=l,r.textContent=l?"Onayland\u0131 \u2713":"Ad\u0131m\u0131 Onayla"}}function S(e){let t={};(A[e]||[]).forEach(r=>{t[r]=n(r)?.value??""});let a=r=>t[r];switch(e){case"brief":{let r=(document.querySelector(".book-title")?.textContent||"").trim();return`T\xFCr: ${a("wizardType")||"-"} \xB7 Hedef: ${a("wizardPages")||"-"} sayfa \xB7 Okur: ${a("wizardReader")||"-"}`}case"template":return`\u015Eablon: ${a("layoutProfile")||"-"}`;case"design":return`Tasar\u0131m: ${a("pageDesign")||"-"}`;case"size":return`Boyut: ${a("pageSize")||"-"} \xB7 ${a("printMode")||"-"} \xB7 ${a("frontMatter")||"-"}`;case"font":return`Yaz\u0131: ${a("typeFont")||"-"} ${a("typeSize")||"-"} pt \xB7 Sat\u0131r: ${a("lineHeight")||"-"}`;case"ornament":return`S\xFCs: ${a("ornamentStyle")||"-"} \xB7 Drop cap: ${a("dropCapStyle")||"-"} \xB7 Sahne: ${a("sceneBreakStyle")||"-"}`;case"margin":return`\xDCst/\u0130\xE7/D\u0131\u015F: ${a("marginTop")||"-"}/${a("marginInside")||"-"}/${a("marginOutside")||"-"} \xB7 Girinti: ${a("indent")||"-"}`;case"header":return`Sayfa no: ${a("pageNumberPosition")||"-"} \xB7 \xDCstbilgi: ${a("runningHeaderPolicy")||"-"} \xB7 \u0130\xE7indekiler: ${a("tocDepth")||"-"}`;case"matter":return"\xD6n/arka sayfalar kapak st\xFCdyosu \xFCzerinden kaydedilir.";case"cover":return"Kapak st\xFCdyosu ayarlar\u0131 kaydedilir.";case"summary":return"T\xFCm ad\u0131mlar\u0131n toplu onay\u0131.";case"write":return"Yaz\u0131m IDE/API modunda ilerler.";case"export":return"Tek paket masa\xFCst\xFCne aktar\u0131l\u0131r.";default:return""}}function h(){let e=m[i.current];if(!n("wzStepInfo"))return;let a=n("wzDesc");a&&(a.textContent=e.desc);let r=n("wzSelection");r&&(r.textContent=v(e.id)?`Onayl\u0131: ${S(e.id)}`:`Se\xE7im: ${S(e.id)}`)}function M(){let e=m[i.current];if(e){if(e.nav!=="wizard"&&typeof focusTypeSection=="function"&&p(()=>focusTypeSection(e.nav)),e.nav==="matter"){let t=n("openMatterManagerBtn");t&&t.click()}if(e.nav==="cover"){let t=n("openCoverStudioBtn");t&&t.click()}h(),x(),k(),N()}}function Z(e){for(let[t,a]of Object.entries(A))if(a.includes(e))return t;return null}function $(e){let t=Z(e);!t||!v(t)||(re(t),p(()=>setStatus(`Motor olay\u0131: ${t} se\xE7imi de\u011Fi\u015Fti \u2014 onay yeniden al\u0131nmal\u0131.`)))}function Q(e){let t=n(e);return t?t.closest("label.field")||t.parentElement:null}function ee(e){return e==="template"?"wzGalleryTemplate":e==="design"?"wzGalleryDesign":e==="font"?"wzGalleryFont":null}function te(e){return e==="matter"?"\xD6n / arka sayfalar d\xFCzenleniyor \u2014 d\xFCzenleme ekran\u0131 a\xE7\u0131ld\u0131. Bitince \u201CKitap Par\xE7alar\u0131n\u0131 Kaydet\u201De bas\u0131n; ad\u0131m otomatik onaylan\u0131r.":e==="cover"?"Kapak st\xFCdyosu a\xE7\u0131ld\u0131. Kapak ayarlar\u0131n\u0131 yap\u0131p \u201CKapak Ayarlar\u0131n\u0131 Kaydet\u201De bas\u0131n (veya g\xF6rsel y\xFCkleyin/\xFCretin); ad\u0131m otomatik onaylan\u0131r.":e==="write"?"Yaz\u0131m ad\u0131m\u0131. T\xFCm onaylar al\u0131nd\u0131ysa \u201CAd\u0131m\u0131 Onayla\u201D yaz\u0131m\u0131 ba\u015Flat\u0131r (IDE: komutu kopyalar, API: fazlar\u0131 \xE7al\u0131\u015Ft\u0131r\u0131r).":e==="export"?"\xC7\u0131kt\u0131 ad\u0131m\u0131. Yaz\u0131m onayland\u0131ysa \u201CAd\u0131m\u0131 Onayla\u201D final DOCX ve paketi masa\xFCst\xFCne \xFCretir.":""}function ae(){let e=n("wzStepSummary"),t=document.querySelector("section.typography .type-body");if(!e&&t&&(e=document.createElement("div"),e.id="wzStepSummary",e.className="wz-sum-list",t.appendChild(e)),!e)return;e.replaceChildren(),m.forEach(o=>{let l=v(o.id),s=document.createElement("div");s.className="wz-sum-item "+(l?"ok":"pending");let d=document.createElement("span");d.textContent=`${o.title}`;let u=document.createElement("span");u.textContent=l?i.approvals[o.id].selection||S(o.id):"Onay bekliyor",s.appendChild(d),s.appendChild(u),e.appendChild(s)});let a=document.createElement("div");a.className="wz-sum-foot";let r=document.createElement("button");r.type="button",r.className="primary",r.textContent="Hepsini Onayla",r.addEventListener("click",I),a.appendChild(r),e.appendChild(a)}function ne(){let e=document.querySelector("section.typography .type-body");if(!e)return null;let t=document.createElement("div");return t.id="wzStepNote",t.className="wz-step-note",e.appendChild(t),t}function N(){let e=document.querySelector("main.app"),t=e&&e.classList.contains("guided"),a=m[i.current],r=document.querySelector("section.typography .type-body");if(!r||!a)return;let o=n("wzStepNote")||ne(),l=n("wzStepSummary");if(o&&(o.style.display="none"),l&&(l.style.display="none"),r.querySelectorAll(".type-group").forEach(c=>c.classList.remove("wz-active-group")),r.querySelectorAll(".wz-gallery").forEach(c=>c.classList.remove("wz-active-gallery")),document.querySelectorAll("section.wizard-panel").forEach(c=>c.classList.remove("wz-active-group")),!t)return;if(a.id==="brief"){let c=document.querySelector("section.wizard-panel");c&&c.classList.add("wz-active-group");return}if(["matter","cover","write","export"].includes(a.id)){o&&(o.textContent=te(a.id),o.style.display="");return}if(a.id==="summary"){ae(),l&&(l.style.display="");return}let d=(A[a.id]||[]).map(Q).find(Boolean);if(d){let c=d.closest(".type-group");c&&c.classList.add("wz-active-group")}let u=ee(a.id),y=u&&n(u);y&&y.classList.add("wz-active-gallery")}function P(e){i.approvals[e]={approved_at:new Date().toISOString(),selection:S(e)},i.updatedAt=new Date().toISOString();let t=E();L(t),k(),x(),h();let a=p(()=>setStatus(`Motor olay\u0131: sihirbaz ad\u0131m\u0131 onayland\u0131 (${e})`))}function re(e){delete i.approvals[e],i.allApproved=!1,i.updatedAt=new Date().toISOString();let t=E();L(t),J(e,!1),k(),x(),h()}function oe(e,t){let a=n(e);a&&(a.value=String(t),$(e),e==="layoutProfile"&&typeof applyLayoutProfile=="function"?applyLayoutProfile(t):typeof applyTypography=="function"&&applyTypography(),K(e),typeof renderPreview=="function"&&renderPreview())}function K(e){let t=j[e];if(!t)return;let a=n(t.containerId);if(!a)return;let r=n(e)?.value;a.querySelectorAll("[data-wz-gallery-value]").forEach(o=>{o.classList.toggle("selected",o.dataset.wzGalleryValue===r)})}function ie(e){let t=j[e];if(!t)return;let a=n(e);if(!a||!a.options)return;let r=a.closest("label.field")||a.parentElement;if(!r||r.querySelector(`[data-wz-gallery-container="${t.containerId}"]`))return;let o=document.createElement("div");o.className="wz-gallery",o.dataset.wzGalleryContainer=t.containerId,o.id=t.containerId,r.parentElement.insertBefore(o,r),[...a.options].forEach(l=>{let s=l.value;if(!s)return;let d=document.createElement("button");d.type="button",d.className="wz-card",d.dataset.wzGalleryValue=s,d.dataset.wzGallery=e;let u=document.createElement("span");u.className="wz-card-mini";let y=document.createElement("span");if(y.className="wz-card-label",y.textContent=l.textContent.trim(),e==="typeFont"){u.innerHTML=`<span class="wz-a" style="font-family: '${s}', serif">Aa</span><span class="wz-ml"></span><span class="wz-ml" style="width:80%"></span><span class="wz-ml" style="width:66%"></span>`;let c=document.createElement("span");c.className="wz-card-sub",c.textContent="Edebi metin",d.appendChild(u),d.appendChild(y),d.appendChild(c)}else{u.innerHTML='<span class="wz-ml wz-hl"></span><span class="wz-ml"></span><span class="wz-ml" style="width:82%"></span><span class="wz-ml" style="width:60%"></span><span class="wz-ml" style="width:74%"></span>';let c=document.createElement("span");c.className="wz-card-sub";let f=n("pageSize")?.value||"";c.textContent=e==="layoutProfile"?f.replace(/\s*\(.*\)/,"")||"A5":"Sayfa g\xF6r\xFCn\xFCm\xFC",d.appendChild(u),d.appendChild(y),d.appendChild(c)}d.addEventListener("click",()=>oe(e,s)),o.appendChild(d)}),a.style.display="none",K(e)}function se(){let e=document.querySelector("section.typography");if(!e)return;let t=document.createElement("div");t.id="kithubWizardBar",t.innerHTML=`
      <div class="wz-head">
        <span class="wz-title">Kitap Sihirbaz\u0131</span>
        <span class="wz-progress" id="wzProgress">0/${m.length} onayland\u0131</span>
        <button type="button" id="wzPrev" class="ghost">\u2190 \xD6nceki</button>
        <button type="button" id="wzApprove" class="primary">Ad\u0131m\u0131 Onayla</button>
        <button type="button" id="wzNext" class="ghost">Sonraki \u2192</button>
        <button type="button" id="wzRunFlow" class="primary" title="T\xFCm onaylar al\u0131nd\u0131ysa plan, yaz\u0131m ve \xE7\u0131kt\u0131y\u0131 tek ak\u0131\u015Fta \xE7al\u0131\u015Ft\u0131r\u0131r">Tek Ak\u0131\u015Fta Yaz & \xC7\u0131kar</button>
      </div>
      <div class="wz-steps" id="wzSteps"></div>
      <div class="wz-info" id="wzStepInfo">
        <span class="wz-desc" id="wzDesc"></span>
        <span id="wzSelection"></span>
        <button type="button" id="wzSummaryMini" class="ghost" title="T\xFCm ad\u0131mlar\u0131n \xF6zetini g\xF6r">Toplu Onay</button>
      </div>
    `,e.insertBefore(t,e.firstChild),n("wzPrev").addEventListener("click",()=>{i.current>0&&(i.current-=1,M())}),n("wzNext").addEventListener("click",()=>{i.current<m.length-1&&(i.current+=1,M())}),n("wzApprove").addEventListener("click",()=>Y()),n("wzSummaryMini").addEventListener("click",D),n("wzRunFlow").addEventListener("click",()=>T()),Object.keys(j).forEach(ie)}async function T(){if(!i.allApproved){setStatus("Motor olay\u0131: tek ak\u0131\u015F i\xE7in 13 ad\u0131m\u0131n onay\u0131 tamamlanmal\u0131 (h\u0131zl\u0131 yol: Ad\u0131m\u0131 Onayla \xD7 13)."),D();return}if(typeof getActiveMode!="function"){setStatus("Motor olay\u0131: mod alg\u0131lanamad\u0131; ak\u0131\u015F ba\u015Flat\u0131lamad\u0131.");return}let e=getActiveMode(),t=[{from:"intake",to:"design-big",label:"Plan"},{from:"design-small",to:"polish",label:"Yaz\u0131m"},{from:"rewrite",to:"export",label:"\xC7\u0131kt\u0131"}];if(e!=="API"){n("fromPhaseSelect").value="intake",n("toPhaseSelect").value="export",typeof copyPipelineCommand=="function"&&await p(()=>copyPipelineCommand()),setStatus("Motor olay\u0131: tek ak\u0131\u015F komutu kopyaland\u0131 (intake \u2192 export). IDE modundas\u0131n\u0131z \u2014 komutu IDE ajan\u0131n\u0131za yap\u0131\u015Ft\u0131r\u0131n ve \xE7al\u0131\u015Ft\u0131r\u0131n; dosyalar runtime/ alt\u0131na yaz\u0131l\u0131r.");return}for(let a of t)n("fromPhaseSelect").value=a.from,n("toPhaseSelect").value=a.to,setStatus(`Motor olay\u0131: tek ak\u0131\u015F \u2192 ${a.label} (${a.from} \u2192 ${a.to}) \xE7al\u0131\u015F\u0131yor...`),typeof copyPipelineCommand=="function"&&await p(()=>copyPipelineCommand());typeof refreshProject=="function"&&await p(()=>refreshProject()),setStatus("Motor olay\u0131: tek ak\u0131\u015F tamamland\u0131 \u2014 proje dosyalar\u0131 yenilendi.")}function le(){if(typeof validateWizard!="function")return!0;let e=validateWizard();return e.complete?!0:(typeof focusFirstMissingWizardField=="function"&&focusFirstMissingWizardField([...e.missing,...e.invalid]),setStatus(`Motor olay\u0131: k\xFCnye eksik \u2014 ${[...e.missing,...e.invalid].join(", ")}`),!1)}async function Y(){let e=m[i.current];if(!(!e||v(e.id))){if(e.id==="brief"){if(!le())return;if(typeof saveWizardRequest=="function"&&await p(()=>saveWizardRequest())===!1){setStatus("Motor olay\u0131: k\xFCnye kaydedilemedi, onay kilitlendi.");return}}if(e.id==="matter"&&typeof savePublicationStudioState=="function"&&await p(()=>savePublicationStudioState())===!1){setStatus("Motor olay\u0131: \xF6n/arka sayfalar kaydedilmedi.");return}if(e.id==="cover"&&typeof savePublicationStudioState=="function"&&await p(()=>savePublicationStudioState())===!1){setStatus("Motor olay\u0131: kapak ayarlar\u0131 kaydedilmedi.");return}if(e.id==="summary"){I();return}if(e.id==="write"){if(!i.allApproved){setStatus("Motor olay\u0131: yaz\u0131m i\xE7in \xF6nce Toplu Onay gerekli."),D();return}let t=n("writeBookBtn");t&&(P("write"),t.click());return}if(e.id==="export"){if(!v("write")){setStatus("Motor olay\u0131: \xE7\u0131kt\u0131 i\xE7in \xF6nce yaz\u0131m ad\u0131m\u0131n\u0131n onaylanmas\u0131 gerekli.");return}let t=n("finalExportBtn");t&&(P("export"),t.click());return}P(e.id),typeof applyTypography=="function"&&applyTypography(),typeof renderPreview=="function"&&renderPreview(),i.current<m.length-1&&(i.current+=1,M())}}function I(){m.forEach(a=>{i.approvals[a.id]||(i.approvals[a.id]={approved_at:new Date().toISOString(),selection:S(a.id)})}),i.allApproved=!0,i.wizardCompletedAt=new Date().toISOString();let e=E();L(e),k(),x(),h(),setStatus("Motor olay\u0131: t\xFCm sihirbaz ad\u0131mlar\u0131 onayland\u0131 \u2014 yaz\u0131m serbest.");let t=n("wzSummaryDialog");t?.open&&t.close()}function de(){if(n("wzSummaryDialog"))return;let t=document.createElement("dialog");t.id="wzSummaryDialog",t.innerHTML=`
      <form method="dialog">
        <header>
          <strong>Toplu Onay</strong>
          <div class="book-meta">A\u015Fa\u011F\u0131daki se\xE7imleri onaylamadan yaz\u0131m ba\u015Flamaz.</div>
        </header>
        <div class="wz-sum-list" id="wzSumList"></div>
        <div class="wz-locked-note" id="wzLockedNote"></div>
        <footer>
          <button type="button" id="wzSumApproveAll" class="primary">Hepsini Onayla</button>
          <button type="button" class="ghost" value="cancel">Vazge\xE7</button>
        </footer>
      </form>
    `,document.body.appendChild(t),n("wzSumApproveAll").addEventListener("click",I)}function D(){de();let e=n("wzSumList");e.innerHTML="",m.forEach(a=>{let r=document.createElement("div");r.className="wz-sum-item";let o=v(a.id);r.classList.add(o?"ok":"pending");let l=document.createElement("span");l.textContent=a.title;let s=document.createElement("span");s.textContent=o?i.approvals[a.id].selection||S(a.id):"Onay bekliyor",r.appendChild(l),r.appendChild(s),e.appendChild(r)}),n("wzLockedNote").textContent=`Onayl\u0131 ad\u0131m: ${m.filter(a=>v(a.id)).length}/${m.length}`;let t=n("wzSummaryDialog");typeof t.showModal=="function"&&t.showModal()}function pe(){let e=n("saveCoverSpecBtn");e&&!e.dataset.wzCoverHook&&(e.dataset.wzCoverHook="1",e.addEventListener("click",()=>{m.find(a=>a.id==="cover")&&P("cover")}));let t=n("saveMatterPlanBtn");t&&!t.dataset.wzMatterHook&&(t.dataset.wzMatterHook="1",t.addEventListener("click",()=>{m.find(a=>a.id==="matter")&&P("matter")}))}function ce(){let e=n("coverStudioDialog");if(!e||e.dataset.wzCoverInit)return;e.dataset.wzCoverInit="1";let t=n("coverSizeSummary"),a=document.createElement("div");a.id="wzCoverImageBox",a.innerHTML=`
      <strong>Kapak G\xF6rseli</strong>
      <div class="wz-cover-note">Y\xFCklenen veya \xFCretilen g\xF6rsel kapak paketine eklenir.</div>
      <img class="wz-cover-img" id="wzCoverImg" alt="" hidden />
      <div class="wz-cover-actions">
        <button type="button" class="ghost" id="wzCoverUploadBtn">G\xF6rsel Y\xFCkle</button>
        <button type="button" class="primary" id="wzCoverGenerateBtn">Konu \u0130\xE7in G\xF6rsel \xDCret</button>
        <button type="button" class="ghost" id="wzCoverStatus" disabled style="opacity:0.9"></button>
        <input type="file" id="wzCoverFile" accept=".png,.jpg,.jpeg,image/png,image/jpeg" class="hidden" hidden />
      </div>
    `,t.insertAdjacentElement("afterend",a);let r=n("wzCoverImg"),o=n("wzCoverStatus"),l=n("wzCoverFile");function s(){return(n("projectPathInput")?.value||"").trim()}function d(f){if(!f){r.hidden=!0;return}r.src="data:image/png;base64,"+f,r.hidden=!1}async function u(){let f=s();if(!f||f===".")return;let w=await p(()=>professionalApi("/api/cover-asset/read",{projectRoot:f}));w&&w.ok&&(d(w.contentBase64),o.textContent=w.asset?"G\xF6rsel y\xFCkl\xFC":"")}function y(){m.find(f=>f.id==="cover")&&(P("cover"),i.current===10&&h())}n("wzCoverUploadBtn").addEventListener("click",()=>l.click()),l.addEventListener("change",async()=>{let f=l.files&&l.files[0];if(!f)return;let w=s();if(!w||w==="."){o.textContent="Proje ba\u011Flanmam\u0131\u015F.";return}o.textContent="Y\xFCkleniyor...";let g=new FileReader;g.onload=async()=>{let _=String(g.result).split(",")[1],B=await p(()=>professionalApi("/api/cover-asset/upload",{projectRoot:w,filename:f.name,contentBase64:_}));B&&B.ok?(d(_),o.textContent="Y\xFCklendi \u2713",y()):o.textContent=B&&B.error?B.error:"Y\xFCkleme ba\u015Far\u0131s\u0131z."},g.readAsDataURL(f)}),n("wzCoverGenerateBtn").addEventListener("click",async()=>{let f=s();if(!f||f==="."){o.textContent="Proje ba\u011Flanmam\u0131\u015F.";return}if((typeof getActiveMode=="function"?getActiveMode():"IDE")!=="API"){o.textContent="G\xF6rsel \xFCretimi i\xE7in API modunu a\xE7 (Ayarlar \u2192 API Modu).";return}o.textContent="G\xF6rsel \xFCretiliyor (birka\xE7 saniye s\xFCrebilir)...";let g=await p(()=>professionalApi("/api/cover-asset/generate",{projectRoot:f}));g&&g.ok?(d(g.contentBase64),o.textContent="\xDCretildi \u2713",y()):o.textContent=g&&g.error?g.error:"\xDCretim ba\u015Far\u0131s\u0131z."}),e.open&&u(),new MutationObserver(()=>{e.open&&u()}).observe(e,{attributes:!0,attributeFilter:["open"]})}let H="kithub-guided-mode",b=p(()=>JSON.parse(localStorage.getItem(H)))!==!1,z=0,ue=null;function me(){let e=(n("projectPathInput")?.value||"").trim();return!!e&&e!=="."&&!e.startsWith(".")}function q(){return me()?i.allApproved?3:2:1}function fe(){return z===1?"Ba\u015Flamak i\xE7in bir kitap projesi olu\u015Fturun veya mevcut projeyi ba\u011Flay\u0131n.":z===2?"Kitap Sihirbaz\u0131 ile ad\u0131mlar\u0131 tek tek se\xE7in; her ad\u0131mda \xF6nizleme ortada canl\u0131 g\xFCncellenir, be\u011Fenince \u201CAd\u0131m\u0131 Onayla\u201D ile ilerleyin.":"Toplu onay tamam. Yaz\u0131m\u0131 ve \xE7\u0131kt\u0131y\u0131 tek ak\u0131\u015Fta ba\u015Flat\u0131n, paket masa\xFCst\xFCne gelecek."}function ye(){let e=document.querySelector("section.typography"),t=document.querySelector("aside.agents"),a=document.querySelector("main.app");!e||!t||(b&&e.parentElement!==t?t.insertBefore(e,t.firstChild):!b&&e.parentElement===t&&a&&a.appendChild(e))}function C(){let e=document.querySelector("main.app");e&&(e.classList.toggle("guided",b),e.classList.toggle("stage-1",b&&z===1),e.classList.toggle("stage-2",b&&z===2),e.classList.toggle("stage-3",b&&z===3)),ye(),N();let t=n("wzGuidedBar");if(!t)return;if(!b){t.style.display="none";let s=n("wzStartPanel"),d=n("wzDonePanel");s&&(s.style.display="none"),d&&(d.style.display="none");return}t.style.display="",z=q(),t.querySelectorAll(".wzg-chip").forEach(s=>{let d=parseInt(s.dataset.wzgStage,10);s.classList.toggle("current",d===z),s.classList.toggle("done",d<z)});let r=n("wzGHint");r&&(r.textContent=fe());let o=n("wzStartPanel"),l=n("wzDonePanel");if(o&&(o.style.display=z===1?"":"none"),l&&(l.style.display=z===3?"":"none"),z===2){document.body.classList.contains("type-collapsed")&&typeof togglePanel=="function"&&p(()=>togglePanel("type-collapsed",n("toggleType")));let s=document.querySelector('.workspace .tabs button[data-tab="preview"]');s&&!s.classList.contains("active")&&p(()=>s.click())}}function ge(){if(!b)return;(q()!==z||!n("wzGuidedBar"))&&C()}async function F(e){let t=(n("projectPathInput")?.value||"").trim();if(!t||t===".")return null;let a=await p(()=>professionalApi("/api/desktop-package/open",{projectRoot:t,open:!!e}));return a&&a.ok?a:null}function ze(){i.approvals={},i.allApproved=!1,i.wizardCompletedAt=null,i.current=0,i.updatedAt=new Date().toISOString();let e=E();L(e),k(),x(),h(),C(),typeof refreshProject=="function"&&p(()=>refreshProject())}function we(){let e=document.querySelector("main.app");if(!e||n("wzGuidedBar"))return;let t=document.createElement("div");t.id="wzGuidedBar",t.innerHTML=`
      <span class="wzg-title">Rehberli Mod</span>
      <span class="wzg-chips">
        <span class="wzg-chip" data-wzg-stage="1">1 \xB7 Proje</span>
        <span class="wzg-chip" data-wzg-stage="2">2 \xB7 Kitap Tasar\u0131m\u0131</span>
        <span class="wzg-chip" data-wzg-stage="3">3 \xB7 Yaz &amp; \xC7\u0131kar</span>
      </span>
      <span class="wzg-hint" id="wzGHint"></span>
      <button type="button" class="wzg-toggle" id="wzGModeBtn">Geli\u015Fmi\u015F Moda Ge\xE7</button>
    `;let a=e.querySelector("header.topbar");a&&a.insertAdjacentElement("afterend",t);let r=n("workspace");if(r){let l=document.createElement("section");l.id="wzStartPanel",l.innerHTML=`
        <div class="wz-start-card">
          <h2>KitHub Studio</h2>
          <p class="wz-start-lead">Kitab\u0131n\u0131z\u0131 ad\u0131m ad\u0131m haz\u0131rlay\u0131n: \xF6nce proje, sonra tasar\u0131m, sonra yaz\u0131m ve \xE7\u0131kt\u0131.</p>
          <ol class="wz-start-steps">
            <li><b>Proje:</b> Yeni bir kitap projesi olu\u015Fturun veya mevcut projeyi ba\u011Flay\u0131n.</li>
            <li><b>Kitap Tasar\u0131m\u0131:</b> 13 ad\u0131ml\u0131k sihirbazla t\xFCr, sayfa boyutu, yaz\u0131 tipi, kapak ve \xF6n/arka sayfalar\u0131 se\xE7in; her ad\u0131m\u0131 onaylay\u0131n.</li>
            <li><b>Yaz &amp; \xC7\u0131kar:</b> Toplu onaylay\u0131n, tek ak\u0131\u015Fta yazd\u0131r\u0131n; DOCX + PDF + kapak paketi masa\xFCst\xFCne gelir.</li>
          </ol>
          <div class="wz-start-actions">
            <button type="button" class="primary" id="wzStartNewBtn">Yeni Kitap Ba\u015Flat</button>
            <button type="button" class="ghost" id="wzStartBindBtn">Mevcut Projeyi Ba\u011Fla</button>
          </div>
          <p class="wz-start-status" id="wzStartStatus" role="status" aria-live="polite"></p>
        </div>
      `,r.prepend(l);let s=document.createElement("section");s.id="wzDonePanel",s.style.display="none",s.innerHTML=`
        <div class="wz-done-card">
          <h2>Kitap haz\u0131r!</h2>
          <p>Onaylar tamamland\u0131. Tek ak\u0131\u015Fta yaz\u0131m ve \xE7\u0131kt\u0131y\u0131 ba\u015Flatabilirsiniz.</p>
          <p class="wz-done-path" id="wzDonePath">Paket: Masa\xFCst\xFC\\Kitap-Ad\u0131\\</p>
          <div class="wz-start-actions" style="margin-top: 14px;">
            <button type="button" class="primary" id="wzDoneRunBtn">Tek Ak\u0131\u015Fta Yaz &amp; \xC7\u0131kar</button>
            <button type="button" class="ghost" id="wzDoneOpenBtn">Paketi A\xE7</button>
            <button type="button" class="ghost" id="wzDoneResetBtn">S\u0131f\u0131rla (Yeni Ak\u0131\u015F)</button>
          </div>
        </div>
      `,l.insertAdjacentElement("afterend",s);let d=n("wzStartStatus"),u=(y,c)=>{d&&(d.textContent=c,d.classList.toggle("wz-start-error",!y))};n("wzStartNewBtn").addEventListener("click",async()=>{if(d&&(d.textContent="Proje olu\u015Fturuluyor..."),typeof createProjectViaBridge!="function"){u(!1,"Motor bulunamad\u0131; sayfay\u0131 yenileyin.");return}let y=(n("projectPathInput")?.value||"").trim();await p(()=>createProjectViaBridge());let c=(n("projectPathInput")?.value||"").trim();c&&c!==y?(u(!0,"Proje olu\u015Fturuldu \u2713 Sihirbaz a\xE7\u0131l\u0131yor."),C()):u(!1,"Proje olu\u015Fturulamad\u0131. Studio Bridge kapal\u0131 olabilir \u2014 start_studio.ps1'i \xE7al\u0131\u015Ft\u0131r\u0131n. Ayr\u0131nt\u0131 i\xE7in alt durum \xE7ubu\u011Funa bak\u0131n.")}),n("wzStartBindBtn").addEventListener("click",async()=>{if(d&&(d.textContent="Proje ba\u011Flan\u0131yor..."),typeof bindProject!="function"){u(!1,"Motor bulunamad\u0131; sayfay\u0131 yenileyin.");return}let y=(n("projectPathInput")?.value||"").trim();await p(()=>bindProject());let c=(n("projectPathInput")?.value||"").trim();c&&c!==y?(u(!0,"Proje ba\u011Fland\u0131 \u2713 Sihirbaz a\xE7\u0131l\u0131yor."),C()):u(!1,"Proje ba\u011Flanamad\u0131. Alt durum \xE7ubu\u011Fundaki mesaj\u0131 kontrol edin.")}),n("wzDoneRunBtn").addEventListener("click",()=>T()),n("wzDoneResetBtn").addEventListener("click",()=>{window.confirm("T\xFCm onaylar s\u0131f\u0131rlan\u0131p yeni bir ak\u0131\u015Fa ba\u015Flans\u0131n m\u0131?")&&ze()}),n("wzDoneOpenBtn").addEventListener("click",async()=>{await F(!0)||setStatus&&setStatus("Motor olay\u0131: paket klas\xF6r\xFC a\xE7\u0131lamad\u0131 (\xF6nce tek ak\u0131\u015F\u0131 \xE7al\u0131\u015Ft\u0131r\u0131n).")})}let o=n("wzGModeBtn");o&&o.addEventListener("click",()=>{b=!b,localStorage.setItem(H,JSON.stringify(b)),C()})}async function be(){if(z!==3)return;let e=n("wzDonePath");if(!e)return;let t=await F(!1);t&&t.path&&(e.textContent=`Paket: ${t.path}${t.exists?" (haz\u0131r)":" (hen\xFCz \xFCretilmedi)"}`)}function ke(){if(n("wzMotorMenu"))return;let e=document.querySelector(".top-actions");if(!e)return;let t=document.createElement("div");t.id="wzAdvancedMenus",t.style.display="flex",t.style.alignItems="center",t.style.gap="8px",t.innerHTML=`
      <details class="settings-menu" id="wzMotorMenu">
        <summary title="Motor" aria-label="Motor">\u26A1</summary>
        <div class="settings-panel">
          <h2>Motor</h2>
          <section class="settings-section">
            <label>Tek ak\u0131\u015F
              <button type="button" class="primary" id="wzMotorFlow">Tek Ak\u0131\u015Fta Yaz &amp; \xC7\u0131kar</button>
            </label>
            <span class="settings-note">T\xFCm ad\u0131mlar onayl\u0131ysa plan \u2192 yaz\u0131m \u2192 \xE7\u0131kt\u0131y\u0131 tek ak\u0131\u015Fta \xE7al\u0131\u015Ft\u0131r\u0131r.</span>
          </section>
          <section class="settings-section">
            <label>\u0130\xE7erik ak\u0131\u015F\u0131
              <button type="button" id="wzMotorPipeline">\u0130\xE7erik Ak\u0131\u015F\u0131n\u0131 \xC7al\u0131\u015Ft\u0131r</button>
            </label>
            <span class="settings-note">Se\xE7ili faz aral\u0131\u011F\u0131n\u0131 \xE7al\u0131\u015Ft\u0131r\u0131r (komut/API uygun).</span>
          </section>
        </div>
      </details>
      <details class="settings-menu" id="wzPanelsMenu">
        <summary title="Paneller" aria-label="Paneller">\u25A6</summary>
        <div class="settings-panel">
          <h2>Paneller</h2>
          <section class="settings-section">
            <label>G\xF6r\xFCn\xFCm
              <div class="mode">
                <button type="button" id="wzPanelsNav">Kitap Haritas\u0131</button>
                <button type="button" id="wzPanelsAgents">AI ve Yay\u0131n</button>
                <button type="button" id="wzPanelsType">Dizgi Paneli</button>
                <button type="button" id="wzPanelsPhase">Faz \u015Eeridi</button>
              </div>
            </label>
            <span class="settings-note">Butonlar paneli a\xE7\u0131p kapat\u0131r; durum alt panelden izlenir.</span>
          </section>
        </div>
      </details>
      <details class="settings-menu" id="wzToolsMenu">
        <summary title="Ara\xE7lar" aria-label="Ara\xE7lar">\u271A</summary>
        <div class="settings-panel">
          <h2>Ara\xE7lar</h2>
          <section class="settings-section">
            <label>Yay\u0131n ara\xE7lar\u0131
              <div class="mode">
                <button type="button" id="wzToolCover">Kapak St\xFCdyosu</button>
                <button type="button" id="wzToolMatter">\xD6n / Arka Sayfalar</button>
                <button type="button" id="wzToolPreflight">Yay\u0131n \xD6ncesi Kontrol</button>
                <button type="button" id="wzToolBuild">PDF/EPUB \xDCret</button>
                <button type="button" id="wzToolExport">Final DOCX'i Kopyala</button>
                <button type="button" id="wzToolBackup">Projeyi Yedekle</button>
              </div>
            </label>
          </section>
        </div>
      </details>
    `;let a=n("exportBtn");e.insertBefore(t,a||e.firstChild),n("wzMotorFlow").addEventListener("click",()=>T()),n("wzMotorPipeline").addEventListener("click",()=>{typeof copyPipelineCommand=="function"&&p(()=>copyPipelineCommand())}),n("wzPanelsNav").addEventListener("click",()=>p(()=>togglePanel("nav-collapsed",n("sideCollapseBtn")))),n("wzPanelsAgents").addEventListener("click",()=>p(()=>togglePanel("agents-collapsed",n("collapseAgents")))),n("wzPanelsType").addEventListener("click",()=>p(()=>togglePanel("type-collapsed",n("toggleType")))),n("wzPanelsPhase").addEventListener("click",()=>{let r=n("wzPhaseList");r&&r.scrollIntoView({behavior:"smooth",block:"nearest"})}),n("wzToolCover").addEventListener("click",()=>p(()=>n("openCoverStudioBtn")?.click())),n("wzToolMatter").addEventListener("click",()=>p(()=>n("openMatterManagerBtn")?.click())),n("wzToolPreflight").addEventListener("click",()=>p(()=>n("runPreflightBtn")?.click())),n("wzToolBuild").addEventListener("click",()=>p(()=>n("buildPublicationBtn")?.click())),n("wzToolExport").addEventListener("click",()=>p(()=>n("finalExportBtn")?.click())),n("wzToolBackup").addEventListener("click",()=>p(()=>n("backupProjectBtn")?.click()))}function ve(){let e=n("wzPhaseList");if(!e)return;let t=document.querySelectorAll("#agentList .agent"),a=["Fikir","Y\xF6n","Karakter","Plan","Yaz\u0131m","Tutarl\u0131l\u0131k","T\xFCrk\xE7e","D\xFCzen","Yay\u0131n"];if(e.replaceChildren(),!t.length){let r=document.createElement("span");r.className="book-meta",r.textContent="fazlar beklemede",e.appendChild(r);return}t.forEach((r,o)=>{let l=r.className||"",s=l.includes("running")||l.includes("review"),d=l.includes("done"),u=document.createElement("div");u.className="wz-ph-node"+(s?" running":d?" done":"");let y=p(()=>r.querySelector("h3")?.textContent?.trim())||"",c=p(()=>r.querySelector("p")?.textContent?.trim())||"",f=p(()=>r.querySelector(".state")?.textContent?.trim())||"Beklemede",w=`${y} \u2014 ${c} (${f})`;u.title=w;let g=document.createElement("span");g.className="wz-ph-label",g.textContent=a[o]||String(o+1),g.title=w,u.appendChild(g),e.appendChild(u)})}function R(){ve()}function he(){if(n("wzPhaseList"))return;let e=document.querySelector("header.topbar .crumbs"),t=document.querySelector("header.topbar .chrome-controls");if(!e||!t)return;let a=document.createElement("div");a.id="wzPhaseList",a.className="wz-phase-list",t.insertAdjacentElement("afterend",a),R()}function W(){U(),V(),se(),pe(),ce(),we(),he(),document.addEventListener("change",e=>{let t=e.target&&e.target.id;t&&$(t)}),X().then(()=>{k(),x(),h(),C()}),ue=setInterval(()=>{ge(),be(),R()},2500)}window.KitHubWizard={steps:m,getState:()=>({...i,approvals:{...i.approvals}}),approveCurrent:Y,openSummary:D,persist:E,runFlow:T},document.readyState==="loading"?document.addEventListener("DOMContentLoaded",W):W()})();})();
