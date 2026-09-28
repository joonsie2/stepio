# step.io

A walking game for iOS and Android built with Godot. Real-world steps are the main input.

## Playable prototype

The app opens on the **Walk** screen:

- Your avatar walks through a park with your starter pal, Sprout, following behind. All art is placeholder shapes drawn in code.
- The top bar shows your Stepcoins, today's steps (the same number as the Health app) and your step multiplier. Tap the multiplier for the breakdown: base 1.00, Sprout +0.05 as a Common pal, and +0.01 per friendship level.
- New steps are read when the app opens, when it comes back to the front, and every 30 seconds while it is open. They pour in as stepscore (steps x multiplier) with a count-up, and the progress bar shows the next milestone of the monthly track.
- Sprout's friendship level rises with the steps you walk together, so the multiplier creeps up as you walk.
- Shop, Collection, Goals and Friends are placeholder tabs. Switch tabs with the bottom bar or by swiping sideways.
- The **Me** button opens the profile: steps counted so far, the step source, the old step reading test screen, and **Reset prototype save**.

Scoring rules, as in the design doc: stepscore = new steps x multiplier, rounded down; the multiplier caps at 3.00x; steps typed into the Health app by hand never count; at most 40,000 steps count per day. On first launch the prototype counts the steps you already walked today, but nothing from earlier days. Each sync re-reads whole days (up to the last 7) and only counts what is new, so steps a watch uploads late still count.

Progress is saved on the phone in `user://save.json`. The real game will keep it on a server (design doc §11.4). Stepcoins stay at 0 for now.

On a desktop the game uses fake steps and shows a **Walk 500 test steps** button.

| Path | What it is |
|---|---|
| `game/main.gd` | Top bar, five tabs, bottom bar, swipe, popups |
| `game/walk/` | Walk screen and its placeholder art |
| `game/game_state.gd` | Autoload `GameState`: party, stepscore, multiplier, save file |
| `game/step_sync.gd` | Autoload `StepSync`: permission and step syncing |
| `game/content.gd` | Placeholder content: the pal, bonuses, milestones |
| `tests/test_scoring.gd` | Scoring checks, run by CI: `godot --headless -s res://tests/test_scoring.gd` |

### Run it on your iPhone

The iOS steps are the same as for the step reading test (see [iOS](#ios) below); the bundle identifier and export preset have not changed, so a Mac that already built the step test only needs:

1. `git pull` on this branch, then open the project in Godot 4.7.2 and let it import.
2. Project > Export > iOS > Export Project, to `build/ios/` as before.
3. Open `build/ios/stepio-steptest.xcodeproj` in Xcode, select your iPhone and press Run.
4. The first time, tap **Allow step access** on the Walk screen if the step test never asked on this phone.

To try it without a phone, press Play in the Godot editor.

## Step reading test

The step reading test is a one-screen app that proves step counts can be read from Apple HealthKit and Google Health Connect, which the design doc flagged as the biggest technical risk. It is still in the app: tap **Me**, then **Step reading test**.

### What the test app does

- Asks for permission to read steps.
- Shows today's steps, refreshed every 30 seconds and whenever the app comes back to the front.
- Shows each of the last 7 days.
- Shows every number twice: the platform total, and the total without manually entered steps (the design doc says typed-in steps must not count).
- Logs how long each read took.

On a desktop (the Godot editor) it uses fake steps so the screen can be worked on without a phone.

### How the step reading works

Godot has no official HealthKit or Health Connect support, and the community plugins found were either iOS only and tied to an old Godot build, or read the raw Android step sensor instead of Health Connect. So this project has two small native parts that expose the same API to GDScript as the engine singleton `StepioHealth`:

| Platform | Native part | Source |
|---|---|---|
| Android | Godot Android plugin (AAR, Kotlin) using Health Connect 1.1.0 | `android/plugin` |
| iOS | GDExtension (Objective-C++) using HealthKit | `ios/src` |

`steps/step_reader.gd` (autoload `StepReader`) wraps the singleton and falls back to fake steps on desktop. `addons/stepio_health` adds the native parts, the Android dependencies and the iOS HealthKit settings to exports.

API, the same on both platforms:

| Method | Result |
|---|---|
| `get_status()` | `"available"`, `"update_required"` (Android: Health Connect needs installing or updating) or `"unsupported"` |
| `check_permission()` | signal `permission_result(granted, message)` |
| `request_permission()` | signal `permission_result(granted, message)` |
| `query_steps(start_unix, end_unix, request_id)` | signal `steps_result(request_id, total, excluding_manual, error)` |
| `open_settings()` | opens Health Connect, or the Health app on iOS |

## Getting a build

Every push and pull request runs `.github/workflows/build.yml`, which:

- builds the Android plugin and exports a debug APK (artifact `stepio-steptest-android`);
- builds the iOS GDExtension (artifact `stepio-health-ios-libs`) and compiles the whole exported Xcode project without signing, to catch build errors.

### Android

Needs an Android phone with Android 8 or newer. Android 14 and newer have Health Connect built in; older versions need the Health Connect app from the Play Store (the test app offers a button for it).

1. Open the latest workflow run on GitHub (Actions tab, "Build") and download `stepio-steptest-android`.
2. Unzip it and install the APK: copy it to the phone and open it (allow installs from unknown sources), or run `adb install stepio-steptest.apk`.
3. Open "step.io", tap **Allow step access** and allow Steps.
4. Walk a bit. Steps usually reach Health Connect only when another app writes them there (Google Fit, Samsung Health, Fitbit, or the phone's built-in step tracking on Android 14+). If the number stays at 0, check that one of those apps is set to share steps with Health Connect.

To build it yourself instead: install Godot 4.7.2 with Android export templates and set up Android export ([Godot docs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)), run `./gradlew copyAarsToAddon` in `android/plugin`, then export the "Android" preset from the editor (Project > Install Android Build Template first).

### iOS

Needs a Mac with Xcode, an iPhone, and an Apple developer account (a free one works for a week-long install on your own phone). HealthKit does not work in the iOS Simulator for real steps.

1. Download `stepio-health-ios-libs` from the latest workflow run and put the two `.dylib` files in `addons/stepio_health/bin/ios/`. Or build them yourself:
   ```sh
   cd ios
   git clone -b godot-4.5-stable --depth 1 https://github.com/godotengine/godot-cpp
   pip3 install scons
   scons platform=ios arch=arm64 target=template_debug
   scons platform=ios arch=arm64 target=template_release
   ```
2. Open the project in Godot 4.7.2 (with iOS export templates), go to Project > Export > iOS and fill in **App Store Team ID** (find it at developer.apple.com under Membership). Change the bundle identifier if `io.stepio.steptest` is taken for your account.
3. Export. This writes an Xcode project to `build/ios/`.
4. Open `build/ios/stepio-steptest.xcodeproj`, select your iPhone, check that Signing & Capabilities shows HealthKit, and press Run.
5. Tap **Allow step access** and turn on Steps.

iOS never tells an app whether the player allowed reading steps; a refusal just looks like 0 steps. If you see 0, check Settings > Health > Data Access & Devices > step.io.

## What to check on each phone

- Today's number matches the Health app / Health Connect for today (within a few steps).
- Yesterday and earlier days match too.
- The number rises after a walk, when you switch back to the app.
- Whether "without manual entries" differs, and by how much. On Android this second number adds up the raw records, so it can be higher than the total when a watch and the phone both recorded the same walk. That is a useful finding, not a bug in the app.
- How long reads take (the log).

Opening the project in the desktop editor prints a `No GDExtension library found for current OS` error. That is expected: the iOS native part has no desktop build.
