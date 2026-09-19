param(
  [string]$Binary = "",
  [int]$IndexTimeoutSeconds = 420,
  [switch]$Verbose
)

# codebase-memory-mcp FIXTURE testi: gercek indeksleme + gercek arama.
#
# Neden gerekli: stdio sondasi yalnizca el sikismasini dogrular. Adaptorun
# gercek kabul kriteri "index_repository + search_graph calisir" oldugu icin
# kucuk bir fixture proje indekslenir, aranir ve sonunda temizlenir.
#
# Kanit: runtime/fixture-reports/codebase-memory-fixture.json

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'lib_mcp_stdio.ps1')

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
if (-not $Binary) {
  $installed = Join-Path $env:LOCALAPPDATA 'Programs\codebase-memory-mcp\codebase-memory-mcp.exe'
  $Binary = if (Test-Path -LiteralPath $installed -PathType Leaf) { $installed } else { Join-Path $repoRoot '.tools/codebase-memory-mcp/codebase-memory-mcp.exe' }
}
if (-not (Test-Path -LiteralPath $Binary -PathType Leaf)) { throw "Binary not found: $Binary" }

$projectName = 'kithub-cbm-fixture'
$fixtureRoot = Join-Path $repoRoot 'runtime/fixture-reports/cbm-fixture-project'
if (Test-Path $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'src') -Force | Out-Null

Set-Content -LiteralPath (Join-Path $fixtureRoot 'src/util.js') -Encoding UTF8 -Value @'
export function greet(name) {
  return `hello ${name}`;
}

export function shout(text) {
  return greet(text).toUpperCase();
}
'@
Set-Content -LiteralPath (Join-Path $fixtureRoot 'src/app.js') -Encoding UTF8 -Value @'
import { greet, shout } from './util.js';

export function main() {
  const greeting = greet('world');
  return shout(greeting);
}

main();
'@

$steps = [ordered]@{}
$ok = $true
$session = $null
$searchHits = @()
$indexed = $false
try {
  $session = New-McpSession -Binary $Binary -WorkingDirectory $repoRoot -InitTimeoutSeconds 90 -ClientName 'kithub-fixture-test'
  $steps.server_version = $session.Version
  $steps.init_ms = $session.InitMs
  if (-not $session.Version) { throw "MCP initialize yanit vermedi" }

  $before = Invoke-McpTool -Session $session -Id 2 -Name 'list_projects' -Arguments @{ format = 'json' } -TimeoutSeconds 120
  $steps.list_projects_before = if ($before) { ($before.Text.Substring(0, [Math]::Min(400, $before.Text.Length))) } else { $null }

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $index = Invoke-McpTool -Session $session -Id 3 -Name 'index_repository' -Arguments @{
    repo_path = $fixtureRoot
    mode      = 'fast'
    name      = $projectName
  } -TimeoutSeconds $IndexTimeoutSeconds
  $steps.index_ms = [int]$sw.Elapsed.TotalMilliseconds
  if (-not $index) {
    $steps.index_result = 'YANIT YOK (timeout)'
    $ok = $false
  } else {
    $steps.index_is_error = $index.IsError
    $steps.index_result = $index.Text.Substring(0, [Math]::Min(600, $index.Text.Length))
    $indexed = (-not $index.IsError)
    if (-not $indexed) { $ok = $false }
  }

  if ($indexed) {
    $status = Invoke-McpTool -Session $session -Id 4 -Name 'index_status' -Arguments @{ project = $projectName; format = 'json' } -TimeoutSeconds 120
    if ($status) { $steps.index_status = $status.Text.Substring(0, [Math]::Min(500, $status.Text.Length)) }

    $search = Invoke-McpTool -Session $session -Id 5 -Name 'search_graph' -Arguments @{
      project = $projectName
      query   = 'greet'
      limit   = 10
      format  = 'json'
    } -TimeoutSeconds 180
    if ($search) {
      $steps.search_is_error = $search.IsError
      $steps.search_result = $search.Text.Substring(0, [Math]::Min(700, $search.Text.Length))
      if ($search.Text -match 'greet') { $searchHits += 'greet' }
      if ($search.Text -match 'shout' -or $search.Text -match 'main') { $searchHits += 'callers' }
    }
    $steps.search_markers = $searchHits
    if ($searchHits.Count -eq 0) { $ok = $false }

    # Temizlik: fixture projesi indeksten silinir (yikici ama yalnizca indeks kaydi).
    $del = Invoke-McpTool -Session $session -Id 6 -Name 'delete_project' -Arguments @{ project = $projectName } -TimeoutSeconds 120
    $steps.delete_result = if ($del) { ($del.Text.Substring(0, [Math]::Min(200, $del.Text.Length))) } else { 'YANIT YOK' }
  }

  $stderr = Get-McpStderr -Session $session
  $steps.stderr_tail = ($stderr.Substring([Math]::Max(0, $stderr.Length - 300)))
  if ($Verbose -and $stderr) { "[stderr] " + $stderr }
}
catch {
  $steps.error = $_.Exception.Message
  $ok = $false
}
finally {
  if ($session) { Close-McpSession -Session $session }
}

$out = [ordered]@{
  schema_version = '1.0.0'
  generatedAt    = (Get-Date).ToString('s')
  binary         = (Resolve-Path -LiteralPath $Binary).Path
  project        = $projectName
  fixture_root   = $fixtureRoot
  ok             = $ok
  steps          = $steps
}

$evidenceDir = Join-Path $repoRoot 'runtime/fixture-reports'
if (-not (Test-Path $evidenceDir)) { New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null }
$out | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidenceDir 'codebase-memory-fixture.json') -Encoding UTF8

$out | ConvertTo-Json -Depth 8
if (-not $ok) { exit 2 }
