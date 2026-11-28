# R3-B motion capture (S-451): films integration_test/r3b_motion_capture_test.dart on the shared emulator with
# `adb shell screenrecord`, without the flutter tool on the device (profile APK, `.qa` id, `adb install -r`,
# `am start`; never uninstalls). Saves splitify-artifacts\screenshots\r3b-motion.mp4 and a PNG per step.
#   powershell -File tool\e2e\capture_r3b.ps1 [-SkipBuild]
param([switch]$SkipBuild, [int]$Seconds = 45)
$ErrorActionPreference = 'Continue'
$repo = (Resolve-Path "$PSScriptRoot\..\..").Path
Set-Location $repo
. "$repo\tool\env.ps1"
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$env:SPLITIFY_APP_ID_SUFFIX = '.qa'
$app = 'com.unizoy.splitify.qa'
$component = "$app/com.unizoy.splitify.MainActivity"
$artifacts = 'C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts'
$shots = Join-Path $artifacts 'screenshots'
$apk = Join-Path $artifacts 'r3b-perf\capture-r3b.apk'
New-Item -ItemType Directory -Force $shots | Out-Null

if (-not $SkipBuild) {
  flutter build apk --profile --target-platform android-x64 -t integration_test/r3b_motion_capture_test.dart `
    --dart-define-from-file=secrets/env.dev.json 2>&1 | Out-File -Encoding utf8 (Join-Path $artifacts 'r3b-perf\build-capture.log')
  Copy-Item build\app\outputs\flutter-apk\app-profile.apk $apk -Force
}

$lock = Join-Path $artifacts 'emulator.lock'
$end = (Get-Date).AddMinutes(40)
while ($true) {
  try { New-Item -ItemType File $lock -ErrorAction Stop -Value 'r3b-motion-capture' | Out-Null; break }
  catch { if ((Get-Date) -gt $end) { throw 'emulator lock not free after 40 min' }; Start-Sleep 30 }
}
try {
  $pm = (& $adb shell pm list packages) -match 'splitify|Splitwise'
  Write-Host "pm before: $($pm -join ' ')"
  & $adb install -r $apk | Out-Null
  & $adb shell am force-stop $app
  & $adb logcat -c
  & $adb shell rm -f /sdcard/r3b-motion.mp4
  $rec = Start-Process -FilePath $adb -ArgumentList @('shell', 'screenrecord', '--time-limit', "$Seconds", '/sdcard/r3b-motion.mp4') -PassThru -WindowStyle Hidden
  Start-Sleep 1
  & $adb shell am start -n $component | Out-Null
  $seen = @{}
  $deadline = (Get-Date).AddSeconds($Seconds + 30)
  while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 700
    $lines = & $adb logcat -d -s flutter:I
    foreach ($m in ($lines | Select-String -Pattern 'R3CAP (\S+)')) {
      $s = $m.Matches[0].Groups[1].Value
      if (-not $seen.ContainsKey($s)) {
        $seen[$s] = $true
        Start-Sleep -Milliseconds 600
        & $adb shell screencap -p "/sdcard/r3b-$s.png"
        & $adb pull "/sdcard/r3b-$s.png" (Join-Path $shots "r3b-$s.png") 2>$null | Out-Null
        & $adb shell rm "/sdcard/r3b-$s.png"
        Write-Host "step $s"
      }
    }
    if ($seen.ContainsKey('done') -or ($lines -match 'Some tests failed')) { break }
    $top = (& $adb shell dumpsys activity activities) -match 'topResumedActivity'
    if (-not ($top -match [regex]::Escape($app))) { & $adb shell am start -n $component | Out-Null }
  }
  ($lines -match 'R3CAP|EXCEPTION|Expected|Actual|failed') | Out-File -Encoding utf8 (Join-Path $artifacts 'r3b-perf\capture-logcat.txt')
  if (-not $rec.HasExited) { Wait-Process -Id $rec.Id -Timeout ($Seconds + 10) -ErrorAction SilentlyContinue }
  Start-Sleep 2
  & $adb pull /sdcard/r3b-motion.mp4 (Join-Path $shots 'r3b-motion.mp4') 2>$null | Out-Null
  & $adb shell rm -f /sdcard/r3b-motion.mp4
  & $adb shell am force-stop $app
  $pm = (& $adb shell pm list packages) -match 'splitify|Splitwise'
  Write-Host "pm after: $($pm -join ' ')"
} finally {
  if (Test-Path $lock) { Remove-Item $lock -Force; Write-Host 'emulator lock released' }
}
