# World 2 bakery and trolley course mechanics

Implemented 2026-11-09 as an isolated component in `godot/src/supermarket_course.gd`. This change alone does **not** enable a level, add a renderer, or certify an authored level completion. Stage integration and capability promotion belong to the world/main owner.

## Evidence and ownership

Executable references in both `game/2-4/index.html` and `game/2-5/index.html`:

- `lvStart`, lines 738–747: initial automatic speed.
- `lvAuto`, lines 749–754: boost, front-player push, active-wave slowdown and interpolation.
- `updatePlay`, lines 633–650: `levelT` increments before player physics; automatic camera executes after physics, before waves.
- `lvUpdate`, lines 824–829: authored-order flame, low-sign and block contacts.
- `lvDrawMid`, lines 928–940: flame phase, warning, visual ramp and sign placement.
- `hurtPlayer`, lines 377–382, and its ability wrapper around 1800: damage eligibility and defenses.

The source level objects and six height values were independently compared with imported `godot/content/levels/{2-4,2-5}.json`; both match. Shared HTML lines 313–1168 match between the two pages, SHA-256 `611cbb893cf49c2ade8e458a2fd01033a7f2a7640ca4af90895e82a36703cf12` when joined with LF without a trailing LF. No embedded image lines were printed or executed for this comparison.

Only boost/flame/low/block dispatch is owned here. Ice, flour, belts, gates, falling drops and runaway trolley hazards remain in their existing shared modules. This controller never creates terrain surfaces, deck physics, coins, receipt/card pickups or hazard entities, and does not own wave completion or stage progression.

## Integration contract

- `reset(host, runtime)` deep-copies the runtime hazard schema, captures host/level/run identity, initializes `speed` from `level.auto * 1000`, clears `boost`, and snapshots `host.elapsed`. Call after a fresh level has set the main clock to zero. Do not call on Continue.
- `auto_displacement(dt, host) -> float` returns camera displacement in pixels. Invoke only for an automatic level in the existing living-player camera phase, after player physics and before this frame's wave activation/completion. Apply the source world-end/scene/camera cap in the owner and set ordinary camera velocity to zero. Do not move the player by this amount or lock its horizontal position. Non-auto levels return zero.
- `hazards_tick(dt, host, runtime)` belongs after shared falling drops and before late carts/drones and receipt/card pickup handling. Its clock is **`host.elapsed`**, not `runtime.elapsed`, and it does not increment an independent timer. The source clock has already advanced before player motion.
- Public `speed` is px/s, `boost` is boolean, `elapsed` is the last valid source clock snapshot in seconds, and `hazards` is an isolated full schema copy. `flame_phase(hazard)` returns seconds into that jet's cycle without changing state. A renderer can use the same timestamp/phase as collision, including at zero visual height.
- Calls with a different host, level, runtime, invalidated run generation, freed runtime, or non-play mode cannot mutate state. No wall-clock callbacks exist. Pausing does not accrue time. Continue retains speed and boost and picks up the same main clock; fresh reset restores authored initial speed.

The controller uses the existing optional `combat_participants()`/`hurt_combat_participant(player, from_x)` adapter. Non-host participant records retain `p`, `hearts`, `down`, `height`, `crouching` and `face`; block rebound additionally reads post-damage `invincible` seconds and updates `velocity.y` and `grounded`. Records must be mutable, as in shared combat. This adapter fixture is not a claim that playable co-op/CPU mode has been implemented.

## Source formulas and strict edges

### Automatic trolley camera

Initial 2-4 speed is 200px/s. A boost applies only when `camera.x + view_width * 0.4` is **strictly** inside its authored interval. It multiplies the base speed by 1.55. Any wave with `started && !done` multiplies that base target by 0.6. The greatest living participant x, including a CPU participant, supplies the additional push:

`clamp(((front - camera.x) / view_width - 0.5) * 400, 0, 120)` px/s.

The push is added **after** both multipliers. Speed approaches this target by `min(1, dt / 0.7)`, then displacement is `speed * dt`. Ending a wave or leaving a boost therefore decelerates/accelerates smoothly. The ordinary pre-camera player clamps remain the host's responsibility; there is no moving deck, trolley attachment constraint or forced player x.

### Flame jets

Phase is `(main.elapsed * 1000 + source_offset_ms) % source_period_ms`, converted to seconds. Contact occurs for phase `< 1.0`, horizontal distance `< 36`, and feet in `(floor - 175, floor + 4]`. Neither height nor crouching changes this feet test. The full 175px logical height applies even at phase zero and throughout the 150ms visual growth/shrink. Damage origin is `flame_x - player.face`.

The renderer owns the source warning at phase strictly greater than `period - 0.7`, visual rise before 0.15 and fall after 0.85. Those graphics never change the logical contact rectangle. No second renderer timer or random gameplay draw is needed.

### Low signs

Contact requires horizontal distance `< 52`, feet `> underside - 40`, and body top `< underside`, where `underside = floor - sign_height`. Body top is feet minus character height times 0.86 standing or 0.56 crouched, minus `level.ride * 0.4`. For the 30px 2-4 ride, the extra logical head offset is exactly 12px. The visual feet shift of 30px is not additionally applied to physics. Damage origin is `sign_x + 200`.

All six authored heights are used: JP 180, Maya 162, Ama 171, Leo 187, Theo 178, Mei 160. Ground crouching clears every authored low sign. Jumping, shooting or aiming uses the non-crouched body test when that is the player's source pose.

One host compatibility correction is explicit: JavaScript damage sets `lockAct = 'hit'` but leaves the current `act` unchanged until the next player update; native `hurt_player` changes the displayed animation immediately. Solo source crouch is therefore reconstructed as `host.crouching && player_animation in ['crouch', 'hit']`. This preserves this frame's crouched body through an earlier hit or block rebound, while excluding jump/aim poses. Next-frame hurt lock clears the host's crouching flag normally. No new host hook is required.

### Blocks and defenses

Contact requires horizontal distance `< width / 2 + 12`, feet `> floor - height + 8`, and feet `<= floor + 4`. Blocks are hazards, not solids. Damage origin is `block_x + 300`. After calling the host damage path, rebound happens only when the **resulting** invulnerability is `> 1.4` seconds: vertical velocity becomes -700px/s and grounded becomes false. Horizontal knockback and the existing platform marker remain untouched.

This is not a check for newly lost health. Existing 1.5s or Continue's 2.5s invulnerability still rebounds, exact 1.4s does not, and Maya's passive 0.9s block does not. Active Maya shield, slide and dash do not rebound unless a separate eligible invulnerability timer already exceeds the threshold. Flame/sign/block damage all goes through `host.hurt_player`, preserving ability/skill defense eligibility and hit counting. Living participants are refreshed for each authored hazard, so a lethal earlier hazard excludes later tuples.

## Authored inventory retained

- 2-4: 102 total tuples, including 36 blocks, 14 low signs, seven boosts, two trolley spawners and 43 coin rows. Boost starts are 4884, 10048, 15435, 20576, 25619, 30934 and 36237, each 800px wide.
- 2-5: 28 total tuples, including 13 flames, two wet signs, four belts, one flour zone and eight coin rows. Six flame periods are 2600ms, seven are 2200ms. Exact positions and all offsets are asserted against the authored fixture. The wet signs remain at 12600 and 14250, width 62 and height 84.

## Verification and remaining work

Executed with Godot **4.6.3**, headless, using an isolated temporary HOME/XDG save/cache directory:

- `godot --headless --path godot --script res://tests/test_supermarket_course.gd`: **6,969 checks, 0 failures**.
- Existing `test_supermarket_hazards`: 118 checks, 0 failures.
- Existing `test_world_two`: 101 checks, 0 failures.
- Existing `test_supermarket_combat`: 115 checks, 0 failures.
- Original level/height equality and shared-runtime source equality checks passed.

The focused suite covers every authored block/sign/flame with all six character heights, both horizontal boundaries, strict/inclusive vertical edges, source pose behavior, timer/ramp edges, boost/wave/push interpolation, mutable participant records, source order, invalidation, pause, Continue and repeated reset. It also instantiates actual `main.tscn` and exercises its real damage path for Maya's shield/passive, slide, dash and existing invulnerability, plus real Continue without reset. These are deliberately placed deterministic fixtures, not authored full runs.

Godot `Vector2` coordinates use 32-bit floats while JavaScript uses 64-bit numbers. Speed assertions permit less than 0.0001px/s rounding noise from those coordinates; collision comparisons themselves retain strict source inequalities without a tolerance. Timer-edge fixtures are specified as absolute source millisecond timestamps, rather than introducing a spurious boundary through adding already-rounded seconds.

Not performed by this component task: main/world integration, renderer screenshots, input-driven 2-4/2-5 traversal and difficulty proof, card persistence integration, full aggregate native suite, packed artifact verification, Android/iOS runs, deployment, or commits. The integration owner must register the suite in aggregate/pack verification and complete those acceptance steps before claiming either stage playable or complete.
