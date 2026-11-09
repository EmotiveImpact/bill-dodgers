# Shared housemate abilities parity

Source: shared abilities patch in `game/1-1/index.html` (readable extraction lines 1180–1640). Native implementation: `godot/src/abilities.gd`. This module uses seconds and pixels/second; JavaScript uses milliseconds and pixels/millisecond. Character heights retain source values.

## Implemented behavior

- Initial charge 0.5, passive refill 30 seconds from empty, +0.07 per newly popped robot, clamped to 1. Charge does not accumulate during specials, and pops during specials are not banked. Input is rising-edge or explicit `request_special()`. Requests while charging are consumed without activation.
- Jean Phil: 1.8-second coin rain. Source scheduler emits at most one shot per tick, at duration/(26 × power) intervals. Boss target probability 35%, visible enemy targeting below 75% when available, otherwise camera-wide targeting. Rain starts above the viewport, damage 2, downward speed 720–920; ends with five collectible coins. Passive magnet attracts coins aged at least 250ms from within 300px at 550px/sec.
- Maya: 6-second flower shield, blocks damage, removes nearby hostile shots, deals enemy/boss damage every 350ms with source distance checks. Passive blocks every second otherwise eligible hit and grants 900ms invulnerability.
- Ama: 4.2-second bubbles on visible live enemies. Captured enemies float up 44px with 5px bob, then return to their saved floor and take one damage. Removes visible hostile shots. Active boss takes three damage and gets at least 3.5 seconds dizzy. Passive jump ×1.09.
- Leo: 5-second glider, grounded activation launches at -800px/sec. Jump climbs, down dives, neutral caps fall at 70px/sec; source ceiling/260px ascent limit preserved. Homing planes every 300ms, every third plane has downward velocity 250. Airborne movement +35%. Passive held-jump fall cap 340px/sec.
- Theo: 3.6-second ball with source radius, gravity, speed, bounce and damage intervals. Camera-edge bounce, boss bounce, two damage to enemies/boss, enemy 240ms and boss 300ms repeat timers. Six-position trail exposed for drawing. Passive moving grounded kick deals one crate damage every 200ms.
- Mei: passive +12% speed; 6-second sugar rush adds +60%, jump ×1.06 and shot cooldown capped at 105ms.
- Explicitly supplied `super` skill doubles recharge/pop charge, extends specials ×1.5, increases Mei rush bonus to +70%, increases rain total scheduling density and end coins using source rounding. No skill automatically unlocks. Other movement skill cards (slide, double-jump, ground-pound, dash, wall-jump) are implemented in movement_skills.gd with stage-specific variants; see SKILLS_PARITY.md. Only the native park can currently award its card through full stage progression.

## Integration contract

Create a RefCounted instance; `reset(character, skills = [])` on a new run. `tick(dt, controls, host)` runs after normal movement. Controls: `left`, `right`, `jump`, `down`, `special`. The module owns charge state, not the UI. `SPEC`, `meter`, `active`, `remaining`, `duration`, `effects` are available to renderers; `active` is a housemate key or an empty string. `rng.seed` may be set after reset for alternate deterministic runs (reset uses 1979).

Before motion, multiply horizontal base speed by `speed_multiplier()` grounded or `airborne_speed_multiplier()` airborne. Apply `jump_multiplier()` once to a normal jump impulse, not continuously. Clamp downward speed with `max_fall_speed(jump_held)`. These are alternatives to source post-movement nudges, so do not also add the source nudges. Preserve normal crouch/lock checks in the integrator.

Host fields: player Vector2 absolute feet; velocity Vector2 px/sec; grounded bool; face int; cooldown seconds; camera Vector2; enemies/bullets/coins/crates Arrays; pop_count int; invincible seconds; nullable boss with state dictionary. Enemy and crate `p` are absolute feet. Coin `age` and bullet `life` are seconds. Boss state must supply `x`, `fy`, `state`, `hp`, `dizzy`.

Callbacks: `damage_enemy(enemy, damage)`, `damage_boss(damage)`, `hit_crate(crate, damage)`, `add_coins(position, count)`, `view_width()`, `view_top()`. Damage callbacks must preserve normal level-specific eligibility rules.

Call `blocks_damage(host)` immediately before applying an otherwise eligible player hit, after checking ordinary invulnerability, death, and other lockouts. A true return cancels damage. Skip normal enemy movement, attacks and contact damage whenever `enemy_is_bubbled(enemy)` returns true. Bubble render uses `ab_bubble`, `ab_bubble_total`, and the mutated enemy feet. Shield/ball/kick repeat timers are stored on enemy/crate dictionaries. Remove or skip bullets with `life <= 0` before collision checks. Friendly bullets provide `p`, `v`, `life`, `enemy=false`, `damage`, `homing`, `gravity`, `kind`, `ab_rain`.

Optional terrain callbacks for exact ball platform/wall bounce: `ability_land_on(x, old_bottom, new_bottom)` returns landing surface y or INF; `ability_inside_wall(position)` returns bool. Without them ball floor defaults to activation player feet; this is a documented flat-floor fallback, not full level collision parity.

## Compatibility fixes and remaining differences

- Source shared boss attacks reference `boss.fy`, although original boss models can lack it. Native integration intentionally supplies ground `fy` so distance/hit tests function rather than comparing undefined values.
- Source specials spawn invisible tiny-velocity shots to defer damage to world rules. Native module calls the host damage callbacks. Those callbacks are responsible for armor, invulnerability and pop bookkeeping. Ball incidental crate contact uses a 36px horizontal/40px vertical proximity approximation instead of a ghost shot passed through each world's crate collider.
- Ball fall cutoff defaults to the source fallback of one million pixels. World-specific hazard removal should be provided by integration if needed.
- The module exposes gameplay and effect geometry, not HTML audio, particles, toast messages, flash overlays or drawing. Renderer/audio integration remains the host's responsibility. Cosmetic RNG is intentionally independent/omitted so tests are deterministic; random trajectory sequence is not byte-for-byte identical to browser Math.random.
- No CPU automatic special trigger is included; a companion controller may request specials using the public request API.
- Scheduler intentionally retains source one-emission-per-frame behavior, not an accumulator loop. Exact emission count consequently depends on tick rate, as in the original.

## Validation

`HOME=/tmp/bd-abilities-home XDG_DATA_HOME=/tmp/bd-abilities-home XDG_CACHE_HOME=/tmp/bd-abilities-home godot --headless --path godot --script res://tests/test_abilities.gd`

67 assertions pass on Godot 4.6.3: charge/pops/skill gating, six activations/durations/expiration, rain/drop, magnet, bubble capture/release/boss stun, Maya passive/shield/cadence, Leo launch/planes/fall, Mei boost/fire, Theo kick/ball/camera rebound, super and rising-edge activation. Module also passes `--check-only`. These isolated tests do not prove host integration, art/audio, device controls, or platform-specific collision behavior.

## Stage 1-6 source-order integration

The native Binman stage now opts into `tick(dt, controls, host, true)`, with `bubbles_tick(dt, host)` between ordinary bot AI and projectile collisions, and `effects_tick(dt, host)` after boss/bin collisions. Its host queues actual invisible ability shots, retains helper → boss → crate → later-bin collision priority, applies ghost damage through each object's normal rules, emits generic free-ball zaps at the exact ball position, and expires ghosts strictly after 70ms at the end of the update. Bubbled bots are excluded from AI/cleanup while held and appended after other bots before shot collisions. Pre-step abilities use the previous ability clock; late ball effects use the incremented clock.

These ordering fixes are currently opt-in for 1-6. Stages 1-1 through 1-5 retain the earlier combined ability tick, direct callbacks and crate-only incidental-ball fallback; the new 1-6 coverage does not establish source-order parity for those stages. The supplied boss `fy` also deliberately repairs source behavior beyond coordinates: in original 1-6, missing `fy` disables Maya/pound/targeted-ball boss eligibility and prevents helpers from intercepting Ama's NaN-position ghost. Native finite ground coordinates enable the intended interactions. See `BINMAN_PARITY.md` for precise contracts and boundaries.

The dedicated `test_ability_ghost_order.gd` suite passes 45 checks; the existing `test_abilities.gd` suite remains 67/67 passing unchanged.
