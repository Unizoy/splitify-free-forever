# Splitify Stop hook: while a phase is being executed by THIS session, don't let the session stop before the phase
# is shipped (report written, branch pushed). Loop-safe: blocks at most twice per execution (counter in the marker).
$ErrorActionPreference = 'SilentlyContinue'

try { $evt = ([Console]::In.ReadToEnd()) | ConvertFrom-Json } catch { exit 0 }
$projectDir = $env:CLAUDE_PROJECT_DIR
if ([string]::IsNullOrWhiteSpace($projectDir)) { $projectDir = [string]$evt.cwd }
$marker = Join-Path $projectDir '.claude/state/execution.json'
if (-not (Test-Path $marker)) { exit 0 }

try { $m = Get-Content $marker -Raw | ConvertFrom-Json } catch { exit 0 }
if ($m.status -ne 'in-progress') { exit 0 }

# Only police the session that started the execution (if it recorded its id).
if ($m.PSObject.Properties.Name -contains 'sessionId' -and $m.sessionId -and $evt.session_id -and ($m.sessionId -ne $evt.session_id)) { exit 0 }

$blocks = 0
if ($m.PSObject.Properties.Name -contains 'stopBlocks') { $blocks = [int]$m.stopBlocks }
if ($blocks -ge 2) { exit 0 }

$m | Add-Member -NotePropertyName stopBlocks -NotePropertyValue ($blocks + 1) -Force
$m | ConvertTo-Json -Depth 5 | Set-Content -Path $marker -Encoding UTF8

[Console]::Error.WriteLine("Phase $($m.phase) is still marked in-progress. Before stopping, follow the ship-phase skill: run verify, update planning/PROGRESS.md, write planning/reports/phase-$($m.phase).md, commit and push the phase branch, then set .claude/state/execution.json status to 'shipped' (or 'blocked' with the reason in the report). Never ask the owner a question.")
exit 2
