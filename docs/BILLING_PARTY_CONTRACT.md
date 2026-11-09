# World 6 party phase and mutation contract

## Current evidence boundary

The world, combat and Sir Charge adapters now use the real stable mutable
PartyCombat records. Existing scalar solo behavior and intentional native
receipt-coordinate and finite-SirCharge-fy repairs remain intact.

- `test_billing_party.gd`: **163 checks, zero failures** with real PartyRuntime,
  PartyCombat, actor-owned abilities, imported metadata, W6 world/combat/boss.
  Includes hold pace/cap/jam, living checkpoint, random fees and charge victims.
- `test_billing_party_host.gd`: **81 checks, zero failures** against real main and
  inherited production PartySession.start and step. The final fixture has no
  start override, so it cannot bypass a missing integration gate. No scheduler
  or game logic override is used. Rechecked against the latest integration tree
  after the complete CPU matrix.
- `test_billing_party_source_contract.py`: **2 tests passing**, comparing eight
  executable source blocks byte-for-byte across all seven W6 HTML pages and
  checking ownership, per-victim debit, hazard, lift and bonus rules.
- Full solo regression after the adapters: **42/42 clears**, all six heroes
  across all seven W6 stages, 404,223 simulation ticks, 420 waves and 76 physical
  receipts. Existing invulnerability-only controller assistance retained.
  Log: `docs/validation/billing_solo_regression.log`.
- Retained solo focused suites: WorldSix **124**, BillingCombat **47**, SirCharge
  **37**, all passing after these edits.
- Full CPU matrix: **42/42 clears**, 355,519 simulation frames, 420 waves,
  all 1,698 authored base-plus-pair entries and 82 physically collected receipts.
  Source CPU catch-ups: 172; downs, live revivals and clear-time rescues: zero.
  Both actors receive the explicit invulnerability-only test assist. See
  `BILLING_PARTY_ACCEPTANCE.md` and its per-route JSON/log for the full evidence.

The focused fixtures are not full P2 routes or physical controller/touch acceptance,
phone exports, signing, installation or deployment. The assisted CPU matrix is
not normal-difficulty or complete-collectible certification.

## Source audit

References are to `game/6-1/index.html`; the checked blocks are identical in
6-1, 6-2, 6-3, 6-4, 6-5, 6-6 and 6-S. Imported stage metadata remains unchanged.

- 343–365: actors, own safe floor, generic -80 second-player spawn and pair waves.
- 377–397: living/nearest (horizontal, first slot on ties), per-victim injury/fall.
- 410–446: timers, inline downed revival, old-support carrying and own safe floor.
- 633–673: once-source-frame scheduler, camera human roster, objective before
  world/combat/boss/jar, all-down after clear.
- 729–781: once-world start; source unsorted g+x wave additions; height/time
  wave triggers; highest-living flyer spawn; drop avoids every living actor.
- 785–837: nearest flyer aim, all-victim contact, exact shot-owner flyer/mini pops.
- 840–879: 60 pair mini HP (44 solo), nearest volley target, all-victim contact
  and shocks, extra pair backup, owner gets five pops and 18 shared coins drop.
- 882–938: ride camera, any-living door eligibility, all-player +70 door spacing,
  bot carry/navigation/debit, secrets, coins, fliers, mini, checkpoint, scene
  systems, boss start, all-victim falling fees and delayed sheets.
- 942–962: pair lift hold spawn interval/cap; unowned jam and cleanup kills.
- 966–993: lift progression from highest living feet, acceleration from lowest
  living feet; push all actors including downed; harm only eligible living;
  cradle hazards maintain a separate hit set for each actor.
- 1005–1010: any-living climb/coffee completion; coffee time bonus goes to slot 0.
- 1014–1080: 150 pair Sir Charge HP (110 solo), nearest ordinary aim, random
  living fee victim, all-victim waves/body, fixed one/two-point projectile damage.
- 2043–2602: shared abilities/skills and input/pose wrappers; CPU never
  receives human double-tap Dash or stationary straight-up fire/pose. The source
  contract compares these wrapper blocks across all seven pages too.
- 1151–1162: each debit holds a specific player reference, drains that player's
  personal contribution and shared kitty, releases only when that player is
  down/removed or jumps twice; at most one latched debit per player.

There is **no actor bag/crate inventory in W6 source**. W6 surface support is
geometric, not a player-owned surface pointer. Debit state belongs to the bot.

## Exact scheduler and integration hooks

### Start

Use normal W6 reset, construct the final party roster, then run
`billing_combat.reset(host, final_roster_count, seed)`. No additional W6
party_start hook is required. Both actor floors must be queried separately and
safe_position initialized as PartySession already does. Mini and Sir Charge
sample the final participant count when their encounters start.

### Each frame

1. Increment host elapsed once. Capture active actor; open shared phase;
   `world_six.pre_motion(delta, host)` once; end phase restoring slot 0. This
   only increments W6 level_time/elapsed and records delta for the wipe.
2. Build every CPU input before moving either player. W6 uses the existing
   source 320px catch-up threshold and W6 scene-target/aim context.
3. Bind/update each actor once. Existing actor_step evaluates carry_player on
   the **old x before displacement**. after_motion and fall_off are actor-only
   callbacks using that actor's bound safe_position. Inline revival stays at
   the source actor boundary. Downed actors do not receive normal movement.
4. Bind a living representative where available and open the shared phase.
5. Camera once, including W6 ride/climb override. Waves once, objective once.
6. `world_six.world_tick` once, before ordinary combat: doors; enemy surface
   carry/navigation; debits; all-living secret/card callbacks; coin carrying;
   fliers; vents; mini; checkpoint; hold/lift/ride/dash; boss start; fees; sheets.
7. Ordinary bots, one global held-enemy bubble pass, shots/bills and pickups.
8. Normal late movement-skill pass, then W6 boss, jar, combat/world visuals.
9. Reconcile before all-down; objective/jar clear takes priority. Keep the final
   source base frame running through clear/story via family_base_step_active(6).
10. Per-actor ability effects, shared effect expiry, then W6 finish_frame once.
    Keep the bridge open through the wipe midpoint so every actor relocation
    is reconciled. End the shared phase restoring slot 0 and its scene facade.

## State ownership

The **only scalar scene facade field is safe_position**. Existing
party_capture_scene / party_apply_scene already bind it. Existing bridge scene
fields px and boss_hits cover W6's previous x and projectile hit tally.

- Enemy debit records keep `latch` plus stable `latch_slot`, `drain`, `jumps`,
  `was_air` and `cool`. Never infer its victim from the active host or nearest
  player after latching. Removed/downed victims release only their debit.
- Ride hazard `hit_slots` is a slot-keyed set. The retained solo `hit` boolean is
  not used to suppress another player's collision.
- Doors relocate all records including downed actors and stamp px. They clear
  enemies, hostile bills and fliers once. They retain friendly shots, horizontal
  knockback, on_platform and safe_position as original party source does.
  CP doors set every actor's hearts to at least two **without clearing down**.
  The old scalar solo branch is retained rather than silently changed here.
- Ordinary checkpoint heals living actors to at least two without reviving.
- Lift pushes every actor above its rising deck but hurts only living eligible
  victims through the actual actor's passive and invulnerability callbacks.
- Coffee finish credits the first slot's personal coins plus kitty once.
  The native one-shot bonus guard is retained.
- Player pickups/weapon grants use collector records. Shared kitty/drop arrays
  change once per event. Receipt rewards remain zero in W6.

## Required host APIs and attribution

Use combat_participants stable proxies; hurt_combat_participant scopes victim
passives; call_combat_participant scopes only actor helpers; credit_combat_pop
uses -1 for current direct actor, explicit nonnegative owner, and -2 unowned.
Never scope an entire world update around each actor.

Every friendly normal and ability ghost projectile carries owner_slot and
owner_x. First-frame sweeps prefer the current owner record, including downed
owners. Missing ownership in party mode can damage but never falsely credits
whatever actor is bound. Ordinary/flyer kills and mini's five pops use the exact
firing owner. Sir Charge hits retain source fixed 1-point damage (2 dizzy) and
increment that owner's boss_hits; no boss-pop reward is invented.

## Actual-host fixtures

The 81-check host suite covers exact once-per-frame phase order; independent
native D-key P2 input; normal/ghost ownership; CPU prelude/old-leader position;
real P2 receipt collision/save; independent safe-state callbacks; all-player door
midpoint/heal/down flags; natural post-door revival; pause/all-down/Continue;
post-actor lift damage and cradle contacts; source pair Sir Charge, fixed ghost
damage/boss-hit owner, final P2 jar clear and all seven CPU frame smokes.
