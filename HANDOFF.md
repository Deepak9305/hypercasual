# Continue Freeze Frame

## Current project

- Godot 4.7.2, GDScript, Compatibility renderer; preserve the selected Cartoon Catastrophe reference in `assets/art/selected_reference.png` and the existing project.
- Twelve rescue puzzles across three chapters, local progress, hints, settings, audio/haptics, mouse/touch, and Android safe-area fitting.
- Version 0.2.0 / code 2; debug APK in `build/FreezeFrame-debug.apk`, ARM64, package `com.freezeframe.rescue`, minimum API 24, target API 36. VIBRATE is the only requested permission; no network gameplay or servers.
- Authored tools: five umbrella, three ramp, four spring solutions. Level 4 introduces the spring against a sliding branch; level 7 combines a stationary sculpture and delayed trolley with a faster courier; level 11 redirects two staggered rolling hazards with one ramp. The gap and final awning puzzles remain intact.
- Animation reuses the original illustrated poses: speed-linked stride, airborne lean/stretch, landing squash/particles, and celebration hop. Frozen and paused poses remain still. BONK / WHOOSH / BOING callouts and a manual FREEZE NOW cue add feedback without changing collision shapes or touch coordinates.
- Hint panels own their expiration timers. Replacing a hint removes the whole old panel. Results use a cancellable child timer, survive a pause overlay, and cannot appear in a new attempt after retry/home navigation.
- Audio shutdown stops players and releases streams before quitting. The original verbose leak was `ambient.wav` plus `AudioStreamPlaybackWAV`; both suites now exit cleanly, including the real game exit flow with music enabled.

## Verified on 2026-10-05

- 196 physics/state assertions: every authored solution, legal wrong placements, freeze/retry invariants, touch, pause/Back, persistence, delayed results, toast cleanup, animation freeze, audio release, and ±12 logical pixel placement tolerance on the three revised puzzles.
- 29 rendered assertions: original UI flows plus real manual Freeze / drag / Resume rescues for levels 4, 7, and 11. Both hazards in level 11 are deflected by the same ramp.
- Approximately 60 FPS for the title scene at 390×844 physical / 780×1688 logical resolution on Linux Mesa software OpenGL. This is not an Android performance measurement.
- Godot Android export, APK alignment, v2/v3 signature verification, package/version/API/ARM64/permissions checks passed using API 36 tools, matching templates, and OpenJDK 21.
- `adb devices -l` lists no targets. No installed emulator or `/dev/kvm` is available. Android installation, safe areas, touch, backgrounding, haptics, sound, and frame rate remain unverified on-device.
- Current reports and build/signature evidence are in `docs/verification`; fresh screenshots, including the revised puzzles and jump/impact feedback, are in `docs/screenshots`.

## Run and export

Read `README.md` for PowerShell and Linux commands. In the cloud environment, first source `/workspace/.cloud-setup/hypercasual/env.sh`; use the existing checkout at `/workspace/hypercasual`. The saved startup instructions describe the Xorg display needed for rendered tests. Other machines need Godot 4.7.2, matching Android templates, a local debug keystore, and SDK/Java paths set in Godot Editor Settings.

The preset now uses the local editor debug-keystore default. The new cloud debug certificate differs from the original Windows APK's certificate, so an old installed debug build must be uninstalled before installing this APK, which removes its local progress. Keep signing keys outside Git. Release signing and store publication need a separate request.

## Next work

1. Connect a real Android ARM64 phone or a compatible emulator and test installation, portrait/cutout layout, dragging, Back/background/resume, persistence, sound/vibration, and sustained frame rate. Record actual observations; desktop checks do not establish these.
2. Run player sessions to assess the new spring introduction, faster level 7, and later shared-ramp puzzle. Tune difficulty from player evidence; passing solutions do not prove retention or accessibility.
3. Further animation frames or content should retain the existing courier identity and cartoon reference. Record generation prompts/provenance if new artwork is created.

Do not add ads, accounts, purchases, analytics, release keys, or store publication without a separate request.
