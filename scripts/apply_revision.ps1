param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectRoot,
  [Parameter(Mandatory = $true)]
  [string]$ProposalId
)

$ErrorActionPreference = "Stop"

function Ensure-File {
  param([string]$Path, [string]$Message)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw $Message
  }
}

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Read-Utf8 {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-Utf8 {
  param([string]$Path, [string]$Content)
  $dir = Split-Path -Parent $Path
  if ($dir) { Ensure-Dir $dir }
  [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($true))
}

function Write-Json {
  param([string]$Path, [object]$Value)
  Write-Utf8 -Path $Path -Content ($Value | ConvertTo-Json -Depth 30)
}

function Get-FileSha256 {
  param([string]$Path)
  Ensure-File -Path $Path -Message "Missing file for hash: $Path"
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $stream = [System.IO.File]::OpenRead($Path)
    try {
      $hash = $sha.ComputeHash($stream)
      return (($hash | ForEach-Object { $_.ToString("x2") }) -join "")
    }
    finally {
      if ($stream) { $stream.Dispose() }
    }
  }
  finally {
    if ($sha) { $sha.Dispose() }
  }
}

function Resolve-ProjectPath {
  param([string]$Root, [string]$RelativePath)
  if ([System.IO.Path]::IsPathRooted($RelativePath)) {
    throw "Revision apply blocked: proposal paths must be project-relative."
  }
  $rootFull = [System.IO.Path]::GetFullPath($Root)
  $targetFull = [System.IO.Path]::GetFullPath((Join-Path $rootFull $RelativePath))
  if (-not $targetFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Revision apply blocked: path escapes project root: $RelativePath"
  }
  return $targetFull
}

function Test-ReaderTextClean {
  param([string]$Text)
  $mojibakePattern = ("[{0}{1}{2}{3}{4}]|\?{{2,}}" -f [char]0x00C3, [char]0x00C4, [char]0x00C5, [char]0x00F0, [char]0xFFFD)
  $forbidden = @(
    "(?im)^\s*#\s*(EP|Sahne|Scene)\b",
    "(?i)\bEP\d{2,}\b",
    "(?i)\brun_id\b|\bstep_id\b|\bVERDICT\b|\bagent-compliance\b",
    $mojibakePattern
  )
  foreach ($pattern in $forbidden) {
    if ($Text -match $pattern) {
      throw "Revision apply blocked: replacement text contains forbidden reader-facing/control pattern '$pattern'."
    }
  }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$proposalPath = Join-Path $ProjectRoot "revision/_workspace/revision-proposals.json"
$approvalPath = Join-Path $ProjectRoot "runtime/approvals/revision-proposals-approval.json"
$appliedDir = Join-Path $ProjectRoot "revision/_workspace/applied"

Ensure-File -Path $proposalPath -Message "Revision apply blocked: missing revision/_workspace/revision-proposals.json. Run scripts/revision_proposals.ps1 first."
Ensure-File -Path $approvalPath -Message "Revision apply blocked: missing runtime/approvals/revision-proposals-approval.json."

$proposalSet = Read-Utf8 -Path $proposalPath | ConvertFrom-Json
$approval = Read-Utf8 -Path $approvalPath | ConvertFrom-Json

if ($approval.approved -ne $true) {
  throw "Revision apply blocked: revision-proposals-approval.json approved must be true."
}

$approvedIds = @($approval.approved_proposal_ids | ForEach-Object { [string]$_ })
if ($approvedIds -notcontains $ProposalId) {
  throw "Revision apply blocked: proposal '$ProposalId' is not listed in approved_proposal_ids."
}

$proposal = @($proposalSet.proposals | Where-Object { [string]$_.id -eq $ProposalId } | Select-Object -First 1)[0]
if (-not $proposal) {
  throw "Revision apply blocked: proposal not found: $ProposalId"
}
if (-not [string]$proposal.target_file -or -not [string]$proposal.replacement_file) {
  throw "Revision apply blocked: proposal '$ProposalId' has no target/replacement file."
}

$targetPath = Resolve-ProjectPath -Root $ProjectRoot -RelativePath ([string]$proposal.target_file)
$replacementPath = Resolve-ProjectPath -Root $ProjectRoot -RelativePath ([string]$proposal.replacement_file)
Ensure-File -Path $targetPath -Message "Revision apply blocked: target file missing: $($proposal.target_file)"
Ensure-File -Path $replacementPath -Message "Revision apply blocked: replacement file missing: $($proposal.replacement_file)"

$replacementText = Read-Utf8 -Path $replacementPath
if (-not $replacementText.Trim()) {
  throw "Revision apply blocked: replacement text is empty."
}
Test-ReaderTextClean -Text $replacementText

Ensure-Dir $appliedDir
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupRel = "revision/_workspace/applied/$ProposalId-$timestamp.before.md"
$backupPath = Resolve-ProjectPath -Root $ProjectRoot -RelativePath $backupRel
Copy-Item -LiteralPath $targetPath -Destination $backupPath -Force

$beforeHash = Get-FileSha256 -Path $targetPath
$replacementHash = Get-FileSha256 -Path $replacementPath
Write-Utf8 -Path $targetPath -Content $replacementText
$afterHash = Get-FileSha256 -Path $targetPath

$logPath = Join-Path $appliedDir "$ProposalId-$timestamp.apply.json"
Write-Json -Path $logPath -Value ([ordered]@{
  schema_version = "1.0.0"
  applied_at = (Get-Date).ToString("o")
  proposal_id = $ProposalId
  approval_file = "runtime/approvals/revision-proposals-approval.json"
  target_file = [string]$proposal.target_file
  replacement_file = [string]$proposal.replacement_file
  backup_file = $backupRel
  before_sha256 = $beforeHash
  replacement_sha256 = $replacementHash
  after_sha256 = $afterHash
  policy = "Only an explicitly approved proposal may replace an episode file."
})

Write-Host "[apply-revision] applied $ProposalId to $($proposal.target_file)"
Write-Host "[apply-revision] backup: $backupRel"
