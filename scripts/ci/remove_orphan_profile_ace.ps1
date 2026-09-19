<#
.SYNOPSIS
  Profil kokundeki YETIM (cozulemeyen) hesap SID'lerine ait Allow ACE'leri kaldirir.
  YALNIZCA DACL yazilir (SACL'e ve sahiplige dokunulmaz) -> yonetici hakki GEREKMEZ.

.NEDEN
  codebase-memory-mcp, cache dizinini "private" sayabilmek icin kullanici profil zincirinin
  DACL'ini denetler. Cakilan bir SID'e degistirme hakki verilmisse baslatmayi reddeder:
    "DACL entry 0 grants mutation rights 0x00010152 to untrusted identity (...)"
  Bu profildeki SID baska bir makineye aittir (makine SID'i farkli), hicbir hesaba
  cozulemez ve ProfileList'te profil kaydi yoktur -> atik kurulum/sandbox kalintisi.

.NEDEN Set-Acl DEGIL
  Profil kokunde bir SACL (denetim) kurali var. PowerShell Set-Acl; sahip+ grup+ DACL+ SACL
  bolumlerini birlikte yazar, SACL icin SeSecurityPrivilege gerekir ve bu yonetici olmayan
  surecte PrivilegeNotHeldException verir. icacls ise cozulemeyen SID'i isleyemez (1332).
  Bu betik SDDL'den DACL bolumunu cikarip yalnizca DACL yazar.

.GUVENLIK
  YALNIZCA su iki kosulu birlikte saglayan Allow ACE'ler cikarilir:
    (1) SID bir HESAP uzayindadir: S-1-5-21-<makine>-<rid>
    (2) SID hicbir hesaba cozulemez (yetim)
  SYSTEM, Administrators, mevcut kullanici, kabiliyet SID'leri (S-1-15-3-*) ve cozulebilen
  tum kimlikler korunur. Oncesi/sonrasi tam ACL kaniti
  runtime/fixture-reports/dacl-profile-root-snapshot.json dosyasina eklenir.
#>
[CmdletBinding()]
param(
  [string]$ProfilePath = "C:\Users\90535",
  [switch]$WhatIfOnly
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$reportPath = Join-Path $repoRoot "runtime/fixture-reports/dacl-profile-root-snapshot.json"
$logPath = Join-Path $repoRoot "runtime/fixture-reports/dacl-remove.log"

function Write-Step {
  param([string]$Message)
  $line = (Get-Date).ToString("HH:mm:ss") + " " + $Message
  Write-Output $line
  try { Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8 } catch {}
}

if (-not ("AclNative" -as [type])) {
  Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class AclNative {
  [DllImport("advapi32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
  public static extern bool ConvertStringSecurityDescriptorToSecurityDescriptor(string sddl, uint revision, out IntPtr sd, out uint size);
  [DllImport("advapi32.dll", SetLastError=true)]
  public static extern bool GetSecurityDescriptorDacl(IntPtr sd, out bool present, out IntPtr dacl, out bool defaulted);
  [DllImport("advapi32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
  public static extern uint SetNamedSecurityInfo(string name, int objectType, uint securityInfo, IntPtr owner, IntPtr group, IntPtr dacl, IntPtr sacl);
  [DllImport("kernel32.dll")]
  public static extern IntPtr LocalFree(IntPtr h);
}
"@
}

function Test-ResolvableSid {
  param([string]$Sid)
  try {
    $null = (New-Object System.Security.Principal.SecurityIdentifier($Sid)).Translate([System.Security.Principal.NTAccount])
    return $true
  } catch { return $false }
}

function Split-DaclSection {
  param([string]$Sddl)
  # DACL bolumu "D:" ile baslar, "S:" (SACL) veya "O:"/"G:" onekleri gelirse biter.
  if ($Sddl -notmatch 'D:') { return $null }
  $rest = $Sddl.Substring($Sddl.IndexOf('D:'))
  $end = $rest.Length
  foreach ($marker in @('S:')) {
    $idx = $rest.IndexOf($marker)
    if ($idx -ge 0 -and $idx -lt $end) { $end = $idx }
  }
  return $rest.Substring(0, $end)
}

function Get-AceParts {
  param([string]$DaclSection)
  $firstParen = $DaclSection.IndexOf('(')
  $flags = ''
  $body = ''
  if ($firstParen -lt 0) { $flags = $DaclSection.Substring(2); return @{ flags = $flags; aces = @() } }
  $flags = $DaclSection.Substring(2, $firstParen - 2)   # "D:" atlanir
  $body = $DaclSection.Substring($firstParen)
  $aces = @()
  foreach ($m in [regex]::Matches($body, '\(([^()]*)\)')) { $aces += $m.Value }
  return @{ flags = $flags; aces = $aces }
}

function Get-AceSid {
  param([string]$Ace)
  $inner = $Ace.Trim('(', ')')
  $fields = $inner.Split(';')
  if ($fields.Count -lt 6) { return $null }
  return $fields[$fields.Count - 1]
}

# ---------------------------------------------------------------- okuma + kanit
if (-not (Test-Path -LiteralPath $ProfilePath)) {
  Write-Output "[dacl] HATA: profil yolu yok: $ProfilePath"
  exit 1
}

$sddlBefore = (Get-Acl -LiteralPath $ProfilePath).Sddl
$daclSection = Split-DaclSection -Sddl $sddlBefore
if (-not $daclSection) { Write-Output "[dacl] HATA: SDDL icinde DACL bolumu yok."; exit 1 }

$parsed = Get-AceParts -DaclSection $daclSection
$keep = @()
$drop = @()
foreach ($ace in $parsed.aces) {
  $sid = Get-AceSid -Ace $ace
  if (-not $sid) { $keep += $ace; continue }
  $isAccountNs = ($sid -match '^S-1-5-21-(\d+-){3}\d+$')
  if ($isAccountNs -and -not (Test-ResolvableSid -Sid $sid)) { $drop += $ace } else { $keep += $ace }
}

Write-Step ("[dacl] profil: " + $ProfilePath)
Write-Step ("[dacl] mevcut ACE: " + $parsed.aces.Count + " | kaldirilacak yetim ACE: " + $drop.Count)
foreach ($d in $drop) { Write-Output ("[dacl]   -> " + $d) }

$evidence = [ordered]@{
  timestamp     = (Get-Date).ToString("s")
  profilePath   = $ProfilePath
  method        = "DACL-only (SetNamedSecurityInfo / SDDL)"
  sddlBefore    = $sddlBefore
  orphanTargets = @($drop | ForEach-Object { Get-AceSid -Ace $_ })
  orphanCount   = $drop.Count
}
if (-not $drop.Count) {
  Add-Content -LiteralPath $reportPath -Value (($evidence | ConvertTo-Json -Depth 4 -Compress)) -Encoding UTF8
  Write-Output "[dacl] SONUC: yetim ACE yok - degisiklik yapilmadi."
  exit 0
}
if ($WhatIfOnly) {
  Write-Output "[dacl] WhatIfOnly: yazim atlandi."
  exit 0
}

# ------------------------------------------------------- yeni DACL'i SDDL'den kur
$newDacl = "D:" + $parsed.flags + ($keep -join '')
Write-Step "[dacl] adim 3: yeni DACL SDDL hazir"
$sdPtr = [IntPtr]::Zero
$size = [uint32]0
if (-not [AclNative]::ConvertStringSecurityDescriptorToSecurityDescriptor($newDacl, 1, [ref]$sdPtr, [ref]$size)) {
  $err = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
  Write-Step ("[dacl] HATA: yeni DACL olusturulamadi (win32 " + $err + ")")
  exit 1
}
Write-Step "[dacl] adim 4: SD bellegi olusturuldu"

try {
  $present = $false; $daclPtr = [IntPtr]::Zero; $defaulted = $false
  if (-not [AclNative]::GetSecurityDescriptorDacl($sdPtr, [ref]$present, [ref]$daclPtr, [ref]$defaulted)) {
    $err = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    Write-Step ("[dacl] HATA: DACL isaretcisi alinamadi (win32 " + $err + ")")
    exit 1
  }
  Write-Step "[dacl] adim 5: SetNamedSecurityInfo cagriliyor (yalniz DACL)..."
  # SE_FILE_OBJECT=1, DACL_SECURITY_INFORMATION=0x4 -> SAHIPLIK ve SACL'e DOKUNULMAZ
  $status = [AclNative]::SetNamedSecurityInfo($ProfilePath, 1, 0x4, [IntPtr]::Zero, [IntPtr]::Zero, $daclPtr, [IntPtr]::Zero)
  if ($status -ne 0) {
    Write-Step ("[dacl] HATA: SetNamedSecurityInfo basarisiz (win32 " + $status + ")")
    exit 1
  }
  Write-Step "[dacl] adim 6: SetNamedSecurityInfo BASARILI"
} finally {
  if ($sdPtr -ne [IntPtr]::Zero) { [void][AclNative]::LocalFree($sdPtr) }
}

# ---------------------------------------------------------------- dogrulama
$sddlAfter = (Get-Acl -LiteralPath $ProfilePath).Sddl
$stillThere = @()
foreach ($d in $drop) { if ($sddlAfter -match [regex]::Escape((Get-AceSid -Ace $d))) { $stillThere += (Get-AceSid -Ace $d) } }

$after = [ordered]@{
  timestamp   = (Get-Date).ToString("s")
  profilePath = $ProfilePath
  sddlAfter   = $sddlAfter
  orphanLeft  = $stillThere.Count
}
Add-Content -LiteralPath $reportPath -Value ((@($evidence, $after) | ForEach-Object { $_ | ConvertTo-Json -Depth 4 -Compress })) -Encoding UTF8

Write-Step ("[dacl] kalan yetim ACE: " + $stillThere.Count)
Write-Step ("[dacl] kanit: " + $reportPath)
if ($stillThere.Count -eq 0) { Write-Step "[dacl] SONUC: TEMIZ"; exit 0 } else { Write-Step "[dacl] SONUC: KISMEN"; exit 2 }
