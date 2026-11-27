# Phase 15 T7 performance numbers on the emulator (holds the shared emulator lock):
#  1. `flutter drive --profile` of integration_test/perf_test.dart (2,000 expenses: open + scroll frame timings,
#     balance recompute) → lines starting with PERF;
#  2. cold start of the release x64 APK (installed over the debug app, so a saved session opens the Groups tab):
#     `am start -W` TotalTime, 5 runs after force-stop.
#   powershell -File tool\e2e\perf.ps1 [-SkipDrive] [-SkipColdStart]
param([string]$Phase = '15', [switch]$SkipDrive, [switch]$SkipColdStart, [switch]$NoLock)
$ErrorActionPreference = 'Continue'
$repo = (Resolve-Path "$PSScriptRoot\..\..").Path
Set-Location $repo
. "$repo\tool\env.ps1"
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
# Side by side (final QA, S-409): the test copy is com.unizoy.splitify.qa (SPLITIFY_APP_ID_SUFFIX, S-310) and the
# flutter tool must not uninstall at the end (it would remove the BASE id, the owner's store build).
if (-not $env:SPLITIFY_APP_ID_SUFFIX) { $env:SPLITIFY_APP_ID_SUFFIX = '.qa' }
$app = "com.unizoy.splitify$env:SPLITIFY_APP_ID_SUFFIX"
$artifacts = 'C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts'
$out = Join-Path $artifacts "phase-$Phase"
$lock = Join-Path $artifacts 'emulator.lock'
New-Item -ItemType Directory -Force $out | Out-Null

if (-not $NoLock) {
  $end = (Get-Date).AddMinutes(40)
  while ($true) {
    try { New-Item -ItemType File $lock -ErrorAction Stop -Value $Phase | Out-Null; break }
    catch { if ((Get-Date) -gt $end) { throw 'emulator lock not free after 40 min' }; Start-Sleep 30 }
  }
  Write-Host 'emulator lock taken'
}
# `flutter drive` has no --no-uninstall: when it ends it runs `adb uninstall` on the BASE id (seen in final QA,
# S-409), so it must never run while the owner's store build com.unizoy.splitify is on the device.
if (-not $SkipDrive -and ((& $adb shell pm list packages) -contains 'package:com.unizoy.splitify')) {
  Write-Host 'com.unizoy.splitify is installed: flutter drive would uninstall it, so the drive part is SKIPPED.'
  $SkipDrive = $true
}
try {
  if (-not $SkipDrive) {
    $log = Join-Path $out 'perf-drive.log'
    flutter drive --profile --no-dds --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart `
      -d emulator-5554 --dart-define-from-file=secrets/env.dev.json 2>&1 | Out-File -Encoding utf8 $log
    Write-Host "drive exit $LASTEXITCODE"
    Get-Content $log | Select-String -Pattern '^PERF|PERF-NUMBERS|All tests passed|Some tests failed|Exception' |
      ForEach-Object { Write-Host "  $($_.Line.Trim())" }
  }
  if (-not $SkipColdStart) {
    $e = Get-Content secrets\env.dev.json -Raw | ConvertFrom-Json
    $ip = (Resolve-DnsName ([Uri]$e.SUPABASE_URL).Host -Type A | Where-Object IPAddress | Select-Object -First 1).IPAddress
    flutter build apk --release --target-platform android-x64 --dart-define-from-file=secrets/env.dev.json `
      "--dart-define=PIN_HOST_IP=$ip" 2>&1 | Out-File -Encoding utf8 (Join-Path $out 'perf-release-build.log')
    & $adb install -r build\app\outputs\flutter-apk\app-release.apk | Out-Null
    $times = @()
    for ($i = 0; $i -lt 6; $i++) {
      & $adb shell am force-stop $app
      Start-Sleep 2
      $r = (& $adb shell am start -W -n "$app/.MainActivity") -join "`n"
      if ($r -match 'TotalTime: (\d+)') { $times += [int]$Matches[1] }
      Start-Sleep 4
    }
    # The first run also warms the file cache: report it apart.
    Write-Host "PERF cold_start_ms first=$($times[0]) rest=$($times[1..($times.Count - 1)] -join ',')"
    & $adb shell screencap -p /sdcard/perf.png
    & $adb pull /sdcard/perf.png "$out\perf-cold-start.png" 2>$null | Out-Null
  }
} finally {
  if (-not $NoLock -and (Test-Path $lock)) { Remove-Item $lock -Force; Write-Host 'emulator lock released' }
}
