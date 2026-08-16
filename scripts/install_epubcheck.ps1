param(
  [string]$Version = "5.3.0",
  [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA "KitHub/tools/epubcheck")
)

$ErrorActionPreference = "Stop"
if ($Version -ne "5.3.0") { throw "Only the verified EPUBCheck 5.3.0 package is supported by this installer." }
$expectedSha256 = "6c07e68584b2e2ce2f89fe06e1246dfead3eb36b46b340e7d93524f29dcff6c5"
$downloadUri = "https://github.com/w3c/epubcheck/releases/download/v$Version/epubcheck-$Version.zip"
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("kithub-epubcheck-" + [guid]::NewGuid().ToString("N"))
$archivePath = Join-Path $temporaryRoot "epubcheck.zip"
$extractRoot = Join-Path $temporaryRoot "extract"
$versionRoot = Join-Path $InstallRoot $Version

try {
  New-Item -ItemType Directory -Path $temporaryRoot,$extractRoot,$versionRoot -Force | Out-Null
  Invoke-WebRequest -Uri $downloadUri -OutFile $archivePath -UseBasicParsing
  $actualSha256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actualSha256 -ne $expectedSha256) { throw "EPUBCheck archive checksum mismatch." }
  Expand-Archive -LiteralPath $archivePath -DestinationPath $extractRoot -Force
  $sourceRoot = Join-Path $extractRoot "epubcheck-$Version"
  $jarPath = Join-Path $sourceRoot "epubcheck.jar"
  if (-not (Test-Path -LiteralPath $jarPath -PathType Leaf)) { throw "epubcheck.jar was not found in the verified archive." }
  Copy-Item -Path (Join-Path $sourceRoot "*") -Destination $versionRoot -Recurse -Force
  $installedJar = Join-Path $versionRoot "epubcheck.jar"
  if (-not (Test-Path -LiteralPath $installedJar -PathType Leaf)) { throw "EPUBCheck installation failed." }
  $manifest = [ordered]@{
    schema_version = "1.0.0"
    version = $Version
    source = $downloadUri
    sha256 = $expectedSha256
    installed_at = (Get-Date).ToString("o")
    jar = $installedJar
  }
  [IO.File]::WriteAllText((Join-Path $InstallRoot "installation.json"), ($manifest | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($true))
  Write-Host "[epubcheck-install] PASS version=$Version jar=$installedJar"
}
finally {
  if (Test-Path -LiteralPath $temporaryRoot -PathType Container) {
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
