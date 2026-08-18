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

# Keep the capable main brain and use the tiny model only for fast orchestration.
Set-JsonProperty $config "llm_chat_model" "gpt-oss:20b"
Set-JsonProperty $config "fast_model" "gemma4:e2b"
Set-JsonProperty $config "embedding_model" "nomic-embed-text"

# Establish a clean latency baseline by removing optional extra LLM passes.
Set-JsonProperty $config "memory_digest_enabled" $false
Set-JsonProperty $config "tool_result_digest_enabled" $false
Set-JsonProperty $config "agentic_max_turns" 4
Set-JsonProperty $config "tool_search_max_calls" 1
Set-JsonProperty $config "planner_enabled" $true
Set-JsonProperty $config "planner_timeout_sec" 3.0
Set-JsonProperty $config "intent_judge_timeout_sec" 6.0
Set-JsonProperty $config "llm_thinking_enabled" $false

$config | ConvertTo-Json -Depth 100 | Set-Content -Path $configPath -Encoding UTF8
Write-Host "Fast-path benchmark profile written." -ForegroundColor Green
Write-Host "Restart Jarvis after changing the config." -ForegroundColor Yellow
