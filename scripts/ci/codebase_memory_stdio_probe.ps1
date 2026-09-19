param(
  [string]$Binary = "",
  [int]$TimeoutSeconds = 90,
  [string]$CacheDir = "",
  [string]$WorkingDirectory = "",
  [switch]$Verbose
)

# codebase-memory-mcp stdio saglik sondasi (read-only; hicbir sey indekslemez).
#
# DACL NOTU (2026-09-18, KANITLI): binary, kendi exe yolunun ATA ZINCIRINDE
# "guvenilmeyen" kimlige degistirme hakki veren ACE bulursa baslamayi reddeder:
#   exact executable identity could not be verified (cache-private)
#   - <yol>: DACL entry N grants mutation rights ... to untrusted identity (...)
# Proje Desktop altinda oldugunda zincir kirlidir (sandbox araclarinin biraktigi
# yabanci/yetim SID'ler: CodexSandboxUsers ve baska makinelere ait SID'ler).
# COZUM: binary'yi + cache'i TEMIZ zincire kurmak. Kanonik kurulum:
#   %LOCALAPPDATA%\Programs\codebase-memory-mcp\  (bkz. scripts/install_codebase_memory.ps1)
# Ayni binary .tools altinda da duruyor ama oradan baslatilamaz (zincir kirli).
#
# OKUMA NOTU: tasima lib_mcp_stdio.ps1'e tasindi; ciktilar olay tabanli okunur,
# cunku Peek() tabanli yoklama tools/list yanitini kaciriyordu.

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'lib_mcp_stdio.ps1')

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path

if (-not $Binary) {
  $installed = Join-Path $env:LOCALAPPDATA 'Programs\codebase-memory-mcp\codebase-memory-mcp.exe'
  if (Test-Path -LiteralPath $installed -PathType Leaf) {
    $Binary = $installed
  } else {
    $Binary = Join-Path $repoRoot '.tools/codebase-memory-mcp/codebase-memory-mcp.exe'
  }
}
if (-not (Test-Path -LiteralPath $Binary -PathType Leaf)) { throw "Binary not found: $Binary" }

if (-not $CacheDir) { $CacheDir = Join-Path (Split-Path -Parent (Resolve-Path -LiteralPath $Binary).Path) 'cache' }
if (-not $WorkingDirectory) { $WorkingDirectory = $repoRoot }

$session = $null
$listMsg = $null
$toolsMs = -1
try {
  $session = New-McpSession -Binary $Binary -CacheDir $CacheDir -WorkingDirectory $WorkingDirectory -InitTimeoutSeconds $TimeoutSeconds
  if ($session.Version) {
    $listMsg = Invoke-Mcp -Session $session -Id 2 -Method 'tools/list' -TimeoutSeconds $TimeoutSeconds
  }
  $toolsMs = [int]$session.Sw.Elapsed.TotalMilliseconds
  $stderr = Get-McpStderr -Session $session
  $rawLines = @($session.Lines)
  $initMs = $session.InitMs
  $serverVersion = $session.Version
}
finally {
  if ($session) { Close-McpSession -Session $session }
}

$initOk = [bool]$serverVersion
$toolCount = -1
$toolNames = @()
if ($listMsg -and $listMsg.result -and $listMsg.result.tools) {
  $toolNames = @($listMsg.result.tools | ForEach-Object { $_.name })
  $toolCount = $toolNames.Count
}

$out = [ordered]@{
  schema_version = '1.0.0'
  generatedAt    = (Get-Date).ToString('s')
  binary         = (Resolve-Path -LiteralPath $Binary).Path
  cache_dir      = $env:CBM_CACHE_DIR
  working_dir    = $WorkingDirectory
  ok             = ($initOk -and $toolCount -ge 0)
  server_init    = $initOk
  server_version = $serverVersion
  tool_count     = $toolCount
  tools          = $toolNames
  init_ms        = $initMs
  tools_ms       = $toolsMs
  raw_lines      = $rawLines.Count
  stderr_head    = ($stderr.Substring(0, [Math]::Min(400, $stderr.Length)))
}

if ($Verbose) {
  foreach ($line in $rawLines) { "[raw] " + $line }
  if ($stderr) { "[stderr] " + $stderr }
}

# KANIT: envanter sozlesme testi (kanita dayali aktivasyon) bu dosyayi arar.
$evidenceDir = Join-Path $repoRoot 'runtime/fixture-reports'
if (-not (Test-Path $evidenceDir)) { New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null }
$out | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $evidenceDir 'codebase-memory-probe.json') -Encoding UTF8

$out | ConvertTo-Json -Depth 4
if (-not $out.ok) { exit 2 }
