param(
  [string]$Url = "http://127.0.0.1:8765/",
  [string]$ReportPath = ""
)
$ErrorActionPreference = "Stop"
$edge = Get-ChildItem "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $edge) { throw "Microsoft Edge executable not found." }
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) { throw "Node.js is required for the Edge interaction probe." }
if (-not $ReportPath.Trim()) { $ReportPath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path "runtime/browser-e2e-report.json" }
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
    [ordered]@{name="restore-preview";pass=($html -match 'restore-version-preview')}
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
  $probeRaw = & $node.Source $probeScript "http://127.0.0.1:$debugPort" $Url $screenshotPath
  if ($LASTEXITCODE -ne 0) { throw "Browser interaction probe failed with exit code $LASTEXITCODE." }
  $interaction = $probeRaw | ConvertFrom-Json
}
finally {
  if ($edgeProcess -and -not $edgeProcess.HasExited) { Stop-Process -Id $edgeProcess.Id -Force -ErrorAction SilentlyContinue }
  if (Test-Path -LiteralPath $profileRoot -PathType Container) { Remove-Item -LiteralPath $profileRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
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
  $interaction.zoom.changedByKeyboard -eq $true
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
  desktop_accessibility=if($desktopAccessibilityPass){"PASS"}else{"FAIL"}
  mobile_accessibility=if($mobileAccessibilityPass){"PASS"}else{"FAIL"}
  wcag_conformance="AUTOMATED_AA_SUBSET_ONLY"
  notes=@("Headless Edge DOM render and computed accessibility audits were executed at desktop and 390x844 mobile viewport sizes.","Edge DevTools interaction automation verified the skip link, keyboard activation, focus restoration, Escape handling, and preview zoom state.","The automated subset checks language, landmarks, live status semantics, heading order, control names, duplicate IDs, 24px targets, computed text contrast, horizontal overflow, and reduced-motion support.","Manual screen-reader, cognitive, and complete WCAG conformance testing remains required.")
  interaction=$interaction
  cases=$results
}
[IO.File]::WriteAllText($ReportPath,($report|ConvertTo-Json -Depth 20),[Text.UTF8Encoding]::new($true))
if (-not $report.desktop_mobile_dom_pass) { throw "Browser DOM render failed." }
if (-not $report.interactive_automation_proven) { throw "Browser keyboard/focus/zoom interaction probe failed." }
if (-not $accessibilityPass) { throw "Automated accessibility subset probe failed." }
Write-Host "[browser-e2e] PASS desktop/mobile DOM; keyboard/focus/zoom=PASS; desktop/mobile-accessibility-subset=PASS"
Write-Host "[browser-e2e] report=$ReportPath"
Write-Host "[browser-e2e] desktop-screenshot=$($interaction.screenshots.desktop)"
Write-Host "[browser-e2e] mobile-screenshot=$($interaction.screenshots.mobile)"
