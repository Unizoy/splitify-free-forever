# Phase 15 e2e with REAL airplane mode and REAL app kills (TC-27-11, TC-27-12, TC-27-13, phase 10 receipts
# offline): runs integration_test/offline_airplane_test.dart one stage per app launch and reacts to what the
# test prints:
#   E2E-NET off|on   -> adb airplane mode on/off (the test waits until the phone sees it)
#   E2E-KILL         -> adb force-stop of the app (kill mid-push)
#   UI-CAPTURE name  -> light + dark screenshots into splitify-artifacts\phase-NN\
# Holds the shared emulator lock for the whole run and always switches airplane mode off at the end.
# `--no-uninstall` keeps the app (and its data) between stages: `flutter test` uninstalls it by default.
#   powershell -File tool\e2e\airplane.ps1                 # all stages: A1 A2 A3 K1 K2 C1
#   powershell -File tool\e2e\airplane.ps1 -Stages C1      # one stage
param(
  [string[]]$Stages = @('A1', 'A2', 'A3', 'K1', 'K2', 'C1'),
  [string]$Phase = '15',
  [int]$Hold = 8,
  [switch]$NoLock
)
$Stages = @($Stages | ForEach-Object { $_ -split ',' } | Where-Object { $_ })   # `-File` passes "K2,C1" as one string
$ErrorActionPreference = 'Continue'   # adb writes to stderr; failures are checked by exit codes
$repo = (Resolve-Path "$PSScriptRoot\..\..").Path
Set-Location $repo
. "$repo\tool\env.ps1"
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$app = 'com.unizoy.splitify'
$artifacts = 'C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts'
$out = Join-Path $artifacts "phase-$Phase"
$lock = Join-Path $artifacts 'emulator.lock'
New-Item -ItemType Directory -Force $out | Out-Null

function Set-Airplane([bool]$on) {
  & $adb shell cmd connectivity airplane-mode $(if ($on) { 'enable' } else { 'disable' }) | Out-Null
  Write-Host "airplane mode $(if ($on) { 'ON' } else { 'OFF' })"
}

function Save-Shot([string]$name) {
  & $adb shell screencap -p /sdcard/e2e.png
  & $adb pull /sdcard/e2e.png "$out\$name.png" 2>$null | Out-Null
}

function Set-Dark([bool]$on) {
  & $adb shell cmd uimode night $(if ($on) { 'yes' } else { 'no' }) | Out-Null
  Start-Sleep 2
}

# The ISP blocks plain DNS for *.supabase.co on the emulator: pin the PC's answer (S-214).
function Get-PinIp {
  $supabaseHost = ([Uri](Get-Content secrets\env.dev.json -Raw | ConvertFrom-Json).SUPABASE_URL).Host
  (Resolve-DnsName $supabaseHost -Type A | Where-Object IPAddress | Select-Object -First 1).IPAddress
}

function Enter-Lock {
  if ($NoLock) { return }
  $end = (Get-Date).AddMinutes(40)
  while ($true) {
    try {
      New-Item -ItemType File $lock -ErrorAction Stop -Value $Phase | Out-Null
      Write-Host 'emulator lock taken'
      return
    } catch {
      if ((Get-Date) -gt $end) { throw 'emulator lock not free after 40 min' }
      Start-Sleep 30
    }
  }
}

function Exit-Lock {
  if (-not $NoLock -and (Test-Path $lock)) { Remove-Item $lock -Force; Write-Host 'emulator lock released' }
}

# Runs one stage; returns the flutter exit code (a killed stage ends with a non-zero code on purpose).
function Invoke-Stage([string]$stage, [string]$ip) {
  $log = Join-Path $out "e2e-$stage.log"
  Remove-Item $log -ErrorAction SilentlyContinue
  $argv = @('test', 'integration_test/offline_airplane_test.dart', '-d', 'emulator-5554', '--no-uninstall',
    '--dart-define-from-file=secrets/env.dev.json', "--dart-define=PIN_HOST_IP=$ip",
    '--dart-define=E2E_AIRPLANE=true', "--dart-define=UI_HOLD=$Hold", '--plain-name', $stage)
  $p = Start-Process -FilePath 'flutter.bat' -NoNewWindow -PassThru -RedirectStandardOutput $log -ArgumentList $argv
  $null = $p.Handle
  $handled = 0
  $killedAt = $null
  while (-not $p.HasExited) {
    Start-Sleep -Milliseconds 400
    $text = Get-Content $log -Raw -ErrorAction SilentlyContinue
    if (-not $text) { continue }
    $marks = [regex]::Matches($text, 'E2E-NET (on|off)|E2E-KILL|UI-CAPTURE ([\w-]+)')
    for ($i = $handled; $i -lt $marks.Count; $i++) {
      $m = $marks[$i]
      if ($m.Value -like 'E2E-NET*') {
        Set-Airplane ($m.Groups[1].Value -eq 'off')
      } elseif ($m.Value -eq 'E2E-KILL') {
        & $adb shell am force-stop $app | Out-Null
        $killedAt = Get-Date
        Write-Host "$stage : app force-stopped mid-push"
      } else {
        $name = $m.Groups[2].Value
        Save-Shot "$name-light"
        Set-Dark $true
        Save-Shot "$name-dark"
        Set-Dark $false
        Write-Host "$stage : captured $name"
      }
    }
    $handled = $marks.Count
    # After a kill the flutter tool may wait for the dead app: give it a minute, then stop it.
    if ($killedAt -and ((Get-Date) - $killedAt).TotalSeconds -gt 60) { Stop-Process -Id $p.Id -Force; break }
  }
  $p.WaitForExit()
  $code = $p.ExitCode
  Write-Host "$stage : exit $code"
  Get-Content $log | Select-String -Pattern 'E2E-OUTBOX|after the kill|synced \d+ ms|B sees|K2:|A2 done|All tests passed|Some tests failed|Expected|Actual|Timed out' |
    Select-Object -Last 12 | ForEach-Object { Write-Host "  $($_.Line.Trim())" }
  & $adb shell am force-stop $app | Out-Null   # the next stage is a fresh launch
  return $code
}

Enter-Lock
$results = [ordered]@{}
try {
  & $adb shell settings put system font_scale 1.0
  Set-Dark $false
  Set-Airplane $false
  $ip = Get-PinIp
  if ($Stages -contains 'A1') { cmd /c "`"$adb`" shell pm clear $app 2>nul" | Out-Null }   # fresh phone for TC-27-11
  foreach ($s in $Stages) {
    $code = Invoke-Stage $s $ip
    $results[$s] = $code
    if ($s -ne 'K1' -and $code -ne 0) { Write-Host "stage $s failed; stopping"; break }
  }
} finally {
  Set-Airplane $false
  Set-Dark $false
  Exit-Lock
}
$results.GetEnumerator() | ForEach-Object { Write-Host "RESULT $($_.Key) exit=$($_.Value)" }
