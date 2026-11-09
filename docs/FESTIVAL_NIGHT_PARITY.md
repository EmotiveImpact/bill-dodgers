# Festival night runtime: 3-3

Implementation scope: `godot/src/festival_night.gd`, isolated test
`godot/tests/test_festival_night.gd`. This is not an assertion of device,
complete-run, audio, or pixel parity, and does not itself register a stage.

## Executable evidence

`game/3-3/index.html` lines 732, 1144–1163, 1287, 1300, 1306,
1316–1317 are the runtime and visual-state authority. Imported JSON is read
without mutation. Source milliseconds become seconds, coordinates remain
absolute feet/world pixels.

- Five fires: (1450,482), (3900,482), (8650,482), (12250,482),
  (14550,482). Damage requires BOTH strict abs(dx)<34 and abs(dy)<30.
  No grounded requirement, no crouch exception, no special wellies immunity.
  Ordinary host damage handles invulnerability and abilities. Participants
  are considered in source fire-major order; down/dead participants excluded.
- Darkness is 0.5. Flash decays with cheer, before checkpoint and hazards.
  Every late active frame consumes one chance draw with probability dt/7,
  after spotlight processing and before mini activation. A burst consumes
  three more random draws for x/y/color, then two independently scaled draws
  per each of22 rays. Angles use i*0.2856, not an idealized full-circle angle.
  Burst x=cam+100+random*(viewWidth−200), y=viewTop+60+random*100.
  Palette: #ff8fc7, #ffd23f, #7fd6ff, #9be37a.
- New burst flash is0.5s. All bursts, including newly created ones, age by
  this frame's dt and are removed when t>=1.4. Darkness alpha is
  max(0,1−flash/0.6)*dark. Painter receives detached snapshots, consumes no RNG.
  Spark x displacement=s.x*t*120, y displacement=s.y*t*120+t²*40.
- **Authored glow quirk:** all15 tent rows contain fifth-column1, but source
  TENTS constructor line732 reads only the first four columns plus shake.
  There is no subsequent t.glow assignment. drawDark's t.glow branch is
  therefore inactive. Preserve flags separately as authored_tent_glows for
  inspection; do not fabricate effective tent lights or duplicate tents.

## Shared behavior, not a second implementation

WorldThree owns mud, coin inventory, tents, scene blocking, checkpoint,
mini trigger and objective. Shared scene at strict living-player x>7000
fades to camera7900, preserves player camera-relative x and snaps feet to
support. Checkpoint at strict x>7000 restores all hearts and1.5s invincibility.
Scene callback runs after the base frame at1.43s; opening starts1.57s;
finish2.17s. Native simulated clocks pause with gameplay and generation checks
reject obsolete callbacks after reset/Continue. These are declared reliability
corrections from browser wall-clock presentation callbacks, not new gameplay.

Bailiff config is copied directly: kind=bailiff, name=Bailiff bot,
cam8000, hp70/hp2=95, mini="Bailiff sorted!". Trigger camera>=7740 with no
boss and not mini_done. Existing FestivalBoss supplies500px/s charge,
three big nontying bills, ±420px/s shockwaves, threshold helpers, dizzy
bonus hits,16 coins and mini removal strictly after1.8s down. No new boss
implementation, tie rule, jar, or artificial progression is needed.

## Production integration contract

Parent-owned WorldThree must preload/instantiate the extension, reset it
on each run, and expose night.snapshot() as stage_data only for3-3:

1. `timers_tick(dt,host,runtime)` beside shared cheer decay.
2. `fires_tick(host,runtime)` after checkpoint/banner hazards, before movers.
3. `fireworks_tick(dt,host,runtime)` after spotlights and before mini trigger.

Calls check stage and shared `_can_step` lifecycle, including the existing
attested final base-frame allowance. No extension callback should run from
ordinary drawing. Wipe is shared, not an animation scheduler in this module.
A firework event includes source tone/noise parameter descriptions. The fourth
argument of noise(0.4,0.15,900,0.05) is a50ms start delay (`delay:0.05`),
not an end-volume parameter. Audible
rendering requires the parent's audio/event adapter and is not proven here.

## Randomness and verification limits

The local source probability, independent component draws and their order
are preserved. Do not claim browser/native seeded sequence identity: JS uses
Math.random, native uses Godot RandomNumberGenerator; shared native combat
has its own RNG, and source cosmetic mud/tied puff draws are not all ported.
Using runtime.rng keeps night randomness deterministic and testable without
inventing a wall-clock burst timer. No drawing-time random draws are added.

The isolated suite tests authored coordinates, strict boundaries, ordinary
invulnerability, source glow omission, RNG draw count and chance equality,
placement/palette/rays, age/flash/expiry, snapshot detachment, pause/reset,
and shared Bailiff HP/bills/charge/shockwaves. Once WorldThree advertises3-3,
the same suite exercises production checkpoint, fade callback, boss trigger,
stage snapshot and late fire-hook dispatch. If not integrated, it prints an
explicit pending message; an isolated pass is not an integration pass.

Command (isolated user data; reject nonzero exit and any ERROR/WARNING/FAIL/
leak/orphan output):

    HOME=/tmp/night-home XDG_DATA_HOME=/tmp/night-data XDG_CONFIG_HOME=/tmp/night-config /usr/local/bin/godot --headless --path godot --script res://tests/test_festival_night.gd

Initial result before parent wiring:62 checks,0 failures; production integration
was explicitly pending. After parent wiring and the audio metadata regression
assertion:69 checks,0 failures with strict log rejection. The scene-position
assertion computes the expected translated Vector2 from the actual stored
pre-jump position; it does not compare float32 coordinates against an exact
decimal literal at an inappropriate1e-6 tolerance. No shared runtime changed.
