param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

$versionPath = Join-Path $RepoRoot "VERSION"
if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) { throw "VERSION file missing: $versionPath" }
$version = ([System.IO.File]::ReadAllText($versionPath, [System.Text.Encoding]::UTF8)).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "VERSION must be semantic (X.Y.Z), got: $version" }
Write-Host "[package-test] version=$version"

$buildScript = Join-Path $RepoRoot "scripts/build_portable_package.ps1"
$installerScript = Join-Path $RepoRoot "scripts/build_installer.ps1"
if (-not (Test-Path -LiteralPath $buildScript -PathType Leaf)) { throw "Missing build script: $buildScript" }
if (-not (Test-Path -LiteralPath $installerScript -PathType Leaf)) { throw "Missing installer script: $installerScript" }

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $buildScript -RepoRoot $RepoRoot
if ($LASTEXITCODE -ne 0) { throw "build_portable_package.ps1 failed with exit code $LASTEXITCODE." }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installerScript -RepoRoot $RepoRoot
if ($LASTEXITCODE -ne 0) { throw "build_installer.ps1 failed with exit code $LASTEXITCODE." }

$zipPath = Join-Path $RepoRoot "dist/kit-hub-studio-portable.zip"
$installerPath = Join-Path $RepoRoot "dist/installer/KitHubStudio-Setup-$version.ps1"
if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) { throw "Portable zip missing: $zipPath" }
if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) { throw "Installer missing: $installerPath" }

$zipSize = (Get-Item -LiteralPath $zipPath).Length
$installerSize = (Get-Item -LiteralPath $installerPath).Length
if ($zipSize -lt 100KB) { throw "Portable zip looks too small: $zipSize bytes" }
if ($installerSize -lt 150KB) { throw "Installer looks too small: $installerSize bytes" }

$installerTokens = $null
$installerErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile($installerPath, [ref]$installerTokens, [ref]$installerErrors) | Out-Null
if ($installerErrors.Count -gt 0) {
  $messages = $installerErrors | ForEach-Object { "line $($_.Extent.StartLineNumber): $($_.Message)" }
  throw "Installer has syntax errors:`n$($messages -join "`n")"
}

$installerContent = [System.IO.File]::ReadAllText($installerPath, [System.Text.Encoding]::UTF8)
if ($installerContent -notmatch "# <<KITHUB_PAYLOAD_BEGIN>>") { throw "Installer payload marker missing." }
if ($installerContent -notmatch [regex]::Escape("$version")) { throw "Installer does not embed version $version." }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
  $names = @($zip.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
  $expected = @("index.html", "scripts/studio_bridge.ps1", "start_studio.ps1", "PORTABLE-README.md", "VERSION", "CHANGELOG.md")
  $missing = $expected | Where-Object { $names -notcontains $_ }
  if ($missing.Count -gt 0) { throw "Portable zip missing entries: $($missing -join ', ')" }
}
finally {
  $zip.Dispose()
}

$installDir = Join-Path $env:TEMP ("kithub-package-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $installDir -Force | Out-Null
try {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installerPath -InstallDir $installDir -NoDesktopShortcut -Quiet
  if ($LASTEXITCODE -ne 0) { throw "Installer execution failed with exit code $LASTEXITCODE." }
  $installedStart = Join-Path $installDir "app/start_studio.ps1"
  $installedVersion = Join-Path $installDir "app/VERSION"
  if (-not (Test-Path -LiteralPath $installedStart -PathType Leaf)) { throw "Installer did not extract start_studio.ps1" }
  if (-not (Test-Path -LiteralPath $installedVersion -PathType Leaf)) { throw "Installer did not extract VERSION" }
  $embeddedVersion = ([System.IO.File]::ReadAllText($installedVersion, [System.Text.Encoding]::UTF8)).Trim()
  if ($embeddedVersion -ne $version) { throw "Installed VERSION mismatch: got=$embeddedVersion expected=$version" }
  $installedIndex = Join-Path $installDir "app/index.html"
  $indexContent = [System.IO.File]::ReadAllText($installedIndex, [System.Text.Encoding]::UTF8)
  if ($indexContent -notmatch "v$version") { throw "Installed index.html does not show version v$version" }

  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installerPath -InstallDir $installDir -Uninstall -Quiet
  if ($LASTEXITCODE -ne 0) { throw "Installer uninstall failed with exit code $LASTEXITCODE." }
  if (Test-Path -LiteralPath $installDir) { throw "Uninstall did not remove install directory." }
}
finally {
  if (Test-Path -LiteralPath $installDir) { Remove-Item -LiteralPath $installDir -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host "[package-test] zip=$zipSize bytes installer=$installerSize bytes"
Write-Host "[package-test] PASS"
exit 0