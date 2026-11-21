# Development setup

Status of every requirement from [PLAN.md](PLAN.md). Last checked: Nov 21, 2026.

## Ready now

| Tool | Version / detail |
|---|---|
| Windows Hypervisor Platform | On (emulator reports WHPX usable) |
| Git for Windows + Git Bash | 2.50.1 |
| GitHub CLI | Logged in; repo `Unizoy/splitify-free-forever` |
| VS Code + Dart and Flutter extensions | VS Code 1.140 |
| Flutter SDK | 3.50.1 stable, Dart 3.14.0, installed at `C:\src\flutter` |
| Android SDK | Platform `android-36` (also `android-37.0`), build-tools 36.0.0 / 37.0.0, cmdline-tools, emulator 37.3, platform-tools, NDK 28.2.13676358. All licenses accepted. Location: `%LOCALAPPDATA%\Android\Sdk` (`ANDROID_HOME`) |
| JDK | Android Studio's bundled JBR (OpenJDK 25), set as `JAVA_HOME` and with `flutter config --jdk-dir` |
| Emulator | AVD `Pixel_9_API_36` (Android 16, Play Store image). Avoid Android 37 images: they crashed on this machine's GPU. |
| Claude Code | 2.1.289 |

`flutter doctor -v` is green for Flutter, Android toolchain and Connected device. The only ✗ is Visual Studio, which this project doesn't need (no Windows desktop builds).

## Known issue on this PC

The system `Path` variable starts with empty entries (`;;;`). This breaks `flutter.bat` with `'WHERE' is not recognized`. Until it's fixed, start PowerShell commands with:

```powershell
$env:Path = (($env:Path -split ';') | ? { $_ -ne '' }) -join ';'
```

Permanent fix (run once in an **admin** PowerShell, then restart VS Code):

```powershell
$p = [Environment]::GetEnvironmentVariable('Path','Machine')
[Environment]::SetEnvironmentVariable('Path', (($p -split ';') | ? { $_ }) -join ';', 'Machine')
```

## Needed later (not set up yet)

| Item | Needed by | Notes |
|---|---|---|
| Supabase account + dev project | Milestone 1 | Free plan, region South Asia (Mumbai), named `<app-name>-dev`. Project URL + publishable key go in a Git-ignored file. |
| Google Cloud OAuth client | Milestone 1 | Only if sign-in stays Google (the default). |
| Supabase MCP (optional) | Milestone 1 | `claude mcp add --transport http supabase "https://mcp.supabase.com/mcp?project_ref=<dev-project-ref>"` — dev project only. |
| Android SDK CMake | When a package needs native code | Not installed. Gradle usually fetches it automatically; otherwise `sdkmanager "cmake;3.22.1"`. |
| Firebase project (FCM only) | Milestone 4 | Add the Android app after the Flutter project exists (needs the package name). `google-services.json` stays out of Git; service-account key only as a Supabase Edge Function secret. |
| Real Android phone with USB debugging | Optional | The emulator is enough until release testing. |
| Supabase prod project | Milestone 8 | `<app-name>-prod`. |

## Not needed

WSL 2, Docker Desktop, Scoop, the Supabase CLI, Node.js, a separate JDK, Visual Studio 2022.

## Verify

```powershell
flutter doctor -v
flutter devices
```

Then run `select now();` in the Supabase SQL Editor once the dev project exists.
