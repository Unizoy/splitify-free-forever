# D-034 WP-B device run (integration_test/d034_b_test.dart) with screenshots. Run from the repo root while holding
# the emulator lock:
#   powershell -Command ". tool\env.ps1; & tool\e2e\capture_d034_b.ps1 [-Hold 5] [-NoUpi]"
# - Built side by side as com.unizoy.splitify.qa (SPLITIFY_APP_ID_SUFFIX, S-310) with --no-uninstall: the owner's
#   store build com.unizoy.splitify is never replaced or uninstalled (checked before and after).
# - Installs the fake UPI app (tool/fake_upi_app) unless -NoUpi, and compares the test's `UPI-EXPECT <uri>` with
#   the app's `FAKE_UPI` logcat line (the batch link must carry the total exactly once). The fake app is removed
#   again only when this script installed it.
# - `UI-DEEPLINK <uri>` → `adb shell am start -a VIEW -d <uri> com.unizoy.splitify.qa` (a real Android deep link).
# - `UI-CAPTURE <name>` → splitify-artifacts\screenshots\d034-b-<name>.png; names ending in -dark are taken with
#   the emulator in dark mode.
param(
  [int]$Hold = 5,
  [switch]$NoUpi,
  [string]$Device = 'emulator-5554',
  [string]$Out = 'C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\screenshots'
)
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
New-Item -ItemType Directory -Force $Out | Out-Null
$log = Join-Path $Out 'd034-b-test.log'
$before = & $adb -s $Device shell pm list packages | Select-String -Pattern 'splitify|Splitwise|fakeupi'
Write-Output "packages before: $($before -join ', ')"
& $adb -s $Device shell settings put system font_scale 1.0
& $adb -s $Device shell cmd uimode night no | Out-Null
$supabaseHost = ([Uri](Get-Content secrets\env.dev.json -Raw | ConvertFrom-Json).SUPABASE_URL).Host
$ip = (Resolve-DnsName $supabaseHost -Type A | Where-Object IPAddress | Select-Object -First 1).IPAddress
$env:SPLITIFY_APP_ID_SUFFIX = '.qa'

$installedFake = $false
if (-not $NoUpi) {
  if (-not ($before -match 'dev.splitify.fakeupi')) {
    & (Join-Path $PSScriptRoot '..\fake_upi_app\build.ps1') -Install -Device $Device
    $installedFake = $true
  }
  & $adb -s $Device logcat -c
}

function Save-Shot([string]$name) {
  & $adb -s $Device shell screencap -p /sdcard/d034b.png
  & $adb -s $Device pull /sdcard/d034b.png (Join-Path $Out "d034-b-$name.png") 2>$null | Out-Null
}

$flutterArgs = @('test', 'integration_test/d034_b_test.dart', '-d', $Device, '--no-uninstall',
  '--dart-define-from-file=secrets/env.dev.json', "--dart-define=UI_HOLD=$Hold", "--dart-define=PIN_HOST_IP=$ip")
$p = Start-Process -FilePath 'flutter.bat' -NoNewWindow -PassThru -RedirectStandardOutput $log -ArgumentList $flutterArgs
$null = $p.Handle
$done = @{}
while (-not $p.HasExited) {
  Start-Sleep -Milliseconds 500
  $text = Get-Content $log -Raw -ErrorAction SilentlyContinue
  if (-not $text) { continue }
  foreach ($m in [regex]::Matches($text, 'UI-DEEPLINK (\S+)')) {
    $uri = $m.Groups[1].Value
    if ($done.ContainsKey("link $uri")) { continue }
    $done["link $uri"] = $true
    Start-Sleep -Milliseconds 1500
    & $adb -s $Device shell am start -a android.intent.action.VIEW -d "`"$uri`"" com.unizoy.splitify.qa | Out-Null
    Write-Output "deep link sent: $uri"
  }
  foreach ($m in [regex]::Matches($text, 'UI-CAPTURE ([\w-]+)')) {
    $name = $m.Groups[1].Value
    if ($done.ContainsKey($name)) { continue }
    $done[$name] = $true
    if ($name.EndsWith('-dark')) {
      & $adb -s $Device shell cmd uimode night yes | Out-Null
      Start-Sleep -Milliseconds 2500
      Save-Shot $name
      & $adb -s $Device shell cmd uimode night no | Out-Null
    } else {
      Start-Sleep -Milliseconds 1200
      Save-Shot $name
    }
    Write-Output "captured $name"
  }
}
& $adb -s $Device shell cmd uimode night no | Out-Null
Write-Output "test exit code: $($p.ExitCode)"
Get-Content $log | Select-String -Pattern 'D-034-|UPI-EXPECT|All tests passed|Some tests failed|Expected:|Actual:|\[E\]' |
  ForEach-Object { Write-Output "  $_" }

if (-not $NoUpi) {
  $m = Select-String -Path $log -Pattern 'UPI-EXPECT (\S+)' | Select-Object -Last 1
  $expected = if ($m) { $m.Matches[0].Groups[1].Value } else { '' }
  $got = & $adb -s $Device logcat -d -s 'FAKE_UPI:I' | Select-String -Pattern 'FAKE_UPI\s*:\s*(\S+)'
  $links = @($got | ForEach-Object { $_.Matches[0].Groups[1].Value })
  Write-Output "  UPI expected: $expected"
  Write-Output "  UPI received ($($links.Count)): $($links -join ' | ')"
  if ($expected -and $links.Count -eq 1 -and $links[0] -eq $expected) {
    Write-Output 'PASS: the fake UPI app received the batch total once, exactly as built'
  } else {
    Write-Output 'FAIL: the fake UPI app did not receive exactly one matching link'
  }
  if ($installedFake) { & (Join-Path $PSScriptRoot '..\fake_upi_app\build.ps1') -Uninstall -Device $Device }
}
$after = & $adb -s $Device shell pm list packages | Select-String -Pattern 'splitify|Splitwise|fakeupi'
Write-Output "packages after: $($after -join ', ')"
