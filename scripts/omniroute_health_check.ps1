[CmdletBinding()]
param([string]$ProjectRoot=(Get-Location).Path)
$cfg=Get-Content (Join-Path $ProjectRoot 'runtime/adapters/omniroute.json') -Raw | ConvertFrom-Json
$result=[ordered]@{adapter='omniroute'; enabled=[bool]$cfg.enabled; base_url=$cfg.base_url; checkedAt=(Get-Date).ToUniversalTime().ToString('o'); status='disabled'}
if($cfg.enabled){ try { $r=Invoke-WebRequest -Uri ($cfg.base_url+$cfg.health_path) -UseBasicParsing -TimeoutSec ([int]$cfg.timeout_seconds); $result.status='healthy'; $result.httpStatus=[int]$r.StatusCode } catch { $result.status='unavailable'; $result.error=$_.Exception.Message } }
$result | ConvertTo-Json -Compress
