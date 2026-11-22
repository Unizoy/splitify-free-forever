# S-160 / phase 19: one REAL WorkManager run (integration_test/background_sync_test.dart). Reacts to the test's
# markers: E2E-NET off|on (airplane mode), E2E-HOME (HOME key), E2E-JOBS (force-run every job of the app with
# `cmd jobscheduler run -f`). Saves the run log, WorkManager's logcat lines and `dumpsys jobscheduler` into
# splitify-artifacts\phase-NN\. Holds the shared emulator lock; always switches airplane mode off at the end.
#   powershell -File tool\e2e\background_sync.ps1 [-Phase 19] [-NoLock]
param([string]$Phase = '19', [switch]$NoLock)
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

function Set-Airplane([bool]$on) {
  & $adb shell cmd connectivity airplane-mode $(if ($on) { 'enable' } else { 'disable' }) | Out-Null
  Write-Host "airplane mode $(if ($on) { 'ON' } else { 'OFF' })"
}

function Invoke-AppJobs {
  $dump = & $adb shell dumpsys jobscheduler
  $ids = [regex]::Matches(($dump -join "`n"), "JOB #u0a\d+/(\d+): [0-9a-f]+ $app/") |
    ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
  foreach ($id in $ids) {
    $r = & $adb shell cmd jobscheduler run -f $app $id
    Write-Host "job $id forced: $r"
  }
  if (-not $ids) { Write-Host 'no scheduled job of the app found' }
}

if (-not $NoLock) {
  $end = (Get-Date).AddMinutes(40)
  while ($true) {
    try { New-Item -ItemType File $lock -ErrorAction Stop -Value $Phase | Out-Null; break }
    catch { if ((Get-Date) -gt $end) { throw 'emulator lock not free after 40 min' }; Start-Sleep 30 }
  }
  Write-Host 'emulator lock taken'
}
try {
  Set-Airplane $false
  & $adb logcat -c
  $supabaseHost = ([Uri](Get-Content secrets\env.dev.json -Raw | ConvertFrom-Json).SUPABASE_URL).Host
  $ip = (Resolve-DnsName $supabaseHost -Type A | Where-Object IPAddress | Select-Object -First 1).IPAddress
  $log = Join-Path $out 'background-sync.log'
  Remove-Item $log -ErrorAction SilentlyContinue
  $argv = @('test', 'integration_test/background_sync_test.dart', '-d', 'emulator-5554',
    '--dart-define-from-file=secrets/env.dev.json', "--dart-define=PIN_HOST_IP=$ip", '--dart-define=E2E_WORKER=true')
  $p = Start-Process -FilePath 'flutter.bat' -NoNewWindow -PassThru -RedirectStandardOutput $log -ArgumentList $argv
  $null = $p.Handle
  $handled = 0
  while (-not $p.HasExited) {
    Start-Sleep -Milliseconds 400
    $text = Get-Content $log -Raw -ErrorAction SilentlyContinue
    if (-not $text) { continue }
    $marks = [regex]::Matches($text, 'E2E-NET (on|off)|E2E-HOME|E2E-JOBS')
    for ($i = $handled; $i -lt $marks.Count; $i++) {
      $m = $marks[$i]
      if ($m.Value -like 'E2E-NET*') { Set-Airplane ($m.Groups[1].Value -eq 'off') }
      elseif ($m.Value -eq 'E2E-HOME') { & $adb shell input keyevent KEYCODE_HOME | Out-Null; Write-Host 'HOME pressed' }
      else {
        & $adb shell dumpsys jobscheduler | Select-String -Pattern $app -Context 0, 6 | Out-File (Join-Path $out 'jobscheduler-before.txt')
        Invoke-AppJobs
      }
    }
    $handled = $marks.Count
  }
  $p.WaitForExit()
  Write-Host "flutter test exit $($p.ExitCode)"
  & $adb logcat -d | Select-String -Pattern 'WM-|BackgroundWorker|flutter.*(sync|W1)' | Out-File (Join-Path $out 'background-sync-logcat.txt')
  Get-Content $log | Select-String -Pattern 'W1 |All tests passed|Some tests failed|Expected|Actual|Timed out' |
    Select-Object -Last 10 | ForEach-Object { Write-Host "  $($_.Line.Trim())" }
  Get-Content (Join-Path $out 'background-sync-logcat.txt') | Select-String -Pattern 'Worker result|WorkerWrapper' |
    Select-Object -Last 5 | ForEach-Object { Write-Host "  $($_.Line.Trim())" }
} finally {
  Set-Airplane $false
  if (-not $NoLock -and (Test-Path $lock)) { Remove-Item $lock -Force; Write-Host 'emulator lock released' }
}
