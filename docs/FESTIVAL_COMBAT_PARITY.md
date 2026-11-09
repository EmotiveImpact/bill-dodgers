# Festival combat and bosses: native controller parity

Date: 2026-11-09. Scope: `festival_combat.gd`, `festival_boss.gd` and their standalone Godot fixtures. These are reusable World 3 controllers. This report does not promote a stage, certify co-op, establish human difficulty or claim iPhone/Android validation. The host/runtime owns supported-stage gating, input, saves, late hazards, music, scene lifecycle and completion.

## Source and units

All seven `game/3-*/index.html` copies share the same active runtime. The independent runtime audit verified lines 90–2286 byte-identical, joined-LF SHA-256 `d1606058aeeea3d470295ccad5b7c29d630b34063fc2abb43ca88a949ef0303c`. Imported non-image META matches each original. See `WORLD_THREE_IMPLEMENTATION.md` for the complete source contract.

Read active dispatch, not copied dormant `startBoss0/updateBoss0`: actual encounters use `startBoss(cfg)/updateBoss/bossDown` at 1350–1395. Boss shot collision is the shared `updateShots` at 528–558. Coordinates are absolute feet pixels. Milliseconds become seconds, px/ms becomes px/s and px/ms² becomes px/s². Synthetic stage and trailer surfaces remain explicit dictionaries. Tiny numerical tolerance protects millisecond timer boundaries from binary round-off; no gameplay-sized tolerance is added to geometry.

## Module contracts

Combat API:

- `reset(host, participants=1, seed_value=31)` copies `host.meta.l3.waves`, initializes crates from `host.level.crates`, and clears presentation state. Call only for a fresh run, never Continue.
- `waves_tick(dt,host)`, `enemies_tick(dt,host)`, `projectiles_tick(dt,host)`, `pickups_tick(dt,host)` are separate ordered phases.
- `spawn(host,side,kind)` implements ordinary left/right, tent `t`, carrying delivery drone `k` and flying drone `d`. `new_bot` exposes the shared source factory for fixtures and adapters; it is not an invented numbered wave format.
- `damage_enemy`, `kill_enemy`, `hit_crate` are low-level state callbacks. Shared character/skill hits must retain the host's **ghost-shot routing**; do not replace that path with direct HP subtraction.
- `start_boss(host,cfg)` creates an actual configured `host.boss`; `boss_tick(dt,host)` handles emitted events and returns `mini_done` after removing the finished mini and camera lock. Host/runtime sets its mini completion flag. `jar_tick` returns `clear`, which only the supported native host may settle.
- `visuals_tick(dt,host)` snapshots stride, decrements `go_time` and updates exiting-drone ages. Renderers do not advance gameplay. Exiting drones store their birth level-time so newly detached carriers begin at age zero in the same frame.

Runtime adapters are `world_three.surfaces(host)`, `below(host,x,y)`, mutable `tents`, live `trailer` (empty dictionary when absent), `cam_dx` in pixels for this frame and `level_time` in seconds. A surface is `{row:[x0,x1,top,...],plat,...properties}`; enemies retain both the row and the **same surface dictionary** for late motion. `set_tied(host,participant,seconds)` runs on every tie hit, even rejected damage. Optional `boss_event(host,event)` receives cheer/music/presentation events without discarding tie metadata.

Native solo uses host player/hearts/power/grounded/velocity. Optional mutable `combat_participants()` records can test scaled rosters and use `hurt_combat_participant`; this is an adapter, not a playable co-op claim. Event dispatch retains its participant snapshot so a preceding death cannot shift a subsequent contact onto another player.

Boss API is separately testable: `reset(cfg,view_width,ground_y,participants,seed,stage,tents)`, `boss_tick`, `jar_tick`, `tick`, `hit`, `drain_events`. `state` follows existing host/ability conventions (`x`, `fy`, `hp`, `max`, `state`, `t`, `dizzy`) and includes source waves/hop/landing timers plus jar. Projectile hits intentionally ignore their damage argument, including special ghosts.

## Preserved behaviors

### Waves and ordinary bots

The optional fourth group field excludes co-op-only entries in solo. Groups are never sorted: late appended early-delay entries remain blocked by the entries before them. Native inventories from actual META are:

| Stage | Waves | Solo spawns | Two-participant spawns |
|---|---:|---:|---:|
| 3-1 | 10 | 47 | 58 |
| 3-2 | 15 | 51 | 66 |
| 3-3 | 10 | 48 | 65 |
| 3-4 | 9 | 31 | 40 |
| 3-5 | 16 | 39 | 62 |
| 3-6 | 3 | 10 | 13 |
| 3-S | 0 | 0 | 0 |

Waves start at camera ≥ authored position−2. Ordinary waves lock camera+40 and wait until all live bots are gone; auto waves finish after final dispatch regardless live bots. Neither start nor completion replaces a boss lock. Failed placement consumes the entry once. A death in later combat does not release a wave until the next waves phase.

Ordinary spawn searches 50 inward candidates at 24px intervals. It accepts solids or platforms wider than260, rejects `nospawn`, applies strict30px margins/view height and chooses nearest mean living feet. Rush HP3 versus throw/flat HP4, source speed/cooldown/retreat ranges, 220/440ms throw timing, arc/flat projectile math and adjacent-solid hops are retained. A new bottom-of-pass hop still contacts the player that frame; existing hops skip contact, including their landing frame.

Untouched non-ride/non-fly bots retire after **12 seconds**, not the stale14-second source comment. Flash decays before refreshing hit-age. Retirement drops no coins or credit. Daze and emergence each skip AI/contact for their complete expiry frame, and both precede wellies. Bubbles skip AI, age and cleanup; the shared ability phase reinserts held bots last before shots.

### Tents, carriers, flyers and wellies

Tents have **no independent HP** in the executable source. A valid tent is visible, strictly more than150px from the front living player, and free of any bot within40px, including popped bots. Rank by distance from front+260; validate its floor, then rise/shake for500ms. Otherwise use an ordinary right spawn. Exactly100px platforms accept a tent arrival; ordinary spawn still requires width>260.

Carrier drones hang a3HP bot75px above the deck, move relative to camera, throw source arcs and drop onto the live trailer after their authored random delay. The420ms delivery hop retains the unusual `cam_dx*30` prediction. Dropped bots become rush type. Fly drones have2HP and source absolute-time bob/retarget/drop-bill behavior. Both bypass ordinary contact and retirement; both still use the normal34×112 shot rectangle. Popping a carried bot detaches its drone exactly once, in the kill transition instead of mutating gameplay in the painter.

Wellies stomp live hook-eligible bots only: airborne, falling>100px/s, strict52px horizontal and feet range bot−135..bot−50. The bot pops regardless HP and the player rebounds−800px/s. This happens after daze/rise and before carrier/fly handling. No invented boss stomp or tent destruction exists.

### Projectile and pickup order

Every player shot moves, then checks bots → boss → crates. All player-shot hooks finish before the separate solid/camera/view filter. Late spotlight and harvester interception belongs after this phase in the runtime. Bot hits sweep x from the owner on first frame, use new y, double requested damage only when `dz>0`, and shove6px **before** the pop/coin callback. Boss shots are nonswept, fixed1 or2 while dizzy. Crates always take1 per bullet. Empty/expired/canceled shots do not reach late hazards.

Bills move after player shots and hit players before floor/solid/camera cleanup. Wristbands set2.2s tie even when damage is rejected by invulnerability or a passive. The late world phase decrements tie in the same frame. Ama and Maya cancellations remove bills before motion/contact, including a shield expiring in that pre-step. A boss volley is created after the shot phase and first moves next frame; carrier/fly volleys are created before it.

Coins preserve semi-implicit gravity,8px support offset, bounce/magnet/strict pickup thresholds. `stay` prevents11-second expiry but does not prevent behind-camera culling. Items retain26px support offset, strict300ms age and horizontal-only collection, with12-second powers. Crates begin with3HP and launch their configured item40px above their feet at−600px/s. Authored coin-row creation, receipts, skill cards and final coin sweep remain runtime/host responsibilities.

### Configured bosses and final jar

Actual HP by solo/two participants: Wristband Seller3-1 **60/80**; Bailiff3-3 **70/95**; Ringmaster3-4 **60/80**; Ticket Tout3-6 **160/220**. All are configuration-driven, not a W1 boss with a new tint.

Preserved details include the first-enter-frame arena clamp,320/640ms attack frames,3/4/5-band volley scaling, non-tying Bailiff bills and charge, strict66%/50%/33% helper/dizzy thresholds, tent-preferred first helper,2.6s one-shot dizzy, source contact/ground shockwave boundaries and Tout's stage/slam branches. Numeric stage0 is distinct from boolean false. Hops return even when landing, so threshold callbacks/contact/stage countdown resume next frame. New stomp waves likewise do not move until next tick.

Down cancels hop and ground waves, drops16coins and pops every live helper using normal coin drops. Existing hostile bills are deliberately retained. Minis disappear only after>1.8s and never spawn a jar or clear the level. The non-mini spawns its falling jar after>1.5s; its first jar phase consumes the full current dt. Jar pickup requires horizontal distance<50 and age>0.6, no y test. The native event emits one clear even if two players overlap, avoiding duplicate settlement. Source late jar attraction remains runtime-owned.

## Verification

Commands (isolated writable HOME/XDG directories):

```
godot --headless --path godot --script res://tests/test_festival_combat.gd
godot --headless --path godot --script res://tests/test_festival_boss.gd
```

Latest focused result: **135 combat checks and116 boss checks, zero failures**, Godot4.6.3. Tests include all seven wave inventories/immutability, strict timer and rectangle boundaries, spawn scanning, tents, retirement/flash ordering, bubble isolation, rise/daze-before-wellies, real delivery/fly motion, shot and wall order, canceled bill/tie behavior, staying money, crates, boss adapter and all configured boss state machines. Actual `abilities.gd` is exercised for Ama bubble/ghost interception, Maya expiry cancellation, delayed football ghost damage and bubble-release ordering.

These focused fixtures are not a replacement for the parent's main-scene integration/full3-1 traversal, aggregate regression, visual comparison, human challenge testing, mobile controls or signed phone exports. Later World3 level-specific runtime systems remain gated until separately integrated. No deployment or push is part of this change.
