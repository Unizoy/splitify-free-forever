# D-033 device check + screenshots of the minimal groups / people / joining / import flows.
# Run from the repo root while holding the emulator lock:
#   powershell -Command ". tool\env.ps1; & tool\e2e\capture_minimal_groups.ps1 [-Test <file>] [-Prefix <name>]"
# Builds side by side as com.unizoy.splitify.qa (SPLITIFY_APP_ID_SUFFIX, S-310): the store build installed on
# the emulator (another signing key, the owner's data) is never replaced or uninstalled.
# Each `UI-CAPTURE <name>` becomes splitify-artifacts\screenshots\<Prefix>-<name>.png; names ending in -dark are
# taken with the emulator in dark mode.
param(
  [string]$Test = 'integration_test/minimal_groups_test.dart',
  [string]$Prefix = 'minimal-groups-after',
  [int]$Hold = 6,
  [string]$Out = 'C:\Users\mohit\OneDrive\Desktop\theCode\splitify-artifacts\screenshots'
)
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
New-Item -ItemType Directory -Force $Out | Out-Null
$log = Join-Path $Out "$Prefix-test.log"
& $adb shell settings put system font_scale 1.0
& $adb shell cmd uimode night no | Out-Null
# The emulator's plain DNS gets a block page for *.supabase.co on this ISP; pin the PC's answer (S-214).
$supabaseHost = ([Uri](Get-Content secrets\env.dev.json -Raw | ConvertFrom-Json).SUPABASE_URL).Host
$ip = (Resolve-DnsName $supabaseHost -Type A | Where-Object IPAddress | Select-Object -First 1).IPAddress
$env:SPLITIFY_APP_ID_SUFFIX = '.qa'

function Save-Shot([string]$name) {
  & $adb shell screencap -p /sdcard/shot.png
  & $adb pull /sdcard/shot.png (Join-Path $Out "$Prefix-$name.png") 2>$null | Out-Null
}

# Only com.unizoy.splitify.qa may change: refuse to run while the owner's store build is installed, and
# never let the flutter tool uninstall anything (S-337).
function Get-Splitify { (& $adb -s emulator-5554 shell pm list packages) -match 'splitify' | Sort-Object }
$before = Get-Splitify
Write-Output "packages before: $($before -join ', ')"
if ($before -contains 'package:com.unizoy.splitify') {
  Write-Output 'The store build com.unizoy.splitify is installed: not running (S-337).'
  exit 4
}
# --no-uninstall: at the end `flutter test` uninstalls the project's BASE application id (com.unizoy.splitify,
# without the .qa suffix), which deleted the owner's store build on 2026-11-27.
$p = Start-Process -FilePath 'flutter.bat' -NoNewWindow -PassThru -RedirectStandardOutput $log `
  -ArgumentList @('test', $Test, '-d', 'emulator-5554', '--no-uninstall',
  '--dart-define-from-file=secrets/env.dev.json', "--dart-define=UI_HOLD=$Hold", "--dart-define=PIN_HOST_IP=$ip")
$null = $p.Handle
$done = @{}
while (-not $p.HasExited) {
  Start-Sleep -Milliseconds 400
  $text = Get-Content $log -Raw -ErrorAction SilentlyContinue
  if (-not $text) { continue }
  foreach ($m in [regex]::Matches($text, 'UI-CAPTURE ([\w-]+)')) {
    $name = $m.Groups[1].Value
    if ($done.ContainsKey($name)) { continue }
    $done[$name] = $true
    if ($name.EndsWith('-dark')) {
      & $adb shell cmd uimode night yes | Out-Null
      Start-Sleep -Milliseconds 2500
      Save-Shot $name
      & $adb shell cmd uimode night no | Out-Null
    } else {
      Start-Sleep -Milliseconds 1200
      Save-Shot $name
    }
    Write-Output "captured $name"
  }
}
& $adb shell cmd uimode night no | Out-Null
$after = Get-Splitify
Write-Output "packages after: $($after -join ', ')"
$gone = $before | Where-Object { $_ -ne 'package:com.unizoy.splitify.qa' -and $after -notcontains $_ }
if ($gone) { Write-Output "WARNING: packages removed during the run: $($gone -join ', ')" }
Write-Output "test exit code: $($p.ExitCode)"
Get-Content $log -Tail 8
