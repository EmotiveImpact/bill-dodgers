# World 5: Moving Day native implementation

Standalone modules for all seven original stages. Shared host integration is owned by the campaign integrator; this report does not establish phone/desktop visual parity or an unaided end-to-end playthrough.

## Source and stage inventory

The original `game/5-*/index.html` files are unchanged. The port reads existing imported META/art instead of replacing levels with generic geometry. Source reference: `game/5-1/index.html` lines313–679 (base geometry/player/combat/frame order),731–1200 (W5 systems),1209–1518 (painter),1680 onward (abilities/final fixes). SHA-256 for the audited 5-1 HTML: `27f1f17ab113d217341a9eaf2afd4bb20361d85fd4c105afa2321d4ff86f1f53`.

| Stage | Authored banner | Waves | Solo wave entries | Surfaces |
|---|---|---:|---:|---:|
| 5-1 | Stage 5-1: box mountain | 12 | 74 | 37 |
| 5-2 | Stage 5-2: sofa round the corner | 21 | 78 | 12 |
| 5-3 | Stage 5-3: lift's broken | 13 | 36 | 41 |
| 5-4 | Stage 5-4: flat-pack frenzy | 13 | 73 | 25 |
| 5-5 | Stage 5-5: van chase | 15 | 42 | 5 |
| 5-6 | Stage 5-6: the Cardboard King | 3 | 14 | 4 |
| 5-S | Bonus: bubble wrap bonanza | 9 | 27 | 70 |

## Modules and units

- `world_five.gd`: copied live surfaces, exact geometry ties, checkpoint/Continue, scene wipes, sofa carry/tipping, proximity mimics, warned falling boxes, shutters, vehicle slots, lift malfunction, low bridges, clocks, bonus bounce and objective gates.
- `moving_day_combat.gd`: source W5 wave scaling and progress axes, ordinary/shutter/vertical/scooter/vehicle spawns, removal men, live surface identities, hops, tape/big/flat bills, player shots, held-sofa bill blocking, coins/items and boss event bridge.
- `cardboard_king.gd`: three independent 26/32/38-HP phases (34/42/49 for pairs), crown and dizzy multipliers, collapse/helper/rebuild cycles, throw/stomp/charge attacks, final defeat and jar collection.
- `moving_day_renderer.gd`: original room/floor/box/vehicle/sofa art and live procedural W5 geometry. It reuses tested command primitives and shared bot/crate/coin/item painters, not festival backgrounds or mechanics.

Coordinates use absolute player feet. Durations are seconds, velocities pixels/second; authored JSON remains source milliseconds and pixels. The maximum host simulation step should remain34ms. Runtime/surface mutations never touch imported META.

## Shared host integration contract

1. On load, select family5 before geometry queries; clear previous actors/coins/boss and reset source W5 runtime/combat. Then call `world_five.seed_pickups(host)` once, after clearing coins. Resolve initial feet via `below(start, ground-10)` for the vertical lift stage or `below(start, ground-3000)` for other stages, and reset cameraY accordingly.
2. Route surfaces/land_on/below/wall_clamp/inside_wall/fall through the W5 runtime. Walls ignore tops at `feet-15`, not W3's `feet-6`. Source stepping supports +/-15px solid support adjustment. `carry_player(dt,host)` is after support/wall clamp and before gravity. `landing(host,surface)` applies the source mattress bounce.
3. `base_displacement` preserves source270px/s and the previous frame's0.78 sofa-carry penalty. Shared abilities apply separately. Keep the existing source W5 own wall-jump implementation.
4. After player/ability movement but before camera/waves, call `before_camera(dt,host,controls)`. It handles scenes/checkpoint/clock/mimics/drops/shutters/out-of-reach bots/movers/lift/finds/bridges/sofa in source order. Do not call these again after pickups.
5. Camera follows normally with `camera_cap` for the sofa. Timed van stage forces vertical desired camera0. W5 does not freeze camera for wipes. Its stage5-3 waves use vertical ascent,5-5 uses elapsed milliseconds, others camera x.
6. Run waves -> objective -> ordinary enemies -> bubbles -> player shots and bills -> coins/items -> boss -> jar -> late ability effects/ghost expiry -> knockout -> guarded `finish_frame`. `objective_tick` internally starts King; `jar_tick` returns `clear`. A clear during objective evaluation still executes the source final combat/base frame.
7. Source receipts use `META.txt`, exact horizontal36/vertical90 feet-distance; skill card uses44/110 and grants wall-jump. `before_camera` calls shared collection at its source phase. Use source top-level text for banners/clear/end.
8. Continue restores3 hearts/inv2.5 then `respawn(host)` without reloading or discarding progression. Scene wipes relocate players to `to+i*60`, sofa to `to+200`, cameraX to `max(0,to-200)`, cameraY to first player feet-ground; behind-scene enemies pop. They do not clear bullets/coins or rewrite safe position.

## Preserved unusual source behavior

- `landOn` keeps the first identical-height overlapping surface. Thus floor belts obscured by an earlier ground surface do not carry; raised belt platforms do. Do not silently reorder surfaces.
- A timed van wave is not considered complete until its ordinary bots have left/died; entries can overlap across wave clocks.
- Bonus timeout is only an end predicate. All authored waves must still complete before the2.6s clear countdown, as in source. It does not immediately grant victory.
- Sofa bill blocking occurs after player contact checks, so holding the sofa does not make the carrier generally invulnerable.
- King body hits ignore projectile `dmg`, then multiply crown and dizzy bonuses. King jar pickup uses x and age, not player height.
- Temporary health scaling/party-count tests do not claim a native second-player implementation.

## King ability-coordinate functional repair

The original `startKing` omits `boss.fy`, but shared special attacks read it. This makes several targeted effects produce invalid coordinates or fail proximity tests. The native adapter deliberately exposes finite `fy=ground`, consistent with the earlier Binman repair. Ama can dizzy and land a ghost hit; Maya, pound and football can pass their normal height checks. The source King body/crown/dizzy damage rules, armour, phase gates and physical hitboxes remain unchanged. This is a functional correction, not source-identical behavior, and the original HTML is untouched.

## Reachable first-receipt functional repair

Original stages 5-1, 5-2, 5-4 and 5-6 author their first receipt at x=-250, unreachable under the source camera floor and player clamp. The native `corrected_receipt_position(host,index)` places only this receipt at x=60 with original y and unchanged save identity. Later receipts and imported source rows remain unchanged. All six characters can collect it by ordinary left/jump input with zero score reward and exactly-once saved identity. This explicit functional repair is not source-identical placement.

## Explicit reliability/visual choices

Source wall-clock wipe/helper/double-stomp callbacks are run-local simulated timers that freeze while paused/over and cannot mutate a new run. This is an intentional reliability correction. Rendering does not consume combat RNG. Source random art jitter uses stable positions; window-layer theme easing uses the current room's target rather than draw-count-dependent easing. Some particle flourishes and tiny procedural decorative details remain visually simplified; all physical actors/hazards and original image assets are retained. These are not screenshot-parity claims.

## Verification

- `test_world_five.gd`:83 assertions passing, including all seven source-data resets, immutable META, traps, strict timer edges, sofa doorway/scene relocation, lift carrying/malfunction, conveyor tie semantics, pair entry scaling, vehicle identities, low bridge/large scooter spawns, timing/bonus conditions and all King phases/jar.
- `test_world_five_renderer.gd`:369 assertions passing, including every W5 asset's actual dimensions, view sections of each stage, valid command crops, original sofa orientation, conveyors/vehicles/King geometry and simulation/RNG purity.

- `test_world_five_integration.gd`:197 assertions passing against actual main, including all seven loads, original asset draw execution, 24 ordinary-input repaired receipt routes, reset/Continue, conveyor/bounce/sofa and finite King special coordinates. Positioned interaction fixtures are separate from traversal claims.
- `test_full_moving_day_runs.gd -- --all-characters`:42 complete input-only routes passing across all six characters and all seven stages. Tests repeatedly grant invulnerability and start with movement cards earned in preceding worlds. They never rewrite player position, camera, geometry, waves, bosses, kills or clear state after load. Each route verifies all waves complete, normal clear mode and immutable source META; limit700 simulated seconds per route. Observed completion35.7–366.1 simulated seconds. This proves assisted scripted progression, not unaided difficulty, human play or device performance.

Run each with an isolated HOME/XDG directory and `godot --headless --path godot --script res://tests/<suite>.gd`. Engine editor import alone does not force every unused script to compile; these explicit preload/runtime suites are necessary. Native exports, physical device controls and independent interactive difficulty testing remain separate gates.
