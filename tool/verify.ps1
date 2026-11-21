# Runs quality gates G1-G4 and prints a table. Usage:  .\tool\verify.ps1 [-SkipBuild]
param([switch]$SkipBuild)

$ErrorActionPreference = 'Continue'
Set-Location (Split-Path -Parent $PSScriptRoot)
. "$PSScriptRoot\env.ps1"

$results = [ordered]@{}

function Invoke-Step([string]$name, [scriptblock]$block) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Write-Host "== $name" -ForegroundColor Cyan
    & $block
    $ok = ($LASTEXITCODE -eq 0)
    $results[$name] = @{ ok = $ok; secs = [int]$sw.Elapsed.TotalSeconds }
}

Invoke-Step 'G1 format' { dart format --output=none --set-exit-if-changed lib test integration_test tool }
Invoke-Step 'G1 analyze' { flutter analyze --no-fatal-infos }
Invoke-Step 'G1 guards' { dart run tool/guards.dart }
Invoke-Step 'G2 tests' {
    flutter test --coverage --exclude-tags quarantine,needs-owner,device
}
Invoke-Step 'G2 coverage' { dart run tool/coverage_check.dart }

if (-not $SkipBuild) {
    $envFile = 'secrets/env.dev.json'
    if (-not (Test-Path $envFile)) { $envFile = 'secrets/env.example.json' }
    Invoke-Step 'G4 build apk' {
        flutter build apk --debug "--dart-define-from-file=$envFile"
    }
}

Write-Host ''
Write-Host 'Gate                 Result  Seconds'
Write-Host '-------------------- ------- -------'
$failed = $false
foreach ($k in $results.Keys) {
    $r = if ($results[$k].ok) { 'PASS' } else { 'FAIL'; $failed = $true }
    '{0,-20} {1,-7} {2,7}' -f $k, $r, $results[$k].secs | Write-Host
}
Write-Host 'G3 backend / G5 device: run separately (not part of this script).'
if ($failed) { exit 1 }
exit 0
