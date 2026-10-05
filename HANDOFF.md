# Continue Freeze Frame

## Current project

- Repository: https://github.com/Deepak9305/hypercasual
- Native portrait Android game in Godot 4.7.2, GDScript, Compatibility renderer.
- 12 authored rescue puzzles in three chapters. Freeze, choose/reposition one prop, resume, physical collision outcome, hints, retry, unlocks and local progress all work.
- User selected Cartoon Catastrophe. Preserve `assets/art/selected_reference.png` as the visual truth, not either of the other two concepts.
- Generated backgrounds, worried/walking/happy courier poses, three props, six hazard types, platform/gap, brand logo and launcher assets are in `assets/art`. Manifests contain exact prompts and source provenance.
- Live UI includes title, level select, pause/settings, result screens, touch/mouse control, safe-area fitting, licensed icons/fonts and original synthesized audio.
- `build/FreezeFrame-debug.apk` is a debug-signed ARM64 Android APK. Package `com.freezeframe.rescue`, version 0.1.0, minimum API24 / Android7, target API36. Permission: VIBRATE; no internet permission.

## Verified baseline

- 175 automated physics/state assertions passed, including every authored solution and every deliberately incorrect placement.
- 16 rendered native-UI assertions passed, including real pointer clicks, drag/drop, rescue, failure/retry, pause/settings, level locks and replay.
- Desktop Compatibility/ANGLE render measured approximately 60 FPS at 390×844 physical / 780×1688 logical viewport.
- `docs/verification/` retains the passing JSON reports. `docs/screenshots/` retains real rendered screenshots and side-by-side visual evidence. `design-qa.md` records fixed layout/layering issues and known differences.
- APK export and signature verification passed.

## What to work on next

1. Test the APK on a real Android phone or an available emulator. Verify installation, portrait/safe-area layouts, drag/drop, background/resume, Android Back, saved progress, sound/vibration and sustained frame rate. Android hardware behavior is not yet verified.
2. Investigate the occasional Godot resource-retention warning at rendered-test shutdown with verbose logging. Check delayed result/toast callbacks, exit cleanup and menu transitions; keep the currently passing gameplay behavior.
3. Add richer courier animation and carefully tuned feedback while retaining the exact chosen cartoon style. Use built-in image generation with the selected reference for new raster artwork; preserve source assets and prompts.
4. Improve puzzle variety and progressive difficulty. Several vertical-hazard levels currently share similar umbrella solutions. Keep 12 coherent levels, with authored solutions and meaningful wrong-placement cases; add further content only after this baseline feels good.
5. Run player sessions before claiming retention or viral success. Tune onboarding, hint timing, failure clarity and replay incentives from observations. No analytics, ads, accounts or purchases are currently implemented.

## Commands

```powershell
powershell -ExecutionPolicy Bypass -File .\Play.ps1
powershell -ExecutionPolicy Bypass -File .\Test.ps1
powershell -ExecutionPolicy Bypass -File .\Test.ps1 -Visual
powershell -ExecutionPolicy Bypass -File .\Build-Android.ps1
```

On another machine, install Godot 4.7.2 with matching export templates and configure Android SDK/OpenJDK17 in Godot Editor Settings. The helper scripts fall back to `godot` on PATH. Update only the local debug-keystore path in the export preset as needed. Never commit a release signing key or credentials.

## Copy-paste continuation prompt

Continue Freeze Frame in https://github.com/Deepak9305/hypercasual. Read README.md, HANDOFF.md, design-qa.md and the verification reports first. Preserve the existing Godot 4.7.2 Android project and the selected Cartoon Catastrophe aesthetic in assets/art/selected_reference.png; do not restart or redesign it. The 12-level game, generated assets, debug APK, local progress, hints, sound/haptics and touch/mouse controls are implemented; 175 physics/state checks and 16 rendered interaction checks passed, with approximately 60 FPS measured on desktop. First verify the APK on an available Android device or emulator and fix any concrete issues; clearly report unavailable device checks. Investigate the occasional resource-retention warning at rendered-test shutdown, then improve courier animation, feedback and puzzle variety while preserving the tested freeze/placement/resume rules. Keep new artwork consistent with the selected reference and record generation prompts. Run the relevant tests, update screenshots and verification notes, rebuild the debug APK, and commit and push the improvements. Do not add ads, accounts, payments or publish to an app store without a separate request.

