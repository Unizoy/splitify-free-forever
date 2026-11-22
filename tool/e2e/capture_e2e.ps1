# Phase 18b payment-bubble e2e (TC-X4-02…07) on the emulator, holding the shared emulator lock.
#   powershell -File tool\e2e\capture_e2e.ps1 [-NoLock] [-SkipShots]
# 1. Builds + installs the fake UPI app (GPay-like flow + notification poster).
# 2. Runs integration_test/capture_bubble_test.dart and reacts to what it prints:
#    E2E-GRANT  -> grants display-over-apps, notification access and accessibility with adb
#    E2E-READY  -> native scenarios: ignore cases, smart capture (pay → PIN → success), UPI notification,
#                  duplicate bank SMS, SMS-only payment; checks the bubble windows / logcat; taps Add to Splitify
#    UI-CAPTURE -> app screenshots (light)
# 3. Screenshot stage: the bubble expanded and collapsed in light, dark and 200 % font.
# Results: splitify-artifacts\phase-18b\ (screenshots, logs, e2e-report.txt).
param([switch]$NoLock, [switch]$SkipShots, [string]$Device = 'emulator-5554')
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8   # adb output (ui dumps) carries the rupee sign
$R = 'Rs.'   # the debug bubble log writes the rupee sign as Rs. (adb output is read with a legacy code page; keep this file ASCII)
$repo = (Resolve-Path "$PSScriptRoot\..\..").Path
Set-Location $repo
. "$repo\tool\env.ps1"
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$app = 'com.unizoy.splitify'
$listener = "$app/$app.capture.PaymentNotificationListener"
$smart = "$app/$app.capture.SmartCaptureService"
$artifacts = 'C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts'
$out = Join-Path $artifacts 'phase-18b'
$lock = Join-Path $artifacts 'emulator.lock'
New-Item -ItemType Directory -Force $out | Out-Null
$report = Join-Path $out 'e2e-report.txt'
Set-Content $report "payment bubble e2e $(Get-Date -Format s)"
$script:fails = 0

function Note([string]$msg) { Write-Host $msg; Add-Content $report $msg }
function Check([bool]$ok, [string]$what) {
  if ($ok) { Note "PASS $what" } else { Note "FAIL $what"; $script:fails++ }
}
function Adb { & $adb -s $Device @args 2>$null }

function Enter-Lock {
  if ($NoLock) { return }
  $end = (Get-Date).AddMinutes(40)
  while ($true) {
    try { New-Item -ItemType File $lock -ErrorAction Stop -Value '18b' | Out-Null; Write-Host 'emulator lock taken'; return }
    catch { if ((Get-Date) -gt $end) { throw 'emulator lock not free after 40 min' }; Start-Sleep 30 }
  }
}
function Exit-Lock { if (-not $NoLock -and (Test-Path $lock)) { Remove-Item $lock -Force; Write-Host 'emulator lock released' } }

function Save-Shot([string]$name) {
  Adb shell screencap -p /sdcard/e2e.png | Out-Null
  Adb pull /sdcard/e2e.png "$out\$name.png" | Out-Null
}

# Our overlay windows (bubble handle / card / ✕ target), from the window manager.
function Get-BubbleWindows {
  $w = (Adb shell dumpsys window windows) -join "`n"
  [regex]::Matches($w, "Window\{[0-9a-f]+ u0 $app\}[^\n]*\n(?:[^\n]*\n){0,40}?[^\n]*ty=(APPLICATION_OVERLAY|ACCESSIBILITY_OVERLAY)") | ForEach-Object { $_.Value }
}
function Bubble-Count { @(Get-BubbleWindows).Count }

# UI dump of every window (Android 13+: --windows); returns the XML text.
function Get-Ui {
  Adb shell uiautomator dump --windows /sdcard/ui.xml | Out-Null
  $x = (Adb shell cat /sdcard/ui.xml) -join ''
  if (-not $x -or $x -notmatch '<hierarchy') {
    Adb shell uiautomator dump /sdcard/ui.xml | Out-Null
    $x = (Adb shell cat /sdcard/ui.xml) -join ''
  }
  return $x
}
function Find-Center([string]$xml, [string]$text) {
  $esc = [regex]::Escape($text)
  $m = [regex]::Match($xml, "(?:text|content-desc)=`"$esc`"[^>]*bounds=`"\[(\d+),(\d+)\]\[(\d+),(\d+)\]`"")
  if (-not $m.Success) { return $null }
  $x = [int](([int]$m.Groups[1].Value + [int]$m.Groups[3].Value) / 2)
  $y = [int](([int]$m.Groups[2].Value + [int]$m.Groups[4].Value) / 2)
  return , @($x, $y)
}
function Tap-Text([string]$text, [int]$tries = 6) {
  for ($i = 0; $i -lt $tries; $i++) {
    $c = Find-Center (Get-Ui) $text
    if ($c) { Adb shell input tap $c[0] $c[1] | Out-Null; return $true }
    Start-Sleep 1
  }
  return $false
}
function Ui-Has([string]$text) { (Get-Ui) -match [regex]::Escape($text) }

function Capture-Log { (Adb logcat -d -s 'SplitifyCapture:I' 'SplitifyBubble:I') -join "`n" }

# The bubble lives in overlay windows that `uiautomator dump` cannot see: debug builds log its texts and the
# screen centre of each tappable view ("ui text ...", "ui tap <label> @ x y") after every show.
function Bubble-Lines {
  $log = (Adb logcat -d -s 'SplitifyBubble:I') -join "`n"
  $i = $log.LastIndexOf('SplitifyBubble: shown')
  $j = $log.LastIndexOf('SplitifyBubble: payment in progress')
  $from = [Math]::Max($i, $j)
  if ($from -lt 0) { return '' }
  return $log.Substring($from)
}
function Bubble-Has([string]$text) {
  # The view log comes right after the first layout pass: allow a few seconds.
  for ($i = 0; $i -lt 8; $i++) {
    if ((Bubble-Lines) -match [regex]::Escape("ui text $text")) { return $true }
    Start-Sleep -Milliseconds 700
  }
  $b = Bubble-Lines
  Write-Host "  (bubble log has no 'ui text $text'; $($b.Length) chars: $($b.Substring(0, [Math]::Min(240, $b.Length)) -replace "`n", ' | '))"
  return $false
}
function Tap-Bubble([string]$label) {
  $ms = [regex]::Matches((Bubble-Lines), "ui tap $([regex]::Escape($label)) @ (\d+) (\d+)")
  if ($ms.Count -eq 0) { return $false }
  $m = $ms[$ms.Count - 1]
  Adb shell input tap $m.Groups[1].Value $m.Groups[2].Value | Out-Null
  return $true
}
function Wait-Log([string]$pattern, [int]$seconds = 12) {
  $end = (Get-Date).AddSeconds($seconds)
  while ((Get-Date) -lt $end) {
    if ((Capture-Log) -match $pattern) { return $true }
    Start-Sleep -Milliseconds 700
  }
  return $false
}

function Post-Pay([string]$amount, [string]$payee, [string]$ref) {
  Adb shell am broadcast -n dev.splitify.fakeupi/.Notifier --es amount $amount --es payee "'$payee'" --es ref $ref | Out-Null
}
function Post-Upi([string]$title, [string]$text) {
  Adb shell am broadcast -n dev.splitify.fakeupi/.Notifier --es title "'$title'" --es text "'$text'" | Out-Null
}
function Post-Shell([string]$tag, [string]$title, [string]$text) {
  Adb shell cmd notification post -S bigtext -t "'$title'" $tag "'$text'" | Out-Null
}
function Send-Sms([string]$text) { Adb emu sms send 5554 $text | Out-Null }

function Grant {
  $script:a11yBefore = ((Adb shell settings get secure enabled_accessibility_services) -join '').Trim()
  Adb shell appops set $app SYSTEM_ALERT_WINDOW allow | Out-Null
  Adb shell cmd notification allow_listener $listener | Out-Null
  Adb shell settings put secure enabled_accessibility_services $smart | Out-Null
  Adb shell settings put secure accessibility_enabled 1 | Out-Null
  Note 'granted: display over apps, notification access, accessibility'
}

function Scenarios {
  Adb logcat -c | Out-Null
  Adb shell input keyevent KEYCODE_HOME | Out-Null
  Start-Sleep 2

  # TC-X4-07: credit, OTP, promo, request and failure alerts give no bubble.
  Post-Shell 'otp1' 'VM-HDFCBK' '123456 is your OTP for a Dr. INR 500.00 transaction. Do not share it.'
  Post-Shell 'cr1' 'CP-CANBNK' 'Dear Customer, Acct XX123 credited with INR 1,000.00 on 18-10-26 from TEST PAYEE; UPI:600000000001'
  Post-Upi 'Get Rs 100 cashback' 'On your next payment! Offer ends today'
  Post-Upi 'Rahul requested Rs 500' 'Tap to pay'
  Post-Upi 'Payment failed' 'Payment of Rs 500 to Rahul failed'
  Start-Sleep 4
  $log = Capture-Log
  foreach ($r in 'otp', 'credit', 'promo', 'request', 'failed') {
    Check ($log -match "ignored [\w.]+: $r") "TC-X4-07 '$r' alert ignored"
  }
  Check ((Bubble-Count) -eq 0) 'TC-X4-07 no bubble for ignored alerts'
  Save-Shot 'e2e-ignored-no-bubble'

  # TC-X4-05: smart capture — pay screen → collapsed "Splitting this?", PIN → hidden, success → expanded.
  Adb shell am start -n dev.splitify.fakeupi/.FlowActivity --es payee "'Arjun Rao'" --es amount 250 --es ref 612345678921 | Out-Null
  Start-Sleep 3
  Check ((Wait-Log 'payment in progress') -and (Bubble-Count) -ge 1) 'TC-X4-05 pay screen shows the collapsed bubble'
  Save-Shot 'e2e-smart-paying'
  Check (Tap-Text 'Proceed to pay') 'fake app: Proceed to pay'
  Start-Sleep 3
  Check ((Wait-Log 'hidden \(pin\)') -and (Bubble-Count) -eq 0) 'TC-X4-05 bubble hidden on the UPI PIN screen'
  Save-Shot 'e2e-smart-pin'
  Check (Tap-Text 'Pay') 'fake app: Pay'
  Start-Sleep 3
  Check ((Wait-Log 'capture added [0-9a-f-]+ screen screen_amount_paid_to') -and (Bubble-Count) -ge 2) 'TC-X4-05 success screen gives the expanded bubble'
  Check ((Bubble-Has "$($R)250") -and ((Bubble-Lines) -match 'ui tap Add to Splitify')) 'bubble card shows Rs 250 and Add to Splitify'
  Save-Shot 'e2e-smart-success'
  Check (Tap-Bubble 'Not now') 'Not now dismisses the smart capture'
  Start-Sleep 2
  Check ((Bubble-Count) -eq 0) 'bubble gone after Not now'
  Adb shell input keyevent KEYCODE_HOME | Out-Null

  # TC-X4-03: a UPI app notification gives a bubble.
  Post-Pay '420' 'Neha Gupta' '612345678920'
  Check (Wait-Log 'capture added [0-9a-f-]+ notification') 'TC-X4-03 UPI notification captured'
  Start-Sleep 2
  Check ((Bubble-Count) -ge 2 -and (Bubble-Has "$($R)420") -and (Bubble-Has 'to Neha Gupta')) 'TC-X4-03 expanded bubble shows Rs 420 to Neha Gupta'
  Save-Shot 'e2e-bubble-notification'

  # TC-X4-02: the bank SMS of the same payment merges (no second bubble).
  Send-Sms 'Sent Rs.420.00 From HDFC Bank A/C *1234 To NEHA GUPTA On 22/11/26 Ref 612345678920 Not You? Call 18002586161'
  Check (Wait-Log 'capture merged|duplicate ignored' 60) 'TC-X4-02 SMS of the same payment merged'
  Check (-not ((Capture-Log) -match 'capture added [0-9a-f-]+ sms sent_from_to')) 'TC-X4-02 no second capture'

  # Drag the handle onto the ✕ target: hidden, still in Payments to add.
  Start-Sleep 9   # card auto-collapses after 8 s
  $hm = [regex]::Matches((Bubble-Lines), "ui tap Splitify: paid $($R)420 to Neha Gupta\. Double tap to open @ (\d+) (\d+)")
  $handle = if ($hm.Count -gt 0) { @([int]$hm[0].Groups[1].Value, [int]$hm[0].Groups[2].Value) } else { $null }
  if ($handle) {
    $size = (Adb shell wm size) -join '' ; $m = [regex]::Match($size, '(\d+)x(\d+)')
    $tx = [int]([int]$m.Groups[1].Value / 2); $ty = [int]$m.Groups[2].Value - 330
    Adb shell input swipe $handle[0] $handle[1] $tx $ty 1500 | Out-Null
    Start-Sleep 2
    Check ((Wait-Log 'hidden \(dropped on target\)') -and (Bubble-Count) -eq 0) 'drag onto the target hides the bubble'
  } else { Check $false 'collapsed handle found for the drag test' }

  # TC-X4-04: an SMS-only payment gives a bubble.
  Send-Sms 'Dear UPI user A/C X1234 debited by 99.0 on date 22Nov26 trf to Chai Point Refno 612345678922 If not u? call-1800111109 -SBI'
  Check (Wait-Log 'capture added [0-9a-f-]+ sms sbi_trf' 60) 'TC-X4-04 bank SMS captured'
  Start-Sleep 2
  Check ((Bubble-Has "$($R)99") -and (Bubble-Has 'to Chai Point')) 'TC-X4-04 bubble shows Rs 99 to Chai Point'
  Save-Shot 'e2e-bubble-sms'

  # TC-X4-06: Add to Splitify opens the app on the capture screen (the test takes over).
  Check (Tap-Bubble 'Add to Splitify') 'TC-X4-06 tapped Add to Splitify'
}

function Shots {
  # Bubble screenshots: expanded + collapsed in light, dark and 200 % font (S-225 review).
  Adb shell am start -n "$app/.MainActivity" | Out-Null   # re-binds the listener after the test run
  Start-Sleep 4
  Adb shell input keyevent KEYCODE_HOME | Out-Null
  $variants = @(@{ n = 'light'; dark = 'no'; font = '1.0'; amt = '1,250.50'; ref = '612345678931' },
                @{ n = 'dark'; dark = 'yes'; font = '1.0'; amt = '1,250.50'; ref = '612345678932' },
                @{ n = 'font200'; dark = 'no'; font = '2.0'; amt = '1,250.50'; ref = '612345678933' })
  foreach ($v in $variants) {
    Adb shell cmd uimode night $v.dark | Out-Null
    Adb shell settings put system font_scale $v.font | Out-Null
    Start-Sleep 3
    Adb logcat -c | Out-Null
    Post-Pay $v.amt 'Priya Nair' $v.ref
    [void](Wait-Log 'SplitifyBubble: shown' 30)
    Start-Sleep 2
    Save-Shot "bubble-expanded-$($v.n)"
    Start-Sleep 9
    Save-Shot "bubble-collapsed-$($v.n)"
    [void](Tap-Bubble "Splitify: paid $($R)1,250.50 to Priya Nair. Double tap to open")
    Start-Sleep 2
    [void](Tap-Bubble 'Not now')
    Start-Sleep 2
  }
  Adb shell cmd uimode night no | Out-Null
  Adb shell settings put system font_scale 1.0 | Out-Null
}

Enter-Lock
try {
  Adb shell settings put system font_scale 1.0 | Out-Null
  Adb shell cmd uimode night no | Out-Null
  Adb logcat -G 16M | Out-Null   # the default ring buffer drops our lines while the test logs
  & (Join-Path $repo 'tool\fake_upi_app\build.ps1') -Install -Device $Device | Out-Null
  Adb shell pm grant dev.splitify.fakeupi android.permission.POST_NOTIFICATIONS | Out-Null
  $supabaseHost = ([Uri](Get-Content secrets\env.dev.json -Raw | ConvertFrom-Json).SUPABASE_URL).Host
  $ip = (Resolve-DnsName $supabaseHost -Type A | Where-Object IPAddress | Select-Object -First 1).IPAddress
  $log = Join-Path $out 'e2e-flutter.log'
  Remove-Item $log -ErrorAction SilentlyContinue
  $argv = @('test', 'integration_test/capture_bubble_test.dart', '-d', $Device, '--no-uninstall',
    '--dart-define-from-file=secrets/env.dev.json', "--dart-define=PIN_HOST_IP=$ip", '--dart-define=E2E_CAPTURE=true')
  $p = Start-Process -FilePath 'flutter.bat' -NoNewWindow -PassThru -RedirectStandardOutput $log -ArgumentList $argv
  $null = $p.Handle
  $handled = 0
  $deadline = (Get-Date).AddMinutes(30)
  while (-not $p.HasExited) {
    if ((Get-Date) -gt $deadline) { Check $false 'integration test finished within 30 min'; break }
    Start-Sleep -Milliseconds 500
    $text = Get-Content $log -Raw -ErrorAction SilentlyContinue
    if (-not $text) { continue }
    $marks = [regex]::Matches($text, 'E2E-GRANT|E2E-READY|E2E-DONE|UI-CAPTURE ([\w-]+)')
    for ($i = $handled; $i -lt $marks.Count; $i++) {
      $m = $marks[$i]
      if ($m.Value -eq 'E2E-GRANT') { Grant }
      elseif ($m.Value -eq 'E2E-DONE') {
        # Accessibility off before the test ends (an active service keeps a Flutter semantics handle open).
        Adb shell settings delete secure enabled_accessibility_services | Out-Null
      }
      elseif ($m.Value -eq 'E2E-READY') { try { Scenarios } catch { Check $false "scenario error: $_" } }
      else {
        # Light, dark and 200 % text while the test holds the screen (UI_HOLD).
        $n = $m.Groups[1].Value
        Start-Sleep 1
        Save-Shot "app-$n-light"
        Adb shell cmd uimode night yes | Out-Null; Start-Sleep 3; Save-Shot "app-$n-dark"
        Adb shell cmd uimode night no | Out-Null
        Adb shell settings put system font_scale 2.0 | Out-Null; Start-Sleep 3; Save-Shot "app-$n-font200"
        Adb shell settings put system font_scale 1.0 | Out-Null
        Note "captured app-$n (light, dark, 200 %)"
      }
    }
    $handled = $marks.Count
  }
  $p.WaitForExit()
  $code = $p.ExitCode
  Get-Content $log | Select-String -Pattern 'E2E-CAPTURES|E2E-RESULT|All tests passed|Some tests failed|Expected|Actual|Timed out' |
    Select-Object -Last 12 | ForEach-Object { Note "  $($_.Line.Trim())" }
  Check ($code -eq 0) "integration test (TC-X4-06 save + sync, TC-X4-02 one capture) exit $code"
  Copy-Item (Join-Path $out 'e2e-flutter.log') (Join-Path $out 'e2e-flutter-last.log') -ErrorAction SilentlyContinue
  (Capture-Log) | Set-Content (Join-Path $out 'e2e-capture-logcat.txt')
  if (-not $SkipShots) { Shots }
} finally {
  # Never leave the flutter test waiting on the device.
  Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*capture_bubble_test*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  # Leave the shared emulator as we found it: our accessibility service off again.
  if ($null -ne $script:a11yBefore) {
    if ($script:a11yBefore -eq 'null' -or -not $script:a11yBefore) {
      Adb shell settings delete secure enabled_accessibility_services | Out-Null
    } else {
      Adb shell settings put secure enabled_accessibility_services $script:a11yBefore | Out-Null
    }
  }
  Adb shell settings put system font_scale 1.0 | Out-Null
  Adb shell cmd uimode night no | Out-Null
  Exit-Lock
}
Note "FAILURES $script:fails"
if ($script:fails -gt 0) { exit 1 }
