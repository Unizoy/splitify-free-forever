# D-032 device check + screenshots of the one-screen add expense (integration_test/simple_expense_test.dart).
# Run from the repo root while holding the emulator lock:
#   powershell -Command ". tool\env.ps1; & tool\e2e\capture_simple_expense.ps1"
# The app is built side by side as com.unizoy.splitify.qa (SPLITIFY_APP_ID_SUFFIX, S-310), so the store build
# installed on the emulator (another signing key, the owner's data) is never replaced or uninstalled.
# Each `UI-CAPTURE <name>` becomes splitify-artifacts\screenshots\simple-expense-<name>.png; names ending in
# -dark are taken with the emulator in dark mode.
param([int]$Hold = 8, [string]$Out = 'C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\screenshots')
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
New-Item -ItemType Directory -Force $Out | Out-Null
$log = Join-Path $Out 'simple-expense-test.log'
& $adb shell settings put system font_scale 1.0
& $adb shell cmd uimode night no | Out-Null
# The emulator's plain DNS gets a block page for *.supabase.co on this ISP; pin the PC's answer (S-214).
$supabaseHost = ([Uri](Get-Content secrets\env.dev.json -Raw | ConvertFrom-Json).SUPABASE_URL).Host
$ip = (Resolve-DnsName $supabaseHost -Type A | Where-Object IPAddress | Select-Object -First 1).IPAddress
$env:SPLITIFY_APP_ID_SUFFIX = '.qa'

function Save-Shot([string]$name) {
  & $adb shell screencap -p /sdcard/shot.png
  & $adb pull /sdcard/shot.png (Join-Path $Out "simple-expense-$name.png") 2>$null | Out-Null
}

$p = Start-Process -FilePath 'flutter.bat' -NoNewWindow -PassThru -RedirectStandardOutput $log `
  -ArgumentList @('test', 'integration_test/simple_expense_test.dart', '-d', 'emulator-5554',
  '--dart-define-from-file=secrets/env.dev.json', "--dart-define=UI_HOLD=$Hold", "--dart-define=PIN_HOST_IP=$ip")
$null = $p.Handle
$done = @{}
while (-not $p.HasExited) {
  Start-Sleep -Milliseconds 500
  $text = Get-Content $log -Raw -ErrorAction SilentlyContinue
  if (-not $text) { continue }
  foreach ($m in [regex]::Matches($text, 'UI-CAPTURE ([\w-]+)')) {
    $name = $m.Groups[1].Value
    if ($done.ContainsKey($name)) { continue }
    $done[$name] = $true
    if ($name.EndsWith('-dark')) {
      & $adb shell cmd uimode night yes | Out-Null
      Start-Sleep -Milliseconds 3000
      Save-Shot $name
      & $adb shell cmd uimode night no | Out-Null
    } else {
      Start-Sleep -Milliseconds 1500
      Save-Shot $name
    }
    Write-Output "captured $name"
  }
}
& $adb shell cmd uimode night no | Out-Null
Write-Output "test exit code: $($p.ExitCode)"
Get-Content $log -Tail 6
