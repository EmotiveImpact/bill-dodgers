# Moving Day acceptance: physical collectibles and completed routes

This report supplements `WORLD_FIVE_IMPLEMENTATION.md`. It distinguishes complete input-driven runs from isolated interaction fixtures. It does **not** establish unaided difficulty, human usability, native export readiness, screenshot parity or physical-device performance.

## Source boundaries

The source is the unchanged `game/5-*/index.html` META and W5 runtime. Receipt proximity is strictly `abs(dx) < 36`, `abs(feet_y - receipt_y) < 90`; the wall-jump card uses `< 44` / `< 110`. The source pickup pass is immediately after mover/lift updates (`game/5-4/index.html`, lines 934–940). Receipts do not award score in World 5.

The wall-jump card is authored in **5-4**, at `(3560, 482)`. Stage 5-3 has no card; it is the lift stage. Native `movement_skills.gd` matches this source placement. No card was moved.

The only receipt placement changes remain the four existing, explicitly documented first-receipt repairs, from unreachable `x=-250` to `x=60` in 5-1, 5-2, 5-4 and 5-6. Original META rows and zero-based native save identities remain unchanged. This acceptance work found no further unreachable receipt requiring a production repair. The King finite-feet repair and van spawn-deck repair remain as documented elsewhere; no production file was changed by this work.

| Stage | Receipt 0 runtime feet coordinate | Receipt 1 | Receipt 2 |
|---|---|---|---|
| 5-1 | (60, 482), repaired | (4290, 32) | (9390, -628) |
| 5-2 | (60, 482), repaired | (11510, 362) | (27790, 482) |
| 5-3 | (60, -178) | (560, -1828) | (60, -2818) |
| 5-4 | (60, 482), repaired | (5850, 242) | (3952, 192) |
| 5-5 | (540, 298) | (240, 300) | (380, 290) |
| 5-6 | (60, 482), repaired | (2096, 370) | (3900, 482) |
| 5-S | (1970, 152) | (14570, 152) | (27170, 152) |

## Complete-stage acceptance

**Final clean matrix: 42/42 completed routes, 354/354 assertions, all three receipts collected in every route.** All six characters passed all seven stages. Godot exited zero, and the complete log contains no engine/script errors or leak warnings. Completion times ranged from **36.9 to 335.8 simulated seconds**; total wall time was **219 seconds** in the shared executor.

`godot/tests/test_full_moving_day_runs.gd` now seeks all three physical receipts by default, rather than merely completing the objective. The driver starts at the actual stage spawn. Initial cards are slide, double-jump, ground-pound and dash, representing the preceding worlds' earned cards. Wall-jump is acquired physically in 5-4.

The sole live assist is repeated invulnerability. After `load_level`, the test never writes player position, velocity, camera, health, geometry, waves, boss state, kills, clock, pickups or clear state. It uses ordinary left/right/jump/down/shoot inputs and observes the resulting state. Scene travel remains the game's own transition callback. No receipt, card or jar is marked collected by the test.

Assertions include:

- All three receipts physically collected and persisted as exactly indices 0, 1 and 2, every authored wave done, immutable imported META and normal clear mode.
- Host/world simulated clocks agree on every frame. Normal stages run the actual 2.6-second end countdown, measured to discrete-frame tolerance.
- Exact completed-stage persistence and one-time banking of the run score; further clear-mode frames cannot pay again. Receipt reward remains zero.
- 5-2: actual sofa carry, doorway tipping, all five scene transitions, checkpoint and sofa delivery to the lorry.
- 5-3: physical ascent to the final floor. Separate input-only lift rides below cover the malfunction sequence, rather than claiming the staircase driver rides it.
- 5-4: physical wall-jump card pickup and persistent, deduplicated unlock.
- 5-5: no clear before the 240-second timer, fixed road camera, warned/active low bridges and vehicle entrance/hold/exit phases. The source starts and increments the ending clock in the same frame, so the lower bound is 242.58 seconds at 60 Hz, not an incorrectly rounded 242.60.
- 5-6: all three HP pools (26, 32, 38), both collapse/rebuild cycles, armour, helper spawns, final defeat and actual jar pickup after its 0.6-second age gate and within its 50-pixel horizontal pickup range.
- 5-S: the original bonus end predicate and completed waves, rather than treating clock expiry alone as victory.

## Local interaction and persistence acceptance

`godot/tests/test_world_five_collectibles.gd` passes **2,370 assertions** across:

- 126 source-surface receipt fixtures: 21 authored identities × all six characters.
- 126 replay pickups after reading the real disk save and reloading the level.
- Six 5-4 card pickup → tutorial-wall kick → disk reload → physical replay-card sequences.
- Six lift rides from the actual 5-3 spawn through wait, move, shake, drop and resumed wait.

Receipt/card fixtures explicitly set up a local standing position before interaction. Every start is checked against an actual source support and lies outside the target pickup bounds. For remote sofa sections, completed scene flags and the local sofa position are initialized to represent the already-entered section. These are **local fixtures**, not complete-stage traversal evidence. There are no actor or collectible writes after fixture setup except declared invulnerability. The lift rides use no fixture placement at all.

Each receipt test then moves/jumps into the original pickup box using actual main-game physics, verifies the physical result and its exact saved identity, confirms no duplicate on replay and checks unchanged META and no premature banking. Replay receipts retain the source's physically collectible ghost behavior. A van route can naturally cross another receipt on the way to its target; the test checks the complete set of physically taken identities against disk rather than incorrectly demanding the target be the only pickup.

Card verification also checks both skill consumers, observes a real upward/outward wall kick (not a direct skill-function call), and confirms the unlock remains available after loading 5-3 without inventing a card there.

## Regression results

The existing World 5 suites were rerun against the current shared host: mechanics **83/83**, renderer **369/369**, actual-main integration **197/197**. All exited zero with no `ERROR`, `ParseError`, `SCRIPT ERROR` or leak warnings.

The first enhanced six-character matrix completed 41 of 42 routes; Theo stalled in 5-1 after the new receipt detour. This was a scripted firing standoff, not an inaccessible collectible or a changed game mechanic. The input driver now approaches/jumps toward an enemy after two seconds of stationary firing. The targeted Theo route then passed all checks with three receipts, all 12 waves and normal clear in **335.8 simulated seconds**. A targeted retry alone was not treated as a clean full matrix. The entire final 42-route matrix was subsequently rerun against the frozen driver and passed, as reported above.

## Reproduction and limits

Godot 4.6.3; headless actual-main simulation, 60 Hz. Use a separate writable HOME/XDG directory per concurrent test process to isolate save files:

```sh
mkdir -p /tmp/w5-acceptance
HOME=/tmp/w5-acceptance XDG_DATA_HOME=/tmp/w5-acceptance/data XDG_CONFIG_HOME=/tmp/w5-acceptance/config \
  godot --headless --path godot --script res://tests/test_world_five_collectibles.gd
HOME=/tmp/w5-acceptance XDG_DATA_HOME=/tmp/w5-acceptance/data XDG_CONFIG_HOME=/tmp/w5-acceptance/config \
  godot --headless --path godot --script res://tests/test_full_moving_day_runs.gd -- --all-characters
```

The collectibles suite took 28–31 seconds in the shared executor. Full-route runs are substantially longer; use the aggregate launcher's 360-second suite allowance or run separate `--character=jp|maya|ama|leo|theo|mei` jobs. `--stage=5-1` selects one stage. `--skip-receipts` exists only for investigating the older objective-only route; it is not the acceptance run.

Logs must be scanned for `ERROR`, `ParseError`, `SCRIPT ERROR` and leaked-object/resource warnings even when the process exits zero. Engine exit status alone is insufficient.
