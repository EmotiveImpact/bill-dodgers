# Independent native gameplay audit

Reviewed 2026-11-09 with Godot 4.6.3. This audit separates reproducible bugs
from unfinished port work. It does not certify physical-device input, difficulty,
all six worlds, or release readiness.

## Repaired defects

### Android Back was still configured to exit

**Priority: high for the mobile lifecycle.** The host explicitly handles
`NOTIFICATION_WM_GO_BACK_REQUEST` by pausing, but the live SceneTree and project
both reported `quit_on_go_back == true`. That leaves Godot's automatic Android
Back exit enabled alongside the intended game pause handler, losing the current
encounter when the application exits.

The project now sets `application/config/quit_on_go_back=false`. The regression
checks the actual SceneTree property, then dispatches the notification into the
host during gameplay and story playback. The resulting pause releases contacts,
freezes simulation, and supports real touchscreen Resume input. Story resume and
skip return to the correct previous mode.

The enabled automatic-exit setting and repaired runtime policy were verified
in-engine. An Android system Back gesture on a physical device was **not** tested.
This is not a claim that an Android build has been produced or installed.

### Dragging a held gameplay contact over the HUD retained its old action

**Priority: medium.** Reproduction with the real Godot input dispatch path:

1. Press the left movement pad using an `InputEventScreenTouch`.
2. Drag that same contact onto the Sound HUD button.
3. Before lifting, observe that `_held("left")` remains true even though the
   contact is no longer inside any gameplay pad.

Godot's GUI consumed the drag before `main.gd::_unhandled_input` could update it.
The original release event did clear the contact; this was **not** a permanently
stuck action after lifting. The failure occurred while holding over the GUI and
also applied to the real mouse fallback.

`main.gd::_input` now updates already-held contacts and clears release/cancel
events before GUI dispatch. New presses still reach GUI first. It does not
consume those events or change checkout's existing raw mash-input handling.

Regression checks demonstrate that crossing the HUD releases only the moving
finger, preserves another finger's firing action, does not activate an unpressed
HUD button, and preserves ordinary Sound button activation. Mouse motion and
release receive equivalent coverage.

## Independent regression coverage

`godot/tests/test_native_audit.gd` passes **119 checks**:

- Real touch/mouse GUI crossing, release/cancel, simultaneous contacts and HUD
  button activation through `Input.parse_input_event`, including emulation.
- Root window sizes 2340×1080, 1440×1080, 1080×1920 and 1280×720, retaining the
  configured 960×540 logical playfield/camera and correct transformed pad input.
  Portrait here is an engine resize fixture, not a changed orientation policy.
- Back notification, gameplay/story pause, touch Resume and story Skip.
- Repeated fresh load and Continue across Hay ride, After dark, rooftops,
  stockroom, Big top and the bus, including exact initial surface/camera state.
- An explicit clue-clear fixture with repeated completion/settlement/navigation
  callbacks, Back/resume/skip and exactly-once banking. This fixture does not
  claim to complete the level through gameplay.

The following existing suites also passed after the fixes:

- Native smoke.
- Campaign host integration: 52 checks.
- Story playback/lifecycle.
- Checkout host integration: 161 checks, including raw mash input.
- Combat integration: 56 checks.
- Skill integration: 62 checks.
- Festival night integration: 109 checks.
- Festival hayride integration: 475 checks.

All nine runs and a fresh editor import used disposable writable HOME/XDG
directories. Every log was scanned for `SCRIPT ERROR`, `Parse Error`, `^ERROR:`
and `ObjectDB instances leaked`, even when the process exited zero. No such
failures appeared. Focused logs are in
`/tmp/native-audit-regressions.2tuS5P/`; the import log is
`/tmp/native-audit-import.ryLPsy/import.log` in the audit execution workspace.
The parent owns adding this suite to the full aggregate and rerunning that
aggregate against its final checkpoint.

## Rendering/debugger observation

The existing unedited doorstep gameplay capture was inspected. The current
separate HUD/art work remains responsible for its legibility and art revisions.
No screenshot was treated as proof of phone fidelity.

The actual GUI Debugger count of 42 was inspected rather than called 42 gameplay
errors. Visible entries included unsupported VSync switching, a cloud-host audio
device `ERR_CANT_OPEN` followed by dummy-driver fallback, integer division and a
shadowed-variable warning. The GUI launch log was not accessible in this shell
namespace, so the audit does not classify all 42 entries or claim a clean audible
GUI run. The focused in-engine logs listed above are independently clean.

## Remaining boundaries

No additional confirmed gameplay blocker was established by these fixtures.
This does not mean the game has no remaining bugs. Physical iPhone/Android
multitouch, safe-area/notch coordinates, system Back and suspend/resume, GPU
layers, listening/performance QA and unassisted human runs remain necessary.
Unported later worlds, co-op, particles, source map/story presentation differences
and signing/export setup are documented scope gaps, not newly discovered defects.

Only the approved input region, Back configuration key, new audit test/UID and
this report were changed by this audit. No staging, commit, push, installation,
account action or deployment was performed.
