# Splitify guard — PreToolUse hook for the Bash and PowerShell tools.
# Exit code 2 blocks the command and shows the reason to Claude. Works in every permission mode,
# including bypassPermissions (owner decision D-003). Windows PowerShell 5.1 compatible.
$ErrorActionPreference = 'Stop'

try {
    $raw = [Console]::In.ReadToEnd()
    $evt = $raw | ConvertFrom-Json
} catch {
    exit 0  # unreadable input: never block on our own bug
}

$cmd = [string]$evt.tool_input.command
if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }

$projectDir = $env:CLAUDE_PROJECT_DIR
if ([string]::IsNullOrWhiteSpace($projectDir)) { $projectDir = [string]$evt.cwd }

function Block([string]$why) {
    [Console]::Error.WriteLine("BLOCKED by splitify guard: $why. See planning/11-execution-protocol.md (hard rules).")
    exit 2
}

function Get-Branch {
    try { return (& git -C $projectDir rev-parse --abbrev-ref HEAD 2>$null | Select-Object -First 1) } catch { return '' }
}

function Test-ExecutionActive {
    $marker = Join-Path $projectDir '.claude/state/execution.json'
    if (-not (Test-Path $marker)) { return $false }
    try { return ((Get-Content $marker -Raw | ConvertFrom-Json).status -eq 'in-progress') } catch { return $false }
}

# Normalise whitespace and drop git's global options (-C <path>, -c key=value) so patterns see "git <verb>".
$c = ($cmd -replace '\s+', ' ')
$c = [regex]::Replace($c, 'git (-C ("[^"]*"|''[^'']*''|\S+) |-c \S+ )+', 'git ')

# ---------------------------------------------------------------- git history and remote safety
if ($c -match 'git push\b') {
    if ($c -match 'git push\b[^;&|]*\s(--force\b|--force-with-lease\b|-f\b|--mirror\b|--delete\b|-d\b|--prune\b)') { Block 'force, mirror, delete and prune pushes are not allowed' }
    if ($c -match 'git push\b[^;&|]*\s\+\S') { Block 'force refspecs (+branch) are not allowed' }
    if ($c -match 'git push\b[^;&|]*\s(--tags|--follow-tags)\b') { Block 'pushing tags is not allowed; the release phase uses a draft GitHub Release' }
    if ($c -match 'git push\b[^;&|]*\s(\S+:)?(refs/heads/)?(main|master)(\s|$|;|&|\|)') { Block 'pushing main/master is not allowed; push the phase branch only' }
    if ($c -match 'git push\b[^;&|]*\sv\d') { Block 'pushing version tags is not allowed' }
    $branch = Get-Branch
    if (($branch -eq 'main' -or $branch -eq 'master') -and ($c -notmatch 'git push\b[^;&|]*\sphase/')) {
        Block "current branch is '$branch'; plan sessions push only phase/* branches"
    }
}
if ($c -match 'git reset\b[^;&|]*--hard') { Block 'git reset --hard is not allowed (use git restore <file> or a new commit)' }
if ($c -match 'git clean\b[^;&|]*\s-[a-zA-Z]*f' -and $c -match 'git clean\b[^;&|]*\s-[a-zA-Z]*[dxX]') { Block 'git clean with -d/-x is not allowed' }
if ($c -match 'git (checkout|restore)\b( --)? \.(\s|$)' -or $c -match 'git checkout -- \.') { Block 'discarding all working-tree changes is not allowed' }
if ($c -match 'git stash (drop|clear)\b') { Block 'dropping stashes is not allowed' }
if ($c -match 'git branch\b[^;&|]*\s(-D|--delete)\s[^;&|]*\b(main|master)\b') { Block 'deleting main/master is not allowed' }
if ($c -match 'git (filter-branch|filter-repo|replace|update-ref -d)\b') { Block 'history rewriting is not allowed' }
if ($c -match 'gh (repo (delete|archive|edit|rename)|release (delete|edit)|secret (set|delete)|api\b[^;&|]*-X ?(DELETE|PUT|PATCH))') { Block 'destructive GitHub operations are not allowed' }
if ($c -match 'gh pr merge\b') { Block 'merging pull requests is the owner''s job' }
if ($c -match 'gh release create\b' -and $c -notmatch '--draft') { Block 'releases must be created with --draft (owner publishes)' }

# ---------------------------------------------------------------- commits: never on main while executing, never secrets
if ($c -match 'git commit\b') {
    $branch = Get-Branch
    if (($branch -eq 'main' -or $branch -eq 'master') -and (Test-ExecutionActive)) {
        Block "plan-execution sessions never commit on '$branch'; switch to the phase branch"
    }

    $files = @(& git -C $projectDir diff --cached --name-only 2>$null)
    if ($c -match 'git commit\b[^;&|]*\s-[a-zA-Z]*a') { $files += @(& git -C $projectDir diff --name-only 2>$null) }
    $badPath = '(^|/)secrets/(?!.*\.example\.)|(^|/)\.env($|\.(?!example))|\.(jks|keystore|p12|p8|pem|key)$|key\.properties$|keystore\.properties$|google-services\.json$|GoogleService-Info\.plist$|service-account|firebase-adminsdk|(^|/)\.claude/settings\.local\.json$|(^|/)\.claude/state/|(^|/)\.vscode/settings\.json$'
    foreach ($f in $files) {
        if ($f -and ($f -replace '\\', '/') -match $badPath) { Block "secret or local-only file staged: $f" }
    }

    # Content scan of added lines. Patterns are built from pieces so this file never matches itself.
    $patterns = @(
        ('sb_' + 'secret_[A-Za-z0-9_\-]{8,}'),
        ('sb_' + 'publishable_[A-Za-z0-9_\-]{8,}'),
        ('-----BEGIN [A-Z ]*' + 'PRIVATE KEY-----'),
        ('"private_' + 'key(_id)?"\s*:'),
        ('\bre_' + '[A-Za-z0-9]{8,}_[A-Za-z0-9]{8,}'),
        ('AI' + 'za[0-9A-Za-z_\-]{35}'),
        ('eyJhbGciOi' + '[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.'),
        ('(store|key)' + 'Password\s*=\s*\S')
    )
    $added = (& git -C $projectDir diff --cached -U0 --no-color 2>$null) -join "`n"
    if ($c -match 'git commit\b[^;&|]*\s-[a-zA-Z]*a') { $added += "`n" + ((& git -C $projectDir diff -U0 --no-color 2>$null) -join "`n") }
    $addedLines = ($added -split "`n") | Where-Object { $_ -match '^\+' -and $_ -notmatch '^\+\+\+ ' }
    foreach ($p in $patterns) {
        foreach ($line in $addedLines) {
            if ($line -match $p) { Block "a staged change looks like a secret (pattern $p). Move it to secrets/ (git-ignored)" }
        }
    }
}
if ($c -match 'git add\b[^;&|]*\s(-f|--force)\b') { Block 'force-adding ignored files is not allowed' }

# ---------------------------------------------------------------- destructive filesystem commands
$protected = '(docs[/\\]PLAN\.md|planning[/\\]research|planning[/\\]00-decisions\.md|splitify-design-reference|(^|[\s/\\"''])\.git([/\\"''\s]|$))'
if ($c -match ('(\brm\b|Remove-Item|\bdel\b|\brmdir\b)[^;&|]*' + $protected)) { Block 'deleting protected plan files, the design reference or .git is not allowed' }
if ($c -match '\brm\s+-[a-zA-Z]*r[a-zA-Z]*\s+(-[a-zA-Z]+\s+)*("|'')?(/|~|\$HOME|/c/?|/c/Users(/mohit)?/?|[A-Za-z]:\\?|\.\.)("|'')?(\s|$)') { Block 'recursive delete of a root, home or parent folder' }
if ($c -match 'Remove-Item\b[^;&|]*-Recurse' -and $c -match 'Remove-Item\b[^;&|]*\s("|'')?([A-Za-z]:\\?("|'')?(\s|$)|~|\$HOME|\$env:USERPROFILE|\.\.)') { Block 'recursive delete of a root, home or parent folder' }
if ($c -match '\bformat(\.com)? +[A-Za-z]:' -or $c -match '\b(diskpart|bcdedit|reg (add|delete)|Set-ExecutionPolicy|shutdown|Restart-Computer|Stop-Computer)\b') { Block 'system-level command not allowed' }
if ($c -match '(curl|wget|iwr|Invoke-WebRequest|irm|Invoke-RestMethod)\b[^;&]*\|\s*(sh|bash|iex|Invoke-Expression|pwsh|powershell)\b') { Block 'piping downloads into a shell is not allowed' }

# ---------------------------------------------------------------- Android emulator safety
if ($c -match 'avdmanager\b[^;&|]*\bdelete\b' -or $c -match 'emulator\b[^;&|]*-wipe-data') { Block 'deleting or wiping the AVD is not allowed (it holds the owner''s test Google account)' }
if ($c -match 'system-images;android-37') { Block 'Android 37 images crash on this PC; use API 36' }

exit 0
