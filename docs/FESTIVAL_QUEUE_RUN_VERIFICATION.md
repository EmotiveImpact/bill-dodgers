# Queue jump: actual-input route verification

Scope: Godot 4.6.3 headless simulation of the actual `main.tscn` / `main.step` gameplay path for stage **3-2**, all six housemates. This is progression and source-contract evidence, not unassisted difficulty, touch-control, graphics, native export, device, or visual-parity acceptance.

## Reproduce

From the repository root:

```sh
RUN_HOME=$(mktemp -d /tmp/bill-queue-route.XXXXXX)
mkdir -p "$RUN_HOME/data" "$RUN_HOME/config"
HOME="$RUN_HOME" XDG_DATA_HOME="$RUN_HOME/data" XDG_CONFIG_HOME="$RUN_HOME/config" \
  /usr/local/bin/godot --headless --path godot \
  --script res://tests/test_full_festival_queue_run.gd > "$RUN_HOME/run.log" 2>&1
RC=$?
cat "$RUN_HOME/run.log"
test "$RC" -eq 0 && ! grep -Ei 'SCRIPT ERROR|Parse Error|ERROR|leaked|leaks' "$RUN_HOME/run.log"
```

Optional user arguments: `-- --jp-only --trace`, or `-- --character=mei`. The process must return zero **and** its whole log must be free of script/parser errors, engine errors and leak warnings. Do not accept an exit-zero run that logs errors.

## Test boundary

Each route selects its housemate, writes a fresh isolated save with no receipts or skills, and loads the real supported 3-2 through `main.load_level`. It does not bypass capability checks. The test disables autonomous scene physics because it supplies every actual `main.step(1/60, controls)` call itself.

The sole assist is explicit player invulnerability, renewed each frame. The test does not teleport, change player/camera/velocity, alter enemy health, set ability charge, write runtime timers or waves, insert pickups, unlock skills, replace geometry, inject completion, or force clear. The only active input keys are ordinary right movement, jump, crouch and fire. Observer/controller variables belong to the test and never alter game state.

The route follows approximately camera+320, jumps before raised solid edges and gaps, and crouches through each banner. Crouching stops ordinary ground movement in this source. The ordinary old-camera left clamp eventually carries the crouched player under the banner; this is not a test teleport or an invented duck-movement ability. Real crowd solids carry grounded players by120px/s independently of ordinary movement. The test measures the resulting per-frame displacement on all five crowd spans.

Receipts0 and1 are genuinely collected during normal jumps near6000 and16500. The controller waits until each receipt jump lands before continuing to the nearby gap. This wait matters: a first fixture that resumed walking immediately after16500 could land in the16612–16722 hole. That test-route defect was corrected; no runtime change or synthetic pickup was used. Receipt2 at25000/262 is legitimately reachable while standing on the442px crowd surface: the source's height-plus10px receipt overlap reaches it without requiring an additional jump. None awards currency; observed score changes on pickup frames must equal real coin pickups only.

## Assertions and observations

- Real initial position320/482, width30000, six gap records, six banners, fifteen authored wave triggers and51 solo entries. All waves start, dispatch every entry and finish through combat logic.
- Strict1.8s camera warmup, actual140px/s scrolling, no scrolling throughout the real iris wipe, no scrolling during final countdown. Both source camera announcements occur.
- Six gap far edges crossed at or above ground, zero falls/recovery/other unexplained position discontinuities, six real crouch overlaps and zero source banner-collision frames.
- Five separate crowd surfaces have measured movement-plus120px/s displacement. This is movement evidence, not merely reading their `conv` properties.
- All80 exact authored coin positions observed at seed time, including the sine-arc coordinates. This does **not** claim collecting all80 coins.
- All three receipts collected in order through actual overlap, with the first two airborne. The source checkpoint crosses14300, restores three hearts and sets1.5s immunity. Actual scene wipe label is `Into the arena`; the callback moves the camera to15300 and clears actors.
- The genuine2.6s distance ending and its jar-runner animation clock finish, then real clear writes to the save. Disk reload verifies clear, receipts, no unearned skills and the banked score.180 further main-step calls leave the save and score unchanged.
- Enemy accounting distinguishes pop rewards,12s retirement, offscreen culls,6s unentered timeouts, real scene cleanup and enemies still alive at clear. The source allows auto-stage completion with live enemies; the test does **not** invent an all-enemies-killed requirement. Unknown removals or unbalanced dispatch accounting fail.
- Contact counts report player/enemy **geometric overlap frames**, not unique enemies, actual damage calls, or a hitless route. Invulnerability masks those contacts. The routes are not evidence that an ordinary three-heart player can survive this controller.

## Recorded final sweep

Final sweep, 2026-11-09: **all six PASS**, process exit0, with no script/parser errors, engine errors or leak warnings.

| Housemate | Ticks | Pops |12s retired| Culls |6s timeouts| Contact overlap frames | Jumps | Score |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| JP |12369|41|3|5|2|300|28|278|
| Maya |12369|41|3|5|2|294|29|262|
| Ama |12369|41|3|5|2|298|28|265|
| Leo |12369|41|3|5|2|302|28|263|
| Theo |12369|42|2|5|2|387|28|266|
| Mei |12368|41|3|5|2|327|29|261|

Every route dispatched51entries, observed51real enemies, had zero failed placements, zero scene-cleanup removals, zero unknown removals and zero live enemies remaining at clear. The latter is an observation, not a completion requirement. Every route reached6gap crossings,6duck overlaps,5measured crowd carries,3receipts,80exact authored coin seeds, zero fall recoveries and zero banner-collision frames including the source's10px edge margins.

Zero-based wipe start/callback/end frames are6100/6186/6231 (Mei6099/6185/6230), with the source1.43s midpoint and2.17s full duration checked. Ending begins at12213 (Mei12212); clear occurs156frames later. Clear simulation time is approximately206.15s (Mei206.13s). The additional180postclear steps verify idempotent save/score behavior and are not included in route ticks.

No source defect was found by these routes. Besides waiting for receipt-jump landing, the controller anticipates banner starts20px early so a walking step cannot enter the source's10px collision margin before crouching. Enemies still geometrically overlap the assisted player hundreds of frames, as reported above.
