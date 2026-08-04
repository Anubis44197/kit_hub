param(
  [string]$Url = "http://127.0.0.1:8765/",
  [string]$ReportPath = ""
)
$ErrorActionPreference = "Stop"
$edge = Get-ChildItem "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $edge) { throw "Microsoft Edge executable not found." }
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
    [ordered]@{name="diagnostics";pass=($html -match 'Tanı Paketi')},
    [ordered]@{name="output-target";pass=($html -match 'settingsOutputTarget')},
    [ordered]@{name="restore-preview";pass=($html -match 'restore-version-preview')}
  )
  $failed = @($checks | Where-Object { -not $_.pass })
  $results += [ordered]@{name=$case.name;size=$case.size;status=if($failed.Count -eq 0){"PASS"}else{"FAIL"};checks=$checks;failed=@($failed | ForEach-Object { $_.name })}
}
$report = [ordered]@{
  schema_version="1.0.0"
  report_type="browser_e2e_render"
  generated_at=(Get-Date).ToString("o")
  url=$Url
  desktop_mobile_dom_pass=(@($results|Where-Object status -eq "FAIL").Count -eq 0)
  interactive_automation_proven=$false
  keyboard_focus_zoom_wcag="UNKNOWN"
  notes=@("Headless Edge DOM render was executed at desktop and mobile viewport sizes.","Interactive keyboard/focus/zoom/WCAG evidence requires a controllable browser session; no PASS is claimed for those checks.")
  cases=$results
}
[IO.File]::WriteAllText($ReportPath,($report|ConvertTo-Json -Depth 20),[Text.UTF8Encoding]::new($true))
if (-not $report.desktop_mobile_dom_pass) { throw "Browser DOM render failed." }
Write-Host "[browser-e2e] PASS desktop/mobile DOM; interactive keyboard/focus/zoom=UNKNOWN"
Write-Host "[browser-e2e] report=$ReportPath"