param(
  [string]$Url = "http://127.0.0.1:8765/",
  [string]$ReportPath = ""
)
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$edge = Get-ChildItem "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $edge) { throw "Microsoft Edge executable not found." }
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) { throw "Node.js is required for the Edge interaction probe." }
if (-not $ReportPath.Trim()) { $ReportPath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path "runtime/browser-e2e-report.json" }
$visualProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "../../tests/fixtures/sample-project")).Path
$cases = @(@{name="desktop-dom";size="1440,1200"},@{name="mobile-dom";size="390,844"})
$results = @()
foreach ($case in $cases) {
  $previousErrorAction = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $html = (& $edge.FullName --headless=new --disable-gpu --no-first-run "--window-size=$($case.size)" --dump-dom $Url 2>$null | Out-String)
  $ErrorActionPreference = $previousErrorAction
  $checks = @(
    [ordered]@{name="title";pass=($html -match '<title>KitHub Studio</title>')},
    [ordered]@{name="viewport";pass=($html -match 'name="viewport"')},
    [ordered]@{name="wizard-reader";pass=($html -match 'id="wizardReader"')},
    [ordered]@{name="wizard-character-policy";pass=($html -match 'Karakterler / Karakter Politikası')},
    [ordered]@{name="diagnostics";pass=($html -match 'Tanı Paketi')},
    [ordered]@{name="output-target";pass=($html -match 'settingsOutputTarget')},
    [ordered]@{name="restore-preview";pass=($html -match 'restore-version-preview')},
    [ordered]@{name="workflow-rail";pass=($html -match 'data-workflow-step="publish"')},
    [ordered]@{name="ai-writing-assistant";pass=($html -match 'id="aiPromptInput"')},
    [ordered]@{name="publication-matter";pass=($html -match 'id="matterManagerDialog"')},
    [ordered]@{name="cover-studio";pass=($html -match 'id="coverStudioDialog"')},
    [ordered]@{name="publication-preflight";pass=($html -match 'id="runPreflightBtn"')},
    [ordered]@{name="professional-studio";pass=($html -match 'id="openProfessionalStudioBtn"')},
    [ordered]@{name="version-diff-dialog";pass=($html -match 'id="versionDiffDialog"')},
    [ordered]@{name="version-diff-files";pass=($html -match 'id="versionDiffFiles"')},
    [ordered]@{name="scene-manager-dialog";pass=($html -match 'id="sceneManagerDialog"')},
    [ordered]@{name="scene-manager-button";pass=($html -match 'id="sceneManagerBtn"')},
    [ordered]@{name="scene-list";pass=($html -match 'id="sceneManagerList"')},
    [ordered]@{name="quick-jump-dialog";pass=($html -match 'id="quickJumpDialog"')}
  )
  $failed = @($checks | Where-Object { -not $_.pass })
  $results += [ordered]@{name=$case.name;size=$case.size;status=if($failed.Count -eq 0){"PASS"}else{"FAIL"};checks=$checks;failed=@($failed | ForEach-Object { $_.name })}
}

$debugPortProbe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$debugPortProbe.Start()
$debugPort = ([System.Net.IPEndPoint]$debugPortProbe.LocalEndpoint).Port
$debugPortProbe.Stop()
$profileRoot = Join-Path ([IO.Path]::GetTempPath()) ("kithub-edge-e2e-" + [guid]::NewGuid().ToString("N"))
$screenshotPath = Join-Path ([IO.Path]::GetTempPath()) "kithub-studio-interaction.png"
$edgeProcess = $null
try {
  $edgeProcess = Start-Process -FilePath $edge.FullName -ArgumentList @(
    "--headless=new", "--disable-gpu", "--no-first-run", "--remote-debugging-port=$debugPort",
    "--user-data-dir=$profileRoot", "--window-size=1440,1200", "about:blank"
  ) -WindowStyle Hidden -PassThru
  $probeScript = Join-Path $PSScriptRoot "browser_interaction_probe.mjs"
  $probeRaw = & $node.Source $probeScript "http://127.0.0.1:$debugPort" $Url $screenshotPath $visualProjectRoot
  if ($LASTEXITCODE -ne 0) { throw "Browser interaction probe failed with exit code $LASTEXITCODE." }
  $interaction = $probeRaw | ConvertFrom-Json
}
finally {
  if ($edgeProcess -and -not $edgeProcess.HasExited) { Stop-Process -Id $edgeProcess.Id -Force -ErrorAction SilentlyContinue }
  if (Test-Path -LiteralPath $profileRoot -PathType Container) { Remove-Item -LiteralPath $profileRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

$perfPortProbe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$perfPortProbe.Start()
$perfPort = ([System.Net.IPEndPoint]$perfPortProbe.LocalEndpoint).Port
$perfPortProbe.Stop()
$perfProfileRoot = Join-Path ([IO.Path]::GetTempPath()) ("kithub-edge-perf-" + [guid]::NewGuid().ToString("N"))
$perfReportPath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path "runtime/browser-performance-report.json"
$perfEdgeProcess = $null
try {
  $perfEdgeProcess = Start-Process -FilePath $edge.FullName -ArgumentList @(
    "--headless=new", "--disable-gpu", "--no-first-run", "--remote-debugging-port=$perfPort",
    "--user-data-dir=$perfProfileRoot", "--window-size=1440,1200", "about:blank"
  ) -WindowStyle Hidden -PassThru
  $perfReady = $false
  for ($attempt = 0; $attempt -lt 40; $attempt++) {
    Start-Sleep -Milliseconds 250
    try {
      $perfTargets = Invoke-RestMethod -Uri "http://127.0.0.1:$perfPort/json/list" -TimeoutSec 2 -ErrorAction Stop
      if (@($perfTargets | Where-Object { $_.type -eq "page" }).Count -gt 0) { $perfReady = $true; break }
    } catch {}
  }
  if (-not $perfReady) { throw "Edge debug target did not become ready on port $perfPort." }
  $perfScript = Join-Path $PSScriptRoot "browser_performance_probe.mjs"
  $perfRaw = & $node.Source $perfScript $perfPort $Url $perfReportPath
  if ($LASTEXITCODE -ne 0) {
    Write-Host "[browser-e2e] performance probe FAILED; stderr/report below"
    Write-Host ($perfRaw | Out-String)
    if (Test-Path -LiteralPath $perfReportPath -PathType Leaf) { Get-Content -LiteralPath $perfReportPath -Raw }
    throw "Browser performance probe failed with exit code $LASTEXITCODE."
  }
  $performance = $perfRaw | ConvertFrom-Json
}
finally {
  if ($perfEdgeProcess -and -not $perfEdgeProcess.HasExited) { Stop-Process -Id $perfEdgeProcess.Id -Force -ErrorAction SilentlyContinue }
  if (Test-Path -LiteralPath $perfProfileRoot -PathType Container) { Remove-Item -LiteralPath $perfProfileRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
$performancePass = (
  [string]$performance.overall -eq "PASS" -and
  [string]$performance.scores.fcp -in @("PASS","NO_DATA") -and
  [string]$performance.scores.lcp -in @("PASS","NO_DATA") -and
  [string]$performance.scores.domNodes -eq "PASS" -and
  [string]$performance.scores.layoutDuration -eq "PASS" -and
  [string]$performance.scores.reflowDuration -eq "PASS" -and
  [string]$performance.scores.scriptDuration -eq "PASS" -and
  [string]$performance.scores.longTasks -eq "PASS" -and
  [string]$performance.scores.consoleErrors -eq "PASS" -and
  [string]$performance.scores.reducedMotion -eq "PASS" -and
  [string]$performance.scores.mainLandmark -eq "PASS"
)
$interactionPass = (
  $interaction.identity.url -like "$($Url.TrimEnd('/'))*" -and
  $interaction.identity.title -eq "KitHub Studio" -and
  [int]$interaction.identity.textLength -gt 500 -and
  $interaction.identity.overlay -ne $true -and
  @($interaction.consoleIssues).Count -eq 0 -and
  $interaction.focus.skipLinkFocused -eq $true -and
  $interaction.focus.skipTargetFocused -eq $true -and
  $interaction.focus.buttonFocusedBeforeActivation -eq $true -and
  $interaction.focus.entered -eq $true -and
  $interaction.focus.escaped -eq $true -and
  $interaction.zoom.changedByKeyboard -eq $true -and
  $interaction.editorCore.dirtyState.saveState -eq "Kaydedilmedi" -and
  $interaction.editorCore.dirtyState.recoveryStored -eq $true -and
  $interaction.editorCore.dirtyState.spellcheck -eq $true -and
  $interaction.editorCore.dirtyState.richSpellcheck -eq $true -and
  $interaction.editorCore.dirtyState.mode -eq "rich" -and
  $interaction.editorCore.dirtyState.sourceHidden -eq $true -and
  $interaction.editorCore.dirtyState.schemaVersion -eq "1.0.0" -and
  $interaction.editorCore.findShortcut.open -eq $true -and
  $interaction.editorCore.findShortcut.focused -eq "findInput" -and
  $interaction.editorCore.findSelection.selected -eq "KitHub" -and
  $interaction.editorCore.replaceShortcut.open -eq $true -and
  $interaction.editorCore.replaceShortcut.replaceVisible -eq $true -and
  $interaction.editorCore.saveShortcut.recoveryStored -eq $true -and
  [int]$interaction.editorCore.editorialRules.findingCount -ge 4 -and
  $interaction.editorCore.editorialRules.settingsPresent -eq $true -and
  $interaction.editorCore.editorialRules.mutatesWithoutApproval -ne $true -and
  [int]$interaction.editorCore.findSearchOptions.defaultCount -eq 2 -and
  [int]$interaction.editorCore.findSearchOptions.caseCount -eq 2 -and
  [int]$interaction.editorCore.findSearchOptions.wholeCount -eq 1 -and
  [int]$interaction.editorCore.findSearchOptions.regexCount -eq 2 -and
  [int]$interaction.editorCore.findSearchOptions.wholeReplaceCount -eq 1 -and
  $interaction.editorCore.findSearchOptions.wholeReplaceApplied -eq $true -and
  $interaction.editorCore.quickJump.opened -eq $true -and
  [int]$interaction.editorCore.quickJump.filteredCount -eq 1 -and
  [int]$interaction.editorCore.quickJump.jumpedIndex -eq 1 -and
  $interaction.editorCore.quickJump.closedAfterJump -eq $true -and
  [int]$interaction.editorCore.spellcheck.enabledFindings -ge 5 -and
  [int]$interaction.editorCore.spellcheck.disabledFindings -eq 0 -and
  [int]$interaction.editorCore.spellcheck.ignoredFindings -eq ([int]$interaction.editorCore.spellcheck.enabledFindings - 1) -and
  $interaction.editorCore.spellcheck.dictionaryHasWord -eq $true -and
  $interaction.editorCore.spellcheck.jumped -eq $true -and
  $interaction.editorCore.spellcheck.editorialRender -eq $true -and
  [int]$interaction.editorCore.lineDiff.addedCount -eq 2 -and
  [int]$interaction.editorCore.lineDiff.removedCount -eq 1 -and
  [int]$interaction.editorCore.lineDiff.contextCount -eq 3 -and
  @($interaction.editorCore.lineDiff.removedText) -contains "satır2" -and
  @($interaction.editorCore.lineDiff.addedText) -contains "satır2 DEĞİŞTİ" -and
  @($interaction.editorCore.lineDiff.addedText) -contains "satır5 YENİ" -and
  $interaction.editorCore.lineDiff.lineNumbers -eq $true -and
  [int]$interaction.editorCore.versionDiffUi.fileButtons -eq 2 -and
  [int]$interaction.editorCore.versionDiffUi.changedChip -eq 1 -and
  [int]$interaction.editorCore.versionDiffUi.unchangedChip -eq 1 -and
  [int]$interaction.editorCore.versionDiffUi.addedLines -eq 2 -and
  [int]$interaction.editorCore.versionDiffUi.removedLines -eq 1 -and
  $interaction.editorCore.versionDiffUi.diffMetaFilled -eq $true -and
  $interaction.editorCore.versionDiffUi.selectedMarked -eq $true -and
  $interaction.editorCore.versionDiffUi.opened -eq $true -and
  $interaction.editorCore.versionDiffUi.closed -eq $true -and
  [int]$interaction.editorCore.sceneParse.count -eq 3 -and
  $interaction.editorCore.sceneParse.roundtrip -eq $true -and
  @($interaction.editorCore.sceneParse.titles) -contains "İkinci Sahne" -and
  @($interaction.editorCore.sceneParse.bodies) -contains "İkinci sahne metni" -and
  $interaction.editorCore.sceneManagerUi.firstOpen -eq $true -and
  [int]$interaction.editorCore.sceneManagerUi.rowsInitial -eq 2 -and
  [int]$interaction.editorCore.sceneManagerUi.rowsAfterAdd -eq 3 -and
  @($interaction.editorCore.sceneManagerUi.titlesAfterMove) -contains "İkinci" -and
  [string]$interaction.editorCore.sceneManagerUi.progressWidth -eq "1%" -and
  [int]$interaction.editorCore.sceneManagerUi.appliedSceneCount -eq 3 -and
  $interaction.editorCore.sceneManagerUi.appliedTargets.'ep001.md' -contains 500 -and
  $interaction.editorCore.sceneManagerUi.dialogClosed -eq $true -and
  $interaction.editorCore.publishingCompatibility.before.font -eq "Garamond" -and
  $interaction.editorCore.publishingCompatibility.before.pageSize -eq "A5 (148 x 210 mm)" -and
  $interaction.editorCore.publishingCompatibility.before.design -eq "classicFrame" -and
  $interaction.editorCore.publishingCompatibility.optInApplied -eq $true -and
  $interaction.editorCore.publishingCompatibility.metricsPreserved -eq $true -and
  $interaction.editorCore.publishingCompatibility.classicRestored -eq $true -and
  @($interaction.editorCore.publishingCompatibility.outputProfiles).Count -eq 4 -and
  $interaction.editorCore.publishingCompatibility.defaultOutputProfile -eq "docx" -and
  [int]$interaction.editorCore.publicationUx.workflowCount -eq 6 -and
  $interaction.editorCore.publicationUx.publishStepActive -eq $true -and
  [double]$interaction.editorCore.publicationUx.promptMinHeight -ge 190 -and
  [int]$interaction.editorCore.publicationUx.promptMaxLength -eq 4000 -and
  [int]$interaction.editorCore.publicationUx.promptContextCount -eq 3 -and
  $interaction.editorCore.publicationUx.matterOpen -eq $true -and
  [int]$interaction.editorCore.publicationUx.matterColumns -eq 2 -and
  $interaction.editorCore.publicationUx.coverOpen -eq $true -and
  $interaction.editorCore.publicationUx.coverSizeCalculated -eq $true -and
  $interaction.editorCore.publicationUx.preflightAvailable -eq $true -and
  $interaction.editorCore.professionalUx.open -eq $true -and
  [int]$interaction.editorCore.professionalUx.tabs -eq 4 -and
  [int]$interaction.editorCore.professionalUx.entityKinds -eq 4 -and
  $interaction.editorCore.professionalUx.reviewTools -eq $true -and
  $interaction.editorCore.professionalUx.publicationTools -eq $true -and
  [int]$interaction.editorCore.controlContracts.visibleButtons -gt 20 -and
  @($interaction.editorCore.controlContracts.unhandled).Count -eq 0 -and
  $interaction.editorCore.paginationFlow.mode -eq "measured-dom" -and
  [int]$interaction.editorCore.paginationFlow.totalPages -gt 12 -and
  [int]$interaction.editorCore.paginationFlow.limitedPages -eq 12 -and
  [int]$interaction.editorCore.paginationFlow.allRenderedPages -eq [int]$interaction.editorCore.paginationFlow.totalPages -and
  [int]$interaction.editorCore.paginationFlow.paragraphSplits -gt 0 -and
  $interaction.editorCore.paginationFlow.hasShowAll -eq $true -and
  [int]$interaction.editorCore.paginationFlow.repeatedChapterTitles -eq 1 -and
  [int]$interaction.editorCore.paginationFlow.runningHeaders -eq ([int]$interaction.editorCore.paginationFlow.totalPages - 1) -and
  [int]$interaction.editorCore.paginationFlow.overflowPages -eq 0 -and
  [int]$interaction.editorCore.paginationFlow.strandedHeadings -eq 0 -and
  [int]$interaction.editorCore.paginationFlow.minimumContinuationLines -ge 3 -and
$interaction.editorCore.chapterSwitchGuard.dialogSeen -eq $true -and
  $interaction.editorCore.chapterSwitchGuard.cancelBlocked -eq $true -and
  $interaction.editorCore.chapterSwitchGuard.discardSwitched -eq $true -and
  $interaction.editorCore.chapterSwitchGuard.discardTextPreserved -eq $true -and
$interaction.editorCore.chapterManagerDialog.open -eq $true -and
  $interaction.editorCore.chapterManagerDialog.title -eq "Yeni bölüm" -and
  $interaction.editorCore.chapterManagerDialog.addEnabled -eq $true -and
  [int]$interaction.editorCore.chapterManagerDialog.draggableRows -eq 2 -and
  $interaction.editorCore.chapterManagerDialog.focused -eq "chapterTitleInput" -and
  $interaction.editorCore.chapterPlanUi.dialogOpen -eq $true -and
  $interaction.editorCore.chapterPlanUi.chipPresent -eq $true -and
  $interaction.editorCore.chapterPlanUi.chipStatus -eq "draft" -and
  $interaction.editorCore.chapterPlanUi.chipLabel -eq "Taslak" -and
  $interaction.editorCore.chapterPlanUi.prefill.status -eq "draft" -and
  [int]$interaction.editorCore.chapterPlanUi.prefill.target -eq 1200 -and
  $interaction.editorCore.chapterPlanUi.prefill.pov -eq "3. kişi" -and
  $interaction.editorCore.chapterPlanUi.prefill.setting -eq "Eski ev" -and
  $interaction.editorCore.chapterPlanUi.prefill.summary -eq "Defne içeri girer" -and
  $interaction.editorCore.chapterPlanUi.prefill.subtitle -eq "ep001.md" -and
  $interaction.editorCore.chapterPlanUi.savePayload.filename -eq "ep001.md" -and
  $interaction.editorCore.chapterPlanUi.saveStatus -eq "editing" -and
  [int]$interaction.editorCore.chapterPlanUi.saveTarget -eq 1800 -and
  $interaction.editorCore.chapterPlanUi.closedAfterSave -eq $true -and
  $interaction.editorCore.chapterPlanUi.activePlanUpdated -eq $true -and
  $interaction.editorCore.chapterArchiveUi.dialogOptionsSeen -contains "Arşivle" -and
  $interaction.editorCore.chapterArchiveUi.archivePayload.filename -eq "ep001.md" -and
  $interaction.editorCore.chapterArchiveUi.archivePayload.action -eq "archive" -and
  $interaction.editorCore.chapterArchiveUi.archiveRemoved -eq $true -and
  $interaction.editorCore.chapterTreeUi.treeRendered -eq $true -and
  $interaction.editorCore.chapterTreeUi.firstRowTitle -eq "Birinci" -and
  $interaction.editorCore.chapterTreeUi.firstRowChip -eq "editing" -and
  $interaction.editorCore.chapterTreeUi.sceneLabel -eq "▸ Kapıda" -and
  [int]$interaction.editorCore.chapterTreeUi.timelineEntries -eq 2 -and
  $interaction.editorCore.chapterTreeUi.timelineFirst -eq "Birinci" -and
  @($interaction.editorCore.chapterTreeUi.timelineDates) -contains "1989-01-15" -and
  @($interaction.editorCore.chapterTreeUi.timelineDates) -contains "1989-06-01" -and
  $interaction.editorCore.chapterTreeUi.currentMarked -eq $true -and
  $interaction.editorCore.mobileLayout.toolbarOverflow -ne $true -and
  $interaction.editorCore.mobileLayout.settingsVisible -eq $true -and
  $interaction.editorCore.mobileProfessionalLayout.open -eq $true -and
  $interaction.editorCore.mobileProfessionalLayout.fitsViewport -eq $true -and
  $interaction.editorCore.mobileProfessionalLayout.horizontalOverflow -ne $true -and
  $interaction.editorCore.mobileProfessionalLayout.railVisible -eq $true
)
function Test-AccessibilityAudit([object]$Audit) {
  return (
    $Audit.lang -eq "tr" -and
    [int]$Audit.mainCount -ge 1 -and
    [int]$Audit.h1Count -eq 1 -and
    [int]$Audit.liveRegionCount -ge 1 -and
    $Audit.skipLinkPresent -eq $true -and
    @($Audit.duplicateIds).Count -eq 0 -and
    @($Audit.unnamedControls).Count -eq 0 -and
    @($Audit.headingSkips).Count -eq 0 -and
    @($Audit.smallTargets).Count -eq 0 -and
    @($Audit.contrastFailures).Count -eq 0 -and
    $Audit.horizontalOverflow -ne $true -and
    $Audit.reducedMotionRulePresent -eq $true
  )
}
$desktopAccessibilityPass = Test-AccessibilityAudit $interaction.accessibility.desktop
$mobileAccessibilityPass = (
  (Test-AccessibilityAudit $interaction.accessibility.mobile) -and
  $interaction.mobileIdentity.url -like "$($Url.TrimEnd('/'))*" -and
  $interaction.mobileIdentity.title -eq "KitHub Studio" -and
  [int]$interaction.mobileIdentity.textLength -gt 500 -and
  $interaction.mobileIdentity.overlay -ne $true -and
  [int]$interaction.accessibility.mobile.viewport.width -eq 390
)
$accessibilityPass = $desktopAccessibilityPass -and $mobileAccessibilityPass
$report = [ordered]@{
  schema_version="1.3.0"
  report_type="browser_e2e_render"
  generated_at=(Get-Date).ToString("o")
  url=$Url
  desktop_mobile_dom_pass=(@($results|Where-Object status -eq "FAIL").Count -eq 0)
  interactive_automation_proven=$interactionPass
  keyboard_focus_zoom=if($interactionPass){"PASS"}else{"FAIL"}
accessibility_probe=if($accessibilityPass){"PASS"}else{"FAIL"}
  performance_probe=if($performancePass){"PASS"}else{"FAIL"}
  desktop_accessibility=if($desktopAccessibilityPass){"PASS"}else{"FAIL"}
  mobile_accessibility=if($mobileAccessibilityPass){"PASS"}else{"FAIL"}
  wcag_conformance="AUTOMATED_AA_SUBSET_ONLY"
  notes=@("Headless Edge DOM render and computed accessibility audits were executed at desktop and 390x844 mobile viewport sizes.","Edge DevTools interaction automation verified the structured editor, workflow rail, expanded AI prompt, front/back matter manager, cover studio, preflight access, Turkish editorial rules and spelling engine, find search options, quick chapter jump, measured pagination, dirty-state recovery, Ctrl+S/F/H/K, version diff rendering, scene management, mobile toolbar fit, settings access, focus restoration, Escape handling, and preview zoom state.","The automated subset checks language, landmarks, live status semantics, heading order, control names, duplicate IDs, 24px targets, computed text contrast, horizontal overflow, and reduced-motion support.","The performance subset measures FCP/LCP, DOM node budget, layout/reflow/script duration, long-task count and console errors under 4x CPU throttling; reduced-motion and main landmark are also enforced.","Manual screen-reader, cognitive, and complete WCAG conformance testing remains required.")
  interaction=$interaction
  performance=$performance
  cases=$results
}
[IO.File]::WriteAllText($ReportPath,($report|ConvertTo-Json -Depth 20),[Text.UTF8Encoding]::new($true))
if (-not $report.desktop_mobile_dom_pass) { throw "Browser DOM render failed." }
if (-not $report.interactive_automation_proven) { throw "Browser keyboard/focus/zoom interaction probe failed." }
if (-not $accessibilityPass) { throw "Automated accessibility subset probe failed." }
if (-not $performancePass) { throw "Automated performance subset probe failed." }
Write-Host "[browser-e2e] PASS workflow, AI writing, publication tools, structured editor, measured pagination, editor-core and chapter-manager UI; desktop/mobile DOM, accessibility subset and performance subset=PASS"
Write-Host "[browser-e2e] report=$ReportPath"
Write-Host "[browser-e2e] desktop-screenshot=$($interaction.screenshots.desktop)"
Write-Host "[browser-e2e] matter-screenshot=$($interaction.screenshots.matter)"
Write-Host "[browser-e2e] cover-screenshot=$($interaction.screenshots.cover)"
Write-Host "[browser-e2e] professional-screenshot=$($interaction.screenshots.professional)"
Write-Host "[browser-e2e] mobile-screenshot=$($interaction.screenshots.mobile)"
Write-Host "[browser-e2e] professional-mobile-screenshot=$($interaction.screenshots.professionalMobile)"
