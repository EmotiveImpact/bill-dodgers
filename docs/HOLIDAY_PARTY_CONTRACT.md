# World 4 party phase and mutation contract

## Scope and evidence

`world_four.gd`, `holiday_combat.gd`, `holiday_foes.gd`, and
`holiday_captain.gd` now consume the actual stable mutable `PartyCombat` records.
The existing scalar solo path remains separate. `test_holiday_party.gd` passes
**154 checks** using real `PartyRuntime`, `PartyCombat`, actor-owned `Abilities`,
source metadata, world/foe controllers and Captain. Its tiny host only supplies
native scalar fields, presentation sinks and bridge callbacks. It is not a
mocked second actor, a main scheduler test, a complete party route or device QA.

The W4 adapter scope excludes main, party_session, the bridge, the
renderer or original web content. The integration owner wired the documented
scheduler, receipt clock and generic party-start seam. The additional
`test_holiday_party_host.gd` passes **79 checks** against actual main and inherited
production session.step. Its trace subclasses always call the real methods.
W4 is now in the production family admission list. The initial temporary start fixture has been
removed: the test uses production Session.start and cannot bypass admission.
Both suites are included in `scripts/verify-party.sh`. Reachable
mode selection, full two-human routes, controller input and touch acceptance
remain separately owned integration work. Complete ordinary-input CPU routes
are now covered separately in `HOLIDAY_PARTY_ROUTES.md`, including their explicit
invulnerability assist, source catch-ups and downed-actor limitations.

## Executable source audit

All references below are to `game/4-1/index.html`. The source blocks for
`updatePlay` (630–670), `W4` (989–1087), the gate helpers (767–789), and Captain
simulation (1305–1356) were compared byte-for-byte with all seven World 4 pages
and are identical. Authored metadata varies by stage and remains unchanged.

- 340–358: actor creation, generic slot spacing, then `W4.start`.
- 373–386: living/nearest queries and per-player falling/damage.
- 407–452: actor timers, downed revival, movement, landing, safe floor and firing.
- 453 onward: W4 CPU targets and Captain `aimX`.
- 630–670: pre-motion before CPU input and actor updates, then camera, waves,
  objective, W4 update, ordinary combat, Captain, jar and all-down.
- 767–789: camera gate eligibility and all-player slot-spaced relocation/healing.
- 926–927: source `g.concat(x2)` without sorting the appended sequence.
- 937–939, 1092–1093: custom-foe owner credit and per-player contacts.
- 952–985: all physical picks precede all human early Dash updates.
- 989–1029: deck slot placement, surface-first carrying, CPU deck clamp, water
  rescue and kept-coin age cap.
- 1046–1063: all-player checkpoint healing and once-shared world update.
- 1095–1238: suitcase, luggage, Bailiff, jet, inflatable, banana, melon and
  towel-grabber logic; banana seats credit their own firing shot owner.
- 1260–1283: one hold clock, 0.8 pair spawn interval, towel reset/reward.
- 1294–1302: sponsored gates and finish deliberately query **all** players,
  including downed players, unlike ordinary enemy targeting.
- 1305–1356: 120 pair HP (90 solo), nearest targeting, fixed body/valve damage,
  per-owner boss-hit tally, per-victim waves/charge and extra final-phase crew.

## Exact scheduler ownership

Call each once-shared function **once per source frame**, not once per actor.
Do not invoke `main.step` or an entire world controller from an actor callback.

### Start

1. Preserve normal world reset and solo floor construction.
2. Construct the final PartyRuntime actor roster and configure the bridge.
3. Begin a shared phase, call `world_four.party_start(host)`, and end it restoring
   slot 0. On a pedalo this replaces generic second-player minus-80 positioning
   with deck-left +120 +90*slot and sets each safe position. Other W4 stages are
   unchanged.
4. Call `holiday_combat.reset(host, final_roster_count)` once. It retains the
   authored wave entries plus the unsorted source x2 extension. Captain samples
   the final roster at encounter start, after the earlier world reset, to avoid
   accidentally retaining the previous stage's participant count.

### Frame

1. Increment host level elapsed once. Capture actor state, begin a shared phase,
   run `world_four.pre_motion(delta, host)`, end the phase, and restore slot 0.
   This must precede **both CPU decisions and normal actor timer decrements**.
2. Build CPU controls from the resulting current roster, before moving P1.
3. Bind and update each actor once. `world_four.after_motion(host)` and
   `world_four.fall_off(host)` are actor-only callbacks, not world updates.
4. Handle source revival at its owned actor boundary, then begin the main shared
   combat phase with a living representative when available.
5. Update camera once, respecting W4's gate/mini/hold/auto override.
6. Run waves once, then scene objective once. The final source base frame can
   continue after a clear/story event through `family_base_step_active(4)`.
7. Increment shared receipt presentation ages once at the session boundary, then
   call `world_four.before_combat(delta, host)` once. It runs checkpoint/set
   triggers, all living actor pickup callbacks, all living **human** early Dash
   callbacks, hold/bonus clocks, custom foes and Captain start in that order.
   Do not also execute the generic late Dash pass for W4.
8. Ordinary enemies, the one global held-enemy bubble pass, player shots and
   hostile bills, then pickups, each once. The held-enemy clock must not run for
   every actor's ability instance.
9. `world_four.boss_tick`, `world_four.jar_tick`, ordinary combat visual clocks,
   then all-down after objective/jar resolution. Boss presentation events drain
   once; their damage/rewards are already applied by their controllers.
10. Per-actor ability effects, shared visual expiration, then
    `world_four.finish_frame(host)` once. Keep the bridge open through the gate
    midpoint so all actor relocations and healing reconcile before end_shared.
11. End shared phase and restore slot 0 plus its scene facade.

Source downed actors still decrement invulnerability and power timers before
entering their inline revival branch inside `updatePlayer`. The integration
owner updated PartySession to retain that inline actor order with
tick_revive_actor, rather than skipping all downed actors and performing revival
after every living actor has moved. The actual-main W4 fixture exercises this
lifecycle, including downed-P1 rescue, all-down and Continue. A downed actor is
not carried by the pedalo in source: the rescue fixture uses a real banana
camera pause so the boat and nearby helper stay in range during the rescue.

## Mutation contract

`combat_participants()` must return stable records throughout each shared phase.
The same record identities survive nested actor callbacks. The world does not
refresh or rebuild the roster. `host_player=true` selects the retained solo
facade path; a non-host roster selects the party branch.

| Operation | Once-shared changes | Actor record/facade changes |
| --- | --- | --- |
| pre_motion | level_time/elapsed, each deck/bob surface, supported bots, kept-coin cap | supported living actors' p/px; grounded CPU deck clamp; water victim p/px, velocity, grounded, on_platform, invincible, then scoped damage |
| after_motion | none | active actor's safe_position only |
| fall_off | none | active victim's position/velocity/platform flags and damage, using its own safe_position |
| checkpoint | one checkpoint latch and presentation event | all actors hearts=3; downed actors down=false and invincible=2 |
| gate midpoint | one wipe latch, camera, deck translation, clears shared bots/bullets, retains controllers | each slot x=base+90*slot, own floor, p/px, zero velocity, grounded, on_platform=false, safe_position; all-player healing |
| pickups | each coin/item removed once; kitty once | collector's coins, hearts, power, power_time |
| projectile kills | target HP/state and shared coin drop once | explicit firing owner's pop_count |
| Captain hits | fixed one-point body or three-point valve damage | explicit firing owner's scene_state.boss_hits |
| hold/bonus | shared timers, source spawn sequence, towels, reward/bonus once | no personal coin credit for shared rewards |

W4 support is geometric: an actor is carried if grounded, alive and within the
old surface bounds/height. There is no additional actor-owned W4 water timer,
boat pointer or towel inventory to bind. Towels belong to grabbers and the shared
hold controller, not to players. The only scalar scene field which needs host
capture/apply here is the existing **safe_position**. `px` and `boss_hits` are
already supported by the bridge's scene-field dirty merge.

Water resets pre-existing invulnerability before calling the actual victim's
hurt handler, so Maya's own passive can block the hit. It preserves the old safe
checkpoint, restores horizontal speed to zero after damage knockback, and uses
deck center -40/+40 for slots 0/1. Source clamps even a downed grounded CPU to the
deck but never silently revives that actor. Downed actors otherwise do not ride
moving surfaces or undergo water rescue.

Manual gates use camera actors: humans, including downed humans, rather than CPU
progress. Sponsored gates use all players. Enemy/custom-foe/Captain targeting uses
living actors, nearest horizontal distance and first roster actor on ties.

## Required host APIs

- `combat_participants()`: stable records, not read-only actor snapshots.
- `hurt_combat_participant(record, from_x)`: invoke exactly the victim's damage
  handler, including their own character passive and movement immunity.
- `call_combat_participant(record, operation, args)`: bind only that actor around
  pickups, early Dash or an actor-reading helper, then restore previous facade.
- `credit_combat_pop(owner_slot=-1)`: -1 means currently bound direct actor call,
  nonnegative means exact firing owner, -2 means intentionally unowned.
- `party_capture_scene(actor)` / `party_apply_scene(actor)`: bind safe_position
  before/after every temporary facade swap, including nested callbacks.
- Every normal and invisible ability shot stamps `owner_slot` and `owner_x`.
  First-frame sweeps prefer the current owner record, matching the source owner
  reference. A downed firing actor still owns its projectile. Missing party
  ownership can damage targets but never credits whichever actor is active.
- `collect_level_pickups` must not increment global receipt ages per actor.
  Session increments them once before W4 before_combat. It must grant an actually
  collected shared card to the full roster, as the source global skills list does.
- `holiday_dash_step` is early W4-only; the controller skips CPU records.
- `combat_bubbles_tick(delta)`: one global held-enemy phase.

## Verification run

With isolated writable HOME/XDG directories, Godot 4.6.3:

- `test_holiday_party.gd`: **154 checks, zero failures**. All seven source wave
  plans, pedalo starts/carry, boat/belt support, CPU clamp, water and normal fall
  recovery with per-victim Maya passive, independent safe floors, all-player
  checkpoints/gates, downed-human gate eligibility, early pick/Dash order,
  source sponsored bonus conditions, ordinary/custom contact and ownership,
  shared pickups, towels/banana seats, Captain pair HP/crew/targeting/hits/waves/
  charge/jar and persistent actor tallies.
- `test_holiday_party_host.gd`: **79 checks**, passing. Exact actual-main phase
  trace, independent engine key input, owned normal/ghost shots, CPU pre-motion
  observations, one receipt clock, real P2 receipt collection/save, early Dash,
  water damage/passive/timer order, pause, moving-deck rescue with source camera
  pause, all-down/Continue, Captain/jar clear and all seven CPU frame smokes.
- `test_full_holiday_party_runs.gd`: **42/42 unique stage/CPU combinations**
  have passing coverage across the first full matrix and final six Captain
  reruns, using actual production admission, main/session and unmodified CPU
  AI. Totals: 383,759 ticks, 354 waves, 1,794 source pair entries, 126 physical
  receipts, 30 manual gates, 42 set pieces and 42 saved clears. Both actors have
  an explicit invulnerability assist; CPU catch-ups, falls, water damage,
  90,240 downed frames, 15 checkpoint rescues and nine clear rescues remain
  recorded. See `HOLIDAY_PARTY_ROUTES.md` and its raw evidence for methodology,
  the human input-driver repair and exact limitations. This is not normal-health
  or autonomous companion navigation certification.
- `test_full_holiday_runs.gd -- --jp-only`: **6/6 non-Captain solo routes**,
  60,401 ticks, all 55 waves/229 source entries, 18 physical receipts, five gates,
  six encounters and six saved clears. Three normal source fall recoveries.
  Existing invulnerability-only assist retained; no route teleports or timeline,
  health, pickup, enemy or clear edits. This is regression evidence, not normal
  difficulty or party route certification.
- `test_holiday_runtime.gd`: **164 checks**, passing.
- `test_holiday_captain.gd`: **155 assertions**, passing.
- `test_holiday_lifecycle.gd`: **634 checks**, passing.
- `test_holiday_renderer.gd`: **153 checks**, passing.
- `test_holiday_captain_renderer.gd`: **98 assertions**, passing.

The pre-existing six-character solo full-route evidence remains documented in
`HOLIDAY_NATIVE_PARITY.md`; these focused fixtures do not convert it into party
route evidence. No physical phone, controller, multitouch, export, signing,
installation or deployment is certified by these results.
