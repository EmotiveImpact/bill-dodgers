# World 3 party combat and world integration

## Implemented boundary

`godot/src/festival_combat.gd` now works with `PartyCombat` stable records for
ordinary and invisible ability-shot ownership, Wellies stomp ownership, and
accepted boss-hit contributions. Existing roster targeting, damage victims,
pickup writes and boss victim snapshots remain in place. All existing visual
and sound callbacks are retained.

- `damage_enemy(host, enemy, damage, owner_slot = -1)` and
  `kill_enemy(host, enemy, credited = true, owner_slot = -1)` preserve old call
  signatures. Direct actor callbacks default to their bound actor; projectile
  hits pass their explicit owner. `-2` is deliberately unowned.
- A party projectile with no owner can damage enemies but cannot award P1 a
  kill. A missing/nonliving owner is not replaced with the nearest actor.
- The first-frame sweep looks up the firing actor's current record x, including
  a downed owner, before using the saved `owner_x` fallback. Ghosts retain their
  ordinary unswept source origin unless explicitly marked `first_frame`.
- Successful boss hits increment the owning record's `boss_hits`, already
  persisted by the bridge into the actor's `scene_state`. Rejected hits and
  unowned hits do not award contributions. Solo's existing no-tally facade is
  unchanged.
- Wellies uses the stomper's slot and updates only that actor's vertical
  rebound. Popped enemies still drop their coins exactly once.
- Damage goes directly through `hurt_combat_participant`. Do not pre-call
  `combat_participant_blocks_damage`: that would consume Maya's alternating
  passive twice for the same attempted hit.

The caller still owns exactly one `enemies_tick`, one `combat_bubbles_tick`,
then `projectiles_tick` and `pickups_tick`. No new bubble or world tick was
introduced inside this combat module. Ama's deferred bubble-release callback
must bind Ama before spawning its owned ghost shot.

## Source evidence

The common implementation was inspected in all seven `game/3-*/index.html`
files, excluding embedded asset data:

- Lines 345–375: roster creation, mean living feet for spawn floor, stable
  horizontal nearest-player targeting.
- Lines 480–579: ordinary enemy contacts, `killBot(b, by)`, first-frame owner
  reference, shot/ghost owner kills, `owner.bossHits`, individual coin/item
  collection, bills that can strike multiple overlapping players, and tie
  assignment even when damage is rejected.
- Lines 1172–1182 and 1218–1219: per-player tie/mud speed, support and carry,
  Wellies stomp owner and rebound.
- Lines 1294–1340 and 1350 onward: global phase order, all-player tied clocks,
  checkpoints, shared movers/trailer, party harvester HP, source wave flag
  filtering and boss `hp2` selection.
- Lines 1772–1776 and 1995–2034: owned ghost shots, held-bubble exclusion and
  release, and exactly one damage-passive evaluation.

## Focused verification

`res://tests/test_festival_party_combat.gd` runs the real combat module,
`world_three.gd`, `festival_boss.gd`, `PartyRuntime`, `PartyCombat`, `Abilities`
and `MovementSkills` against an isolated host facade. It reuses the W1/W2 test
host's scalar declarations, not its combat implementation.

65 checks pass with Godot 4.6.3, covering:

- Nearest targeting, downed filtering, stable ties and one enemy clock tick.
- P2 damage, own character height/ducking, Maya's first/second/third/fourth hit,
  independent dash immunity, overlapping victims and tie record attribution.
- Human and CPU coin, heart, power and Wellies stomp attribution, plus merge
  persistence and one set of pickup presentation callbacks.
- Live owner-reference sweep, ordinary and ghost kills, downed owners,
  explicit unowned/missing/unknown owners, direct scoped kills, uncredited
  cleanup, own ability-meter charge, and shove-before-drop order.
- Boss-hit contribution and phase persistence, rejected hits and filtered boss
  victim indices after P1 goes down.
- One global held-bubble pass, source reordering, Ama-owned release ghost and
  restored facade.
- Exact party wave entries/order in all seven stages, exact boss `hp2`, and
  the source 1.3x harvester HP.

Run using an isolated HOME and XDG directories, as `scripts/verify-native.sh`
does. Treat script errors in the log as failures even if Godot exits zero.
This is shared-phase integration evidence, not a completed native co-op route,
real controller/multitouch test, or permission to expose family modes.

## Implemented World 3 adapter contract

The world-facing changes live in `world_three.gd` and
`festival_queue_rush.gd` (inherited by hayride). The coordinated host integration
supplies actor scene bindings and the once-per-world scheduler. Native mode
selection remains gated independently of these fixtures.

### Actor-scoped scene state

Keep these values on each actor and bind/capture them around actor callbacks:

| Actor scene key | Existing WorldThree facade | Meaning |
| --- | --- | --- |
| `safe_position` | `safe_position` | Absolute native feet used by fall recovery. |
| `tied` | `tied` | Remaining seconds. Starts at zero per actor. |
| `standing_surface` | `_standing_surface` | Original live surface dictionary, not a deep copy. |
| `px` | No current W3 scalar | Source previous x, if retained by the adapter. |

Use `party_capture_scene(actor)` and `party_apply_scene(actor)` to bind those
three existing facade values. Preserve surface object identity so late mover
and trailer mutations are seen by the next frame's carry. Do not capture
`level_time`, `elapsed`, `cam_dx`, `_camera_before`, scene/wipe state, tents,
movers, harvester state or boss state with an actor.

The bridge publishes and dirty-merges the shared writable scene fields.
`set_tied` writes `participant.tied`, which must reconcile into actor state
before any later movement callback. Scene transitions now write the canonical
`participant.safe_position`, matching `scene_state.safe_position`, rather than
an unrelated `safe` property. Surface dictionaries keep their original identity
through the bridge. `boss_hits` and `px` use the same scene-state mechanism.

During shared phases, update every record's `tied` exactly once at the source
late timer point, including downed players. In party mode do not also decrement
the currently bound facade's tie. Capture/apply must restore that actor's result
before subsequent base motion and ability movement nudges. Tie slows only its
victim to 0.45 speed and disables only the normal jump, not the earlier
down-plus-jump platform-drop branch.

### Separate per-actor work from one shared frame

1. Run source CPU decisions and actor motion once per actor with its own
   support/tie/safe state. Preserve old-camera clamp, W3 carry-before-wall order,
   squash/recovery and cached base lock. `_actor_step` already contains these
   solo branches; never call the entire main step for each actor.
2. Update source downed timers/revival in the actor phase. Source still decays
   downed players' invulnerability and weapon duration before returning from
   `updatePlayer`; skipping their entire actor phase requires that small timer
   phase separately. Freeze all of this on pause/story/Continue UI.
3. Capture actors and begin the stable shared phase. Camera motion/easing and
   `world_three.after_camera` run once. Follow the human roster, including a
   downed human while a teammate is alive; CPU does not drive the camera.
   Auto-scroll W3 stages can advance before final all-down resolution.
4. Run waves, objective, enemies, one global bubbles pass, projectiles and
   pickups in existing solo order. Reset combat with the actual roster count,
   on fresh level and restart.
5. At the beginning of the one `after_pickups` call, evaluate
   `collect_level_pickups` once for each living actor through scoped callbacks.
   Do not run all of `after_pickups` for each actor: it advances shared timers,
   scene triggers, bonus clock, movers, trailer, harvester and effects.
6. Keep the existing scene/events/coins/cheer/tent/tie/checkpoint order.
   Checkpoint healing/revival covers all records. It must not be rolled back by
   a stale active facade when the shared phase ends.
7. `festival_queue_rush.banners_tick` tests all living participants
   with each actor's `height` and source `player_animation == "crouch"`, routing
   damage through the victim callback. Hayride inherits this adapter.
   Night fire and harvester contact already iterate living participants.
8. Tick movers, spotlights, trailer and harvester once. Both actors consume the
   previous shared support displacement during their next ordinary movement
   phase, as the source does. Do not move shared surfaces during an actor bind.
9. Run each actor's late skills once, then boss, jar and visuals once. Apply
   all-down only after objective/clear and boss/jar outcomes; a surviving mate
   may finish. Run per-owner ability effects and one ghost-expiry pass afterward.
10. Apply `finish_frame`/wipe callback once at the original post-effect point.
    Rendering may bind actors for their own character/effect/decor layers, but
    must restore P1 and never advance any of the above clocks.

### Scene transitions and recovery

In party mode, one authoritative record loop in `_apply_scene_transition`
replaces independent edits to the active facade and records. Translate every
actor, including downed actors, by the
same one-time camera delta. Clear horizontal velocity; in non-auto scenes find
each actor's own floor and clear vertical velocity when one is found. Update
that actor's `safe_position` and `px`. Keep source grounded/platform/support,
cameraY/speed, invulnerability, power, tents and coins unchanged. Translate the
shared trailer/harvester once and clear enemies/shots once. Retain existing
generation guards, delayed render-phase timing and pause behavior. Wipe focus
matches `game/polish.js:113–120`: the mean x of non-down/non-out actors, falling
back to all actors, clamped into the central 22–78% of the canvas. This is not
the human-only camera-follow roster.

Fall and squash recovery must bind the recovering actor's safe position and
damage immunity. CPU catch-up must not borrow another actor's stale support;
invalidate/re-evaluate that actor's cached surface on its next carry check using
the source geometry validation. Restart clears per-actor scene fields normally.

### Actual-main fixtures and remaining acceptance

`res://tests/test_festival_party_world.gd` passes 78 actual-main checks for:

- One shared world/ability clock and owned shots in all seven stages.
- P2 tie persistence, expiry, slowed movement and blocked normal jump.
- Independent safe-position recovery and actual victim damage.
- P2 queue/hayride banner collision, own Maya passive and own crouch animation.
- Checkpoint revival/protection of both actors, P2 receipt pickup and shared
  earned ground-pound card.
- Two actors using distinct mover deltas and preserving live surface identity.
- Two riders consuming one previous trailer delta, plus one late deck update.
- Living and downed actors translated once by non-auto and auto scenes,
  canonical safe/previous positions, one shared deck/harvester translation,
  retained support/power/airborne state, delayed/pause-safe callbacks, repeat
  callback immunity and source mean focus.
- CPU catch-up through ordinary scheduling, stale-support rebind, source
  downed timer decay, nearby revival and pause freeze.
- All-down, Continue without encounter reset, and bonus clear taking priority
  over same-frame all-down.

W3 is now admitted internally by `PartySession`; native mode selection remains
hidden. The fixture uses production initialization when admitted. Its explicit
dormant-session fallback is only a focused adapter fixture if that admission is
disabled, never evidence of reachable production progression.

## Complete CPU progression harness

`res://tests/test_full_festival_party_run.gd` runs the real admitted main scene
with a production CPU companion. It accepts `--level=3-1`, `--character=jp`,
`--all-characters`, `--trace` and `--events`; without selectors it runs JP
through all seven stages. Each leader pairs with the next entry in the source
housemate roster, covering every leader and every CPU identity once per stage.

The separate `festival_party_route_controls.gd` copies the certified solo
tests' ordinary input controllers. It does not set positions or alter enemies,
waves, timers, boss HP, scene transitions or completion. Night/Tout's solo
boss-observation holds are disabled in the controller because an independent
CPU can keep shooting during such a hold. Existing solo suites retain those
pattern-observation tests.

Each stage starts from a clean save with no learned movement skills. Big Top
must collect the actual shared ground-pound card and perform an observed
ground-pound landing; no skill is injected. The only gameplay assist is
refreshing invulnerability for **both** actors in non-bonus stages. The bonus
runs without that assist. These are progression/attribution tests, not proof of
unaided combat survival.

Every completed run checks all authored party wave entries, all three receipts,
natural clear, real party-scaled boss damage, shared clocks advancing once,
immutable imported metadata, and frozen post-clear settlement. Combat stages
require both actors' owned shots and CPU kills. Big Top requires actual moving
trapeze support; Hayride requires both actors riding the real shared moving
deck and actual damage through the source 1.3x harvester HP. Personal coin totals
must equal the shared kitty after the source nearest-living-player clear sweep.
The log distinguishes coins before the clear frame from final-frame pickups
plus the sweep; it does not label final-frame physical coins as swept coins.

JP + CPU Maya has naturally completed all seven stages. Source CPU catch-up
events by stage 3-1 through 3-S were 5, 2, 0, 7, 0, 1, 0; no CPU down frame was
observed with the stated assist. Catch-up is unchanged source AI behavior and
is reported separately, so route success is not claimed as independent
no-teleport CPU navigation.

### All-six paired matrix

The final matrix completed **42/42 natural stage clears**, with all receipts,
all source party wave entries, accepted actual boss damage, once-only clocks
and settlement, and no runtime errors or object leaks. Combat and actual-main
focused suites were re-run afterward: 65 and 78 checks, zero failures.

| Stage | Natural clears | Runs with no CPU down frame | Source catch-up events, total |
| --- | ---: | ---: | ---: |
| 3-1 Festival Field | 6/6 | 6/6 | 32 |
| 3-2 Queue Rush | 6/6 | 1/6 | 6 |
| 3-3 After Dark | 6/6 | 6/6 | 3 |
| 3-4 Big Top | 6/6 | 6/6 | 39 |
| 3-5 Hayride | 6/6 | 6/6 | 0 |
| 3-6 Ticket Tout | 6/6 | 6/6 | 10 |
| 3-S Bonus | 6/6 | 6/6 | 0 |
| Total | 42/42 | 37/42 | 90 |

All six Hayride pairs rode the same real moving trailer and dealt 91 actual
damage to the source party harvester (70 × 1.3 HP). Big Top pairs earned their
shared ground-pound card and used it through ordinary input. The bonus accepts
both source clear conditions, exhausted stay-coins or the 90-second timer,
rather than imposing an invented coin quota.

### Queue CPU limitation, kept separate from completion

Five Queue identity runs have 6,346–9,106 CPU down frames despite the stated
invulnerability assist, with one checkpoint revival. They contribute before
going down, then the living leader finishes. These runs prove stage completion,
not a surviving companion throughout. The exact down-frame counts in roster
order JP, Maya, Ama, Leo, Theo, Mei are 0, 9051, 9106, 9055, 6346, 6573.

The `--events` repeat reproduced every result. Ama as Maya's CPU first falls
through the 2521–2631 gap at frame1159, is squashed by the 5490–5570 barrier at
frame2448, and falls through the 6132–6242 gap at frame2705, becoming downed.
The checkpoint revives Ama at frame6100 without changing position; normal
camera clamp/recovery resumes next frame. Another gap downs Ama at frame6712,
leaving the leader to finish. JP as Mei's CPU similarly loses its last heart
to the frame2448 barrier and recovers at x5530.038, feet372.

Source `fellOff` explicitly sets `p.inv = 0` before damage
(`game/3-2/index.html:386–390`), and auto-scroll `squash` calls it when camera
clamping pushes an actor inside a solid (line1184). Source CPU catch-up returns
immediately for a downed actor (lines452–459), before it can rescue them.
`tests/test_festival_party_source_recovery.py` passes three tests: it confirms
identical CPU/recovery/squash functions across all seven W3 HTML files, then
executes the **actual original JavaScript functions** on these recorded native
states. The gap recovery positions/damage, barrier death, and downed catch-up
early return agree. This is a targeted source-rule replay, not a full browser
simulation or independent no-teleport navigation proof. No AI improvement,
fall-immunity override or manual revival was inserted to make the matrix pass.
The third test proves W3's source CPU only resets aim to false and that its
only authored skill card is Big Top's ground-pound, never Dash.

Reproduce with isolated HOME/XDG directories and one engine process at a time:
`godot --headless --path godot --script res://tests/test_full_festival_party_run.gd -- --level=3-2 --all-characters --events`.
Run that command without `--events` for each of the other six stage IDs. Run
`python3 -m unittest discover -s tests -p test_festival_party_source_recovery.py -v`
for the small source-rule replay. Scan logs for script errors as well as exit
status. One interrupted attempt could not preload a concurrently edited W6
script before any gameplay; the affected stage was re-run after compilation
was stable. That interruption is not counted as a route result.

### Shared-host aim/Dash guard audit

After the matrix, the shared host was corrected to exclude CPU actors from
human-only stationary upward firing/poses and to pass the CPU flag to movement
skill callbacks, preventing CPU automatic earned-Dash activation. The W3 matrix
does not exercise either changed branch: every route starts with a freshly
written empty skill save and asserts both actors' skill lists are empty; its
only possible earned card is ground-pound. W3 CPU never requests aim, while
ordinary leader aiming remains human-scoped. The 42-route evidence is retained,
not represented as a rerun after this repair. The new source assertion above
checks this scope; `test_party_cpu_skills.gd` separately exercises the repaired
host guards across all six families, including synthetic inherited Dash/aim.

Final unchanged solo progression also passes all six housemates in all seven
W3 stages (42 routes), plus the existing live/Continue Hayride and idle-bonus
variants. Neither these solo routes nor the CPU route fixtures certify physical
controllers, multitouch, rendering on devices, two-human full progression or
permission to expose native family modes.
