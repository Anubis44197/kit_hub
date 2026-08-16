param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path,
  [switch]$KeepFixture
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$pandoc = Get-Command pandoc -ErrorAction Stop
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("kithub-docx-roundtrip-" + [guid]::NewGuid().ToString("N"))
$projectRoot = Join-Path $fixtureRoot "project"
$episodeDir = Join-Path $projectRoot "episode"
$stateDir = Join-Path $projectRoot "revision/_state"
$runtimeDir = Join-Path $projectRoot "runtime"
$sourceDir = Join-Path $fixtureRoot "source"
New-Item -ItemType Directory -Path $episodeDir,$stateDir,$runtimeDir,$sourceDir -Force | Out-Null

function Write-Utf8([string]$Path, [string]$Value) {
  [IO.File]::WriteAllText($Path, $Value, [Text.UTF8Encoding]::new($true))
}
function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

$marker = [ordered]@{ schema_version = "1.0.0"; project_name = "DOCX Round Trip Test" }
Write-Utf8 (Join-Path $projectRoot ".kithub-project.json") ($marker | ConvertTo-Json)
$imagePath = Join-Path $sourceDir "sample.png"
[IO.File]::WriteAllBytes($imagePath, [Convert]::FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Z2S8AAAAASUVORK5CYII="))
$markdownPath = Join-Path $sourceDir "fixture.md"
$fixtureMarkdown = Join-Path $PSScriptRoot "fixtures/docx-roundtrip-source.md"
Copy-Item -LiteralPath $fixtureMarkdown -Destination $markdownPath -Force
$docxPath = Join-Path $sourceDir "structured-fixture.docx"
& $pandoc.Source "--from=markdown+raw_attribute" "--resource-path=$sourceDir" "--output=$docxPath" $markdownPath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $docxPath -PathType Leaf)) { throw "DOCX fixture generation failed." }

$probe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$probe.Start()
$port = ([Net.IPEndPoint]$probe.LocalEndpoint).Port
$probe.Stop()
$stdout = Join-Path $fixtureRoot "bridge.stdout.log"
$stderr = Join-Path $fixtureRoot "bridge.stderr.log"
$bridgeProcess = $null
try {
  $bridgeProcess = Start-Process -FilePath "powershell.exe" -ArgumentList @(
    "-NoProfile","-ExecutionPolicy","Bypass","-File",(Join-Path $RepoRoot "scripts/studio_bridge.ps1"),
    "-RepoRoot",$RepoRoot,"-Port",$port
  ) -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
  $baseUrl = "http://127.0.0.1:$port"
  $ready = $false
  for ($attempt = 0; $attempt -lt 50; $attempt++) {
    Start-Sleep -Milliseconds 150
    try {
      $health = Invoke-RestMethod -Uri "$baseUrl/api/health" -TimeoutSec 2
      if ($health.ok) { $ready = $true; break }
    } catch {}
  }
  if (-not $ready) { throw "Fixture Bridge did not become ready." }
  $session = Invoke-RestMethod -Uri "$baseUrl/api/session" -TimeoutSec 5
  $payload = [ordered]@{
    filename = "structured-fixture.docx"
    contentBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($docxPath))
    projectRoot = $projectRoot
  }
  $jsonBytes = [Text.Encoding]::UTF8.GetBytes(($payload | ConvertTo-Json -Depth 5 -Compress))
  $result = Invoke-RestMethod -Uri "$baseUrl/api/import-docx" -Method Post -Headers @{ "X-KitHub-Session" = $session.token } -ContentType "application/json; charset=utf-8" -Body $jsonBytes -TimeoutSec 30
  Write-Utf8 (Join-Path $fixtureRoot "import-result.json") ($result | ConvertTo-Json -Depth 20)

  Assert-True ($result.ok -eq $true) "DOCX import did not return ok=true."
  Assert-True ($result.importReport.mode -eq "ooxml-structured") "Structured OOXML mode was not reported."
  Assert-True ($result.text -match "(?m)^# .+$") "Heading 1 was not preserved."
  Assert-True ($result.text -match "(?m)^## .+$") "Heading 2 was not preserved."
  Assert-True ($result.text -match "\*\*[^*\r\n]+\*\*") "Bold run was not preserved."
  Assert-True ($result.text.Contains("_italik metin_")) "Italic run was not preserved."
  Assert-True ($result.text.Contains("](https://example.com/kithub)")) "Hyperlink was not preserved."
  Assert-True ($result.text.Contains("- Birinci madde")) "Bullet list was not preserved."
  Assert-True ($result.text.Contains("| Alan |")) "Table header was not preserved."
  $turkishWord = "T" + [char]0x00FC + "rk" + [char]0x00E7 + "e"
  Assert-True ($result.text.Contains($turkishWord)) "UTF-8 Turkish text was not preserved."
  Assert-True ($result.text.Contains("<!-- page-break -->")) "Page break was not preserved."
  Assert-True ($result.text -match "\[\^\d+\]") "Footnote reference was not preserved."
  Assert-True ([int]$result.importReport.counts.images -eq 1) "Embedded image count mismatch."
  Assert-True ([int]$result.importReport.counts.tables -eq 1) "Table count mismatch."
  Assert-True ([int]$result.importReport.counts.footnotes -eq 1) "Footnote count mismatch."
  Assert-True ([int]$result.importReport.counts.page_breaks -ge 1) "Page break count mismatch."
  Assert-True ([bool]$result.importReport.preserved.images) "Image preservation was not reported."
  Assert-True ([bool]$result.importReport.media_root) "Extracted media root was not reported."
  $mediaPath = Join-Path $projectRoot (($result.media[0].relative_path -replace "/", "\"))
  Assert-True (Test-Path -LiteralPath $mediaPath -PathType Leaf) "Embedded image was not extracted into the project."
  Assert-True ((Get-Item -LiteralPath $mediaPath).Length -gt 0) "Extracted image is empty."
  Write-Host "[studio-bridge-docx-roundtrip] PASS headings; runs; links; lists; tables; image extraction; footnote; page break"
  if ($KeepFixture) {
    Write-Host "[studio-bridge-docx-roundtrip] fixture=$fixtureRoot"
    Write-Host "[studio-bridge-docx-roundtrip] docx=$docxPath"
  }
}
finally {
  if ($bridgeProcess -and -not $bridgeProcess.HasExited) { Stop-Process -Id $bridgeProcess.Id -Force -ErrorAction SilentlyContinue }
  if (-not $KeepFixture -and (Test-Path -LiteralPath $fixtureRoot -PathType Container)) {
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
  }
}
