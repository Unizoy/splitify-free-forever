# D-034 WP-A device run: integration_test/d034_a_test.dart + screenshots of every new / changed screen.
# Run from the repo root while holding the emulator lock:
#   powershell -Command ". tool\env.ps1; & tool\e2e\capture_d034_a.ps1"
# Side-by-side build com.unizoy.splitify.qa (SPLITIFY_APP_ID_SUFFIX, S-310) and `--no-uninstall` always (S-329):
# the owner's store build com.unizoy.splitify is never replaced or removed. Installed packages are listed before
# and after. The receipt fixture pictures (tool/e2e/d034_receipt_images.py) are pushed to the gallery
# (Pictures/Splitify-e2e) and to the app's own internal files folder (run-as), which the test reads.
# The test saves each screen (light, then dark through the app's theme setting) in its files folder; this script
# pulls them to splitify-artifacts\screenshots\d034-a-<name>.png.
param(
  [string]$File = 'integration_test/d034_a_test.dart',
  [int]$Hold = 6,
  [string]$Out = 'C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\screenshots'
)
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$pkg = 'com.unizoy.splitify.qa'
New-Item -ItemType Directory -Force $Out | Out-Null
$log = Join-Path $Out 'd034-a-test.log'
& $adb shell settings put system font_scale 1.0
& $adb shell cmd uimode night no | Out-Null
$supabaseHost = ([Uri](Get-Content secrets\env.dev.json -Raw | ConvertFrom-Json).SUPABASE_URL).Host
$ip = (Resolve-DnsName $supabaseHost -Type A | Where-Object IPAddress | Select-Object -First 1).IPAddress
$env:SPLITIFY_APP_ID_SUFFIX = '.qa'
function Get-Splitify { & $adb -s emulator-5554 shell pm list packages | Where-Object { $_ -match 'splitify' } }
$before = @(Get-Splitify)
Write-Output "splitify packages before: $($before -join ', ')"

# Receipt pictures: the gallery (as a person would have them) and the app's internal files folder (read by the
# test). Files adb writes into Android/data are owned by shell and hidden from the app on Android 11+, so that copy
# goes in through `run-as` (debug build).
$pics = Get-ChildItem test\fixtures\receipts\*.jpg
& $adb shell mkdir -p /sdcard/Pictures/Splitify-e2e /data/local/tmp/d034a | Out-Null
& $adb shell "run-as $pkg mkdir -p files/receipts" | Out-Null
foreach ($p in $pics) {
  & $adb push $p.FullName "/sdcard/Pictures/Splitify-e2e/$($p.Name)" | Out-Null
  & $adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file:///sdcard/Pictures/Splitify-e2e/$($p.Name)" | Out-Null
  & $adb push $p.FullName "/data/local/tmp/d034a/$($p.Name)" | Out-Null
  & $adb shell "cat /data/local/tmp/d034a/$($p.Name) | run-as $pkg sh -c 'cat > files/receipts/$($p.Name)'" | Out-Null
}
& $adb shell "run-as $pkg ls files/receipts"
& $adb shell rm -r /data/local/tmp/d034a | Out-Null
Write-Output "pushed $($pics.Count) receipt pictures"

# Screens are captured inside the app (takeScreenshot): the emulator showed the test window black here.
& $adb shell "run-as $pkg rm -rf files/shots" | Out-Null

$p = Start-Process -FilePath 'flutter.bat' -NoNewWindow -PassThru -RedirectStandardOutput $log `
  -ArgumentList @('test', $File, '-d', 'emulator-5554', '--no-uninstall',
  '--dart-define-from-file=secrets/env.dev.json', "--dart-define=UI_HOLD=$Hold", "--dart-define=PIN_HOST_IP=$ip")
$null = $p.Handle
$null = $p.WaitForExit()
& $adb shell cmd uimode night no | Out-Null
# Pull the screenshots the test saved in the app's files folder (binary-safe through cmd /c).
$names = & $adb shell "run-as $pkg ls files/shots" 2>$null
foreach ($n in $names) {
  $n = $n.Trim()
  if (-not $n.EndsWith('.png')) { continue }
  cmd /c "`"$adb`" exec-out run-as $pkg cat files/shots/$n > `"$(Join-Path $Out $n)`""
  Write-Output "captured $n"
}
$after = @(Get-Splitify)
Write-Output "splitify packages after: $($after -join ', ')"
Get-Content $log | Select-String -Pattern 'D034-|All tests|Some tests|\[E\]|Expected|Actual|Timed out' | ForEach-Object { $_.Line }
Write-Output "exit $($p.ExitCode)"
