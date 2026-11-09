# Shopping bonus input-run verification

Scope: native Godot **2-S, Sample sprint**, solo progression with all six housemates. This is not unassisted difficulty testing, visual parity certification, co-op or Android/iOS device QA, a packed-artifact check, or deployment evidence.

## Reproduce

Run from the repository root with Godot 4.6.3 and writable, isolated state:

```sh
state=$(mktemp -d /tmp/bd-shopping-run.XXXXXX)
mkdir -p "$state"/{home,cache,config,data}
HOME="$state/home" XDG_CACHE_HOME="$state/cache" \
XDG_CONFIG_HOME="$state/config" XDG_DATA_HOME="$state/data" \
  godot --headless --path godot \
  --script res://tests/test_full_shopping_bonus_run.gd
```

The default command runs Jean Phil, Maya, Ama, Leo, Theo and Mei. Append `-- --jp-only` or `-- --character=mei` to select one. Add `--trace` for a bounded trace every 1,200 updates and each wave completion. Unknown character names exit nonzero. Each housemate starts with a freshly written save, no stage clear and no earned skills. Each progression run is bounded at 12,000 updates, or 200 simulated seconds, and failed assertions cause a nonzero exit.

## Executable source policy

`game/2-S/index.html` declares `const L = {}` at 1172. Its sunny shopping street painter places nine decorative stalls but adds no colliders, objective controller, refrigerator, treat or timer callback. The imported JSON retains `timer:100000`, and the original prose says 100 seconds, but that metadata does not drive the executable stage. As recorded in `WORLD_TWO_IMPLEMENTATION.md`, completion is ordinary camera distance plus completed waves, followed by the shared 2.6-second exit. This regression preserves that behavior rather than creating a timed redesign.

A **separate NONPROGRESSION fixture** advances 6,300 normal updates, or 105 seconds, with no input. It does not edit any clock or actor. The player/camera remain at their source start, no waves start, no rewards or hazards appear, and neither memory nor disk has a clear. It verifies that the stage remains in play past 100 seconds. This idle fixture is never presented as a completed route and is reset before every progression run.

## How progression is exercised

The real main scene advances at 60 simulated updates per second using normal left/right, jump, down, aim, shoot and special input dictionaries. **Invulnerability is the only progression assist.** The test never changes player/enemy position or health, applies enemy damage, skips waves, changes timers or geometry, grants power or special meter, manufactures pickups, invokes completion, or preloads movement skills. Automatic physics processing is disabled solely to avoid a second uncontrolled tick. The silent test audio adapter is not an audio-quality test.

The controller walks toward the next receipt or the exit, shoots actual enemies, uses a naturally charged special during combat, jumps among the sample coins, and briefly aims while travelling. It stops before the low crate at x4500 and uses crouch shots, since standing shots pass above the crate. It then walks to the real dropped split-shot item and fires the actual power-up. No stall needs to be climbed because stalls are paintings, not surfaces. All receipts are collected through source body overlap; none requires an earned double jump.

## Assertions

- The original 9,000px stage, 738px view, start `(300,482)`, road `[-400,9400,482]`, no platforms, nine exact stall positions, one 3HP split crate, two solo wave groups, 22 coin rows and all three receipt coordinates remain intact. No scene, checkpoint, boss, refrigerator, extra hazard or earned skill is introduced.
- Waves start only at their source camera triggers 2,000 and 5,200. Their four solo entries dispatch at source delays 0/900ms and 0/800ms: three 3HP rush bots and one 2HP cart, all from the right. All four actually appear and die through gameplay, rather than being abandoned or merely marked done. The last wave completes on the update after its final enemy dies.
- All nine stall centers are crossed through ordinary movement. Runtime collision remains one solid road and no platform throughout the route.
- All 22 authored coin rows create 128 coins once, at their original interpolated positions and sine arcs. Resting authored coins retain their source 2-second keep-age cap. Actual coin pickups are observed separately from creation and end-of-stage banking. The route does not promise every character collects every coin.
- The actual crate takes ordinary projectile damage, breaks, creates a split item, grants it by contact, and produces split projectiles. Every housemate performs a naturally charged special, an upward launch, crouch shooting, aiming and ordinary projectile damage.
- Receipts at `(2000,362)`, `(5300,362)` and `(8200,482)` are observed at horizontal/body contact with the World 2 `y−30` lower bound. All three persist after save reload.
- The exit begins only with both waves complete and camera≥8,260. It clears after 155 additional 60Hz updates beyond the first observed active exit frame, preserving the source 2.6-second timer. Remaining actual coins are banked exactly once. Clear, receipts and the banked total survive disk reload. A further 180 updates after clear cannot duplicate rewards or alter the save.
- Imported source data is unchanged at completion. No abrupt player teleport or fall-safe recovery occurs. The earned-skill arrays and saved skills remain empty.

## Source anchors

`game/2-S/index.html`: shared `updatePlay` 633–673 defines camera, wave and end order; `lvStart` 738–747 and `lvReadyEnd` 748 reset/resolve common state; `lvUpdate` 771 onward spawns the authored coins and caps resting keep-age; `LEVEL_WAVES` 1059 concatenates co-op extras only when requested; `updatePicks` 1080–1094 uses the source receipt contact rectangle. The stage-specific empty `L` and decorative street/stall painter are at 1170–1186. `godot/content/levels/2-S.json` contains all original geometry, waves, crate, coin rows, stall coordinates and receipts. Readable executable functions were inspected without printing embedded asset lines.

Native positions use absolute feet coordinates and clocks use seconds. The source player y is relative to ground 482 and its clocks use milliseconds.

## Recorded result

Verified on **2026-11-09 with Godot 4.6.3**, fresh isolated HOME/XDG state and fresh saves. The standard six-housemate run passed with no engine script errors. The separate 105-second idle fixture remained in play with no reward or clear. No source gameplay or receipt-reachability blocker was found.

| Housemate | Updates to clear | Authored coins contact-collected | Upward launches | Specials | Banked score |
| --- | ---: | ---: | ---: | ---: | ---: |
| Jean Phil | 2127 | 128 | 19 | 1 | 171 |
| Maya | 2129 | 120 | 19 | 1 | 158 |
| Ama | 2131 | 122 | 19 | 1 | 158 |
| Leo | 2087 | 117 | 18 | 1 | 155 |
| Theo | 2127 | 120 | 19 | 1 | 158 |
| Mei | 1836 | 119 | 15 | 1 | 156 |

Every row also passed 2/2 waves, 4/4 actual enemy kills, 3/3 receipts, 9/9 stalls, 128/128 authored coin creation positions, the genuine split-crate sequence, 155 additional exit ticks, and reloaded clear/receipts/reward. The upward-launch counter includes Leo's source special launch, not only jump-button presses. Scores also contain enemy/ability coins, receipt rewards and eligible loose coins banked at clear; they are not a claim that all authored coins were contact-collected.

The focused Jean Phil trace and named Mei selector were checked separately. The aggregate native suite and packed artifact must be checked by their respective scripts; this focused verification does not claim those broader checks. Human touch controls, visual composition, unassisted survival and later stages still need their own QA.
