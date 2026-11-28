# W2-Y device run: integration_test/w2y_test.dart (attachments offline → online, full size, PDF, restore; the
# monthly card; one push per batch settle) + screenshots of the new screens, light and dark.
# Run from the repo root while holding the emulator lock:
#   powershell -Command ". tool\env.ps1; & tool\e2e\capture_w2y.ps1"
# Side-by-side build com.unizoy.splitify.qa (SPLITIFY_APP_ID_SUFFIX, S-310) and `--no-uninstall` always (S-329):
# the owner's store build com.unizoy.splitify is never replaced or removed. Installed packages are listed before
# and after. The test saves each screen in its files folder; this script pulls them to
# splitify-artifacts\screenshots\w2y-<name>-{light,dark}.png.
param(
  [string]$File = 'integration_test/w2y_test.dart',
  [int]$Hold = 6,
  [string]$Out = 'C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\screenshots'
)
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$pkg = 'com.unizoy.splitify.qa'
New-Item -ItemType Directory -Force $Out | Out-Null
$log = Join-Path $Out 'w2y-test.log'
& $adb shell settings put system font_scale 1.0
& $adb shell cmd uimode night no | Out-Null
$supabaseHost = ([Uri](Get-Content secrets\env.dev.json -Raw | ConvertFrom-Json).SUPABASE_URL).Host
$ip = (Resolve-DnsName $supabaseHost -Type A | Where-Object IPAddress | Select-Object -First 1).IPAddress
$env:SPLITIFY_APP_ID_SUFFIX = '.qa'
function Get-Splitify { & $adb -s emulator-5554 shell pm list packages | Where-Object { $_ -match 'splitify|Splitwise' } }
$before = @(Get-Splitify)
Write-Output "packages before: $($before -join ', ')"
& $adb shell "run-as $pkg rm -rf files/shots" 2>$null | Out-Null

$p = Start-Process -FilePath 'flutter.bat' -NoNewWindow -PassThru -RedirectStandardOutput $log `
  -ArgumentList @('test', $File, '-d', 'emulator-5554', '--no-uninstall',
  '--dart-define-from-file=secrets/env.dev.json', "--dart-define=UI_HOLD=$Hold", "--dart-define=PIN_HOST_IP=$ip")
$null = $p.Handle
$null = $p.WaitForExit()
& $adb shell cmd uimode night no | Out-Null
$names = & $adb shell "run-as $pkg ls files/shots" 2>$null
foreach ($n in $names) {
  $n = $n.Trim()
  if (-not $n.EndsWith('.png')) { continue }
  cmd /c "`"$adb`" exec-out run-as $pkg cat files/shots/$n > `"$(Join-Path $Out $n)`""
  Write-Output "captured $n"
}
$after = @(Get-Splitify)
Write-Output "packages after: $($after -join ', ')"
Get-Content $log | Select-String -Pattern 'W2Y-|All tests|Some tests|\[E\]|Expected|Actual|Timed out|Error' | ForEach-Object { $_.Line }
Write-Output "exit $($p.ExitCode)"
