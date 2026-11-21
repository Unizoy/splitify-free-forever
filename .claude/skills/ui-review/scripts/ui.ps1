# UI review helpers for the emulator (dot-source: . .claude\skills\ui-review\scripts\ui.ps1 -Phase 02)
# Tap by accessibility label (uiautomator), screenshots, dark mode and font scale. Idempotent, no secrets.
param([string]$Phase = '00')
$script:adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$script:out = "C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\phase-$Phase"
New-Item -ItemType Directory -Force $script:out | Out-Null

function Invoke-TapLabel([string]$label) {
  & $script:adb shell uiautomator dump /sdcard/ui.xml | Out-Null
  $xml = (& $script:adb shell cat /sdcard/ui.xml) -join ''
  foreach ($attr in @('content-desc', 'text')) {
    $pattern = $attr + '="' + [regex]::Escape($label) + '[^"]*"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
    $m = [regex]::Match($xml, $pattern)
    if ($m.Success) {
      $x = ([int]$m.Groups[1].Value + [int]$m.Groups[3].Value) / 2
      $y = ([int]$m.Groups[2].Value + [int]$m.Groups[4].Value) / 2
      & $script:adb shell input tap $x $y
      Start-Sleep -Milliseconds 1500
      return
    }
  }
  Write-Output "NOT FOUND: $label"
}

function Save-Shot([string]$name) {
  & $script:adb shell screencap -p /sdcard/shot.png
  & $script:adb pull /sdcard/shot.png "$script:out\$name.png" 2>$null | Out-Null
}

function Set-Dark([bool]$on) {
  & $script:adb shell cmd uimode night ($(if ($on) { 'yes' } else { 'no' })) | Out-Null
  Start-Sleep 2
}

function Set-FontScale([string]$scale) {
  & $script:adb shell settings put system font_scale $scale
  Start-Sleep 2
}

function Invoke-Scroll([int]$dy = 1200) {
  & $script:adb shell input swipe 540 1800 540 (1800 - $dy) 400
  Start-Sleep 1
}

function Start-App {
  & $script:adb shell am force-stop com.unizoy.splitify
  & $script:adb shell am start -n com.unizoy.splitify/.MainActivity | Out-Null
  Start-Sleep 5
}
