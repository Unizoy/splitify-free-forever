# Builds the release APKs (phase 19 T6, S-201; flavours D-028, S-276): for each flavour an arm64 APK and a universal
# phone APK (arm + arm64), then checks with aapt2 that `standard` declares no payment-bubble permission or service.
#   standard  default for GitHub / sideloading: no accessibility, notification-listener or overlay permissions,
#             so Google Play Protect's enhanced fraud protection (India) lets it install.
#   full      with the payment bubble: for adb installs and a future Play Store listing.
# Both have the same applicationId (com.unizoy.splitify): one updates the other in place, only one can be installed.
# Signing: android/app/build.gradle.kts uses secrets/release-key.properties, else secrets/key.properties, else the
# debug key (the script says which). Usage, from the repo root:
#   powershell -File tool\build_release.ps1 [-EnvFile secrets/env.prod.json] [-Flavor standard|full|both]
param(
    [string]$EnvFile = 'secrets/env.dev.json',
    [ValidateSet('standard', 'full', 'both')][string]$Flavor = 'both'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
. "$root\tool\env.ps1"

$key = @('secrets\release-key.properties', 'secrets\key.properties') | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($key) { Write-Host "Signing with $key" } else { Write-Host 'No key properties found: signing with the DEBUG key' }

$out = Join-Path $root 'build\release-apks'
New-Item -ItemType Directory -Force $out | Out-Null
$apkDir = Join-Path $root 'build\app\outputs\flutter-apk'
$flavors = if ($Flavor -eq 'both') { @('standard', 'full') } else { @($Flavor) }

$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
$aapt = Get-ChildItem "$sdk\build-tools" -Directory | Sort-Object { [version]($_.Name -replace '[^0-9.]', '') } |
    ForEach-Object { Join-Path $_.FullName 'aapt2.exe' } | Where-Object { Test-Path $_ } | Select-Object -Last 1

# What the standard flavour must not declare (D-028).
$forbidden = 'BIND_ACCESSIBILITY_SERVICE|BIND_NOTIFICATION_LISTENER_SERVICE|SYSTEM_ALERT_WINDOW|RECEIVE_SMS|READ_SMS|SEND_SMS|PaymentNotificationListener|SmartCaptureService'

foreach ($f in $flavors) {
    $log = "build\release-$f-arm64.log"
    cmd /c "flutter build apk --release --flavor $f --split-per-abi --target-platform android-arm64 --dart-define-from-file=$EnvFile > $log 2>&1"
    if ($LASTEXITCODE -ne 0) { Get-Content $log -Tail 30; throw "$f arm64 build failed" }
    Copy-Item "$apkDir\app-arm64-v8a-$f-release.apk" (Join-Path $out "splitify-$f-arm64-v8a.apk") -Force

    $log = "build\release-$f-universal.log"
    cmd /c "flutter build apk --release --flavor $f --target-platform android-arm,android-arm64 --dart-define-from-file=$EnvFile > $log 2>&1"
    if ($LASTEXITCODE -ne 0) { Get-Content $log -Tail 30; throw "$f universal build failed" }
    Copy-Item "$apkDir\app-$f-release.apk" (Join-Path $out "splitify-$f-universal.apk") -Force
}

if ($aapt) {
    foreach ($f in $flavors) {
        foreach ($apk in Get-ChildItem $out -Filter "splitify-$f-*.apk") {
            $dump = (& $aapt dump permissions $apk.FullName) + (& $aapt dump xmltree --file AndroidManifest.xml $apk.FullName)
            $hits = $dump | Select-String -Pattern $forbidden
            if ($f -eq 'standard' -and $hits) { $hits | ForEach-Object { Write-Host $_.Line }; throw "$($apk.Name) declares payment-bubble permissions" }
            if ($f -eq 'full' -and -not $hits) { throw "$($apk.Name) has no payment bubble" }
            Write-Host ("{0}: manifest OK ({1})" -f $apk.Name, $(if ($f -eq 'standard') { 'no bubble services/permissions' } else { 'bubble present' }))
        }
    }
} else {
    Write-Host 'aapt2 not found (Android build-tools): manifest check SKIPPED'
}

Get-ChildItem $out -Filter splitify-*.apk | ForEach-Object {
    $mb = [math]::Round($_.Length / 1MB, 1)
    $sha = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower()
    Write-Host ("{0,-36} {1,6} MB  {2}" -f $_.Name, $mb, $sha)
}
foreach ($f in $flavors) {
    $universal = (Get-Item (Join-Path $out "splitify-$f-universal.apk")).Length / 1MB
    if ($universal -ge 40) { throw "$f universal APK is $([math]::Round($universal, 1)) MB (limit 40 MB)" }
}
