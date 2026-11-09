# Festival Big top: actual-input route verification

Scope: Godot 4.6.3 headless, actual `main.tscn`, native-supported stage 3-4, all six solo housemates. The runner refuses a preview/native capability mismatch. This is simulation/progression evidence, not device, touchscreen, difficulty, screenshot, visual-parity, export or performance evidence.

## Reproduce

Use an isolated HOME and XDG directory, not a real player's save:

```sh
mkdir -p /tmp/bill-big-top-proof
HOME=/tmp/bill-big-top-proof \
XDG_DATA_HOME=/tmp/bill-big-top-proof/data \
XDG_CONFIG_HOME=/tmp/bill-big-top-proof/config \
/usr/local/bin/godot --headless --path godot \
  --script res://tests/test_full_big_top_run.gd
```

Optional `-- --character=jp --trace` selects one housemate and logs waypoints/state. Require successful process exit, six PASS lines, and no script/engine errors or resource-leak diagnostics. Merely seeing exit zero is insufficient.

The test writes a fresh empty-skills save per housemate. It only drives ordinary movement, jump, duck and shooting/aim controls. The sole gameplay assist is refreshing player invulnerability. It never assigns player/camera position, enemy HP/state, waves, checkpoint state, skill state or objective progress; it never bypasses the native gate. Save setup and normal stage reload are explicit test setup, not progression shortcuts.

## Legitimate route

1. Walk and jump up the three bleachers, then the alternating 118px truss staircase at x2285. Reach the upper −218 platform, stop under the x2800 spotlight and fire upward. The real spotlight is observed at HP1 before activation, demonstrating two ordinary hits.
2. Cross the authored cases, collect receipt3900/−278, then jump onto moving trapezes10,11,12,13. Launch waits use the source sinusoid's predicted landing edge; no geometry or phase is altered. Each trapeze has an observed grounded landing and a stationary frame whose actual player displacement equals that surface's previous-frame dx/dy. The run then jumps off to the next surface.
3. Land at x5510/−226, climb to x5700/−278, collect the actual ground-pound card at5700/−358, and perform a real airborne down-edge ground-pound start and landing. Cross the checkpoint and −278 route, then collect receipt7900/−218.
4. Drop through the real route to ground482 for Ringmaster. Approach, fire and retreat when necessary to avoid placing the muzzle beyond an overlapping boss. Record60 actual HP damage, down and mini dismissal. The boss is never directly damaged by the test.
5. Climb the x9500 alternating truss staircase, cross the final cases/decks, and collect receipt12300/−438 while standing on the −378 route. Finish all nine waves and their31 solo entries, then wait for the actual2.6second ending.
6. Read disk save for clear, all three receipts, only earned ground-pound and exact banked score. Step180 post-clear frames and require an unchanged save. Reload3-4 normally from disk and demonstrate another ordinary jump/airborne down ground-pound start and landing.

## Results

All six passed. Counts below are deterministic for this controller and runtime, not claims about player difficulty.

| Housemate | Ticks to clear | Checkpoint frame | Mini dismissed frame | Ending frame | Jumps | Fall recoveries | Bot-contact frames |
|---|---:|---:|---:|---:|---:|---:|---:|
| JP | 8116 | 3368 | 5791 | 7960 | 35 | 0 | 383 |
| Maya | 7999 | 3368 | 5698 | 7843 | 35 | 0 | 384 |
| Ama | 8393 | 3561 | 6036 | 8237 | 35 | 0 | 388 |
| Leo | 8116 | 3368 | 5791 | 7960 | 35 | 0 | 383 |
| Theo | 8116 | 3368 | 5791 | 7960 | 35 | 0 | 383 |
| Mei | 7978 | 3356 | 5685 | 7822 | 35 | 0 | 444 |

Every run:9 completed waves;31 dispatched solo entries;1 genuine source placement failure;4 boss helper spawns;34 observed actors;30 popped;4 source retirements after more than12seconds since last hit;0 entry timeouts;0 camera culls. Ledger:31−1+4=34=30+4. Pair metadata retains40 entries; this is not a two-player playthrough. Retired actors and failed placements are not relabeled as kills.

Every run: receipts `[0,1,2]`, all four mover landings and measured carries, card collected without inherited skills, ground-pound used before clear and after reload, one real spotlight activation,60 boss HP damage and true mini dismissal. Imported metadata stays unchanged. Clear occurs156 frames after the observed first ending frame at60Hz, consistent with the source's increment-on-trigger and `>2.6s` threshold.

Contact frames count the ordinary bot contact rectangle, including while invulnerable, not separate damage events. They are deliberately reported rather than implying a damage-free or unassisted route. Boss/bill contact exposure is not completely enumerated by that counter. All actual fall recoveries are counted; all six had zero.

## Spotlight evidence and limits

The full route activates one real spotlight through normal upward shooting and observes its intermediate HP1. It does **not** claim that all six spots were activated or that any enemy happened to stand in that moving beam. Full-route `dazzle_frames=0` for every housemate.

Separate focused tests own beam/dazzle coverage: `test_festival_big_top.gd` checks source beam membership, immediate activation dazzle,0.25second refresh, already-longer daze preservation and pop exclusion. `test_big_top_integration.gd` uses an explicitly arranged host fixture for real late dazzle refresh and next-frame damage behavior. Those fixtures are not presented as ordinary-input route progression.

Source exit depends on distance, wave completion and Ringmaster dismissal, not an altitude, spotlight or card clear gate. This test intentionally navigates the upper route to prove accessibility, but adds no runtime gate. It does not infer handset usability or visual readability from headless success.
