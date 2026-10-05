# Freeze Frame

A native portrait Android rescue puzzle game. Freeze a disaster, move one object, and resume to save the courier. Includes 12 levels across courtyard, workshop and rooftop chapters, generated cartoon artwork, local progress, hints, settings, original sound, and vibration on Android.

[Download Android debug APK](https://github.com/Deepak9305/hypercasual/raw/refs/heads/main/build/FreezeFrame-debug.apk) · [Continuation notes](HANDOFF.md)

<img src="docs/screenshots/gameplay.png" alt="Freeze Frame playable cartoon game" width="300">

## Play

- Android: copy `build/FreezeFrame-debug.apk` to a phone and open it to install. This is a debug-signed ARM64 build, requiring Android 7.0 / API 24 or newer. Android may request permission for your file manager to install this app.
- Windows desktop: run `powershell -ExecutionPolicy Bypass -File .\Play.ps1`, or open `project.godot` in Godot 4.7.2 and press F6/F5 to run the game.
- Mouse and touch are supported. Desktop shortcuts: Space for Start / Freeze / Resume, R to retry, H for hints, Escape for pause.

## Controls

Start the scene, then freeze before the hazard reaches the courier. Levels 1–2 freeze automatically. Drag a prop card into the scene, or select a card and place it with a click. Umbrellas can be placed overhead; ramps and springs snap to the floor. An outlined ghost previews placement. Overlaps are rejected and preserve the last placed prop. You may replace your chosen object before resuming; only one prop is active per attempt.

Resume lets the physical scene continue from its frozen velocities. A rescue unlocks the next level. Hints first explain the danger, then reveal the authored solution location. Failed attempts can be retried immediately. A FREEZE NOW cue helps with manual timing after the two tutorial levels. Chapters introduce umbrella, ramp, and spring solutions before combining stationary obstacles, staggered hazards, wind, and moving platforms. The courier has speed-linked stride motion, airborne lean, landing squash, and a celebration hop; short BONK / WHOOSH / BOING callouts explain successful physical interactions. Progress and audio/haptic settings are stored locally in Godot's app data folder. There are no accounts, ads, network permissions, or gameplay servers.

## Develop and build

Use Godot 4.7.2 with GDScript and the Compatibility renderer. Android export needs matching templates, the SDK, and OpenJDK 17 or later. On another machine, install matching export templates and configure Java SDK / Android SDK paths under Editor Settings > Export > Android. The Android preset uses your locally configured Godot debug keystore; no machine-specific key path is committed.

```powershell
powershell -ExecutionPolicy Bypass -File .\Test.ps1
powershell -ExecutionPolicy Bypass -File .\Test.ps1 -Visual
powershell -ExecutionPolicy Bypass -File .\Build-Android.ps1
```

Linux / cloud commands (Godot 4.7.2 must be on PATH):

```bash
godot --headless --editor --path . --import
godot --headless --path . --scene tests/runner.tscn --fixed-fps 60 -- --test
godot --path . --resolution 390x844 --audio-driver Dummy --max-fps 60 --scene tests/visual_runner.tscn -- --test
godot --headless --path . --export-debug Android build/FreezeFrame-debug.apk
```

Rendered tests need an X11 display. Cloud startup instructions activate the matching engine, writable app/cache directories, SDK, and a dummy Xorg display. Android export was verified with API 36 build tools, matching Godot templates, and OpenJDK 21. No Gradle build is needed for this project.

The standard Godot Android export template supplies minimum API 24 and target API 36. The APK package is `com.freezeframe.rescue`, version `0.2.0` (version code 2). Release signing and store publication are separate from this debug build. The rebuilt APK uses a different local debug certificate from the original Windows build. Android will reject an in-place update signed with the old key: back up any progress you need before uninstalling the old debug app and installing this one. No signing key is committed.

## Project layout

- `scripts/levels.gd` authors 12 `LevelDefinition` resources. Adjust motion, timing, hazards, hints and solution placements here.
- `scripts/world.gd` owns the fixed-step scene, collision rules, freeze state, prop placement and effects. `scripts/actor.gd` supplies physics-driven hazards.
- `scripts/main.gd` owns native menus, touch/mouse input, safe-area fitting, hints and results. `save_data.gd` and `sound.gd` are autoload services.
- `assets/art` contains project-owned raster artwork and generation manifests; `docs` retains all three original visual directions.
- `tools/make_audio.py` regenerates the nine original synthesized WAV files without third-party samples.
- `tests` covers solutions and wrong placements, freeze/retry invariants, touch, pause, persistence, and rendered pointer interaction.
- `build` contains the APK, captured screenshots, test reports and build logs. It is excluded from game resource import.

## Verification and limits

All 12 authored solutions and incorrect-placement cases are exercised through Godot's physics engine. Rendered tests click actual native UI controls, drag a prop, complete a rescue, exercise failure/retry, pause/settings and replay. See `build/test_results.json`, `build/visual_test_results.json`, and `design-qa.md` for final results and evidence.

The latest verified reports are committed under `docs/verification`: 196 physics/state assertions and 29 rendered interface assertions passed on Godot 4.7.2. Desktop rendering measured approximately 60 FPS on Linux with Mesa software OpenGL at a 390×844 window / 780×1688 logical viewport. Both suites exit without leaked-object or retained-resource warnings, including the real game exit path with music enabled.

Desktop Compatibility rendering is measured separately from Android. No Android device or emulator is connected; installation, real-device safe areas, haptics, audio focus, battery use and Android frame rate remain unverified. This is a playable debug build; retention, level difficulty and viral appeal need player testing.

## Assets and licenses

Game illustration, character poses, props, hazards, launcher artwork and logo were generated with the built-in image-generation tool using the selected Cartoon Catastrophe mockup. Each `*_manifest.json` records exact prompts, reference inputs, source image paths, final paths and asset processing. UI labels remain native editable controls.

Lilita One and Bangers fonts are distributed under SIL Open Font License; license files are in `assets/fonts`. Pause, hint and retry icons are unmodified Phosphor Icons assets, under the MIT license in `assets/icons/LICENSE.txt`. Audio was synthesized locally for this project. Godot is distributed under the MIT license; see https://godotengine.org/license/.

