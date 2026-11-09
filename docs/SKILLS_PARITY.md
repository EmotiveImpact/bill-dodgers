# Movement skill cards: native source port

Implemented in `godot/src/movement_skills.gd`; isolated validation in `godot/tests/test_movement_skills.gd`. Units are absolute feet coordinates, pixels/second and seconds, matching the abilities module. This is a gameplay component, not a claim that all world-specific set pieces or a full game clear are validated.

## Source audit

Inspected all 42 `game/{1..6}-{1..6,S}/index.html` files. The shared skill-card and ground-pound code is identical across all 42 files (SHA-256 of that extracted code block: `167c35a33e5f249b25aae2484b1dbb58edc2d32c6a9e6f30d47e37a0256b8fb2`). The world-owned overrides are also identical within their seven stages: World 1 `updateSlide`, World 2 `lvJump`, World 4 `updateDash2`, World 5 inline wall-jump branch and `W5.wall`. The shared `OWN` map disables its corresponding fallback in those worlds. World 3 ground pound has no separate owned implementation.

Representative sources: 1-1 lines 831–867 (pickup/slide), 2-1 lines 428–430 and 1080–1106 (jump order/pickup/air jump), 3-1 lines 1264–1276 (pickup), 4-1 lines 950–988 (pickup/dash), 5-1 lines 425–431 and 935–938 (wall collision/pickup), 6-1 lines 1118–1132 (super pickup), and shared abilities patch skill-card and pound sections in all stages.

## Exact unlock locations and tests

No stage entry, stage clear, boss defeat, receipt count or currency threshold unlocks a skill. Only collecting the specific placed card does. Previously collected skills persist via the host's existing save system and apply to all housemates. Debug `?skills=all` in browser source is not a player progression rule and is not ported.

| Stage | Skill | Source position |
|---|---|---|
| 1-4 | slide | (8497, 442) |
| 2-5 | double-jump | (8850, 232) |
| 3-4 | ground-pound | (5700, -358) |
| 4-4 | dash | (11710, 342) |
| 5-4 | wall-jump | (3560, 482) |
| 6-4 | super | (369, -5632) |

With player feet `f`, card position `c`, housemate height `h`, every comparison below is strict. All checks require a living player and an uncollected card in the current stage:

- Worlds 1 and 4: `abs(f.x-c.x)<42`, `f.y>c.y-120`, `f.y-h<c.y`.
- World 2: `abs(f.x-c.x)<42`, `f.y>c.y-30`, `f.y-h<c.y`.
- World 3: `abs(f.x-c.x)<42`, `c.y>f.y-h-10`, `c.y<f.y+20`.
- World 5: `abs(f.x-c.x)<44`, `abs(f.y-c.y)<110`.
- World 6: `abs(f.x-c.x)<44`, `abs(f.y-h/2-c.y)<h*0.6`.

`collect_card(feet, character, alive)` performs these tests, marks this run's card collected, and returns its skill name once. It adds that name to this module's `skills` but deliberately never writes saves. The host must persist that return, update every other housemate skill instance and `abilities.skills`, and display the pickup. A previously saved card may still be touched on a replay, as in source, but the skill list is deduplicated.

World 6's pickup banner says special hits are twice as hard. The actual shared source does **not** multiply all damage by two: `super` doubles recharge/pop charge, scales durations by 1.5, changes rain cadence/reward and Mei bonus, and scales ground-pound **enemy horizontal radius** from 170 to 255. Ground-pound damage remains 3, boss/crate radii unchanged. The abilities module already owns special scaling; this module owns ground-pound scaling. No later seventh card exists in these sources.

## Movement behavior and world overrides

### Slide

Requires card, grounded, unlocked, direction+down and **prior** run time >120ms. Lasts 420ms, face is right if right is held, otherwise left. Remaining time is reduced on activation's frame. Horizontal impulse is `face*620*(remaining/.42+.2)` and clears to zero at expiry. Only run/rundiag animation builds run time. It is not a rising-edge-only down action.

Shared fallback: nonflying live enemies within 50 horizontal /30 vertical take 3 damage (big enemies 1), with per-enemy 400ms repeat cooldown. Damage hook blocks player hits while sliding. World 1 instead directly subtracts damage each frame in range, flashes enemy 90ms, shoves it 30px in facing direction, and refreshes normal player invulnerability to at least 60ms. It does not use the shared hit timer. Collision boxes remain the normal source crouch/movement boxes; the module does not invent an additional low collider.

### Double jump

Fresh jump input once airborne; velocity must be strictly greater than -900. Sets vy=-860, rearmed while grounded. Shared fallback runs after movement, requires the player was already airborne before the step, rejects a new normal jump/launch via `current_vy >= previous_vy-300`, and gives a successful shared wall jump priority. World 2 performs its own check **before gravity**, excludes down+jump, and lacks the shared prior-grounded/velocity-change guards. Normal ground jump/drop must already have run before calling its hook.

### Ground pound

Fresh down while previously/currently airborne, no jump input, no hurt lock, vy>-700, and no floor within 70px below. A gap is allowed. Sets vy=1400 and vx=0, then enforces at least 1400 downward speed until landing. Hurt lock cancels; host death cancellation is explicit. Leo glider suspends this entire branch, including any in-progress state, exactly as source's outer conditional does.

Landing deals 3 damage to live enemies inside 170×power horizontal and 80 vertical; active boss inside 210 horizontal and 140 vertical; unbroken crates inside 140 horizontal and 70 vertical. No new damage multiplier is added. A 380ms ring effect and landing event are exposed. Actual level combat eligibility belongs to the same host callbacks used for abilities' invisible-shot replacements.

### Dash

Human control only. Fresh dash button (Shift/Q in source) or second fresh same-direction press less than 260ms after prior press. Directional checks run right then left; explicit dash button overrides with current facing. Impulse vx=±1100; normal host damping is `pow(.992, dt*1000)` and wall/camera collision still apply. Shared cooldown 650ms, hurt-lock gate, damage protection 260ms minus the current step. World 4 cooldown 600ms, no hurt-lock gate, and normal invulnerability raised to at least 260ms. No automatic dash continuation force is applied: this is an impulse, not fixed-speed travel.

### Wall jump

Shared fallback probes 8px toward input at feet-90, detects >0.5px wall clamping, caps fall speed at 220, and retains wall direction for 140ms. Fresh jump and the `current_vy >= previous_vy-300` guard kick vy=-950, vx=-wall*550, turn away and rearm double jump. Wall probe is a real world-solid clamp, not camera boundary.

World 5 uses actual horizontal movement collision, excludes camera-edge clamps, and runs before gravity: fresh jump while airborne at a wall sets vy=-960, vx=-wall*220 and turns away. It has no shared wall-slide fall cap or coyote grace. Its wall-jump branch does not itself reset double-jump state.

## Host integration and ordering

Construct and `reset(stage_id, saved_skills)` for each housemate/run. Do not call the begin/post/late phases for dead players or when gameplay is paused/cleared. Invoke `cancel_on_death()` on death. `events` is cleared each begin phase and contains names for audio/feedback; `effects` contains ring geometry. Exposed state includes `slide_remaining`, `dash_remaining`, `dash_cooldown`, `double_jumped`, `ground_pounding`, `skills`, `card_collected`.

1. Decrement host ordinary lock/invulnerability timers. Call `begin_step(dt, controls, host)` before horizontal movement/jump. Controls use `left`, `right`, `down`, `jump`, `dash` booleans.
2. Integrate ordinary horizontal movement plus velocity.x, collision/camera clamp and damping. Run normal ground jump/drop-through.
3. Call `jump_step(host, wall_hit)` before vertical gravity/landing. `wall_hit` is -1/0/+1, derived from actual intended versus wall-clamped horizontal position, only for a nonzero movement input and away from camera edges. This hook owns World 2 air jump / World 5 wall jump. Then perform normal gravity and landing.
4. Run abilities post-movement logic. Call `post_step(host, abilities.active, player_animation, cpu)` afterward. This mirrors the shared patch's skills-after-specials/passives order.
5. Complete ordinary projectiles, enemies and world pickup updates. Call `collect_card` at the stage's pickup phase; persist and broadcast only its returned name. Then `late_step(host, player_animation, cpu)` runs World 1 slide / World 4 dash, which originally run late in the world update. Newly collected own-world cards can act in this phase; shared cards act next player-update frame.
6. Every eligible player-hit path checks ordinary invulnerability and then `blocks_damage()` before abilities' Maya passive counter. World-owned variants already grant host.invincible. Skill horizontal impulses must remain separate from normal base walking speed so the host does not overwrite velocity.x each frame.

Required host fields: `player`, `velocity`, `grounded`, `hurt_lock`, `invincible`, `face`, `enemies`, `crates`, nullable `boss.state` with x/fy/state/hp. Enemy flags `fly` and `big` must carry source meaning. Enemy/crate position `p` is feet. Boss ground `fy` compatibility fix follows the abilities contract.

Required callbacks:

- `skill_wall_clamp(from_x, to_x, feet) -> float`: same solid-wall clamp as player movement; no camera clamp.
- `skill_floor_below(x, y) -> float`: nearest supporting solid/platform top at/below the supplied y or INF. Includes one-way platforms just as source `below` does.
- `skill_slide_hit(enemy, damage, shove_dx)`: World 1 exact local override: directly subtract hp, set 90ms flash, add shove to enemy.x, then invoke normal pop/rewards if hp<=0. It must not go through armored projectile rejection; source owns this direct subtraction.
- `damage_enemy`, `damage_boss`, `hit_crate`: same world-aware callbacks as abilities; shared skills use these instead of invisible shots.

The module does not implement or replace platform collision, drop-through, crouch, normal jumps, death, hazard handling, damage rules, input mapping, audio, saved progression, companion synchronization or rendering. These are explicit host responsibilities. No main/save/abilities files were changed for this component.

## Validation

Godot 4.6.3 parser check passes. Run:

`HOME=/tmp/bd-abilities-home XDG_DATA_HOME=/tmp/bd-abilities-home XDG_CACHE_HOME=/tmp/bd-abilities-home godot --headless --path godot --script res://tests/test_movement_skills.gd`

83 assertions pass: all six actual card pickups and wrong-stage/dead/boundary rejection, locked skills, slide run-up/timing/damage/own-world shove, double-jump edge/rearm/source variant, shared wall slide/coyote and World 5 impulse/no-slide, pound gates/landing/strict radii/super/gaps, dash double-tap/cooldowns/CPU/lock exceptions. These are module-level tests with deterministic host stubs, not end-to-end movement on every map or a simulated full-game clear.

## Main-scene integration review

`tests/test_skill_integration.gd` runs the real main scene and host controls through `step`, with silent audio and an isolated temporary save fixture. On Godot 4.6.3, 62 checks pass. Coverage includes canonical saved skill sanitization/deduplication and restoration into both modules, actual park slide-card acquisition/persistence and the other five card-stage preview non-awards, no stage-entry auto-unlock, actual main slide/air-jump/dash/wall-jump/pound sequencing, earned-only dash touch control, combat big/fly flags, direct World 1 slide shove/flash/pop/reward, damage-block priority before Maya's hit counter, and death cancellation.

The review found and reported a World 5 main-scene wall-hit discrepancy. Main now uses actual movement, the source >0.3px collision threshold and excludes camera margins; a regression assertion verifies camera-margin collisions cannot grant wall jumps.

Later-world movement cases use explicitly constructed flat/wall terrain fixtures inside the real scene. They test phase ordering and collision hooks, not faithful traversal of later worlds. Preview card-stage tests position the player at the real source pickup and verify nothing is awarded, while the native park test verifies the actual award; source pickup geometry itself remains covered by the module suite. Native card earning is intentionally disabled until the corresponding authored stage is actually ported; the park is now enabled. Eighteen complete park/alley/bonus input runs also verify earning, saving, reloading and using the slide. No fake progression or full-game completion is asserted.

Run the integration suite with an isolated HOME/data directory:

`HOME=/tmp/bd-skills-integration XDG_DATA_HOME=/tmp/bd-skills-integration XDG_CACHE_HOME=/tmp/bd-skills-integration godot --headless --path godot --script res://tests/test_skill_integration.gd`
