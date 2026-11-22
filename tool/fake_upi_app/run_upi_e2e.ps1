# Pay-via-UPI device tests (phase 11: TC-26-02, TC-26-03, TC-2-02). Run from the repo root while holding the
# emulator lock:
#   powershell -File tool\fake_upi_app\run_upi_e2e.ps1 [-Only installed|absent]
# 1. Builds and installs the fake UPI app, runs integration_test/friends_upi_test.dart, then checks that the link
#    the fake app logged (logcat tag FAKE_UPI) is exactly the one the test expected (`UPI-EXPECT <uri>`).
# 2. Uninstalls it and runs the test again with FAKE_UPI=absent ("No UPI app found" sheet).
param([string]$Only = '', [string]$Device = 'emulator-5554')
$ErrorActionPreference = 'Stop'
$repo = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $repo
$out = Join-Path $env:TEMP 'splitify-upi-e2e'
New-Item -ItemType Directory -Force $out | Out-Null

# The emulator's plain DNS gets a block page for *.supabase.co on this ISP; pin the PC's answer (S-214).
$supabaseHost = ([Uri](Get-Content secrets\env.dev.json -Raw | ConvertFrom-Json).SUPABASE_URL).Host
$ip = (Resolve-DnsName $supabaseHost -Type A | Where-Object IPAddress | Select-Object -First 1).IPAddress

function Invoke-UpiTest([string]$mode) {
  $log = Join-Path $out "test-$mode.log"
  # flutter.bat writes warnings to stderr; run it through cmd so PowerShell does not stop on them.
  & cmd /c "flutter test integration_test/friends_upi_test.dart -d $Device --dart-define-from-file=secrets/env.dev.json --dart-define=PIN_HOST_IP=$ip --dart-define=FAKE_UPI=$mode > `"$log`" 2>&1"
  $code = $LASTEXITCODE
  Get-Content $log | Select-String -Pattern 'UPI-EXPECT|All tests passed|Some tests failed|Expected:|Actual:|\[E\]' |
    ForEach-Object { Write-Host "  $_" }
  return @{ Code = $code; Log = $log }
}

$ok = $true
if ($Only -ne 'absent') {
  & (Join-Path $PSScriptRoot 'build.ps1') -Install -Device $Device
  & adb -s $Device logcat -c
  Write-Output 'fake UPI app installed: running the pay path'
  $r = Invoke-UpiTest 'installed'
  $expected = (Select-String -Path $r.Log -Pattern 'UPI-EXPECT (\S+)' | Select-Object -Last 1).Matches.Groups[1].Value
  $logged = (& adb -s $Device logcat -d -s 'FAKE_UPI:I' | Select-String -Pattern 'FAKE_UPI\s*:\s*(\S+)' |
      Select-Object -Last 1).Matches.Groups[1].Value
  Write-Output "  expected: $expected"
  Write-Output "  received: $logged"
  if ($r.Code -ne 0) { Write-Output 'FAIL: installed path test failed'; $ok = $false }
  elseif (-not $expected -or $expected -ne $logged) { Write-Output 'FAIL (TC-26-02): the fake UPI app got a different link'; $ok = $false }
  else { Write-Output 'PASS (TC-26-02): the fake UPI app received exactly the expected link' }
}
if ($Only -ne 'installed') {
  & (Join-Path $PSScriptRoot 'build.ps1') -Uninstall -Device $Device
  Write-Output 'no UPI app: running the fallback path'
  $r = Invoke-UpiTest 'absent'
  if ($r.Code -ne 0) { Write-Output 'FAIL (TC-26-03)'; $ok = $false } else { Write-Output 'PASS (TC-26-03)' }
}
if (-not $ok) { exit 1 }
