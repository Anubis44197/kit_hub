[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$RecordJson)
$cfg=Get-Content (Join-Path (Get-Location) 'runtime/memory/schema.json') -Raw | ConvertFrom-Json
$r=$RecordJson | ConvertFrom-Json
$missing=@($cfg.required_fields | Where-Object { [string]::IsNullOrWhiteSpace([string]$r.$_) })
$forbidden=@($cfg.forbidden_fields | Where-Object { $null -ne $r.$_ })
[ordered]@{valid=($missing.Count -eq 0 -and $forbidden.Count -eq 0);missing=$missing;forbidden=$forbidden} | ConvertTo-Json -Compress
if($missing.Count -gt 0 -or $forbidden.Count -gt 0){exit 2}
