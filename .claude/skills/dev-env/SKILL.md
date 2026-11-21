---
name: dev-env
description: Prepares and repairs the Splitify development environment on this Windows PC — PATH fix for flutter.bat, Flutter/Dart/JDK/Android SDK checks, emulator boot, adb, Deno install. Use at the start of every session, whenever flutter/dart/adb/gradle commands fail with environment errors ("'WHERE' is not recognized", device not found, JAVA_HOME), or before installing a tool.
---

# Splitify dev environment (Windows 11)

Known facts (verified 2026-11-21): Flutter 3.50.1 / Dart 3.14.0 at `C:\src\flutter`; Android SDK at
`%LOCALAPPDATA%\Android\Sdk`; JDK = `C:\Program Files\Android\Android Studio\jbr` (`JAVA_HOME`); AVD
`Pixel_9_API_36` (Android 16, Play Store) appears as `emulator-5554`. Never use Android 37 images (GPU crash).
No Docker, WSL, Node or Supabase CLI — by design.

## 1. PATH fix (every PowerShell command that runs flutter/dart/gradle)

The machine PATH may start with empty entries, which breaks `flutter.bat`. Prefix commands with:
```powershell
$env:Path = (([Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')) -split ';' | Where-Object { $_ -ne '' }) -join ';'
```
Each PowerShell tool call is a fresh shell, so repeat it in every call (or call the repo script
`tool/env.ps1` once phase 01 has created it: `. .\tool\env.ps1; flutter test`).
In Git Bash, `flutter` works when `/c/src/flutter/bin` is on PATH; prefer PowerShell for Flutter.

## 2. Preflight checks

```powershell
flutter --version            # expect 3.50.x stable
dart --version               # expect 3.14.x
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" devices
& "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -list-avds   # expect Pixel_9_API_36
```
If Flutter is upgraded or downgraded by a later phase, record it as an `S-` decision first (never casually).

## 3. Emulator

- Running? `adb devices` shows `emulator-5554  device`.
- Start (no window needed, keeps snapshots):
  ```powershell
  Start-Process "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -ArgumentList '-avd','Pixel_9_API_36','-no-boot-anim','-gpu','auto' -WindowStyle Minimized
  & "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" wait-for-device
  # wait for full boot
  do { Start-Sleep 3; $b = & "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" shell getprop sys.boot_completed } until ($b -match '1')
  ```
- Never run `-wipe-data` or delete the AVD (it may hold the owner's test Google account). The guard hook blocks it.
- If the emulator hangs: `adb emu kill`, then start again. If it still fails, add a learning and a blocker; continue
  with non-device gates.

## 4. Deno (needed from phase 04 for Edge Function tests)

Install per-user without piping scripts into a shell (the guard blocks `irm | iex`):
```powershell
$v = (Invoke-RestMethod https://api.github.com/repos/denoland/deno/releases/latest).tag_name
$zip = "$env:TEMP\deno.zip"
Invoke-WebRequest "https://github.com/denoland/deno/releases/download/$v/deno-x86_64-pc-windows-msvc.zip" -OutFile $zip
New-Item -ItemType Directory -Force "$HOME\.deno\bin" | Out-Null
Expand-Archive $zip -DestinationPath "$HOME\.deno\bin" -Force
$u = [Environment]::GetEnvironmentVariable('Path','User'); if ($u -notlike "*\.deno\bin*") { [Environment]::SetEnvironmentVariable('Path', "$u;$HOME\.deno\bin", 'User') }
& "$HOME\.deno\bin\deno.exe" --version
```
Record the installed version in LEARNINGS.md.

## 5. Common failures

| Symptom | Fix |
| --- | --- |
| `'WHERE' is not recognized` | PATH fix (step 1) |
| Gradle: "Unsupported class file major version" / JDK issues | ensure `JAVA_HOME` = Android Studio JBR; `flutter config --jdk-dir "C:\Program Files\Android\Android Studio\jbr"` |
| Large downloads fail midway | `curl -C - --retry 5 --retry-all-errors -L -o <file> <url>`; `redirector.gvt1.com` mirrors are fast for Google downloads |
| `adb: device offline` | `adb kill-server; adb start-server`; restart emulator |
| Build cache weirdness | `flutter clean` then `flutter pub get` (never delete folders outside the repo) |
