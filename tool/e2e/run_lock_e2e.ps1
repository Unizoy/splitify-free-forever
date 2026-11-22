# TC-X2-02 (phase 18): app lock against the emulator's real lock screen. Hold the emulator lock first.
# Sets device PIN 1234, runs integration_test/app_lock_test.dart (LOCK_E2E=true), answers its prompts:
#   LOCK-PROMPT n  -> records whether FLAG_SECURE is on for the app window, saves a screenshot (blank while
#                     secure), types the PIN; LOCK-BACKGROUND -> HOME, then brings the app back.
# Always clears the PIN again. Output: splitify-artifacts\phase-18\lock-e2e.log (+ lock-prompt-*.png).
param([string]$Phase = '18')
. "$PSScriptRoot\..\..\.claude\skills\ui-review\scripts\ui.ps1" -Phase $Phase
$adb = $script:adb
$log = Join-Path $script:out 'lock-e2e.log'
$pkg = 'com.unizoy.splitify'
& $adb shell locksettings set-pin 1234 | Out-Null
try {
  $p = Start-Process -FilePath 'flutter.bat' -NoNewWindow -PassThru -RedirectStandardOutput $log `
    -ArgumentList @('test', 'integration_test/app_lock_test.dart', '-d', 'emulator-5554',
      '--dart-define=LOCK_E2E=true')
  $null = $p.Handle
  $done = @{}
  while (-not $p.HasExited) {
    Start-Sleep -Milliseconds 700
    $text = Get-Content $log -Raw -ErrorAction SilentlyContinue
    if (-not $text) { continue }
    foreach ($m in [regex]::Matches($text, 'LOCK-(PROMPT \d|BACKGROUND)')) {
      $key = $m.Groups[1].Value
      if ($done.ContainsKey($key)) { continue }
      $done[$key] = $true
      if ($key -like 'PROMPT*') {
        Start-Sleep 6   # the slow (loaded) emulator shows the system prompt later (phase 19)
        $n = $key.Split(' ')[1]
        $secure = (& $adb shell dumpsys window windows) -join "`n"
        $flag = [regex]::Match($secure, "(?s)$pkg/$pkg\.MainActivity.{0,4000}?fl=[^\n]*").Value -match 'SECURE'
        Write-Output "prompt $n : FLAG_SECURE on app window = $flag"
        Save-Shot "lock-prompt-$n"
        & $adb shell input text 1234
        & $adb shell input keyevent 66
      } else {
        Start-Sleep 2
        & $adb shell input keyevent 3
        Start-Sleep 4
        & $adb shell monkey -p $pkg -c android.intent.category.LAUNCHER 1 | Out-Null
      }
    }
  }
  Write-Output "test exit code: $($p.ExitCode)"
  Get-Content $log -Tail 6
} finally {
  & $adb shell locksettings clear --old 1234 | Out-Null
  Write-Output 'device PIN cleared'
}
