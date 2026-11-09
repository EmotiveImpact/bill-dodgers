# Festival / real-main integration fixtures

Date: 2026-11-09. Scope: `godot/tests/test_festival_integration.gd` against the actual `main.tscn`, `main.gd`, `world_three.gd`, `festival_combat.gd`, `festival_boss.gd`, shared abilities/skills, renderer dispatch and save writer. Latest result: **146 checks, zero failures**, Godot 4.6.3 headless.

This is a focused integration suite, **not a full input-driven route**. It deliberately places actors, suppresses wave triggers, supplies overlap geometry and selects health/state/timers to isolate seams. Every such helper is marked in the fixture. The independent full-field suite owns route, source-wave, receipt, fight/retirement and real exit evidence. These tests do not establish human difficulty, artwork fidelity, co-op play, device behavior, export correctness or complete later-World-3 gameplay.

## Harness and isolation

The suite instantiates the real main scene and disables only its automatic physics process. It advances `game.step` through ordinary ≤10ms steps, or exact zero-time boundary fixtures. The actual production movement, character specials, skills, combat, pickups, boss events, checkpoint/scene logic, completion and save writer execute.

Small subclasses call their real parent implementations while recording phase names and the host mode. A rendering probe calls the real painter during actual canvas redraws; it does not simulate drawing calls from outside the draw callback. An audio logger substitutes the sound device and verifies actual main soundtrack/effect requests. Tests use an isolated writable HOME/XDG environment so no personal save is touched.

Vector position/velocity comparisons permit 0.001px or px/s for Godot's single-precision Vector2 storage. Exact source boundaries are set and asserted separately. This is not an expanded collision tolerance.

Example execution:

```
HOME=<isolated-home> XDG_CACHE_HOME=<isolated-cache> \
XDG_CONFIG_HOME=<isolated-config> XDG_DATA_HOME=<isolated-data> \
godot --headless --path godot --script res://tests/test_festival_integration.gd
```

The verifier should reject `SCRIPT ERROR`, parse errors, engine errors or leaked objects even if the engine process exits successfully.

## Covered seams

### Family selection and source phase order

- Supported 3-1 selects the distinct festival world/combat policy and source-style ghost abilities. Actual main loads 10 waves / 47 solo entries, 7 crates, 3 receipts, 16 tents, 28 solids and 3 one-way platforms.
- 3-2 through 3-6 and 3-S remain previews and reject completion; reusable combat/boss code is not evidence of stage integration.
- Returning to 1-2 retains W1 and its twelve crumbles; returning to 2-1 retains the supermarket policy and eleven waves.
- The main trace is motion → carry → after-motion → ability pre-pass → camera → waves → objective → bots → bubble reinsertion → shots → pickups → late world → boss → jar → ability effects → finish-frame callback. The trace uses real implementations, not replacements that merely report expected labels.

### All six characters and mud/tie/wellies

Each housemate is tested in actual main for:

- Mud scaling ordinary and post-passive horizontal movement.
- Tied preventing an ordinary jump and multiplying mud movement by both 0.55 and 0.45; tie decrements in the late world phase, not before motion.
- Mud jumping at −980×0.84, applying gravity before the character jump multiplier, with no retroactive correction to that frame's position. Ama's ×1.09 occurs after the base displacement.
- A jumping Mei uses mud for the base grounded move but no mud for the post-motion airborne speed bonus, because the source samples current grounded state again.
- Wellies removing both mud penalties, and wellies expiring before base motion when the power timer reaches zero.
- Actual airborne wellies contact killing an eligible live bot, granting one pop and rebounding −800px/s.
- An invulnerable wristband still applying a 2.2-second tie, immediately reduced by the current late-world dt.

Additional active-special fixtures verify Mei's bonus also receives mud/tie scaling and Leo's airborne bonus receives tie scaling before his post-gravity glide cap.

### Live surfaces and carry

Main floor, landing, drop-through, skill-floor/side-wall, ability landing and inside-wall queries all observe the same added live W3 geometry. Adding it does not mutate imported META.

A standing player uses the actual carry hook for conveyor displacement, previous surface dx and dy before support testing. Tied still permits the earlier down+jump platform-drop branch; `nodrop` plus tied blocks both branches. Theo's actual late football step bounces against the same one-way platform. These synthetic surface fixtures validate reusable queries and the player carry seam; they are not evidence that an unimplemented later moving-platform course is playable.

### Shots and abilities

Both visible shots and invisible special ghosts execute bot → seller → crate → solid filtering through real main. An overlapping bot intercepts first; the seller takes fixed1 despite a damage999 field, or fixed2 while dizzy; an entering seller passes the shot to the crate, which takes fixed1. Unconsumed shots die in the live wall pass.

Actual Ama special requests a damage3 ghost but deals only fixed2 to the dizzy seller. Actual Maya at exact shield expiry cancels a wristband before later collision/tie handling. Seller volleys are created after the shot pass at age zero, preserving tie metadata, and move only on the following frame.

### Seller entry, soundtrack and defeat

The real late predicate rejects camera<8640 and starts the configured 60HP seller at 8640, with the authored 8900 camera lock. Repeated eligibility keeps the same boss object and plays boss music once. The actual entry/clamp sequence reaches walk.

A deliberately selected final-HP fixture is defeated by a real ordinary shot. It drops sixteen actual coins and resumes ordinary music, without clearing the level. The down mini persists at exactly1.8seconds, creates no jar, then disappears only after the strict threshold, clears the camera lock and sets runtime `mini_done`. It neither restarts nor writes a stage clear. This proves a host seam, not that the fixture earned all prior boss damage.

### Checkpoints, receipts and saving

Checkpoint activation is strictly after player x=7000. A nonlethal shot happens before the late full heal/invulnerability; the new protection blocks the next frame's bill. A lethal solo shot leaves no living crosser, so it produces knockout rather than a checkpoint revival.

All three receipt records keep their original authored y coordinates. The actual source collection predicate rejects the exact42px horizontal edge. Collection writes the expected zero-based native save IDs immediately and grants **zero currency**. The real save writer is reread to verify receipts and unchanged kitty. Replay restores all live pickups while retaining previously-collected presentation markers.

### Clear and knockout transition frames

The source ability wrapper at `game/3-1/index.html:1990–1995` invokes `abTick(dt)` unconditionally after the original `updatePlay`, including a call that changed state to clear or over. The original base update itself continues bots/shots/coins/world/boss/jar after an earlier `stageClear` (`668–673`). The suite explicitly verifies both distinctions:

- An isolated end-time fixture changes main to clear through the real objective, then bots, shots, item aging, late tie countdown, boss/jar dispatch, football and ghost expiry still run once.
- Completion sweeps and banks an already-existing coin once. A real bot shot later in the same clear transition drops new coins which receive the pickup timestep but remain unbanked, matching source ordering rather than inventing another sweep. A newly emitted late football ghost ages in the wrapper but cannot collide until another play frame, which never occurs after clear.
- A lethal wristband runs late world and boss/jar while main is still play, then global knockout occurs, then the unconditional ability effects and ghost expiry run with mode over.
- Subsequent clear/over calls freeze; the temporary permission for a final base step does not leak into arbitrary later runtime calls or duplicate banking.

### Pause, Continue, replay and scene callbacks

Pause freezes the damaged live seller, bots, player, tie, clocks and audio. Actual knockout retains the same encounter. Continue restores three hearts and2.5seconds of invulnerability **in place**, keeping the same boss identity/HP, bots and world clock. Fresh replay resets the encounter, tie and mini state.

The actual field scene gate begins the authored door while ordinary movement/gameplay continues. Native pause freezes the pending callback as an explicitly declared reliability repair. At1430ms the actual post-frame callback moves the camera to7900. A replay generation change rejects an old callback. If a lethal shot lands on its due frame, the callback remains pending through knockout and executes after Continue, rather than running in the over screen or being discarded.

### Rendering dispatch

Real scene redraws call festival sky, level, finds, boss, bot, player-back/player-front, wristband and front layers. The source boss-before-bots-before-bills ordering is asserted. Repeated painting leaves boss/bots/bills/player/tie state unchanged. Dedicated painter tests retain responsibility for command geometry and source art transformations; headless dispatch is not a visual quality certification.

## Integration defects caught and fixed by the shared-code owner

1. W3 post-passive movement initially reused W2's deliberately unscaled bonus nudge. The main now computes the bonus through the current W3 mud/tie factor **after** base physics, retaining W2 behavior unchanged. All-six grounded/jump and active Mei/Leo fixtures cover the distinction.
2. The main had a festival music callback but the event path initially reached only the runtime cheer handler. Runtime boss events now forward to the host, so entry and mini defeat produce the actual expected soundtrack sequence. These assertions remain enabled.

No other source/runtime edits were made by this integration-test worker. No stage promotion, source staging, push or deployment was performed. Run the aggregate verifier and the independent full-field suite against the final shared files before claiming a completed native slice.

## Full checkpoint verification

The clean 3-1 checkpoint passes eight Python tests, 56 Godot suites including all 90 supported stage/housemate input routes, 109 asset-free packed-runtime checks and 140 audio checks. The older movement-skill fixture was updated to reset the live World 3 surface cache and add its explicit wall to that cache, rather than mutating only imported terrain. No production collision change was needed for that test fixture.
