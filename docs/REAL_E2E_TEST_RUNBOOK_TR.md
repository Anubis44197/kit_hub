# KitHub Gercek E2E Test Runbook (TR)

## Amac
Bu belge, temiz klondan baslayarak KitHub'in gercekten calisip calismadigini adim adim dogrulamak icindir.

## Test Ortami
- Repo: `C:\Users\90535\Desktop\kit_hub_clean_test`
- Commit: `f97f9c1`
- Tarih: `2026-04-20`

## Asama 0 - Temiz Kurulum
1. Depoyu klonla.
2. Kurulumu calistir:
   - `powershell -ExecutionPolicy Bypass -File scripts/install.ps1 -ProjectRoot .`
3. Beklenen:
   - `runtime/runner-config.json`
   - `runtime/approvals/design-freeze.json`
   - `runtime/approvals/rewrite-approval.json`
   - `runtime/approvals/export-approval.json`

## Asama 1 - Sistem Saglik Testi
1. PowerShell readiness:
   - `powershell -ExecutionPolicy Bypass -File scripts/ci/final_readiness_check.ps1`
2. Bash readiness:
   - `bash scripts/ci/final_readiness_check.sh`
3. Beklenen:
   - Her iki test de PASS.

## Asama 2 - Gate Dogrulama (Zorunlu)
1. Propose fase testi:
   - `powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -FromPhase intake -ToPhase intake -NoWait`
2. Beklenen:
   - Propose artifact yoksa FAIL vermeli.
3. Create fase testi:
   - `powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -FromPhase create -ToPhase create -NoWait`
4. Beklenen:
   - Approval yoksa `BLOCKED` vermeli.

## Asama 3 - Windsurf Gercek Uretim Testi
Asagidaki promptlari IDE'ye sirasiyla ver.

### Prompt A - Propose
`Turkce psikolojik gerilim turunde 3 farkli roman onerisi hazirla. Her biri ayri bir ana catismaya sahip olsun. En guclu olanı secip adini net yaz.`

Kontrol:
- `design/01_proposals.md` var mi?
- Secilen proje icin `design/<proje>_proposal.md` var mi?

### Prompt B - Design Big
`Sectigimiz proje icin buyuk tasarim asamasini tamamla: dunya kurallari, karakter cekirdekleri ve olay orgusu kancalari net olsun.`

Kontrol:
- `design/01_concept_bootstrap.md`
- `design/02_character_core.md`
- `design/03_macro_plot_hooks.md`
- `design/04_book_plan.md`
- `design/05_chapter_plan.md`
- `design/06_layout_plan.md`
- `novel-config.md`
- `revision/_state/book-plan.json`
- `revision/_state/chapter-plan.json`
- `revision/_state/layout-plan.json`
- `revision/_state/longform-plan.json`
- `revision/_state/character-state.json`
- `revision/_state/plot-ledger.json`
- `revision/_state/continuity-ledger.json`

### Prompt C - Design Small (Atlama Yasak)
`Ayni proje icin design-small asamasini eksiksiz tamamla. Sahne plani, karakter detaylari ve plot detaylari dosya olarak olussun. Atlama yapma.`

Kontrol:
- `runtime/approvals/book-plan-approval.json` onayli olmali
- `revision/_state/book-plan.json`
- `revision/_state/chapter-plan.json`
- `revision/_state/layout-plan.json`
- `design/*scene_plan*.md`
- `design/*_character-detail_*.md`
- `design/*_plot-detail_*.md`

### Prompt D - Create
`Romanin ilk bolumunu guclu bir psikolojik gerilim olarak yaz. Tekrarli cumlelerden kac, duygusal derinlik ve sahneleme guclu olsun.`

Kontrol:
- `episode/ep001.md`
- `revision/*tdk-polisher*issues*.json`
- `revision/*quality-verifier*.md`
- `revision/_state/book-plan.json`
- `revision/_state/chapter-plan.json`
- `revision/_state/layout-plan.json`
- `character_count` alt limitin altindaysa PASS verilmemeli.

### Prompt E - Polish
`Metni cilala: TDK uyumu, ritim, anlatim akiciligi, tekrar temizligi ve kitap duzeni iyilestirilsin.`

Kontrol:
- `revision/*tdk-polisher*`
- `revision/*tdk-layout*`
- `revision/*revision-reviewer*.md`

### Prompt F - Rewrite
`Eger kalite raporunda zayif nokta varsa metni yeniden yaz ve psikolojik gerilim katmanlarini derinlestir.`

Kontrol:
- `revision/*rewrite*report*.md`
- `revision/*quality-verifier*.md`

### Prompt G - Export Word
`Final metni Word olarak disa aktar. Cikti gercek DOCX olsun.`

Kontrol:
- `export/*.docx`
- Dosya basligi byte olarak `50 4B` olmali (ZIP/DOCX).

## Asama 4 - Kanit Zorunlulugu
Calisma tamamlandi denmesi icin asagidaki kanitlar zorunlu:
- `runtime/current-run.json`
- `runtime/runs/RUN-*/run-summary.json`
- `runtime/runs/RUN-*/evidence/*.json`
- final metin yolu
- final docx yolu + byte boyutu

Kanit yoksa calisma "tamamlandi" sayilmaz.

## Bu Oturumda Gerceklesen Dogrulama Sonuclari
- Kurulum: PASS
- PowerShell readiness: PASS
- Bash readiness: PASS (CRLF->LF duzeltmesi sonrasi)
- Propose gate: PASS (beklendigi gibi artifact yoksa FAIL)
- Create gate: PASS (beklendigi gibi approval yoksa BLOCKED)

## Not
Bu runbook'un amaci "gorunuste tamamlandi" yerine "kanitli tamamlandi" standardini zorlamaktir.
