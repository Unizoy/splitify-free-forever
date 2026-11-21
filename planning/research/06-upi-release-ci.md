# 06 - UPI, release, CI, emulator automation (research, 2026-11-21)

Tags: [V] = verified from a fetched/searched source this session; [E] = verified by running on the emulator (API 36); [UNVERIFIED] = from memory or thin sources.

## 1. UPI deep link

### Parameters (NPCI Linking Spec v1.6 draft, 2017; still the de-facto spec) [V]
Spec copies: https://www.labnol.org/files/linking.pdf , https://studylib.net/doc/27265723/upi.linking.specs-ver-1.6 . NPCI circular 37 (1.11.2017) says all PSP apps must honour the spec: https://www.npci.org.in/PDF/npci/upi/circular/2017/Circular%20on%20Non-compliance%20of%20UPI%20apps%20to%20Deeplinking%20specs%20Circular%2037-%201.11.2017.pdf
- `pa` payee VPA (required). `pn` payee name (required). `am` amount, decimal rupees "100.50" (optional for static, required for dynamic). `cu` currency, only `INR`. `tn` note (optional). `tr` txn ref id, up to 35 chars (required for dynamic/merchant; optional for P2P). `mc` merchant category code (merchant only; omit for P2P). `mode` initiation mode (merchant stack, e.g. 04 intent) - skip. Others: `url`, `tid`, `mam` (min amount), `orgid`, `sign` (signed links, merchants only) - skip.
- Amount format: plain decimal, max 2 decimals, no commas, no currency symbol. Our Dart: `(paise/100).toStringAsFixed(2)` is acceptable ONLY for formatting an integer via integer division: build string as `${p ~/ 100}.${(p % 100).toString().padLeft(2,'0')}` (no floats, rule 1).
- URL-encode `pn` and `tn` with `Uri.encodeComponent` (spaces as %20, not +). Keep `tn` short (<= ~50 chars; apps truncate; spec says 50?) [UNVERIFIED limit]. Avoid `&`, `#`, emoji in names; strip non-ASCII from `pn`/`tn` to be safe.
- Spec says apps must not trust `am` in static mode and user may edit amount; do NOT rely on the amount being locked. Our rule 13: record payment only on "Mark as paid", which fits.

### 2024-2026 reality
- NPCI circular 29 Jul 2025: UPI P2P collect requests disallowed from 1 Oct 2025 [V]: https://www.businesstoday.in/personal-finance/banking/story/npci-to-tighten-upi-rules-peer-to-peer-collect-feature-to-end-in-october-489244-2025-08-13 , https://yourstory.com/2025/08/npci-to-ends-p2p-collect-requests-on-upi-by-october-amid-fraud-concerns . Merchant collect stays; send-money, QR and contact pay unaffected. This kills "request money via VPA" but NOT push-pay intents (`upi://pay`), which the payer approves with PIN. Consequence: Splitify must never try "collect"; only intent/QR (our design already does).
- Intent flow is the supported path for merchants (Cashfree/Razorpay docs say intent+QR are the surviving flows) [V]: https://www.cashfree.com/docs/payments/manage/payment-methods/upi-collect
- Personal-VPA intents: no official NPCI/Google statement found. Community reports: some apps show warnings/limits for link-initiated payments to non-merchant VPAs; "declined for security reasons"/"limit exceeded" errors on GPay/PhonePe when a merchant-less link with `am` is used; sometimes a bad amount encoding triggers a false "limit exceeded" [V as reports, anecdotal]: https://www.technetexperts.com/fix-upi-limit-exceeded-error/ , https://dev.to/srvmhptr/how-upi-deep-links-work-upipay-build-a-payment-link-and-qr-code-without-a-payment-gateway-g8m , https://kiwix.lema.org/stackoverflow.com_en_all_2023-11/questions/64573022/upi-deep-link-payment-declined . Known historically (stackoverflow): GPay rejects `upi://pay` to personal VPAs in some versions with "can't process, bank limit/security", and GPay may ignore/disable prefilled amount above ~Rs 2000 for P2P links [UNVERIFIED; unfixable from our side]. PhonePe/Paytm/BHIM/CRED generally open with VPA+amount prefilled [UNVERIFIED]. Spec says compliance varies by app: https://medium.com/@thinksantosh/upi-deep-linking-specification-app-developers-mustnt-expect-consistency-of-implementation-across-90b919e077cb
- Bank/PSP caps still apply: Rs 1 lakh/day, 20 txns/day, new-user Rs 5000 first 24h [V, secondary]. We cannot detect failure: the intent result is unreliable (GPay often returns nothing).
- Conclusion: treat UPI launch as best-effort convenience, not a guaranteed pay. Cannot be validated without a real phone + real accounts; list as a manual test item for a friend's phone before v1 claims it works.

### Recommended UX (robust)
1. Button "Pay Rs X via UPI" shown only if currency == INR and payee has a VPA.
2. Build link (above), `launchUrl(mode: externalNonBrowserApplication)`. Android shows the system chooser of UPI apps. If it returns false/throws (no UPI app) -> bottom sheet fallback.
3. Fallback sheet always available: show VPA + amount + note with "Copy UPI ID", "Copy amount", "Share", and a QR of the same link (payer scans from another app/phone). Text: "If your app says payment failed, paste the UPI ID and amount in your UPI app manually."
4. After returning to app: dialog "Did you pay?" -> "Mark as paid" / "Not yet". Never auto-record (rule 13), because returned status is unreliable.
5. Tell users the amount may be editable/ignored by their UPI app; show recorded amount in our own screen.
6. Hide button for non-INR; never convert.

### Flutter/Android implementation
- `url_launcher` (6.x): `launchUrl(Uri.parse(link), mode: LaunchMode.externalNonBrowserApplication)`. Simple, enough. `canLaunchUrl` for `upi` needs the manifest `<queries>` entry on Android 11+ or returns false. Do not rely on canLaunchUrl; just try launch and catch.
- `android_intent_plus`: needed only if we want `Intent.createChooser` with a custom title, or to target a package (`com.google.android.apps.nbu.paisa.user`, `com.phonepe.app`, `net.one97.paytm`, `in.org.npci.upiapp` = BHIM). Not required. Skip unless chooser behaviour is bad. (No result-returning API either; both are fire-and-forget. `upi_pay`/`upi_india` packages return status but are poorly maintained and status is unreliable - avoid.) [UNVERIFIED maintenance state]
- AndroidManifest (app) outside `<application>`:
```xml
<queries>
  <intent>
    <action android:name="android.intent.action.VIEW"/>
    <data android:scheme="upi" android:host="pay"/>
  </intent>
</queries>
```
  (Flutter template already has a `<queries>` for PROCESS_TEXT; add to it.)
- VPA regex (practical): `^[a-zA-Z0-9][a-zA-Z0-9._-]{1,255}@[a-zA-Z][a-zA-Z0-9]{1,63}$`. Handle: trim, lowercase handle part, reject spaces. Real handles: `name@okicici`, `9876543210@ybl`, `x@paytm`, `x@upi`. Warn (not block) on unknown handle; can't verify existence offline.
- Parse UPI QR: QR content is the same URI string `upi://pay?pa=..&pn=..&...`. `final u = Uri.parse(s); if (u.scheme=='upi' && u.host=='pay') { pa = u.queryParameters['pa']; pn = u.queryParameters['pn']; }`. Ignore `am`/`tr`/`mc` from a scanned merchant QR when importing a person's VPA; if `mc` present and non-0000 warn "looks like a shop". Scan with `mobile_scanner` (Flutter) [UNVERIFIED version]; image-from-gallery decode also supported there.

## 2. Testing UPI on the emulator: fake UPI handler
Tiny separate debug-only Android app (not in main app): one Activity, package `dev.splitify.fakeupi`, installed with `adb install`. It shows the received URI and logs `Log.i("FakeUPI", data)`, optionally returns result `Activity.RESULT_OK` with extras `txnId, responseCode=00, Status=SUCCESS` (use `setResult`) to simulate success/failure/cancel.
Manifest:
```xml
<activity android:name=".PayActivity" android:exported="true">
  <intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="upi" android:host="pay"/>
  </intent-filter>
</activity>
```
Test: `adb logcat -s FakeUPI` then tap Pay in Splitify; or direct `adb shell am start -a android.intent.action.VIEW -d "upi://pay?pa=a@b\&pn=X\&am=10.00\&cu=INR"` (escape & ; in Git Bash prefer quoting with single quotes). With no handler installed, same command yields "unable to resolve Intent" -> test the no-app fallback. Install two copies with different labels to test the chooser. `dumpsys package resolve-activity` / `cmd package query-activities -a android.intent.action.VIEW -d upi://pay?pa=a@b` confirms resolution [E: resolve-activity runs]. Proves our URI building/encoding and fallback only; says nothing about real GPay/PhonePe acceptance.

## 3. Android developer verification (Google)
Primary: https://developer.android.com/developer-verification [V], blog https://android-developers.googleblog.com/2026/06/android-developer-verification.html [V].
- Effective 30 Sep 2026: enforced for installs on certified Android devices (Android 8/API 26+) in Brazil, Indonesia, Singapore, Thailand only. Unregistered package names there no longer installable (limited-distribution page). "Global rollout in 2027 and beyond"; India not named, no date [V]. Expect India sometime 2027; plan for it.
- What it means: an APK must come from a registered package name + signing key tied to a verified developer. Unregistered apps can still be installed via (a) `adb install`, (b) the "advanced flow" for power users (one-time setup with security checkpoints; launched Aug 2026) [V]. So not a ban, but friction for our testers.
- Options for us:
  1. Android Developer Console account, "distribute exclusively outside Google Play" (https://developer.android.com/developer-verification/guides/android-developer-console.md.txt): identity verification; fees/ID rules per account type - details not fetched [UNVERIFIED fee; check FAQ].
  2. Limited distribution account (free, no government ID, Google account + 2SV + payments profile): register apps, share with limited devices (page says up to 50 devices authorised via QR/link; Google's landing page says 20 - inconsistent, check) [V]: https://developer.android.com/developer-verification/guides/limited-distribution.md.txt . Fine for friends/testers, NOT for a public open-source release.
  3. For public release: full console account, register package name + SHA-256 of our release key (add key by fingerprint; no APK upload for a new app; existing apps with >=50 installs may need an `adi-registration.properties` file in `assets/` and an APK upload) [V]: https://developer.android.com/developer-verification/guides/open-source-app-registration.md.txt
- To do for open source: (1) pick final applicationId now (changing it later = new app + re-registration); (2) generate release keystore (below), record its SHA-256 in docs; (3) register package + key in Android Developer Console before India enforcement; (4) ALWAYS sign with the same key (GitHub Releases is not a re-signing store, so our key is the one registered); (5) tell users in README the SHA-256 and that if Android shows an unverified warning they can use the advanced flow. Put a "Developer verification" task in the release checklist and re-check Google's page before v1.0.0.
- Android 16 / targetSdk 36: Flutter's current template sets compile/target via `flutter.targetSdkVersion`; target 36 is fine for sideloading (target requirements are Play-only; but Android 16 behaviour changes still apply when targetSdk=36: edge-to-edge enforced, predictive back on by default, 16 KB, etc.) [UNVERIFIED details]. Test with emulator (API 36 = our Android 16).
- 16 KB page size: Play-only rule (apps with native code must support it; official page says updates blocked from 1 Feb 2027) [V]: https://developer.android.com/16kb-page-size . Not enforced for sideloaded APKs, but 16 KB devices exist (Pixel 8+ option, some Android 15/16 phones). Flutter >= 3.32 engine and AGP 8.5.1+ / NDK r28 align libs; third-party plugins with .so must also be aligned [V community]. Cheap check on each release: `zipalign -c -P 16 -v 4 app-release.apk` or Google's `check_elf_alignment.sh`; test on an Android 15+ 16 KB emulator image only if we add native-heavy plugins.

## 4. Release signing for a public repo
- Keystore lives outside repo (e.g. `C:\Users\mohit\keys\splitify-release.jks`), backed up offline (2 copies; lost key = cannot update installs, and breaks verification registration). Generate: `keytool -genkeypair -v -keystore splitify-release.jks -alias splitify -keyalg RSA -keysize 4096 -validity 10000`. Enable Play-style key unnecessary.
- `.gitignore`: `android/key.properties`, `*.jks`, `*.keystore`. Check `git status` before commit (project rule).
- `android/key.properties` (ignored):
```
storeFile=C:\\Users\\mohit\\keys\\splitify-release.jks
# store password line (name=value)
keyAlias=splitify
# key password line (name=value)
```
- `android/app/build.gradle.kts`:
```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) FileInputStream(f).use { load(it) }
}

android {
    signingConfigs {
        create("release") {
            if (keystoreProps.isNotEmpty()) {
                storeFile = file(keystoreProps["storeFile"] as String)
                // also set the store password from keystoreProps (same pattern)
                keyAlias = keystoreProps["keyAlias"] as String
                // also set the key password from keystoreProps (same pattern)
            }
        }
    }
    buildTypes {
        release {
            // fall back to debug signing only when key.properties is absent (CI / contributors)
            signingConfig = if (keystoreProps.isNotEmpty())
                signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }
}
```
  Better: make the build fail for release when no key (so you never publish a debug-signed APK) - add a Gradle check or the release script verifies with `apksigner verify --print-certs` and compares SHA-256 to the known one.
- Versions: `pubspec.yaml` `version: 1.0.0+1` -> versionName 1.0.0, versionCode 1. Increment the +N every release (monotonic integer). Tag `v1.0.0` matches versionName. `flutter build apk --release --split-per-abi` gives 3 APKs (arm64-v8a is what phones need; ship arm64 + a universal one, or just arm64-v8a plus universal).
- Release script (Git Bash/PowerShell):
```
flutter build apk --release --dart-define-from-file=env/prod.json --split-per-abi
cd build/app/outputs/flutter-apk
sha256sum *.apk > SHA256SUMS.txt        # PowerShell: Get-FileHash -Algorithm SHA256
apksigner verify --print-certs app-arm64-v8a-release.apk
gh release create v1.0.0 --draft --title "v1.0.0" --notes-file ../../../../CHANGELOG-v1.0.0.md \
  app-arm64-v8a-release.apk app-armeabi-v7a-release.apk app-x86_64-release.apk SHA256SUMS.txt
```
  Draft first, review, then publish in the GitHub UI. Rename APKs to `splitify-1.0.0-arm64-v8a.apk` before upload. Note `--dart-define-from-file` file holds only URL + publishable key (rule 15); the publishable key is embedded in the APK and thus public anyway.
- Optional GH Actions signing (only if we want CI builds): store keystore base64 as secret `KEYSTORE_B64` + 3 password secrets; step `echo $KEYSTORE_B64 | base64 -d > $RUNNER_TEMP/k.jks` and write key.properties; trigger on tag push only; never on pull_request (fork PRs get no secrets anyway). Risk: key in GitHub secrets; owner decides. Default: sign locally. 

## 5. GitHub Actions CI
- Public repos: standard GitHub-hosted runners are free and unlimited; larger runners are paid [V]: https://docs.github.com/en/actions/reference/runners/github-hosted-runners , https://docs.github.com/en/billing/concepts/product-billing/github-actions . One dev.to post claimed a pricing change 28 Oct 2026 - [UNVERIFIED], re-check billing docs.
- Pin Flutter: `subosito/flutter-action@v2` with `flutter-version: 3.50.1` (check it exists on the stable list when writing the workflow [UNVERIFIED]), `channel: stable`, `cache: true`. Pin action versions by SHA for a public repo (supply chain).
- Supabase local stack in CI: feasible. `supabase/setup-cli@v1`, `supabase start` pulls ~10 Docker images; typically 1.5-3 min on ubuntu runner with `-x studio,imgproxy,realtime...` excludes to speed up [UNVERIFIED timing]; `supabase db reset` then `supabase test db` (pgTAP). Caveat: project rule says "nothing Supabase runs locally" for dev; CI-only ephemeral stack is a deliberate exception - OR run pgTAP via a throwaway Postgres container with the migrations applied (simpler, faster) if Auth/Storage schemas are stubbed. Decide in plan; MCP-based SQL tests exist already for local dev.
- android-emulator-runner (`reactivecircus/android-emulator-runner@v2`): works on ubuntu-latest because public runners have KVM (enable via udev rule step) [UNVERIFIED current state], API 34-35 x86_64 images; API 36 image availability uncertain. Slow (8-15 min), flaky. Recommend: not in PR CI; maybe manual/nightly workflow later. Keep emulator E2E local.
- Compact sketch `.github/workflows/ci.yml`:
```yaml
name: ci
on:
  pull_request:
  push: { branches: [main] }
permissions: { contents: read }
concurrency: { group: ci-${{ github.ref }}, cancel-in-progress: true }
jobs:
  flutter:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4          # pin by SHA
      - uses: subosito/flutter-action@v2
        with: { flutter-version: 3.50.1, channel: stable, cache: true }
      - run: flutter pub get
      - run: dart format --output=none --set-exit-if-changed .
      - run: flutter analyze
      - run: flutter test --coverage      # goldens included; generate goldens on same OS as CI (Linux) or tag/skip them on Windows
      - run: flutter build apk --debug    # optional; needs a dummy env json
  sql:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: supabase/setup-cli@v1
        with: { version: latest }          # pin a version instead
      - run: supabase start -x studio,imgproxy,inbucket,edge-runtime
      - run: supabase test db
```
  Golden gotcha: golden PNGs differ between Windows and Linux font rendering; either generate/commit goldens from CI (Linux) or run goldens only locally via a tag (`@Tags(['golden'])`) and exclude in CI. Add Deno job for Edge Function tests (`denoland/setup-deno@v2`, `deno test`).

## 6. Emulator automation from Windows (API 36 emulator-5554, tested just now)
adb: `$LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe`.
- Airplane on/off [E]: `adb shell cmd connectivity airplane-mode enable` (rc 0, `settings get global airplane_mode_on` -> 1) and `... disable`. Note the setting flips but the emulator's network may stay in data; verify app behaviour via the app's own offline state, or additionally `adb shell svc wifi disable; adb shell svc data disable` [svc UNVERIFIED here].
- Screenshots without corruption [E]: use `adb exec-out screencap -p > file.png` from Git Bash (valid PNG header confirmed). In PowerShell 5.1 `>` re-encodes bytes and corrupts it; either run via Bash tool, or `adb shell screencap -p /sdcard/s.png; adb pull /sdcard/s.png`. `cmd /c "adb exec-out screencap -p > s.png"` also works.
- Fingerprint [E]: `adb -e emu finger touch 1` -> OK (finger id 1). Enroll first in Settings; biometric prompt then accepts.
- Notifications [E]: `adb shell dumpsys notification --noredact` lists records (use `| grep -A8 "pkg=<our.package>"`). Also `adb shell cmd notification` subcommands; `adb shell service call` not needed.
- uiautomator dump [E]: `adb shell uiautomator dump /sdcard/u.xml` works (prints "UI hierchary dumped"). GOTCHA in Git Bash: paths starting with `/sdcard` are rewritten to `C:/Program Files/Git/sdcard` (the dump path printed that, and `cat` failed). Fix: `MSYS_NO_PATHCONV=1 adb ...` or use `//sdcard/u.xml`, or run in PowerShell. Read with `adb exec-out cat /sdcard/u.xml` (or `adb exec-out uiautomator dump /dev/tty`). Tap by coordinates parsed from bounds: `adb shell input tap X Y`; text: `adb shell input text "abc"` (spaces as %s).
- Other handy: `adb shell am start -a android.intent.action.VIEW -d "splitify://invite/abc" <pkg>` (deep links), `adb logcat -d -s flutter`, `adb shell pm clear <pkg>`, `adb install -r app.apk`, `adb shell cmd locale`, dark mode `adb shell cmd uimode night yes`, font scale `adb shell settings put system font_scale 1.3` [last three UNVERIFIED here].
