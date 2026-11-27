# D-033 device checks + screenshots of the minimal money-movement flows (settle up, record a payment, payment
# detail, loan, default split). Run from the repo root while holding the emulator lock:
#   powershell -Command ". tool\env.ps1; & tool\e2e\capture_minimal_pay.ps1 [-Test minimal_pay_test] [-Prefix after]"
# Built side by side as com.unizoy.splitify.qa (SPLITIFY_APP_ID_SUFFIX, S-310): the owner's store build on the
# emulator is never replaced or uninstalled. Each `UI-CAPTURE <name>` becomes
# splitify-artifacts\screenshots\minimal-pay-<prefix>-<name>.png; names ending in -dark are taken with the
# emulator in dark mode. -Hold 0 runs the test without captures.
param(
  [string]$Test = 'minimal_pay_test',
  [string]$Prefix = 'after',
  [int]$Hold = 6,
  [string]$Defines = '',
  [string]$Out = 'C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\screenshots'
)
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
New-Item -ItemType Directory -Force $Out | Out-Null
$log = Join-Path $Out "minimal-pay-$Prefix-test.log"
& $adb shell settings put system font_scale 1.0
& $adb shell cmd uimode night no | Out-Null
# The emulator's plain DNS gets a block page for *.supabase.co on this ISP; pin the PC's answer (S-214).
$supabaseHost = ([Uri](Get-Content secrets\env.dev.json -Raw | ConvertFrom-Json).SUPABASE_URL).Host
$ip = (Resolve-DnsName $supabaseHost -Type A | Where-Object IPAddress | Select-Object -First 1).IPAddress
$env:SPLITIFY_APP_ID_SUFFIX = '.qa'

function Save-Shot([string]$name) {
  & $adb shell screencap -p /sdcard/shot.png
  & $adb pull /sdcard/shot.png (Join-Path $Out "minimal-pay-$Prefix-$name.png") 2>$null | Out-Null
}

# --no-uninstall: at the end `flutter test` uninstalls the project's BASE application id (com.unizoy.splitify,
# without the .qa suffix) — that removed the owner's store build on 2026-11-27 (S-329).
$flutterArgs = @('test', "integration_test/$Test.dart", '-d', 'emulator-5554', '--no-uninstall',
  '--dart-define-from-file=secrets/env.dev.json', "--dart-define=UI_HOLD=$Hold", "--dart-define=PIN_HOST_IP=$ip")
foreach ($d in ($Defines -split ' ' | Where-Object { $_ })) { $flutterArgs += "--dart-define=$d" }
$p = Start-Process -FilePath 'flutter.bat' -NoNewWindow -PassThru -RedirectStandardOutput $log -ArgumentList $flutterArgs
$null = $p.Handle
$done = @{}
while (-not $p.HasExited) {
  Start-Sleep -Milliseconds 500
  $text = Get-Content $log -Raw -ErrorAction SilentlyContinue
  if (-not $text) { continue }
  foreach ($m in [regex]::Matches($text, 'UI-CAPTURE ([\w-]+)')) {
    $name = $m.Groups[1].Value
    if ($done.ContainsKey($name)) { continue }
    $done[$name] = $true
    if ($name.EndsWith('-dark')) {
      & $adb shell cmd uimode night yes | Out-Null
      Start-Sleep -Milliseconds 3000
      Save-Shot $name
      & $adb shell cmd uimode night no | Out-Null
    } else {
      Start-Sleep -Milliseconds 1500
      Save-Shot $name
    }
    Write-Output "captured $name"
  }
}
& $adb shell cmd uimode night no | Out-Null
Write-Output "test exit code: $($p.ExitCode)"
Get-Content $log -Tail 8
