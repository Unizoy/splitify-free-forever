# Runs plain device integration tests one after another under ONE hold of the shared emulator lock (phase 19 T8
# full regression). Each file: `flutter test <file> -d emulator-5554` with the dev env and the S-214 DNS pin; the log
# goes to splitify-artifacts\phase-NN\it-<name>.log and a RESULT line is printed per file. Stops starting new files
# after -MaxMinutes so the lock is never held for long (the rest can run in a second call).
#   powershell -File tool\e2e\run_suite.ps1 -Files groups_test,sync_offline_test [-MaxMinutes 28] [-NoLock]
param([string[]]$Files, [string]$Phase = '19', [int]$MaxMinutes = 28, [switch]$NoLock)
$Files = @($Files | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$ErrorActionPreference = 'Continue'
$repo = (Resolve-Path "$PSScriptRoot\..\..").Path
Set-Location $repo
. "$repo\tool\env.ps1"
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
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
$started = Get-Date
try {
  & $adb shell cmd connectivity airplane-mode disable | Out-Null
  & $adb shell settings put system font_scale 1.0 | Out-Null
  $supabaseHost = ([Uri](Get-Content secrets\env.dev.json -Raw | ConvertFrom-Json).SUPABASE_URL).Host
  $ip = (Resolve-DnsName $supabaseHost -Type A | Where-Object IPAddress | Select-Object -First 1).IPAddress
  foreach ($f in $Files) {
    if (((Get-Date) - $started).TotalMinutes -gt $MaxMinutes) { Write-Host "RESULT $f NOT-RUN (time box)"; continue }
    $name = [IO.Path]::GetFileNameWithoutExtension($f)
    $path = if ($f -like 'integration_test/*') { $f } else { "integration_test/$name.dart" }
    $log = Join-Path $out "it-$name.log"
    $t0 = Get-Date
    cmd /c "flutter test $path -d emulator-5554 --dart-define-from-file=secrets/env.dev.json --dart-define=PIN_HOST_IP=$ip > `"$log`" 2>&1"
    $code = $LASTEXITCODE
    if ($code -ne 0 -and (Select-String -Path $log -Pattern 'Failed to start Dart Development Service|did not complete|loading' -Quiet)) {
      Write-Host "$name : tool/loading failure, one re-run (LEARNINGS phase 01/07)"
      cmd /c "flutter test $path -d emulator-5554 --dart-define-from-file=secrets/env.dev.json --dart-define=PIN_HOST_IP=$ip > `"$log`" 2>&1"
      $code = $LASTEXITCODE
    }
    $secs = [int]((Get-Date) - $t0).TotalSeconds
    $summary = (Select-String -Path $log -Pattern '^\d+:\d+ \+\d+.*(All tests passed|Some tests failed)' | Select-Object -Last 1).Line
    Write-Host "RESULT $name exit=$code ${secs}s $summary"
  }
} finally {
  & $adb shell cmd connectivity airplane-mode disable | Out-Null
  if (-not $NoLock -and (Test-Path $lock)) { Remove-Item $lock -Force; Write-Host 'emulator lock released' }
}
