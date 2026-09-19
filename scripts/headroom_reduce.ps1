<#
.SYNOPSIS
  Headroom sikistirma motoru (deterministik, fail-open).

.NEDEN
  Onceki durumda yalnizca "policy check" vardi; gercek motor/SDK yoktu. Bu betik
  KitHub'in kendi deterministik kisalticisidir: ayni girdi -> ayni cikti, kayip riski
  olculur ve esik altinda kalirsa HAM ICERIGE doner (fail-open).

POLITIKA (runtime/adapters/headroom.json)
  - targets: tool_output | repeated_log | large_json
  - excluded: book_request, phase_contract, context_pack, verifier_evidence,
              creative_text, manuscript, export  (ASLA dokunulmaz)
  - max_input_bytes: bu boyutun ALTINDAKI icerik islenmez (fallback raw_content)
  - min_reduction_ratio: olculen kisalma bunun altinda kalirsa fallback raw_content
  - preserve_fields: bu anahtarlarin DEGERLERI ciktida birebir korunmak zorundadir;
    korunmazsa fallback raw_content

KISALTMA KURALLARI (deterministik)
  repeated_log:
    * JSON-lines log ise: degisken alanlar (timestamp/time/pid/hostname/... ) maskelenip
      ayni "imza"ya sahip satirlar TEK satirda toplanir; ilk satir aynen korunur,
      `_headroom_count` ile kac kez gectigi ve `_headroom_last_<alan>` ile son deger eklenir.
    * Duz metin ise: birebir ayni satirlar tek satirda toplanir (`[headroom xN]`).
    * Cok uzun satirlar kirpilir.
  large_json / JSON tool_output:
    * 4096 karakterden uzun metin degerleri kirpilir.
    * 300'den fazla elemanli dizilerde ilk 150 + son 150 eleman tutulur; atlanan
      araliklar `{"_headroom_elided": N}` ile isaretlenir.
    * preserve_fields DEGERI iceren elemanlar ASLA atlanmaz (butunluk garantisi).
  tool_output: JSON ise JSON kurallari, degilse metin kurallari.

KULLANIM
  scripts/headroom_reduce.ps1 -Path <dosya> -ContentType repeated_log
  scripts/headroom_reduce.ps1 -Path <dosya> -ContentType large_json -OutPath <cikti.json>
  scripts/headroom_reduce.ps1 -Content '...' -ContentType tool_output
  ... -Force   # boyut esigini yoksay (pilot/test)
#>
[CmdletBinding(DefaultParameterSetName = 'ByPath')]
param(
  [Parameter(ParameterSetName = 'ByPath', Mandatory = $true)][string]$Path,
  [Parameter(ParameterSetName = 'ByContent', Mandatory = $true)][string]$Content,
  [Parameter(Mandatory = $true)]
  [ValidateSet('tool_output', 'repeated_log', 'large_json')][string]$ContentType,
  [string]$OutPath,
  [string]$ConfigPath,
  [switch]$Force,
  [switch]$DiagPreserve
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $ConfigPath) { $ConfigPath = Join-Path $repoRoot 'runtime/adapters/headroom.json' }

function Fail-Open {
  param([string]$Reason, [int]$InputBytes)
  [ordered]@{
    schema_version = '1.0.0'
    contentType    = $ContentType
    applied        = $false
    reason         = $Reason
    inputBytes     = $InputBytes
    outputBytes    = $InputBytes
    reductionRatio = 0.0
    preserveOk     = $true
    outPath        = $OutPath
    content        = $null
  } | ConvertTo-Json -Depth 6 -Compress
}

# ------------------------------------------------------------------ yapilandirma
$cfg = $null
try {
  if (Test-Path -LiteralPath $ConfigPath) { $cfg = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json }
} catch { }
if (-not $cfg) { Fail-Open -Reason 'config_unreadable' -InputBytes 0; exit 0 }

$excluded = @($cfg.excluded)
$targets = @($cfg.targets)
$floor = 0
if ($cfg.PSObject.Properties.Name -contains 'max_input_bytes') { $floor = [int]$cfg.max_input_bytes }
$minRatio = 0.15
if ($cfg.PSObject.Properties.Name -contains 'min_reduction_ratio') { $minRatio = [double]$cfg.min_reduction_ratio }
$script:PreserveFields = @()
if ($cfg.PSObject.Properties.Name -contains 'preserve_fields') { $script:PreserveFields = @($cfg.preserve_fields) }

# Degisken (gurultu) alan adlari: imza olusturulurken maskelenir.
$script:VolatileKeys = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($k in @('timestamp', 'time', 'date', 'datetime', 'ts', 'pid', 'hostname', 'host',
                 'duration', 'durationms', 'elapsed', 'elapsedms', 'latency', 'latencyms',
                 'uptime', 'seq', 'requestid', 'traceid', 'spanid', 'id')) { [void]$script:VolatileKeys.Add($k) }

# ------------------------------------------------------------------ girdiyi oku
$raw = ''
if ($PSCmdlet.ParameterSetName -eq 'ByPath') {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { Fail-Open -Reason 'input_missing' -InputBytes 0; exit 0 }
  $raw = Get-Content -LiteralPath $Path -Raw
} else {
  $raw = $Content
}
if ($null -eq $raw) { $raw = '' }
$inputBytes = [System.Text.Encoding]::UTF8.GetByteCount($raw)

# ------------------------------------------------------------------ politika kapilari
if (-not $cfg.enabled) { Fail-Open -Reason 'adapter_disabled' -InputBytes $inputBytes; exit 0 }
if ($excluded -contains $ContentType) { Fail-Open -Reason 'content_type_excluded' -InputBytes $inputBytes; exit 0 }
if ($targets -notcontains $ContentType) { Fail-Open -Reason 'content_type_not_target' -InputBytes $inputBytes; exit 0 }
if ((-not $Force) -and $inputBytes -lt $floor) { Fail-Open -Reason 'below_size_floor' -InputBytes $inputBytes; exit 0 }

# ------------------------------------------------------------------ yardimcilar
function Get-AnsiStripped {
  param([string]$Text)
  return [regex]::Replace($Text, "\x1B\[[0-9;?]*[ -/]*[@-~]", '')
}

function Test-NodeHasPreserveValue {
  param($Node)
  if ($null -eq $Node) { return $false }
  if ($Node -is [System.Collections.IList]) {
    foreach ($i in @($Node)) { if (Test-NodeHasPreserveValue -Node $i) { return $true } }
    return $false
  }
  # Sozlukler (OrderedDictionary/Hashtable) ANAHTARLARI uzerinden gezilmeli:
  # .PSObject.Properties bunlar icin .NET uyelerini (Count, Keys...) dondurur.
  if ($Node -is [System.Collections.IDictionary]) {
    foreach ($k in @($Node.Keys)) {
      $v = $Node[$k]
      if ($script:PreserveFields -contains ([string]$k) -and $v -is [string]) { return $true }
      if (Test-NodeHasPreserveValue -Node $v) { return $true }
    }
    return $false
  }
  if ($Node -is [System.Management.Automation.PSCustomObject]) {
    foreach ($p in $Node.PSObject.Properties) {
      if ($script:PreserveFields -contains $p.Name -and $p.Value -is [string]) { return $true }
      if (Test-NodeHasPreserveValue -Node $p.Value) { return $true }
    }
  }
  return $false
}

function Reduce-JsonNode {
  param($Node, [int]$Depth = 0, [string]$Key = '')
  if ($Depth -gt 64) { return $Node }
  if ($null -eq $Node) { return $null }
  if ($Node -is [string]) {
    # preserve_fields'ta adi gecen anahtarlarin degerleri ASLA kirpilmaz (butunluk garantisi)
    if ($script:PreserveFields -contains $Key) { return $Node }
    if ($Node.Length -gt 4096) { return $Node.Substring(0, 4096) + '...[headroom:kirpildi ' + ($Node.Length - 4096) + ' karakter]' }
    return $Node
  }
  if ($Node -is [bool] -or $Node -is [byte] -or $Node -is [int] -or $Node -is [long] -or $Node -is [double] -or $Node -is [decimal]) { return $Node }
  if ($Node -is [System.Collections.IList]) {
    $items = @($Node)
    if ($items.Count -le 300) {
      $resSmall = @()
      foreach ($i in $items) { $resSmall += ,(Reduce-JsonNode -Node $i -Depth ($Depth + 1) -Key $Key) }
      return $resSmall
    }
    $selected = New-Object 'System.Collections.Generic.HashSet[int]'
    for ($i = 0; $i -lt 150; $i++) { [void]$selected.Add($i) }
    for ($i = [Math]::Max(0, $items.Count - 150); $i -lt $items.Count; $i++) { [void]$selected.Add($i) }
    for ($i = 0; $i -lt $items.Count; $i++) {
      if (Test-NodeHasPreserveValue -Node $items[$i]) { [void]$selected.Add($i) }   # butunluk garantisi
    }
    $res = @()
    $i = 0
    while ($i -lt $items.Count) {
      if ($selected.Contains($i)) {
        $res += ,(Reduce-JsonNode -Node $items[$i] -Depth ($Depth + 1) -Key $Key)
        $i++
      } else {
        $j = $i
        while ($j -lt $items.Count -and -not $selected.Contains($j)) { $j++ }
        $res += ,([ordered]@{ _headroom_elided = ($j - $i) })
        $i = $j
      }
    }
    return $res
  }
  if ($Node -is [System.Management.Automation.PSCustomObject] -or $Node -is [System.Collections.IDictionary]) {
    $resObj = [ordered]@{}
    foreach ($p in $Node.PSObject.Properties) { $resObj[$p.Name] = Reduce-JsonNode -Node $p.Value -Depth ($Depth + 1) -Key $p.Name }
    return $resObj
  }
  return $Node
}

function Reduce-LineList {
  param([string[]]$Lines, [int]$MaxLine = 2000)
  $counts = New-Object 'System.Collections.Generic.Dictionary[string,int]'
  foreach ($l in $Lines) {
    if ($counts.ContainsKey($l)) { $counts[$l] = $counts[$l] + 1 } else { $counts[$l] = 1 }
  }
  $seen = New-Object 'System.Collections.Generic.HashSet[string]'
  $out = New-Object 'System.Collections.Generic.List[string]'
  foreach ($l in $Lines) {
    if (-not $seen.Add($l)) { continue }
    $shown = $l
    if ($shown.Length -gt $MaxLine) { $shown = $shown.Substring(0, $MaxLine) + ' ...[headroom:kirpildi ' + ($l.Length - $MaxLine) + ' karakter]' }
    $n = $counts[$l]
    if ($n -gt 1) { $out.Add($shown + ' [headroom x' + $n + ']') } else { $out.Add($shown) }
  }
  return ($out -join "`n")
}

function Get-JsonLineSignature {
  param($Obj)
  if ($Obj -isnot [System.Management.Automation.PSCustomObject] -and $Obj -isnot [System.Collections.IDictionary]) {
    return ($Obj | ConvertTo-Json -Depth 16 -Compress)
  }
  $pairs = @()
  foreach ($p in $Obj.PSObject.Properties) {
    if ($script:VolatileKeys.Contains($p.Name)) { continue }
    $pairs += ($p.Name + '=' + ($p.Value | ConvertTo-Json -Depth 16 -Compress))
  }
  return (($pairs | Sort-Object) -join ';')
}

function Reduce-JsonLines {
  param([string[]]$Lines)
  $groups = [ordered]@{}
  foreach ($l in $Lines) {
    if ($l.Trim().Length -eq 0) { continue }
    $obj = $null
    try { $obj = $l | ConvertFrom-Json } catch { return $null }   # JSON degil -> cagiran tarafa birak
    $sig = Get-JsonLineSignature -Obj $obj
    if (-not $groups.Contains($sig)) {
      $groups[$sig] = [ordered]@{ count = 0; first = $obj; lastObj = $obj; lastLine = $l }
    }
    $g = $groups[$sig]
    $g.count = $g.count + 1
    $g.lastObj = $obj
    $g.lastLine = $l
  }
  $out = New-Object 'System.Collections.Generic.List[string]'
  foreach ($sig in $groups.Keys) {
    $g = $groups[$sig]
    if ($g.count -le 1) { $out.Add($g.lastLine); continue }
    $clone = [ordered]@{}
    foreach ($p in $g.first.PSObject.Properties) { $clone[$p.Name] = $p.Value }
    $clone['_headroom_count'] = $g.count
    $volatileSeen = 0
    foreach ($p in $g.first.PSObject.Properties) {
      if (-not $script:VolatileKeys.Contains($p.Name)) { continue }
      if ($volatileSeen -ge 3) { break }
      $lastVal = $null
      if ($g.lastObj.PSObject.Properties.Name -contains $p.Name) { $lastVal = $g.lastObj.$($p.Name) }
      if ($null -ne $lastVal -and ([string]$lastVal) -ne ([string]$p.Value)) {
        $clone['_headroom_last_' + $p.Name] = $lastVal
        $volatileSeen++
      }
    }
    $out.Add(($clone | ConvertTo-Json -Depth 32 -Compress))
  }
  return ($out -join "`n")
}

function Reduce-Text {
  param([string]$Text, [int]$MaxLine = 2000)
  $lines = $Text -split "`r?`n"
  # Bos satirlar JSON-lines tespitini ENGELLEMEZ (dosya sonundaki yeni satir dahil).
  $nonEmpty = @($lines | Where-Object { $_.Trim().Length -gt 0 })
  if ($nonEmpty.Count -gt 0) {
    $jsonLines = Reduce-JsonLines -Lines $nonEmpty
    if ($null -ne $jsonLines) { return $jsonLines }
  }
  return Reduce-LineList -Lines $lines -MaxLine $MaxLine
}

function Get-StringValuesOfKey {
  param($Node, [string]$Key, [System.Collections.Generic.List[string]]$Acc)
  if ($null -eq $Node) { return }
  if ($Node -is [System.Collections.IList]) {
    foreach ($i in @($Node)) { Get-StringValuesOfKey -Node $i -Key $Key -Acc $Acc }
    return
  }
  # Sozlukler (OrderedDictionary/Hashtable) ANAHTARLARI uzerinden gezilmeli.
  if ($Node -is [System.Collections.IDictionary]) {
    foreach ($k in @($Node.Keys)) {
      $v = $Node[$k]
      if (([string]$k) -eq $Key -and $v -is [string]) { $Acc.Add($v) }
      Get-StringValuesOfKey -Node $v -Key $Key -Acc $Acc
    }
    return
  }
  if ($Node -is [System.Management.Automation.PSCustomObject]) {
    foreach ($p in $Node.PSObject.Properties) {
      if ($p.Name -eq $Key -and $p.Value -is [string]) { $Acc.Add($p.Value) }
      Get-StringValuesOfKey -Node $p.Value -Key $Key -Acc $Acc
    }
  }
}

function Get-PreserveDiag {
  param($Original, $Reduced, [string[]]$Fields)
  $out = [ordered]@{}
  foreach ($f in $Fields) {
    $b = New-Object 'System.Collections.Generic.List[string]'
    $a = New-Object 'System.Collections.Generic.List[string]'
    Get-StringValuesOfKey -Node $Original -Key $f -Acc $b
    Get-StringValuesOfKey -Node $Reduced -Key $f -Acc $a
    $miss = @($b | Where-Object { -not $a.Contains($_) })
    $out[$f] = [ordered]@{ before = $b.Count; after = $a.Count; missing = $miss.Count; sample = @($miss | Select-Object -First 3) }
  }
  return $out
}

function Test-PreserveFields {
  # Basarili ise $null doner; degilse ihlal edilen alan adlarini dondurur (teshis icin).
  param($Original, $Reduced, [string[]]$Fields)
  $failed = @()
  foreach ($f in $Fields) {
    $before = New-Object 'System.Collections.Generic.List[string]'
    $after = New-Object 'System.Collections.Generic.List[string]'
    Get-StringValuesOfKey -Node $Original -Key $f -Acc $before
    Get-StringValuesOfKey -Node $Reduced -Key $f -Acc $after
    foreach ($v in $before) { if (-not $after.Contains($v)) { $failed += $f; break } }
  }
  if ($failed.Count -gt 0) { return ($failed -join ',') }
  return $null
}

# ------------------------------------------------------------------ kisaltma
$reduced = $null
$preserveOk = $true
$violation = $null
$debug = $null
try {
  switch ($ContentType) {
    'repeated_log' {
      $reduced = Reduce-Text -Text (Get-AnsiStripped -Text $raw)
    }
    'tool_output' {
      $stripped = Get-AnsiStripped -Text $raw
      $parsed = $null
      $isJson = $false
      try { $parsed = $stripped | ConvertFrom-Json; $isJson = $true } catch { $isJson = $false }
      if ($isJson -and $parsed -isnot [string]) {
        $node = Reduce-JsonNode -Node $parsed
        $violation = Test-PreserveFields -Original $parsed -Reduced $node -Fields $script:PreserveFields
        if ($violation) { $preserveOk = $false } else { $preserveOk = $true }
        if ($DiagPreserve) { $debug = Get-PreserveDiag -Original $parsed -Reduced $node -Fields $script:PreserveFields }
        $reduced = $node | ConvertTo-Json -Depth 64 -Compress
      } else {
        $reduced = Reduce-Text -Text $stripped
      }
    }
    'large_json' {
      $parsed = $null
      try { $parsed = $raw | ConvertFrom-Json } catch {
        Fail-Open -Reason 'json_parse_failed' -InputBytes $inputBytes; exit 0
      }
      $node = Reduce-JsonNode -Node $parsed
      $violation = Test-PreserveFields -Original $parsed -Reduced $node -Fields $script:PreserveFields
      if ($violation) { $preserveOk = $false } else { $preserveOk = $true }
      if ($DiagPreserve) { $debug = Get-PreserveDiag -Original $parsed -Reduced $node -Fields $script:PreserveFields }
      $reduced = $node | ConvertTo-Json -Depth 64 -Compress
    }
  }
} catch {
  Fail-Open -Reason ('reducer_error: ' + $_.Exception.Message) -InputBytes $inputBytes; exit 0
}

if ($null -eq $reduced) { Fail-Open -Reason 'reducer_no_output' -InputBytes $inputBytes; exit 0 }

$outputBytes = [System.Text.Encoding]::UTF8.GetByteCount([string]$reduced)
$ratio = 0.0
if ($inputBytes -gt 0) { $ratio = [Math]::Round(1.0 - ($outputBytes / [double]$inputBytes), 4) }

if (-not $preserveOk -and -not $DiagPreserve) { Fail-Open -Reason ('preserve_fields_violation: ' + $violation) -InputBytes $inputBytes; exit 0 }
if ($ratio -lt $minRatio) { Fail-Open -Reason ('below_min_reduction_ratio (' + $ratio + ' < ' + $minRatio + ')') -InputBytes $inputBytes; exit 0 }

if ($OutPath) {
  $dir = Split-Path -Parent $OutPath
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  Set-Content -LiteralPath $OutPath -Value ([string]$reduced) -Encoding UTF8 -NoNewline
}

[ordered]@{
  schema_version = '1.0.0'
  contentType    = $ContentType
  applied        = $true
  reason         = 'reduced'
  inputBytes     = $inputBytes
  outputBytes    = $outputBytes
  reductionRatio = $ratio
  preserveOk     = $preserveOk
  outPath        = $OutPath
  content        = $null
  debug          = $debug
} | ConvertTo-Json -Depth 6 -Compress
exit 0
