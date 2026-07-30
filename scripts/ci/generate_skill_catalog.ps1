param(
  [string]$ProjectRoot = (Get-Location).Path,
  [ValidateSet("json", "xml")]
  [string]$Format = "json",
  [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"

function Read-Utf8 {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Get-FrontmatterValue {
  param(
    [string]$Raw,
    [string]$Key,
    [string]$Path
  )

  $match = [regex]::Match($Raw, "(?m)^\s*$([regex]::Escape($Key))\s*:\s*(.+?)\s*$")
  if (-not $match.Success) {
    throw "Missing frontmatter field '$Key' in $Path"
  }
  $value = $match.Groups[1].Value.Trim()
  if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
    $value = $value.Substring(1, $value.Length - 2)
  }
  return $value
}

function Get-AgentSkillPhases {
  param(
    [string]$ProjectRoot,
    [string]$SkillPath
  )

  $relative = ($SkillPath.Substring($ProjectRoot.Length).TrimStart("\", "/")) -replace "\\", "/"
  $phaseDir = Join-Path $ProjectRoot "runtime/phase-contracts"
  if (-not (Test-Path -LiteralPath $phaseDir -PathType Container)) {
    return @()
  }

  $phases = @()
  foreach ($contractFile in Get-ChildItem -LiteralPath $phaseDir -Filter "*.json" -File) {
    $raw = Read-Utf8 -Path $contractFile.FullName
    if ($raw -like "*$relative*") {
      $phases += [System.IO.Path]::GetFileNameWithoutExtension($contractFile.Name)
    }
  }
  return @($phases | Sort-Object -Unique)
}

function ConvertTo-XmlText {
  param([string]$Value)
  return [System.Security.SecurityElement]::Escape($Value)
}

$skillsRoot = Join-Path $ProjectRoot "skills"
if (-not (Test-Path -LiteralPath $skillsRoot -PathType Container)) {
  throw "Missing skills directory: $skillsRoot"
}

$skillRecords = @()
foreach ($skillFile in Get-ChildItem -LiteralPath $skillsRoot -Recurse -Filter "SKILL.md" -File | Sort-Object FullName) {
  $raw = Read-Utf8 -Path $skillFile.FullName
  $name = Get-FrontmatterValue -Raw $raw -Key "name" -Path $skillFile.FullName
  $description = Get-FrontmatterValue -Raw $raw -Key "description" -Path $skillFile.FullName
  $relativePath = ($skillFile.FullName.Substring($ProjectRoot.Length).TrimStart("\", "/")) -replace "\\", "/"
  $skillRecords += [pscustomobject]@{
    name = $name
    description = $description
    location = $relativePath
    phases = @(Get-AgentSkillPhases -ProjectRoot $ProjectRoot -SkillPath $skillFile.FullName)
  }
}

if ($Format -eq "json") {
  $payload = [pscustomobject]@{
    schema_version = 1
    format = "agent-skills-catalog"
    skills = $skillRecords
  } | ConvertTo-Json -Depth 8
} else {
  $lines = @("<available_skills>")
  foreach ($skill in $skillRecords) {
    $lines += "<skill>"
    $lines += "<name>$(ConvertTo-XmlText $skill.name)</name>"
    $lines += "<description>$(ConvertTo-XmlText $skill.description)</description>"
    $lines += "<location>$(ConvertTo-XmlText $skill.location)</location>"
    if (@($skill.phases).Count -gt 0) {
      $lines += "<phases>$(ConvertTo-XmlText ((@($skill.phases) -join ' ')))</phases>"
    }
    $lines += "</skill>"
  }
  $lines += "</available_skills>"
  $payload = $lines -join [Environment]::NewLine
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $payload
} else {
  $fullOutput = if ([System.IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $ProjectRoot $OutputPath }
  $parent = Split-Path -Parent $fullOutput
  if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  [System.IO.File]::WriteAllText($fullOutput, $payload + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
  Write-Host "[skill-catalog] wrote $fullOutput"
}
