$ErrorActionPreference = "Stop"
$configPath = Join-Path $HOME ".config\jarvis\config.json"
if (-not (Test-Path $configPath)) {
    throw "Jarvis config not found at $configPath"
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = "$configPath.backup-$stamp"
Copy-Item $configPath $backup
Write-Host "Backed up config to $backup" -ForegroundColor Cyan

$config = Get-Content $configPath -Raw | ConvertFrom-Json

function Set-JsonProperty($obj, [string]$name, $value) {
    $prop = $obj.PSObject.Properties[$name]
    if ($null -eq $prop) {
        $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value
    } else {
        $obj.$name = $value
    }
}

# Pin the intended local model stack. Set both the provider-aware fields and
# the older Ollama aliases so either config path resolves to the same models.
Set-JsonProperty $config "llm_provider" "ollama"
Set-JsonProperty $config "llm_chat_model" "gpt-oss:20b"
Set-JsonProperty $config "ollama_chat_model" "gpt-oss:20b"
Set-JsonProperty $config "fast_model" "gemma4:e2b"
Set-JsonProperty $config "embedding_provider" "ollama"
Set-JsonProperty $config "embedding_model" "nomic-embed-text"
Set-JsonProperty $config "ollama_embed_model" "nomic-embed-text"

# Restore the low-latency STT profile used for the benchmark instead of the
# upstream Windows default (Whisper medium/auto).
Set-JsonProperty $config "whisper_model" "tiny"
Set-JsonProperty $config "whisper_backend" "faster-whisper"
Set-JsonProperty $config "whisper_device" "cuda"
Set-JsonProperty $config "whisper_compute_type" "int8"

# Establish a clean latency baseline by removing optional extra LLM passes.
Set-JsonProperty $config "memory_digest_enabled" $false
Set-JsonProperty $config "tool_result_digest_enabled" $false
Set-JsonProperty $config "agentic_max_turns" 4
Set-JsonProperty $config "tool_search_max_calls" 1
Set-JsonProperty $config "planner_enabled" $true
Set-JsonProperty $config "planner_timeout_sec" 3.0
Set-JsonProperty $config "intent_judge_timeout_sec" 6.0
Set-JsonProperty $config "intent_judge_thinking_enabled" $false
Set-JsonProperty $config "llm_thinking_enabled" $false

$config | ConvertTo-Json -Depth 100 | Set-Content -Path $configPath -Encoding UTF8
Write-Host "Fast-path benchmark profile written." -ForegroundColor Green
Write-Host "Expected startup: chat=gpt-oss:20b, fast=gemma4:e2b, Whisper=tiny CUDA." -ForegroundColor Cyan
Write-Host "Run the fork from source with scripts\run_windows.ps1 so the patched Python files are actually used." -ForegroundColor Yellow
