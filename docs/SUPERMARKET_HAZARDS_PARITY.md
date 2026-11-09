# Shared supermarket hazards

Implemented component: `godot/src/supermarket_hazards.gd`. Source: the actual shared hooks in `game/2-2/index.html`, lines 738–747 (`lvStart`), 756–770 (`lvMove`), 784–819 (gates and drops), 860–863 (`lvShot`). The component does not enable stages, award clears, or implement an entire 2-2 run.

## Integration contract

- Call `reset(host, runtime)` after the runtime has copied its surfaces/hazards and incremented `run_generation`. This replaces gate surfaces, removes old drops, and clears timers/momentum/hints while preserving unrelated entities and ordinary surface identities. Do not call it for Continue or a scene transition.
- Route base walking through `base_displacement(dt, host, move)`. Keep knockback and character bonuses in their existing separate host phases.
- Late order: scene update, embedded-bot repair, checkpoint, authored coins, **`gates_tick`**, existing trolleys, **`drops_tick`**, later-stage hazards when implemented, carts, drones, picks, then dead-entity removal.
- In the shot hook, call `intercept_shot(host, bullet)` after ordinary bot hits, before checkout/crates and solid cleanup. It returns whether the shot was consumed; it does not remove bullets itself.
- Timers are seconds; movement velocities are pixels/second. Both late hooks receive `(dt, host, runtime)`. They and movement/shots reject pause, other hosts/levels, and invalidated run generations. The owning runtime decides which stages may execute them.

Public renderer state: `gates`, `plates`, `buttons`, `drop_counters`, `ice_velocity`, `hazards`, `hinted`. Each gate has `x/floor/h/id/q/open/timer/held`; plate `x/y/id/on`; button `x/y/id/hit`. Gate `q` is the same dictionary appended to `runtime.surfaces(host)`, with `{row: [left, right, top], plat: false, gate: id}`. Never copy that collider into independent runtime geometry.

Drops are in `runtime.entities` as `{k: "drop", p: Vector2, top, vy, warn, t, kind, dead}`. `p.y` is the falling object's bottom. A shadow uses the stored `top` throughout; show a warning until `t >= warn` and the falling box/icicle afterward. Rendering must not advance timers or consume `runtime.rng`.

The native host supplies `player`, `hearts`, `grounded`, `crouching`, `face`, `meta.ground`, `mode`, `level_id`, `character_height()`, `view_top()`, `hurt_player(x)`, `sfx(name)`, and `status`. Runtime supplies `hazards`, stable `surfaces(host)`, `entities`, `rng`, `run_generation`, and `below(host, x, y)`.

## Preserved rules

- All seven 2-2 shelves, five plates, high button `(4370,152)`, and low button `(11650,372)` come from the imported source schema. Buttons use strict 30px point overlap, including ghost shots; they are not proximity switches or swept button rays.
- Pads need grounded feet, strict 46px horizontal and 6px vertical bounds. Held timer is 5.2s solo/CPU mate, 2.6s with two humans. Buttons raise it to at least 6.5s and flash for 0.3s. Both shot timers and flash decrement in that frame's late gate pass.
- Opening/closing takes 0.38s. Collider stays closed through exactly 55% open, then moves to `ground + 5000`. Occupancy keeps an already-more-than-half-open gate open at strict 60px x distance without a height check. Closed shelves never open from overlap alone.
- Ice blends toward ±310px/s with `dt / 0.9`; stored faster momentum survives airborne departure with `dt / 0.5`. Flour multiplies base speed by 0.55 even airborne at matching height. Belts add only to grounded displacement after ice and do not affect stored momentum, enemies, or items. Every zone x test and 4px floor tolerance is strict.
- Drop counters accrue only with living occupants strictly inside the zone, pause outside, and consume at most one attempt per zone/frame. Target choice and x spread use exactly two gameplay RNG draws, even solo or when support is absent. Landing query starts at target feet minus 300; landing top is captured once. Spawn-frame dt counts toward the 0.95s warning. After expiry the full current dt drives semi-implicit 3200px/s² gravity. Body collision uses strict bounds and consumes the drop even if the player is invulnerable. Impact is inclusive at stored top. Dead entities remain until the owner's final cleanup.
- Source schemas for belts/flour and unknown later hazards remain copied intact. This component does not implement flames, ride signs, blocks, auto-camera, or checkout behavior and does not make their stages completable.

## Co-op adapter and intentional differences

Solo uses current host state. Optional `combat_participants()` reuses the existing shared-combat roster of mutable `p/hearts/down/height/crouching` dictionaries, adding `grounded/face/cpu`; damage uses `hurt_combat_participant(record, x)`. `participant_displacement(dt, host, move, record, stable_id)` provides independent per-player momentum without relying on mutable dictionary identity. This preserves the source multi-participant rules for isolated tests, not a claim of integrated co-op/CPU play.

Fresh resets intentionally clear drop-zone counters. The browser source accidentally preserves `LVS.d<index>` across fresh starts. Continue retains counters, active drops, gates and ice momentum. Cosmetic ice puffs, impact fragments and camera shake are not generated by this physics component; it exposes the required warning/drop state and gate hints, and emits the source select/power/stomp sounds without consuming cosmetic random numbers. Native Vector2 storage is float32; timer math remains double precision, with a 1ns tolerance only for inclusive millisecond timer boundaries.

## Validation

Run with isolated writable HOME/XDG directories:

`godot --headless --path godot --script res://tests/test_supermarket_hazards.gd`

The focused suite covers authored schema, repeated reset, shared dynamic wall/support/landing/projectile collisions, exact plate/button/occupancy bounds, timer/order edges, actual combat interception ordering, high/low and ghost shots, retained airborne momentum, flour/belts, independent participant momentum, seeded drop targeting, warning/gravity/contact/impact, pause, Continue, and stale generations. It does not fake wave completion or claim a legitimate stage run, visual QA, device QA, deployment, or new level support.
