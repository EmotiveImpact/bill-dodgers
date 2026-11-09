# World 1 scene port

`godot/src/world_one.gd` translates scene state from the checked-in Canvas game.
It is not a new level design or a claim that World 1 is finished. All imported
geometry, wave lists, original art and source files remain unchanged.

## Implemented state

- **1-2 rooftops:** source geometry queries, twelve collapsing slate surfaces,
  roof-to-roof robot jumps, chimney-clearing robot jumps, safe falling recovery,
  flyer spawn-height selection, and the non-boss ending objective. The original
  metadata contains **eleven waves**, fourteen roof runs, 28 solid surfaces,
  22 ordinary one-way surfaces, six crates and two checkpoint flags.
- **Shared World 1:** dynamic `landOn`/`below` queries, safe floor selection,
  one-shot boss request events and timed exit events. Existing `combat.gd`
  continues to own wave scheduling, enemy AI, flying bob, coins, crate pickups,
  checkpoints and Bailiff volleys. Receipt and skill-card behavior belongs to
  the host/movement module; this module does not duplicate it.
- **Reusable tile-run systems:** 1-5's 190 px/s and 1-S's 250 px/s camera
  advance, the source auto-scroll wall-lifting rule, and all four repeating
  eight-coin patterns in 1-S. These scenes are now integrated with original
  renderers and full input traversals for all six housemates; see
  STREET_RUN_VERIFICATION.md and STREET_RENDERER_PARITY.md.
- **1-3 top deck:** the separate `bus_ride.gd` module now owns its sequential
  encounters, scooter arrivals, overhead collisions and objective. See
  [BUS_RIDE_PARITY.md](BUS_RIDE_PARITY.md) for the contract and verification.

## Host contract

All positions are absolute world pixels, with player/enemy positions at their
feet. Source milliseconds are converted to seconds; source pixel/millisecond
velocities are converted to pixels/second. In particular, source `GROUND + p.y`
is the native `host.player.y`. `camera.y` remains the source vertical offset.

Read/write host fields:

- `level_id`, `level`, `meta`, `mode`, `player: Vector2`, `velocity: Vector2`,
  `camera: Vector2`, `camera_speed`, `grounded`, `on_platform`, `hearts`,
  `invincible`, `face`, `status`, `boss`, `enemies`, `coins`, `combat`.
- `combat.waves`: dictionaries with `done`; `combat.rng`: native RNG.
- Enemy dictionaries use existing combat fields `p`, `kind`, `state`, `segment`,
  `face`, `entered`, `t`, `gone`. An optional `hop` dictionary is owned by this
  module. `segment` is a three-value `[left, right, top]` array.
- `view_width()`, `view_top()`, `sfx(name)`, `hurt_player(from_x)`,
  `add_coins(position, count)`.

Public entry points:

1. `reset(host)` resets scene state after assigning level metadata and player
   position. Crumbles are cloned, never appended to or removed from source JSON.
2. `land_on(host, x, old_feet, new_feet, skip_platforms=false)` returns
   `{row: [left,right,top], plat: bool}` or an empty dictionary. A slate also
   has `crumble: true`. Use this in player, enemy, projectile and pickup landing
   queries and in the grounded support check. Landing `on_platform` must use
   the returned `plat`, including a slate. This is a full collision query,
   not a second slate-only pass.
3. `below(host, x, feet)` returns the nearest surface with top >= feet-2, or
   empty. Hosts may expose a float wrapper for their existing `floor_at` API,
   but a missing roof must not become a fake global collision plane.
4. `after_motion(host)` records the source fall-safe position when grounded
   on a solid and strictly 90 pixels inside both edges. This is distinct from
   checkpoint flags. Continue revives in place without reloading the stage.
   `recover_from_fall(host)` implements the
   source 60-attempt, 20-pixel forward search within the current viewport,
   applies fall damage, and cancels horizontal knockback afterward.
5. `after_camera(dt, host)` adds auto-scroll after ordinary camera following.
   It does nothing for paused/dead/boss states. Combat must leave camera locks
   null on auto-scrolling levels; this routine does not own wave locks.
6. `objective_tick(dt, host)` runs **after waves, before enemy/projectile
   updates**. It returns `""`, `"ending"`, `"clear"` or `"boss"`. The host
   owns banners, honk/music, completion UI and save updates. On `ending`, use
   `meta.text.endBanner`, `endSub`, `endSay`; on `clear`, use `text.cleared`.
   `boss` means dispatch the level's own boss, not always Jar Thief.
7. For exact shared frame order, call `crumble_step(dt, host)` after combat
   and checkpoints, then `combat.bob_flyers(dt, host)`, `chimney_step(host)`,
   `combat.bailiff_volleys(dt, host)`, host receipt/card/slide processing, and
   `after_pickups(host)` for auto-wall lifting/bonus coins. `tick(dt, host)`
   composes only the three scene-owned hooks for isolated adapter tests; the
   integrated main uses the separate hooks to preserve source ordering.

Enemy AI hooks:

- At the beginning of an active enemy's update, **after** advancing `t` and
  decrementing flash, and after the `pop` early return, call
  `tick_enemy_hop(dt, enemy)`. If it returns true, skip ordinary AI/contact
  for that enemy this frame, including its arrival frame. Preserve any global
  offscreen cleanup after the enemy loop.
- After the entered-screen horizontal clamp and **before** the segment-edge
  clamp, call `try_enemy_gap_hop(host, enemy)`. If it created `hop`, omit the
  segment clamp. The source still checks contact that frame.
- Flyers spawn at `flyer_floor(host) - random(190,230)`. A falling player
  cannot lower the flyer base to an unreachable depth. Do not apply hop
  behavior to flyers or double-step their existing sine bob.

The required scene order is: player motion/passives, base camera, auto camera,
waves, objective, enemy update, shots, coins/items, checkpoint handling,
crumble, flying bob/specials, pickups/slide, level-specific update. The current
combat implementation combines some independent shared operations; where
those operations interact with a changing surface, keep the source order.

## Exact timing and boundary details

- Slates trigger only for a living, grounded player within 3 px of their top,
  with inclusive horizontal edges. Their countdown continues after departure.
  They fall when `t > 0.650`, set `fall = 0.001`, release a rider at 50 px/s,
  and regenerate when `fall > 5.200`. They are one-way surfaces. Robots whose
  segment is that slate pop and drop 4–6 coins without adding player pop credit.
- Collision uses the source `top >= oldFeet-1` and `top <= newFeet+0.5`.
- Gap jumps require a solid wider than 200 px, gap strictly <230 px and height
  difference strictly <230 px. They land 40 px inside the new roof, taking
  `0.520 + abs(dx)*0.0012` seconds. Chimney jumps land 34 px past a block at
  most 260 px wide, taking `0.650 + abs(dx)*0.0015` seconds. Both use the source
  sine arc with height `70 + max(0,startY-endY)*0.6`.
- Timed exits require camera >= `worldWidth-viewWidth-2` and every wave done.
  The timer starts at **0.001 seconds**, includes that frame's dt, and clears
  only when greater than 2.600 seconds. 1-2 never spawns a boss.
- 1-S starts its next row at x=700. Each row has eight coins 46 px apart; rows
  begin every 560 px when they enter `camera+viewWidth+120`. Coins are resting
  and age 0.260 at spawn. The patterns are low, sine arc, high, alternating.

## Rendering contract

The separate rooftop renderer consumes `host.level`, `host.meta`, original
`host.images`, `host.camera` and `scene.crumbles`. Slate dictionaries contain
`row`, `t` and `fall` in seconds. Their geometry never moves. Source artwork
matches a slate when `abs(row[0]-6-decorX)<2`. A falling slate is drawn at
`decorY + fall*fall*1200`, alpha `max(0,1-fall/0.7)`, hidden after 0.7 seconds;
before falling it shakes horizontally by up to 2 px. Keep the source paintings
at original dimensions and preserve foreground/background order.

## Verification and limits

`godot --headless --path godot --script res://tests/test_world_one.gd`
passes 65 checks for imported rooftop counts/coordinates, collision tolerances, slate
trigger/removal/regrowth, enemy hops, flyer heights, fall-safe positions, exit
timing/guards, auto-scroll, wall lifting and all bonus coin patterns using an
isolated host adapter. Run Godot with writable isolated HOME/XDG directories
as `scripts/verify-native.sh` does.

`godot --headless --path godot --script res://tests/test_world_one_integration.gd`
passes 31 checks against the actual main/combat scripts, including input jumping
onto the fire escape, dynamic-slate landing/drop-through/collapse, pause/reload,
actual enemy hops/flyer height, safe-roof fall recovery, native end/save behavior
and no fake clear for an unported World 2 preview. Dedicated collision regressions verify
that flyer bob and new Bailiff volleys happen after the current frame's projectile
pass. These are focused fixtures, not a whole-level input traversal.

These tests alone do not establish visual,
difficulty, touch, physical-device or full-level playthrough parity.

Still pending:

- Exact particles, banners, presentation and human/device fidelity QA.
  All seven World 1 solo progression paths are integrated, including the
  dedicated Binman controller, rather than substituting the Jar Thief.
- Two-player/CPU parity. The host adapter is solo; source multi-player choices
  of safe roofs, flyer height and shared revival are not represented here.
- The host owns finish-line coin banking and completion/save handling. Its
  in-place Continue behavior is covered by the bus integration tests rather
  than simulated by this module.

Source references: `game/1-2/index.html` `landOn`/`below` (318–328), `fellOff`
(385–393), `updatePlayer` (410–449), `updateBots` (482–525), `updatePlay`
(632–675), common scene code (722–818) and rooftop drawing (884–962).
Auto-scroll wall lifting: `game/1-5/index.html` (910–914). Bonus patterns:
`game/1-S/index.html` (917–929).

The full rooftop route now runs with all six housemates; see ROOFTOP_ALL_CHARACTERS.md. Tiny robots use the source auto-scroll speed bonus: 190–230 px/s normally, 380–420 in the alley. The separate bus spawn adapter remains unchanged.
