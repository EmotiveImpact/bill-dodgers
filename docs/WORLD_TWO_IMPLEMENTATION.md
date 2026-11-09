# World 2 implementation contract: The big shop

Status: source-grounded implementation contract, audited 2026-11-09. The initial plan below is preserved as design history. **All seven World 2 stages are now integrated and pass six-housemate input-driven progression tests with explicit invulnerability**; see WORLD_TWO_RUNTIME_PARITY.md, SUPERMARKET_COMBAT_PARITY.md, WORLD_TWO_RENDERER.md, SUPERMARKET_INTEGRATION.md and PARKING_RUN_VERIFICATION.md. Checkout controller, renderer, focused real-main and complete-route evidence are in CHECKOUT_BOSS_PARITY.md, CHECKOUT_RENDERER_PARITY.md, CHECKOUT_INTEGRATION.md and CHECKOUT_RUN_VERIFICATION.md. Campaign next-stage routing remains separate unfinished work. Aisle and bonus acceptance evidence is in AISLE_RUN_VERIFICATION.md, SHOPPING_BONUS_RUN_VERIFICATION.md and AISLE_INTEGRATION.md. The later implementation chunks below are not claims of completed work.

## Evidence and scope

Read the actual executable hooks in `game/2-{1,2,3,4,5,6,S}/index.html`, their imported JSON, `docs/LEVEL_PARITY_MATRIX.md`, and native `main.gd`, `combat.gd`, `world_one.gd`, abilities/skills/save integration. The embedded `META.level` and `godot/content/levels/<id>.json` level objects compare equal in all seven files. Readable JSON is the geometry/wave/hazard inventory, not an implementation of the hooks.

The shared HTML **lines 313–1168 are byte-identical** across all seven pages (SHA-256 of those lines joined by LF, without trailing LF: `611cbb893cf49c2ade8e458a2fd01033a7f2a7640ca4af90895e82a36703cf12`). Shared anchors below therefore use `2-1`; stage-specific anchors identify their own page. Recheck function anchors after source revisions. Never print the enormous base64-bearing META/SRC lines to inspect code.

Units below follow source unless stated otherwise: time **ms**, velocity **px/ms**, acceleration **px/ms²**, coordinates absolute world pixels. Native equivalents multiply velocity by 1,000 and acceleration by 1,000,000; divide timers by 1,000. All W2 ground lines are 482, fall lines 742, view width 738 (`round(960/1.3)`), zoom 1.3. Native player `Vector2.y` is absolute feet, whereas JS `p.y` is feet minus 482. Source simulation dt is capped at 34 ms.

### Immediate next chunk: make 2-1 a real solo stage

Use three disjoint module owners and **one host integration owner**. Suggested parallel handoff:

1. **World/runtime owner:** `world_two.gd` plus isolated tests. Implement `reset(host)`, runtime surface queries, `base_displacement(player,move,dt)`, `camera_cap()`, `objective_tick(dt,host) -> event`, `after_pickups(dt,host)`, `intercept_shot(shot,host) -> bool`, scene callback/run token, checkpoint, authored coins, trolleys and W2 receipt data. Initially exercise only 2-1, but parse future hazard schemas without claiming those levels supported. Return state snapshots for the renderer. No edits to main or W1 modules.
2. **Combat owner:** isolated `supermarket_combat.gd` plus tests, with `reset(host,participants,seed)`, `waves_tick`, `enemies_tick`, `projectiles_tick`, `pickups_tick`, `spawn(host,side:Variant,kind)`, `late_carts`, `late_drones`. Reuse simple helpers only when behavior/order matches. Preserve ordinary bot dictionary fields used by abilities; expose W2 hw/hh and security/cart/drone semantics. Do not silently change existing `combat.gd` W1 dispatch.
3. **Renderer owner:** `supermarket_renderer.gd`/parking painter plus tests/screenshots, consuming runtime state and `host.images` only. Implement `draw_sky`, `draw_level`, `draw_mid`, `draw_enemy`, `draw_player_back/front`, `draw_front`, `draw_hud`; source parking crops/scene filter and trolley warning/geometry first. Do not own physics, progress saves or main.
4. **Integration owner, after interfaces agree:** runtime registry/adapter and minimal `main.gd` + shared save capability list. Wire the phase order below, per-world receipt geometry and ability ghost/bubble ordering; integrate only 2-1. Add full11-wave/scene/receipt/actual-end controller regression, then run every W1 suite and packed-runtime checks. Keep all other W2 IDs previews until their own modules and runs pass.

For 2-1's first milestone, no checkout/controller or gate/ice/bakery implementation blocks progress. Required dependency order is collision/spawn contract → shared W2 combat and parking scene/trolleys → host integration/rendering → complete legitimate stage run → capability/save promotion. Names above are proposed interfaces, not claims that these files already exist.

## 1. Native boundaries to fix before enabling a stage

Current `main.gd:NATIVE_LEVELS/_native_world_one/load_level/step/_complete_level` gates all integrated play to W1. `save_store.gd:read_save` independently limits cleared IDs to W1. `combat.gd` can parse an object wave but still implements W1 spawn strings, foes, checkpoint arrays and W1 hooks. Do not add W2 IDs to `NATIVE_LEVELS` and thereby send them through WorldOne.

Recommended structure, names illustrative:

- A small runtime registry returns `{runtime, combat_policy, renderer, completion_supported}` by world/stage. Keep a W1 adapter calling the current hooks in their current order; leave preview fallback separate. Expose `is_native_supported()` separately from `is_world_one()`.
- `world_two.gd` owns copied runtime surfaces, scene index/wipe state, one checkpoint flag, ice velocity per player, hazard entities/timers, gates/plates/buttons, authored coin rows, W2 pickups and normal exit. A `checkout.gd` owns only TB, scanner, bags, carry crates, receipt surfaces and jar lifecycle. Use data-driven hazard dispatch, not one main-loop condition per stage.
- Share geometric **queries**, not all world policy: `surfaces`, `land_on`, `below`, `wall_clamp`, `inside_wall`, `safe_position/recover_from_fall`. Return a stable surface identity with `row`, `plat`, owner and enabled/current top. Keep imported META immutable. Runtime gate/receipt surfaces must participate in every query, including projectiles, abilities and skill probes.
- Split `combat.tick` at existing seams: `waves_tick` → `objective_tick` → `enemies_tick` → `projectiles_tick` → `pickups_tick`; inject spawn, hitboxes and special-shot policies. A W2 combat adapter can initially reuse ordinary bot math without altering W1. Spawn location must be a variant (`'l'`, `'r'`, **numeric world x**), not the current `String` parameter.
- Runtime hooks needed: reset/start; base movement displacement; camera target/cap; end-ready/event; post-pickup world update; shot intercept after ordinary bots/before ordinary crates; CPU target/input extension; player damage/death/continue hooks; render background/level/mid/player layers/front/HUD. Use explicit phase calls, not a single unordered `tick`.
- Host service contract: living participants, source character heights, position/velocity/ground/platform/jump-edge/hurt timers; spawn/hurt/pop/drop coin/sfx/banner/clear services; runtime collision; normal and ghost shots. Preserve W1 aliases only inside its adapter. Avoid giving TB a fake Jar Thief interface merely to satisfy existing code.
- Move supported-clear allowlists to one shared definition used by menu, runtime and save validation. Promote each stage only after its real objective is integrated and tested. Keep other 35-preview handling honest as W2 stages graduate one at a time.

**Important existing-host mismatches:** `_wall_clamp`/`ability_inside_wall` currently inspect only static solids; receipt creation uses W1 draw offset −60 and pickup lower bound y−120; W2 needs −40 and y−30. `combat.spawn` cannot accept numeric x or W2 hitboxes. `_game_over` immediately changes mode on lethal damage; source all-down resolution is at the end of the frame, after a possible full-heal checkpoint. `abilities.tick` currently defers effects only for 1-6; W2 needs the same source-order mechanism without a new 1-6-or-2-* condition chain.

## 2. Exact shared step and collision order

Sources: `2-1:updatePlayer` 408–447; `updatePlay` 633–673; `updateBots` 482–524; `updateShots` 529–559; `lvUpdate` 771–841; injected wrappers 1843–1888, 2030–2129. Preserve this order even when extracting classes:

1. Increment `levelT`. Run CPU input, including common hazards/plate helper logic and `L.cpu` last. For each player, snapshot ability pre-state, run base player update, then shared ability/passive/skill post-update, then final aim-pose wrapper.
2. Base player update: invulnerability/flash/power timers; down-player revive; hurt-lock decrement; compute crouch/move/face; `lvMove` plus knockback; wall clamp then **old-camera** clamp ±30; knockback damping `0.992^dt`; ground jump/drop → W2 `lvJump` → store jump edge/drop timer → support check → gravity/landing/fall → safe solid position → fire/animation. Normal speed .27, jump −.98, gravity .0033, terminal fall 1.5, drop speed .12/drop timer260; hurt one heart, inv1500, lock420, knockback±.35. Normal/split shot intervals210/260, projectile speed .78.
3. Update horizontal camera (normal follow or `lvAuto`), scene cap and wave lock, then vertical camera. Ordinary camera never reverses: target speed `min(.42,diff/240)`, acceleration limit `.0012*dt`. Vertical tracking uses remembered grounded feet/min(current feet+170), target≤0 and blend `min(1,dt/260)`.
4. Process waves in authored order. Start when cam≥at−2, ordinary camera lock=cam+40; auto stages use no wave lock. Increment timer then consume due entries sequentially. Complete only when all entries consumed and **no live non-pop bot anywhere**; hazards do not block completion. Call end predicate now, before this frame's enemy deaths. Normal end starts `endT=1`, adds current dt, clears at >2600. A last enemy killed later this frame releases wave/end next frame.
5. Run ordinary enemy AI/contact/cleanup. Ability-bubbled bots are removed from this pass and appended after their bubble update. Then player shots: home/move → swept horizontal bot test → `lvShot` (buttons first, then TB) → dormant generic-boss slot → ordinary crates. After all shots, solid-wall cleanup/culling. Then hostile bills: move/gravity → player hit → descending surface/solid/fall cleanup. Preserve strict comparisons.
6. Run coins/items. Then `lvUpdate`: timer → scene gate/wipe → lift embedded bots out of solids → checkpoint full heal/revive → authored coin spawn/keep-age → plates/gates → button flash → trolley spawns/motion → falling-zone timers/drops → flame/low/block harm → cart late motion → drone late motion/fire → receipts/card → dead hazard removal → `L.update` (checkout).
7. Dormant generic boss if non-null; jar physics/pickup; go indicator; resolve all-down. **Only after the whole base play update**, advance shared ability effect clock/ricochet-ball effects and expire ghost shots older than70. Their new shots generally collide next frame; pre-combat passive shots collide this frame.

W2 floor/belt displacement is not a universal moving-platform carry pass: belts affect **grounded players only**, inside strict x interval and feet within4px of belt top. They do not move bots, coins, items, ordinary crates or checkout crates. Runaway trolleys are hazards, not supporting platforms. W1 crumble/chimney/bus late hooks must not run here.

Native projectile hit policy must preserve ghost-shot behavior: abilities generate shot-shaped hits judged in the same order as bullets. Do not directly damage a button/boss/crate through an earlier helper. Bubbled cart/drone objects return before `lvUpdate`, whose late cart/drone logic is not bubble-filtered in source; a blanket freeze would be a deliberate change.

## 3. Shared W2 contracts

### Waves, foes and navigation

`LEVEL_WAVES` at1059 returns `w.g.concat(extra ? w.x : [])`, where extra means more than one participant, including CPU. **Do not sort** merged delays. Example 2-1 wave6880 has base delays0/2500/4500/6500 and appended extra3500, so the extra cannot dispatch until the earlier array entries have dispatched. Preserve this oddity or record a fix explicitly.

`spawnBot` 364–373 searches up to50 candidate x positions at24px increments on non-platform solids wider than200; candidate must be30px inside, top in `(viewTop+120,camY+600)`, sorted by distance to average living feet. Numeric x searches to the **right**, initial face +1, then `lvBot` adds arrival effect and entered state. No candidate means no spawn; that consumed wave entry is not retried. Use current runtime SURF, not only level.solids.

- Rush HP3, other ordinary throw/flat HP4; rush speed `.11*(.9+random*.25)`, others `.075*(.9+random*.25)`. Rush stop0, throwers stop230–400; initial cd900–1800. Flat bill `(face*.42,0)` at feet−128; arc bill vx clamped±.5 toward player over900ms, vy−.78/g.0017 at feet−100. Release at220ms, resume walk at440ms, subsequent cd1400–2800.
- `cart`: HP2, state cart, speed .30–.36; direction by entry side/numeric midpoint. Base pass still performs entered bounds/contact/segment clamp; its extra movement occurs **after shots**. Turn bounds are segment±26, additionally screen±44 once entered. It is not the autonomous trolley hazard.
- `drone`: HP2, hw40/hh70, base=spawn floor, initial feet base−200. Late update phase advances dt/400, feet=base−200+sin(phase)*14; tracks player±60 at .09, screen clamps±40 and marks entered. First cd1500–2300, later1700–2600; sticker bill at feet+6, vx0/vy.05/g.0012. Late-spawned sticker moves next frame. Propeller is procedural over the bot sheet, not W1's `IMG.drone` enemy replacement.
- `big` security bot: HP24 solo/34 pair, hw58/hh186, speed .055, stop250, first cd1200, render scale1.66/cap/health bar. **No separate volley/slam/charge attack exists**: it uses ordinary arc-throw AI. W1 Bailiff behavior is not reusable as its policy.
- Bot shots use `(hw||34,hh||112)`; contact uses horizontal `(hw?hw+10:44)`, feet inside `(botFeet−(hh?hh−17:95),botFeet+24)`. Preserve flags `big` and source absence of `fly` on drones for shared ability/slide tests; do not infer physics flags from names.
- Ordinary walk bots can hop to next non-platform segment: height difference<230, horizontal gap<230, target width>200, player distance>30, within26 of edge; land40px inside after `520+distance*1.2` ms, sine arc height `70+max(0,startY-endY)*.6`. Hopping skips the normal contact pass that frame. W2 late solid repair lifts any non-pop/non-drone bot to the **first** overlapping solid 6–400px above its feet. Do not add W1 chimney navigation.
- Pop yields4–6 coins; remove at gone>1300. Unentered bots abandon after>6000; ordinary cleanup outside cam−400/cam+WV+400.

### Surfaces, special floors, pressure gates and hazards

Shared anchors: `lvStart`738–747, `lvMove`756–770, `lvUpdate`771–841, `lvShot`860–863, `lvCPU`865–882, `lvDrawMid`913–949.

- Landing selects the highest top crossed between old feet−1 and new feet+.5; `below` allows top≥queryY−2. Solids extend down forever, platforms are one-way. Wall crossing keeps14px offset and ignores tops≥feet−6. `insideWall` requires y>top+4. Geometry equality at boundaries differs from hazard strictness.
- Ice uses stored iv per player: grounded, strict zone x, feet within4 of floor; ease toward `move*.31` with dt/900. Leaving ice airborne retains faster momentum and eases to normal v with dt/500; otherwise iv=v. Flour multiplies base v by .55; its test has height tolerance but **no on-ground requirement**. Belt velocity adds after iv. Shared `L.speed` extension is never assigned by these seven pages: carrying a checkout crate causes **no speed penalty**. Character bonus motion is a separate post-base `.27*extra*dt` nudge, not multiplied by ice/flour/belt/carry factors. Native combining all walking multipliers would change this.
- Gate tuple `[gate,x,floor,height,id]` creates solid x±34/top=floor−height. Matching plates require grounded |dx|<46/feet tolerance6. Held refresh=5200 solo or CPU-mate;2600 two humans. A shot within30px on both axes of matching button flashes300 and raises gate timer to at least6500.
- Gate open changes by±dt/380, clamped0–1. Collider top becomes ground+5000 only when open>.55. Keep-open occupancy applies if open>.5 and a living player's x is within60 (no y test). A closed gate is not opened merely by overlap. Occupancy prevents closing on a player. Buttons intercept before TB/crates/solid cleanup but after bot hits. CPU mate intentionally returns to/holds pads while leader waits.
- Trolley spawner `[trolleys,at,n,gap,dir]` activates when camera≥at and starts with t=gap, so first spawn is immediate. One spawn per update even for large dt. Entry at cam+WV+90 for dir−1 or cam−90 for +1; uses `below(x,ground−4)`. Speed .36–.44; unsupported gravity .003; wall impact reverses/attenuates vx by−.6 **without correcting x**. Harm |dx|<46 and player feet in(trolleyFeet−86,trolleyFeet+20). Despawn outside cam−300/cam+WV+400 or fall. Cannot be shot/stood on in source.
- Drop zones `[drops,x0,x1,interval,box|icicle]` accrue time only while a living player is strictly inside; target chosen from occupants. Drop x=player.x+(random−.4)*160+face*60; landing query starts playerFeet−300. Warn950 at viewTop−80, then gravity .0032. Hit |dx|<34, bottom>playerBodyTop and bottom−60<feet. Shadow/warning is mandatory telegraph; removes on hit or reaching stored landing top. Source `LVS.d<index>` counters survive replay accidentally because `lvStart` does not delete them.
- Flame `[flame,x,floor,period,offset]`: phase=(levelT+offset)%period; harms throughout phase<1000 with |dx|<36, feet>floor−175 and≤floor+4. Visual grows150ms and shrinks after850; warning flashes in last700ms of cycle. Logical height stays175 during visual ramp. Low signs use |dx|<52 and body top minus ride*.4 below sign underside; block uses |dx|<width/2+12, feet>floor−height+8 and≤floor+4; normal newly granted inv>1400 triggers jump vy−.7. Blocks are hazard rectangles, not solid terrain.

### Checkpoint, pickups, persistence and recovery

- Source checkpoint is **one `LV.check` scalar**, fires at camera midpoint≥check, heals **every** player to3 and revives down players with inv2000. It does not save a respawn coordinate or reset the encounter. Fallen-player recovery uses latest interior solid safe position (90px inset), clamped into camera; searches right in20px steps, then fallback; clears inv before normal damage. W1 geometry helper is reusable, W1 checkpoint healing is not.
- Continue after all-down retains scene/waves/gates/coins/TB and player positions, restores hearts3/inv2500; it is not `load_level`. Fresh start must reset everything. A teammate revive requires proximity80x/70y for>1400ms, gives2 hearts/inv2200/lock600; progress decays .5×dt without helper. Keep co-op schema even if first milestone is solo.
- Coin rows `[coins,x0,x1,y,count,arc]` spawn once when x0<cam+WV+260, evenly spaced with sine arc, t300/rest/keep. Keep coins reset age to2000 each late update if rest and age>2000; generic filtering still runs first and removes behind cam−60. Do not expire all authored rows at11s. Configured coins are distinct from enemy drops and receipts.
- Ordinary coin gravity .0024; floor bounce−.45/vx*.7 until |vy|≤.15; age>250 before attraction/collection. Attraction110x/150y at .5; collection30x/height*.6. Crates HP3, shots remove **one HP regardless s.dmg**, drop item at feet−40 with vy−.6; items gravity.002, rest26px above surface, pickup after300 and |dx|<40 **with no vertical check**. Heart+1 capped3, split/debit12000ms. No conveyor transport or imagined item expiry.
- Three receipts each stage use source **1-based n**, display center `(x,y−40+sin(t/260)*4)`, pickup |dx|<42, feet>y−30 and feet−height<y. Reward adds5 to shared kitty, not personal coin count. The source presents/rewards receipts again on replay while deduplicating persisted IDs. Native currently hides saved receipts and uses zero-based IDs; retain native save indexing by explicit adapter n→n−1, and document/test replay-award policy instead of silently mixing conventions. No web-save migration is implied.
- Bakery card uses the same pickup geometry. `movement_skills.gd` already knows `(8850,232)` and W2 air-jump order: fresh non-down jump, airborne, unlocked, not used, vy>−.9 → vy−.86 before gravity; grounded resets it. Award/persist only on actual touch in an enabled 2-5 run. No entry/clear/debug unlock. Source fallback slide/dash/wall/pound still works if earned elsewhere; W2 owns double-jump and disables the generic fallback.

## 4. Seven stage contracts and inventories

Counts below are static solids/platforms/ordinary crates, then waves, authored coin rows/coins. Runtime gates/receipt stairs are additional. Wave group totals are attempts, not guaranteed successful spawns; exact arrays remain in JSON.

| Stage | Width/start | Geometry; waves (solo + pair extras) | Authored coins | Scene/checkpoint/end |
|---|---|---|---|---|
| 2-1 Car park |16000 /300|1/13/5;11 (52+12)|13 rows/73|Lift7600→8020; check7700; distance+waves+2600ms|
| 2-2 Aisle seven |15200 /300|1/14/5;10 (43+11)|12/70|Door10400→10820; check10500; normal end|
| 2-3 Stockroom |14600 /300|13/19/5;11 (46+12)|6/40|Lift8910→8910; check8950; normal end|
| 2-4 Trolley dash |40000 /330|1/0/0;13 (40+13)|43/243|No scene; check20000; variable auto camera + waves + normal delay|
| 2-5 Bakery |15000 /300|1/9/5;11 (45+12)|8/46|Door9400→9820; check9500; normal end; actual label **Shop floor**|
| 2-6 Checkouts |4900 /300|1/5/3;3 (14+3)|5/25|No checkpoint; final camera4162 activates TB; jar only|
| 2-S Sample sprint |9000 /300|1/0/1;2 (4+2)|22/128|No scene/checkpoint; normal end; timer100000 is dormant|

### Scene transitions shared by 2-1/2-2/2-3/2-5

`sceneStart/SCN/lvCamMax/sceneUpdate`1115–1137. Stop camera at `sceneX+sceneView−738`, clamp every player x≤sceneX, wait for no active wave and no unfinished wave with at≤camera cap, then trigger when front living player≥sceneX−50. `LVS.wiping` suppresses duplicate transitions, not the rest of simulation.

For 2-1/2-2/2-5: sceneView300/land420/cam offset160. Camera caps7162/9962/8962; post-transition camera at least7860/10660/9660. Place players at destination+i*70 and highest surface via below(−9999). Stockroom uses sceneView120/land0/cam offset200/landY=476: cap8292; destination8910−i*70, floor482 rather than nearby high racking; camera≥8710. Zero must not be replaced by a default420.

Callback increments scene, resets player vx/vy/grounded, revives down players to3, marks bots left of destination−100 pop, clears player shots/hostile bills, resets camV/camY. Source does **not** reset safe/onPlat/ice/ability caches here. Record any native safety cleanup as deliberate. Guard callback with a run-generation token so exit/restart cannot move a new run.

`game/polish.js:BD.wipe/drawWipe`109–163 currently renders all lift/door/stairs as soft iris: close520, labelled hold1050, open600; callback at1430ms (close+hold−140). Source W2 does not check `BD.wiping` to suspend simulation/input; decide/test pause and app-background behavior explicitly rather than presenting a different freeze as parity.

### 2-1: parking decks and trolley introductions

Stage hooks/rendering1170–1289. Thirteen car roofs are one-way platforms, not car-body walls; painted cars from `LV.cars` align at ground−imageHeight+4. Top deck → surface car park is a scene change, not a moving lift surface. Autonomous trolley sets `(at,count,gap,dir)` = `(2600,3,1300,−1)`, `(5200,5,750,−1)`, `(11300,4,1000,−1)`, `(13900,3,1100,+1)`. Two security waves at6880 and final15262. Numeric spawn x values in this stage must survive normalization. Receipts `(80,482),(3920,269),(12120,269)`, including the one **behind** starting x300; test leftward recovery before camera advances.

### 2-2: shelves, high button and frozen aisle

Stage1170–1218. Gate x positions2500/4500/6500/9200/9700/12000/14000, all floor482/height560 (closed top−78). Plates `(1900,482,id0),(5950,482,2),(8750,482,3),(9450,482,4),(13450,482,6)`; buttons `(4370,152,id1),(11650,372,id5)`. The high first button needs shelf/aim geometry, not a generic proximity interaction. Seven shelf islands each have levels364 and246.

Boxes zone5000–8000 every1700; ice10800–13700 at482; icicles11000–13600 every2300. Scene label Frozen foods. Receipts `(3700,246),(8300,246),(12880,246)`. Test coupled gates9200/9700, press/release, delayed closure occupancy, shoot-button during bot interception, jump while retaining ice momentum, and full heal only after transition.

### 2-3: racking climb, belts and loading-bay opening

Stage1170–1271. Six towers `(x0,x1,height)` = `(3000,4400,360),(4650,5600,240),(6000,7400,240),(7700,8800,360),(10500,11700,480),(12100,13000,360)`. Ground gap9000–9440; chained pallets `[9110,9200,452]`, `[9270,9340,422]` are **static** one-way platforms, not animated pendulums. Tower maximum top2. Keep nineteen authored climb/bridge platforms and side-wall rules; do not substitute a trolley race.

Belts `[4400,4650,122,+.08]`, `[7400,7700,242,−.07]`, `[11700,12100,122,+.10]`. Drop zones3000–5600/1900 and10400–13000/1600. Elevated security wave at6900 and end13862. Scene is a visual goods-lift transition to **Top floor**, not y-teleport onto the highest rack. Receipts `(9305,422),(8760,122),(11620,2)`. Test spawn search against height/camera, magic solid lift after shots, no enemy chimney extension, safe recovery at both sides of gap, and route without an earned double-jump.

### 2-4: trolley dash is variable camera scrolling

Stage1170–1212; `lvAuto`749–754. Ground remains482, normal control physics remains active; trolley art surrounds player and sprite feet render30px higher, low-sign body test subtracts another12px. It is **not** a shared moving deck or locked player x. Base auto .20; boost determined at cam+.4*738, multiplier1.55; active wave multiplier.6; forward-player push=`clamp(((front−cam)/738−.5)*.4,0,.12)`. Desired speed=`.20*boostFactor*waveFactor+push`; actual speed approaches with dt/700, starts .20. Auto camera assigns want directly/camV0; normal waves never stop it. Player is clamped against pre-camera bounds, so left-edge pressure arrives next frame.

Seven 800px boosts start4884/10048/15435/20576/25619/30934/36237. Preserve all36 block tuples and14 low signs in JSON, including closely spaced wet signs. Trolleys `(19500,7,750,+1)` and `(31000,4,900,−1)`. Elapsed clock and “par 3:30” are HUD only, no time-gated loss or bonus. Receipts `(9000,312),(21000,312),(33000,312)`. Test each housemate crouch/standing/airborne geometry at all50 obstacles, acceleration when entering/leaving wave/boost, forced-camera Continue, and last wave at39262.

### 2-5: bakery, double-jump and flour

Stage1170–1229, shared flame/movement/pickup hooks. Six period2600 jets at1920/2440/2960/3480/4000/4520, offsets2200/640/1680/120/1160/2200. Seven period2200 jets at6320/6780/7240/7700/8160/8620/9080, offsets1000/180/1560/740/2120/1300/480. `noGrate=true` changes only drawing: flames appear from oven doors; gameplay warning/height unchanged.

Belts `[2000,2900,352,−.09],[3300,4400,352,−.09],[6400,7400,352,+.10],[7800,8900,232,−.08]`; rack platform7500–7700/top292. Double-jump card8850/232 before swing doors; receipt positions `(3350,352),(7600,292),(13600,370)`. Flour10800–12200/top482 multiplies normal base movement. Wet blocks12600 and14250, width62/height84. Wave7200 has **two security bots** (second at1800ms); don't collapse it to one mini-boss. Verify card reachable without possessing itself, persist/reload, then first fresh jump works next player update.

### 2-S: sunny shopping street, not a timed refrigerator game

Stage1170–1186. Nine non-colliding sample stalls at700+900*k (k0..8),22 coin rows, one split crate4500, two waves at2000/5200. Receipts `(2000,362),(5300,362),(8200,482)`. L is empty; there is no runtime LV.timer read, no countdown HUD, no fridge/treat spawn, no special timeout reward. Recommendation: retain executable distance/wave completion for initial port and make native copy truthful; do not silently activate the100s metadata timer. Any later timed redesign needs a separately recorded behavior decision/tests.

## 5. Checkout boss: dedicated puzzle state machine

Active code is `game/2-6/index.html:1200–1367` (`TB`, `L.readyEnd/update/shot/cpu/mid/hud`). `startBoss/updateBoss/bossDown`585–619 are copied **dormant Jar Thief** logic with no active start call. `TB` is not the global `boss`; no chase, stomp, health-threshold backup, double-damage dizzy, reflected-code attack or stock rain should be imported from comments/dead code.

### Entry, hit geometry and scanner

- At camera≥4160 with all three approach waves done, `L.readyEnd` creates TB once and always returns false, preventing normal timed exit. Camera lock4162. HP70 solo/90 pair, x4760; body BW250/BH340, left4635/top142. Enter state boots stationary for strictly>1400; first attack next1800 counts down only in fighting logic.
- Projectile rectangle strict x(4635,4885), y(122,482); screen means y<272, broader than painted screen. Entry/down reject hit consumption. Other states consume all intersecting shots even when invulnerable. Helpers have collision priority. **s.dmg is ignored** by TB; split and extra projectiles matter, arbitrary damage multipliers do not.
- Scanner randomly selects low y448 or high332. Warn900ms; harm strictly900<t<1450; end strictlyt>1600. Each completed beam increments beams even if it hit someone. Inter-beam delays1200/2600/2000 for phases1/2/3. Beam scans all living players x<4635 whose body contains its y (standing .86h/crouching .56h; lower boundary feet−4).
- Bag applies only when inv≤0, alive and not already bagged. Calls wrapped hurt then sets bag1500/vx0 **even when shield/slide/dash prevented health damage**. Bag loop deducts dt plus160 per global keydown/touchstart for every human bagged player; CPU only dt. It forces vx0 and lock≥60/hit animation. No separate carry speed multiplier, pickup key, throw key or bag movement wrapper exists.
- Final player barrier is x>4625→4595, but located at bottom of active update. It is skipped by entry/down/frozen/freeze-trigger returns. Do not turn art/body into an always-on solid without declaring the difference.

### Phase 2: deliver three separate boss crates

- Phase1 bullets do zero damage. Transition occurs on next update after third complete beam/no beam, not HP; set phase2/next1600 and drop3 crates. Boss crates are distinct from ordinary breakable power-up crates.
- Spawn kinds0/1/2, x=`clamp(livingPlayer.x−120+i*120,cam+60,4475)`, y=`viewTop−60−i*90`, gravity.0025, ground floor482. Falling crate has no damaging collision. Ground pickup only phase2, no bag/carried crate, |dx|<46, feet>422. Carry at `(player.x,feet−height−10)`; down/out/missing owner drops to ground and clears reference.
- Auto-throw when carrier x>4335; increment placed **at launch**. Flight650ms, linear path plus upward sin(πk)*160. Tray x4816–4935/y354; successive target bottoms `(4846,354),(4906,354),(4876,292)` (one is beyond world width4900; don't clamp it).
- When placed≥3 and no crate is flying, freeze5000, cancel beam. Frozen branch has no attacks/helpers. Shots deal2 body/3 screen. Before phase3, HP floor=`ceil(max*.3)`=21/27; hitting floor shortens frozen to1ms. Frozen expiry removes on-tray crates, placed0, next crate batch after1500 if still phase2. Phase3 threshold is checked **before** frozen decrement, so it normally occurs the frame after freeze expires.

### Phase 3, defeat and completion

- Enter phase3 when HP/max≤.3 and not frozen; discard non-on crates, clear carry refs, reset steps, cancel beam, next2500; immediate rush spawn on both sides. Receipt steps emit one per strictly>600ms (reset accumulator, no catch-up loop): `[4385,4475,412]`, `[4465,4555,347]`, `[4545,4635,282]`. They are live one-way surfaces for players/projectiles/items/skill queries.
- In phases≥2, non-frozen helper timer>11000 and active bot count<1 solo/<2 pair spawns one random-side rush/reset timer. At cap, timer keeps accumulating. Phase3's immediate pair ignores that cap and does not reset timer.
- Phase3 screen always3 damage; body independently has34% chance of1. Thus climbing stairs is intended but **not a mandatory clear prerequisite**. Bounce hint throttle900. Screen/frozen hits increment owner bossHits; random body hits do not.
- Defeat clears beam/codes/frozen; drops20 coins, ordinary-pops all live helpers (their coin drops still count), clears bags/carry/boss crates; keeps stairs. After down timer>1500 create jar `(4610,262)`, velocity(−.15,−.9), gravity.0024, floor452/bounce. Shared jar pickup requires horizontal distance<50 and age>600, **no vertical check**; only that triggers clear. Bank loose coins once, stop music, record legitimate2-6 clear and unlock actual next stage flow.
- Source CPU: high beam duck500–1500/no movement, low beam jump780–1000, fetch nearest ground crate/carry toward4375, then stepwise receipt climb; `L.targets` adds x4700. CPU/friend implementation is deferred only if clearly labelled, not replaced with solo-timer shortcuts.

**Ability compatibility:** injected `bossOn` tests global `boss`, which remains null for checkout. Auto-targeted boss specials (Ama stun, Maya boss aura, ball boss targeting, biased coin rain/ground pound) do not automatically recognize TB. Incidental physical/ghost shots may hit it through `L.shot` and receive the same fixed2/3/1 damage. A native generic boss interface must not accidentally grant new TB auto-targeting, stun or multiplied damage. Keep `codes` and `dizzy` out of active attack requirements: source never populates codes or activates dizzy.

**Fresh-run repair recommended, not source parity:** TB is set null only at declaration; no L.start resets it, and lvStart removes only gate surfaces, not receipt stairs. Native reset must explicitly clear TB, boss crates, mash count, bags/carry refs, receipt surfaces and all per-zone drop counters. Continue must retain encounter state. Test both operations separately and record the intentional replay bug fix.

## 6. Renderer and asset contracts

Use already imported `meta.imgs` resource keys. All six player sheets plus `bot` remain shared; `thief` is imported but dormant in W2. Never treat source painted backgrounds as full scene renders or hash filenames as semantic keys.

| Stage | Exact image keys | Active composition |
|---|---|---|
|2-1|`car-estate-0`, `car-estate-1`, `car-hatch-0`, `car-hatch-1`, `car-van-0`, `carpark`, `lamp`, `lamp-td-0`, `lamp-td-1`, `lamp-td-2`, `lift`, `shelter`, `topdeck`|`topDeck`1199: sky .05/town .2/deck1; restore cropped lamp heads with mirrored tile alignment. Surface frontage .3, entrance once at doors15580; scene-filter cars/shelters/lamps.|
|2-2|`aisle`, `freezer`, `strip`|`wallOf/islandArt/drawSky`1182–1198: ceiling crop0–.22 at.6, wall at1, aisle signs .8; island top246/lower364 must align with shelf art.|
|2-3|`glift`, `mezz`, `pallet`, `stockroom`|`drawSky/rackArt/stackArt/drawLevel`1186–1265: downstairs roof .3/wall .55; upstairs .6/.85/1, clipped rack rows, hoist opening and chained pallet art. `pallet` is imported but active pallet drawing uses procedural `blockArt`, not an assumed image call.|
|2-4|`aisle0`…`aisle5`|`painted`1062/`drawSky`1178: painting selected every3200px modulo6; floor factor.777, ceiling/signs, procedural speed lines; trolley rear→player at feet−30→clipped basket front.|
|2-5|`bakery`, `swing`, `table`, `wet`|`drawSky`1180 crop bands .4/.7/1; oven/rack/deli crops, elevated conveyor supports and bread animation, no floor grates, flour/wet signs.|
|2-6|`boss`, `checkout`, `crate0`, `crate1`, `crate2`|`tillArt/L.mid`1178/1287/1356: boss paint origin4565/132 inside390×360 canvas; logical body differs. Checkout crops0–.1/.1–.265/rest at.4/.7/1; last layer unmirrored so numbers read. Screen overlay/errors/tells, tray, steps/crates/bags.|
|2-S|`stall0`…`stall3`, `street`|`drawSky/drawLevel`1176–1184: street split at.855; shops .55, pavement1; nine stall paintings (noncolliding).|

Shared procedural keys/functions: `trolleyArt`, `boxArt`, `gateArt`, `signArt`, `blockArt`, `drawBelt`, `lvDrawBig`, `lvDrawBotExtra`, `drawPicks`; cached art has no imported resource for pressure pads, open gate countdown, drone propeller, stickers, hazard shadows, scanner warning or paper stairs. Hazard visuals are needed for playability, not postponed final polish.

Exact source draw order (`2-1:drawWorld`1380; `2-6`1455): sky (camera-y-aware) → translate world vertically → level art → ordinary crates → shared mid/picks/**L.mid** → items/coins → dormant generic boss → bots → jar → players with ability aura/trolley wrappers → shots/bills → effects/floating text → front → HUD/L.hud/banner. Checkout bags are drawn before players, scanner beam in front; render phase timestamps must match collision timers. Shared foreground helper is now **low bollards only** at canvas y≈494, not tall full-height pillars. Preserve low occlusion and mirror crops carefully.

Use a `supermarket_renderer.gd` with shared prop helpers and small stage painters (parking, shelves/stockroom, dash/bakery, checkout/bonus), or equivalent resources. Keep physics outside draw calls; source flour/trolley cosmetic particles consume random values during rendering, so use a separate cosmetic RNG in native and document that deterministic improvement. Runtime RNG seeds must not depend on screenshots/render count.

## 7. Grouped implementation work and acceptance tests

1. **Extract runtime contracts.** Registry + W1 adapter + collision provider + ordered combat seams + variant spawn input + shot interception + deferred W2 game-over/effects. Keep all W1 behavior/tests unchanged. Add data fixtures for seven counts, unit conversion, all image keys and byte-identical shared-source expectation. This is architecture, not a completed W2 level.
2. **Port supermarket base.** `world_two` foes, common projectiles/pickups/full-heal checkpoint/coin rows, normal end and scene transitions; parking painter/trolleys. Integrate **2-1**, all11 waves, lift, three receipts and actual clear. Test numeric spawn x, behind-start receipt, normal/CPU/pair schemas and wave concat order. No fake boss at exit.
3. **Port shelf/climb hazards.** Gates/plates/buttons/ice/drops/belts and aisle/stockroom painters; integrate **2-2 and2-3**. Test every gate and both button elevations, gate occupancy/collider threshold, preserved ice momentum, drop warning duration, all climbing surfaces/gap/fall recovery, 2-3 sceneLand0 and floor-specific landing. Normal source-order bot contact/projectile-before-late-move fixtures are essential.
4. **Port bakery and ride.** Flame phases/flour/block/low/boost/hazard renderers; integrate **2-5**, earn and persist double-jump, then **2-4** variable-speed trolley ride. Test six housemates at every flame/sign/block, crouch+jump/aim/fire/special combinations, speed zones/wave slowdown, no unwanted moving-deck semantics, continue in flight, and copied skill ownership. Add **2-S** painter/rows/legitimate distance-wave end with explicit dormant-timer policy.
5. **Port checkout puzzle.** Dedicated TB controller + renderer, dynamic stairs, crate carrying, bags/mash/input count, all three phases and actual jar collection; route ordinary/ghost shots through source collision order. Unit tests for exact thresholds + real main-scene controller run through all phases. Validate normal shots, all six specials, phase floor, error expiry/next-frame transition, helper caps, death dropping carry, shield-but-bagged, body-chip alternative, jar age/vertical quirk and exactly-once reward.
6. **Integrate progression and release QA.** Promote only passed stages in registry/save allowlist; update parity matrix/README and preview labels. Test W1→W2 continuation,2-6→next actual catalog destination,2-5 earned skill carried onward, fresh reset vs Continue, return-to-map, app pause/resume during wipe/beam/fly, stale callbacks and repeated clears. Co-op/CPU and real Android/iOS remain explicit outstanding work until implemented/verified.

Minimum regression/risk suite:

- Source fixtures preserve every wave group and co-op extras in order, hazard tuple count, receipt coordinate, geometry and authored coin total. Assert special-wave spawn failures don't wedge wave completion and hazards aren't invented wave blockers.
- Deterministic order tests: last bot dies this frame/end next frame; gate button hit opens collider only in late update; cart contact before late movement; new drone bill starts next frame; bubble reinsertion before shots; final-frame checkpoint may revive; spawned pickup waits next pickup pass; receipt stair appears after player physics.
- Reset fresh runs twice, switch worlds during wipe, pause >expected callback delay, resume, die/Continue during trolley/ice/drop/bag/carry/frozen/receipt phase. No stale TB, stair, zone accumulator, carrier reference or delayed callback reaches a new run. No world-specific W1 hooks leak into W2 or vice versa.
- Screenshot each scene start/transition, high gate button, stockroom highest tower/gap, every ride sign posture, flame tell/active ramp, card pickup, checkout low/high tell, all crate states/error/stairs/jar. Check graphic hit alignment and no tall foreground occlusion; headless parse/tests alone cannot certify it.
- Legitimate input-driven solo runs for all six housemates, actual authored objectives and all receipts/card. Debug teleport/invincibility/forced damage can isolate contracts but must be reported as such, never substitute for a real completion or difficulty validation. No synthetic clear/save tokens.

After implementation run `scripts/verify-native.sh` with new suites registered, then packed-runtime verification `scripts/verify-native-pack.sh` for the actual artifact. Existing W1 smoke/combat/rooftop/bus/street/Binman/ghost-order/skill tests remain mandatory. For this **documentation-only** audit, source equality/count checks were run; no new runtime test, export, deployment or gameplay completion is claimed.
