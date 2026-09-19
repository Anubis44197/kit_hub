[CmdletBinding()]
param(
  [string]$SourceBinary = "",
  [string]$InstallRoot = "",
  [string]$ExpectedSha256 = "7edcd3807ebcfd85ec1968985964080f2589748da2fc3c7ce9261eebab31ff04",
  [switch]$CheckOnly,
  [switch]$SkipProbe
)

# codebase-memory-mcp kurulumu (Windows, DACL-guvenli yol).
#
# NEDEN: binary, kendi exe yolunun ata zincirinde "guvenilmeyen" kimlige
# degistirme hakki veren bir ACE bulursa baslamayi reddeder:
#   exact executable identity could not be verified (cache-private)
# Repo Desktop altinda oldugu icin oradaki zincir kirlidir (sandbox araclari
# tarafindan birakilan yabanci/yetim SID'ler). Bu yuzden binary KULLANICI
# PROFILINDEN DEGIL, temiz zincirli bir kurulum dizininden calistirilir:
#   %LOCALAPPDATA%\Programs\codebase-memory-mcp\
# Kullanici klasorlerinin ACL'lerine HIC dokunulmaz (varsayilan davranis budur).

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$version = "0.11.0"

if (-not $SourceBinary) { $SourceBinary = Join-Path $repoRoot ".tools/codebase-memory-mcp/codebase-memory-mcp.exe" }
if (-not $InstallRoot) { $InstallRoot = Join-Path $env:LOCALAPPDATA "Programs" }
$installDir = Join-Path $InstallRoot "codebase-memory-mcp"
$target = Join-Path $installDir "codebase-memory-mcp.exe"

# Kullanici/SYSTEM/Administrators/kabiliyet SID'leri guvenilir sayilir; digerleri "yabanci".
$trustedPattern = '^(NT AUTHORITY\\(SYSTEM|LOCAL SERVICE|NETWORK SERVICE)|BUILTIN\\Administrators|CREATOR OWNER|APPLICATION PACKAGE AUTHORITY)|^S-1-(5-18|5-32-544|15-2|15-3)-'
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

# Binary'nin gercek kurali: yalnizca MUTASYON hakki veren ACE'ler sorun.
# Salt-okunur (ReadAndExecute) ve AppendData gibi OS varsayilanlari sorun degil
# (C:\ uzerindeki "Authenticated Users: AppendData" kaydi binary tarafindan kabul edilir).
$mutationMask = 0x2 -bor 0x10 -bor 0x40 -bor 0x100 -bor 0x10000 -bor 0x40000 -bor 0x80000 -bor 0x10000000 -bor 0x40000000

function Test-MutationRights {
  param($Rights)
  $r = [int]$Rights
  return (($r -band $mutationMask) -ne 0)
}

function Get-ForeignAces {
  param([Parameter(Mandatory)][string]$Path)
  $result = @()
  try { $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop } catch { return $result }
  foreach ($a in $acl.Access) {
    if ($a.AccessControlType -ne 'Allow') { continue }
    if ($a.IsInherited) { continue }
    if (-not (Test-MutationRights -Rights $a.FileSystemRights)) { continue }
    $id = $a.IdentityReference.ToString()
    if ($id -eq $currentUser) { continue }
    if ($id -match $trustedPattern) { continue }
    $result += [pscustomobject]@{
      path     = $Path
      identity = $id
      rights   = $a.FileSystemRights.ToString()
      mask     = ('0x{0:x8}' -f [int]$a.FileSystemRights)
    }
  }
  return $result
}

# Binary, ev dizini (profil koku) DISINDAKI isletim sistemi varsayilanlarini
# sorun saymiyor: kanit -> exe Desktop altindayken C:\ ve C:\Users sikayet
# edilmedi, yalnizca C:\Users\90535 ve C:\Users\90535\Desktop sikayet edildi.
# Bu yuzden zincir yuruyusu profil kokunde DURUR (dahil).
function Test-AncestorChain {
  param([Parameter(Mandatory)][string]$ExePath)
  $dir = (Resolve-Path -LiteralPath (Split-Path -Parent (Resolve-Path -LiteralPath $ExePath).Path)).Path
  $stopAt = (Resolve-Path -LiteralPath $env:USERPROFILE).Path
  $dirty = @()
  $guard = 0
  while ($dir -and $guard -lt 64) {
    $guard++
    $dirty += Get-ForeignAces -Path $dir
    if ($dir -ieq $stopAt) { break }
    $parent = Split-Path -Parent $dir
    if (-not $parent -or $parent -eq $dir) { break }
    $dir = $parent
  }
  return $dirty
}

$steps = [ordered]@{}
$ok = $true

# 1) Kaynak binary + hash
if (-not (Test-Path -LiteralPath $SourceBinary -PathType Leaf)) {
  $steps.source = "EKSIK: $SourceBinary"
  $ok = $false
} else {
  $sourceHash = (Get-FileHash -LiteralPath $SourceBinary -Algorithm SHA256).Hash.ToLower()
  $hashOk = ($sourceHash -eq $ExpectedSha256)
  $steps.source_hash = $sourceHash
  $steps.hash_verified = $hashOk
  if (-not $hashOk) { $ok = $false }
}

# 2) Kurulum (idempotent)
$targetInstalled = Test-Path -LiteralPath $target -PathType Leaf
$targetHash = $null
if ($targetInstalled) { $targetHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLower() }

if ($CheckOnly) {
  $steps.install_action = if ($targetInstalled) { "mevcut ($targetHash)" } else { "kurulmali" }
} elseif ($targetInstalled -and $targetHash -eq $ExpectedSha256) {
  $steps.install_action = "already_installed"
} elseif ($ok) {
  New-Item -ItemType Directory -Path $installDir -Force | Out-Null
  Copy-Item -LiteralPath $SourceBinary -Destination $target -Force
  $targetHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLower()
  $steps.install_action = "copied"
  if ($targetHash -ne $ExpectedSha256) { $steps.install_hash_mismatch = $true; $ok = $false }
} else {
  $steps.install_action = "skipped (kaynak hash dogrulanmadi)"
}

$installOk = (Test-Path -LiteralPath $target -PathType Leaf)
$steps.installed_path = if ($installOk) { (Resolve-Path -LiteralPath $target).Path } else { "" }
if ($installOk) {
  $steps.installed_hash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLower()
  $manifest = [ordered]@{
    schema_version = '1.0.0'
    binary         = 'codebase-memory-mcp'
    version        = $version
    sha256         = $steps.installed_hash
    installedAt    = (Get-Date).ToString('s')
    source         = $SourceBinary
    note           = 'DACL-guvenli kurulum: zincirde yabanci mutasyon ACE kaydi yok; .tools kopyasi bu yuzden baslatilamaz.'
  }
  $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $installDir 'install-manifest.json') -Encoding UTF8
}

# 3) Zincir kontrolu (kurulum dizini -> surucu koku)
$chainDirty = @()
if ($installOk) {
  $chainDirty = @(Test-AncestorChain -ExePath $target)
  $steps.ancestor_chain_clean = ($chainDirty.Count -eq 0)
  if ($chainDirty.Count -gt 0) { $steps.ancestor_chain_dirty = $chainDirty }
}

# 4) Sonda (gercek MCP el sikismasi)
$steps.probe_ok = $null
if ($installOk -and -not $SkipProbe -and -not $CheckOnly) {
  $probeScript = Join-Path $PSScriptRoot "ci/codebase_memory_stdio_probe.ps1"
  $probeJson = & powershell -NoProfile -ExecutionPolicy Bypass -File $probeScript -Binary $target 2>&1 | Out-String
  $probeObj = $null
  try { $probeObj = ($probeJson.Trim() | ConvertFrom-Json) } catch { $probeObj = $null }
  $steps.probe_ok = ($null -ne $probeObj -and $probeObj.ok)
  if ($probeObj) {
    $steps.probe_version = $probeObj.server_version
    $steps.probe_tool_count = $probeObj.tool_count
  }
  if (-not $steps.probe_ok) { $ok = $false }
}

$result = [ordered]@{
  schema_version = '1.0.0'
  generatedAt    = (Get-Date).ToString('s')
  ok             = $ok
  steps          = $steps
}

$evidenceDir = Join-Path $repoRoot 'runtime/fixture-reports'
if (-not (Test-Path $evidenceDir)) { New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null }
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidenceDir 'codebase-memory-install.json') -Encoding UTF8

$result | ConvertTo-Json -Depth 8
if (-not $ok) { exit 2 }
