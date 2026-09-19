import "./studio-professional.css";

const clone = value => JSON.parse(JSON.stringify(value));
const uid = prefix => `${prefix}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
const html = value => String(value ?? "").replace(/[&<>"']/g, character => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[character]));
const elapsed = (started, finished) => { if (!started) return ""; const seconds = Math.max(0, Math.round((new Date(finished || Date.now()) - new Date(started)) / 1000)); return `${Math.floor(seconds / 60)}dk ${seconds % 60}sn`; };
const nowIso = () => new Date().toISOString();
const roles = { author: "Yazar", editor: "Editör", reviewer: "Okur", admin: "Yönetici" };
const entityLabels = { characters: "Karakterler", locations: "Mekânlar", plot: "Olay Örgüsü", research: "Araştırma" };

function familyEntityLabels(family) {
  if (family === "academic") return { characters: "Literatür", locations: "Kapsam", plot: "Argüman Akışı", research: "Kaynaklar" };
  if (family === "research" || family === "report") return { characters: "Kanıtlar", locations: "Kapsam", plot: "Bulgu Akışı", research: "Araştırma" };
  if (family === "instructional") return { characters: "Örnekler", locations: "Modüller", plot: "Öğrenme Akışı", research: "Kaynaklar" };
  if (family === "article") return { characters: "Örnekler", locations: "Kanal", plot: "Mesaj Akışı", research: "Kaynaklar" };
  if (family === "poetry") return { characters: "İmgeler", locations: "Atmosfer", plot: "Tema Akışı", research: "Notlar" };
  return entityLabels;
}

function entityCopy(kind, family) {
  const labels = familyEntityLabels(family);
  const label = labels[kind] || entityLabels[kind] || "Kayıt";
  if (kind === "characters" && family !== "fiction" && family !== "screenplay") return { label, detail: "Odak / kaynak / örnek durumu", intro: "Seçilen türe göre odak kayıtlarını yönetin." };
  if (kind === "locations" && family !== "fiction" && family !== "screenplay") return { label, detail: "Kapsam / seviye / bağlam", intro: "Kapsam ve bağlam kayıtları proje state dosyalarına yazılır." };
  if (kind === "plot" && family !== "fiction" && family !== "screenplay") return { label, detail: "Akış durumu", intro: "Argüman, bulgu veya öğrenme akışını izleyin." };
  if (kind === "research") return { label, detail: "Kaynak", intro: "Kaynak, not ve kanıt kayıtlarını yönetin." };
  return { label, detail: kind === "characters" ? "Karakter yayı / durum" : kind === "locations" ? "İlk göründüğü bölüm" : "Durum", intro: "Kitap dünyasını tek yerden yönetin." };
}

function defaults() {
  return {
    schema_version: "1.0.0",
    comments: [],
    changes: [],
    collaboration: { current_role: "author", current_name: "Yazar", members: [] },
    writing: { daily_goal_words: 1000, project_goal_words: 80000, deadline: "", sessions: [] },
    publication: { profile: "kdp", isbn: "", imprint: "", language: "tr-TR", cover_asset: null }
  };
}

function normalize(value) {
  const base = defaults();
  const next = value ? clone(value) : {};
  return {
    ...base,
    ...next,
    comments: Array.isArray(next.comments) ? next.comments : [],
    changes: Array.isArray(next.changes) ? next.changes : [],
    collaboration: { ...base.collaboration, ...(next.collaboration || {}), members: Array.isArray(next.collaboration?.members) ? next.collaboration.members : [] },
    writing: { ...base.writing, ...(next.writing || {}), sessions: Array.isArray(next.writing?.sessions) ? next.writing.sessions : [] },
    publication: { ...base.publication, ...(next.publication || {}) }
  };
}

export function createProfessionalStudio(config) {
  let state = defaults();
  let entities = { characters: [], locations: [], plot: [], research: [] };
  let tab = "entities";
  let entityKind = "characters";
  let editEntity = null;
  let coverPreviewUrl = "";
  let dialog;
  let agentRefreshTimer;

  const projectRoot = () => {
    const value = config.getProjectRoot();
    if (!value || value === ".") config.setStatus("Profesyonel araçlar için önce gerçek bir KitHub projesi bağlayın.");
    return value && value !== "." ? value : "";
  };

  async function saveState(message) {
    const root = projectRoot();
    if (!root) return false;
    const result = await config.api("/api/professional-state/save", { projectRoot: root, state });
    if (!result.ok) throw new Error(result.error || "Profesyonel state kaydedilemedi.");
    state = normalize(result.state);
    config.setStatus(message || "Profesyonel proje verileri kaydedildi.");
    render();
    return true;
  }

  const tabTitle = () => ({ entities: "Kitap Varlıkları", review: "Yorumlar ve Değişiklikler", writing: "Hedefler ve Oturumlar", agents: "Ajanlar ve Görevler", publication: "Yayın Kimliği ve Kapak" }[tab]);

  function shell() {
    const tabs = [["entities","Varlıklar"],["review","Editörlük"],["agents","Ajanlar"],["writing","Yazma Hedefleri"],["publication","Yayın Kimliği"]];
    return `<div class="professional-shell">
      <aside class="professional-rail"><strong>Profesyonel Araçlar</strong><div class="professional-tabs" role="tablist" aria-label="Profesyonel araç bölümleri">
        ${tabs.map(([key,label]) => `<button type="button" role="tab" data-prof-tab="${key}" aria-selected="${tab === key}">${label}</button>`).join("")}
      </div></aside>
      <section class="professional-main"><header class="professional-head"><h2 id="professionalDialogTitle">${tabTitle()}</h2><button type="button" class="ghost" data-prof-close aria-label="Profesyonel araçları kapat">×</button></header><div class="professional-body" data-prof-body></div></section>
    </div>`;
  }

  function entityForm() {
    const item = editEntity || {};
    const copy = entityCopy(entityKind, config.getWritingFamily?.() || "fiction");
    const detailLabel = copy.detail;
    return `<form class="professional-form" data-entity-form>
      <strong>${editEntity ? "Kaydı düzenle" : "Yeni kayıt"}</strong>
      <input type="hidden" name="id" value="${html(item.id || "")}"><input type="hidden" name="originalLabel" value="${html(item.label || "")}">
      <label>Ad / Başlık<input name="label" required maxlength="180" value="${html(item.label || "")}"></label>
      ${entityKind === "plot" ? `<label>${detailLabel}<select name="status"><option value="open" ${item.status !== "closed" ? "selected" : ""}>Açık</option><option value="closed" ${item.status === "closed" ? "selected" : ""}>Kapandı</option></select></label>` : `<label>${detailLabel}<input name="detail" maxlength="4000" value="${html(item.detail || "")}"></label>`}
      ${entityKind === "characters" ? `<label>Rol<input name="role" maxlength="120" value="${html(item.role || "")}"></label><label>Hedef<input name="goal" maxlength="1000" value="${html(item.goal || "")}"></label><label>Çatışma<input name="conflict" maxlength="1000" value="${html(item.conflict || "")}"></label>` : ""}
      <label>Notlar<textarea name="notes" maxlength="4000">${html(item.notes || "")}</textarea></label>
      <div class="professional-actions">${editEntity ? '<button type="button" class="ghost" data-entity-cancel>Vazgeç</button>' : ""}<button type="submit" class="primary">${editEntity ? "Güncelle" : "Oluştur"}</button></div>
    </form>`;
  }

  function entitiesView() {
    const items = entities[entityKind] || [];
    const labels = familyEntityLabels(config.getWritingFamily?.() || "fiction");
    const copy = entityCopy(entityKind, config.getWritingFamily?.() || "fiction");
    return `<div class="professional-section-head"><div><h3>${html(copy.intro)}</h3><p>Kayıtlar doğrudan proje state dosyalarına atomik olarak yazılır.</p></div></div>
      <div class="professional-kind-tabs">${Object.entries(labels).map(([key,label]) => `<button type="button" data-entity-kind="${key}" aria-pressed="${entityKind === key}">${label} <span>${(entities[key] || []).length}</span></button>`).join("")}</div>
      <div class="professional-grid"><div class="professional-list">
        ${items.length ? items.map(item => `<article class="professional-row"><div><strong>${html(item.label || item.id)}</strong><span>${html(item.detail || item.status || "")}</span></div><div class="professional-row-actions">${item.readonly ? '<span class="professional-badge">Salt okunur belge</span>' : `<button type="button" class="ghost" data-entity-edit="${html(item.id)}">Düzenle</button><button type="button" class="ghost danger" data-entity-delete="${html(item.id)}">Sil</button>`}</div></article>`).join("") : '<div class="professional-empty">Bu türde henüz kayıt yok.</div>'}
      </div>${entityForm()}</div>`;
  }

  function commentsView() {
    const chapter = config.getChapter();
    const items = state.comments.filter(item => item.status !== "resolved");
    return `<section class="professional-stack"><form class="professional-form" data-comment-form><strong>Satır içi yorum ekle</strong><label>Alıntı<textarea name="quote" maxlength="2000">${html(config.getSelection())}</textarea></label><label>Yorum<textarea name="text" maxlength="4000" required></textarea></label><div class="professional-actions"><span class="professional-badge">${html(chapter?.title || "Bölüm seçilmedi")}</span><button type="submit" class="primary">Yorumu Ekle</button></div></form>
      ${items.length ? items.map(item => `<article class="professional-card" data-comment-card="${html(item.id)}"><div><strong>${html(item.author || "Yazar")}</strong> <span class="professional-badge">${html(roles[item.role] || item.role)}</span></div>${item.quote ? `<blockquote>${html(item.quote)}</blockquote>` : ""}<p>${html(item.text)}</p>${(item.replies || []).map(reply => `<p><strong>${html(reply.author || "Yanıt")}</strong> — ${html(reply.text)}</p>`).join("")}<label>Yanıt<input data-comment-reply maxlength="2000"></label><div class="professional-actions"><button type="button" class="ghost" data-comment-reply-send="${html(item.id)}">Yanıtla</button><button type="button" data-comment-resolve="${html(item.id)}">Çözüldü</button></div></article>`).join("") : '<div class="professional-empty">Açık yorum yok.</div>'}</section>`;
  }

  function changesView() {
    const items = state.changes.filter(item => item.status === "pending");
    return `<section class="professional-stack"><form class="professional-form" data-change-form><strong>Değişiklik öner</strong><label>Mevcut metin<textarea name="original" maxlength="12000" required>${html(config.getSelection())}</textarea></label><label>Önerilen metin<textarea name="replacement" maxlength="12000" required></textarea></label><div class="professional-actions"><button type="submit" class="primary">Öneriyi Kaydet</button></div></form>
      ${items.length ? items.map(item => `<article class="professional-card"><div><strong>${html(item.author || "Editör")}</strong> <span class="professional-badge">${html(item.chapter || "")}</span></div><p><del>${html(item.original)}</del></p><p><ins>${html(item.replacement)}</ins></p><div class="professional-actions"><button type="button" class="ghost danger" data-change-reject="${html(item.id)}">Reddet</button><button type="button" class="primary" data-change-accept="${html(item.id)}">Kabul Et</button></div></article>`).join("") : '<div class="professional-empty">Bekleyen değişiklik önerisi yok.</div>'}</section>`;
  }

  function reviewView() {
    const current = state.collaboration;
    return `<div class="professional-section-head"><div><h3>Editör–yazar çalışma alanı</h3><p>Yorumlar, öneriler ve roller proje içinde sürümlenir.</p></div></div>
      <div class="professional-settings" style="margin-bottom:18px"><div class="professional-split"><label>Aktif kullanıcı<input data-current-name maxlength="120" value="${html(current.current_name)}"></label><label>Aktif rol<select data-current-role>${Object.entries(roles).map(([key,label]) => `<option value="${key}" ${current.current_role === key ? "selected" : ""}>${label}</option>`).join("")}</select></label></div><div class="professional-actions"><button type="button" data-save-collaboration>Rolü Kaydet</button></div></div>
      <div class="professional-split"><div><div class="professional-section-head"><div><h3>Yorumlar</h3><p>${state.comments.filter(item => item.status !== "resolved").length} açık konuşma</p></div></div>${commentsView()}</div><div><div class="professional-section-head"><div><h3>Değişiklikleri İzle</h3><p>${state.changes.filter(item => item.status === "pending").length} bekleyen öneri</p></div></div>${changesView()}</div></div>`;
  }

  function membersView() {
    const members = state.collaboration.members || [];
    return `<div class="professional-settings" style="margin-bottom:18px"><strong>Proje Ekibi</strong><form class="professional-split" data-member-form><label>Ad<input name="name" required maxlength="120"></label><label>Rol<select name="role">${Object.entries(roles).map(([key,label]) => `<option value="${key}">${label}</option>`).join("")}</select></label><div class="professional-actions"><button type="submit">Ekip Üyesi Ekle</button></div></form><div class="professional-list">${members.length ? members.map(member => `<div class="professional-row"><div><strong>${html(member.name)}</strong><span>${html(roles[member.role] || member.role)}</span></div><button type="button" class="ghost danger" data-member-delete="${html(member.id)}">Kaldır</button></div>`).join("") : '<div class="professional-empty">Proje ekibinde kayıtlı kişi yok.</div>'}</div></div>`;
  }

  function sessionTotals() {
    const sessions = state.writing.sessions || [];
    return {
      words: sessions.reduce((sum,item) => sum + Math.max(0, Number(item.end_words || item.start_words) - Number(item.start_words || 0)), 0),
      minutes: Math.round(sessions.reduce((sum,item) => item.started_at && item.ended_at ? sum + Math.max(0, new Date(item.ended_at) - new Date(item.started_at)) / 60000 : sum, 0))
    };
  }

  function writingView() {
    const totals = sessionTotals();
    const words = config.getWordCount();
    const goal = Math.max(0, Number(state.writing.project_goal_words || 0));
    const percent = goal ? Math.min(100, Math.round(words / goal * 100)) : 0;
    const active = [...state.writing.sessions].reverse().find(item => !item.ended_at);
    return `<div class="professional-section-head"><div><h3>Yazma ritmi</h3><p>Hedefler ve oturumlar gerçek kelime sayısıyla izlenir.</p></div></div>
      <div class="professional-metrics"><div class="professional-metric"><strong>${words.toLocaleString("tr-TR")}</strong><span>Geçerli bölüm kelimesi</span></div><div class="professional-metric"><strong>${totals.words.toLocaleString("tr-TR")}</strong><span>Oturumlarda yazılan</span></div><div class="professional-metric"><strong>${totals.minutes}</strong><span>Toplam dakika</span></div></div>
      <div class="professional-progress" aria-label="Proje kelime hedefi yüzde ${percent}"><span style="width:${percent}%"></span></div>
      <div class="professional-split" style="margin-top:18px"><form class="professional-settings" data-goal-form><strong>Hedefler</strong><label>Günlük kelime<input name="daily" type="number" min="0" max="100000" value="${Number(state.writing.daily_goal_words || 0)}"></label><label>Proje kelime hedefi<input name="project" type="number" min="0" max="10000000" value="${goal}"></label><label>Bitiş tarihi<input name="deadline" type="date" value="${html(state.writing.deadline || "")}"></label><div class="professional-actions"><button type="submit" class="primary">Hedefleri Kaydet</button></div></form>
      <div class="professional-settings"><strong>Odak Oturumu</strong><p>${active ? "Oturum çalışıyor; bitirildiğinde süre ve yazılan kelime kaydedilir." : "Yeni oturum başlangıç kelime sayısını kaydeder."}</p><div class="professional-actions"><button type="button" class="${active ? "danger" : "primary"}" data-session-toggle>${active ? "Oturumu Bitir" : "Oturumu Başlat"}</button></div></div></div>`;
  }

  function publicationView() {
    const publication = state.publication;
    const asset = publication.cover_asset;
    return `<div class="professional-section-head"><div><h3>Yayın kimliği ve kapak kaynağı</h3><p>Profil, ISBN ve görsel kalite kontrolleri yayın önkontrolüne bağlanır.</p></div></div><div class="professional-grid">
      <form class="professional-settings" data-publication-form><label>Dağıtım profili<select name="profile"><option value="kdp" ${publication.profile === "kdp" ? "selected" : ""}>Amazon KDP</option><option value="ingram" ${publication.profile === "ingram" ? "selected" : ""}>IngramSpark</option><option value="custom" ${publication.profile === "custom" ? "selected" : ""}>Özel matbaa</option></select></label><label>ISBN-13<input name="isbn" inputmode="numeric" maxlength="17" value="${html(publication.isbn || "")}" placeholder="978..."></label><label>Yayınevi / Marka<input name="imprint" maxlength="180" value="${html(publication.imprint || "")}"></label><label>Dil<input name="language" maxlength="20" value="${html(publication.language || "tr-TR")}"></label><label>Kapak görseli (PNG/JPEG, en fazla 15 MB)<input type="file" data-cover-file accept="image/png,image/jpeg"></label><div class="professional-actions"><button type="button" class="ghost" data-apply-matter-templates>Ön/Arka Sayfaları Otomatik Doldur</button><button type="submit" class="primary">Yayın Kimliğini Kaydet</button></div></form>
      <div class="professional-settings"><div class="professional-cover-preview">${coverPreviewUrl ? `<img src="${coverPreviewUrl}" alt="Yüklenen kapak görseli">` : `<span>${asset ? `${html(asset.filename)} · ${Number(asset.width_px || 0)}×${Number(asset.height_px || 0)} px` : "Kapak görseli yüklenmedi; tipografik kapak kullanılacak."}</span>`}</div><p>${asset ? `Kaynak: ${html(asset.relative_path)} · ${(Number(asset.bytes || 0) / 1048576).toFixed(1)} MB` : "Yüklenen görsel kapak PDF’sine ve EPUB paketine bağlanır; 300 DPI kontrolü otomatik yapılır."}</p></div>
    </div>`;
  }


  async function agentsView() {
    const root = projectRoot();
    if (!root) return '<div class="professional-empty">Ajanlar için önce gerçek bir KitHub projesi bağlayın.</div>';
    const summary = await config.api("/api/task-summary", { projectRoot: root });
    if (!summary || !summary.ok) throw new Error((summary && summary.error) || "Görev özeti alınamadı.");
    const counts = summary.task_counts || {};
    const tasks = (summary.tasks || []).slice().reverse();
    const feed = (summary.feed || []).slice().reverse();
    const agents = summary.agents || [];
    const runs = summary.runs || [];
    const statusLabel = { pending: "Bekliyor", in_flight: "Çalışıyor", completed: "Tamamlandı", failed: "Hata", cancelled: "İptal", blocked: "Engelli" };
    const phaseLabel = { intake: "İstek", propose: "Öneri", "design-big": "Büyük Tasarım", "design-small": "Sahne Tasarımı", create: "Yazım", polish: "Düzeltme", rewrite: "Yeniden Yazım", export: "Export" };
    const agentMeta = {};
    for (const a of agents) agentMeta[a.id] = { label: a.label || a.id, color: a.color || "#6b7280", enabled: a.enabled };
    const chip = (label, value, color) => '<div class="professional-card" style="padding:10px 14px;min-width:110px"><div style="font-size:22px;font-weight:700;color:' + color + '">' + html(value) + '</div><div style="font-size:12px;color:#6b7280">' + html(label) + '</div></div>';
    const chipRow = '<div class="professional-stack" style="flex-direction:row;flex-wrap:wrap;gap:8px">' + chip("Bekleyen", counts.pending || 0, "#b45309") + chip("Çalışıyor", counts.in_flight || 0, "#2563eb") + chip("Tamamlandı", counts.completed || 0, "#15803d") + chip("Hata", (counts.failed || 0) + (counts.blocked || 0), "#be123c") + '</div>';
    const taskRows = tasks.length ? tasks.map(t => {
      const meta = agentMeta[t.agent] || { label: t.agent, color: "#6b7280", enabled: true };
      const st = statusLabel[t.status] || t.status;
      const ph = phaseLabel[t.phase] || t.phase || "—";
      const scope = t.scope ? (t.scope.episode ? html(t.scope.episode) : t.scope.kind === "phase" ? "Faz: " + (phaseLabel[t.scope.phase] || t.scope.phase) : t.scope.kind || "") : "";
      let appr = "";
      if (t.approval) appr = t.approval.status === "approved" ? '<span class="professional-badge" style="background:#dcfce7;color:#15803d">Onaylandı · ' + html(t.approval.by || "") + '</span>' : '<span class="professional-badge" style="background:#fee2e2;color:#be123c">Reddedildi</span>';
      const run = runs.find(item => item.runId === t.run_id);
      const runtimeMeta = run ? '<div style="font-size:12px;color:#6b7280;margin-top:6px">Run ' + html(run.runId) + ' ? PID ' + html(run.pid ?? '?') + ' ? ' + html(run.status || '') + (run.startedAt ? ' ? s?re ' + elapsed(run.startedAt, run.finishedAt) : '') + (t.attempts ? ' ? deneme ' + html(t.attempts) + '/' + html(t.max_attempts || 2) : '') + ' ? log: ' + html(run.logOut || '') + ' ? verifier: runtime/agent-runs/' + html(run.runId) + '/verification.json</div>' : '';
      if (t.requires_approval && t.status === "completed") appr = '<span class="professional-badge" style="background:#fef3c7;color:#b45309">Onay bekliyor</span>';
      const result = t.result ? '<div style="font-size:12px;color:#374151;margin-top:6px">' + html(t.result.summary || "") + (t.result.issues != null ? " · <strong>" + t.result.issues + "</strong> sorun" : "") + '</div>' : "";
      const btns = [];
      appr += runtimeMeta;
      if (t.status === "pending") btns.push('<button type="button" class="primary" data-task-run="' + html(t.id) + '">Başlat</button>');
      if (t.status === "in_flight") btns.push('<button type="button" class="primary" data-task-complete="' + html(t.id) + '">Tamamlandı İşaretle</button>');
      if (t.requires_approval && t.status === "completed" && !t.approval) { btns.push('<button type="button" class="primary" data-task-approve="' + html(t.id) + '">Onayla</button>'); btns.push('<button type="button" class="ghost danger" data-task-reject="' + html(t.id) + '">Reddet</button>'); }
      if (t.status === "pending" || t.status === "in_flight") btns.push('<button type="button" class="ghost danger" data-task-cancel="' + html(t.id) + '">İptal</button>');
      const btnsHtml = btns.length ? '<div class="professional-actions">' + btns.join("") + '</div>' : "";
      const runtimeMetaHtml = runtimeMeta;
      return '<article class="professional-card"><div style="display:flex;justify-content:space-between;gap:8px;align-items:center"><div><strong>' + html(t.title) + '</strong> <span class="professional-badge" style="background:' + meta.color + '1a;color:' + meta.color + ';border:1px solid ' + meta.color + '55">' + html(meta.label) + '</span> <span class="professional-badge">' + html(ph) + '</span> <span class="professional-badge">' + html(st) + '</span></div>' + appr + '</div><div style="font-size:12px;color:#6b7280;margin-top:4px">' + scope + ' · ' + html(t.source) + ' · ' + new Date(t.created_at).toLocaleString("tr-TR") + '</div>' + result + btnsHtml + '</article>';
    }).join("") : '<div class="professional-empty">Görev yok. Aşağıdan bir görev oluşturun veya yorumda @ajan yazın.</div>';
    const agentOptions = agents.filter(a => a.enabled).map(a => '<option value="' + html(a.id) + '">' + html(a.label || a.id) + '</option>').join("");
    const phaseOptions = Object.entries(phaseLabel).map(([k, v]) => '<option value="' + k + '">' + v + '</option>').join("");
    const feedRows = feed.length ? feed.map(e => '<div class="professional-row"><div><span class="professional-badge">' + html(e.actor_id || e.actor_type) + '</span> <span style="font-size:12px;color:#6b7280">' + new Date(e.at).toLocaleString("tr-TR") + '</span></div><div style="font-size:13px">' + html(e.message) + '</div></div>').join("") : '<div class="professional-empty">Akış boş.</div>';
    const agentChips = agents.map(a => '<span class="professional-badge" style="background:' + html(a.color || "#6b7280") + '1a;color:' + html(a.color || "#6b7280") + ';border:1px solid ' + html(a.color || "#6b7280") + '55">' + html(a.label || a.id) + (a.enabled ? "" : " · pasif") + '</span>').join(" ");
    return '<section class="professional-stack">'
      + '<div style="display:flex;justify-content:space-between;align-items:center"><h3>Ajan Durumu</h3><button type="button" class="ghost" data-task-refresh>Yenile</button></div>'
      + chipRow
      + '<h3 style="margin-top:14px">Görev Kuyruğu</h3>'
      + '<div class="professional-stack">' + taskRows + '</div>'
      + '<form class="professional-form" data-task-form style="margin-top:14px"><strong>Yeni görev oluştur</strong>'
      + '<div class="professional-split"><label>Ajan<select name="agent" required>' + agentOptions + '</select></label><label>Faz<select name="phase">' + phaseOptions + '</select></label></div>'
      + '<label>Başlık<input name="title" maxlength="200" required placeholder="Örn: Bölüm 5 TDK kontrolü"></label>'
      + '<label>@mention (opsiyonel)<input name="mentionText" maxlength="300" placeholder="Örn: @tdk-polisher bölüm 5i kontrol et"></label>'
      + '<div class="professional-actions"><button type="submit" class="primary">Görevi Ekle</button></div>'
      + '</form>'
      + '<h3 style="margin-top:14px">Olay Akışı</h3>'
      + '<div class="professional-stack">' + feedRows + '</div>'
      + '<h3 style="margin-top:14px">Ajanlar</h3>'
      + '<div>' + agentChips + '</div>'
      + '</section>';
  }

  function render() {
    if (!dialog) return;
    dialog.innerHTML = shell();
    const body = dialog.querySelector("[data-prof-body]");
    if (tab === "agents") {
      body.innerHTML = '<div class="professional-empty">Ajanlar yükleniyor…</div>';
      agentsView().then(htmlOut => { if (body) body.innerHTML = htmlOut; }).catch(error => { if (body) body.innerHTML = '<div class="professional-empty">Ajanlar yüklenemedi: ' + html(error.message) + '</div>'; });
      return;
    }
    body.innerHTML = tab === "entities" ? entitiesView() : tab === "review" ? reviewView() : tab === "writing" ? writingView() : publicationView();
    if (tab === "review") body.insertAdjacentHTML("afterbegin", membersView());
  }

  async function entitySubmit(form) {
    const data = Object.fromEntries(new FormData(form));
    const result = await config.api("/api/manage-entity", { projectRoot: projectRoot(), kind: entityKind, action: editEntity ? "update" : "create", ...data });
    if (!result.ok) throw new Error(result.error || "Varlık kaydedilemedi.");
    editEntity = null;
    config.setStatus(`${entityLabels[entityKind]} kaydı atomik olarak kaydedildi.`);
    await config.refresh();
  }

  async function deleteEntity(id) {
    const item = (entities[entityKind] || []).find(entry => entry.id === id);
    if (!item || !window.confirm(`“${item.label}” kaydı silinsin mi? İşlem sürüm geçmişine alınır.`)) return;
    const result = await config.api("/api/manage-entity", { projectRoot: projectRoot(), kind: entityKind, action: "delete", id, originalLabel: item.label, label: item.label });
    if (!result.ok) throw new Error(result.error || "Varlık silinemedi.");
    config.setStatus(`${item.label} silindi; önceki durum sürüm geçmişinde korundu.`);
    await config.refresh();
  }

  async function loadCover() {
    if (!state.publication.cover_asset) return;
    const result = await config.api("/api/cover-asset/read", { projectRoot: projectRoot() });
    if (result.ok && result.contentBase64 && result.asset?.mime) {
      coverPreviewUrl = `data:${result.asset.mime};base64,${result.contentBase64}`;
      if (tab === "publication") render();
    }
  }

  async function uploadCover(file) {
    if (!file) return;
    if (file.size > 15728640) throw new Error("Kapak görseli 15 MB sınırını aşıyor.");
    const dataUrl = await new Promise((resolve,reject) => {
      const reader = new FileReader();
      reader.onerror = () => reject(new Error("Kapak görseli okunamadı."));
      reader.onload = () => resolve(String(reader.result));
      reader.readAsDataURL(file);
    });
    const dimensions = await new Promise((resolve,reject) => {
      const image = new Image();
      const objectUrl = URL.createObjectURL(file);
      image.onerror = () => { URL.revokeObjectURL(objectUrl); reject(new Error("Kapak boyutları okunamadı.")); };
      image.onload = () => { const result = { widthPx: image.naturalWidth, heightPx: image.naturalHeight }; URL.revokeObjectURL(objectUrl); resolve(result); };
      image.src = objectUrl;
    });
    const result = await config.api("/api/cover-asset/upload", { projectRoot: projectRoot(), filename: file.name, contentBase64: dataUrl.split(",")[1] || "", ...dimensions });
    if (!result.ok) throw new Error(result.error || "Kapak yüklenemedi.");
    state.publication.cover_asset = result.asset;
    coverPreviewUrl = dataUrl;
    config.setStatus(`Kapak görseli yüklendi: ${dimensions.widthPx}×${dimensions.heightPx} px`);
    render();
  }

  async function click(event) {
    const tabButton = event.target.closest("[data-prof-tab]");
    if (tabButton) { tab = tabButton.dataset.profTab; editEntity = null; render(); if (tab === "publication") loadCover().catch(() => {}); return; }
    if (event.target.closest("[data-prof-close]")) { dialog.close(); return; }
    const kind = event.target.closest("[data-entity-kind]");
    if (kind) { entityKind = kind.dataset.entityKind; editEntity = null; render(); return; }
    const edit = event.target.closest("[data-entity-edit]");
    if (edit) { editEntity = clone((entities[entityKind] || []).find(item => item.id === edit.dataset.entityEdit) || null); render(); return; }
    if (event.target.closest("[data-entity-cancel]")) { editEntity = null; render(); return; }
    const remove = event.target.closest("[data-entity-delete]");
    if (remove) { await deleteEntity(remove.dataset.entityDelete); return; }
    const memberDelete = event.target.closest("[data-member-delete]");
    if (memberDelete) { state.collaboration.members = state.collaboration.members.filter(item => item.id !== memberDelete.dataset.memberDelete); await saveState("Ekip üyesi kaldırıldı."); return; }
    const resolve = event.target.closest("[data-comment-resolve]");
    if (resolve) { const item = state.comments.find(entry => entry.id === resolve.dataset.commentResolve); if (item) { item.status = "resolved"; await saveState("Yorum çözüldü."); } return; }
    const reply = event.target.closest("[data-comment-reply-send]");
    if (reply) {
      const item = state.comments.find(entry => entry.id === reply.dataset.commentReplySend);
      const text = reply.closest("[data-comment-card]")?.querySelector("[data-comment-reply]")?.value.trim();
      if (item && text) { item.replies ||= []; item.replies.push({ id: uid("reply"), text, author: state.collaboration.current_name, role: state.collaboration.current_role, created_at: nowIso() }); await saveState("Yorum yanıtı kaydedildi."); }
      return;
    }
    const accept = event.target.closest("[data-change-accept]");
    if (accept) { const item = state.changes.find(entry => entry.id === accept.dataset.changeAccept); if (item && await config.applyTrackedChange(item)) { item.status = "accepted"; await saveState("Değişiklik kabul edildi ve bölüm kaydedildi."); } return; }
    const reject = event.target.closest("[data-change-reject]");
    if (reject) { const item = state.changes.find(entry => entry.id === reject.dataset.changeReject); if (item) { item.status = "rejected"; await saveState("Değişiklik reddedildi."); } return; }
    if (event.target.closest("[data-save-collaboration]")) {
      state.collaboration.current_name = dialog.querySelector("[data-current-name]").value.trim() || "Yazar";
      state.collaboration.current_role = dialog.querySelector("[data-current-role]").value;
      await saveState("Aktif kullanıcı rolü kaydedildi.");
      return;
    }
    if (event.target.closest("[data-session-toggle]")) {
      const active = [...state.writing.sessions].reverse().find(item => !item.ended_at);
      if (active) { active.ended_at = nowIso(); active.end_words = config.getWordCount(); await saveState("Odak oturumu tamamlandı."); }
      else { state.writing.sessions.push({ id: uid("session"), started_at: nowIso(), ended_at: "", start_words: config.getWordCount(), end_words: 0, chapter: config.getChapter()?.filename || "" }); await saveState("Odak oturumu başladı."); }
      return;
    }
    if (event.target.closest("[data-task-refresh]")) { render(); return; }
    const taskRun = event.target.closest("[data-task-run]");
    if (taskRun) { const result = await config.api("/api/task-run", { projectRoot: projectRoot(), taskId: taskRun.dataset.taskRun }); if (!result.ok) throw new Error(result.error || "Görev başlatılamadı."); config.setStatus(result.task.id + " başlatıldı."); render(); return; }
    const taskApprove = event.target.closest("[data-task-approve]");
    if (taskApprove) { const result = await config.api("/api/task-approve", { projectRoot: projectRoot(), taskId: taskApprove.dataset.taskApprove, approval: "approved", by: state.collaboration.current_name || "Yazar" }); if (!result.ok) throw new Error(result.error || "Görev onaylanamadı."); config.setStatus(taskApprove.dataset.taskApprove + " onaylandı."); render(); return; }
    const taskReject = event.target.closest("[data-task-reject]");
    if (taskReject) { const result = await config.api("/api/task-approve", { projectRoot: projectRoot(), taskId: taskReject.dataset.taskReject, approval: "denied", by: state.collaboration.current_name || "Yazar" }); if (!result.ok) throw new Error(result.error || "Görev reddedilemedi."); config.setStatus(taskReject.dataset.taskReject + " reddedildi."); render(); return; }
    const taskComplete = event.target.closest("[data-task-complete]");
    if (taskComplete) { const result = await config.api("/api/task-complete", { projectRoot: projectRoot(), taskId: taskComplete.dataset.taskComplete, summary: "Kullanıcı tarafından tamamlandı işaretlendi." }); if (!result.ok) throw new Error(result.error || "Görev tamamlanamadı."); config.setStatus(taskComplete.dataset.taskComplete + " tamamlandı."); render(); return; }
    const taskCancel = event.target.closest("[data-task-cancel]");
    if (taskCancel) { const result = await config.api("/api/task-cancel", { projectRoot: projectRoot(), taskId: taskCancel.dataset.taskCancel, by: state.collaboration.current_name || "Yazar" }); if (!result.ok) throw new Error(result.error || "Görev iptal edilemedi."); config.setStatus(taskCancel.dataset.taskCancel + " iptal edildi."); render(); return; }
    if (event.target.closest("[data-apply-matter-templates]")) {
      await config.applyMatterTemplates({ ...state.publication, author: state.collaboration.current_name });
      return;
    }
  }

  async function submit(event) {
    event.preventDefault();
    const form = event.target;
    if (form.matches("[data-task-form]")) {
      const data = Object.fromEntries(new FormData(form));
      const result = await config.api("/api/task-create", { projectRoot: projectRoot(), agent: data.agent, title: data.title, phase: data.phase || "", scope: { kind: "phase" }, source: "manual", mentionText: data.mentionText || "" });
      if (!result.ok) throw new Error(result.error || "Görev oluşturulamadı.");
      config.setStatus("Görev oluşturuldu: " + result.task.id + " → " + (result.mentions && result.mentions.length ? "@" + result.mentions.join(", @") : data.agent));
      render();
      return;
    }
    if (form.matches("[data-entity-form]")) { await entitySubmit(form); return; }
    if (form.matches("[data-member-form]")) { const data = Object.fromEntries(new FormData(form)); state.collaboration.members.push({ id: uid("member"), name: data.name, role: data.role }); await saveState("Ekip üyesi kaydedildi."); return; }
    if (form.matches("[data-comment-form]")) {
      const data = Object.fromEntries(new FormData(form));
      const chapter = config.getChapter();
      state.comments.push({ id: uid("comment"), chapter: chapter?.filename || "", quote: data.quote, text: data.text, author: state.collaboration.current_name, role: state.collaboration.current_role, status: "open", created_at: nowIso(), replies: [] });
      await saveState("Yeni yorum kaydedildi.");
      return;
    }
    if (form.matches("[data-change-form]")) {
      const data = Object.fromEntries(new FormData(form));
      const chapter = config.getChapter();
      state.changes.push({ id: uid("change"), chapter: chapter?.filename || "", original: data.original, replacement: data.replacement, author: state.collaboration.current_name, role: state.collaboration.current_role, status: "pending", created_at: nowIso() });
      await saveState("Değişiklik önerisi kaydedildi.");
      return;
    }
    if (form.matches("[data-goal-form]")) {
      const data = Object.fromEntries(new FormData(form));
      state.writing.daily_goal_words = Number(data.daily || 0);
      state.writing.project_goal_words = Number(data.project || 0);
      state.writing.deadline = data.deadline || "";
      await saveState("Yazma hedefleri kaydedildi.");
      return;
    }
    if (form.matches("[data-publication-form]")) {
      const data = Object.fromEntries(new FormData(form));
      state.publication.profile = data.profile;
      state.publication.isbn = String(data.isbn || "").replace(/\D/g, "");
      state.publication.imprint = data.imprint;
      state.publication.language = data.language || "tr-TR";
      await saveState("Yayın kimliği kaydedildi.");
    }
  }

  function mount() {
    if (dialog) return;
    const button = document.createElement("button");
    button.type = "button";
    button.id = "openProfessionalStudioBtn";
    button.textContent = "Profesyonel Araçlar";
    (document.querySelector(".publication-tools") || document.body).prepend(button);
    dialog = document.createElement("dialog");
    dialog.className = "professional-dialog";
    dialog.setAttribute("aria-labelledby", "professionalDialogTitle");
    document.body.append(dialog);
    dialog.addEventListener("click", event => click(event).catch(error => config.setStatus(`Profesyonel araç hatası: ${error.message}`)));
    dialog.addEventListener("submit", event => submit(event).catch(error => config.setStatus(`Profesyonel araç hatası: ${error.message}`)));
    dialog.addEventListener("change", event => { if (event.target.matches("[data-cover-file]")) uploadCover(event.target.files?.[0]).catch(error => config.setStatus(`Kapak yüklenemedi: ${error.message}`)); });
    button.addEventListener("click", () => { if (!projectRoot()) return; render(); dialog.showModal(); if (tab === "publication") loadCover().catch(() => {}); });
    agentRefreshTimer = window.setInterval(() => { if (dialog?.open && tab === "agents") render(); }, 5000);
    render();
  }

  function hydrate(nextState, nextEntities) {
    state = normalize(nextState);
    entities = Object.fromEntries(Object.keys(entityLabels).map(key => [key, clone(nextEntities?.[key] || [])]));
    if (dialog?.open) render();
  }

  function openEntity(kind) {
    if (!projectRoot()) return;
    entityKind = Object.hasOwn(entityLabels, kind) ? kind : "characters";
    tab = "entities";
    editEntity = null;
    render();
    dialog.showModal();
  }

  return { mount, hydrate, openEntity, getState: () => clone(state) };
}

window.KitHubProfessional = { createProfessionalStudio };
