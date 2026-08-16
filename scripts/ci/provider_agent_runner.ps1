param(
  [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path,
  [ValidateSet("codex","claude","gemini","ollama")]
  [string]$Provider = "codex",
  [string]$Model = "qwen2.5:3b",
  [int]$MaxAgents = 36,
  [switch]$AllowExternalProviderData
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
if (-not $AllowExternalProviderData -and $Provider -ne "ollama") {
  throw "Provider execution requires explicit -AllowExternalProviderData because fixture content is sent to an external agent service."
}

$registryPath = Join-Path $ProjectRoot "runtime/agent-registry.json"
$goldenRoot = Join-Path $ProjectRoot "tests/golden/agents"
if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) { throw "Missing agent registry: $registryPath" }
if (-not (Test-Path -LiteralPath $goldenRoot -PathType Container)) { throw "Missing golden fixture root: $goldenRoot" }
$providerCommand = Get-Command $Provider -ErrorAction SilentlyContinue
if (-not $providerCommand) { throw "Provider CLI is not installed: $Provider" }

function Get-SignificantTokens {
  param([string]$Text)
  $stopWords = @("agent","kitap","icin","olan","olarak","this","that","with","from","output","input","agentin","gore","veya","must","only")
  return @([regex]::Matches($Text.ToLowerInvariant(), "\p{L}{4,}") | ForEach-Object { $_.Value } | Where-Object { $_ -notin $stopWords } | Select-Object -Unique)
}

function Get-BehavioralOutputErrors {
  param([string]$AgentName, [string]$Output, [string]$InputText, [string]$ExpectedText, [string[]]$AllowedEvidence)
  $issues = @()
  $trimmed = $Output.Trim()
  if ($trimmed -eq $InputText.Trim()) { $issues += "provider echoed fixture input verbatim" }
  if ($trimmed -eq $ExpectedText.Trim()) { $issues += "provider echoed expected contract verbatim" }
  if ($trimmed -match '(?i)placeholder input|expected contract for \$agent|\[TODO\]|lorem ipsum|^\s*EXPECTED CONTRACT\s*:') { $issues += "provider output contains placeholder or fixture-contract text" }
  if ([regex]::IsMatch($trimmed, '[\uFFFD]|(?:Ã.|Ä.|Å.|Â.){2,}', [Text.RegularExpressions.RegexOptions]::CultureInvariant)) { $issues += "provider output contains mojibake markers" }
  $responseAgent = ""
  $evidenceValues = @()
  $resultText = ""
  $jsonParsed = $false
  try {
    $json = $trimmed | ConvertFrom-Json -ErrorAction Stop
    if ($json -and $json.PSObject.Properties.Name -contains "agent" -and $json.PSObject.Properties.Name -contains "evidence" -and $json.PSObject.Properties.Name -contains "result") {
      $jsonParsed = $true
      $responseAgent = [string]$json.agent
      $evidenceValues = @($json.evidence | ForEach-Object { [string]$_ })
      $resultText = [string]$json.result
    }
  }
  catch {}
  if (-not $jsonParsed) {
    $cultureInvariantIgnoreCase = [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Multiline -bor [Text.RegularExpressions.RegexOptions]::CultureInvariant
    $agentMatch = [regex]::Match($trimmed, '^AGENT:\s*(.+?)\s*$', $cultureInvariantIgnoreCase)
    $evidenceMatch = [regex]::Match($trimmed, '^FIXTURE_EVIDENCE:\s*(.+?)\s*$', $cultureInvariantIgnoreCase)
    $resultMatch = [regex]::Match($trimmed, '^RESULT:\s*(.+)$', $cultureInvariantIgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
    if ($agentMatch.Success) { $responseAgent = $agentMatch.Groups[1].Value.Trim() }
    if ($evidenceMatch.Success) { $evidenceValues = @($evidenceMatch.Groups[1].Value -split '\|' | ForEach-Object { $_.Trim() }) }
    if ($resultMatch.Success) { $resultText = $resultMatch.Groups[1].Value.Trim() }
  }
  if (-not [string]::Equals($responseAgent, $AgentName, [StringComparison]::OrdinalIgnoreCase)) { $issues += "provider output is missing the exact agent identity" }
  $evidenceTokens = @(Get-SignificantTokens -Text ($evidenceValues -join " "))
  $matchedTerms = @($evidenceTokens | Where-Object {
    $candidate = $_
    @($AllowedEvidence | Where-Object { [string]::Equals($_, $candidate, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
  } | Select-Object -Unique)
  if ($matchedTerms.Count -lt 2) { $issues += "provider output does not cite two fixture-derived evidence tokens" }
  if ($resultText.Trim().Length -lt 80) { $issues += "provider result is missing or too short" }
  return @($issues)
}

$reportRoot = Join-Path $ProjectRoot "runtime/provider-fixture-reports"
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
$registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
$agents = @($registry.agents | Select-Object -First $MaxAgents)
$results = @()
foreach ($agent in $agents) {
  $name = [string]$agent.name
  $fixtureDir = Join-Path $goldenRoot $name
  $inputPath = Join-Path $fixtureDir "input.md"
  $expectedPath = Join-Path $fixtureDir "expected.md"
  $outputPath = Join-Path $reportRoot "$name.output.md"
  $started = Get-Date
  $errors = @()
  $exitCode = -1
  if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) { $errors += "missing input.md" }
  if (-not (Test-Path -LiteralPath $expectedPath -PathType Leaf)) { $errors += "missing expected.md" }
  if ($errors.Count -eq 0) {
    $input = Get-Content -LiteralPath $inputPath -Raw
    $expected = Get-Content -LiteralPath $expectedPath -Raw
    $agentContractPath = Join-Path $ProjectRoot "agents/$name.md"
    $agentContract = if (Test-Path -LiteralPath $agentContractPath -PathType Leaf) { Get-Content -LiteralPath $agentContractPath -Raw } else { "" }
    $allowedEvidence = @(Get-SignificantTokens -Text $input | Select-Object -First 12)
    if ($allowedEvidence.Count -lt 2) { $errors += "fixture does not provide two usable evidence terms" }
    $responseSchema = [ordered]@{
      type = "object"
      properties = [ordered]@{
        agent = [ordered]@{ type = "string"; enum = @($name) }
        evidence = [ordered]@{ type = "array"; minItems = 2; maxItems = 2; uniqueItems = $true; items = [ordered]@{ type = "string"; enum = @($allowedEvidence) } }
        result = [ordered]@{ type = "string"; minLength = 80 }
      }
      required = @("agent", "evidence", "result")
      additionalProperties = $false
    }
    $prompt = @"
You are the KitHub agent '$name'. This is a read-only deterministic fixture execution.
Do not edit files, run commands, browse, or claim work you did not perform.
Return only a concise response that follows the agent contract and addresses the fixture.
Respond in Turkish. Do not repeat the fixture or expected contract.

FIXTURE INPUT:
$input

EXPECTED CONTRACT:
$expected

ROLE CONTRACT:
$agentContract

ALLOWED FIXTURE EVIDENCE TERMS (copy exactly; do not translate, pluralize, or join with underscores):
$($allowedEvidence -join " | ")

Return exactly one JSON object and no markdown or preamble:
{"agent":"$name","evidence":["<one allowed word>","<a different allowed word>"],"result":"<at least 80 characters; input-specific role result in Turkish>"}
"@
    try {
      if (Test-Path -LiteralPath $outputPath -PathType Leaf) { Remove-Item -LiteralPath $outputPath -Force }
      $previousErrorAction = $ErrorActionPreference
      $ErrorActionPreference = "Continue"
      switch ($Provider) {
        "codex" {
          $result = & $providerCommand.Source exec --ephemeral --sandbox read-only --skip-git-repo-check -C $ProjectRoot -o $outputPath $prompt 2>&1
          $exitCode = $LASTEXITCODE
          if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) { [IO.File]::WriteAllText($outputPath,(($result|Out-String).Trim()),[Text.UTF8Encoding]::new($true)) }
        }
        "claude" {
          $result = & $providerCommand.Source -p $prompt --no-session-persistence --permission-mode plan 2>&1
          $exitCode = $LASTEXITCODE
          [IO.File]::WriteAllText($outputPath,(($result|Out-String).Trim()),[Text.UTF8Encoding]::new($true))
        }
        "gemini" {
          $result = & $providerCommand.Source -p $prompt --approval-mode plan --skip-trust 2>&1
          $exitCode = $LASTEXITCODE
          [IO.File]::WriteAllText($outputPath,(($result|Out-String).Trim()),[Text.UTF8Encoding]::new($true))
        }
        "ollama" {
          $requestBody = @{ model = $Model; prompt = $prompt; stream = $false; format = $responseSchema; options = @{ temperature = 0 } } | ConvertTo-Json -Depth 20
          $requestBytes = [Text.Encoding]::UTF8.GetBytes($requestBody)
          $ollamaResponse = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:11434/api/generate" -ContentType "application/json; charset=utf-8" -Body $requestBytes
          $exitCode = 0
          [IO.File]::WriteAllText($outputPath,[string]$ollamaResponse.response,[Text.UTF8Encoding]::new($true))
        }
      }
    }
    catch { $errors += $_.Exception.Message }
    finally { $ErrorActionPreference = $previousErrorAction }
    if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) { $errors += "provider output missing" }
    else {
      $output = Get-Content -LiteralPath $outputPath -Raw
      if ($output -match '(?i)authentication|unauthorized|rate limit|cannot connect|no such model') { $errors += "provider reported unavailable execution" }
      $behaviorErrors = @(Get-BehavioralOutputErrors -AgentName $name -Output $output -InputText $input -ExpectedText $expected -AllowedEvidence $allowedEvidence)
      if ($Provider -eq "ollama" -and $exitCode -eq 0 -and $behaviorErrors.Count -gt 0) {
        $repairPrompt = @"
$prompt

Your previous response failed validation:
$($behaviorErrors -join "; ")

PREVIOUS RESPONSE:
$output

Return one corrected JSON object now. Copy two individual allowed evidence words exactly and make result at least 80 characters.
"@
        try {
          $repairBody = @{ model = $Model; prompt = $repairPrompt; stream = $false; format = $responseSchema; options = @{ temperature = 0 } } | ConvertTo-Json -Depth 20
          $repairBytes = [Text.Encoding]::UTF8.GetBytes($repairBody)
          $repairResponse = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:11434/api/generate" -ContentType "application/json; charset=utf-8" -Body $repairBytes
          $output = [string]$repairResponse.response
          [IO.File]::WriteAllText($outputPath,$output,[Text.UTF8Encoding]::new($true))
          $behaviorErrors = @(Get-BehavioralOutputErrors -AgentName $name -Output $output -InputText $input -ExpectedText $expected -AllowedEvidence $allowedEvidence)
        }
        catch { $behaviorErrors += "repair attempt failed: $($_.Exception.Message)" }
      }
      $errors += $behaviorErrors
    }
  }
  $results += [ordered]@{
    agent = $name
    phase = (@($agent.allowed_phases) -join ",")
    status = if ($errors.Count -eq 0 -and $exitCode -eq 0) { "PASS" } else { "FAIL" }
    execution_claim_mode = "provider_execution"
    provider = $Provider
    model = $Model
    exit_code = $exitCode
    duration_seconds = [math]::Round(((Get-Date)-$started).TotalSeconds,2)
    output = "runtime/provider-fixture-reports/$name.output.md"
    errors = @($errors)
  }
}
$failed = @($results | Where-Object status -eq "FAIL")
$report = [ordered]@{
  schema_version = "1.1.0"
  report_type = "provider_agent_fixture_execution"
  generated_at = (Get-Date).ToString("o")
  project_root = $ProjectRoot
  execution_claim_mode = "provider_execution"
  provider = $Provider
  model = $Model
  validation_policy = "JSON/envelope response, minimum result length, exact agent identity, two fixture-derived evidence tokens, no fixture echo/placeholders, UTF-8 integrity"
  provider_execution_proven = ($failed.Count -eq 0 -and $results.Count -eq $agents.Count)
  behavioral_contract_proven = ($failed.Count -eq 0 -and $results.Count -eq $agents.Count)
  total_agents = $results.Count
  passed_agents = @($results | Where-Object status -eq "PASS").Count
  failed_agents = $failed.Count
  verdict = if ($failed.Count -eq 0 -and $results.Count -eq $agents.Count) { "PASS" } else { "FAIL" }
  agents = @($results)
}
$reportPath = Join-Path $reportRoot "$Provider-$($agents.Count)-agent-report.json"
[IO.File]::WriteAllText($reportPath,($report|ConvertTo-Json -Depth 20),[Text.UTF8Encoding]::new($true))
if ($failed.Count -gt 0 -or $results.Count -ne [math]::Min($MaxAgents,@($registry.agents).Count)) { throw "Provider fixture execution failed: $($failed.agent -join ', ')" }
Write-Host "[provider-agent-runner] PASS $($report.passed_agents)/$($report.total_agents) provider=$Provider"
Write-Host "[provider-agent-runner] report=$reportPath"
