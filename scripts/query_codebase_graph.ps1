[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [ValidateSet("architecture", "search", "status", "symbols")][string]$Mode = "architecture",
  [string]$Query = "",
  [string]$ProjectName = "",
  [int]$MaxBytes = 8192,
  [int]$TimeoutSeconds = 180,
  [switch]$Fresh
)

# codebase-memory-mcp read-only sorgu araci (adaptor gercek kullanim noktasi).
#
# Sozlesme: runtime/adapters/codebase-memory-mcp.json -> enabled olmali.
# Fail-open: adaptor kapali, binary yok ya da cagri hata verirse ok=false dondurur
# ve cagiran taraf filesystem baglamina duser (hicbir zaman gorevi dusurmez).
#
# Ciktilar repo icine YAZILMAZ (persistence kullanilmaz); grafik verisi cache
# dizininde tutulur.

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "ci/lib_mcp_stdio.ps1")

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path

$configPath = Join-Path $repoRoot "runtime/adapters/codebase-memory-mcp.json"
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json

if (-not $config.enabled) {
  [pscustomobject]@{ ok = $false; source = "disabled"; reason = "adapter_disabled"; project = $ProjectRoot; bytes = 0 } | ConvertTo-Json -Compress
  return
}

$binary = ""
$preferred = [string]$config.binary_resolution.preferred_path
if ($preferred) {
  $expanded = [Environment]::ExpandEnvironmentVariables($preferred)
  if (Test-Path -LiteralPath $expanded -PathType Leaf) { $binary = $expanded }
}
if (-not $binary) {
  $repoCopy = Join-Path $repoRoot ".tools/codebase-memory-mcp/codebase-memory-mcp.exe"
  if (Test-Path -LiteralPath $repoCopy -PathType Leaf) { $binary = $repoCopy }
}
if (-not $binary) {
  [pscustomobject]@{ ok = $false; source = "fallback"; reason = "binary_missing"; project = $ProjectRoot; bytes = 0 } | ConvertTo-Json -Compress
  return
}

if (-not $ProjectName) {
  $ProjectName = "kithub-" + ((Split-Path -Leaf $ProjectRoot).ToLowerInvariant() -replace "[^a-z0-9-]", "-")
}

$session = $null
try {
  $session = New-McpSession -Binary $binary -WorkingDirectory $ProjectRoot -InitTimeoutSeconds 90 -ClientName "kithub-graph-query"
  if (-not $session.Version) {
    [pscustomobject]@{ ok = $false; source = "fallback"; reason = "mcp_init_failed"; project = $ProjectRoot; bytes = 0 } | ConvertTo-Json -Compress
    return
  }

  $known = Invoke-McpTool -Session $session -Id 2 -Name 'list_projects' -Arguments @{ format = 'json' } -TimeoutSeconds 60
  $hasIndex = ($known -and -not $known.IsError -and $known.Text -match [regex]::Escape($ProjectName))

  if ($Fresh -or -not $hasIndex) {
    $index = Invoke-McpTool -Session $session -Id 3 -Name 'index_repository' -Arguments @{
      repo_path = $ProjectRoot
      mode      = 'fast'
      name      = $ProjectName
    } -TimeoutSeconds $TimeoutSeconds
    if (-not $index -or $index.IsError) {
      [pscustomobject]@{ ok = $false; source = "fallback"; reason = "index_failed"; project = $ProjectRoot; bytes = 0 } | ConvertTo-Json -Compress
      return
    }
  }

  $args = @{ project = $ProjectName; format = 'json' }
  switch ($Mode) {
    "architecture" { $args.aspects = @('overview', 'structure', 'hotspots'); $tool = "get_architecture" }
    "status" { $tool = "index_status" }
    "symbols" { $tool = "search_graph"; $args.query = $Query; $args.limit = 20 }
    "search" { $tool = "search_code"; $args.pattern = $Query; $args.mode = 'compact'; $args.limit = 10 }
  }

  $result = Invoke-McpTool -Session $session -Id 4 -Name $tool -Arguments $args -TimeoutSeconds $TimeoutSeconds
  if (-not $result -or $result.IsError) {
    [pscustomobject]@{ ok = $false; source = "fallback"; reason = "query_failed"; project = $ProjectRoot; bytes = 0 } | ConvertTo-Json -Compress
    return
  }

  $text = $result.Text
  $truncated = $false
  if ($MaxBytes -gt 0 -and [Text.Encoding]::UTF8.GetByteCount($text) -gt $MaxBytes) {
    $text = $text.Substring(0, [Math]::Min($text.Length, $MaxBytes))
    $truncated = $true
  }

  [pscustomobject]@{
    ok        = $true
    source    = "codebase-memory-mcp"
    tool      = $tool
    project   = $ProjectName
    root      = $ProjectRoot
    version   = $session.Version
    truncated = $truncated
    bytes     = [Text.Encoding]::UTF8.GetByteCount($text)
    result    = $text
  } | ConvertTo-Json -Depth 8 -Compress
}
catch {
  [pscustomobject]@{ ok = $false; source = "fallback"; reason = $_.Exception.Message; project = $ProjectRoot; bytes = 0 } | ConvertTo-Json -Compress
}
finally {
  if ($session) { Close-McpSession -Session $session }
}
