<#
.SYNOPSIS
  Headroom uygunluk kapisi: verilen icerik tipi/boyutu politika geregi islenmeli mi?

.NOT
  Esikler artik YAPILANDIRMADAN okunur (onceki surumde 1048576 sabit kodluydu ve
  min_reduction_ratio hic raporlanmiyordu -> yapilandirma ile kapi celisiyordu).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$ContentType,
  [int]$Bytes = 0,
  [string]$ConfigPath
)

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $ConfigPath) { $ConfigPath = Join-Path $repoRoot 'runtime/adapters/headroom.json' }
$cfg = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

$targets = @($cfg.targets)
$excluded = @($cfg.excluded)
$floor = 0
if ($cfg.PSObject.Properties.Name -contains 'max_input_bytes') { $floor = [int]$cfg.max_input_bytes }
$minRatio = 0.15
if ($cfg.PSObject.Properties.Name -contains 'min_reduction_ratio') { $minRatio = [double]$cfg.min_reduction_ratio }

$isTarget = ($targets -contains $ContentType)
$isExcluded = ($excluded -contains $ContentType)
$aboveFloor = ($Bytes -ge $floor)
$eligible = ([bool]$cfg.enabled) -and $isTarget -and (-not $isExcluded) -and $aboveFloor

$reason = 'eligible'
if (-not $cfg.enabled) { $reason = 'adapter_disabled' }
elseif ($isExcluded) { $reason = 'content_type_excluded' }
elseif (-not $isTarget) { $reason = 'content_type_not_target' }
elseif (-not $aboveFloor) { $reason = 'below_size_floor' }

[ordered]@{
  contentType        = $ContentType
  bytes              = $Bytes
  eligible           = $eligible
  reason             = $reason
  size_floor_bytes   = $floor
  min_reduction_ratio = $minRatio
  fallback           = 'raw_content'
} | ConvertTo-Json -Compress
