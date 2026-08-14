import "./studio-professional.css";

const clone = value => JSON.parse(JSON.stringify(value));
const uid = prefix => `${prefix}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
const html = value => String(value ?? "").replace(/[&<>"']/g, character => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[character]));
const nowIso = () => new Date().toISOString();
const roles = { author: "Yazar", editor: "Editör", reviewer: "Okur", admin: "Yönetici" };
const entityLabels = { characters: "Karakterler", locations: "Mekânlar", plot: "Olay Örgüsü", research: "Araştırma" };

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

  const tabTitle = () => ({ entities: "Kitap Varlıkları", review: "Yorumlar ve Değişiklikler", writing: "Hedefler ve Oturumlar", publication: "Yayın Kimliği ve Kapak" }[tab]);

  function shell() {
    const tabs = [["entities","Varlıklar"],["review","Editörlük"],["writing","Yazma Hedefleri"],["publication","Yayın Kimliği"]];
    return `<div class="professional-shell">
      <aside class="professional-rail"><strong>Profesyonel Araçlar</strong><div class="professional-tabs" role="tablist" aria-label="Profesyonel araç bölümleri">
        ${tabs.map(([key,label]) => `<button type="button" role="tab" data-prof-tab="${key}" aria-selected="${tab === key}">${label}</button>`).join("")}
      </div></aside>
      <section class="professional-main"><header class="professional-head"><h2 id="professionalDialogTitle">${tabTitle()}</h2><button type="button" class="ghost" data-prof-close aria-label="Profesyonel araçları kapat">×</button></header><div class="professional-body" data-prof-body></div></section>
    </div>`;
  }

  function entityForm() {
    const item = editEntity || {};
    const detailLabel = entityKind === "characters" ? "Karakter yayı / durum" : entityKind === "locations" ? "İlk göründüğü bölüm" : entityKind === "plot" ? "Durum" : "Kaynak";
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
    return `<div class="professional-section-head"><div><h3>Kitap dünyasını tek yerden yönetin</h3><p>Kayıtlar doğrudan proje state dosyalarına atomik olarak yazılır.</p></div></div>
      <div class="professional-kind-tabs">${Object.entries(entityLabels).map(([key,label]) => `<button type="button" data-entity-kind="${key}" aria-pressed="${entityKind === key}">${label} <span>${(entities[key] || []).length}</span></button>`).join("")}</div>
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

  function render() {
    if (!dialog) return;
    dialog.innerHTML = shell();
    const body = dialog.querySelector("[data-prof-body]");
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
    if (event.target.closest("[data-apply-matter-templates]")) {
      await config.applyMatterTemplates({ ...state.publication, author: state.collaboration.current_name });
      return;
    }
  }

  async function submit(event) {
    event.preventDefault();
    const form = event.target;
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
