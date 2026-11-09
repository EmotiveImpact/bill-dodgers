# Festival field input-route verification

## Result

**All six housemates pass the actual-main 3-1 input route** under Godot 4.6.3 (2026-11-09). The final rerun includes the host's source-order final-clear phase and post-physics mud/tie scaling for character bonus movement.

Runner: `godot/tests/test_full_festival_field_run.gd`.

| Housemate | Input frames | Pops | 12-second retirements | 6-second entry timeouts | Wellies stomps | Saved kitty |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Jean Phil | 7,983 | 36 | 8 | 3 | 2 | 189 |
| Maya | 8,048 | 36 | 8 | 3 | 2 | 176 |
| Ama | 7,976 | 37 | 7 | 3 | 3 | 174 |
| Leo | 7,904 | 36 | 8 | 3 | 2 | 175 |
| Theo | 7,905 | 37 | 7 | 3 | 2 | 168 |
| Mei | 7,590 | 37 | 7 | 3 | 2 | 173 |

Each route reaches the real `clear` state and persists that result. No script/runtime errors occurred in the final all-six run. Counts are native headless observations, not claims of a complete browser/native replay equivalence or physical-device testing.

## Method and explicit assist

The runner instantiates `main.tscn`, calls the normal `load_level("3-1")`, requires the real native support gate, and advances `game.step(1/60, controls)` through ordinary left/right/jump/down/aim/shoot input. It does not bypass the native gate. It starts with a fresh isolated save and no unlocked movement skills. It does not activate specials, grant powers, or alter enemies, waves, geometry, camera, scene state, objective state or saves to manufacture a clear.

**Invulnerability is the sole assist:** each input frame sets `game.invincible = 999`. This makes the run a progression/integration test, not a survivability/difficulty test. Source wristband ties still apply during invulnerability and were observed. Runtime phase/unit tests separately verify damage/fall/strict boundary behavior.

A normal standing muzzle is above the 70-pixel crate hitbox. The route crouch-fires to open the first real wellies crate, walks into its naturally spawned item, and deliberately jumps toward a live robot. A stomp is counted only when the actual post-gravity descending contact bounds hold, the robot changes to `pop` without an HP subtraction, and the source -800 px/s bounce is observed. This avoids falsely counting ordinary shot kills as stomps.

## Proven route coverage

Every housemate run observed:

- Ten ordinary waves and all **47 solo entries dispatched** from the actual authored groups, including the source tent-entry paths. Five or six successful tent emergences occurred per final run, with real mutable tent shake.
- All **18 authored bale surfaces** landed on and **all three van roofs** physically reached. No fall recovery occurred in these routes. There were 20–22 actual jumps.
- Grounded mud traversal, real wellies pickups, and two or three actual wellies stomps. Wellies were active for 720 or 1,440 frames, reflecting one or two ordinary pickups, rather than a granted test power.
- All three receipts collected through real overlap in source order at their original authored positions. For each receipt frame the runner accounts for actual coin pickups and verifies the receipt itself added **zero currency**.
- All **29** authored coin seeds, including exact row x-step and sine-arc coordinates. This verifies seeding, not that all 29 were individually picked up: ordinary collection, behind-camera culling and final remaining-coin banking are left to the real controllers.
- A real checkpoint at living player x > 7000, with three hearts and 1.5 seconds of protection on that frame.
- The actual **Food village** door iris: trigger, callback at 1.43 seconds, camera x=7900, safe-point update and enemy/projectile clearing, followed by visual completion at 2.17 seconds. Player movement was input-driven before/after the callback; the test did not teleport them.
- The **60-HP Wristband seller** mini, actual projectile damage totaling 60, real down state and dismissal, `mini_done`, and no jar. Four real reinforcements were observed. The normal route received 132 tied frames despite the explicit invulnerability assist.
- The real ending only after all ten ordinary waves and the mini were done, followed by the source 2.6-second timed exit. The final exit occupied 155 subsequent 1/60-second frames after its first timer update, reflecting the source's initial one-millisecond offset.
- Disk-reloaded clear status, all three receipts and banked kitty. Another 180 calls to `step` after clear changed neither score nor save.
- Imported metadata remained unchanged.

## Spawn and removal accounting

**47 dispatched entries do not mean 47 ordinary enemies killed.** On this route, four ordinary placement attempts produce no enemy under the actual source spawn rules; their entries are still consumed. There are **43 successful ordinary spawns plus four mini reinforcements**, giving **47 observed enemies** per run.

Every observed enemy is classified separately:

- 36 or 37 `pop` outcomes, including normal damage/stomps and the source mini-down cleanup.
- Seven or eight genuine source retirements after **more than 12 seconds since the last hit**. These are not counted as kills.
- Three robots that never enter the view and are removed after **more than six seconds**. Trace evidence places all three on the ground beyond the first receipt's bale section; their segment prevents them reaching the locked camera's entry interval. These are not counted as kills or twelve-second retirements.

The runner balances dispatched entries, failed placements, extra boss spawns and all removal outcomes. No unclassified removal remained in the final runs.

## Reproduction

Use isolated `HOME`, `XDG_CACHE_HOME`, `XDG_CONFIG_HOME` and `XDG_DATA_HOME` directories so tests never touch personal saves.

```sh
godot --headless --path godot --script res://tests/test_full_festival_field_run.gd
godot --headless --path godot --script res://tests/test_full_festival_field_run.gd -- --jp-only --trace
godot --headless --path godot --script res://tests/test_full_festival_field_run.gd -- --character=mei
```

The runner refuses preview support rather than modifying it. `--trace` reports route points, spawns, removals, wave completion, receipts and boss snapshots.

## Separate verification and limitations

`test_world_three.gd` provides **139 isolated runtime checks**, including strict geometry/mud/find thresholds, copied properties, carry units, fall recovery, wipe callback ordering, pause/Continue/restart invalidation, unsupported-stage gating and the attested final-clear phase. Combat, configurable boss, renderer and focused integration fixtures have separate reports; they are not substituted for the input runs above.

This is not unassisted difficulty balancing, special-ability route coverage, co-op testing, touch/controller usability validation, render screenshot approval, iOS/Android export or signing, or physical-device verification. Stages 3-2 through 3-S remain outside this completed runtime scope.
