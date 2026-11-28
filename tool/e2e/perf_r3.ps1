# R3-B profile-mode numbers on the shared emulator (S-450) without the flutter tool on the device (it
# uninstalls the app it ran, S-415). Two profile APKs with the side-by-side id com.unizoy.splitify.qa:
#   screens: integration_test/perf_r3_test.dart (50 groups, 2,000-expense group, storm, editor, Insights,
#            search, memory) -> one `R3PERF {json}` logcat line;
#   startup: the real app with --dart-define=SPLITIFY_STARTUP_LOG=true -> `R3START …` per cold start, plus
#            `am start -W` TotalTime.
# Installed with `adb install -r` (keeps data, never uninstalls); the owner's com.unizoy.splitify and
# com.Splitwise.SplitwiseMobile are never touched (pm list before and after is logged).
#   powershell -File tool\e2e\perf_r3.ps1 -Label before -Build        # builds only (no device, no lock)
#   powershell -File tool\e2e\perf_r3.ps1 -Label before -Run          # runs the built APKs (holds the lock)
param([string]$Label = 'run', [switch]$Build, [switch]$Run, [int]$StartRuns = 6, [switch]$NoLock,
  [ValidateSet('both', 'screens', 'startup')][string]$Only = 'both')
$ErrorActionPreference = 'Continue'
$repo = (Resolve-Path "$PSScriptRoot\..\..").Path
Set-Location $repo
. "$repo\tool\env.ps1"
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$env:SPLITIFY_APP_ID_SUFFIX = '.qa'
$app = 'com.unizoy.splitify.qa'
$component = "$app/com.unizoy.splitify.MainActivity"
$artifacts = 'C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts'
$out = Join-Path $artifacts 'r3b-perf'
New-Item -ItemType Directory -Force $out | Out-Null
$screensApk = Join-Path $out "perf-$Label-screens.apk"
$startupApk = Join-Path $out "perf-$Label-startup.apk"

if ($Build) {
  $e = Get-Content secrets\env.dev.json -Raw | ConvertFrom-Json
  $ip = (Resolve-DnsName ([Uri]$e.SUPABASE_URL).Host -Type A -ErrorAction SilentlyContinue |
      Where-Object IPAddress | Select-Object -First 1).IPAddress
  $pin = if ($ip) { "--dart-define=PIN_HOST_IP=$ip" } else { '--dart-define=PIN_HOST_IP=' }
  if ($Only -ne 'startup') {
    flutter build apk --profile --target-platform android-x64 -t integration_test/perf_r3_test.dart `
      --dart-define-from-file=secrets/env.dev.json 2>&1 | Out-File -Encoding utf8 (Join-Path $out "build-$Label-screens.log")
    Copy-Item build\app\outputs\flutter-apk\app-profile.apk $screensApk -Force
    Write-Host "screens apk: $screensApk"
  }
  if ($Only -ne 'screens') {
    flutter build apk --profile --target-platform android-x64 --dart-define-from-file=secrets/env.dev.json `
      --dart-define=SPLITIFY_STARTUP_LOG=true $pin 2>&1 | Out-File -Encoding utf8 (Join-Path $out "build-$Label-startup.log")
    Copy-Item build\app\outputs\flutter-apk\app-profile.apk $startupApk -Force
    Write-Host "startup apk: $startupApk"
  }
}

if (-not $Run) { return }
$lock = Join-Path $artifacts 'emulator.lock'
if (-not $NoLock) {
  $end = (Get-Date).AddMinutes(40)
  while ($true) {
    try { New-Item -ItemType File $lock -ErrorAction Stop -Value 'r3b-motion-perf' | Out-Null; break }
    catch { if ((Get-Date) -gt $end) { throw 'emulator lock not free after 40 min' }; Start-Sleep 30 }
  }
  Write-Host 'emulator lock taken'
}
$log = Join-Path $out "perf-$Label.log"
try {
  $pm = (& $adb shell pm list packages) -match 'splitify|Splitwise'
  "pm before: $($pm -join ' ')" | Tee-Object -FilePath $log -Append
  if ($Only -ne 'startup' -and (Test-Path $screensApk)) {
    & $adb install -r $screensApk | Out-Null
    & $adb shell am force-stop $app
    & $adb logcat -c
    & $adb shell am start -n $component | Out-Null
    $deadline = (Get-Date).AddMinutes(12)
    $done = $false
    while (-not $done -and (Get-Date) -lt $deadline) {
      Start-Sleep 10
      # A frame only comes while the app is in front: bring it back if something covered it (a calendar
      # reminder did on the first run); singleTop brings the running task forward without restarting it.
      $top = (& $adb shell dumpsys activity activities) -match 'topResumedActivity'
      if (-not ($top -match [regex]::Escape($app))) {
        Write-Host "app not in front ($top): bringing it back"
        & $adb shell am start -n $component | Out-Null
      }
      $lines = & $adb logcat -d -s flutter:I
      if ($lines -match 'R3PERF-DONE|Some tests failed|EXCEPTION CAUGHT') { $done = $true }
    }
    $lines | Out-File -Encoding utf8 (Join-Path $out "perf-$Label-screens-logcat.txt")
    ($lines -match 'R3PERF |EXCEPTION|Expected|Actual|failed') | Tee-Object -FilePath $log -Append
    & $adb shell screencap -p /sdcard/r3b.png
    & $adb pull /sdcard/r3b.png (Join-Path $out "perf-$Label-screens-end.png") 2>$null | Out-Null
    & $adb shell rm /sdcard/r3b.png
    & $adb shell am force-stop $app
  }
  if ($Only -ne 'screens' -and (Test-Path $startupApk)) {
    & $adb install -r $startupApk | Out-Null
    for ($i = 0; $i -lt $StartRuns; $i++) {
      & $adb shell am force-stop $app
      Start-Sleep 3
      & $adb logcat -c
      $r = (& $adb shell am start -W -n $component) -join ' '
      Start-Sleep 7
      $s = (& $adb logcat -d -s flutter:I) -match 'R3START'
      $total = if ($r -match 'TotalTime: (\d+)') { $Matches[1] } else { '?' }
      "start $i TotalTime=$total $s" | Tee-Object -FilePath $log -Append
    }
    & $adb shell screencap -p /sdcard/r3b.png
    & $adb pull /sdcard/r3b.png (Join-Path $out "perf-$Label-startup-end.png") 2>$null | Out-Null
    & $adb shell rm /sdcard/r3b.png
    & $adb shell am force-stop $app
  }
  $pm = (& $adb shell pm list packages) -match 'splitify|Splitwise'
  "pm after: $($pm -join ' ')" | Tee-Object -FilePath $log -Append
} finally {
  if (-not $NoLock -and (Test-Path $lock)) { Remove-Item $lock -Force; Write-Host 'emulator lock released' }
}
