# Aisle and shopping-street host integration

`test_aisle_integration.gd` uses actual `main.tscn` with explicit actor-placement and suppressed-wave fixtures. It passes 44 checks under Godot 4.6.3, with isolated HOME/XDG and saves. These are collision/lifecycle fixtures, not full-run proof. Independent all-six routes are documented in AISLE_RUN_VERIFICATION.md and SHOPPING_BONUS_RUN_VERIFICATION.md.

- Registry, gameplay and save capability share 2-1, 2-2 and 2-S support. Each selects its own original-art painter; other W2 stages remain previews.
- Gate controllers append seven mutable surface references. Player walls, abilities, floor and skill queries see the same source 55% opening threshold, without altering imported META.
- The real high-button projectile sets the matching 6.5-second timer, consumes the shot, then opens collision in the late gate phase. Friendly bot interception remains earlier, ordinary crates/walls later.
- Base movement uses source floor/ice momentum. Mei's passive speed is a separate post-physics nudge and is not multiplied by ice, belt or slow-floor rules. Momentum continues into the air and decays toward normal input.
- Box warnings spawn from occupied authored zones in the late world update. Pause freezes timers and entities. Continue retains gates, drops and momentum. Explicit replay resets controllers and source-leaked per-zone counters.
- Bonus street has no inherited gate/drop state. A separate idle fixture exceeds 100 seconds without invented defeat, reward or clear. The full bonus regression also independently checks 105 seconds idle without editing clocks.
- Independent review regression tests cover fresh replay facing right versus Continue retaining facing, and source crouch+aim split/debit patterns across W1, aisle and bonus. Crouching suppresses aim before every power-up branch.
- The capability save fixture deliberately writes supported and unsupported cleared IDs only to an isolated test save, confirming future stages are stripped. This is not a claim of earned gameplay progress.

All normal source W2 physics phases remain ordered: player and ability pre-step; camera; waves and objective; bots/bubbles; friendly then hostile projectiles; pickups; scenes/embedded bot repair/checkpoint/coins; gates; trolleys; falling stock; late carts/drones; receipts; effects; deferred knockout; scene callback while still playing. The source draw-driven wipe is intentionally simulation-clock based, as documented in WORLD_TWO_RUNTIME_PARITY.md.

A source edge case is preserved: a wave entry can fail placement when vertical camera bounds exclude all eligible solid floors, and the entry is still consumed. The aisle full-run controller descends before its later wave trigger, so it proves all 43 enemies were actually spawned and beaten without altering that rule.

No co-op/CPU, rendered screenshots, unassisted difficulty, native device installation, signing or deployment is established here.
