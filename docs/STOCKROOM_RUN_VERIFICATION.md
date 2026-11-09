# Stockroom input-run verification

Scope: native Godot **2-3, Stockroom**, solo input-driven progression. This is not difficulty balancing, visual certification, co-op, phone device QA, deployment evidence or completion of all six worlds.

## Reproduce

From the repository root using Godot 4.6.3 and isolated writable save/cache paths:

```sh
state=$(mktemp -d /tmp/bd-stockroom-run.XXXXXX)
mkdir -p "$state"/{home,cache,config,data}
HOME="$state/home" XDG_CACHE_HOME="$state/cache" \
XDG_CONFIG_HOME="$state/config" XDG_DATA_HOME="$state/data" \
  godot --headless --path godot --script res://tests/test_full_stockroom_run.gd
```

The default runs Jean Phil, Maya, Ama, Leo, Theo and Mei independently. Use `-- --jp-only` or `-- --character=mei` for a focused run; `--trace` adds bounded route, wave, spawn and receipt events plus state summaries every 900 updates. A run is limited to 36,000 updates at 60 Hz and returns nonzero on an unfinished route or failed assertion.

Each housemate begins with a fresh isolated save, no previous clear and no earned skills. The controller uses only ordinary left/right, jump, down, aim, fire and each housemate's own special. **Explicit invulnerability is the sole progression assist.** It does not teleport, damage enemies directly, change health, geometry, waves, timers, pickups, meter, skills, scene callbacks or completion. Audio is silenced and automatic physics disabled to prevent duplicate uncontrolled ticks. This does not verify listening or unassisted survival.

## Source route and checks

The imported stage is 14,600 pixels long with a 738-pixel viewport. Assertions preserve the exact thirteen solid rows, six tower footprints/heights, five stacks, nineteen one-way platforms, three belts, two falling-box zones, all receipt coordinates and all eleven authored wave groups.

The input route climbs the actual stacked pallets and one-way end bays to the racks at top 122 and 242, traverses all three conveyor surfaces and reaches all six tower tops, including the 480-pixel rack at top 2. It collects the rack receipt at `(8760,122)`, the chained-pallet receipt at `(9305,422)` and the highest receipt at `(11620,2)` in that physical route order. Landing on both static gap pallets is required: `[9110,9200,452]` and `[9270,9340,422]`. They are not animated pendulums. No double jump or other earned skill is available.

The goods lift is at 8910 and is a visual scene change, not a shortcut onto the highest rack. Before entry, source sceneView 120 caps the camera at 8292. The first seven waves must be complete. At the actual 1.43-second callback, sceneLand 0 and landY 476 place the player at `(8910,482)`; sceneCam 200 sets the camera to `(8710,0)` and clears momentum/projectiles. The checkpoint 8950 fires on the following update. Simulation and movement continue during the 2.17-second wipe. Full hearts under invulnerability checks checkpoint timing, not healing after damage.

All eleven waves must start/finish in order at camera 300, 1600, 3100, 4500, 6000, 6900, 8150, 9700, 10900, 12300 and 13862. There are 46 solo entries: 22 rush, 11 throw, 4 drone, 4 cart, 3 flat and 2 security bots. Actual enemies are tracked through their real combat lifecycle; a despawn is not accepted as a defeat. Security bots must retain solo 24 HP and 58×186 extents; drones retain World2's no-fly-flag contract. Ordinary projectile damage, jumps, down input, aiming and each housemate's naturally charged special must occur.

Source spawn search can legitimately consume an entry without creating an enemy when the camera height excludes every eligible solid. The test records the exact wave/entry/frame/player/camera for such failures and never changes the camera, spawn rule, wave or geometry to conceal them. Its input route should give authored enemies viable surfaces where possible; any unavoidable source behavior must be documented rather than described as a complete 46-enemy run.

Falling-box entities must appear at the real above-view position, warn for 0.95 seconds and then fall. Both authored drop zones are traversed. The six authored coin rows must create all 40 exact positions/arcs once and preserve keep-age behavior. All receipts require actual horizontal and body overlap; imported data must remain unchanged. No fall-recovery shortcut or separate invented boss is permitted.

The source timed exit starts only after every wave and camera 13860 or later, then clears after 155 further 60 Hz updates. The earned 2-3 clear and all receipts must survive disk reload. Invulnerability does not bypass this actual source end condition.

## Source anchors

`game/2-3/index.html`: `spawnBot` at lines 364–373, shared player/combat functions at 408–559, shared level hooks at 738–882, receipts at 1080–1094, scene hooks at 1116–1138, and stage-specific `L` at 1176 (`sceneView:120`, `sceneLand:0`, `sceneCam:200`, `landY:GROUND-6`). `game/polish.js` provides the wipe's 1430 ms callback and 2170 ms total duration. `godot/content/levels/2-3.json` contains the source geometry, wave groups, hazards and pickups. Native coordinates are absolute feet; source player y is relative to ground 482. Native timers are seconds rather than source milliseconds.

## Recorded verification

2026-11-09: Godot 4.6.3 check-only parser passed. After native integration, the complete six-housemate command exited 0 in about 9.3 wall-clock seconds with no script errors. Every run passed all assertions:

| Housemate | Updates | Simulated seconds | Jumps | Earned specials | Real falling boxes |
|---|---:|---:|---:|---:|---:|
| Jean Phil | 5930 | 98.83 | 24 | 5 | 18 |
| Maya | 5933 | 98.88 | 24 | 4 | 17 |
| Ama | 6060 | 101.00 | 23 | 4 | 18 |
| Leo | 6082 | 101.37 | 41 | 5 | 18 |
| Theo | 5932 | 98.87 | 23 | 4 | 17 |
| Mei | 5407 | 90.12 | 25 | 4 | 18 |

Every run observed 11 completed waves, all 46 actual enemies defeated, all three receipts, all six tower tops, both chained pallets, all three belts, boxes warning/falling in both authored zones, all 40 authored coins, the real lift and next-update checkpoint, and the exact 155-update exit. There were **zero failed enemy spawns and zero falls**. Actual clears and receipt order `[1,0,2]` survived disk reload. The route lands on 15 of the 19 authored platforms; the other four optional lower rungs are preserved by exact geometry assertions, not claimed as landings.

The final six-run log is `/tmp/bd-stockroom-final.log` in the verification workspace; isolated save/cache state is `/tmp/bd-stockroom-final.y8xHAb`. These are local diagnostic paths, not shipped game content.

Controller development exposed two navigation problems, not port repairs. Combat originally stopped the player below an elevated drone and failed to return for a lower stranded robot. The final input route prioritizes the ordinary robot, backtracks via real ledges, then permits the next rack climb before aiming at the drone. Leo's still-active glider after the lift clamps upward velocity, making the first raised pallet unreachable with a normal brief jump at that moment. The controller waits on the safe bank until the real special expires, then crosses normally. It never edits special duration or velocity. No source spawn/camera rule was changed for the test.

Both `--jp-only` and `--character=leo --trace` were exercised during development. The final default six-housemate run and subsequent final `--jp-only --trace` run both passed; the six-housemate run is the recorded acceptance result. There is no rendered/device pass claimed here.

Aggregate regression and packed-runtime checks are separate evidence. Real touch controls, visual readability, unassisted difficulty and other unported stages remain outside this regression.
