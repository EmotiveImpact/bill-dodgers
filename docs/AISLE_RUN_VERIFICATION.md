# Aisle seven input-run verification

Scope: native Godot **2-2, Aisle seven**, solo progression. This is not six-world completion, difficulty balancing, visual parity certification, co-op verification, Android/iOS device QA or deployment evidence.

## Reproduce

Run from the repository root using Godot 4.6.3, with isolated writable save and cache directories:

```sh
state=$(mktemp -d /tmp/bd-aisle-run.XXXXXX)
mkdir -p "$state"/{home,cache,config,data}
HOME="$state/home" XDG_CACHE_HOME="$state/cache" \
XDG_CONFIG_HOME="$state/config" XDG_DATA_HOME="$state/data" \
  godot --headless --path godot --script res://tests/test_full_aisle_run.gd
```

The standard command runs Jean Phil, Maya, Ama, Leo, Theo and Mei independently. Append `-- --jp-only` or `-- --character=mei` to select a focused run. `--trace` adds wave, switch, gate and receipt events plus a compact state report every 900 updates. Each run is bounded at 36,000 updates. The test exits nonzero on assertion failure or an unfinished route. Retain the isolated state directory and engine output for investigation.

Every housemate starts from a fresh save with no earned skills or existing 2-2 clear. The controller advances the real main scene at 60 simulated updates per second through its normal left/right, jump, down, aim, shoot and special input dictionary. **Invulnerability is the sole progression assist.** It never changes actor positions, health, damage, geometry, waves, gate states, timers, skill unlocks, ability charge, pickups or completion. It does not call switch hooks, scene callbacks or clear functions. Turning automatic physics processing off only prevents a second uncontrolled simulation tick. The silent audio adapter keeps the regression inexpensive; this is not listening QA.

## Source route

The route activates the yellow plate at x1900 and passes the shelf gate at x2500, collecting the first receipt at `(3700,246)` and climbing the real shelf tiers at y364 and y246. Standing shots from the upper shelf reach the high button at `(4370,152)`, which opens gate x4500. The route then activates plate x5950 for gate x6500, climbs the receipt shelf around `(8300,246)`, and crosses the two consecutive plate gates at x9200 and x9700 using their separate pads at x8750 and x9450.

After clearing the preceding seven waves, it enters the actual frozen-foods door at x10400. The source callback moves the player to `(10820,482)` and camera to `(10660,0)`; the checkpoint at x10500 occurs on the next update. This authored scene movement is distinguished from a test teleport. Left/right input and simulation continue while the visual wipe is active.

In frozen foods, real shots hit the low button at `(11650,372)` to open gate x12000. The route climbs the shelf at the final receipt `(12880,246)`, then uses down+jump to descend to the floor before moving into the next wave. It activates plate x13450 and crosses the final gate at x14000. Ordinary countersteering inputs compensate for the icy floor. The final waves and the source timed endpoint earn the clear; the controller never awards it.

Combat has priority over route movement. If a shot button lies between the player and a ground enemy, the controller walks past that button before firing back toward the enemy. Actual projectiles defeat ordinary robots, upward shots target barcode drones, down+jump drops from one-way shelves when ground combat is needed, and specials are pressed only after the real meter is charged. A plate can be revisited through normal movement if combat has consumed its open interval. Receipts use the source body-overlap test, not an invented feet-only collision test. Reaching each receipt shelf's actual upper surface is additionally required, including the high-button shelf.

## Assertions

- Original width15200/view738, start300, ground482, one solid floor, seven exact island intervals and fourteen exact shelf platforms, all three receipts, scene boundary10400, door label and checkpoint10500 remain unchanged.
- All ten source waves start and finish in order at camera positions400,1250,2800,4800,6800,7800,9900,11000,12600,14462. Every one of43 solo entries produces an actual enemy:19 rush,11 throw,4 drone,4 cart,3 flat,2 big. Every observed enemy must be defeated, not silently despawned. Security bots retain solo24HP and58×186 extents; drones retain the World2 contract.
- All five real plates activate under grounded contact; their matching gate timers are the source5.2s. Both real buttons produce the source impact flash. A gate cannot open before an observed matching activation, and the player must pass all seven with open collision geometry. The high-button and all receipt shelves must be actually climbed.
- Ordinary damage, jumps, upward aiming, down input and each housemate's own earned special are observed. There is no invented separate boss, fall-recovery shortcut or earned skill.
- Scene0 clamps player x10400 and camera x9962. Door entry requires x10350 and the first seven completed waves. At1.43s the actual callback resets player/camera/momentum/projectiles. The checkpoint is next-update and the visual wipe lasts2.17s. Full hearts under invulnerability verifies timing, not injured-player healing.
- Both falling-box and icicle entities appear at their actual above-view spawn position, spend the source0.95s warning phase, and fall through real updates. More than100 updates exercise grounded frozen-floor movement. This is hazard execution coverage, not an assertion that the assisted player can be hurt.
- All twelve authored coin rows create all70 exact positions and sine arcs once. Resting authored coins retain the source2s keep-age cap. Creation is observed; collecting every coin is not required.
- Each receipt is observed during real horizontal/body contact. The timed exit starts only at camera14460 or later with every wave done and clears after155 further60Hz updates. The actual in-memory clear and all three receipts survive a disk reload. Imported data is unchanged throughout.

## Source anchors

`game/2-2/index.html`: shared `lvStart`738–746, `lvMove`757–770, `lvUpdate`771–841, `lvShot`860–863, `updatePicks`1080–1094, `sceneUpdate`1122–1138, and Aisle seven's `L`1176 (`sceneView:300`, `sceneLand:420`). `game/polish.js` supplies the labelled wipe callback at520+1050−140=1430ms and total duration520+1050+600=2170ms. `godot/content/levels/2-2.json` supplies the lossless source layout, wave groups, hazards and pickups. Readable source functions were inspected without dumping embedded asset data.

Native positions are absolute feet coordinates and timers are seconds; the source player y is relative to ground482 and timers are milliseconds.

## Recorded result

Verified on 2026-11-09 with Godot4.6.3 and isolated writable HOME/XDG directories. The final standard six-housemate command passed with no engine script errors. The check-only parser, `--jp-only`, named `--character=mei` selector and bounded `--trace` path were also exercised.

| Housemate | Updates to clear | Upward launches / specials | Door trigger / callback / finish | Checkpoint update | Observed drops |
| --- | ---: | ---: | --- | ---: | ---: |
| Jean Phil | 5677 | 6 / 5 | 3547 / 3633 / 3678 | 3634 | 16 |
| Maya | 6482 | 6 / 5 | 3613 / 3699 / 3744 | 3700 | 21 |
| Ama | 5910 | 6 / 4 | 3638 / 3724 / 3769 | 3725 | 17 |
| Leo | 5834 | 10 / 4 | 3598 / 3684 / 3729 | 3685 | 16 |
| Theo | 5802 | 6 / 4 | 3539 / 3625 / 3670 | 3626 | 17 |
| Mei | 5708 | 7 / 4 | 3258 / 3344 / 3389 | 3345 | 19 |

Door/checkpoint columns use zero-based update indexes. Upward launches count actual grounded-to-air upward transitions, including Leo's source special, rather than implying every launch was a jump-button press. Every row passed10/10waves,43/43actual defeated enemies,5/5plates,2/2shot buttons,7/7opened-gate passages,3/3receipts,70/70authored coin positions, both falling-stock types, actual shelf climbing, zero fall recoveries,155additional exit ticks, and disk-reloaded clear/receipts.

### Preserved source behaviors found during route verification

The initial route walked off the final receipt shelf and triggered wave8 while the vertical camera was still high. At camera `(12599.58,-172.3457)` and player `(12981.67,290.25)`, the wave consumed its opening cart entry without creating an enemy. Original `spawnBot` line369 only considers non-platform floors satisfying `top < camY + VH + 60`; ground482 was outside that window. The source consumes the entry even when placement fails. This is preserved source behavior, **not a native repair or an all43-enemy pass**. The final controller descends through real down+jump inputs and waits for the camera to ease before walking into camera12600. Its stricter actual43-enemy assertion remains intact. Other routes can still encounter the source skipped-spawn behavior.

Ice drift can also leave a housemate to the right of the low green button while an enemy is to its left. Source shot interception then absorbs shots at the button. The controller now walks past the intervening button using ordinary input rather than waiting for incidental crouched shots to hit the enemy. No shot-hook order, gate timer, enemy or geometry was changed.

A test-only strict comparison of the initial drop y coordinate was changed to a small numeric epsilon because native Vector2 uses float precision. No gameplay assertion or warning duration was relaxed.

The aggregate regression and packed-artifact checks are separate evidence. Device touch behavior, visual composition, unassisted survival/difficulty and other unported stages still need their own verification.
