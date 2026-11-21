# Splitify guard — PreToolUse hook for MCP tools (matcher "mcp__.*").
# Blocks the prod Supabase server outside the release phase, destructive account tools, and dangerous SQL
# that is not wrapped in a rolled-back transaction. Exit code 2 blocks. Windows PowerShell 5.1 compatible.
$ErrorActionPreference = 'Stop'

try {
    $evt = ([Console]::In.ReadToEnd()) | ConvertFrom-Json
} catch {
    exit 0
}

$tool = [string]$evt.tool_name
if (-not $tool.StartsWith('mcp__')) { exit 0 }

$projectDir = $env:CLAUDE_PROJECT_DIR
if ([string]::IsNullOrWhiteSpace($projectDir)) { $projectDir = [string]$evt.cwd }

function Block([string]$why) {
    [Console]::Error.WriteLine("BLOCKED by splitify MCP guard: $why. See planning/11-execution-protocol.md.")
    exit 2
}

function Get-ActivePhase {
    $marker = Join-Path $projectDir '.claude/state/execution.json'
    if (-not (Test-Path $marker)) { return '' }
    try {
        $m = Get-Content $marker -Raw | ConvertFrom-Json
        if ($m.status -eq 'in-progress') { return [string]$m.phase }
    } catch { }
    return ''
}

# Only Supabase servers are policed here.
if ($tool -notmatch '^mcp__supabase') { exit 0 }

# Prod project: only during phase 20 (release).
if ($tool -match '^mcp__supabase[-_]?prod') {
    if ((Get-ActivePhase) -ne '20') { Block 'the prod Supabase server may only be used while phase 20 (release) is in progress' }
}

# Destructive account / project tools.
if ($tool -match '__(delete_project|pause_project|delete_branch|reset_branch|merge_branch|rebase_branch)$') {
    Block "tool $tool is destructive and not part of the plan"
}

# Dangerous SQL unless it is a test wrapped in BEGIN ... ROLLBACK.
$sql = ''
if ($evt.tool_input.PSObject.Properties.Name -contains 'query') { $sql = [string]$evt.tool_input.query }
if ($sql) {
    $isRolledBack = $sql -match '(?is)^\s*begin\b.*\brollback\b\s*;?\s*$'
    $dangerous = '(?i)\b(drop\s+(schema|database|role|owned)|alter\s+role|truncate\b|delete\s+from\s+auth\.|drop\s+table\s+(if\s+exists\s+)?auth\.|alter\s+table\s+(if\s+exists\s+)?(auth|storage)\.|drop\s+extension\b)'
    if (($sql -match $dangerous) -and -not $isRolledBack) {
        Block 'destructive SQL outside a BEGIN ... ROLLBACK test transaction; schema changes go through numbered migrations'
    }
}

exit 0
