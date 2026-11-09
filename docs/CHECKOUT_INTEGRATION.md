# Checkout: real-main integration fixtures

Verified 2026-11-09 with Godot **4.6.3.stable.official.7d41c59c4**, headless.

`godot/tests/test_checkout_integration.gd`: **161 checks, 0 failures**.

These are deliberately configured integration fixtures, **not a complete
input-driven checkout run**. The independent `test_full_checkout_run.gd` owns
that progression claim. These fixtures instantiate the actual `main.tscn` and
exercise its `step`, lifecycle, input, world, combat, abilities, movement skills,
completion and disk-save paths. They neither call `_complete_level()` directly
nor manually set a clear flag to obtain their completion assertions.

Only this test and this report were changed by the integration-test work. No
runtime, painter, isolated controller test, or aggregate verification script was
edited here. The aggregate owner must include the suite and verify the final
combined tree.

## Reproduce safely

From the repository root, isolate all save/cache locations before running:

```sh
TEST_ENV=$(mktemp -d /tmp/bd-checkout-integration.XXXXXX)
mkdir -p "$TEST_ENV"/{home,data,config,cache}
HOME="$TEST_ENV/home" \
XDG_DATA_HOME="$TEST_ENV/data" \
XDG_CONFIG_HOME="$TEST_ENV/config" \
XDG_CACHE_HOME="$TEST_ENV/cache" \
godot --headless --path godot \
  --script res://tests/test_checkout_integration.gd
```

Expected final line:

```text
Checkout main integration: 161 checks, 0 failures (focused fixtures, not full progression)
```

The test intentionally writes native progress using the production
`SaveStore.write_save()` and reloads it using `read_save()`. Do not run this
save-writing suite against a player's ordinary HOME/XDG directories.

## What ran through the actual host

### Entry, authored approach data and camera

- Main selects the native supermarket runtime and checkout painter. Its generic
  `boss` stays null while `world_two.checkout` owns TB.
- All three solo approach waves retain their authored trigger coordinates and
  complete source groups/order. Each unfinished wave independently blocks entry,
  even with the camera at the endpoint and the other two wave flags complete.
- Camera 4159.999 cannot enter; exactly 4160 can. Entry creates the stationary
  70-HP boss at 4760, once, with the 4162 camera cap and lock.
- The actual 1.4-second boot boundary returns before the first countdown update.
  Waiting beyond an ordinary stage's 2.6-second end delay cannot grant a clear.
- Actual host motion respects the camera cap and late 4595 player barrier;
  TB does not become a generic solid wall.
- The host's real `_physics_process` clamps an oversized frame to 34 ms.

### Ordered physical and ghost shots

Identical overlapping fixtures run both physical shots and ability ghosts
through **main's full frame**, not a replacement interception function:

1. A real spawned bot takes the hit before the shared button, TB, ordinary
   breakable crate and final wall pass.
2. With the bot removed, the real shared button intercepts before TB.
3. With the button removed, TB takes exactly three screen damage, even when the
   incoming shot declares damage 999. Host-owned boss-hit credit increments.
4. When TB rejects the shot during entry, the ordinary crate takes the hit.
5. Without the crate, the final solid-wall cleanup consumes the shot.

An incidental homing shot also reaches TB normally. The test's overlapping
button, ordinary crate, wall and relocated bot are deliberate ordering fixtures;
checkout does not acquire an authored gate/button mechanic from them.

### Dynamic receipt geometry and consumers

A deliberately configured phase-2 health threshold enters real phase 3 and
spawns both rush helpers. The real late update then creates all three receipt
platforms, one per strictly-more-than-600-ms interval.

Every receipt is verified through live surface identity, player landing,
ability landing, ordinary floor lookup, movement-skill floor lookup,
drop-through filtering, side-wall clamp and projectile-wall exclusion. The
imported level's five conveyor platforms and source geometry remain unchanged.

Further complete main frames demonstrate:

- An actually falling player lands with `on_platform=true`, then drops through
  with ordinary jump+down input.
- A real coin settles 8 px above the paper and an item rests 26 px above it.
- A descending hostile bill lands on the paper; a horizontal friendly shot can
  pass beneath it because paper is not a solid wall.
- Theo's actual late ball effect bounces on the same dynamically added surface.

### Bags, raw input and real defenses

- The live low scanner causes health loss and a 1500-ms bag for every housemate.
  All six real crouch bodies avoid the high beam.
- Real Maya special activation, run+down slide and shared dash each prevent
  scanner health loss while the source bag still applies. The late bag zeros
  slide/dash lateral velocity. Maya's actual second-hit passive also preserves
  the source distinction between rejecting damage and applying a bag.
- Already-active invulnerability prevents both damage and bagging.
- Actual `InputEventKey` key-down/repeat and `InputEventScreenTouch` press
  objects reach `_input`; each supplies one global 160-ms mash unit. An unmapped
  key counts. Releases, real/emulated mouse presses, mouse motion and screen
  drags do not count. Routing through `_unhandled_input` does not count twice.
- A touch is also sent through the real viewport over a GUI button. `_input`
  receives it before GUI handling, and its release does not add mash.
- The next ordinary main frame consumes the queued count exactly once. Held
  control dictionaries do not fabricate repeated key events. Even the release
  frame preserves the source minimum hurt lock and zero lateral velocity.
- Paused input cannot add mash or advance the encounter; resume releases held
  touches and resumes the requested soundtrack.

This verifies the native solo host's global raw-input path. It does not claim
integrated multi-human or CPU participation, OS-generated touch delivery, or
physical-device multitouch testing.

### Generic boss blindness and late ability ordering

All six actual specials activate with the super skill fixture while generic
boss targeting remains disabled. They cannot directly auto-damage or stun TB.
Additional close-range fixtures cover Maya aura, ground-pound landing and Theo
ball targeting/reflection. Seeded JP rain uses the ordinary screen-wide source
position rather than a boss-biased position.

Theo's untargeted ball ghost is deliberately emitted inside the screen during
the late effect pass. It does not retroactively hit that frame; the next actual
projectile pass consumes it and deals the fixed three damage.

### Lifecycle, carry references and stale callbacks

A real crate overlap acquires the crate with a stable host identity; its shared
carry reference and full-height attachment are checked. Application focus-out
pauses the real game, releases input and freezes carry/timers. Layout resize
releases controls without resetting the encounter.

A real hostile bill kills the carrier. Before the global knockout screen is
shown, the same late frame drops the crate to the floor and clears the player
carry reference. The retained owner field is an integer identity, not a cyclic
host reference. Continue restores three hearts and 2.5 seconds of protection
without replacing the controller, boss, run generation or encounter snapshot.
The resumed player can pick up the dropped crate normally.

Switching to another W2 stage removes checkout and receipt surfaces. Old
controller references and input cannot mutate the new run. Fresh checkout
replay clears carry, bags, hit counts, global mash, jar and completion latches,
and restores six authored static surfaces. Returning to the map or another
world invalidates old callbacks and prevents stale W2 activity.

### Source music requests, defeat, jar and real save

A recording audio adapter verifies **production call ordering**, not audible
music fidelity. Main requests normal music at load and boss music once at
entry. Defeat's `boss_music(enabled=false)` notice does not stop the soundtrack.
The actual jar clear stops it exactly once and plays one win effect.

The final-hit fixture configures TB to three HP, then uses a genuine main-frame
projectile to defeat it. Twenty real coins appear without immediate banking or
clear. The jar is absent at exactly 1500 ms down time. Pause/resume preserves
that pending deadline. On the first later frame, the actual jar spawns and
immediately receives gravity, movement and age in that same frame.

A mature jar away from the player cannot clear. Placing a living player at its
horizontal coordinate but more than 100 px away vertically exercises the real
source collection predicate. Both completion latches set, remaining real coins
and the configured carried score bank once, and the production save file
contains the checkout clear and exact resulting kitty. Repeated post-clear
main/world/controller calls neither rebank nor replay win nor change the file.

Two additional knockout order cases run:

- A final player shot resolves before an enemy bill stored first in the array.
  TB goes down, coins drop and its late down timer advances before global
  knockout. The pending jar callback freezes until Continue.
- A lethal bill arrives while a mature real jar overlaps the player. No living
  collector remains, so the late jar updates without clearing and the game
  enters knockout. Continue retains that original jar; the next frame collects
  it once through the normal completion path.

## Source anchors and limits

Executable browser reference: `game/2-6/index.html`:

- `updateShots`, lines 529–559: bots → level hook → generic boss → crates → walls.
- `updateJar`/`stageClear`, lines 620–630: living horizontal-only collection,
  age gate and coin banking.
- `updatePlay`, lines 633–673: wave/end predicate, late update and final all-down.
- `L.readyEnd`, `bagPlayer`, `L.update`, `tillHit`, `L.shot`, lines 1200–1286:
  separate checkout, raw mash, phase behavior, defeat and jar timer.

Native seams are `main.gd` (`step`, `_input`, `checkout_event`, lifecycle,
`_complete_level`), `world_two.gd` (`objective_tick`, `intercept_shot`,
`after_pickups`, live geometry queries), and the existing checkout/combat/
abilities/skills/save implementations.

Fixture shortcuts are explicit: player/camera placement; completed approach
wave flags; boss phase, threshold/final-hit HP, beam and step-counter setup;
spawned/relocated overlap objects; acquired skills and special meter; a prepared
ground-pound landing; a configured carried score. Helpers may be cleared to
isolate surfaces. These shortcuts cannot establish full progression, balance,
difficulty or whether a person can perform the sequence.

No framebuffer comparison, exported-package verification, audible synthesis
validation, real phone/OS lifecycle test, mobile multitouch certification,
network/co-op play, publication or deployment is claimed here. This suite does
not replace the controller, painter, full-route, packed-runtime or broader
regression suites.

The existing completion UI remains **Settle up → Play again / Back to worlds**.
This work does not claim automatic routing to a next catalog stage. That is a
separate existing UI/progression gap, not a checkout jar/save failure.
