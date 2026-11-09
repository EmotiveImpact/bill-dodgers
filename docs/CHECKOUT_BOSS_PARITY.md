# Checkout puzzle controller: isolated source parity

Status: isolated implementation and headless contract verification, 2026-11-09. **This does not enable 2-6.** No checkout renderer, main-scene progression run, save promotion, export, device test or deployment is claimed by this work. The implementation must remain gated until host integration, visuals and a legitimate objective run pass.

Owned deliverables:

- `godot/src/checkout_boss.gd`
- `godot/tests/test_checkout_boss.gd`
- This document

## Evidence and units

The active boss is `TB` with `L.readyEnd/update/shot/targets/cpu` in `game/2-6/index.html:1200–1286`, and the painter hooks through1367. The executable code takes precedence over the stale comments at1170–1173. Shared `updateShots`529–559, `updateJar`620–625, `stageClear`625–630, `updatePlay`633–673, `lvShot`860–863 and ability `bossOn/zap`1697–1707 establish integration order and exclusions. Also see `WORLD_TWO_IMPLEMENTATION.md`, section5.

Coordinates are absolute world pixels. Player `p` is absolute feet, unlike browser `GROUND+p.y`. Timers use seconds and velocities use px/s. The host caps play delta to34ms; the component does not clamp or subdivide supplied delta. Large-delta tests isolate source single-pass/no-catch-up branches and are not gameplay/difficulty evidence. A 1 ns timer epsilon normalizes unit-conversion residue at exact source millisecond boundaries, including preventing a duplicate replacement-crate batch after 1500 ms.

## Host interface

`reset(host, runtime)`

- Fresh-run only. Clears TB, its jar, bags, carry references, boss-hit counts, mash, event queue and completion latch. Removes only surfaces tagged `receipt`, leaving unrelated geometry and object identities unchanged.
- `runtime` supplies `run_generation`, `surfaces(host)` returning the live mutable Array, and `rng`. The shared `world_two.reset` remains responsible for resetting shared gates, scene state and drop-zone counters. A regression checks this combined fresh-run behavior.
- Continue restores player health/invulnerability without calling reset. Pause, all-down, wrong stage/host and stale runtime generation prevent stepping. No wall-clock timer survives a run.

`ready_end(host) -> bool`

- Invoke at the normal source end predicate: camera ≥4160 and all three authored approach waves done, before enemies/shots this frame.
- Always returns false. Initializes once at x4760 with 70 solo/90 multi-participant HP, sets `host.camera_lock=4162`, emits the boss-music event and boots for strictly >1400ms.
- The method assumes the caller performed camera/wave eligibility, exactly like `L.readyEnd`; it is not a replacement eligibility check.

`camera_cap() -> float`

- Returns 4162 while an encounter exists; otherwise infinity. It does not create a boss/body collider.

`intercept_shot(host, bullet) -> bool`

- Takes the existing native projectile dictionary with `p:Vector2`; `damage`, ghost, homing and special flags never multiply TB damage.
- Call after ordinary enemy collision and shared gate buttons, before generic boss/ordinary breakable crates and the final solid-wall cleanup. Both physical and ghost shots use this same hook.
- True means consume the shot. Enter/down/outside reject consumption. Other intersecting states consume even invulnerable bounces.
- Optional dictionary `owner` receives source `bossHits`; existing ownerless solo shots increment `checkout.players[host_instance_id].boss_hits`. Random body chip hits do not increment either counter.

`late_tick(dt, host, runtime) -> String`

- Invoke after shared `lvUpdate` work, including coins/pickups, hazards, late carts/drones, and receipts/card. It performs `L.update` then the shared jar pass, including after every early return and on the jar-spawn frame.
- Returns `"jar_collected"` once and only after a genuine jar collision. The host then invokes its ordinary completion pathway, which banks remaining coins exactly once, stops music, saves the legitimate clear and presents the existing settle-up/replay/world-selection flow. Automatic next-stage routing remains a separate unfinished native feature. The component never changes save data, grants an artificial clear, banks coins or sets the game mode.
- The host must defer all-down handling until this base frame finishes, as the shared W2 host does. Ability effect/ghost aging follows this method, so a newly emitted late ghost collides next frame.

`input_event(host)`

- Call once for every native key-down and touch-start, including actual keyboard repeat, in active play. Do not derive it from held action state or count an emulated mouse event again.
- Input count is global, consumed by the next update and applied to every bagged human. CPU bags lose only elapsed time. The component does not impose an additional movement multiplier or carry/throw input.

`drain_events() -> Array`

- Returns and clears visual/audio integration notices: `boss_music`, `bagged`, `bag_released`, `crates_dropped`, `freeze`, `hit`, `screen_hit`, `bounce_hint`, `down`, `jar_spawn`.
- Normal sound names already go through `host.sfx`, and source instruction text goes through `host.status`. Events provide particle, floating-text, shake and music-flag data for a later host/painter integration; those visuals are not implemented here.
- `boss_music {enabled:true}` starts boss music. Source defeat only sets its `bossMusic` flag false; `enabled:false` is a flag change, **not an early soundtrack-stop request**. Music stops on jar completion.

Existing required host services are `player`, `velocity`, `hearts`, `invincible`, `hurt_lock`, `player_animation`, `grounded`, `crouching`, `camera`, `camera_lock`, `level_id`, `mode`, `enemies`, `status`, `character_height()`, `view_top()`, `sfx()`, `hurt_player(x)`, `add_coins(point,count)`, `combat.spawn(host,side,kind)` and `combat.kill_enemy(host,enemy,false)`. No new solo player fields are required. The component never assigns `host.boss`.

## Painter snapshot

`snapshot()` returns a detached deep copy with `active`, `boss`, `jar`, `players`, `mash`, `clear_reported`. Drawing must not mutate it or advance RNG/timers.

- `boss`: source-shaped keys `x`, `hp`, `max`, `state`, `t`, `phase`, `flash`, `mouth`, `beam`, `beams`, `next`, `frozen`, `crates`, `placed`, `crateT`, `steps`, `stepT`, `spawnT`, `bounce`. `codes=[]` and `dizzy=0` intentionally remain dormant.
- `beam`: null or `{y,t}`. Harm is strictly900<t<1450ms, warning lasts until 900 and completion is strictly>1600. A painter should preserve the source's exact visual bounds rather than assume all active-red frames cause harm.
- Crates: `{p,vy,st,k,by}` with source states `fall/ground/carry/fly/on`; flight adds `t,start,target`. Kindk selects imported `crate0/1/2`. `p` is crate bottom-center, not its top-left. `by` is a stable identity, never a cyclic player object reference.
- Players: identity-keyed `{p,height,cpu,bag,crate,boss_hits}`. Solo identity is `host.get_instance_id()`. Bag shape uses feet and full height as in `L.mid`.
- Jar: empty or `{p,v,t,got,by?}` with source absolute coordinates. Painter should use the shared jar art rather than a generic boss death animation.
- `receipt_step(i)` returns `{row:[x0,x1,top],plat:true,receipt:true}`. Exact steps:4385–4475/top412,4465–4555/top347,4545–4635/top282. These same dictionaries are appended to live runtime surfaces, so all shared landing/below/item/projectile/skill queries see them.

## Preserved encounter behavior

### Boot, scanner, bags and barrier

- The body hit rectangle is strict x(4635,4885),y(122,482), independent of painted art. Screen damage tests y<272.
- Boot returns before fights, phase clocks, helpers and the barrier. After boot the initial1800ms countdown begins; a new beam immediately receives that frame's dt.
- Phase 1 never loses HP. Three completed scanner beams advance phase 2 on the **next** update, with next1600ms and a new three-crate batch. Completed beam delays are1200/2600/2000ms by phase.
- Scanner checks every living player's source body: standing.86h/crouched.56h, bottomfeet−4, x<4635. Bag eligibility checks existing invulnerability before wrapped hurt. A shield, slide or dash can reject health loss **while bag still applies**; new bag1500ms zeros horizontal velocity without changing vertical velocity.
- Each bag loop removes dt plus160ms per human key/touch event, zeros vx and refreshes lock≥60ms/hit animation, even on the release frame.
- The final player barrier is strictlyx>4625→4595. Enter, down, frozen, freeze-expiry and freeze-trigger returns skip it. It is not an always-on wall or solid boss body.

### Crate puzzle and frozen damage

- Three kinds spawn around living players, clamped between camera+60 and 4475, at viewTop−60/−150/−240. Falling gravity2500px/s² ends atground 482 without damage. Ground pickup requires phase 2, no bag/carry, |dx|<46 and feet>422. Landing, pickup, carry and flight each take their distinct source else-if pass.
- Carry uses full character height+10. Dead, out or absent owner drops toground 482 and clears carry. The module never reduces walking speed.
- Strictlyx>4335 auto-throws and increments `placed` immediately, not at impact.650ms flight adds a160px sine arc. Targets are(4846,354),(4906,354),(4876,292); the second is deliberately outside world width4900.
- Once placed≥3 and no crate remains flying, freeze5000ms cancels the beam and returns before helpers/attacks/barrier. Frozen body/screen hits do exactly 2/3. Phase 2 floors21/27 shorten freeze to1ms rather than kill.
- Freeze expiry removes on-tray crates, resets placed, schedules replacements1500ms later and returns. Phase 3 threshold is checked **before** frozen decrement, so the phase changes the following frame after expiry.

### Phase 3, helpers, defeat and jar

- Phase 3 clears non-on crates/carry, resets step counters, cancels beam, sets next2500ms and immediately spawns a rush helper on each side. This pair ignores the normal helper cap and does not reset the helper accumulator.
- Receipt steps appear one per strictly >600ms, resetting the accumulator without catch-up. Non-frozen later-phase helper timer>11000ms spawns below 1 solo/2 pair active bots. At cap it keeps accruing; pop bots do not count. Frozen time does not advance it.
- Phase 3 screen hits always 3; body has 34% chance of 1. There is no forced stair-completion gate, no multiplied dizzy damage, no barcode reflection or stock-rain attack. Seeded runtime gameplay RNG is separate from future cosmetic render RNG.
- Defeat clears attacks/bags/carry/crates, drops 20 base coins at(4700,282), and ordinary-pops each live helper without player kill credit, retaining their usual 4–6 coin drops. Existing receipt platforms remain.
- Strictly>1500ms down spawns jar(4610,262),v(−150,−900). Shared jar update then immediately applies this frame's dt. Gravity2400px/s², floor 452, bounce−.4 above 200px/s, horizontal velocity halves on impacts; once settled it stops moving.
- Collection requires a living player, |dx|<50 and jar age>600ms. **No vertical condition exists.** Completion is reported once. Defeating TB alone never clears or banks coins.

## Ability and optional participant contracts

`host.boss` remains null. The existing shared abilities' `_boss_on` therefore remains false for checkout: Ama does not auto-stun/target it; Maya aura and Theo boss targeting remain blind; JP rain is not boss-biased; ground-pound boss auto-targeting must remain blind too. Incidental actual shots and untargeted ball ghosts can intersect TB through the ordinary ordered shot hook. Damage values are fixed by TB regardless of the special or unlocked super multiplier.

Solo is the currently usable host interface. Optional `combat_participants()` may return persistent dictionaries with `p/hearts/down/height/crouching/grounded/cpu/invincible/velocity` and `hurt_combat_participant(participant,x)`. Mutable dictionaries receive `checkout_id` once; a host returning fresh snapshots must provide stable `checkout_id`, `id` or `slot`. Bag/carry/lock/animation are published back to non-host participant dictionaries. This schema is tested but is **not a claim of integrated co-op/network or CPU play**.

`cpu_input(host,participant,inputs)` extends a future shared CPU controller using native keys `left/right/jump/down/face` and a seconds-valued `participant.jump_cd`. Source high-beam duck500–1500ms, low-beam jump780–1000ms, nearest ground crate/carry target4375, and receipt climbing are preserved. `targets()` returns [4700] only for active fighting TB. CPU input is not wired into a game host here.

## Verification

Executed headlessly with Godot 4.6.3 using isolated HOME/XDG locations:

- `test_checkout_boss.gd`: **207 checks, 0 failures**.
- `test_supermarket_combat.gd`: 115 checks, 0 failures.
- `test_supermarket_hazards.gd`: 118 checks, 0 failures.
- `test_abilities.gd`: 67 checks, 0 failures.
- `test_ability_ghost_order.gd`: 45/45 checks passed.

The four shared regression results preceded concurrent course-controller host integration. The checkout suite was rerun cleanly against that updated runtime after adding the new host `elapsed` fixture field. The integration owner must rerun the shared suites against the final combined tree.

Coverage includes exact timing/geometry edges, all six character heights, all six shared special activations and generic-boss blindness, real shared Maya/slide/dash protection, physical/ghost interception priority, crate flight positions and ordering, replacement batch residue,21/27HP floors, phase/helper/step timing, source barrier early returns, body-chip alternative, ordinary helper coin drops, jar bounce/age/horizontal-only collection, one-shot completion, reset/Continue/pause/stale generation and optional pair/CPU records.

Tests use deliberately configured state fixtures and isolated large-delta probes. They do **not** constitute an input-driven full checkout run or prove difficulty, render alignment, mobile touch routing or any device/export correctness. The aggregate verification script was not edited or run by this isolated owner; host integration must register the new suite and rerun full regressions and packed verification.

Outstanding integration gates: source-ordered main hooks; exact key/touch mash routing; event consumption/music; checkout painter with warning/active scanner, body/tray, all crate states, bags/error/steps/jar; authoritative completion/save flow; actual approach-wave and puzzle run without synthetic clear; all-six-character visual/input/controller coverage; mobile pause/resume and device QA. Keep 2-6 preview-only until those pass.
