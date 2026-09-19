param(
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][string]$Agent,
  [Parameter(Mandatory = $true)][string]$RelativePath
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path -LiteralPath $ProjectRoot).Path
$normalized = $RelativePath.Replace("/", "\").TrimStart("\")
if (-not $normalized -or $normalized -match '(^|\\)\.\.($|\\)') { throw "Invalid provider output path." }
$target = [IO.Path]::GetFullPath((Join-Path $root $normalized))
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $target.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Provider output escapes project root." }
$registryPath = Join-Path $root "runtime/agent-registry.json"
if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) { throw "Agent registry not found." }
$registry = [IO.File]::ReadAllText($registryPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
$entry = @($registry.agents | Where-Object { [string]$_.name -eq $Agent } | Select-Object -First 1)[0]
if (-not $entry) { throw "Agent is not present in registry: $Agent" }
$allowed = @($entry.allowed_write_roots | ForEach-Object { ([string]$_).Replace('/', '\').Trim('\') })
$relativeResolved = $target.Substring($rootPrefix.Length).Replace('\', '/')
if (-not (@($allowed | Where-Object { $relativeResolved -eq $_ -or $relativeResolved.StartsWith(($_ + '/'), [StringComparison]::OrdinalIgnoreCase) }).Count)) {
  throw "Agent '$Agent' cannot write '$RelativePath'. Allowed roots: $($allowed -join ', ')"
}
[pscustomobject]@{ ok = $true; path = $normalized; agent = $Agent }
