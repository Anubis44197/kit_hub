[CmdletBinding()]
param([string]$ProjectRoot=(Get-Location).Path)
# codebase-memory-mcp: binary KURULUM dizininden calistirilir; repo kopyasi (.tools)
# DACL-kirli zincirde oldugu icin oradan baslatilamaz (bkz. scripts/install_codebase_memory.ps1).
$cbmRepoCopy=Join-Path $ProjectRoot '.tools/codebase-memory-mcp/codebase-memory-mcp.exe'
$cbmInstalled=Join-Path $env:LOCALAPPDATA 'Programs/codebase-memory-mcp/codebase-memory-mcp.exe'
$cbmExe=if(Test-Path -LiteralPath $cbmInstalled -PathType Leaf){$cbmInstalled}else{$cbmRepoCopy}
$items=@(
  @{id='codebase-memory-mcp'; config='runtime/adapters/codebase-memory-mcp.json'; exe=$cbmExe; args=@('--version')},
  @{id='observer'; config='runtime/adapters/observer.json'; exe='.tools/observer/observer.exe'; args=@('--version')},
  @{id='omniroute'; config='runtime/adapters/omniroute.json'; exe=$null; args=@()},
  @{id='headroom'; config='runtime/adapters/headroom.json'; exe=$null; args=@()}
)
$out=@()
foreach($i in $items){
  $c=Get-Content (Join-Path $ProjectRoot $i.config) -Raw | ConvertFrom-Json
  $e=if($i.exe){if([System.IO.Path]::IsPathRooted($i.exe)){$i.exe}else{Join-Path $ProjectRoot $i.exe}}else{$null}
  $binaryPresent=$false
  if($null -ne $e){
    try { $binaryPresent=(Test-Path -LiteralPath $e -PathType Leaf -ErrorAction Stop) } catch { $binaryPresent=$false }
  }
  $row=[ordered]@{id=$i.id; enabled=[bool]$c.enabled; mode=[string]$c.mode; config=$i.config; binary_present=$binaryPresent; version=$null; sha256=$null; fallback=$c.fallback; notes=$c.notes}
  if($row.binary_present){
    try { $row.version=((& $e @($i.args) 2>$null) | Out-String).Trim() } catch { $row.version=$null }
    try { $row.sha256=(Get-FileHash -LiteralPath $e -Algorithm SHA256 -ErrorAction Stop).Hash.ToLower() } catch { $row.sha256=$null }
  }
  $out+=[pscustomobject]$row
}
$out | ConvertTo-Json -Depth 8
