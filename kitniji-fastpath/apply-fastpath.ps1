param(
    [string]$RepoPath = "."
)

$ErrorActionPreference = "Stop"
$RepoPath = (Resolve-Path $RepoPath).Path

function Replace-Exact {
    param(
        [string]$Path,
        [string]$Old,
        [string]$New,
        [string]$Label
    )

    $full = Join-Path $RepoPath $Path
    if (-not (Test-Path $full)) { throw "Missing file: $full" }
    $text = Get-Content $full -Raw
    if (-not $text.Contains($Old)) {
        throw "[$Label] Expected upstream text was not found in $Path. Nothing was changed for this step; the fork may have moved upstream."
    }
    $backup = "$full.kitniji-backup"
    if (-not (Test-Path $backup)) { Copy-Item $full $backup }
    $text = $text.Replace($Old, $New)
    Set-Content -Path $full -Value $text -Encoding UTF8 -NoNewline
    Write-Host "✓ $Label" -ForegroundColor Green
}

Push-Location $RepoPath
try {
    if (-not (Test-Path ".git")) { throw "RepoPath is not a Git repository: $RepoPath" }

    $status = git status --porcelain
    if ($status) {
        throw "Working tree is not clean. Commit/stash your changes before applying the fast path."
    }

    Write-Host "Applying KitNiji Jarvis fast-path changes..." -ForegroundColor Cyan

    $oldRouter = @'
        "Return 'none' ONLY for pure greetings/small talk OR when the exact "
        "fact needed is already visible in the KNOWN FACTS block below. If "
        "the query depends on data NOT in KNOWN FACTS — the user's logs, "
        "current conditions, web info, files, screen — pick a tool, even "
        "when the phrasing is indirect ('should I order pizza?' → needs the "
        "meal log; 'do I need a jacket?' → needs the weather). Do NOT pick a "
        "tool merely because its domain is loosely adjacent. "
        "If the query asks for DETAILED information on a topic (articles, "
        "explanations, write-ups), include BOTH a search tool AND a page-fetch "
        "tool so the model can follow the chain. "
'@

    $newRouter = @'
        "Return 'none' for pure greetings/small talk, stable general-knowledge "
        "questions the main model can answer without external data, OR when the exact "
        "fact needed is already visible in the KNOWN FACTS block below. Use tools "
        "when the query depends on fresh/current information, the user's logs, "
        "files, screen, external services, or when the user explicitly asks to "
        "search/browse/check a source. If the query depends on data NOT in KNOWN "
        "FACTS — the user's logs, current conditions, files, screen — pick a tool, even "
        "when the phrasing is indirect ('should I order pizza?' → needs the "
        "meal log; 'do I need a jacket?' → needs the weather). Do NOT pick a "
        "tool merely because its domain is loosely adjacent. "
        "Do NOT select webSearch or fetchWebPage merely because the user asks for "
        "an explanation, definition, or a why/how question about stable knowledge. "
        "If the query asks for DETAILED information that actually requires freshness "
        "or source verification, include BOTH a search tool AND a page-fetch tool "
        "so the model can follow the chain. "
'@

    Replace-Exact "src/jarvis/tools/selection.py" $oldRouter $newRouter "router: stable knowledge can return none"

    $enginePath = "src/jarvis/reply/engine.py"
    $engineFull = Join-Path $RepoPath $enginePath
    $engine = Get-Content $engineFull -Raw
    if (-not $engine.Contains('and _query_word_count <= 8')) {
        throw "[planner bypass] Expected <= 8 gate not found in $enginePath"
    }
    if (-not (Test-Path "$engineFull.kitniji-backup")) { Copy-Item $engineFull "$engineFull.kitniji-backup" }
    $engine = $engine.Replace('and _query_word_count <= 8', 'and _query_word_count <= 12')
    $engine = $engine.Replace(
        '# tools out. We also require the query to be short (< 8 words) so',
        '# tools out. We allow up to 12 words so short stable-knowledge questions'
    )
    $engine = $engine.Replace(
        '# longer tool-free queries that might need memory still reach the',
        '# can use the reply-only fast path without a planner pass. Longer queries still reach the'
    )
    Set-Content -Path $engineFull -Value $engine -Encoding UTF8 -NoNewline
    Write-Host "✓ engine: simple planner bypass 8 → 12 words" -ForegroundColor Green

    $oldPlanner = @'
    # Planning runs on the CHAT tier: the plan is the scaffolding the chat
    # model then follows, so the two must be matched — a weaker planner on a
    # stronger chat model produces scaffolding the chat model fights against.
    model = resolve_model(cfg, Tier.CHAT)
'@
    $newPlanner = @'
    # KitNiji latency fork: planning rides the FAST tier. Tool routing and
    # intent already run there, avoiding a FAST -> CHAT -> FAST -> CHAT model
    # ping-pong on constrained VRAM. The CHAT model still owns the final answer.
    model = resolve_model(cfg, Tier.FAST)
'@
    Replace-Exact "src/jarvis/reply/planner.py" $oldPlanner $newPlanner "planner: use FAST tier"

    Write-Host ""
    Write-Host "Fast-path source changes applied. Review with: git diff" -ForegroundColor Cyan
    Write-Host "Then run: .\kitniji-fastpath\configure-fastpath.ps1" -ForegroundColor Yellow
}
finally {
    Pop-Location
}
