# Bakery input-run verification

Scope: native Godot **2-5, Bakery**, solo input-driven progression. This is not difficulty balancing, visual certification, co-op, phone device QA, deployment evidence or completion of all six worlds.

## Reproduce

From the repository root using Godot 4.6.3 and isolated writable save/cache paths:

```sh
state=$(mktemp -d /tmp/bd-bakery-run.XXXXXX)
mkdir -p "$state"/{home,cache,config,data}
HOME="$state/home" XDG_CACHE_HOME="$state/cache" \
XDG_CONFIG_HOME="$state/config" XDG_DATA_HOME="$state/data" \
  godot --headless --path godot --script res://tests/test_full_bakery_run.gd
```

The default runs Jean Phil, Maya, Ama, Leo, Theo and Mei independently. Use `-- --jp-only` or `-- --character=mei` for a focused run. `--trace` adds bounded route, wave, spawn, receipt, card and double-jump events, plus state summaries every 900 updates. Each run is bounded at 36,000 updates of 1/60 second and returns nonzero if unfinished or an assertion fails.

Each housemate begins with a fresh isolated save, no previous clear and **no earned skills**. The controller supplies only ordinary left/right, jump, down, aim, fire and the housemate's naturally charged special. **Explicit invulnerability is the sole progression assist.** It does not teleport, directly damage actors, alter waves, geometry, timers, pickups, meter, skills or scene/completion state. Audio is silenced and automatic physics is disabled to prevent duplicate uncontrolled ticks. This does not prove unassisted survival or audio quality.

Invulnerability is not a blanket course bypass: the original wet-block logic checks post-contact invulnerability, so even an already-invulnerable player receives the real −700 px/s bounce. The test preserves and checks that outcome whenever it occurs. Ordinary jump navigation can also clear a wet sign without contact. These are different observed outcomes, not a modification of the block or its timer.

## Source route and assertions

The stage is 15,000 pixels long with a 738-pixel viewport. Exact assertions preserve its one solid ground row, nine one-way platforms, four counter footprints, rack footprint, thirteen ovens, five pickup crates, thirteen flame tuples, four conveyor tuples, flour zone, two wet blocks, eight authored coin rows, three receipts and double-jump card.

The route physically climbs and traverses the conveyor platforms at 352 and the rack at 292, then the upper conveyor at 232. All four conveyors and all nine platforms, including the four deli counter tops, must have actual grounded contact. It collects receipts at `(3350,352)`, `(7600,292)` and `(13600,370)` in source index order `[0,1,2]`.

The card at `(8850,232)` must be touched using the ordinary jump, with no pre-owned skill. The test checks the source horizontal and vertical contact bounds, the card-collected flag, both real skill owners and the disk save at pickup. It then issues separate ground-jump and airborne-jump presses and observes the actual second-jump event, upward velocity and change in position. After the complete stage clear, it reloads the earned disk save through the normal level loader and repeats the real two-press double jump. Reload is never used as a mid-run shortcut.

All eleven source waves must start and finish in order at camera 400, 1700, 3300, 4800, 6200, 7200, 8800, 10600, 12000, 13300 and 14262. Their **45 solo entries** are 19 rush, 11 throw, 5 cart, 4 drone, 3 flat and 3 security bots. Wave7200 retains both security bots, at 0 and 1800 ms, and its later rush/throw entries. The test tracks actual enemy dictionaries, requires all 45 to appear, and accepts only their real popped/zero-HP defeats. A consumed entry or despawn is not substituted for a defeat. Security bots retain solo 24 HP and 58×186 extents; drones retain World2's no-fly-flag contract. Ordinary weapon damage and actual jump/down/aim/special use are required.

Source camera-dependent failed-spawn consumption is preserved. The controller descends before the upper route, waits for the real wave 7200 fight to finish on the ground, then revisits conveyor352 and climbs rack292 to belt232. The test records exact wave/entry/frame/camera/player details for any failed spawn, and fails instead of changing spawning, camera, wave timing or geometry. Returning to a lower rung after combat must complete a real landing before resuming a higher climb.

All thirteen oven positions must be crossed. Every active gameplay update compares the course phase to `(elapsed_ms + source_offset) % source_period`, with both active and warning phases observed. It preserves six 2600 ms jets and seven 2200 ms jets, the 1000 ms active interval and original collision range, including flames encountered beneath conveyor352. The course's last snapshot intentionally does not advance on the final frame: the source timed-clear check returns before the late hazard pass. Flame rendering and exact hurt/visual-boundary checks belong to their separate component/painter suites; this run is not a rendered certification.

The shop-floor flour zone 10800–12200 must be traversed on the real floor. Moving grounded frames assert the stored base speed is ±148.5 px/s, the original 270×0.55, before independent housemate bonus motion. Both actual wet blocks at 12600 and 14250 must be crossed; any contact must retain the source invulnerable bounce. All eight coin rows must appear once, at all 46 exact authored positions, with original keep-age behavior. No fall-recovery shortcut or separate invented boss is accepted.

## Door, checkpoint and exit

The door is at 9400, labeled **Shop floor**, and caps the first-scene camera at 8962. Entry requires all seven preceding waves to be complete. The 1.43-second wipe callback lands at **(9820,370)**, the actual highest deli platform, not the ground. It resets the camera to(9660,0), clears momentum/projectiles and advances the scene. The checkpoint 9500 triggers on the following update. Simulation and ordinary movement continue during the 2.17-second wipe.

The source intentionally retains `onPlat` across the callback. Because entry was from the floor, the controller walks off the first deli counter to descend instead of trying a drop-through before a fresh platform landing. This preserves source state rather than fixing it in the test. Full hearts under invulnerability demonstrate checkpoint timing, not healing after damage.

The source exit starts only after the final wave and camera 14260 or later. Exactly 155 further 60 Hz updates must elapse before the real clear. The cleared 2-5 flag, all three receipts and the earned double-jump card must survive disk reload. Imported source data must be unchanged throughout.

## Source anchors

`game/2-5/index.html`: ordinary movement/combat at408–559; wave/exit ordering at657–667; shared movement at755–769; flame/low/block pass at824–838; card/receipt pickup at1076–1090; scene logic at1116–1138; bakery configuration/painter at1170–1229. The bakery `L` uses sceneView300, sceneLand420 and noGrate=true. `game/polish.js` supplies the 1430 ms callback and 2170 ms total wipe duration. `godot/content/levels/2-5.json` holds the imported exact stage data. Native coordinates are absolute feet and timers are seconds; source player y is relative to ground482.

## Recorded verification

2026-11-09: Godot 4.6.3 check-only parser passed. The final default six-housemate command exited 0 in 14.073 wall-clock seconds, without script errors. All six passed every assertion:

| Housemate | Updates | Simulated seconds | Card pickup update | Subsequent double jump | Jumps | Earned specials | Wet-block contact frames |
|---|---:|---:|---:|---:|---:|---:|---|
| Jean Phil | 6288 | 104.80 | 3561 | 3569 | 17 | 5 | 1,1 |
| Maya | 6687 | 111.45 | 3707 | 3715 | 17 | 4 | 1,1 |
| Ama | 6946 | 115.77 | 3947 | 3956 | 18 | 5 | 0,0 |
| Leo | 7061 | 117.68 | 4202 | 4210 | 38 | 5 | 1,6 |
| Theo | 6699 | 111.65 | 3715 | 3723 | 17 | 5 | 1,1 |
| Mei | 5856 | 97.60 | 3288 | 3296 | 17 | 4 | 0,0 |

Every run completed 11 waves, defeated all 45 actual enemies, collected all 3 receipts, landed on all 9 platforms, traversed all 4 conveyors and 13 oven positions, observed all 46 authored coins and actual flour movement, crossed both wet blocks, and completed the source door/checkpoint and exact 155-update exit. There were **zero failed enemy spawns and zero falls**. The earned clear, receipts and card survived disk reload, and each housemate performed a real subsequent double jump both during the original run and after normal reload. Card/double-jump event columns are zero-based updates from the trace.

The final six-run log is `/tmp/bd-bakery-final.log`, with isolated state under `/tmp/bd-bakery-final.BqMOey`. These are local diagnostic paths, not shipped content.

Controller development found navigation problems, not gameplay-port repairs. Mei's faster travel reached the ground waypoint before the camera started wave 7200, so the initial controller climbed too soon. The final controller waits at that legitimate waypoint for the real wave to complete. It also retains a selected lower recovery rung until actually landing, instead of changing its target halfway through the jump. No actor, camera, wave or course state is edited for either behavior. A transient concurrent renderer parse error was fixed by its owner before final acceptance and is not treated as a bakery gameplay failure.

Both focused selectors and bounded trace output were exercised during development. The successful final Mei trace is `/tmp/bd-bakery-mei-dev.log`; a final JP `--jp-only --trace` rerun also passed with the same 6288 updates, recorded at `/tmp/bd-bakery-jp-final.log`.
Aggregate regression and packed-runtime checks are separate evidence. Real touch controls, visual readability, unassisted difficulty and other unported stages remain outside this regression.
