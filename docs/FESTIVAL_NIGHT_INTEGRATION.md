# After dark host integration

The 3-3 native stage combines shared World 3 geometry/combat/mini logic, the isolated night controller, exact original artwork, two ordered GPU material overlays and prebuilt source firework sound.

## Focused verification

`test_festival_night_integration.gd` passes 109 actual-main checks. These use explicit placement, health, clocks or prerequisite fixtures and are separate from full input routes.

- Exact ten waves/48 solo entries, fifteen tents, five fires, source darkness and distinct painter/runtime selection. The ignored fifth tent-glow metadata field remains ineffective, matching executable source.
- Every housemate takes real fire damage at each strict inner boundary, with exact outer/vertical edges safe. Existing invulnerability, Maya shield, slide and dash protect normally. A separately placed fire verifies checkpoint healing/protection occurs first.
- An actual runtime RNG chance sample spawns a firework in the correct late phase, ages its sparks immediately, preserves the new half-second flash and requests the prebuilt firework effect once. Pause, knockout, Continue and fresh replay preserve/reset clocks and chance state appropriately.
- The actual night fade, 1.43-second callback, destination, 70-HP Bailiff entry/music and strict mini dismissal are exercised. The mini produces no jar and cannot falsely clear the stage.
- Both actual overlay roots execute their CanvasItem callbacks: additive campfire before actors; darkness, additive glow and foreground after actors; native UI/touch controls remain above world lighting. Repeated drawing preserves simulation and RNG. The HUD uses the source fade instead of an iris. Menu navigation hides the layers.
- A campaign prerequisite fixture reaches the actual timed night clear, opens 3-clue, returns to settlement on Skip, saves the real supported clear and stops at the next unported stage. The attested final base update now remains allowed when immediate native clue presentation changes mode from clear to story; subsequent story frames remain frozen. This avoids dropping late source effects from the completion frame.

## Independent progression and limitations

All six fresh-save, no-skill input routes independently pass in `test_full_festival_night_run.gd`: 48 authored entries plus four summons, three actual receipts, fifteen exact coin seeds, all three camper roofs/fifteen bales, checkpoint/fade, 70 boss damage with observed throw/charge/shockwaves/down/dismissal, timed exit and disk-save idempotence. There are no fire contacts or falls. Invulnerability is the sole assist and these runs do not validate unassisted survival. Exact enemy outcomes and frame counts are in FESTIVAL_NIGHT_RUN_VERIFICATION.md.

The night shader has an explicit 128-visible-light capacity assertion. It is not silently truncated, but handset GPU compilation, framebuffer comparison, performance/battery measurements and worst-case ability lighting remain real-device acceptance work. Headless callbacks and pure light math are not screenshots. Native randomness preserves local source probabilities/draw order, not JavaScript global RNG sequence identity. Firework audio is source-parameter faithful with a 50ms delayed noise component; listening/device QA remains pending.

## Clean checkpoint

The complete clean snapshot passes eight Python tests, 64 Godot suites including 102 supported stage/housemate input runs, 126 asset-free packed-runtime checks and 154 mandatory-prebuilt audio checks (22 resources). Original game files and public-web build behavior are unchanged. No phone export or device test is implied.
