# D-034 WP-A device run: integration_test/d034_a_test.dart + screenshots of every new / changed screen.
# Run from the repo root while holding the emulator lock:
#   powershell -Command ". tool\env.ps1; & tool\e2e\capture_d034_a.ps1"
# Side-by-side build com.unizoy.splitify.qa (SPLITIFY_APP_ID_SUFFIX, S-310) and `--no-uninstall` always (S-329):
# the owner's store build com.unizoy.splitify is never replaced or removed. Installed packages are listed before
# and after. The receipt fixture pictures (tool/e2e/d034_receipt_images.py) are pushed to the gallery
# (Pictures/Splitify-e2e) and to the app's own files folder, which the test reads without any permission.
# Each `UI-CAPTURE <name>` becomes splitify-artifacts\screenshots\d034-a-<name>.png (names ending in -dark are
# taken with the emulator in dark mode).
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

# Receipt pictures: the gallery (as a person would have them) and the app's files folder (read by the test).
$pics = Get-ChildItem test\fixtures\receipts\*.jpg
& $adb shell mkdir -p /sdcard/Pictures/Splitify-e2e "/sdcard/Android/data/$pkg/files/receipts" | Out-Null
foreach ($p in $pics) {
  & $adb push $p.FullName "/sdcard/Pictures/Splitify-e2e/$($p.Name)" | Out-Null
  & $adb push $p.FullName "/sdcard/Android/data/$pkg/files/receipts/$($p.Name)" | Out-Null
  & $adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file:///sdcard/Pictures/Splitify-e2e/$($p.Name)" | Out-Null
}
Write-Output "pushed $($pics.Count) receipt pictures"

function Save-Shot([string]$name) {
  & $adb shell screencap -p /sdcard/d034a.png
  & $adb pull /sdcard/d034a.png (Join-Path $Out "d034-a-$name.png") 2>$null | Out-Null
}

$p = Start-Process -FilePath 'flutter.bat' -NoNewWindow -PassThru -RedirectStandardOutput $log `
  -ArgumentList @('test', $File, '-d', 'emulator-5554', '--no-uninstall',
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
$after = @(Get-Splitify)
Write-Output "splitify packages after: $($after -join ', ')"
Get-Content $log | Select-String -Pattern 'D034-|All tests|Some tests|\[E\]|Expected|Actual|Timed out' | ForEach-Object { $_.Line }
Write-Output "exit $($p.ExitCode)"
