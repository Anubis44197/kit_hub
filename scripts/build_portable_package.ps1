param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$distRoot = Join-Path $RepoRoot "dist"
$packageRoot = Join-Path $distRoot "kit-hub-studio-portable"
$zipPath = Join-Path $distRoot "kit-hub-studio-portable.zip"

$versionPath = Join-Path $RepoRoot "VERSION"
if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) { throw "VERSION file not found: $versionPath" }
$version = ([System.IO.File]::ReadAllText($versionPath, [System.Text.Encoding]::UTF8)).Trim()
if (-not $version) { throw "VERSION is empty" }
$versionPattern = '^\d+\.\d+\.\d+$'
if ($version -notmatch $versionPattern) { throw "VERSION must be semantic (X.Y.Z), got: $version" }

if (-not (Test-Path -LiteralPath $RepoRoot -PathType Container)) { throw "RepoRoot not found: $RepoRoot" }
$required = @(
  "index.html",
  "assets",
  "scripts",
  "scripts/start_studio.ps1"
)
foreach ($item in $required) {
  $check = Join-Path $RepoRoot $item
  if (-not (Test-Path -LiteralPath $check)) { throw "Required path missing: $check" }
}

if (Test-Path -LiteralPath $packageRoot) { Remove-Item -LiteralPath $packageRoot -Recurse -Force }
New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null

foreach ($item in @("index.html", "assets", "scripts")) {
  Copy-Item -LiteralPath (Join-Path $RepoRoot $item) -Destination $packageRoot -Recurse -Force
}
Copy-Item -LiteralPath (Join-Path $RepoRoot "scripts/start_studio.ps1") -Destination (Join-Path $packageRoot "start_studio.ps1") -Force
Copy-Item -LiteralPath $versionPath -Destination (Join-Path $packageRoot "VERSION") -Force
$changelogSource = Join-Path $RepoRoot "CHANGELOG.md"
if (Test-Path -LiteralPath $changelogSource -PathType Leaf) {
  Copy-Item -LiteralPath $changelogSource -Destination (Join-Path $packageRoot "CHANGELOG.md") -Force
}

$readmeText = @(
  "# KitHub Studio - Tasinabilir Paket",
  "",
  "Surum: $version",
  "",
  "## Calistirma",
  "1. Bu klasoru kopyalayip acin.",
  "2. `start_studio.ps1` dosyasina sag tiklayip 'PowerShell ile calistir' secin,",
  "   veya bir PowerShell penceresinde su komutu calistirin:",
  "",
  "   powershell -NoProfile -ExecutionPolicy Bypass -File .\start_studio.ps1",
  "",
  "3. Tarayici otomatik olarak http://127.0.0.1:8765/ adresini acar.",
  "4. Studio Bridge basladiktan sonra proje ekranindan bir kitap projesi secin",
  "   veya 'Yeni Proje' ile baslayin.",
  "",
  "## Guncelleme",
  "- Yeni surumler GitHub Releases sayfasindan indirilir; paket tasinabilir oldugu",
  "  icin eski klasorun uzerine kopyalanarak guncellenir.",
  "- Verileriniz proje klasorlerinde saklanir; paket guncellemesi verileri etkilemez.",
  "",
  "## Notlar",
  "- Paket tek sayfa (index.html) + PowerShell motorundan olusur; ek kurulum gerekmez.",
  "- DOCX/PDF/EPUB disa aktarimlari harici komut satiri araclari isteyebilir",
  "  (pandoc gibi); bunlar eksikse ilgili faz bunu raporda belirtir.",
  "- Guvenlik: Studio Bridge yalnizca 127.0.0.1 uzerinde dinler ve oturum token'i",
  "  ile istek dogrular."
) -join "`n"
[System.IO.File]::WriteAllText((Join-Path $packageRoot "PORTABLE-README.md"), $readmeText, [System.Text.UTF8Encoding]::new($true))

if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
Compress-Archive -Path (Join-Path $packageRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal

if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) { throw "Portable package zip was not created." }

$entryCount = (Get-ChildItem -LiteralPath $packageRoot -Recurse -File).Count
$size = (Get-Item -LiteralPath $zipPath).Length
$sizeText = if ($size -gt 1MB) { "{0:N1} MB" -f ($size / 1MB) } else { "{0:N0} KB" -f ($size / 1KB) }

Write-Host "[build-portable] packageRoot=$packageRoot"
Write-Host "[build-portable] zip=$zipPath"
Write-Host "[build-portable] entries=$entryCount size=$sizeText"

$add = Add-Type -AssemblyName System.IO.Compression.FileSystem -PassThru
$zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
  $names = @($zip.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
  $hasIndex = $names -contains "index.html"
  $hasBridge = $names -contains "scripts/studio_bridge.ps1"
  $hasLauncher = $names -contains "start_studio.ps1"
  $hasReadme = $names -contains "PORTABLE-README.md"
  $hasVersion = $names -contains "VERSION"
  $hasChangelog = $names -contains "CHANGELOG.md"
  if (-not ($hasIndex -and $hasBridge -and $hasLauncher -and $hasReadme -and $hasVersion -and $hasChangelog)) {
    throw "Package contents incomplete: index=$hasIndex bridge=$hasBridge launcher=$hasLauncher readme=$hasReadme version=$hasVersion changelog=$hasChangelog"
  }
  $versionEntry = $zip.Entries | Where-Object { $_.FullName.Replace('\', '/') -eq "VERSION" } | Select-Object -First 1
  $reader = New-Object System.IO.StreamReader($versionEntry.Open(), [System.Text.Encoding]::UTF8)
  try { $embeddedVersion = $reader.ReadToEnd().Trim() } finally { $reader.Dispose() }
  if ($embeddedVersion -ne $version) { throw "Embedded VERSION mismatch: got=$embeddedVersion expected=$version" }
  Write-Host "[build-portable] version=$version"
  Write-Host "[build-portable] contents verified: index=$hasIndex bridge=$hasBridge launcher=$hasLauncher readme=$hasReadme version=$hasVersion changelog=$hasChangelog"
}
finally {
  $zip.Dispose()
}
Write-Host "[build-portable] PASS"
exit 0