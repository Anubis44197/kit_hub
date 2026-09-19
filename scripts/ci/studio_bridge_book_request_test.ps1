param(
  [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$bridgeScript = Join-Path $ProjectRoot "scripts/studio_bridge.ps1"
if (-not (Test-Path -LiteralPath $bridgeScript -PathType Leaf)) { throw "Studio bridge script not found: $bridgeScript" }

$portProbe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$portProbe.Start()
$port = ([System.Net.IPEndPoint]$portProbe.LocalEndpoint).Port
$portProbe.Stop()

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("kithub-book-request-test-" + [guid]::NewGuid().ToString("N"))
$runtimeDir = Join-Path $testRoot "runtime"
$stdoutPath = Join-Path $testRoot "bridge-stdout.log"
$stderrPath = Join-Path $testRoot "bridge-stderr.log"
$bridgeProcess = $null

function Invoke-StudioJson {
  param(
    [string]$Path,
    [string]$Method = "GET",
    [object]$Body = $null,
    [string]$SessionToken = ""
  )
  $headers = @{ Origin = "http://127.0.0.1:$port" }
  if ($SessionToken) { $headers["X-KitHub-Session"] = $SessionToken }
  $request = @{
    Uri = "http://127.0.0.1:$port$Path"
    Method = $Method
    Headers = $headers
    UseBasicParsing = $true
    TimeoutSec = 10
  }
  if ($null -ne $Body) {
    $request.ContentType = "application/json; charset=utf-8"
    $request.Body = ($Body | ConvertTo-Json -Depth 10)
  }
  return Invoke-WebRequest @request
}

try {
  New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = "powershell.exe"
  $startInfo.Arguments = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$bridgeScript`"",
    "-RepoRoot", "`"$ProjectRoot`"", "-Port", $port
  ) -join " "
  $startInfo.WorkingDirectory = $ProjectRoot
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  $bridgeProcess = [System.Diagnostics.Process]::Start($startInfo)

  $ready = $false
  for ($attempt = 0; $attempt -lt 40; $attempt++) {
    Start-Sleep -Milliseconds 250
    try {
      $health = Invoke-StudioJson -Path "/api/health"
      if ($health.StatusCode -eq 200) { $ready = $true; break }
    }
    catch {}
  }
  if (-not $ready) { throw "Studio bridge did not become ready on port $port." }

  $session = (Invoke-StudioJson -Path "/api/session").Content | ConvertFrom-Json
  if (-not $session.ok -or -not $session.token) { throw "Studio session token was not returned." }

  $requestText = @"
# Kitap İsteği

## Zorunlu Cevaplar
- Tür: Psikolojik gizem romanı
- Hedef sayfa: 24
- Hedef okur: Yetişkin psikolojik gizem okurları
- Konu: Şifreli bir defterin aile sırrını açığa çıkarması.
- Karakterler: Defne Aral, sahaf Rauf, gazeteci Cem ve Nermin.
- Dönem ve mekân: Günümüz İstanbul'u; Beyoğlu ve Balat.
- Anlatıcı: Üçüncü tekil sınırlı, geçmiş zaman.
- Final: Defne gerçeği öğrenir ve annesiyle yüzleşir.
- Üslup: Edebi, akıcı ve psikolojik gerilim odaklı.
- Sınırlar: Grafik şiddet ve gerçek kişi iddiaları yok.
- Yayın paketi: A5 DOCX, başlık sayfası, içindekiler ve kapak briefi.
"@
  # Keep the fixture ASCII-only so Windows PowerShell 5.1 parses the script
  # consistently even when the host's legacy code page is not UTF-8.
  $requestText = @"
# Kitap Istegi

## Zorunlu Cevaplar
- Calisma adi: Sifreli Defter
- Yazar / imza: KitHub Test
- Tur: Psikolojik gizem romani
- Cikti hedefi: Kitap dosyasi
- Yapi / plan sablonu: 3 Perde Yapisi
- Hedef sayfa: 24
- Hedef okur: Yetiskin psikolojik gizem okurlari
- Okur seviyesi: Yetiskin
- Kitap amaci: Psikolojik gizem romani icin tutarli plan olusturmak
- Konu: Sifreli bir defterin aile sirrini aciga cikarmasi.
- Karakterler: Defne Aral, sahaf Rauf, gazeteci Cem ve Nermin.
- Donem ve mekan: Gunumuz Istanbul'u; Beyoglu ve Balat.
- Anlatici: Ucuncu tekil sinirli, gecmis zaman.
- Final: Defne gercegi ogrenir ve annesiyle yuzlesir.
- Uslup: Edebi, akici ve psikolojik gerilim odakli.
- Sinirlar: Grafik siddet ve gercek kisi iddialari yok.
- Kaynak / gerceklik kurali: Gercek kisi iddiasi uretme
- Yayin paketi: A5 DOCX, baslik sayfasi, icindekiler ve kapak briefi.
"@
  $saveResponse = Invoke-StudioJson -Path "/api/save-book-request" -Method "POST" -SessionToken $session.token -Body @{
    projectRoot = $testRoot
    text = $requestText
  }
  $save = $saveResponse.Content | ConvertFrom-Json
  if ($saveResponse.StatusCode -ne 200 -or -not $save.ok) { throw "Named character request was not accepted." }

  $savedPath = Join-Path $runtimeDir "book-request.md"
  $contractPath = Join-Path $runtimeDir "book-contract.json"
  if (-not (Test-Path -LiteralPath $savedPath -PathType Leaf)) { throw "runtime/book-request.md was not written." }
  if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) { throw "runtime/book-contract.json was not written." }
  $savedText = [System.IO.File]::ReadAllText($savedPath, [System.Text.Encoding]::UTF8)
  if ($savedText -ne $requestText) { throw "Saved book request does not match the submitted text." }
  $contract = [System.IO.File]::ReadAllText($contractPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
  if ($contract.writing_family -ne "fiction") { throw "Expected fiction writing contract, got '$($contract.writing_family)'." }

  $invalidText = $requestText -replace '(?m)^- Karakterler:.*$', '- Karakterler: '
  $invalidRejected = $false
  try {
    Invoke-StudioJson -Path "/api/save-book-request" -Method "POST" -SessionToken $session.token -Body @{
      projectRoot = $testRoot
      text = $invalidText
    } | Out-Null
  }
  catch {
    $invalidRejected = ([int]$_.Exception.Response.StatusCode -eq 500)
  }
  if (-not $invalidRejected) { throw "Empty character input was not rejected." }

  Write-Host "[studio-bridge-book-request] PASS named character list accepted; empty character input rejected"
}
finally {
  if ($bridgeProcess -and -not $bridgeProcess.HasExited) {
    Stop-Process -Id $bridgeProcess.Id -Force -ErrorAction SilentlyContinue
    $bridgeProcess.WaitForExit(5000) | Out-Null
  }
  if (Test-Path -LiteralPath $testRoot -PathType Container) {
    Remove-Item -LiteralPath $testRoot -Recurse -Force
  }
}
