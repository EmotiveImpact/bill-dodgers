# 1-3 Top Deck scene state

`godot/src/bus_ride.gd` ports `levelStart`, `levelUpdate` and
`levelSpawn` in `game/1-3/index.html` (lines 884–925). It preserves the source
timeline and collision rules. The native main/combat integration now enables
1-3 explicitly and calls this module's separate objective. The generic World 1
objective still rejects 1-3 completion, preventing a second completion path.

## Source content and timing

- The fixed arena is **738 px** wide. The roof is `[45,689,150]`. Player feet
  begin at `(319,150)`, with source ground baseline 482. The painting rectangle
  is `[19,146,700,385]`; its gentle visual bounce does not move the roof collider.
- `levelUpdate` pins `camera.y` to **-235**, after the ordinary shared camera
  update. The horizontal camera stays at zero because world and viewport widths
  match. Scenery distance `drive` advances at **420 px/s**, including fights.
- There are **12 sequential fights** and **25 between-fight obstacles**. The
  source metadata and order are unchanged. Every wave's trigger starts at
  `1e9` until the bus controller releases just that wave by setting `at=-1e9`.
- Initial rest is **2.600 s**. After a fight completes, its obstacle queue is
  copied and a **1.400 s** rest starts. On an obstacle release, rest becomes
  **0.900 s**, but another obstacle/fight cannot release until no obstacle
  remains. Only one obstacle is active at a time.
- Bridges are **330 px** wide; branches are **150 px** wide. Their starting
  x is `viewportWidth + 40 + driveSpeed*1.900` (1576 px in the source stage).
  Warning time starts at **1.900 s**. Both obstacle position and warning time
  consume the spawn frame's dt immediately.
- An obstacle is removed when its right edge is **<= -60**. The queue checks
  before obstacle movement/removal, so the next obstacle/fight can release only
  on a subsequent frame. The final fight has no following obstacles.
- Ending begins when the camera end condition and all twelve completed waves
  pass, before enemy updates that frame. As in the shared engine, the timer
  starts at **0.001 s**, consumes that frame's dt, and clears only at **>2.600 s**.
  There is no boss, jar collection or invented distance-based finish.

The 25 source obstacles, grouped after each fight:

1. bridge
2. branch, bridge
3. bridge, bridge
4. branch
5. bridge, branch, bridge
6. bridge
7. branch, bridge, bridge
8. bridge, branch
9. branch, branch, bridge
10. bridge, bridge, branch
11. branch, bridge, branch, bridge
12. none

## Arriving robots and an important source quirk

`spawn(host, side, kind)` must intercept **before** shared special spawning.
It returns false for flyers, which use the existing flying-mailer path. Other
types start 90 px beyond the painting's corresponding end: right x=809 or left
x=-71. Feet begin at roof+230 (380). Their **760 ms** source hop lands at
x=489–609 from the right or x=129–249 from the left, using the existing WorldOne
sine-hop implementation. The halfway arc is 208 px above linear interpolation.

Rush arrivals have 3 HP, zero stop distance and speed 90–115 px/s. Every other
non-fly type has 4 HP, stop distance 200–350 px and speed 63–80.5 px/s. Initial
cooldown is 1.4–2.3 s. Arrivals are already `entered`, skip ordinary AI/contact
while hopping, and land on the real bus segment.

**The source 1-3 `tiny` and `mini` labels do not receive Small Print or Bailiff
upgrades.** `levelSpawn` consumes these labels before `spawnSpecial` sees them.
They are ordinary size, 4 HP, normal throwing robots with no special volley.
The port deliberately preserves that behavior: `source_kind` and `type`
retain the source label, while native `kind="throw"`, `scale=1`, `big=false`
avoid accidentally activating shared mini-boss rendering/health/volley rules.

Scooters start 10 px above their riders' initial feet (y=370), moving outward
at +250 px/s from the right or -350 px/s from the left, initial vy=-200 px/s,
gravity 1600 px/s². Their source semi-implicit update advances vy before y.
They disappear at **1.500 s**. Their artwork is separate from the robot hop.

## Obstacle collision

- Player x is inside at inclusive `[obstacle.x-10, obstacle.x+width+10]`.
- Bridge underside is roof-132 (18); branch underside is roof-128 (22).
- Player top is feet-height×0.56 **only when animation is `crouch`**; otherwise
  it is feet-height×0.86. A top strictly above the underside gets hit. Exact
  equality is safe. The code uses the source character height, not sprite bounds.
- Each obstacle marks a player hit before calling `hurt_player(player.x+40)`.
  Invulnerability may block damage but still consumes that obstacle's hit.
  Standing up beneath an obstacle can hurt a player who previously ducked it.
- Non-flying, non-popping robots on the bus segment are killed only with x
  strictly inside the obstacle. Arriving hop robots are exempt. The kill drops
  4–6 coins but does not add player pop credit.
- The adapter is **solo**: the native `hit` boolean represents the source Set's
  sole human player. Multi-player revival and per-player obstacle Sets remain
  outside the current host contract.

## Integration contract and order

Positions are absolute world pixels; times are seconds; velocities are px/s.
The host supplies the same basic fields as WorldOne plus `player_animation`,
`character_height()` and its `bus_ride` instance. It uses `combat.waves`,
`combat.rng`, `enemies`, `coins`, `meta`, `level`, `level_id`, `camera`, `hearts`,
`player`, `boss`, `mode`, `status`, `sfx`, `hurt_player` and `add_coins`.

1. Set level metadata and player, reset generic scene/geometry and combat, then
   call **`bus_ride.reset(host)` after `combat.reset(host)`**. This ordering is
   required to gate the twelve otherwise-zero-trigger waves. Reset on all level
   switches so another stage cannot retain an enabled bus module.
2. In `combat.spawn`, call `bus_ride.spawn(host, side, kind)` before any generic
   ground spawn or tiny/mini dispatcher. If it returns true, stop spawning there.
3. Keep shared player motion, camera, wave processing, enemy hop/AI, projectiles,
   coins, flyers, skills and receipts in their usual source order. At the
   objective point immediately after waves, dispatch the bus objective only
   when the selected native stage is 1-3.
4. At the very end of the scene update, **after receipt/card/slide updates**,
   call `bus_ride.tick(dt, host)`. Do not call it twice or move it before waves:
   newly armed fights are intentionally first processed next frame.
5. On `"ending"`, use the original `endBanner`/`endSay`/`endSub` and honk. On
   `"clear"`, use the normal host completion/save/coin-banking path and
   `meta.text.cleared` ("Bus ride survived!"). The module never saves progress
   or invokes Jar Thief itself.

The public rendering state is `drive`, `roof_y`, `warn_time`, `obstacles`
(`{k,x,w,hit}`), and `scooters` (`{x,y,vx,vy,t,face}`). These are source-shaped
coordinates. The artwork renderer uses the original metadata/images and reads
this state without changing timers, camera or collision positions. Original
skyline/town paintings, one-off embankment, rear bridge piers, bus, scooters,
shadows, foreground bridge/branch and blinking warning need their source order.

## Verification and honest limits

Run with writable isolated HOME/XDG state, as the main verification script does:

`godot --headless --path godot --script res://tests/test_bus_ride.gd`

**60 checks pass** on Godot 4.6.3. They cover source arena/data, initialization,
all transition waits and same-frame timing, spawns and hops, all robot labels,
scooter physics/lifetime, pose and boundary-sensitive obstacle collisions,
invulnerability hit consumption, environmental robot kills, pause/reset and
one-shot ending guards. A full controller fixture releases all twelve fights
in source order and encounters all 25 obstacles, holding crouch throughout.
That fixture resolves each fight after its original final spawn delay. It is
**timeline validation, not an actual player-controlled combat run**.

`godot --headless --path godot --script res://tests/test_bus_integration.gd`

**37 actual-main checks pass** for the source frame sequence, ordinary/special
spawn dispatch, first between-wave transition, knockout/pause/resume/replay,
obstacle collision and native completion/save. Continue is specifically tested
to restore three hearts and 2.5 s invulnerability **without** changing player,
camera, drive, obstacles, scooters, rest/warning timers, waves, enemies, coins,
score or collected receipts. The same overhead obstacle cannot hit again after
Continue. Unsupported 1-6 remains unable to save a false clear.

The separate `test_full_bus_run.gd` exercises the real player-control path for
all six characters through all twelve fights and 25 ducked obstacles, with a
native saved completion. Its explicit gameplay assist is **invulnerability**,
so it is progression coverage, not difficulty validation. It does not move
actors directly, skip waves, change damage, spawn enemies or invoke completion.
The separate original-art renderer has its own tests as well.

The current native milestone supports all seven World 1 stages; the other 35 stages remain
previews. Physical phone input, graphics, full audio listening, difficulty,
two-player behavior and exact VFX still require further work and playtesting.
