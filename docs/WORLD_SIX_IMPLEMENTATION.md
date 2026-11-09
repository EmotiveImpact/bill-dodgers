# World 6: The Bill-ding native implementation

Updated 2026-11-09. All seven original stages have distinct native Godot systems,
not a reused street loop. Original HTML, imported META and assets stay unchanged.
This report distinguishes source-boundary fixtures, assisted input routes and
remaining device/visual acceptance work.

## Source inventory

The W6-specific runtime between the `World 6:` and `World 6 art:` markers is
byte-identical in all seven HTML files; the systems test verifies this directly.
The authored level data is different in every stage. Audited source anchors in
`game/6-1/index.html`: base player/combat 389–628; frame order 629–669; W6 systems
718–1186; original paintings/procedural art 1187–1818; HUD/draw order 1819–1881;
shared abilities and movement appear later in each original file.
SHA-256 of audited HTML: `ab34f2eb9d3ab00d41ee1f44201fef958620650d3191fc080475656625a7c349`.

| Stage | Name | Kind | Waves | Solo wave entries | Surfaces |
|---|---|---|---:|---:|---:|
| 6-1 | Post room | run | 12 | 47 | 18 |
| 6-2 | Call centre | hold | 9 | 34 | 17 |
| 6-3 | Hot desks | run | 13 | 50 | 31 |
| 6-4 | Lift shaft | climb | 12 | 27 | 69 |
| 6-5 | Window cleaners | ride | 14 | 31 | 1 |
| 6-6 | Sir Charge | boss | 3 | 12 | 6 |
| 6-S | Coffee run | dash | 7 | 14 | 24 |

## Modules and actual host phase contract

- `world_six.gd` owns copied live surfaces, stage clocks, exact belt carry,
  navigation, door wipes, checkpoints, free/height/time wave readiness, hold/lift/
  ride/coffee objectives, hazards, warned fees, receipts and final-boss adapter.
- `billing_combat.gd` owns W6 ordinary bots, drop bots, debit latches, flying
  mailers, Franker/Jammer mini-bosses, source waves, projectiles and pickups.
- `sir_charge.gd` is the actual final W6 controller, not `startBossOld` left
  unused in the HTML. It has 110 solo/150 multi-count HP, ledger attacks,
  66%/33% phase thresholds, fee storm, wall charges, dizzy vulnerability and the
  real dropped jar with its own age and physics.
- `billing_renderer.gd` uses original room/facade/shaft/decorator paintings,
  sprite sheets and W6-specific procedural machinery. It inherits common
  drawing primitives, crates/items/coins and standard bot sprite cropping, not
  another world's scenery. `draw_mid` explicitly submits W6 actors and finds.

Native positions are absolute feet, simulation clocks are seconds and velocities
are pixels/second. Authored surface rows are `[x0,x1,top,vx,art]`, with vx still in
source pixels/millisecond. Every conversion happens at the boundary, and copied
live surfaces never mutate imported META.

Actual main integration binds geometry before initial floor lookup, clears old
shared state, then calls `seed_pickups` after combat reset. Each play frame runs:

1. `pre_motion` before player/ability movement. Sample `carry_player` at old x
   before base movement and wall clamping; stepping off a belt or cradle keeps
   that frame's source carry. `after_motion` updates a safe standing point.
2. `camera_override` handles the ride before common vertical camera smoothing.
3. Source wave triggers, then `objective_tick`, then `world_tick` (doors, enemy
   carry/navigation, debit, finds, coins, fliers/vents/mini, checkpoint, distinct
   stage hazards and delayed sheets).
4. Ordinary bots, held bubbles, player shots before hostile bills, coins/items,
   actual Sir Charge, jar, late ability effects and visual bookkeeping, knockout,
   then guarded wipe callbacks. Source clear-before-all-down precedence remains.

The original last play frame can continue after its own clear/story transition
through `family_base_step_active(6)`. Unrelated story/clear callbacks do not mutate
W6 state. Wipes use generation-guarded simulation clocks, so pause, replacement
and invalidation cannot execute a stale door callback. Source 6-6 introductory
lift wipe is preserved without accidentally applying a doorway teleport.

## Distinct mechanics preserved

- **Post room:** positive/reverse raised conveyors and the 44-HP Franker, three
  stamps per volley, every-third shockwave, backup thresholds and Loading bay.
- **Call centre:** two authored room transitions, then 90-second lift hold with
  timed/capped reinforcements. Each bot reaching the door adds five seconds.
  Completion clears threats and opens the doors over 0.9 seconds.
- **Hot desks:** navigation over cabinets/shelves, 44-HP Jammer alternating low/
  high sheets and delayed double sheets, second backup threshold, Records room.
- **Lift shaft:** all 69 surfaces, height-triggered waves, five-second delay,
  24→42 px/s rising lift with 1.6/2.6 catch-up, charging damage/bounce, top landing,
  coin/item carry, physically collectible super-special skill card.
- **Window cleaners:** real single moving cradle, 100 px/s automatic camera,
  carry, timed/free waves, mailers and authored beam/box hazards.
- **Sir Charge:** all three opening waves, ledger slam/volley, airborne fee
  warnings, breath/dizzy windows, 550 px/s wall charges and debris, 24 defeat coins,
  money rain, jar spawn strictly after 1.8 seconds and pickup only after its own
  age exceeds 0.6 seconds. Jar pickup is horizontal, matching the source.
- **Coffee run:** 110-second countdown, original finish coordinate and exact
  ceiling-seconds bonus. Timeout starts the 2.6-second ending rather than a loss.
- Shared W6 systems include mailer 130 px/s pursuit/drop cadence, ceiling bots,
  latch/drain/release debits, one-based authored receipts mapped to zero-based
  save identities, zero receipt rewards and replay ghost art.

Preserved unusual rules include source multiplayer group concatenation without
sorting, surface first-tie identity, the normal-standing beam predicate (short
characters only intersect it while sufficiently elevated), one source 16 ms
navigation increment per call, and boss shot damage 1/2 independent of projectile
damage. Pair-count scaling tests are not an implemented second-player mode.

## Explicit functional repairs

### Finite Sir Charge feet

The HTML omits `boss.fy` although shared abilities read it. Native `fy` aliases
`ground+yo` and stays synchronized while floating, dizzy or descending. This
prevents invalid coordinates/silent misses without changing the actual body
hitbox, phases, damage scalar or dizzy multiplier. The original HTML is untouched.

### Four receipts inside skipped doorway voids

These source receipts lie on the top of non-playable sentinel walls 1,400 pixels
above the floor. The doorway skips those walls and advances the camera clamp;
normal movement cannot reach them. Runtime-only repair uses doorway.to+140 and
floor−70, 60 pixels beyond the actual doorway arrival, on unobstructed floor.

| Stage | Source one-based receipt | Immutable source x,y | Runtime x,y | Source door x→to |
|---|---:|---|---|---|
| 6-1 | 3 | 8090,-988 | 8440,412 | 7760→8300 |
| 6-2 | 2 | 6530,-988 | 6880,412 | 6200→6740 |
| 6-2 | 3 | 9830,-988 | 10180,412 | 9500→10040 |
| 6-3 | 2 | 7820,-988 | 8180,412 | 7480→8040 |

`receipt_position(host,index,source_position)` changes only those four runtime
anchors. Save indices, source rows, ghost behavior and zero rewards are retained.
The all-six-character receipt suite uses normal right input from exact door-
arrival fixtures, not forced collection, and verifies replay/persistence. Whole-
stage input routes separately assert physical collection of these repaired rows.

## Rendering and presentation

Original wall/far paintings use source-sized crops, mirrors, clipping and
parallax. Belts use source three-slice caps plus moving ribs/arrows. Lift/cradle
cables, bars, rails, warnings, room props, paintings, procedural debit bots,
receipts and skill-card art have distinct commands. Mailers use 173×129 source
cells and Sir Charge uses 468×310 cells. Mini-bosses use original Franker/copier
paintings. All W6 mini/boss/flier/fee layers draw in the source world order.

HUD includes lift countdown, coffee countdown, climb floor, ride progress,
mini-boss bar, Sir Charge/dizzy bar, receipt count and source central banners.
Source informational floats have 1.3-second life, 16 px text and 40 px/s upward motion;
mini backups/death, checkpoint, lift events, ride collisions, coffee bonus, boss
fee quips/dizzy and debit messages are distinct, not an unchanged generic header.

Rendering is pure and does not advance simulation or consume combat randomness.
Seeded skyline placement and some particle flourishes/tiny decoration details
are native approximations, not a pixel-identical Canvas screenshot claim.
Additional source-specific flier scraps, mini/fee impact puffs and Sir Charge
shake/burst events remain cosmetic residuals at this freeze. Common shared
particle additions are a separate integration pass; the complete W6 floating
messages must not be emitted twice.

## Verification and limits

Focused suites: `test_world_six.gd`, `test_billing_combat.gd`,
`test_sir_charge.gd`, `test_billing_renderer.gd`,
`test_world_six_integration.gd`, `test_world_six_receipts.gd` and
`test_world_six_presentation.gd` and `test_world_six_collectibles.gd`.
The eight focused suites pass 3,411 checks: 124 systems, 47 combat, 37 Sir Charge,
240 renderer, 27 production-host seams, 336 receipt repair/replay assertions,
20 presentation/audio event checks and 2,580 complete-collectible assertions.
These cover strict source thresholds, final-frame guards, old-x carry, all seven
actual scene paints, live geometry, phase/receipt/save ordering and render purity.
The final serial production-input matrix passes all 42 combinations: all six
characters across all seven stages, exit 0 and no script/parse/error/leak/FAIL
matches. Completion takes 54.9–235.2 simulated seconds per route. All waves,
normal persisted clears, source ending delays, both mini-bosses, all three Sir
Charge phases and the actual jar are verified, as are all repaired receipt
pickups and all six characters' physical Super-card pickup in the climb.

`test_world_six_collectibles.gd` independently covers all 21 receipt identities
for every character, including all original elevated shelves, galleries, shaft
girders, trophy plinths and all three moving-cradle jumps. Fixtures place the
player on actual source/live support before ordinary approach/jump input. They
do not move any receipt, modify geometry or force a pickup. Each identity is
physically collected and replayed with zero reward, exact persistent indices,
replay ghost state and unchanged META. The same suite covers Super pickup,
persistence, actual special-button activation at fixture-full meter, the source
1.5x power/duration, reload and physical replay without duplicate unlock. These
fixtures complement, rather than replace, the full-stage progression matrix.

`test_world_six_full_runs.gd -- --all-characters` uses actual main input,
movement, camera, authored waves, shots, mini/boss phases, source door callbacks
and normal save/clear. Invulnerability is repeatedly granted for deterministic
progression coverage. The controller never teleports, kills enemies directly,
edits waves, changes timers, grants pickups or forces clear. It does not collect
every optional original receipt, and it does not demonstrate unaided difficulty,
human play, physical touch controls, mobile performance or exact visual parity.

Run with isolated HOME/XDG directories and `/usr/local/bin/godot --headless
--path godot --script res://tests/<suite>.gd`. Check logs for script/parse/errors,
leaks and FAIL even when exit status is 0. No source website changes, commits,
pushes, installations, deployments or visibility changes were performed by this
World 6 task. Native device exports, human play and visual/device acceptance are
separate gates.
