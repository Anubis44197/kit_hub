# Ledger-filler model çağrı kütüphanesi (dot-source edilir).
# provider_phase.ps1'in Invoke-DirectProviderApi'si ile AYNI env sözleşmesi:
#   KITHUB_API_PROVIDER      : openai (varsayilan) | anthropic | gemini | openrouter | ollama
#   KITHUB_API_MODEL         : zorunlu (yoksa cagri bloklanir -> cagiran taraf fail-open atlar)
#   KITHUB_API_KEY           : API anahtari (yerel model icin bos + ALLOW_EMPTY_KEY=1)
#   KITHUB_API_BASE_URL      : opsiyonel tam endpoint; yoksa saglayici varsayilani
#   KITHUB_API_ALLOW_EMPTY_KEY : "1" -> bos anahtara izin (Ollama/LM Studio/llama.cpp)
# Donus: modelin duz metin yaniti (chat content). Hata firlatir; cagiran try/catch ile atlar.

function Invoke-LedgerModelApi {
  param([Parameter(Mandatory = $true)][string]$Prompt)

  $provider = if ($env:KITHUB_API_PROVIDER) { [string]$env:KITHUB_API_PROVIDER } else { "openai" }
  $model = [string]$env:KITHUB_API_MODEL
  $apiKey = [string]$env:KITHUB_API_KEY
  $baseUrl = [string]$env:KITHUB_API_BASE_URL
  $allowEmptyKey = ([string]$env:KITHUB_API_ALLOW_EMPTY_KEY).Trim() -eq "1"
  if (-not $model.Trim()) { throw "KITHUB_API_MODEL ayarli degil; defter guncellemesi icin model gerekli." }
  if (-not $apiKey.Trim() -and -not $allowEmptyKey) {
    throw "KITHUB_API_KEY ayarli degil (yerel model icin KITHUB_API_ALLOW_EMPTY_KEY=1 ayarlayin)."
  }

  if (-not $baseUrl.Trim()) {
    if ($provider -eq "anthropic") { $baseUrl = "https://api.anthropic.com/v1/messages" }
    elseif ($provider -eq "gemini") { $baseUrl = "https://generativelanguage.googleapis.com/v1beta" }
    elseif ($provider -eq "openrouter") { $baseUrl = "https://openrouter.ai/api/v1/chat/completions" }
    else { $baseUrl = "https://api.openai.com/v1/chat/completions" }
  }

  if ($provider -eq "anthropic") {
    $headers = @{ "x-api-key" = $apiKey; "anthropic-version" = "2023-06-01"; "content-type" = "application/json" }
    $body = @{ model = $model; max_tokens = 2048; messages = @(@{ role = "user"; content = $Prompt }) } | ConvertTo-Json -Depth 20
    $resp = Invoke-RestMethod -Method Post -Uri $baseUrl -Headers $headers -Body $body -TimeoutSec $script:TimeoutSeconds
    return (@($resp.content) | ForEach-Object { [string]$_.text }) -join "`n"
  }

  if ($provider -eq "gemini") {
    $uri = "$($baseUrl.TrimEnd('/'))/models/$model`:generateContent?key=$apiKey"
    $body = @{ contents = @(@{ parts = @(@{ text = $Prompt }) }) } | ConvertTo-Json -Depth 20
    $resp = Invoke-RestMethod -Method Post -Uri $uri -ContentType "application/json" -Body $body -TimeoutSec $script:TimeoutSeconds
    return (@($resp.candidates[0].content.parts) | ForEach-Object { [string]$_.text }) -join "`n"
  }

  # openai-uyumlu (openai, openrouter, ollama /v1/chat/completions, LM Studio, ...)
  $headers = @{ "content-type" = "application/json" }
  if ($apiKey.Trim()) { $headers["Authorization"] = "Bearer $apiKey" }
  if ($provider -eq "openrouter") {
    $headers["HTTP-Referer"] = "http://127.0.0.1:8765"
    $headers["X-Title"] = "KitHub Studio"
  }
  $body = @{
    model = $model
    temperature = 0.2
    messages = @(
      @{ role = "system"; content = "You are the KitHub story ledger keeper. Return only strict JSON." },
      @{ role = "user"; content = $Prompt }
    )
  } | ConvertTo-Json -Depth 20
  $resp = Invoke-RestMethod -Method Post -Uri $baseUrl -Headers $headers -Body $body -TimeoutSec $script:TimeoutSeconds
  return [string]$resp.choices[0].message.content
}
