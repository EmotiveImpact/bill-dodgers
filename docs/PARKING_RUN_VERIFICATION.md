# Parking stage input-run verification

Scope: native Godot **2-1, Car park**, solo progression. This is not six-world completion, difficulty balancing, visual parity certification, co-op verification, Android/iOS device QA or deployment evidence.

## Reproduce

Run from the repository root with Godot 4.6.3. Keep game saves isolated from personal data:

```sh
state=$(mktemp -d /tmp/bd-parking-run.XXXXXX)
mkdir -p "$state"/{home,cache,config,data}
HOME="$state/home" XDG_CACHE_HOME="$state/cache" \
XDG_CONFIG_HOME="$state/config" XDG_DATA_HOME="$state/data" \
  godot --headless --path godot --script res://tests/test_full_parking_run.gd
```

The standard command runs Jean Phil, Maya, Ama, Leo, Theo and Mei separately. Append `-- --jp-only` or `-- --character=mei` for focused investigation. `--trace` prints periodic state and wave completions. Every housemate starts from a new save, without earned skills or a pre-existing stage clear. The test exits nonzero on failed assertions or a bounded route that does not finish. Retain the `/tmp` directory and engine log when investigating a failure.

## Progression evidence and limits

The test advances the real main scene at 60 simulated updates per second using its normal left/right, jump, down, aim, shoot and special input dictionary. **Invulnerability is the sole progression assist.** It does not set player/enemy positions, health, enemy damage, wave indexes, timers, power meters, pickups or completion. It does not change geometry or invoke the exit directly. Disabling automatic physics processing only prevents a second, uncontrolled simulation tick. The silent audio adapter avoids synthesizing sound during the headless run; it is not audio QA.

The source lift itself moves the player to another scene. The regression distinguishes that authored callback from a test teleport, and rejects other abrupt horizontal displacement. Full-health checkpoint behavior in the assisted run proves checkpoint timing, not healing an injured character. Focused host-integration fixtures cover healing and same-frame revive separately, without using those fixtures as progression evidence.

The route first walks left from x300 to the receipt at x80 while camera x remains zero. It then walks through the authored stage, pauses to shoot actual enemies, aims at barcode drones, drops from car platforms if necessary, and uses actual earned special-meter activations. The elevated receipts at `(3920,269)` and `(12120,269)` use source body overlap, not feet-on-platform overlap: an ordinary jump from the road can collect them. Their nearby high van roofs do not require a manufactured pickup or an unearned double jump.

## Assertions

- Original width16000/view738, ground482, one solid road, thirteen platforms, all three exact receipt positions, lift x7600, start300 and scalar checkpoint7700 remain unchanged.
- All eleven source waves start and finish in order at camera positions500,1500,3000,4300,5600,6880,8200,9700,11900,13300,15262. All52 solo authored spawn entries dispatch and produce actual enemies. All eight numeric entries appear at their original x positions. Both security bots have solo24HP and source58×186 hit extents; all three barcode drones appear, without the World1 flyer flag.
- Actual ordinary projectile damage, normal jumps, upward aiming and each housemate's own special occur. Parking never invents a separate boss objective.
- Before the lift, scene0 clamps the player at x7600 and camera at7162. Only after the first six waves finish can x7550 trigger the lift. Simulation and left/right inputs continue during the wipe. Its callback occurs at1.43s, lands at `(8020,482)`, resets camera to `(7860,0)`, clears velocity/projectiles, and leaves the player grounded. The checkpoint occurs on the next update, and the visual wipe ends at2.17s.
- All four autonomous trolley spawners finish their3/5/4/3 batches, producing15 actual hazards at360–440px/s. These are distinct from cart enemies and do not become wave blockers.
- All thirteen authored coin rows generate their73 exact positions and sine arcs once. Resting authored coins retain the source2s keep-age cap. This observes their creation, not a claim that every coin is collected.
- Each receipt is observed at real horizontal/body contact using the World2 y−30 lower bound. All three persist after a save reload.
- The exit starts only at the actual camera endpoint with every wave done. The source2.6s exit takes155 additional60Hz ticks after its first observed active frame, then produces a real clear and a persisted2-1 clear. Source data remains unchanged and no earned movement skill appears.

## Source anchors

`game/2-1/index.html`: `spawnBot`364–373, `updatePlay`633–673, `lvUpdate`771–841, `updatePicks`1080–1094, `sceneUpdate`1122–1138. Parking's `L` at1176 sets `sceneView:300` and `sceneLand:420`. `game/polish.js` defines the labelled wipe callback as520+1050−140=1430ms and total duration520+1050+600=2170ms. `godot/content/levels/2-1.json` supplies original geometry, wave groups, hazards and receipt positions. Readable source functions were inspected without printing embedded asset lines.

Native positions are absolute feet coordinates and timers are seconds; the source player y is relative to ground482 and timers are milliseconds.

## Recorded result

Verified on 2026-11-09 with Godot4.6.3, fresh isolated saves, using the standard six-housemate command. All six runs passed with no engine script errors. The initial Jean Phil focused run and check-only parser also passed.

| Housemate | Updates to clear | Upward launches / special activations | Lift trigger / callback / finish | Checkpoint update |
| --- | ---: | ---: | --- | ---: |
| Jean Phil | 6093 | 2 / 6 | 2834 / 2920 / 2965 | 2921 |
| Maya | 6136 | 2 / 5 | 2882 / 2968 / 3013 | 2969 |
| Ama | 6156 | 2 / 5 | 2880 / 2966 / 3011 | 2967 |
| Leo | 6178 | 7 / 5 | 2839 / 2925 / 2970 | 2926 |
| Theo | 6099 | 2 / 5 | 2815 / 2901 / 2946 | 2902 |
| Mei | 5538 | 2 / 4 | 2587 / 2673 / 2718 | 2674 |

The lift/checkpoint columns use zero-based update indexes. The jump counter observes ground-to-air upward transitions, including Leo's source special launch, rather than claiming all seven Leo transitions were jump-button presses. Every row also passed11/11waves,52/52actual enemies,8/8numeric spawns,3/3receipts,15/15trolleys,73/73authored coin positions, zero fall recoveries,155additional exit ticks and disk-reloaded clear/receipts. A separate `--character=mei` run verified the named-character selector.

Two test-only issues were corrected during integration: nested JSON numeric values needed value comparisons rather than Godot's type-strict nested array equality; and Mei can finish wave6 and trigger the lift in the same update, so the lift assertion inspects authoritative current wave state instead of a not-yet-refreshed observer list. Neither required a gameplay change. No receipt reachability blocker was found.

The full engine's aggregate regression and packed-artifact checks are reported by their respective scripts, not inferred from this focused test. Device touch behavior, visual composition, unassisted survival/difficulty and the remaining unported stages still require their own verification.
