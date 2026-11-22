# Builds the fake UPI handler (debug APK, package dev.splitify.fakeupi) and optionally installs or removes it on
# the emulator. Used by the Pay-via-UPI device tests (phase 11 T5, TC-26-02 / TC-26-03).
#
#   .\tool\fake_upi_app\build.ps1                 # build only -> tool\fake_upi_app\app\build\outputs\apk\debug\app-debug.apk
#   .\tool\fake_upi_app\build.ps1 -Install        # build + adb install -r
#   .\tool\fake_upi_app\build.ps1 -Uninstall      # remove it (the "no UPI app" path)
#
# Needs JDK 17+ (JAVA_HOME, e.g. Android Studio's jbr) and the Android SDK (ANDROID_HOME or android\local.properties).
# Uses the app's Gradle distribution from %USERPROFILE%\.gradle (same version as android/gradle/wrapper).
param(
    [switch]$Install,
    [switch]$Uninstall,
    [string]$Device = 'emulator-5554'
)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$repo = Resolve-Path (Join-Path $here '..\..')
$apk = Join-Path $here 'app\build\outputs\apk\debug\app-debug.apk'

if ($Uninstall) {
    & adb -s $Device uninstall dev.splitify.fakeupi | Out-Host
    return
}

if (-not $env:JAVA_HOME) {
    $jbr = 'C:\Program Files\Android\Android Studio\jbr'
    if (Test-Path $jbr) { $env:JAVA_HOME = $jbr }
}
if (-not $env:ANDROID_HOME) {
    $props = Join-Path $repo 'android\local.properties'
    $line = if (Test-Path $props) { Get-Content $props | Where-Object { $_ -match '^sdk\.dir=' } } else { $null }
    if ($line) { $env:ANDROID_HOME = ($line -replace '^sdk\.dir=', '') -replace '\\\\', '\' -replace '\\:', ':' }
}

# Gradle: the app's wrapper when Flutter generated it, else the same distribution from the Gradle cache.
$wrapper = Join-Path $repo 'android\gradlew.bat'
$props = Get-Content (Join-Path $repo 'android\gradle\wrapper\gradle-wrapper.properties') -Raw
$version = [regex]::Match($props, 'gradle-([0-9.]+)-').Groups[1].Value
if (Test-Path $wrapper) {
    $gradle = $wrapper
} else {
    $dist = Get-ChildItem (Join-Path $env:USERPROFILE ".gradle\wrapper\dists\gradle-$version-*") -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Get-ChildItem $_.FullName -Directory } |
        ForEach-Object { Join-Path $_.FullName "gradle-$version\bin\gradle.bat" } |
        Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $dist) { throw "Gradle $version not found: run 'flutter build apk' once so Flutter downloads it." }
    $gradle = $dist
}

& $gradle -p $here --console=plain -q ':app:assembleDebug'
if ($LASTEXITCODE -ne 0) { throw "fake UPI build failed ($LASTEXITCODE)" }
Write-Host "fake UPI app: $apk"

if ($Install) {
    & adb -s $Device install -r $apk | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "adb install failed ($LASTEXITCODE)" }
}
