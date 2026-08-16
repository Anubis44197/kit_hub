param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$distRoot = Join-Path $RepoRoot "dist"
$packageRoot = Join-Path $distRoot "kit-hub-studio-portable"
$zipPath = Join-Path $distRoot "kit-hub-studio-portable.zip"

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

$readmeText = @(
  "# KitHub Studio - Tasinabilir Paket",
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
  if (-not ($hasIndex -and $hasBridge -and $hasLauncher -and $hasReadme)) {
    throw "Package contents incomplete: index=$hasIndex bridge=$hasBridge launcher=$hasLauncher readme=$hasReadme"
  }
  Write-Host "[build-portable] contents verified: index=$hasIndex bridge=$hasBridge launcher=$hasLauncher readme=$hasReadme"
}
finally {
  $zip.Dispose()
}
Write-Host "[build-portable] PASS"
exit 0