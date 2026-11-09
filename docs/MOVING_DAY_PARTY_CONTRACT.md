# World 5 party phase and mutation contract

## Acceptance boundary

The native Moving Day world and combat adapters use real persistent PartyCombat
records. `test_moving_day_party.gd` passes **180 checks**; the actual-main suite
`test_moving_day_party_host.gd` passes **127 checks**. The latter uses production
main/session admission and stepping, with no start/gate override. Neither focused suite
is a full-route, physical controller, multitouch, phone export or difficulty test.

The adapters live in `world_five.gd` and `moving_day_combat.gd`, with focused
tests. Main/session scheduling remains a separate module boundary. `cardboard_king.gd`
already accepts a living roster and source participant scaling, so its existing
simulation was verified rather than unnecessarily rewritten. Its native finite
feet repair and reachable first-receipt repair remain intact.

## Source audit

`tests/test_moving_day_party_source_contract.py` passes six executable-source
audit tests, with subcases across every W5 page. The following blocks are
byte-identical in all seven source pages:

- Actor creation/start and source slot spacing, `game/5-1/index.html:342–363`.
- Player update, including per-actor carrying and safe floor, 409–450.
- CPU update, 451–482. The source CPU is unchanged.
- Friendly/hostile projectile update, 534–565.
- Base frame scheduler, 640–683.
- Extra wave plan, 1393–1395.

The W5 closure, 731–1205, differs only in an unused sofa render-height multiplier
on 5-3/4/5/6/S. Only 5-2 authors a sofa, and its actual source multiplier is 0.28,
which the native version retains. All simulation logic in this closure agrees.

Important source details:

- Scene changes relocate **players**, not just living actors, to dest+60*slot.
  They reset x/previous-x, y, velocity and grounded; they do **not** heal, revive,
  reset on-platform or replace safe floors.
- Checkpoint triggers need a living actor, but restore the complete roster to
  three hearts and 1.2s immunity, including downed actors.
- Each actor has its own sofa `carry`. Every frame clears carry for all actors,
  then marks nearby grounded living carriers. Only carriers receive 0.78 normal
  movement speed. Either actor's real down input can tip the sofa after strictly
  450ms. Sofa height uses the shortest participating character.
- Lift riders are grounded living actors geometrically supported by its old
  floor. A downed actor is not carried. The lift, vans, drop traps, beams, sofa
  and bonus clock each advance once, independent of roster size.
- Extra waves append a rush bot 600ms after the final authored entry, with side
  determined by original group length parity, unless `extra:false`.
- Pair removal men have 34HP, vans/flatbeds have three riders, and King phases
  have rounded 1.3x HP: 34, 42, 49. Collapse helpers are 3+phase.
- A friendly shot sweeps from its current owner's x on its first frame, including
  a downed owner. Kills and boss-hit tallies belong to that exact actor.
- Overlapping hostile bills, falling boxes and boss waves can contact both actors
  during one source loop. Each victim uses their own immunity and character
  passive. The source does not stop its victim loop after the first contact.

## Exact integration order

### Level start

1. Construct the normal world surfaces and source scene state.
2. Create final PartyRuntime actors and configure the bridge.
3. In one shared phase call `world_five.party_start(host)`, then restore slot 0.
   Every actor floor is independently resolved with source y query GROUND-3000,
   or GROUND-10 on vertical levels. Set own safe/checkpoint/previous-x and clear
   each own carrying flag.
4. Call `moving_day_combat.reset(host, final_roster_count, seed)` once. King
   samples that count when its encounter starts.

### Frame

1. Host elapsed increments once. Gather all CPU and human controls before moving
   either actor. W5 has no W4-style shared pre-motion step.
2. Bind each living actor and run its movement/ability pre-step once. The existing
   W5 `carry_player` belongs **after wall/support resolution and before gravity**.
   `landing`, `after_motion`, and `recover_from_fall` are actor-only callbacks.
   Revive remains in source actor order, including timer prelude for downed actors.
3. Begin the main shared bridge phase with a living representative if available.
4. Increment shared receipt ages once, then call
   `world_five.before_camera(delta, host, inputs)` once. In party mode `inputs`
   must be the **whole `{slot: controls}` dictionary**, not P1 controls alone.
   The retained solo call takes its ordinary flat controls dictionary.
5. This shared world phase owns scene/checkpoint triggers, bonus clock, mimics,
   falling crates, shutters, out-of-reach cleanup, vehicle/lift updates, per-living
   actor physical receipt/card collection, beams and one sofa update, in order.
6. Camera once, waves once, objective once. A final clear/story base frame must
   continue through the existing `family_base_step_active(5)` guard.
7. Ordinary enemies, one global held-enemy bubble pass, friendly shots/hostile
   bills, physical coins/items, each once. Then each actor's late skills.
8. King once, jar once, combat visual bookkeeping once. Check all-down only after
   objective/jar resolution; a downed P1 must not end a living P2's game.
9. Per-actor ability effects, shared visual expiration, then
   `world_five.finish_frame(host)` once while the bridge remains open, so delayed
   all-roster scene relocation merges before P1 restoration.
10. Close shared phase and restore P1 native **and scene** facade.

### Continue

PartyRuntime revives both actors without reloading the encounter. Run W5's
checkpoint `respawn(host)` once inside a shared bridge transaction, preserving
source all-roster relocation and each actor's existing horizontal speed. The
world callback itself does not heal. Host Continue supplies 3 hearts/2.5s immunity.

## Host API and scene state

- `combat_participants()` returns stable mutable records within shared phases.
- `hurt_combat_participant(record, from_x)` binds only the actual victim.
- `call_combat_participant(record, operation, args)` scopes pickup and carry
  writes without stepping the world or refreshing the roster.
- `credit_combat_pop(owner_slot)` uses -1 for the currently bound direct actor,
  nonnegative for the exact shot owner, and -2 for intentionally unowned damage.
- Normal and invisible ability shots stamp `owner_slot` and `owner_x`.
- `party_capture_scene(actor)` and `party_apply_scene(actor)` must transfer both
  `safe_position` and `carrying` to/from W5's scalar facade on every swap.
- Carry writes use scoped callbacks, so `carrying` need not be added to the
  bridge's dirty-record scene field list. `boss_hits`/`px`/`safe_position` already
  use its stable scene-field reconciliation.
- Receipt ages must not also increment inside each scoped pickup call. An
  actually collected card must be shared to both actor-owned skill instances.
- `combat_bubbles_tick(delta)` is global once; Ama's actor instance owns its
  release damage/credit even when P1 is bound for ordinary shared combat.

## Focused verification

Godot 4.6.3, isolated writable HOME/XDG directories:

- `test_moving_day_party.gd`: **180 checks, zero failures**. All seven exact pair
  wave plans; per-slot floors/carry/safe; source sofa tipping/shortest-height;
  lift rider/drop rules; vehicle movement; all-actor checkpoints/wipes/respawn;
  nearest targeting/ties; per-victim passives; coins/items; both-actor contact;
  current-owner sweep/kill credits; all three King HP pools/helpers/waves/hit
  tallies and physical jar.
- `test_moving_day_party_host.gd`: **127 checks, zero failures**. Exact inherited
  production phase trace; native P2 D-key input; pre-motion CPU intent; shared
  clocks; per-actor carry slowdown; all-actor delayed scene wipe; real P2 receipt
  save and shared wall-jump card; lift, pause, rescue, all-down/Continue; P2 Ama
  finite-feet King ghost/credit; one bubble clock; jar/normal final-frame clear;
  all seven CPU and P2 stage smokes.
- Existing solo `test_world_five.gd`: **83 checks**, passing.
- Existing solo `test_world_five_renderer.gd`: **369 checks**, passing.
- Existing `test_world_five_collectibles.gd`: **2,370 checks**, passing. Includes
  126 local receipt fixtures/replays, six card/use and six input-only lift runs.
- Existing solo `test_world_five_integration.gd`: **197 checks**, passing, including
  24 input-only repaired-secret routes.
- `tests/test_moving_day_party_source_contract.py`: **six tests**, passing.

Full input-driven party route results are recorded separately when available.
The source CPU's permitted catch-up relocations are counted as relocations,
never described as successful pathfinding. Repeated invulnerability, if used
by a route fixture, is explicit and does not certify ordinary difficulty.

## Completed CPU route matrix (2026-11-09)

After the shared CPU Dash/aim source-order corrections, all **42 unique stage/CPU
identity combinations** passed: seven stages for each of JP, Maya, Ama, Leo, Theo
and Mei as the CPU. The leader is JP except when the mate is JP, where it is Maya.
This is not a 36-pair cross-product. Evidence is stored in
`verification/moving_day_party_cpu_acceptance.json`, including raw JSON hashes.

Totals: **416,164 ticks, 516 waves, 2,490 authored pair entries, 126 physical
receipts**, all normal saved clears. Sofa routes exercised both carriers and all
five transitions; lift/van/King/bonus routes used their actual runtimes. King
phases used the source paired HP pools (34/42/49); the two actors registered
534/115 boss hits across six fights.

The explicit assist was repeated invulnerability for both actors plus inherited
previous-world skill unlocks. The human route driver used ordinary controls only
after stage load. There were **67 source CPU catch-ups**, one CPU fall, and zero
downed frames, revivals or clear rescues. Catch-ups are not claimed as successful
pathfinding. No normal-health difficulty, physical device or two-human acceptance
is implied. The earlier seven scripted-P2 routes also passed but are not a full
human-controller/device matrix.
