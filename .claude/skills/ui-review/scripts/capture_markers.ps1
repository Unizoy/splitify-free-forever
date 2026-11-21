# Screenshots driven by an integration test (for screens that need a signed-in dev user, which release
# builds cannot do). The test prints `UI-CAPTURE <name>` and holds the screen for UI_HOLD seconds; this
# script then saves <name>-light/-dark/-text200.png. Run from the repo root while holding the emulator lock:
#   powershell -File .claude\skills\ui-review\scripts\capture_markers.ps1 -Phase 06 `
#     -Test integration_test/scenarios/sync_storage_review_test.dart
param([string]$Phase = '00', [Parameter(Mandatory)][string]$Test, [int]$Hold = 30)
. "$PSScriptRoot\ui.ps1" -Phase $Phase
$log = Join-Path $script:out 'capture-test.log'
& $script:adb shell settings put system font_scale 1.0
& $script:adb shell cmd uimode night no | Out-Null
# The emulator's plain DNS gets a block page for *.supabase.co on this ISP; pin the PC's answer (S-214).
$supabaseHost = ([Uri](Get-Content secrets\env.dev.json -Raw | ConvertFrom-Json).SUPABASE_URL).Host
$ip = (Resolve-DnsName $supabaseHost -Type A | Where-Object IPAddress | Select-Object -First 1).IPAddress
$p = Start-Process -FilePath 'flutter.bat' -NoNewWindow -PassThru -RedirectStandardOutput $log `
  -ArgumentList @('test', $Test, '-d', 'emulator-5554', '--dart-define-from-file=secrets/env.dev.json',
  "--dart-define=UI_HOLD=$Hold", "--dart-define=PIN_HOST_IP=$ip")
$null = $p.Handle   # makes ExitCode readable after the process ends
$done = @{}
while (-not $p.HasExited) {
  Start-Sleep -Milliseconds 700
  # Test prints reach the flutter tool's output (not logcat).
  $text = Get-Content $log -Raw -ErrorAction SilentlyContinue
  if (-not $text) { continue }
  foreach ($m in [regex]::Matches($text, 'UI-CAPTURE ([\w-]+)')) {
    $name = $m.Groups[1].Value
    if ($done.ContainsKey($name)) { continue }
    $done[$name] = $true
    Start-Sleep 2
    Save-Shot "$name-light"
    Set-Dark $true; Start-Sleep 1
    Save-Shot "$name-dark"
    Set-Dark $false
    Set-FontScale '2.0'; Start-Sleep 1
    Save-Shot "$name-text200"
    Set-FontScale '1.0'
    Write-Output "captured $name"
  }
}
Write-Output "test exit code: $($p.ExitCode)"
Get-Content $log -Tail 5
