# D-034 WP-D device e2e + screenshots (TC-D34D-05): runs integration_test/d034_d_test.dart on emulator-5554
# under the shared emulator lock and reacts to what the test prints:
#   E2E-NET off|on   -> adb airplane mode on/off (the test waits until the phone sees it)
#   UI-CAPTURE name  -> splitify-artifacts\screenshots\d034-d-<name>-light.png and -dark.png
# Built side by side as com.unizoy.splitify.qa (SPLITIFY_APP_ID_SUFFIX, S-310) with --no-uninstall: the owner's
# store build com.unizoy.splitify is never replaced or removed (S-329). Airplane mode is always switched off at
# the end. Run from the repo root:
#   powershell -Command ". tool\env.ps1; & tool\e2e\capture_d034_d.ps1"
param(
  [int]$Hold = 10,
  [string]$Out = 'C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\screenshots',
  [switch]$NoLock
)
$ErrorActionPreference = 'Continue'   # adb writes to stderr; failures are checked by the test's exit code
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$lock = 'C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\emulator.lock'
New-Item -ItemType Directory -Force $Out | Out-Null
$log = Join-Path $Out 'd034-d-test.log'

function Save-Shot([string]$name) {
  & $adb shell screencap -p /sdcard/d034d.png
  & $adb pull /sdcard/d034d.png (Join-Path $Out "d034-d-$name.png") 2>$null | Out-Null
}

function Set-Airplane([bool]$on) {
  & $adb shell cmd connectivity airplane-mode $(if ($on) { 'enable' } else { 'disable' }) | Out-Null
  Write-Output "airplane mode $(if ($on) { 'ON' } else { 'OFF' })"
}

if (-not $NoLock) {
  $end = (Get-Date).AddMinutes(40)
  while ($true) {
    try {
      New-Item -ItemType File $lock -ErrorAction Stop -Value 'd034-d' | Out-Null
      Write-Output 'emulator lock taken'
      break
    } catch {
      if ((Get-Date) -gt $end) { throw 'emulator lock not free after 40 min' }
      Start-Sleep 30
    }
  }
}
try {
  Write-Output 'packages before:'
  & $adb shell pm list packages | Select-String splitify
  & $adb shell settings put system font_scale 1.0
  & $adb shell cmd uimode night no | Out-Null
  # The emulator's plain DNS gets a block page for *.supabase.co on this ISP; pin the PC's answer (S-214).
  $supabaseHost = ([Uri](Get-Content secrets\env.dev.json -Raw | ConvertFrom-Json).SUPABASE_URL).Host
  $ip = (Resolve-DnsName $supabaseHost -Type A | Where-Object IPAddress | Select-Object -First 1).IPAddress
  $env:SPLITIFY_APP_ID_SUFFIX = '.qa'
  $flutterArgs = @('test', 'integration_test/d034_d_test.dart', '-d', 'emulator-5554', '--no-uninstall',
    '--dart-define-from-file=secrets/env.dev.json', "--dart-define=UI_HOLD=$Hold", "--dart-define=PIN_HOST_IP=$ip")
  $p = Start-Process -FilePath 'flutter.bat' -NoNewWindow -PassThru -RedirectStandardOutput $log -ArgumentList $flutterArgs
  $null = $p.Handle
  $handled = 0
  while (-not $p.HasExited) {
    Start-Sleep -Milliseconds 500
    $text = Get-Content $log -Raw -ErrorAction SilentlyContinue
    if (-not $text) { continue }
    $marks = [regex]::Matches($text, 'E2E-NET (on|off)|UI-CAPTURE ([\w-]+)')
    for ($i = $handled; $i -lt $marks.Count; $i++) {
      $m = $marks[$i]
      if ($m.Value -like 'E2E-NET*') {
        Set-Airplane ($m.Groups[1].Value -eq 'off')
      } else {
        $name = $m.Groups[2].Value
        Start-Sleep -Milliseconds 800
        Save-Shot "$name-light"
        & $adb shell cmd uimode night yes | Out-Null
        Start-Sleep -Milliseconds 3000
        Save-Shot "$name-dark"
        & $adb shell cmd uimode night no | Out-Null
        Write-Output "captured $name"
      }
    }
    $handled = $marks.Count
  }
  Write-Output "test exit code: $($p.ExitCode)"
  Get-Content $log -Tail 12
} finally {
  Set-Airplane $false
  & $adb shell cmd uimode night no | Out-Null
  Write-Output 'packages after:'
  & $adb shell pm list packages | Select-String splitify
  if (-not $NoLock) { Remove-Item $lock -ErrorAction SilentlyContinue; Write-Output 'emulator lock released' }
}
