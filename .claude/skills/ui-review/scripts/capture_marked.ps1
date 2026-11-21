# Device UI review for signed-in screens (release builds cannot sign in, debug APKs only render while
# attached to the flutter tool). Runs an integration test that logs `UIREVIEW SHOT <name>` while each
# screen is on screen and `UIREVIEW DONE` at the end; takes an adb screenshot per marker.
# Hold the emulator lock while this runs. Usage (from the repo root, after `. .\tool\env.ps1`):
#   powershell -File .claude\skills\ui-review\scripts\capture_marked.ps1 -Phase 08 `
#     -Test integration_test/ui_review_expenses_test.dart
param([string]$Phase = '00', [Parameter(Mandatory)][string]$Test, [int]$TimeoutMin = 20)
. "$PSScriptRoot\ui.ps1" -Phase $Phase
$adb = $script:adb
& $adb logcat -c
$log = Join-Path $script:out 'ui-review-run.log'
$job = Start-Job -ScriptBlock {
  param($root, $test, $log)
  Set-Location $root
  . .\tool\env.ps1
  flutter test $test -d emulator-5554 --dart-define-from-file=secrets/env.dev.json *> $log
} -ArgumentList (Get-Location).Path, $Test, $log
$seen = @{}
$deadline = (Get-Date).AddMinutes($TimeoutMin)
while ((Get-Date) -lt $deadline) {
  $lines = & $adb logcat -d -s flutter:I 2>$null
  foreach ($l in $lines) {
    if ($l -match 'UIREVIEW SHOT (\S+)' -and -not $seen.ContainsKey($Matches[1])) {
      $name = $Matches[1]; $seen[$name] = $true
      Start-Sleep -Milliseconds 600
      Save-Shot $name
      "shot $name"
    }
  }
  if ($lines -match 'UIREVIEW DONE') { break }
  if ($job.State -ne 'Running' -and -not ($lines -match 'UIREVIEW')) { Start-Sleep 5 }
  if ($job.State -ne 'Running' -and $seen.Count -gt 0 -and -not ($lines -match 'UIREVIEW SHOT')) { break }
  Start-Sleep -Milliseconds 700
}
Wait-Job $job -Timeout 120 | Out-Null
Remove-Job $job -Force
"captured $($seen.Count) screens into $script:out (run log: $log)"
