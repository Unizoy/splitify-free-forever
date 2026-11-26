# Builds the release APKs (phase 19 T6, S-201; one build since D-030, S-292): one APK per ABI (arm64-v8a,
# armeabi-v7a, x86_64) plus a universal phone APK (arm + arm64), then checks with aapt2 that no APK declares a
# notification-listener, accessibility, "display over other apps" or SMS permission: Google Play Protect's enhanced
# fraud protection (India) blocks sideloaded APKs that do. Output: build\release-apks\splitify-<abi>.apk and
# splitify-universal.apk.
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
Get-ChildItem $out -Filter *.apk | Remove-Item -Force
$apkDir = Join-Path $root 'build\app\outputs\flutter-apk'

$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
$aapt = Get-ChildItem "$sdk\build-tools" -Directory | Sort-Object { [version]($_.Name -replace '[^0-9.]', '') } |
    ForEach-Object { Join-Path $_.FullName 'aapt2.exe' } | Where-Object { Test-Path $_ } | Select-Object -Last 1

# What no APK may declare (D-028, D-030).
$forbidden = 'BIND_ACCESSIBILITY_SERVICE|BIND_NOTIFICATION_LISTENER_SERVICE|SYSTEM_ALERT_WINDOW|RECEIVE_SMS|READ_SMS|SEND_SMS'

$log = 'build\release-split.log'
cmd /c "flutter build apk --release --split-per-abi --dart-define-from-file=$EnvFile > $log 2>&1"
if ($LASTEXITCODE -ne 0) { Get-Content $log -Tail 30; throw 'split-per-abi build failed' }
foreach ($abi in @('arm64-v8a', 'armeabi-v7a', 'x86_64')) {
    Copy-Item "$apkDir\app-$abi-release.apk" (Join-Path $out "splitify-$abi.apk") -Force
}

$log = 'build\release-universal.log'
cmd /c "flutter build apk --release --target-platform android-arm,android-arm64 --dart-define-from-file=$EnvFile > $log 2>&1"
if ($LASTEXITCODE -ne 0) { Get-Content $log -Tail 30; throw 'universal build failed' }
Copy-Item "$apkDir\app-release.apk" (Join-Path $out 'splitify-universal.apk') -Force

if ($aapt) {
    foreach ($apk in Get-ChildItem $out -Filter 'splitify-*.apk') {
        $dump = (& $aapt dump permissions $apk.FullName) + (& $aapt dump xmltree --file AndroidManifest.xml $apk.FullName)
        $hits = $dump | Select-String -Pattern $forbidden
        if ($hits) { $hits | ForEach-Object { Write-Host $_.Line }; throw "$($apk.Name) declares a blocked permission" }
        Write-Host ('{0}: manifest OK (no listener/accessibility/overlay/SMS permission)' -f $apk.Name)
    }
} else {
    Write-Host 'aapt2 not found (Android build-tools): manifest check SKIPPED'
}

Get-ChildItem $out -Filter splitify-*.apk | ForEach-Object {
    $mb = [math]::Round($_.Length / 1MB, 1)
    $sha = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower()
    Write-Host ("{0,-36} {1,6} MB  {2}" -f $_.Name, $mb, $sha)
}
$universal = (Get-Item (Join-Path $out 'splitify-universal.apk')).Length / 1MB
if ($universal -ge 40) { throw "universal APK is $([math]::Round($universal, 1)) MB (limit 40 MB)" }
