# Current portable native checkpoint

Recorded 2026-11-09. The native source, original artwork inputs, legal notices,
setup helper and tests are version-controlled. This is a development checkpoint,
not an installable phone build, final soundtrack approval or release certificate.

## Fresh-computer proof

A source-only copy of the 885 files in local commit
`ec6b805e4cdab544604c9fbdacf9ecf3d912df62` was checked against every Git blob SHA.
It initially had **no generated assets, content JSON or Godot import cache**.
`python3 scripts/prepare-native.py --godot /usr/local/bin/godot` then completed:

- All six worlds/42 levels and original images/fonts/sprites were imported.
- All 21 source story scenes and 193 shots were extracted.
- All 22 native source sound/music fallback resources were generated.
- Godot 4.6.3 completed its first editor import without script/runtime errors.

After preparation, the isolated project passed actual runtime smoke, 566 official
selector checks and 308 campaign/story/ending checks. The smoke fixture received
the same real 1280×720 window/960×540 canvas and scroll-into-view handling as the
other GUI fixtures; Godot's 100×100 headless placeholder is not a supported mobile
viewport. This was a test setup correction, not a gameplay change.

Detailed machine-generated logs and reports are kept locally, outside the public
repository. See [validation and reproducibility](VALIDATION.md). Windows/macOS
instructions are provided, but this clean preparation proof ran on Linux with
Python 3.12, Node24 and Godot4.6.3. No network download, package installation,
game publishing or player save migration was needed.

## Current QA scope

- All 252 solo character/stage routes pass on the integrated gameplay, with the
  assistance disclosed by each driver. Current revalidation ran in segments.
  The earlier separately frozen all-solo checkpoint has an uninterrupted full
  aggregate pass; it is not substituted for the later UI work.
- All 252 stage/CPU-identity route cases have source-backed assisted evidence,
  including logged source downs/catch-ups/rescues. This is not every possible
  leader/mate combination or proof both actors survived naturally.
- Independent synthetic-key local-P2 full routes pass for 1-1, 2-1 and 2-2,
  plus seven prior W5 scripted-local-P2 routes. Physical two-human input remains
  a separate acceptance gate.
- Final frontend: 1,880 measured target/input checks, 566 selector checks,
  308 campaign completion checks, 47 map/title GUI checks, 100 mobile map checks,
  26 map checks and 187 save checks pass. The title/menu/selector keep deliberate
  map-only character changes and persistent choices between stages.
- The standalone Licenses view passes 602 checks, and verified full OFL font
  notices are bundled. Supplied-art commercial provenance remains unresolved.
- Pickup inventory/effects: 19,599 checks; W1 receipt replay: 3,680 checks.
- Audio lifecycle: 187 actual-main checks, distinguishing the painted map cue
  from the title cue. The music itself is still a replaceable prototype.
- Python source/setup/launcher checks: 49 passed before this documentation-only
  recording. Full launchers include the additional frontend/legal/local-P2 tests.

The two older aggregate UI expectations encountered during revalidation were
updated to the consolidated Menu and scrollable title. No failed assertion was
replaced by a fake gameplay clear or weakened progression condition.

## Still separate

Real Android/iPhone export and installation, signing, Safari/browser preview,
normal-health human difficulty, physical-device input/performance/audio/heat,
final art/music acceptance, Commune membership/app integration and publication.
The tested resource PCK is game data, not an APK or IPA. The isolated genuine Rive
HUD preview does not replace the native HUD and is not required to edit the game.
