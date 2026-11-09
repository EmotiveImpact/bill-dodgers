# Trolley dash input-run verification

Scope: native Godot **2-4, Trolley dash**, all six solo housemates. This is source-grounded, input-driven progression with explicit invulnerability, not unassisted difficulty balancing, visual certification, co-op, phone-device QA, deployment evidence or completion of all six worlds.

## Reproduce

From the repository root, with Godot 4.6.3 and isolated writable save/cache paths:

```sh
state=$(mktemp -d /tmp/bd-trolley-run.XXXXXX)
mkdir -p "$state"/{home,cache,config,data}
HOME="$state/home" XDG_CACHE_HOME="$state/cache" \
XDG_CONFIG_HOME="$state/config" XDG_DATA_HOME="$state/data" \
  godot --headless --path godot --script res://tests/test_full_trolley_dash_run.gd
```

The default executes the separately labelled elapsed-par fixture, then Jean Phil, Maya, Ama, Leo, Theo and Mei from clean saves. Use `-- --jp-only` or `-- --character=mei` to select a housemate. Add `--trace` for receipt/wave events and a bounded state summary every 1,200 updates. Each progression run is capped at 30,000 updates at 60 Hz; an incomplete run or failed assertion returns nonzero. The selected-character flags do not skip the elapsed-par fixture.

## Source and test boundaries

Sources: `game/2-4/index.html`, the corresponding `godot/content/levels/2-4.json`, and `WORLD_TWO_IMPLEMENTATION.md`. Relevant HTML anchors are shared player/combat code at lines 364–559, `lvStart` at 738–747, `lvAuto` at 749–754, `lvUpdate` at 771–841, low/block collision at 825–828, receipts at 1080–1094, and the Trolley dash painter/HUD at 1170–1212. Native positions are absolute feet in pixels, velocities pixels/second and timers seconds; source player y is relative to ground 482 and source timers use milliseconds.

The only gameplay-state write during a run is `game.invincible = 999` before each update. All movement, jumping, crouching, aiming, firing and specials use the ordinary input dictionary passed to the actual main-scene `step`. The test does not teleport, set actor health/damage/velocity, change geometry, force a pickup, generate enemies, advance a wave/timer, add a skill, fill an ability meter, bypass a spawn restriction or call completion. Fresh-save setup is not a gameplay reward. Housemate abilities charge and activate naturally.

**Invulnerability changes contact outcomes, including motion.** The source block pass applies upward velocity −700 whenever a colliding player's post-damage invulnerability exceeds 1.4 seconds, even when damage did not occur. The test preserves this rule, records every block-contact/bounce frame, and does not label an airborne block-center crossing a completely contact-free jump. Runaway-trolley contact frames are also reported. These runs demonstrate achievable progression with this sole assist, not a damage-free human route.

## What the full route verifies

- All source flat terrain: start `(330,482)`, solid `[-400,40400,482]`, no platforms, world width 40,000 and view width 738. Obstacles and runaway trolleys never become supporting geometry. No fixed bus arena, scene transition or invented boss is permitted.
- Every exact block tuple (36), low-sign tuple (14), boost interval (7), both runaway-trolley batches and all three receipt coordinates. The 43 authored coin rows emit all 243 coins once. Imported data remains unchanged.
- The camera is genuinely variable scrolling. Each update independently checks the source recurrence: base speed 200; boost probe at old camera plus 0.4 × 738; boost factor 1.55; pre-wave-update active-wave factor 0.6; forward-player push clamped to 0–120; and approach factor `dt / 0.7`. Camera displacement is speed × dt, capped at 39,262. All seven boost entries and exits, wave slowdown, forward push and left-edge pressure occur. Waves never lock this camera. The test verifies players move independently rather than riding a shared moving deck.
- Every housemate issues a real ordinary jump approaching all 36 blocks and crosses each block center above its harmful feet threshold. All 14 signs are actually crossed while grounded and crouching, with standing body top inside the sign but crouched body top below its underside. The additional ride-body offset is 12 pixels. There are zero sign-contact frames; this is measured from actual collision geometry, not inferred from preserved hearts.
- All 13 authored wave triggers, solo entry delays, sides and enemy kinds are checked. Each run consumes 40 entries and creates all 40 actual enemies: 22 cart, 9 throw, 4 rush, 2 drone, 2 flat and 1 security bot. The security bot retains 24 HP and 58×186 hit extents. Drones retain the source no-fly-flag contract. Every enemy is tracked to actual `pop`; disappearance/abandonment cannot substitute for a defeat.
- Source spawn eligibility remains unchanged. A failed spawn is recorded with its exact wave, entries, update, camera and player coordinates and fails the full-inventory assertion. These successful routes require no retries or altered placement rules. Leo uses ordinary down input to land his glider; no vertical position or camera correction is injected.
- All seven positive-direction runaway trolleys spawn from camera −90 after camera 19,500, and all four negative-direction trolleys spawn from camera +828 after camera 31,000. First spawns occur immediately at those source camera thresholds. Following spawns are exactly 45/54 updates apart (750/900 ms), retain 360–440 px/s speed and receive their first movement update immediately.
- The source checkpoint at camera midpoint 20,000 fires once. All three receipts `(9000,312)`, `(21000,312)` and `(33000,312)` require real horizontal and body overlap. No double jump or other earned skill is inherited or added.
- Ordinary projectile damage, aiming, down input, jumping and each character's own naturally charged special occur. The final wave completes on the update after the final enemy dies. The actual distance/wave objective starts only with all 13 waves complete and camera at least 39,260. It clears after 155 further 60 Hz updates, matching the source strict greater-than-2.6-second rule including its initial 1 ms.
- Every earned clear, all three receipts and actual banked coins survive `SaveStore.read_save()` from disk. A further 180 updates after clear cannot duplicate the reward or change the persisted result. Every character starts with a new empty save, including no previously earned skills.

## Elapsed clock is not a deadline

The separately labelled **NONPROGRESSION fixture** runs 12,660 ordinary updates (211 seconds) with no movement, shooting or special input and only the disclosed invulnerability. The automatic camera and all authored threats continue normally. At 211 seconds it is still in play at camera **27,674.943359375**, without an end timer or saved clear. This verifies that the elapsed clock and “par 3:30” are presentation, not a time-gated loss or completion. It is not included among the six completed routes or used to earn their rewards.

## Recorded verification

2026-11-09, Godot **4.6.3.stable.official.7d41c59c4**: check-only parser passed. The final default command, including the 211-second elapsed-par fixture and exact trolley-interval assertions, exited **0**. Every assertion passed for all six housemates with no script errors or leaked-object warnings. The earlier JP trace and six-housemate run produced the same progression results.

| Housemate | Updates | Simulated seconds | Real jumps | Earned specials | Block-contact/bounce frames | Runaway-trolley contact frames | Camera speed range, px/s |
|---|---:|---:|---:|---:|---:|---:|---:|
| Jean Phil | 12,000 | 200.00 | 39 | 7 | 10 | 198 | 120.16–309.05 |
| Maya | 12,208 | 203.47 | 39 | 7 | 14 | 202 | 120.09–308.95 |
| Ama | 12,234 | 203.90 | 39 | 7 | 7 | 198 | 120.09–309.06 |
| Leo | 12,091 | 201.52 | 39 | 7 | 58 | 202 | 120.09–308.96 |
| Theo | 12,260 | 204.33 | 39 | 7 | 20 | 197 | 120.06–309.07 |
| Mei | 11,964 | 199.40 | 39 | 7 | 26 | 191 | 120.14–318.79 |

Every route recorded **13/13 completed waves, 40/40 actual enemy kills, 3/3 persisted receipts, 36/36 airborne block-center crossings with ordinary jump approaches, 14/14 safe crouch passages, 11/11 runaway trolleys and the real 2.6-second exit**. No failed spawn, abandoned enemy, fall-recovery shortcut or unearned skill was observed. The listed contact numbers are frames, not unique obstacles, damage events or proof of safe difficulty. Leo's extra block-bounce frames in particular must not be hidden by the all-receipts/all-enemies result.

This suite does not certify renderer pixels or touch controls, and it does not exercise a death/Continue transition because invulnerability prevents death. Those remain separate integration/device checks. No commits, exports, deployment or visibility changes are performed by this test.
