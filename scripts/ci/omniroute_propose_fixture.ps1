[CmdletBinding()]
param(
  [string]$ProjectRoot = (Get-Location).Path,
  [string]$GatewayBaseUrl = "http://127.0.0.1:8787",
  [string]$Model = "auto/fast",
  [string]$ApiKey = $env:OMNIROUTE_API_KEY,
  [int]$TimeoutSeconds = 240
)

# OmniRoute uzerinden GERCEK propose cagrisi (dusuk riskli fixture):
# gateway /v1/chat/completions -> kitap onerileri JSON donusu beklenir.
# Adapter enabled=true oncesindeki son dogrulama kapisi; fail-closed calisir.

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$reportDir = Join-Path $ProjectRoot "runtime/fixture-reports"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

$prompt = @"
You are a KitHub propose-phase agent. Return ONLY strict JSON, no markdown fences:
{"files":[{"path":"_workspace/01_proposals.md","content":"..."}]}
The content must be Turkish, at least 500 characters, containing three alternative
book proposals (numbered headings and a short pitch for each) for this request:
- Tur: Psikolojik gizem romani
- Konu: Sifreli bir defterin aile sirrini aciga cikarmasi.
- Karakterler: Defne Aral, sahaf Rauf, gazeteci Cem ve Nermin.
"@

$body = @{
  model = $Model
  temperature = 0.3
  max_tokens = 2000
  messages = @(
    @{ role = "system"; content = "You are a KitHub phase agent. Return only strict JSON." },
    @{ role = "user"; content = $prompt }
  )
} | ConvertTo-Json -Depth 10

$headers = @{ "content-type" = "application/json" }
if ($ApiKey) { $headers["Authorization"] = "Bearer $ApiKey" }

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$response = $null
$errText = ""
try {
  $response = Invoke-RestMethod -Method Post -Uri "$GatewayBaseUrl/v1/chat/completions" -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec $TimeoutSeconds
} catch {
  $errText = $_.Exception.Message
}

$sw.Stop()
$text = ""
if ($response) {
  $text = (@($response.choices) | ForEach-Object { [string]$_.message.content }) -join "`n"
}

# files haritasini dogrula (write-root'a YAZMADAN sadece icerik dogrulamasi)
$filesOk = $false
$pathOk = $false
$contentLen = 0
if ($text.Trim()) {
  try {
    $clean = $text.Trim() -replace "^\s*```(?:json)?\s*", "" -replace "\s*```\s*$", ""
    $obj = $clean | ConvertFrom-Json
    if ($obj.files) {
      $filesOk = $true
      $first = @($obj.files)[0]
      if ($first.path -eq "_workspace/01_proposals.md") { $pathOk = $true }
      $contentLen = ([string]$first.content).Length
    }
  } catch { $errText = "JSON parse: $($_.Exception.Message)" }
}

$report = [ordered]@{
  schema_version = "1.0.0"
  gateway = $GatewayBaseUrl
  model = $Model
  status = if ($filesOk -and $pathOk -and $contentLen -ge 500) { "pass" } else { "fail" }
  latency_ms = $sw.ElapsedMilliseconds
  files_array = $filesOk
  expected_path = $pathOk
  content_chars = $contentLen
  error = $errText
  checked_at = (Get-Date).ToString("o")
}
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $reportDir "omniroute-propose-fixture.json") -Encoding utf8
$report | ConvertTo-Json -Depth 5
if ($report.status -ne "pass") { exit 2 }
