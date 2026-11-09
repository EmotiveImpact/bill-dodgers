# World 2 shared combat policy

Implemented in `godot/src/supermarket_combat.gd`, separately from World 1's
`combat.gd`. This subsystem does not enable stages, grant clears or skills, change
save capability lists, or change the public web build. Its isolated tests are not
evidence of device performance, complete co-op or completion of later World 2
stages. The first host integration target is **2-1, Car park**.

## Source and units

The policy follows the readable hooks in `game/2-1/index.html`: `spawnBot`
364–373, `updateBots` 482–524, `updateShots` 529–559, `updateCoins` 560–586,
`updatePlay` 633–673, `lvUpdate` cart pass 829–837, `lvBot` 842–849,
`LEVEL_WAVES` 1059, and `droneStart`/`droneUpdate` 1107–1114. These shared hooks
are identical across the seven World 2 source pages. The original level data is
not changed. Native timers use seconds, velocities pixels/second, acceleration
pixels/second², and bot/player positions use absolute feet coordinates.

## Host interface and phase order

`reset(host, participants = 1, seed_value = 21)` copies the authored waves and
creates ordinary crates. The participant count selects extra wave groups and
security-bot HP. It does not create a second player or claim co-op is integrated.
Fresh level loading remains responsible for clearing host entity arrays.

The host invokes these phases, preserving the original boundaries:

1. `waves_tick(dt, host)`, then the scene objective/end predicate.
2. `enemies_tick(dt, host)`, then `abilities.bubbles_tick(dt, host)`.
3. `projectiles_tick(dt, host)`, then `pickups_tick(dt, host)`.
4. World runtime scene/checkpoint/coins/hazards update, then `late_carts(dt, host)`
   and `late_drones(dt, host)`, then receipts/remaining world-specific logic.
5. Global knockout resolution and deferred ability effects/ghost expiration.

Geometry comes from `host.world_two.surfaces(host)` as stable
`{row: [x0, x1, top], plat: bool}` dictionaries. The host's `_land`, `floor_at`
and `ability_inside_wall` must also query current runtime geometry. The
projectile hook is `host.world_two.intercept_shot(host, shot)` and runs after
ordinary bots, before the dormant generic boss slot, crates and wall cleanup.

The primary solo adapter uses the existing host fields and methods. A future
participant adapter may supply mutable dictionaries through
`combat_participants()` with `p`, `hearts`, `down`, `height`, `crouching`, and
`hurt_combat_participant(player, from_x)`. Pair-specific geometry/overlap
fixtures verify that interface, but the full game still needs co-op input,
revive, ownership attribution and UI integration.

## Behavior retained

- Authored camera wave thresholds are unchanged. Group extras are concatenated,
  never sorted. In the 6880 wave, the appended 3500 ms entry waits behind the
  base 6500 ms entry. Failed placements consume their wave entries. Every live
  bot blocks wave completion, but pop states and autonomous hazards do not.
- Spawn accepts `"l"`, `"r"`, and numeric world x. It checks up to 50 positions
  at 24 px increments against current non-platform surfaces, chooses the nearest
  floor to average living feet and preserves strict source width/inset/view
  constraints. Numeric search proceeds right. `spawn_side` preserves provenance.
- Rush, flat and arc throwers retain source HP, timings, speed and gap hopping.
  Security bots use 24 solo/34 pair HP and 58×186 shot extents. They have ordinary
  arc-throw AI, not the World 1 Bailiff's volley attack.
- Cart robots have 2 HP, 300–360 px/s late motion, source segment/screen turn
  bounds, and are separate from autonomous runaway trolley hazards. Drones
  have 2 HP, 40×70 extents, a 200 px floor-relative hover and late price stickers.
  Drones deliberately do not have World 1's `fly` flag.
- Bubbled live bots skip ordinary AI, timers and cleanup. The ability phase
  floats/releases and appends them before shots. Re-appended carts and drones
  still receive late motion, matching the source rather than freezing them.
- Every player shot, including ability ghosts, resolves before hostile bills.
  Horizontal sweep includes first-frame owner-to-muzzle distance. Source
  strict hit/culling boundaries, custom extents, homing, shove-before-loot,
  one-HP crate hits and late sticker movement are covered. Hostile arcs survive
  above the viewport. No artificial projectile lifetime countdown is added.
- Bills already canceled by Ama's activation or Maya's shield are removed
  before hostile movement/contact. This includes Maya's final shield frame,
  when the shield cancels a bill and then expires before combat. Bills still
  live at the start of their pass retain contact-before-floor/wall cleanup.
- Coins/items retain source gravity, bounce, attraction and age thresholds.
  The generic coin filter runs before the world's authored keep-age reset.
  Items have no vertical collection-distance check or invented age expiry.
  A down player cannot collect them before a later checkpoint revives them.
- `late_drones` ends with `sync_visuals`, moving source draw-time stride
  bookkeeping out of the renderer. It tracks net frame displacement only
  inside the original drawing margin. Rendering does not mutate gameplay.

Enemy records retain common native fields: `p`, `kind`, `type`, `hp`, `max_hp`,
`state`, `t`, `cd`, `stop`, `speed`, `face`, `entered`, `wait`, `gone`, `flash`,
`pending`, `scale`, and `segment`. Extra fields are `big`, optional `hw`/`hh`,
`cart_dir`, `base_y`/`phase`, `hop`, `arrival`, `spawn_side`, and renderer-only
`stride`/`visual_move`/`last_visual_x`. Numeric arrival timing is exposed as
data; original particle effects are not certified by these combat tests.

## Verification

Run with Godot 4.6.3 and isolated HOME/XDG state:

```sh
godot --headless --path godot --script res://tests/test_supermarket_combat.gd
```

Recorded isolated result on 2026-11-09: **115 checks, zero failures**, with no
script/runtime errors. Coverage includes all eleven 2-1 wave definitions,
unsorted pair extras, dynamic and numeric placement, source bot policies,
projectile/ability/late ordering, Ama/Maya cancellation boundaries, strict
boundaries, pickups and deterministic reset. Real-main progression and
all-World 1 regressions are separate integration gates. This note makes no
release, signing, deployment or device claim.
