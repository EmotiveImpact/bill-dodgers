# Companion and local co-op port contract

## Current acceptance boundary

The actor, lifecycle, CPU and input modules are now integrated with all six
worlds, shared combat, rendering and reachable selection. Full CPU progression
matrices are recorded in `NATIVE_PARTY_ACCEPTANCE.md`; device, difficulty and
physical two-human acceptance remain open. The architecture uses one shared
world step and actor-local phases, never two whole `main.step` calls.

Focused checks, Godot 4.6.3:

- `res://tests/test_party_runtime.gd`: 43 checks.
- `res://tests/test_companion_ai.gd`: 40 checks.
- `res://tests/test_party_input.gd`: 17 checks, including native engine key events.
- `res://tests/test_companion_context.gd`: 58 real-main query, all-stage context and flat-shot fixtures.
- `res://tests/test_party_combat.gd`: 26 mutable-record and facade-transaction checks.
- `res://tests/test_party_combat_integration.gd`: 26 W1/W2 combat/facade fixtures.
- `res://tests/test_party_world_one.gd`: 15 party slate, scroll, flyer and bus fixtures.
- `res://tests/test_party_cpu_order.gd`: 6 actual-main CPU-before-player boundary fixtures.
- `res://tests/test_party_revive_order.gd`: 8 actual-main per-actor rescue-order fixtures.

These use deterministic fixtures and synthetic input. No physical controller,
multitouch device, complete co-op route or phone export is certified by them.
Run with an isolated writable HOME/XDG directory, as `verify-native.sh` does.
These suites are registered in `scripts/verify-party.sh`.

The separate W1 progression matrix and its explicit CPU-survival limitations are
recorded in [PARTY_WORLD_ONE_ACCEPTANCE.md](PARTY_WORLD_ONE_ACCEPTANCE.md).

## Source reviewed

`game/1-1/index.html`: `mkPlayer`, `startLevel`, `updatePlayer`, `updateCPU`,
`updatePlay`, `drawHUD`, the ability wrapper and the later input-fix wrapper.
`updateCPU` is byte-identical in worlds 1, 3 and 5. Worlds 2, 4 and 6 share the
base with the following additional source behavior, checked across all seven
stages of each world:

- World 2 adds `lvTargets`, `lvCPU` and the 2-6 `L.cpu` checkout puzzle helper.
- World 4 includes `W4.targets()` and the boss's `aimX` where present.
- World 6 uses a 320px catch-up threshold instead of 460px, adds `w6Targets()`
  and `w6Aim()` for fliers, raised bots and an elevated boss.

Source mode IDs are `cpu`, `p2`, `solo`, with initial web selection `cpu`.
Different housemates must be selected for the two slots. Each actor starts with
three hearts and half a special meter. P2 starts 80 pixels behind P1 and its own
floor must be resolved. The native runtime object defaults to solo only to avoid
changing the already-tested solo path before explicit mode selection.

## File ownership and callable API

### `party_actor.gd`

One instance per actor. Native field names are retained for existing helpers.
`initialize(character, slot, cpu, absolute_feet, level_id, skills)` is intended
for a newly created instance. Each owns its own `Abilities` and `MovementSkills`
instances, positions, cooldowns, jump edges, safe checkpoint, health, animation,
weapon and AI state.

`capture_native(host)` / `apply_native(host)` transfer only the fixed
`NATIVE_FIELDS` list. They do not transfer `score`, `receipt_score`, elapsed time,
camera, enemy/bullet/coin arrays, scene runtime, boss, world state or global input.
`pop_count` is per actor; projectile attribution must update the correct actor.
`coins` is the source player's contribution, distinct from the shared kitty.
`scene_state` is a per-actor dictionary for source fields such as a carried crate,
bag, water state, platform support, debit latch or movement-transition state.
World singletons must not use one shared field for these player-specific states.

`participant()` returns `slot`, `position`, `alive`, `height`, `crouching`, `cpu`.
The slot is stable for the level; never use nearest-player lookup to infer the
owner of a projectile after it has been fired.

### `party_runtime.gd`

- `configure(mode, p1, p2 = "") -> bool`: validates atomically; no invalid mode,
  unknown housemate or duplicate P1/P2. Solo does not require P2.
- `start(level_id, spawn_feet, skills = [])`: creates fresh actor instances.
  Floor-query each separately, then update their checkpoint and last-floor cache.
- `actors`, `actor_at(slot)`, `living_actors()`, `participants()`,
  `living_participants()`, `nearest_actor(x)`: actor queries. Nearest uses source
  horizontal distance and first actor wins a tie. Missing actor returns null.
- `camera_actors()`: human, non-remote, non-out actors, falling back to living
  actors only if there are no humans. The source filter intentionally lacks a
  down check, keeping a downed human visible for rescue. CPU never drives camera.
- `camera_follow_x(current, width, world_width, lock = null)` and
  `camera_follow_y(ground, visible_height)`: desired source follow coordinates;
  main retains once-per-frame camera easing, scene caps and auto-scroll overrides.
- `tick_revive_actor(actor, delta, playing = true) -> Dictionary`: call in actor-update
  phase once. A living helper within strictly 80 horizontal and 70 vertical
  pixels revives after strictly 1.4 seconds; progress otherwise decays at half
  speed. Result has `kind=revived`, `slot`, `helper_slot`, `position` for sound/UI.
  Revive grants two hearts, 2.2s invulnerability and a 0.6s celebration lock.
- `all_down()`: evaluate after source objective/clear events, not after the first
  actor's lethal hit. `continue_in_place()` gives everyone three hearts and 2.5s
  protection without rewinding world state or position. `settle_clear()` raises
  downed actors with one heart and marks all actors winning.
- `record_coin(slot,count)` and `record_pop(slot,count)` affect only that actor.
  The caller must increment shared kitty exactly once, or this creates duplicate
  awards. Receipt rewards are not ordinary player-collected coins.
- `grant_skill(skill)`: shares an actually collected source card with all actors;
  it does not save it or grant unearned cards.
- `plate_hold_seconds()`: source 2.6s for two humans and 5.2s otherwise.

### `companion_ai.gd`

`controls(delta, actor, context) -> Dictionary` returns the same normal input keys
used by native movement: `left/right/jump/down/shoot/aim/special/dash`. It owns no
physics, health, shared scene timer or enemy simulation. `events` contains the
current call's catch-up relocations with `slot/from/to`; drain immediately for
VFX and per-world support rebinding. It does perform the source catch-up actor
relocation, retaining horizontal velocity but resetting vertical velocity,
grounded and platform state. A downed actor emits neutral controls.

Context contract (omit absent optional collections; coordinates are absolute
native feet and timer values are seconds):

| Field | Value |
| --- | --- |
| actors | Party actor objects in slot order; first is human leader. |
| world | Integer 1–6. |
| camera_x, view_width, elapsed, ground, auto | Shared scene values. |
| enemies | Dictionaries with `p: Vector2` feet, optional `state`, `hp`, `alive`; W2 cart attacks add `cart_direction`. |
| boss | Empty or `{x, state, hp?, alive?, aim_x?, offset_y?}`. `aim_x` is W4 aimX; `offset_y` is W6 yo. |
| scene_targets | Source scene-specific x targets, already filtered by each scene's rules. W2 follows boss in target order; W4/W6 precede it. |
| bills | Hostile projectile dictionaries `{p: Vector2, v: Vector2, flat: bool}`. Do not pass friendly shots. |
| boss_waves | Dictionaries `{x}` for source shockwave dodging. |
| floor_below | Callable `(x, y) -> float`, INF if no surface; source `below`, not collision-only `landOn`. |
| wall_clamp | Callable `(from_x, to_x, feet_y) -> float`. |
| inside_wall | Callable `(point: Vector2) -> bool`; catch-up checks human feet minus 10. |
| entities | W2 objects `{kind, x, vx}` for runaway trolley decisions. |
| hazards | W2 `{kind, x, y}` for low/block; flames add `period`, optional `offset`, both seconds. |
| gates, plates | W2 gate `{id,x,open,held}`, plate `{id,x,y}`. |
| checkout | W2-6 `{alive,phase,frozen?,beam?,till_left?,crates?,steps?}`. Beam `{y,age}`; crates `{x,state}`; steps `{x0,x1,top}` in source step order. Held crate flag is `actor.scene_state.carrying_crate`. |
| fliers | W6 `{p:Vector2,state?,hp?,alive?}`, where p.y is actual flyer body y, not feet. |
| scene_cpu | Optional W2 callable `(actor, controls)` invoked after built-in checkout decisions. |

The CPU ability wrapper waits strictly more than 0.7s with a full meter and two
visible living bots or a live source boss. It does not auto-use earned dash
(the source only binds dash input for humans). Catch-up requires a grounded
leader not inside a wall, after strictly 1.6s separated horizontally by 460px
(320 in W6) or vertically by more than 50px with a grounded leader.

Source quirks retained: retreat intent can change facing in subsequent ordinary
movement; 2-6 assigns an inert `controls.face` on its last receipt step; W4 uses
normal 210px standoff when aimX differs from boss.x. Do not describe those as
fixes unless a deliberate repair and its test are recorded separately.

### `party_input.gd`

- `read(slot, mode, touch = {})` samples native input; `from_snapshot(...)` is
  the equivalent deterministic test seam.
- P1: arrows, Z jump, Space/X/K fire, C special; native Shift/Q dash retained.
- P2: A/D, S duck, G jump, W aim, F/E fire, R special. T is the added native
  dedicated dash button. Source double-tap dash remains a movement-skill feature.
- A/D/S aliases are retained for P1 only when mode is not p2. Touch is P1 only.
- `bind_gamepad(slot, device)` assigns one physical device to exactly one slot.
  No automatic reassignment on disconnect. Missing device is neutral. Main/UI
  chooses whether one pad belongs to P1 or P2 and may expose rebinding.
- Native controller mapping: stick/D-pad movement/aim/duck, A jump, X/right
  shoulder fire, Y special, left shoulder dash. Deadzone 0.25. This is a native
  addition, not a claim that the original browser supported controllers.
- `release_all()` suppresses held actions until neutral input is observed after
  focus loss, pause, rotation or mode change. Call for both players, not just P1.

## Required integration phase ownership

Preserve the certified solo execution path. Refactor a separate party path only
when its phase ordering can be verified against each world's source wrappers.

1. Increment shared level time once. Prepare any shared scene motion once.
2. Build CPU contexts and human controls, one per actor. CPU runs before the
   ordinary player movement; never feed P2 keys through P1 aliases.
3. Run actor movement, timers and source wrapper phases with actor-scoped state.
   World 6 carrying samples the old x before displacement; W3/W4/W5/W6 have their
   own carry, water, landing, squash and freeze ordering. Do not call shared
   `pre_motion` or world-ticking callbacks twice if they mutate global entities.
4. Update source revival and actor effects in their source phase. Freeze actor
   simulation while story, pause, completion or Continue UI is active.
5. Camera follows the appropriate human roster once, including scene caps and
   forced-scrolling cases. Pressure plates query every eligible actor; source
   doors relocate all actors once and checkpoint healing applies to each.
6. Tick waves, shared hazards, enemies, projectiles, items, boss and objective
   once in that world's current source order. Enemy attacks query living actors,
   and harmful geometry iterates victims with per-actor hit sets where needed.
7. Every projectile/effect carries `owner_slot`; hit/kill/coin accounting uses
   that identity. Host callbacks must not credit whatever actor happens to be
   active when the once-per-world projectile pass runs. Per-actor ability charge
   and damage immunity query the actual owner/victim, not P1's ability object.
8. Apply the all-down transition after clear/objective resolution; a fallen
   leader remains rescueable while P2 or the CPU is alive. Continue preserves
   encounter state. Settlement awards uncollected coins once and keeps each
   actor's contribution, shared kitty and receipt rewards distinct.
9. Render every actor and independent HUD health/meter/power without mutating
   world simulation. Restore the active P1 facade after any temporary render
   swap. Existing special-effect renderer needs each actor's effects, not two
   draws of a shared instance.
10. Integrate source participant-count wave groups/boss HP and source co-op
    adjustments, not just roster construction. See the per-world parity notes.

## Co-op acceptance still required

- Reachable mode and two-housemate selection; source distinctness, restart,
  campaign/development picker and saved configuration behavior.
- Two actors can move/jump/aim/fire independently and each receives pickups,
  injury, ability charge and correctly attributed kills/coins.
- CPU completes source-required pressure-pad, crate and receipt-step tasks using
  ordinary controls, not test teleport helpers; source catch-up is separately
  accounted for rather than counted as pathfinding success.
- One downed player can be rescued; both down, Continue, pause/focus/rotation,
  story transitions and level clear work in every world, including moving decks.
- Shared time, waves, shots and boss phases advance once, not once per player.
- W4 water/boat, W5 carried platforms/crates and W6 doors/lifts/debits use each
  actor's own state and identity, with all-actor scene transitions.
- Full two-human and CPU routes with real input events; actual gamepad and
  multitouch on target hardware. Unit snapshot tests are not this evidence.

## Actual-host query adapter

`companion_context.gd` builds the documented normalized context with
`build(host, party, actor)`. It reads real W2 gates/pads/hazards, checkout puzzle
state keyed by actor slot, W4 hittable foes, W6 entered fliers/fighting mini and
source boss aim aliases. It binds the host's floor/wall/inside-wall query methods.
The adapter does not tick anything. Its actor-bearing collections are snapshots,
not a combat mutation API. Read-only contexts should be discarded after the CPU
call so their geometry callables do not keep an old scene alive.

The W1 flat throw now explicitly preserves `flat=true` in its bullet record.
The optional `_bill(..., big=false, flat=false)` argument is set only at the
actual flat bot's throw. Zero gravity alone does not make a projectile flat.
This restores source CPU ducking metadata without changing solo trajectories or
presentation hooks. `test_companion_context.gd` covers both explicit flat spawn
and a non-flat zero-gravity control.

## Mutable combat records and scoped actor callbacks

`party_combat.gd` is a bridge for the existing `combat_participants()` APIs.
It is still an integration component, not a second world simulation.

1. After `PartyRuntime.start`, call `bridge.configure(party, host, initial_slot)`.
2. Enter a once-per-world shared phase with `bridge.begin_shared(active_slot)`.
   It captures the active facade and publishes all actors once. Duplicate begin
   is rejected. Host `combat_participants()` delegates to `bridge.participants()`
   while this shared phase is active. Every query returns the same dictionaries.
3. World routines may write `p`, `velocity`, `hearts`, `power`, `power_time`,
   `hurt_lock`, `player_animation`, `coins` and other documented record fields.
   The bridge keeps a baseline and merges only changed record values, preserving
   unrelated newer facade state. It never refreshes all records on each query.
4. Victim/owner-specific host helpers call
   `bridge.call_for_actor(slot, Callable(host, "method"), arguments)`.
   The bridge reconciles the target record, applies that actor to the host,
   executes exactly one actor-specific callback, captures and republishes it,
   then restores the prior actor. Nested callbacks preserve outer scalar edits.
   This is for damage/passive/credit operations, **not** world ticks or main.step.
5. Shared-phase direct credits use `bridge.credit_pop(slot, count)` or
   `bridge.credit_coin(slot, count)`. They dirty the stable record even if the
   credited actor is currently bound to the facade. Shared kitty is still the
   caller's separate once-per-event increment.
6. Finish with `bridge.end_shared(restore_slot=0)`. All records reconcile and the
   requested actor is applied to the host. Duplicate end and end during an actor
   callback are rejected. The caller applies party-wide all-down/clear afterward.

Records include stable `id`, `slot`, `checkout_id`, and `host_player=false` for
both actors. `cpu`, `remote` and `out` are published read-only roster metadata;
proxy edits never change those actor flags. Their `p` uses native absolute feet; `height` is the actor's own
character height. `bag`, `crate`, `boss_hits`, `px`, `tied`, `standing_surface` and
`safe_position` persist to `scene_state` with dirty-field reconciliation;
crate references preserve source identity rather than deep-copying the world.
The adapter owns neither the lifetime of crate objects nor checkout's players
map. Runtime reset must still discard old encounter state normally.

Outside shared phases, actor movement uses the existing native scalar facade.
Do not call `bridge.participants()` there expecting it to reflect unsaved
movement. Capture/publish at the explicit boundary. Do not enable pair mode until
every callback path uses the victim/owner slot and relevant shared routines are
adapted. Source solo host snapshots may remain a separate compatibility branch.

## W1/W2 shared combat adapter status

The W1 and supermarket combat modules now consume persistent party records for
nearest targeting, contact/projectile victims and pickups, and pass the firing
owner through ordinary bot damage/kill accounting. W1 gap-hop calls bind the
chosen target through `call_combat_participant(record, callable, arguments)`.
Its flyer floor uses the lowest supporting floor among grounded living players;
party mini health is 46, and `reset(host, seed=11, participants=1)` adds the source
opposite-side copy of the final wave entry after 600ms. Existing seed position is
unchanged. W2 reset retains source unsorted extra-group concatenation and 34HP
party security bots.

Host requirements in addition to stable records:

- `hurt_combat_participant(record, from_x)` scopes the host to the victim.
- `call_combat_participant(record, operation, arguments)` scopes an existing
  actor-reading helper without ticking the world again.
- `credit_combat_pop(owner_slot=-1)` scopes credit: -1 is the active actor for a
  direct actor skill/ability callback; nonnegative is an explicit owner; -2 is
  intentionally unowned and must not credit anyone.
- `combat_bubbles_tick(delta)` is a single global held-enemy phase, never one
  pass per actor. W1 invokes it for Binman or an active party, retaining the old
  solo fallback otherwise. The current session binds the unique Ama actor for
  this global pass; distinct housemates make that ownership unambiguous.
- Every friendly projectile must carry `owner_slot` and `owner_x`. Its first-frame
  sweep prefers the current stable owner record, matching the source's owner
  reference. A missing owner in a party can damage enemies but never credits the
  currently bound actor by accident.

The isolated integration fixtures exercise both combat implementations with the
real facade bridge, including Maya's own alternating-hit passive, direct mutable
pickup writes and returned ownership. They do not validate the main party frame,
world transitions, bus/crumble state, character rendering or complete routes.

## W1 scene and bus adapters

World 1 shared scene queries now consider all living participants. Slate timers
advance once, any living standing actor activates a slate, and collapse releases
all supported actors. Forced-scroll anti-crush is per actor; camera/objective
checks can continue with a living P2. Chimney hops target the nearest living
actor and flyer spawn height uses all grounded actors. Bonus coin generation
remains one world-owned counter. Bus drive/waves/obstacle motion still tick once,
while each obstacle records separate stable-slot hits so P1 and P2 can both be
hit once or duck independently. Existing solo obstacle.hit behavior remains.

Per-actor safe-floor storage remains the main session's responsibility. The
combat bridge calls optional `host.party_capture_scene(actor)` before capturing
the scalar facade and `host.party_apply_scene(actor)` after applying it, including
nested callbacks and the final restored actor. This prevents a temporarily bound
victim from using another actor's safe floor; it also provides a future seam for
actor-specific water/support state without ticking shared world state.

Bubbles in W1 use the once-global callback for Binman or a two-actor non-host
roster. Ordinary solo W1 keeps its previously verified combined ability path.

## Historical W2 integration checklist (resolved)

The following notes record pre-integration gaps, not the current runtime. They
were addressed by the tested W2 scene adapter; see `WORLD_TWO_PARTY_SCENES.md`
and its 42-route evidence. The original checklist is retained for the mutation
ownership rationale:

- `world_two.gd::base_displacement` delegates to the hazard controller. Its ice
  velocity key currently uses the host instance ID, so two facade actors would
  share a slide accumulator. Key by a stable actor slot in pair mode.
- Scene gate approach/clamp and wipe trigger currently read `host.player` and
  `host.hearts`. Source eligibility must query living participants; advance the
  wipe clock once and relocate/revive every actor exactly once at midpoint.
- Checkpoint healing currently writes only the facade actor. Apply source healing
  to the appropriate roster without resetting the checkpoint world latch twice.
- Runaway trolley motion is world-owned once, but its contact collision currently
  targets only the facade actor. Iterate living records and scope each damage.
- Safe roof storage stays in main's `party_capture_scene`/`party_apply_scene`
  hooks. Extend those hooks only for genuinely per-actor water/support state;
  never duplicate the scene timeline while swapping actors.

The existing W2 hazards/course and checkout code already accept participant
records in many paths. Audit their remaining host aliases before changing them,
not by replacing all scalar accesses indiscriminately. A schema check or two-player
boss scaling alone is not W2 pair acceptance.

Integrated revive uses `tick_revive_actor(actor, delta, playing=true)` at the
individual downed actor's source update position. The array-returning
`tick_revives` remains only a convenience for isolated lifecycle fixtures. Do not
run that bulk helper after both actors move or after later damage has newly
knocked down an actor; that changes the source's proximity and first-tick timing.
