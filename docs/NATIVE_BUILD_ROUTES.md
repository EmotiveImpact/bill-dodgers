# Native build routes

## Current follow-up

The inspection below records the initial build environment. Since then, the
Godot project has been saved on the `mobile/godot-foundation` GitHub branch,
without changing `main` or its deployment. Official 4.6.3 Web export templates
were obtained and a separate single-threaded Godot browser export now succeeds.
See [the Web demo guide](GODOT_WEB_DEMO.md). These updates do not supply the
missing Android SDK/full JDK, Xcode/signing setup or physical-device acceptance.

## Original inspection

Read-only investigation on 2026-11-09. No software was installed, credentials inspected, workflow dispatched, source pushed, or release submitted. This report is the only file added by the investigation.

## Finding

There is no verified installable Android or iPhone build route already configured for this repository. The existing cloud can run Godot and package game resources, but needs Android build prerequisites. The registered Mac Mini is offline; its Xcode and signing setup could not be inspected. An Android test APK is a separate, earlier milestone than either store release.

## Evidence

- Local branch: `mobile/godot-foundation`. No `.github` workflow, Fastlane, Bitrise, Codemagic, or Jenkins configuration was found in the checkout.
- GitHub's [branch list](https://api.github.com/repos/EmotiveImpact/bill-dodgers/branches?per_page=100) returned only `main`, at `6f9e9941f553d8ae03795d45eb4a6edb5599be0f`. The native branch has not been published there.
- GitHub's [workflow run list](https://api.github.com/repos/EmotiveImpact/bill-dodgers/actions/runs?per_page=10) returned `total_count: 0`. The [repository root](https://api.github.com/repos/EmotiveImpact/bill-dodgers/contents) contains no `.github` directory or native project. The [release list](https://api.github.com/repos/EmotiveImpact/bill-dodgers/releases?per_page=10) is empty. There is no existing run or release artifact identified to download.
- The remote main commit's combined status contains only successful `Vercel`. `vercel.json` builds `node scripts/build-web.mjs` into `dist`; this is web deployment, not native packaging. README documents deployment on pushes to main, so that route must remain untouched.
- Current machine: Linux x86_64, Godot `4.6.3.stable.official.7d41c59c4`, OpenJDK Java runtime `21.0.13`, and `keytool`. No `javac`, `jar`, `jarsigner`, `adb`, `sdkmanager`, `aapt`, `aapt2`, `apksigner`, `zipalign`, `gradle`, `xcodebuild`, Docker, or Podman executable was found on PATH.
- Standard SDK/JDK/tool locations and bounded searches in `/opt`, `/usr`, `/tmp`, the task workspace, and shared workspace found no usable Android SDK or full JDK. Discovered Godot export-template folders were empty. `/opt/godot/4.6.3` contains the editor binary and icon, not templates. No matching template or SDK installer archive was found in the checked cache/workspace locations.
- Environment catalog returned the cloud connected and `Augustuss-Mac-mini.local` offline, with no other machine listed. No attachment or machine change was attempted.

## Android test build: smallest practical next step

Use the current cloud or an already-equipped computer after authorizing any needed official software installation. The existing preset already targets a debug-playtest APK, ARM64 only, package `io.ourcommune.billdodgers.preview`, and disables Internet permission. It uses standard export templates, with Gradle custom builds disabled. This avoids introducing a new CI service merely to obtain the first test build.

1. Install the exact Godot 4.6.3 export templates and a supported full JDK. Godot recommends JDK 17; later JDKs are supported, so Java 21's version is not itself the blocker. This machine lacks the full toolchain.
2. Install/configure Google's Android SDK and required packages. Godot 4.6 documents Platform Tools 35+, Build Tools 35.0.1, Platform 35 and current command-line tools; its complete documented setup also lists NDK 28.1.13356709 and CMake 3.10.2.4988404. Use official sources, review applicable SDK terms, and set Godot's Java/Android SDK paths. These are build-tool versions, not a claim about current Play submission target requirements.
3. Configure an authorized development signing setup without putting keys or passwords in Git. No existing key material was opened during this inspection.
4. Export the `Android Native Preview` preset, verify the resulting APK and its signature, then install and test it on an ARM64 Android phone. A successful PCK test does not substitute for this step.

Reference: [Godot 4.6 Android export setup](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html). Android requires APK signing; a development certificate is suitable for testing, not store publication. [Android signing](https://developer.android.com/studio/publish/app-signing). Device debugging/pairing and any security-setting changes require their own approved setup; no device is currently verified. [Android device testing](https://developer.android.com/studio/run/device).

## iPhone build

Reconnect the existing Mac first, then inspect Xcode, Godot/templates, and the user's existing Apple team before requesting new tools, accounts, or payment. Godot's supported iOS export route requires macOS with Xcode and matching export templates. The preset's Apple Team ID is empty; its `.preview` bundle ID remains provisional. The currently configured Linux workspace cannot finish that supported route. [Godot 4.6 iOS export setup](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_ios.html).

An existing Apple account may permit Xcode Personal Team testing on the owner's iPhone without paid membership, subject to its limitations and seven-day provisioning. TestFlight/App Store distribution instead needs the appropriate developer-program team and distribution setup. Existing membership is unknown, not assumed absent. No sign-in, certificate creation, provisioning or account change was attempted. [Apple developer account options](https://developer.apple.com/help/account/basics/about-your-developer-account).

## CI alternative

A new Android/Linux and iOS/macOS CI workflow could be designed, but none is ready to run. It would require permission to publish the native source/workflow, check provider entitlement and costs, and configure any signing access securely. Existing GitHub repository access is not permission to push, dispatch, create credentials, or deploy. A public repository's build artifacts must not be treated as a private beta distribution channel without an explicit access decision.

## Test build versus release

- **Private phone test:** produce an installable development build and check real graphics, multitouch, interruptions, saves, performance, memory, heat and loading. This can happen before full-game completion.
- **Store release:** complete the intended content and gameplay acceptance; settle final app identity, rights/notices, privacy/rating and access/payment model; prepare release signing and distribution accounts; satisfy current Apple/Google submission requirements; obtain publication authorization and pass review. Google Play uses an AAB/release-signing route, not this debug APK preset.

There is no evidence-based calendar release date yet. The immediate decision is whether to authorize official Android toolchain setup and reconnect the Mac for an existing-setup check, while content and QA work continues.
