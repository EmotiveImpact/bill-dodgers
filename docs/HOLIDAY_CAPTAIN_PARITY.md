# Captain Overcharge controller

Implemented 2026-11-09 in `godot/src/holiday_captain.gd`. This is an isolated
World 4 boss controller, dedicated painter, focused tests and actual-main
input-driven 4-6 progression routes. The routes use explicit invulnerability.
They do not establish human playtesting, difficulty balance, complete World 4
parity, multiplayer support or device readiness.

## Executable source and retained mechanics

Reference: `game/4-1/index.html:1305–1356`, the W4 shot dispatch at 1073,
the shared bill helper at 942, and `WORLD_FOUR_IMPLEMENTATION.md` sections 6,
9 and 10. The seven W4 pages share this implementation. Stage 4-6 metadata
remains unchanged, including width 5712, bossY 522 and ground 482.

- Initial boss: 90 HP solo, 120 for more than one participant, x=world+260,
  y=cfg.bossY (or water+30), enter, next=1.8 seconds. Camera lock is world−738.
  The pair count includes down participants, rather than counting only living
  targets. Pair scaling is tested through an adapter, not playable co-op.
- Entry moves left at 250 px/s until x≤R−120. Every active-target tick clamps
  x to [L−40,R+300], where L=world−view+120 and R=world−110. The first source
  frame therefore snaps from 5972 to 5902. `aimX=x−20` is set before movement.
- Drift faces the nearest living participant, using left for exact overlap.
  Its sine target and bounded 80 px/s approach match the source. Strict
  t>next chooses rear only in phases 2/3 with random<0.4; otherwise throw.
- Throw fires once after strict 380 ms: three big bills in phase 1, four in
  later phases, from x−60/y−300 with centered 120-pixel target spacing. It
  returns after strict 900 ms to a random 1.5–2.5 second delay, or 1–2 seconds
  in phase 3. The world's bill helper owns the actual source trajectory.
- Rear waits strictly longer than 700 ms, then chooses direction from the
  arena midpoint. Charge moves at 550 px/s. Crossing its strict boundary
  creates one reverse-traveling 400 px/s wave and a 1.4 second drift delay.
  The new wave first moves on the following tick. The turnaround frame does
  not also inflict neck contact damage.
- Phase thresholds use >0.66 and >0.33. Crew thresholds independently use
  <0.8, <0.5 and <0.25, once each: right jet, then left jet/right ring, then
  right jet and an additional left jet for a pair. Several thresholds can
  fire together. A projectile pass uses the previous phase until boss tick.
- Waves move before contact, use strict horizontal distance<26 and absolute
  feet>ground−30, then cull at L−200/R+200. Charge neck contact uses strict
  distance<60 around x+dir×60 and feet>ground−120. No grounded requirement
  or stationary body contact was added. The runtime retains invulnerability.
- Shot interception uses a strict swept-x/current-y asymmetric body box:
  x−150s..x+120s, y−330s..y−20, s=1−sink×0.35. Entry/down are immune. Damage
  is fixed 1 regardless of shot.damage. In phase 3 a final shot endpoint
  strictly within 60 pixels on both axes of the facing-dependent valve deals
  3. Sweeping through the valve is insufficient. Dizzy never freezes AI,
  decays, or multiplies damage.
- Death immediately clears the boss's waves, drops 18 physical coins at
  x−60/ground−200, and calls the runtime's ordinary-bot/hittable-foe cleanup.
  Existing hostile bills and non-hittable controllers must survive that
  cleanup. The boss sinks at 30 px/s with scale progression dt/2.4 capped at
  1. After strict 1.8 seconds it creates one jar at the current camera center,
  ground−220, with velocity (−100,−900) px/s. Death alone never clears.

## Deliberate native corrections

**Shared ability feet repair:** the source creates `y` but omits `fy`.
Shared direct boss zaps and several proximity tests consequently use invalid
coordinates or fail their condition. The integration owner selected the
functional repair proposed in the World 4 contract: native `fy` mirrors the
current boss `y`, including every sinking update. `state` exposes the same
dictionary, so shared ability targeting can safely read these coordinates.
This intentionally makes those source-broken ability interactions functional;
it is not exact source parity. It does not change body/valve damage, custom
foe interception priority, or the unused dizzy behavior. Arbitrary non-finite
projectiles are still rejected safely. Focused tests distinguish a source-shaped
missing-fy fixture from a valid repaired direct hit and verify sink synchronization.
All six direct real-main ability paths remain a separate integration acceptance
responsibility; the progression routes exercise each character and their
naturally earned approach specials.

**Randomness/presentation separation:** source charge spray samples the same
global random stream used by gameplay. The controller does not consume gameplay
RNG for that cosmetic spray; a painter may use a separate presentation RNG.
Attack probabilities and numeric ranges are retained, but a globally seeded
browser/native random sequence is not promised to be identical. The controller
uses the supplied `world.rng`, which permits deterministic focused fixtures.

**Lifecycle safeguards:** repeated start does not restart an existing boss;
reset discards all boss, jar, event and generic-hit context. The native shot
adapter also honors dead/enemy/expired bullets and sets life=0 on consumption.
Negative timestep is clamped to zero. Authored valid bossY is retained; missing
both bossY and water uses a safe ground fallback for invalid configuration.

## Runtime integration contract

Public API:

- `reset(host)`, `start(host)` and `tick(dt,host,world)`.
- `intercept_shot(shot,old_x,host,world) -> bool`.
- `boss` dictionary; `state` is an alias of that same dictionary.
- `jar` dictionary: `{p: Vector2, v: Vector2, t: seconds, got: bool}`.
- `body_box() -> Dictionary` and `drain_events() -> Array[Dictionary]`.
- `configure_context(host,world)` and `hit(point: Vector2,damage: int=1)`
  adapt the existing generic boss interface. Tick and explicit interception
  also bind that context. Reset invalidates it; bindings use weak references.

Host supplies `level`, `meta`, `camera`, `camera_lock`, `status`, `view_width()`,
`sfx(key)`, `add_coins(position,count)` and optionally `combat_participants()`.
World supplies `rng.randf()`, `living(host)`, `hurt(host,participant,source_x)`,
`spawn_foe(side,kind,host)`, `bill(host,position,target_x,big)` and
`clear_threats(host)`. Living records have absolute-feet `p: Vector2`.

Runtime owns the camera/all-waves start predicate, source frame cap and pause
guard. Call interception after custom foes and before ordinary bots/crates;
call boss tick after ordinary projectiles and pickups. Newly created helpers
and bills must not update retroactively in the already-finished combat phase.
Do not also run a generic legacy boss tick.

Runtime must update the independent jar in the same frame it is created,
including the full timestep, source gravity/bounce, strict age>600 ms and
horizontal distance<50 pickup. Collection, not HP zero or sinking, invokes
the normal clear/save flow. This controller never calls `_complete_level()`.

Sound/status/reward/cleanup actions occur directly. Events are presentation
requests (`warning`, `shake`, `text`, `bits`, `jar_spawn`) and accepted-hit
reports (`hit`, including `boss_hits:1`, damage and valve flag). The initial
warning carries `music:true`; the integration owner applies boss music. Do
not replay direct sounds or awards from event consumption. A supplied mutable
source-shaped shot owner receives its `bossHits` increment directly; native
owner/meter accounting should avoid double-crediting that and the hit report.

## Verification performed

Godot 4.6.3 headless focused suite, **155 assertions passed, 0 failures**:

```sh
work=$(mktemp -d)
HOME="$work/home" XDG_CACHE_HOME="$work/cache" \
  XDG_CONFIG_HOME="$work/config" XDG_DATA_HOME="$work/data" \
  godot --headless --path godot --script res://tests/test_holiday_captain.gd
rm -rf "$work"
```

Coverage includes actual imported 4-6 metadata, source numeric entry/drift,
strict timing and collision boundaries, deterministic attack choices,
phase/crew order and pair counts, nearest-target ties, real host damage and
invulnerability, shot priority adapter guards, delayed phase changes,
fixed body/valve damage, down/reward idempotence, sink/jar timing, replay,
generic interface binding, and the explicitly repaired ability feet.

An additional one-off Node VM probe executed the **unmodified extracted**
`startW4Boss`, `bossBox`, `bossShot`, `updateW4Boss` and `w4BossDown` functions
with stubbed effects/world services. All **16 reference assertions passed**
for initial state, entry snap, drift, throws, phase/crew order, body/valve
damage, original NaN rejection, charge/wave boundary and down/jar values.
This is a numeric source reference check, not an input-driven game run.

### Source-art renderer

`holiday_captain_renderer.gd` adds `build_boss`/`draw_boss` and
`build_jar`/`draw_jar`, extending the festival painter for command and sprite
primitives only. It does not paint World 3 scenery. The source has no Captain
sheet; actual art is a pink procedural flamingo with its quadratic neck,
beak/eye, gold valve, original thief-sheet rider and four-part captain hat.
The painter retains body bob/rear rotation, source facing, sink scale/fade,
level-clock valve sparkle, source splash waves, and the full-size holiday pot.

The original fallback's `drawSprite(...,alpha=1)` overrides its enclosing down
fade. The native painter explicitly preserves this quirk: the rider remains
opaque while flamingo and hat fade. It does not invent a sink sprite. Smooth
curves are tessellated (64-point ellipses, 32-segment quadratic neck), rather
than claiming pixel-identical browser Canvas rasterization.

The transformed rider uses the `captain_rider` command, handled by this
painter's `draw_commands` through `CanvasItem.draw_polygon` with texture UVs.
A batching parent must delegate that command, or call `draw_boss` directly.
Temporary flash textures preserve the original sheet and are cache-cleared.

`test_holiday_captain_renderer.gd`: **98 assertions passed**, including
**20 actual CanvasItem draw callbacks** spanning states, both facings,
flashes, affine rider rendering and jar hooks. Tests verify source anchors,
all four throw crops, procedural geometry, rounding/rotation/fade, waves,
jar dimensions, resource/cache safety, and no RNG or simulation mutation.

### Actual-main 4-6 routes

`test_full_captain_run.gd` loads `main.tscn` and fresh isolated saves, then
drives ordinary left/right/jump/crouch/fire/special controls. It never sets
player/camera positions, waves done, enemy/boss HP, or the clear result.
The only gameplay assist is `invincible=999` to isolate progression. It does
not prove damage-free or practically survivable play.

Every character completes the original four waves/17 ordered solo entries,
fights the 34-HP Bailiff set, collects all three original receipts, takes the
Captain through all three HP phases and enter/drift/throw/rear/charge/down,
observes the splash wave and exact jet/jet/ring/jet helper sequence, pauses
and resumes the live encounter, and obtains the actual delayed age-gated
holiday jar. In-memory and reloaded disk clears are verified. Original metadata
is unchanged, and retirement is counted separately from foe deaths.

| Character | Input ticks | Jumps | Falls | Foe deaths / retirements | Contact frames: bot / foe / neck / wave / bill |
|---|---:|---:|---:|---:|---|
| JP | 5666 | 8 | 0 | 6 / 3 | 0 / 0 / 32 / 0 / 12 |
| Maya | 6470 | 7 | 0 | 5 / 4 | 0 / 2 / 37 / 0 / 12 |
| Ama | 6574 | 9 | 0 | 5 / 4 | 0 / 3 / 40 / 2 / 10 |
| Leo | 6482 | 15 | 0 | 5 / 4 | 0 / 190 / 30 / 0 / 9 |
| Theo | 6059 | 8 | 0 | 6 / 3 | 0 / 0 / 32 / 0 / 11 |
| Mei | 6009 | 5 | 0 | 5 / 4 | 6 / 0 / 12 / 0 / 13 |

These are observed contact-overlap frames or consumed hostile-bill contacts,
not a count of hearts that would be lost: host invulnerability and source
abilities normally suppress repeated damage. Each run naturally used three
approach specials. All jar spawns were 108 simulation frames after defeat,
then actually collected 35 frames later with age strictly greater than 600 ms.
Times in this table use the fixed test step of 1/60 second.

The route deliberately lands on the first stair at x3060/y412 before jumping
to the next jetty. An earlier direct two-riser attempt exposed a source-style
Mei speed-nudge edge case: crossing x3120 after the vertical landing check at
y343.725 can miss the y342 surface and fall through it. This change does not
alter that shared movement ordering or claim to fix it. The final route uses
normal input to take each stair safely; the earlier fall is not hidden as a
physics fix or a difficulty pass.

Run the three suites with isolated HOME/XDG state, as above:

```sh
godot --headless --path godot --script res://tests/test_holiday_captain.gd
godot --headless --path godot --script res://tests/test_holiday_captain_renderer.gd
godot --headless --path godot --script res://tests/test_full_captain_run.gd
```

The full-route suite also accepts `-- --character=jp --trace` (or another
housemate) for focused diagnostics. All-six reruns passed against the integrated
W4 main/runtime; this worker did not edit the shared host or registry.

Not performed by this change: aggregate native regression, resource-pack
verification, screenshot/pixel comparisons, human playtesting, exports or
devices. Dedicated rendering callbacks are not physical-device graphics QA.
