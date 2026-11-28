# R4 device checks that need adb from the PC (prepared in round 4, run in round 5). Hold the emulator lock first
# (splitify-artifacts\emulator.lock) and install the side-by-side test copy com.unizoy.splitify.qa; never touch
# com.unizoy.splitify (the owner's store build). Output: splitify-artifacts\phase-r4\r4-device.log (+ screenshots).
#   R4-DEV-05 (S-479) Android backup is off for the app (no ALLOW_BACKUP flag; bmgr refuses it).
#   R4-DEV-06 (S-478) a share whose picture is a file:// URI of Splitify's own private files opens no editor and
#                     copies nothing; a picture from the gallery (content://media/...) still opens "Add expense".
#   Then runs integration_test/r4_robustness_test.dart (R4-DEV-01..04) with the .qa id and --no-uninstall.
param([string]$PinHostIp = $env:PIN_HOST_IP)
. "$PSScriptRoot\..\..\.claude\skills\ui-review\scripts\ui.ps1" -Phase 'r4'
$adb = $script:adb
$log = Join-Path $script:out 'r4-device.log'
if (-not $env:SPLITIFY_APP_ID_SUFFIX) { $env:SPLITIFY_APP_ID_SUFFIX = '.qa' }
$pkg = "com.unizoy.splitify$env:SPLITIFY_APP_ID_SUFFIX"
$activity = "$pkg/com.unizoy.splitify.MainActivity"
$fails = 0
function Note([string]$line) { Write-Output $line; Add-Content -Path $log -Value $line }
function Check([string]$name, [bool]$ok, [string]$detail) {
  if (-not $ok) { $script:fails++ }
  Note ("{0} {1} {2}" -f ($(if ($ok) { 'PASS' } else { 'FAIL' })), $name, $detail)
}
function Screen-Text {
  & $adb shell uiautomator dump /sdcard/r4-ui.xml | Out-Null
  return (& $adb shell cat /sdcard/r4-ui.xml) -join ''
}

Set-Content -Path $log -Value "R4 device checks $(Get-Date -Format s) on $pkg"
$packages = (& $adb shell pm list packages) -join "`n"
if ($packages -notmatch [regex]::Escape("package:$pkg")) { throw "$pkg is not installed (install the .qa build first)" }

# R4-DEV-05: no backup.
$flags = [regex]::Match(((& $adb shell dumpsys package $pkg) -join "`n"), 'pkgFlags=\[[^\]]*\]').Value
Check 'R4-DEV-05 no ALLOW_BACKUP flag' ($flags -and $flags -notmatch 'ALLOW_BACKUP') $flags
$bmgr = (& $adb shell bmgr backupnow $pkg 2>&1) -join ' '
Check 'R4-DEV-05 bmgr does not back it up' ($bmgr -notmatch 'Success') $bmgr

# R4-DEV-06: a file:// share of a private file is ignored.
& $adb shell am force-stop $pkg
& $adb shell am start -W -a android.intent.action.SEND -t image/jpeg `
  --eu android.intent.extra.STREAM "file:///data/data/$pkg/shared_prefs/FlutterSharedPreferences.xml" `
  -n $activity | Out-Null
Start-Sleep 6
Save-Shot 'r4-share-file-uri'
Check 'R4-DEV-06 file:// share opens no editor' ((Screen-Text) -notmatch 'Add expense') 'screen has no "Add expense"'
& $adb shell am start -W -a android.intent.action.SEND -t image/jpeg `
  --eu android.intent.extra.STREAM "content://$pkg.files/pdf/x.pdf" -n $activity | Out-Null
Start-Sleep 4
Check 'R4-DEV-06 own provider URI ignored' ((Screen-Text) -notmatch 'Add expense') 'screen has no "Add expense"'

# A gallery picture (content://media/...) still works.
$jpg = Join-Path $PSScriptRoot '..\..\test\fixtures\receipts\grocery.jpg'
if (Test-Path $jpg) {
  & $adb push $jpg /sdcard/Pictures/r4-receipt.jpg | Out-Null
  & $adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Pictures/r4-receipt.jpg | Out-Null
  Start-Sleep 3
  $row = (& $adb shell content query --uri content://media/external/images/media --projection _id `
      --where "_display_name=\'r4-receipt.jpg\'") -join ' '
  $id = [regex]::Match($row, '_id=(\d+)').Groups[1].Value
  if ($id) {
    & $adb shell am force-stop $pkg
    & $adb shell am start -W -a android.intent.action.SEND -t image/jpeg `
      --eu android.intent.extra.STREAM "content://media/external/images/media/$id" -n $activity | Out-Null
    Start-Sleep 8
    Save-Shot 'r4-share-gallery'
    Check 'R4-DEV-06 gallery picture opens Add expense' ((Screen-Text) -match 'Add expense|Reading') "media id $id"
  } else {
    Check 'R4-DEV-06 gallery picture found' $false $row
  }
  & $adb shell rm /sdcard/Pictures/r4-receipt.jpg | Out-Null
} else {
  Note "SKIP gallery share: $jpg missing"
}
& $adb shell am force-stop $pkg

# R4-DEV-01..04 (the app's sync engine against DEV).
$testArgs = @('test', 'integration_test/r4_robustness_test.dart', '-d', 'emulator-5554', '--no-uninstall',
  '--dart-define-from-file=secrets/env.dev.json')
if ($PinHostIp) { $testArgs += "--dart-define=PIN_HOST_IP=$PinHostIp" }
& flutter.bat @testArgs 2>&1 | Tee-Object -Variable run | Out-Null
$tail = ($run | Select-Object -Last 4) -join ' '
Check 'R4-DEV-01..04 integration test' ($tail -match 'All tests passed') $tail
Note "failures: $fails"
exit $fails
