param(
    [string]$RepoPath = "."
)

$ErrorActionPreference = "Stop"
$RepoPath = (Resolve-Path $RepoPath).Path

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Backup-File {
    param([string]$FullPath)
    $backup = "$FullPath.kitniji-backup"
    if (-not (Test-Path $backup)) {
        Copy-Item $FullPath $backup
    }
}

function Replace-Exact {
    param(
        [string]$Path,
        [string]$Old,
        [string]$New,
        [string]$Label
    )

    $full = Join-Path $RepoPath $Path
    if (-not (Test-Path $full)) {
        throw "Missing file: $full"
    }

    # Explicit UTF-8 read/write is required on Windows PowerShell 5.1.
    # Get-Content defaults to the legacy Windows code page for UTF-8 files
    # without a BOM and would corrupt Unicode punctuation in Jarvis sources.
    $text = [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8)

    if ($text.Contains($New)) {
        Write-Host "Already applied: $Label" -ForegroundColor DarkYellow
        return
    }

    if (-not $text.Contains($Old)) {
        throw "[$Label] Expected upstream text was not found in $Path. The fork may have moved upstream."
    }

    Backup-File $full
    $text = $text.Replace($Old, $New)
    [System.IO.File]::WriteAllText($full, $text, $script:Utf8NoBom)
    Write-Host "Applied: $Label" -ForegroundColor Green
}

Push-Location $RepoPath
try {
    if (-not (Test-Path ".git")) {
        throw "RepoPath is not a Git repository: $RepoPath"
    }

    $status = git status --porcelain
    if ($status) {
        $meaningful = @($status | Where-Object { $_ -notmatch '\.kitniji-backup$' })
        if ($meaningful.Count -gt 0) {
            throw "Working tree is not clean. Commit/stash your changes before applying the fast path.`n$($meaningful -join "`n")"
        }
    }

    Write-Host "Applying KitNiji Jarvis fast-path changes..." -ForegroundColor Cyan

    # 1) Router: stable general knowledge should be allowed to use no external tools.
    $routerPath = "src/jarvis/tools/selection.py"

    Replace-Exact $routerPath `
        '        "Return ''none'' ONLY for pure greetings/small talk OR when the exact "' `
        '        "Return ''none'' for pure greetings/small talk, stable general-knowledge questions, OR when the exact "' `
        "router: stable knowledge can return none"

    Replace-Exact $routerPath `
        '        "If the query asks for DETAILED information on a topic (articles, "' `
        '        "Do NOT select webSearch or fetchWebPage merely because the user asks for "' `
        "router: explanations do not force web line 1"

    Replace-Exact $routerPath `
        '        "explanations, write-ups), include BOTH a search tool AND a page-fetch "' `
        '        "an explanation, definition, or why/how question about stable knowledge. "' `
        "router: explanations do not force web line 2"

    Replace-Exact $routerPath `
        '        "tool so the model can follow the chain. "' `
        '        "Use search plus page-fetch when freshness or source verification is actually needed. "' `
        "router: explanations do not force web line 3"

    # 2) Existing reply-only fast path: allow short stable questions up to 12 words.
    $enginePath = "src/jarvis/reply/engine.py"
    Replace-Exact $enginePath `
        'and _query_word_count <= 8' `
        'and _query_word_count <= 12' `
        "engine: planner bypass 8 to 12 words"

    # 3) Planner: use the FAST model tier instead of paging in CHAT just to plan.
    $plannerPath = "src/jarvis/reply/planner.py"
    Replace-Exact $plannerPath `
        '    model = resolve_model(cfg, Tier.CHAT)' `
        '    model = resolve_model(cfg, Tier.FAST)' `
        "planner: use FAST tier"

    Write-Host ""
    Write-Host "Fast-path source changes applied." -ForegroundColor Cyan
    Write-Host "Review with: git diff -- src/jarvis/tools/selection.py src/jarvis/reply/engine.py src/jarvis/reply/planner.py" -ForegroundColor Yellow
    Write-Host "Then run: .\kitniji-fastpath\configure-fastpath.ps1" -ForegroundColor Yellow
}
finally {
    Pop-Location
}
