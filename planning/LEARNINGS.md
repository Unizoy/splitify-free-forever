# Learnings

Gotchas, working commands and fixes discovered while building. Every session reads this at start and adds to it
at the end of its phase (`capture-learning` skill). When an entry describes a repeatable procedure, turn it into a
skill under `.claude/skills/` and leave a one-line pointer here.

Format: `- [phase NN] <topic>: <what happened> → <what works>`

## Environment (Windows PC)

- [planning] PATH: the machine PATH starts with empty entries (`;;;`), which breaks `flutter.bat` with
  `'WHERE' is not recognized`. Fix per shell: see `CLAUDE.md` (Windows dev environment). Verified 2026-11-21:
  with the fix, `flutter --version` → Flutter 3.50.1 / Dart 3.14.0.
- [planning] Emulator AVD `Pixel_9_API_36` (Android 16, Play Store image) shows as `emulator-5554`.
  Android 37 images crash on this GPU — never create or use them.
- [planning] JDK: Android Studio's JBR at `C:\Program Files\Android\Android Studio\jbr` (`JAVA_HOME`).
  `keytool` lives in its `bin` folder.
- [planning] Not installed on purpose: Docker, WSL, Node, Supabase CLI. Deno is not installed yet — phase 04
  installs it per-user (see that phase).
- [planning] GitHub CLI `gh` is logged in (account owns `Unizoy/splitify-free-forever`).

## Build and tooling

_Add entries here._

## Backend (Supabase)

_Add entries here._

## Testing

_Add entries here._

## UI

_Add entries here._
