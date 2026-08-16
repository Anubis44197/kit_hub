param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$indexPath = Join-Path $RepoRoot "index.html"
if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) { throw "Studio index not found: $indexPath" }

$html = [IO.File]::ReadAllText($indexPath, [Text.Encoding]::UTF8)

function Assert-ContainsLiteral {
  param([string]$Value,[string]$Message)
  if (-not $html.Contains($Value)) { throw $Message }
}

# Approved backwards-compatible defaults. New editor, page and publishing
# features may extend them, but must not rename or silently change them.
foreach ($font in @("Garamond","Times New Roman","Georgia","Palatino Linotype","Courier New")) {
  Assert-ContainsLiteral "<option>$font</option>" "Existing font option changed or removed: $font"
}
Assert-ContainsLiteral '--book: Garamond, "EB Garamond", "Times New Roman", serif;' "Default book font stack changed."
Assert-ContainsLiteral '<option>A5 (148 x 210 mm)</option>' "Existing A5 page choice was removed."
Assert-ContainsLiteral '<option>A4 (210 x 297 mm)</option>' "Existing A4 page choice was removed."
Assert-ContainsLiteral '<option>6 x 9 in (152 x 229 mm)</option>' "6x9 trade paperback page choice was removed."
$customOptionLiteral = "<option>$([char]0x00D6)zel $([char]0x00F6)l$([char]0x00E7)$([char]0x00FC)...</option>"
Assert-ContainsLiteral $customOptionLiteral "Custom page size entry was removed."
Assert-ContainsLiteral 'getPageDimensions' "Custom page size dimension resolution was removed."
Assert-ContainsLiteral '<select id="pageDesign">' "Page design selector was removed."
Assert-ContainsLiteral '<option value="classicFrame">' "Existing page appearance is no longer the default design option."
Assert-ContainsLiteral 'label: "Roman Klasik"' "Classic novel layout profile was removed."
Assert-ContainsLiteral 'pageSize: "A5 (148 x 210 mm)"' "Classic A5 page baseline was removed."
Assert-ContainsLiteral 'font: "Garamond"' "Classic Garamond baseline was removed."
Assert-ContainsLiteral 'size: 11.5' "Classic 11.5 point baseline was removed."
Assert-ContainsLiteral 'line: 1.15' "Classic line-height baseline was removed."
Assert-ContainsLiteral 'top: 18' "Classic top margin baseline was removed."
Assert-ContainsLiteral 'inside: 20' "Classic inside margin baseline was removed."
Assert-ContainsLiteral 'outside: 16' "Classic outside margin baseline was removed."
Assert-ContainsLiteral 'indent: 0.55' "Classic paragraph indent baseline was removed."

Write-Host "[studio-typography-baseline] PASS existing fonts; A5/A4 and 5x8/5.25x8/5.5x8.5/6x9/custom page choices; classic page design; classic novel metrics"
