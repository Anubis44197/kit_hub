param(
  [string]$ProjectRoot = (Get-Location).Path,
  [switch]$StrictAgentSkillsFields
)

$ErrorActionPreference = "Stop"

$allowedSpecFields = @(
  "name",
  "description",
  "license",
  "compatibility",
  "metadata",
  "allowed-tools"
)
$allowedLocalFields = @("prompt_version")
$allowedFields = if ($StrictAgentSkillsFields) { $allowedSpecFields } else { $allowedSpecFields + $allowedLocalFields }

function Read-Utf8 {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Get-SkillFrontmatter {
  param([string]$Path)

  $raw = Read-Utf8 -Path $Path
  $lines = $raw -split "`r?`n"
  if ($lines.Count -lt 3 -or $lines[0].Trim() -ne "---") {
    throw "SKILL.md must start with YAML frontmatter: $Path"
  }

  $closingIndex = -1
  for ($i = 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Trim() -eq "---") {
      $closingIndex = $i
      break
    }
  }
  if ($closingIndex -lt 0) {
    throw "SKILL.md frontmatter is not closed with ---: $Path"
  }

  $metadata = [ordered]@{}
  for ($i = 1; $i -lt $closingIndex; $i++) {
    $line = $lines[$i]
    if ($line.Trim().Length -eq 0 -or $line.TrimStart().StartsWith("#")) {
      continue
    }
    $match = [regex]::Match($line, "^\s*([A-Za-z0-9_-]+)\s*:\s*(.*)\s*$")
    if (-not $match.Success) {
      throw "Unsupported frontmatter line in $Path`: $line"
    }
    $key = $match.Groups[1].Value.Trim()
    $value = $match.Groups[2].Value.Trim()
    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
      $value = $value.Substring(1, $value.Length - 2)
    }
    if ($metadata.Contains($key)) {
      throw "Duplicate frontmatter field '$key' in $Path"
    }
    $metadata[$key] = $value
  }

  return [pscustomobject]@{
    Metadata = $metadata
    BodyLineCount = [Math]::Max(0, $lines.Count - $closingIndex - 1)
  }
}

function Assert-Name {
  param(
    [string]$Name,
    [string]$DirectoryName,
    [string]$Path
  )

  if ([string]::IsNullOrWhiteSpace($Name)) {
    throw "Field 'name' must be a non-empty string: $Path"
  }
  if ($Name.Length -gt 64) {
    throw "Skill name exceeds 64 characters: $Path"
  }
  if ($Name -cne $Name.ToLowerInvariant()) {
    throw "Skill name must be lowercase: $Path"
  }
  if ($Name.StartsWith("-") -or $Name.EndsWith("-")) {
    throw "Skill name cannot start or end with a hyphen: $Path"
  }
  if ($Name.Contains("--")) {
    throw "Skill name cannot contain consecutive hyphens: $Path"
  }
  if ($Name -notmatch "^[a-z0-9]+(?:-[a-z0-9]+)*$") {
    throw "Skill name may only contain lowercase ASCII letters, digits, and hyphens: $Path"
  }
  if ($Name -ne $DirectoryName) {
    throw "Skill name '$Name' must match directory name '$DirectoryName': $Path"
  }
}

function Assert-Description {
  param(
    [string]$Description,
    [string]$Path
  )

  if ([string]::IsNullOrWhiteSpace($Description)) {
    throw "Field 'description' must be a non-empty string: $Path"
  }
  if ($Description.Length -gt 1024) {
    throw "Description exceeds 1024 characters: $Path"
  }
}

function Assert-CompatibleMetadata {
  param(
    [object]$Metadata,
    [string]$Path
  )

  foreach ($key in $Metadata.Keys) {
    if ($allowedFields -notcontains $key) {
      throw "Unexpected frontmatter field '$key' in $Path. Allowed fields: $($allowedFields -join ', ')"
    }
  }

  foreach ($required in @("name", "description")) {
    if (-not $Metadata.Contains($required)) {
      throw "Missing required frontmatter field '$required' in $Path"
    }
  }

  if ($Metadata.Contains("compatibility") -and [string]$Metadata["compatibility"].Length -gt 500) {
    throw "Compatibility exceeds 500 characters: $Path"
  }

  if (-not $StrictAgentSkillsFields) {
    if (-not $Metadata.Contains("prompt_version")) {
      throw "Missing local required frontmatter field 'prompt_version' in $Path"
    }
    if ([string]$Metadata["prompt_version"] -notmatch '^\d+\.\d+\.\d+$') {
      throw "prompt_version must use SemVer format, e.g. 1.0.0: $Path"
    }
  }
}

$skillsRoot = Join-Path $ProjectRoot "skills"
if (-not (Test-Path -LiteralPath $skillsRoot -PathType Container)) {
  throw "Missing skills directory: $skillsRoot"
}

$skillFiles = Get-ChildItem -LiteralPath $skillsRoot -Recurse -Filter "SKILL.md" -File | Sort-Object FullName
if (@($skillFiles).Count -lt 1) {
  throw "No SKILL.md files found under $skillsRoot"
}

foreach ($file in $skillFiles) {
  $parsed = Get-SkillFrontmatter -Path $file.FullName
  $metadata = $parsed.Metadata
  Assert-CompatibleMetadata -Metadata $metadata -Path $file.FullName
  Assert-Name -Name ([string]$metadata["name"]) -DirectoryName $file.Directory.Name -Path $file.FullName
  Assert-Description -Description ([string]$metadata["description"]) -Path $file.FullName
}

Write-Host "[skill-standard] PASS ($(@($skillFiles).Count) skills)"
