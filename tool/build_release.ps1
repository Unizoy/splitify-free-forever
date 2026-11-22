# Builds the release APKs (phase 19 T6, S-201): one APK per ABI plus a universal phone APK (arm + arm64).
# Signing: android/app/build.gradle.kts uses secrets/release-key.properties, else secrets/key.properties, else the
# debug key (the script says which). Usage, from the repo root:
#   powershell -File tool\build_release.ps1 [-EnvFile secrets/env.prod.json]
param([string]$EnvFile = 'secrets/env.dev.json')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
. "$root\tool\env.ps1"

$key = @('secrets\release-key.properties', 'secrets\key.properties') | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($key) { Write-Host "Signing with $key" } else { Write-Host 'No key properties found: signing with the DEBUG key' }

$out = Join-Path $root 'build\release-apks'
New-Item -ItemType Directory -Force $out | Out-Null
$apkDir = Join-Path $root 'build\app\outputs\flutter-apk'

cmd /c "flutter build apk --release --split-per-abi --dart-define-from-file=$EnvFile > build\release-split.log 2>&1"
if ($LASTEXITCODE -ne 0) { Get-Content build\release-split.log -Tail 30; throw 'split-per-abi build failed' }
Copy-Item "$apkDir\app-*-release.apk" $out -Force

cmd /c "flutter build apk --release --target-platform android-arm,android-arm64 --dart-define-from-file=$EnvFile > build\release-universal.log 2>&1"
if ($LASTEXITCODE -ne 0) { Get-Content build\release-universal.log -Tail 30; throw 'universal build failed' }
Copy-Item "$apkDir\app-release.apk" (Join-Path $out 'app-universal-release.apk') -Force

Get-ChildItem $out -Filter *.apk | ForEach-Object {
    $mb = [math]::Round($_.Length / 1MB, 1)
    $sha = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower()
    Write-Host ("{0,-36} {1,6} MB  {2}" -f $_.Name, $mb, $sha)
}
$universal = (Get-Item (Join-Path $out 'app-universal-release.apk')).Length / 1MB
if ($universal -ge 40) { throw "universal APK is $([math]::Round($universal, 1)) MB (limit 40 MB)" }
