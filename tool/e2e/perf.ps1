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
$app = 'com.unizoy.splitify'
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
try {
  if (-not $SkipDrive) {
    $log = Join-Path $out 'perf-drive.log'
    flutter drive --profile --no-dds --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart `
      -d emulator-5554 --dart-define-from-file=secrets/env.dev.json *> $log
    Write-Host "drive exit $LASTEXITCODE"
    Get-Content $log | Select-String -Pattern 'PERF|All tests passed|Some tests failed|Exception' |
      ForEach-Object { Write-Host "  $($_.Line.Trim())" }
  }
  if (-not $SkipColdStart) {
    $e = Get-Content secrets\env.dev.json -Raw | ConvertFrom-Json
    $ip = (Resolve-DnsName ([Uri]$e.SUPABASE_URL).Host -Type A | Where-Object IPAddress | Select-Object -First 1).IPAddress
    flutter build apk --release --target-platform android-x64 --dart-define-from-file=secrets/env.dev.json `
      "--dart-define=PIN_HOST_IP=$ip" *> (Join-Path $out 'perf-release-build.log')
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
