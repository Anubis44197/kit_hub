param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$versionPath = Join-Path $RepoRoot "VERSION"
if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) { throw "VERSION file not found: $versionPath" }
$version = ([System.IO.File]::ReadAllText($versionPath, [System.Text.Encoding]::UTF8)).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "VERSION must be semantic (X.Y.Z), got: $version" }

$distRoot = Join-Path $RepoRoot "dist"
$zipPath = Join-Path $distRoot "kit-hub-studio-portable.zip"
if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) { throw "Portable zip not found; run build_portable_package.ps1 first: $zipPath" }

if (-not $OutDir) { $OutDir = Join-Path $distRoot "installer" }
if (-not (Test-Path -LiteralPath $OutDir -PathType Container)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$installerName = "KitHubStudio-Setup-$version.ps1"
$installerPath = Join-Path $OutDir $installerName
$zipBytes = [System.IO.File]::ReadAllBytes($zipPath)
$zipBase64 = [Convert]::ToBase64String($zipBytes)

$payloadMarkerStart = "# <<KITHUB_PAYLOAD_BEGIN>>"
$payloadMarkerEnd = "# <<KITHUB_PAYLOAD_END>>"

$template = @"
# KitHub Studio Installer - v$version
# Tek dosyalik kurulum paketi. Guvenli ortamda calistirin:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\$installerName
#
# Ayni zamanda basit bir calistirici olarak da kullanilabilir:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\$installerName -Launch

param(
  [string]`$InstallDir = (Join-Path `$env:LOCALAPPDATA "KitHub Studio"),
  [switch]`$NoDesktopShortcut,
  [switch]`$Quiet,
  [switch]`$Uninstall,
  [switch]`$Launch
)

`$ErrorActionPreference = "Stop"
`$Version = "$version"

function Write-Step {
  param([string]`$Text)
  if (-not `$Quiet) { Write-Host "[installer] `$Text" }
}

if (`$Uninstall) {
  if (Test-Path -LiteralPath `$InstallDir) {
    Remove-Item -LiteralPath `$InstallDir -Recurse -Force
    Write-Step "Kaldirildi: `$InstallDir"
  } else {
    Write-Step "Kurulum dizini bulunamadi: `$InstallDir"
  }
  exit 0
}

`$extractDir = Join-Path `$InstallDir "app"
`$startScript = Join-Path `$extractDir "start_studio.ps1"

if (`$Launch) {
  if (-not (Test-Path -LiteralPath `$startScript -PathType Leaf)) {
    Write-Host "[installer] Kurulum bulunamadi: `$startScript"
    Write-Host "[installer] Once kurulum paketini calistirin."
    exit 1
  }
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "`$startScript"
  exit `$LASTEXITCODE
}

Write-Step "KitHub Studio v`$Version kuruluyor..."

if (Test-Path -LiteralPath `$InstallDir) {
  Write-Step "Mevcut kurulum bulundu, uzerine yaziliyor."
} else {
  New-Item -ItemType Directory -Path `$InstallDir -Force | Out-Null
}

`$payload = @'
$payloadMarkerStart
$zipBase64
$payloadMarkerEnd
'@

`$base64Lines = `$payload -split "\r?\n" | Where-Object { `$_ -and -not `$_.TrimStart().StartsWith("#") }
`$base64 = (`$base64Lines -join "")
if (-not `$base64) { throw "Installer payload is empty." }

`$zipTemp = Join-Path `$env:TEMP ("kithub-installer-" + [guid]::NewGuid().ToString("N") + ".zip")
[System.IO.File]::WriteAllBytes(`$zipTemp, [Convert]::FromBase64String(`$base64))
if (-not (Test-Path -LiteralPath `$extractDir -PathType Container)) { New-Item -ItemType Directory -Path `$extractDir -Force | Out-Null }

Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path -LiteralPath `$extractDir -PathType Container) {
  Get-ChildItem -LiteralPath `$extractDir -Recurse -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}
[System.IO.Compression.ZipFile]::ExtractToDirectory(`$zipTemp, `$extractDir)
Remove-Item -LiteralPath `$zipTemp -Force

if (-not (Test-Path -LiteralPath `$startScript -PathType Leaf)) { throw "Paket icerigi eksik: start_studio.ps1" }
`$installedVersionPath = Join-Path `$extractDir "VERSION"
if (Test-Path -LiteralPath `$installedVersionPath -PathType Leaf) {
  `$installedVersion = ([System.IO.File]::ReadAllText(`$installedVersionPath, [System.Text.Encoding]::UTF8)).Trim()
  Write-Step "Kurulu surum: v`$installedVersion"
}

if (-not `$NoDesktopShortcut) {
  `$desktop = [Environment]::GetFolderPath("Desktop")
  `$lnkPath = Join-Path `$desktop "KitHub Studio.lnk"
  `$ws = New-Object -ComObject WScript.Shell
  `$sc = `$ws.CreateShortcut(`$lnkPath)
  `$sc.TargetPath = "powershell.exe"
  `$sc.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + `$startScript + '"'
  `$sc.WorkingDirectory = `$extractDir
  `$sc.Description = "KitHub Studio v`$Version"
  `$sc.Save()
  Write-Step "Masaustu kisa yolu olusturuldu."
}

Write-Step "Kurulum tamamlandi: `$extractDir"
Write-Step "Baslatmak icin: powershell -NoProfile -ExecutionPolicy Bypass -File `"`$startScript`""
if (-not `$Quiet) { Write-Host "" ; Read-Host "Kurulum tamam. Cikmak icin Enter" }
"@

[System.IO.File]::WriteAllText($installerPath, $template, [System.Text.UTF8Encoding]::new($false))

$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($installerPath, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
  $messages = $errors | ForEach-Object { "line $($_.Extent.StartLineNumber): $($_.Message)" }
  throw "Installer has syntax errors:`n$($messages -join "`n")"
}

$content = [System.IO.File]::ReadAllText($installerPath, [System.Text.Encoding]::UTF8)
if ($content -notmatch [regex]::Escape($payloadMarkerStart)) { throw "Installer payload marker missing." }

$size = (Get-Item -LiteralPath $installerPath).Length
$sizeText = if ($size -gt 1MB) { "{0:N1} MB" -f ($size / 1MB) } else { "{0:N0} KB" -f ($size / 1KB) }

Write-Host "[build-installer] installer=$installerPath"
Write-Host "[build-installer] version=$version size=$sizeText"
Write-Host "[build-installer] PASS"
exit 0