# W2-X device run (integration_test/w2x_test.dart) with screenshots. Run from the repo root while holding the
# emulator lock:
#   powershell -Command ". tool\env.ps1; & tool\e2e\capture_w2x.ps1"
# - Built side by side as com.unizoy.splitify.qa (SPLITIFY_APP_ID_SUFFIX, S-310) with --no-uninstall: the owner's
#   store build com.unizoy.splitify is never replaced or uninstalled (package list checked before and after;
#   the run refuses to start if the .qa suffix is missing).
# - `W2X-SHOT <name>` → splitify-artifacts\screenshots\w2x-<name>.png; names ending in -dark are taken with the
#   emulator in dark mode.
# - `W2X-CONTACTS-OPEN` → the system contact picker is open: Back closes it (nothing picked, nothing added).
param(
  [string]$Device = 'emulator-5554',
  [string]$Out = 'C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\screenshots'
)
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
New-Item -ItemType Directory -Force $Out | Out-Null
$log = Join-Path $Out 'w2x-test.log'
$before = & $adb -s $Device shell pm list packages | Select-String -Pattern 'splitify|Splitwise'
Write-Output "packages before: $($before -join ', ')"
& $adb -s $Device shell settings put system font_scale 1.0
& $adb -s $Device shell cmd uimode night no | Out-Null
$supabaseHost = ([Uri](Get-Content secrets\env.dev.json -Raw | ConvertFrom-Json).SUPABASE_URL).Host
$ip = (Resolve-DnsName $supabaseHost -Type A | Where-Object IPAddress | Select-Object -First 1).IPAddress
$env:SPLITIFY_APP_ID_SUFFIX = '.qa'
if ($env:SPLITIFY_APP_ID_SUFFIX -ne '.qa') { throw 'refusing to run without the .qa suffix' }

function Test-Shown {
  $w = & $adb -s $Device shell dumpsys window windows
  $i = ($w | Select-String -Pattern 'Window #\d+ Window\{.*splitify\.qa' | Select-Object -First 1).LineNumber
  if (-not $i) { return $false }
  return [bool]($w[($i - 1)..($i + 40)] | Select-String -Pattern 'Surface: shown=true' | Select-Object -First 1)
}

function Show-App {
  for ($n = 0; $n -lt 3 -and -not (Test-Shown); $n++) {
    & $adb -s $Device shell input keyevent KEYCODE_HOME
    Start-Sleep -Milliseconds 1000
    & $adb -s $Device shell am start -n com.unizoy.splitify.qa/com.unizoy.splitify.MainActivity 2>$null | Out-Null
    Start-Sleep -Milliseconds 1800
    Write-Output 'window was hidden: brought to the front'
  }
}

function Save-Shot([string]$name) {
  Show-App
  & $adb -s $Device shell screencap -p /sdcard/w2x.png
  & $adb -s $Device pull /sdcard/w2x.png (Join-Path $Out "w2x-$name.png") 2>$null | Out-Null
}

$flutterArgs = @('test', 'integration_test/w2x_test.dart', '-d', $Device, '--no-uninstall',
  '--dart-define-from-file=secrets/env.dev.json', "--dart-define=PIN_HOST_IP=$ip")
$p = Start-Process -FilePath 'flutter.bat' -NoNewWindow -PassThru -RedirectStandardOutput $log -ArgumentList $flutterArgs
$null = $p.Handle
$done = @{}
while (-not $p.HasExited) {
  Start-Sleep -Milliseconds 500
  $text = Get-Content $log -Raw -ErrorAction SilentlyContinue
  if (-not $text) { continue }
  if ($text -match 'UI-READY' -and -not $done.ContainsKey('ready')) {
    $done['ready'] = $true
    & $adb -s $Device shell input keyevent KEYCODE_HOME
    Start-Sleep -Milliseconds 1000
    & $adb -s $Device shell am start -n com.unizoy.splitify.qa/com.unizoy.splitify.MainActivity 2>$null | Out-Null
    Write-Output 'window brought to the front'
  }
  if ($text -match 'W2X-CONTACTS-OPEN' -and -not $done.ContainsKey('contacts')) {
    $done['contacts'] = $true
    Start-Sleep -Milliseconds 2500
    $top = & $adb -s $Device shell dumpsys activity activities | Select-String -Pattern 'topResumedActivity' | Select-Object -First 1
    Write-Output "contact picker: $top"
    & $adb -s $Device shell screencap -p /sdcard/w2x.png
    & $adb -s $Device pull /sdcard/w2x.png (Join-Path $Out 'w2x-contact-picker.png') 2>$null | Out-Null
    & $adb -s $Device shell input keyevent KEYCODE_BACK
    Write-Output 'contact picker closed with Back'
  }
  foreach ($m in [regex]::Matches($text, 'W2X-SHOT ([\w-]+)')) {
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
Get-Content $log | Select-String -Pattern 'W2X-E2E|All tests passed|Some tests failed|Expected:|Actual:|\[E\]|Timed out' |
  ForEach-Object { Write-Output "  $_" }
$after = & $adb -s $Device shell pm list packages | Select-String -Pattern 'splitify|Splitwise'
Write-Output "packages after: $($after -join ', ')"
if (($before -match 'package:com.unizoy.splitify$') -and -not ($after -match 'package:com.unizoy.splitify$')) {
  Write-Output 'ALARM: the owner''s store build com.unizoy.splitify is gone'
}
