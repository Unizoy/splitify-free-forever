# R3-A device screenshots (integration_test/r3a_capture_test.dart) of the key screens at font scale 1.0, 0.85,
# 1.3 and 2.0, or with -Small on a small display (720 x 1280 px at 360 dpi = 320 x 569 dp) at 1.0 and 1.3.
# Run from the repo root while holding the emulator lock:
#   powershell -Command ". tool\env.ps1; & tool\e2e\capture_r3a.ps1 -Prefix before"
#   powershell -Command ". tool\env.ps1; & tool\e2e\capture_r3a.ps1 -Prefix before -Small"
# - Built side by side as com.unizoy.splitify.qa (SPLITIFY_APP_ID_SUFFIX, S-310) with --no-uninstall: the owner's
#   store build com.unizoy.splitify is never replaced or uninstalled (package list before and after).
# - Each `UI-CAPTURE <name>` becomes splitify-artifacts\screenshots\r3a-<Prefix>-<name>-<variant>.png.
# - The small display is set once before the app starts (switching size and density for every screen froze the
#   emulator twice). Font scale, display size and density are ALWAYS reset at the end (finally).
param(
  [string]$Prefix = 'after',
  [switch]$Small,
  [int]$Hold = 16,
  [string]$Device = 'emulator-5554',
  [string]$Out = 'C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\screenshots'
)
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
New-Item -ItemType Directory -Force $Out | Out-Null
$tag = if ($Small) { "$Prefix-small" } else { $Prefix }
$log = Join-Path $Out "r3a-$tag-test.log"
$supabaseHost = ([Uri](Get-Content secrets\env.dev.json -Raw | ConvertFrom-Json).SUPABASE_URL).Host
$ip = (Resolve-DnsName $supabaseHost -Type A | Where-Object IPAddress | Select-Object -First 1).IPAddress
$env:SPLITIFY_APP_ID_SUFFIX = '.qa'
if ($env:SPLITIFY_APP_ID_SUFFIX -ne '.qa') { throw 'refusing to run without the .qa suffix' }
$before = & $adb -s $Device shell pm list packages | Select-String -Pattern 'splitify|Splitwise'
Write-Output "packages before: $($before -join ', ')"

function Reset-Display {
  & $adb -s $Device shell settings put system font_scale 1.0
  & $adb -s $Device shell wm size reset
  & $adb -s $Device shell wm density reset
}

function Save-Shot([string]$name) {
  & $adb -s $Device shell screencap -p /sdcard/r3a.png
  & $adb -s $Device pull /sdcard/r3a.png (Join-Path $Out "r3a-$Prefix-$name.png") 2>$null | Out-Null
}

$variants = if ($Small) {
  @(@{ n = 'small-100'; f = '1.0' }, @{ n = 'small-130'; f = '1.3' })
} else {
  @(@{ n = '100'; f = '1.0' }, @{ n = '085'; f = '0.85' }, @{ n = '130'; f = '1.3' }, @{ n = '200'; f = '2.0' })
}

try {
  Reset-Display
  & $adb -s $Device shell cmd uimode night no | Out-Null
  if ($Small) {
    & $adb -s $Device shell wm size 720x1280
    & $adb -s $Device shell wm density 360
    Start-Sleep -Seconds 4
  }
  $p = Start-Process -FilePath 'flutter.bat' -NoNewWindow -PassThru -RedirectStandardOutput $log `
    -ArgumentList @('test', 'integration_test/r3a_capture_test.dart', '-d', $Device, '--no-uninstall',
    '--dart-define-from-file=secrets/env.dev.json', "--dart-define=UI_HOLD=$Hold", "--dart-define=PIN_HOST_IP=$ip")
  $null = $p.Handle
  $done = @{}
  while (-not $p.HasExited) {
    Start-Sleep -Milliseconds 500
    $text = Get-Content $log -Raw -ErrorAction SilentlyContinue
    if (-not $text) { continue }
    if ($text -match 'UI-READY' -and -not $done.ContainsKey('__ready')) {
      $done['__ready'] = $true
      # The tool starts the app behind the launcher on this emulator: bring it to the front.
      & $adb -s $Device shell am start -n com.unizoy.splitify.qa/com.unizoy.splitify.MainActivity 2>$null | Out-Null
    }
    foreach ($m in [regex]::Matches($text, 'UI-CAPTURE ([\w-]+)')) {
      $name = $m.Groups[1].Value
      if ($done.ContainsKey($name)) { continue }
      $done[$name] = $true
      foreach ($v in $variants) {
        & $adb -s $Device shell settings put system font_scale $v.f
        Start-Sleep -Milliseconds 1800
        Save-Shot "$name-$($v.n)"
      }
      & $adb -s $Device shell settings put system font_scale 1.0
      Write-Output "captured $name"
    }
  }
  Write-Output "test exit code: $($p.ExitCode)"
} finally {
  Reset-Display
  & $adb -s $Device shell cmd uimode night no | Out-Null
  Write-Output "display: $(& $adb -s $Device shell wm size) / $(& $adb -s $Device shell wm density) / font $(& $adb -s $Device shell settings get system font_scale)"
}
Get-Content $log | Select-String -Pattern 'R3A-CAPTURE|All tests passed|Some tests failed|Expected:|Actual:|\[E\]|Timed out' |
  ForEach-Object { Write-Output "  $_" }
$after = & $adb -s $Device shell pm list packages | Select-String -Pattern 'splitify|Splitwise'
Write-Output "packages after: $($after -join ', ')"
if (-not $after) {
  Write-Output 'WARNING: no package list after the run (device gone?) - check the owner app by hand'
} elseif (($before -match 'package:com.unizoy.splitify$') -and -not ($after -match 'package:com.unizoy.splitify$')) {
  Write-Output 'ALARM: the owner''s store build com.unizoy.splitify is gone'
}
