# World 2 party scene integration

## Implemented boundary

The World 2 scene modules now use the real `PartyCombat` stable mutable roster
for shared interactions and retain the original scalar solo branches. The focused suites
are scene/bridge checks; the whole-route section separately records companion
progression. Physical controllers, multitouch, two-human full routes, rendering
and mobile exports are not certified here.

Changed production modules:

- `godot/src/world_two.gd`
- `godot/src/supermarket_hazards.gd`
- `godot/src/checkout_boss.gd`

`supermarket_course.gd` already had roster-based flame, low-sign, block and auto
scroll logic. Its existing logic is now exercised through the actual bridge,
including post-damage P2 bounce. It did not require a production edit.

## Source audit

Reviewed executable source in all seven `game/2-*/index.html` files, specifically
`updatePlay` (634–675), `lvMove` (756–770), `lvAuto` (749–754), `lvUpdate`
(771–841), `lvCPU` (864 onward), `sceneUpdate` (1122–1138), the stage-specific
`L` policies, and the active checkout `L.readyEnd`, `L.update`, `L.shot`, `L.cpu`
and jar routines in `2-6`. Also reviewed `game/polish.js` `focusPoint` (113–120).

The source-contract test compares the complete `lvAuto`, `lvMove`, `lvUpdate`,
`sceneUpdate` and `lvCPU` function bodies across all seven stages. They are
byte-identical. Stage geometry and the checkout extension remain stage-owned.

Important source behavior preserved:

- Ice momentum belongs to the actor object. Native identity is the stable slot,
  never the host facade's instance ID. Movement reads the current scalar facade,
  not the prior shared-phase record position.
- Pads and gate occupancy consider all living actors. Gate hold time is 2.6
  seconds with two humans, 5.2 seconds with a CPU or solo player. Gate motion,
  button decay and drop-zone counters advance once per world frame.
- Scene caps clamp every actor, including downed actors and an existing `px`.
  Any living actor at the threshold may trigger the single pending wipe, subject
  to source wave gates.
- The midpoint relocates every actor once. Normal destinations use `x0 + i*70`;
  2-3 uses `x0 - i*70` because its sceneLand is zero. Each actor gets a separate
  `below` query. Stockroom queries first from y=476, then falls back from -9999.
- Midpoints reset velocity and grounded state and raise downed actors with three
  hearts. Living injured actors are not healed. Source safe points, on-platform
  flags, protection and abilities remain intact. Shared enemies/projectiles and
  camera are cleaned or moved once.
- The iris focus averages living roster positions, falling back to all actors.
  It reads live records so the opening focus includes the pending midpoint's
  new positions before facade restoration.
- Checkpoints heal all actors once and give only raised actors 2 seconds of
  protection. Source per-actor state persists through nested victim callbacks.
- Trolleys advance once and can hit each overlapping living actor independently.
  Falling stock, low signs, flames and block bounce use each actor's actual
  state and actual damage callback.
- Checkout HP is 90 for a pair. Bags, crate references and boss-hit counters are
  keyed separately by stable slot. Human mash affects human bags, not CPU bags.
  Crate references remain the original world objects, including carrier IDs.
- Native `owner_slot` checkout shots update their actual owner's boss-hit tally.
  Missing or stale party owners cannot accidentally credit the bound facade.
  Solo checkout snapshots retain the original host-instance identity.
- A living P2 can collect the jar with P1 down. Jar completion remains one-shot.

## Host and scheduler contract

There is no second World 2 actor simulation and no per-actor call to the complete
world update. Required APIs are already shared with the party combat adapter:

1. Reset world geometry with the previous party inactive. Resolve each new
   actor's starting floor and configure the bridge.
2. Call `world_two.party_start(host)` after the new roster exists. This replaces
   checkout's temporary scalar state with slot 0/1 state. It does not tick or
   rebuild scenery, advance clocks, reset RNG or duplicate spawned objects.
3. During actor motion, `host.combat_owner_slot()` returns the currently bound
   slot, or -1 in solo. The existing scalar `base_displacement` and `after_motion`
   methods are each called once for that actor.
4. `party_capture_scene(actor)` saves `scene_runtime.safe_position` into the
   actor's `scene_state`; `party_apply_scene(actor)` restores it. Both ordinary
   binding and bridge nested callbacks must invoke these hooks.
5. Before the shared phase, capture actor state and call `bridge.begin_shared`.
   `combat_participants()` returns the stable records, not fresh snapshots.
6. Preserve source camera, waves/objective, enemies, global bubble, projectiles
   and ordinary pickup ordering. `world_two.after_pickups(dt, host)` then runs
   once. Its internal order is scene trigger, embedded-bot repair, checkpoint,
   authored coins, gates, trolleys, falling stock, course hazards, late carts,
   late drones, actor-scoped receipt/skill pickups, dead entity removal,
   checkout extension, and pending wipe scheduling.
7. `after_pickups` itself invokes `collect_level_pickups` for every living actor
   through `call_combat_participant`. Do not duplicate those calls in the outer
   scheduler. It does not take over the ordinary coin/item combat pickup pass.
8. Continue the source late actor effects and all-down ordering. Invoke
   `world_two.finish_frame(host)` once after all-down resolution and while the
   bridge is still shared. `over`, pause or another non-play mode freezes the
   pending callback. Finish with `bridge.end_shared` to reconcile relocations.
9. `hurt_combat_participant(record, from_x)` and
   `call_combat_participant(record, callable, args)` bind the actual victim or
   pickup actor. Never use these callbacks to run a world clock.

The checkout component owns its player map; the bridge publishes `bag`, `crate`,
`boss_hits` and `px` into each actor's scene state. Restart discards old state;
Continue retains the encounter. The optional `party_start` hook is initialization,
not a Continue hook.

## Verification

Godot 4.6.3, headless, isolated writable HOME and XDG directories:

- New `test_party_world_two.gd`: **103 checks passed** using actual PartyRuntime,
  PartyCombat, WorldTwo, supermarket hazards/course/combat and checkout objects.
- New `tests/test_party_world_two_source_contract.py`: **8 tests passed**,
  including seven-source function equality and source subsystem order.
- New `test_party_world_two_host.gd`: **34 checks passed** through the actual
  main and PartySession scheduler, including P2-triggered scene midpoint,
  checkpoint/Continue, slot-keyed ice, P2 input-shot attribution and replay.
- Existing `test_world_two`: 101 checks passed.
- Existing `test_supermarket_hazards`: 118 checks passed.
- Existing `test_supermarket_course`: 6,969 checks passed.
- Existing `test_checkout_boss`: 207 checks passed.
- Existing `test_checkout_integration`: 161 checks passed.
- Existing `test_party_combat_integration`: 26 checks passed.
- Existing `test_companion_context`: 58 checks passed.
- Existing `test_supermarket_integration`: 109 checks passed.
- Existing `test_course_integration`: 44 checks passed.
- Existing `test_aisle_integration`: 44 checks passed.
- Existing `test_stockroom_integration`: 21 checks passed.

The new fixtures deliberately set actor positions, wave completion and checkout
phase to isolate scene boundaries. They verify actor independence, exact shared
clocks/order, reset/pause and persistence through real bridge transactions. They
must not be described as ordinary-input co-op progression or hardware testing.

## Whole-route verification

All 42 existing solo World 2 input runs (seven stages times six housemates)
passed after the scene changes. These retain the existing explicit solo
invulnerability assist and do not certify difficulty or hardware.

The new `test_party_world_two_full_runs.gd` drives real PartySession frames with
source CompanionAI and the original solo normal-input P1 controllers. The
controller bodies are preserved in `party_world_two_drivers.gd`; the source test
compares every body against its original. The only access adaptation reads the
active slot's ice history instead of the original solo host-instance key.
Original controller-only shelf/card observations are maintained by the runner.
No gameplay state is edited except explicit invulnerability for both actors.

Initial JP + Maya CPU run passed all seven stages, every source party wave and
all three receipts. The CPU picked up and delivered two actual checkout crates,
received 27 credited checkout hits, and the real 90-HP encounter traversed all
three phases before jar completion. Catch-up relocations were counted separately:
two in 2-2, two in 2-3, eight in 2-5, none in the other four stages. This is not a
claim that the companion navigated those elevated routes without catch-up.

The all-six-CPU expansion now has passing complete runs for **42/42 stage/CPU
combinations**. JP CPU is paired with a Maya leader; all other CPUs use JP,
preserving the source distinct-housemate constraint. Raw results, the unsuccessful
original-driver attempt and its passing rerun are retained in
[`validation/world_two_party_routes.json`](validation/world_two_party_routes.json).

The original P1 drivers passed 41/42 combinations. JP + Theo CPU in 2-5 exposed a
human-test-driver limitation: its final drone remained just beyond the closed
scene cap at x9460 while P1 at x9400 kept walking/aiming into the boundary. The
source CPU was unchanged. A narrowly guarded P1 input maneuver now jumps while
shooting diagonally right when this exact live-geometry situation exists. It
needed six ordinary-input frames in the successful rerun, which defeated all
57 enemies, completed all 11 waves and three receipts, and reached real clear
in 6,714 frames. The final tightened default seven-stage Maya CPU suite was
then rerun and passed all seven, including enemy-count/no-escape assertions.
No position, damage, enemy, timer, ability or objective was changed. The original failure is not silently counted as a pass.

An additional six-CPU checkout audit observed **every CPU** pick up/deliver two
crates, land on all three receipt steps and score five or six phase-three screen
hits. All six checkout runs used **zero catch-up relocations**. A separate Maya
CPU aisle audit observed all five pad IDs (0,2,3,4,6), including 434 frames holding
a pad while P1 was off it. Elevated navigation in other stages did use source
catch-up and remains labeled as such in the recorded results.

Reproduce fast checks:

```sh
python3 -m unittest discover -s tests -p test_party_world_two_source_contract.py -v
godot --headless --path godot --script res://tests/test_party_world_two.gd
godot --headless --path godot --script res://tests/test_party_world_two_host.gd
```

Full routes need a longer timeout than the default 120-second unit-test budget:

```sh
godot --headless --path godot --script res://tests/test_party_world_two_full_runs.gd -- --cpu=maya
godot --headless --path godot --script res://tests/test_party_world_two_full_runs.gd -- --all-cpu
```

Use isolated writable HOME/XDG paths, as with the existing full-run suites.
`--level=2-6`, `--cpu=<housemate>`, `--trace`, `--max-ticks=<n>` and
`--output=<absolute-json-path>` are supported. The two-character invulnerability
assist means these results certify progression/ownership, not game difficulty.
