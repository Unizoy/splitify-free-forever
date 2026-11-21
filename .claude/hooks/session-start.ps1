# Splitify SessionStart hook: prints a short orientation that is added to the session context.
$ErrorActionPreference = 'SilentlyContinue'

try { $evt = ([Console]::In.ReadToEnd()) | ConvertFrom-Json } catch { $evt = $null }
$projectDir = $env:CLAUDE_PROJECT_DIR
if ([string]::IsNullOrWhiteSpace($projectDir) -and $evt) { $projectDir = [string]$evt.cwd }
if ([string]::IsNullOrWhiteSpace($projectDir)) { exit 0 }

$branch = (& git -C $projectDir rev-parse --abbrev-ref HEAD 2>$null | Select-Object -First 1)
$dirty = @(& git -C $projectDir status --porcelain 2>$null).Count

$lines = @()
$lines += "[splitify] branch: $branch ($dirty changed files)"

$progress = Join-Path $projectDir 'planning/PROGRESS.md'
if (Test-Path $progress) {
    $rows = Get-Content $progress | Where-Object { $_ -match '^\| \d\d \|' } | ForEach-Object { $_ -replace '\[([^\]]+)\]\([^)]+\)', '$1' }
    $active = $rows | Where-Object { $_ -match '\| in-progress \|' } | Select-Object -First 1
    $next = $rows | Where-Object { $_ -match '\| todo \|' } | Select-Object -First 1
    $done = @($rows | Where-Object { $_ -match '\| done(-with-blockers)? \|' }).Count
    $lines += "[splitify] phases done: $done of $(@($rows).Count)"
    if ($active) { $lines += "[splitify] IN PROGRESS: " + (($active -split '\|')[2].Trim()) + " (phase " + (($active -split '\|')[1].Trim()) + ")" }
    elseif ($next) { $lines += "[splitify] next phase: " + (($next -split '\|')[1].Trim()) + " " + (($next -split '\|')[2].Trim()) }
}

$blockers = Join-Path $projectDir 'planning/BLOCKERS.md'
if (Test-Path $blockers) {
    $open = $false; $count = 0
    foreach ($l in (Get-Content $blockers)) {
        if ($l -match '^## Open') { $open = $true; continue }
        if ($l -match '^## Closed') { $open = $false }
        if ($open -and $l -match '^## BLK-') { $count++ }
    }
    $lines += "[splitify] open blockers: $count (planning/BLOCKERS.md)"
}

$marker = Join-Path $projectDir '.claude/state/execution.json'
if (Test-Path $marker) {
    try {
        $m = Get-Content $marker -Raw | ConvertFrom-Json
        if ($m.status -eq 'in-progress') { $lines += "[splitify] an execution of phase $($m.phase) did not finish; 'execute the plan' resumes it." }
    } catch { }
}

$lines += "[splitify] To build: owner says 'execute the plan' -> use the execute-phase skill. Rules: planning/11-execution-protocol.md"
$lines -join "`n" | Write-Output
exit 0
