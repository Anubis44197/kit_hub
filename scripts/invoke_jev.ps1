<#
.SYNOPSIS
    TypeSafe Jev PowerShell Entegrasyon Köprüsü
.DESCRIPTION
    Kit_Hub pipeline ve scriptleri için Jev System One karar motorunu çağırır.
.EXAMPLE
    .\scripts\invoke_jev.ps1 -Action route -Text "Ahmet silahini cekti."
    .\scripts\invoke_jev.ps1 -Action quality -Text "Metin buraya..."
    .\scripts\invoke_jev.ps1 -Action gate -Text "Dışa aktarılacak metin..."
#>

param (
    [Parameter(Mandatory=$false)]
    [ValidateSet("route", "quality", "gate", "test")]
    [string]$Action = "test",

    [Parameter(Mandatory=$false)]
    [string]$Text = ""
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$clientJs = Join-Path $scriptDir "typesafe_jev_client.js"

if (-not (Test-Path $clientJs)) {
    Write-Error "typesafe_jev_client.js bulunamadı: $clientJs"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($Text)) {
    & node $clientJs "--$Action"
} else {
    & node $clientJs $Action $Text
}
