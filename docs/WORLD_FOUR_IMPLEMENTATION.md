# World 4 implementation contract: Holiday

Status: source audit and implementation plan, 2026-11-09. This document does **not** add native capabilities, change production code, establish a completed port, or claim a playthrough/device/visual parity pass. World 4 is **Arrivals, Old town steps, Sun loungers, Harbour chase, Pedalo panic, Captain Overcharge and the Splash park bonus**. Its executable mechanics, not a descriptive task label or old planning prose, define the contract.

The user requested the whole six-world game in a real engine, keeping the repository public for now. Preserve all 42 stages and their source content. This audit does not authorize a push, deployment, repository-visibility change, source replacement, membership change or store release.

## Evidence and first implementation slice

Read all seven `game/4-*/index.html` pages, their imported `godot/content/levels/4-*.json`, `game/polish.js`, the importer/manifest/catalogue, the W3 contract, and current native host/runtime/combat/ability/skill/campaign seams. All seven JSON objects equal their HTML `META` objects after excluding **only `imgs` values**, which the importer rewrites to content-addressed resource paths. Image key sets agree. `META.level`, top-level `txt`, `ground`, `dims`, `heights`, `heads` and `sheets` agree exactly. Opened all 71 image references with Pillow and confirmed their actual dimensions equal `META.dims`; this is file/shape verification, not a screenshot review.

Shared-code SHA-256, 1-based inclusive lines joined with LF **without trailing LF**:

| Range in every W4 page | Meaning | SHA-256 |
|---|---|---|
| 90–2229 | Shared game, W4 implementation, abilities and final fixes | `1efeec055e60e17f0b997dc26882abbd9eb02fd8f29741c116e988fccb7e131c` |
| 313–672 | Base geometry, player, bots, shots, pickups, frame loop | `7ff5758f838079b66ec796c76efda640ab5c0a77dc3eaa2eb174ba254e71619e` |
| 719–1380 | W4 config/rendering, runtime hooks, foes, objectives, Captain | `d139ad7846822aa53af591eb2a5568a85637be4f5f5e46cb3928e885b98da213` |
| 989–1087 | W4 object | `b6824685244f7ec85754327f384db709cf06952aa55bf3b9f086806abae03d0b` |
| 1667–2220 | Shared abilities and effective input/art fixes | `bd2ce386f5891a8d6f2cc38d7cc1a1ca68df7859000ca5de0d54a20a6fa54147` |

| Stage | Whole HTML SHA-256 |
|---|---|
| 4-1 | `99820722f31bb69cf38a73818085a0ccb13ca1d8b0cb79530e0ef2fafb011ed0` |
| 4-2 | `2b3e1fe73eedc12895686a92c10a506119531b3262179f42f5753080b185e898` |
| 4-3 | `d172149756c1b149434ed9353ff21d0182a59d2fc47bbabd9a065d24ad30e2ab` |
| 4-4 | `cebd3b235d147cb7b3ecaf5bd5bb7e49bb4c8845ee97f861d0fe46aab76dcadd` |
| 4-5 | `b3ab28d7affc342d61b5a03ac13e33cf204c91a77d53646f687a323dd046b4c5` |
| 4-6 | `1b803d79348efb66e05ed4fa8290effc27257093828cab6fc526d752982052df` |
| 4-S | `eed4c4412983370137871437c36fa088b415951c9cb6caec144ae6e45e0d363e` |

Across the common 2249-line prefix, only lines4 (title),53 (META),89 (SRC),2230 (flow ID),2249 (save/story bridge) differ. 4-1/4-3/4-6 have story tails through2263; the others end2249. All HTML anchors below refer to 4-1 unless stated otherwise. Do not print the enormous base64 META/SRC lines; parse their JSON and inspect selected keys.

**First playable milestone: 4-1 only.** Required: immutable live surfaces and all four conveyors; 12 waves/60 solo entries; nine fixed suitcase ambushes plus seven wave cases; fourteen warned chute drops plus four wave drops; 34/46-HP Bailiff; lift/checkpoint; all four crates and three receipts; faithful airport panels/floors/carousels; six characters with existing powers/skills; true distance + all waves + all set pieces + no blocking foes + delayed exit; pause/Continue/replay/save/story. A level-shaped scene with generic robots and an end trigger is not that milestone.

## 1. Data, coordinate and API boundary

- `VW=960`, `VH=540`, `ZOOM=1.3`, `WV=round(960/1.3)=738`, `GROUND=482`. Source player `y` is **feet relative to GROUND**; foe `y`, bot `fy`, surfaces, pickups and shots use absolute world y. Native `host.player.y` is absolute feet.
- Source clocks are milliseconds, speeds px/ms, acceleration px/ms². Native clocks seconds, speeds px/s, acceleration px/s². Multiply speeds by1000, acceleration by1,000,000; divide durations by1000. Preserve a 34ms maximum simulation step, exact `<`/`>` distinctions and pair-count branches.
- All stage data is `META.level`; W4 text is **top-level `META.txt`**, not W2 `text` or W3 `l3.txt`. `CFG=level.cfg`. `level.top` in4-2 is not a camera/physics limit in this executable code.
- Solids `[x0,x1,top,nobot?]`; the fourth slot is converted with JavaScript boolean coercion, **not W3's properties dictionary**. Platforms `[x0,x1,top]` are one-way. Solids extend downward indefinitely even when their artwork uses a finite `bottom`, `hide`, boat or jetty style. Construct solids then platforms in source order, preserving stable identities. A `nobot` solid still blocks players and shots.
- Styles `[x0,x1,properties]` apply to the first matching **solid**. Belts `[x0,x1,top,speed]` match the first platform on all three coordinates, attach `belt` and `nobot=true`. Bobs `[x0,x1,amplitude,imageKey]` match solid endpoints, set `bob0`, `style='boat'`, `col=imageKey`, phase=`x0/97`. `CFG.ground` applies `st` to overlapping ordinary ground solids lacking style/hide, without clipping their span.
- `level.waves=[{at,g:[[delay,side,type],...],x2:[...]}]`. Pair mode appends **x2**, never W2's `x`; W3's fourth entry flag is not applicable. `side` is r/l, and the **type** selects W4 foe spawn. Numeric/tent/carrier/fly side adapters from other worlds are not needed.
- `level.scenes=[{x,sky,layers,back?,fg?,waterCol?}]`; scene is the last with `cameraX>=x−1`, not viewport center or gate destination. Layers retain img/fill/f/y/yf/mirror/drift/alpha/sea/smooth/etc. Panels `[key,x,top,flip,clip?,parallax?,sceneIndex?]`; ordinary decor/front `[key,x,top,flip]`.
- Gates `[ {x,to,kind,label} ]` are independent of scene indices. Hidden very tall solids in4-1/2/3 enforce their gate boundaries; retain their collision and `nobot` flag, do not turn them into decoration.
- Receipts `[x,y]` use an authored vertical reference with artwork at `y−60`, not W3's draw centers. Card `[x,y]` always grants dash here. Crates `[x,y,give]` use `below(x,y).top`, not necessarily the authored y or nearest visually drawn shelf.
- `CFG.sets=[{id,kind,at,n?,gap?,after?}]`; mark each id before spawning. `after` means all waves whose at≤set.at are done. No actual W4 set has `after`, but preserve the schema. Failed set spawn still marks it done.
- `CFG.hold={cam,time,towels:[x...]}`; `CFG.dash={time,gates:[x...],coins:[[x,y]...]}`. A dash bonus gate is a clock pickup, not a wipe gate. `CFG.deck={off,w,top}` creates a **new solid** marked dynamic/nobot/hide; deckLine is a drawing anchor only.

### Recommended modules and host seams

Use a **distinct family4 dispatch**, not `_native_world_three()` aliases. Names below are proposed, not implemented.

- `world_four.gd`: reset/invalidate, immutable copied surface identities, geometry queries, `pre_motion(dt,host)`, camera override, gate/checkpoint lifecycle, set-piece order, finds, ending and guarded wipe callback; own live run timers and stage snapshots. Reuse tested geometry/wipe helpers by composition only when their semantics agree.
- `holiday_combat.gd`: W4 ordered wave factory, ordinary bots/hops, player shots/hostile bills, coins/crates/items, bubble integration. Export phases `waves_tick`, `enemies_tick`, `projectiles_tick`, `pickups_tick`, `boss_tick`, `jar_tick`; never conceal the world pre-combat update inside `enemies_tick`.
- `holiday_foes.gd`: ordered separate foe list and registry. Methods `spawn_if_known(side,type)->bool`, `tick`, `busy`, `pause_camera(auto)`, `intercept_shot(shot,old_x)->bool`, `cpu_targets`, `start_set`. Foes **must not be placed in ordinary host.enemies merely to reuse abilities**: that changes homing, bubbles, slide, pound, CPU crowd counts, wave blockers and shot priority.
- Isolated foe/controller modules: luggage/cases/chute, bailiff, melon controller, water foes/banana, towel-hold and Captain. Pure painters use those snapshots, not cross-world enemy-kind guesses.
- Renderer layer seams `draw_sky`, `draw_level`, `draw_boss`, `draw_bot`, `draw_foes`, `draw_jar`, `draw_player_back/front`, `draw_front`, `draw_hud`; commands must not mutate runtime or consume combat RNG.
- Surface object at least `{row,plat,nobot,style,belt,bob,bob0,phase,col,bottom,hide,dynamic,...}` with current rows used by **all** player/bot/spawn/shot/ability/collision/draw paths. A copied bot segment array breaks bob carry; reference the live surface.
- Separate kitty and personal coin accounting. A receipt, towel award or time bonus increases kitty only; physical coins increase both. Existing single-host score must not silently imply these are personal coins in a later co-op HUD.
- Host main should supply source-aware actor access, source-ability ghosts, callback generation guard, proper text dispatch, early world-owned dash and family-specific boss ability compatibility. Do not give Captain a synthetic `fy` without deciding the source bug in §10.

Current native facts, inspected 2026-11-09: `main.gd:343–429` dispatches W1/W2/W3 and initializes their pickups; `591–767` has W3 carry **after horizontal movement**, shared W2/W3 waves→bots→shots→pickups and late world updates; `900–906` performs W2/W3 passive nudges; `977–999` only knows W2/W3 auto policies. W4 needs changes at all those seams. `movement_skills.gd:late_step/_dash` already knows W4's own dash values but main currently calls late_step **after combat**, too late for W4. Its4-4 card geometry is already correct, which is not evidence the stage works. `native_levels.gd` has no family4; do not register unimplemented stages. The audit did not change any of these files.

## 2. Exact frame order, including abilities

Sources: `updatePlay`630–671, W4 object989–1087, base player407–445, ability wrappers1933–1979, final wrapper2178–2191.

1. Increment `levelT`, then **W4.pre**. Move bobbing boats/deck and carry players/bots before CPU input and base physics. Perform pedalo CPU clamp/splash rescue, then clamp persistent bonus-coin age.
2. CPU inputs; for each player snapshot ability pre-state, base update, ability/passive/skill post-hook, final aim pose. Base expiry→revive/down→hurt lock→crouch/face→horizontal move+knockback→wall/old-camera clamp→ordinary drop/jump→support/gravity/landing/fall→safe position→fire/animation. No W3 mud/tie multiplier, carry after horizontal motion, wellies or squash hook.
3. Horizontal camera hook: active global wipe freezes it; then gate policy; then automatic scroll or mini/hold/boss locks; otherwise ordinary monotone follow. Vertical follow still runs independently. There is **no 1800ms auto warm-up**. Auto can move on the final lethal base frame before global all-down detection.
4. Waves start and consume entries; then objective predicate and ending countdown. Wave completion sees bots/foes from before this frame's next phase. `endT` starts1ms, immediately adds dt, clear at **>2600ms**.
5. **W4.update before ordinary combat**, in this order: camera checkpoint heal → one-shot set triggers → receipts/card → own Dash → towel hold → bonus clock → ordered foe updates and cleanup → final Captain start.
6. Ordinary bot update, removing bubbled live bots for the base pass and reinserting afterward. Then all player shots: homing/move → **custom foes in insertion order** → Captain → ordinary bots → legacy non-W4 boss (not an authored W4 encounter) → crates → solid cleanup/cull. Then hostile bills. Then ordinary coins and items.
7. Boss tick after pickups (Captain or unused legacy boss), then jar gravity/pickup/clear; decrement Go; resolve all-down only if still play.
8. Unconditional ability effect/football and ghost-age wrapper after the base play function, even if that function cleared/knocked out. New football ghosts usually collide next frame; passive/slide/pound ghosts created before combat collide this frame.
9. Render, then polish wipe callback. Native can put a guarded callback after this entire step; never place it before shots or inside camera advance. Pause/over callback freezing is a declared reliability correction, not the source's wall-clock behavior.

Important consequences:

- A case opened by proximity in W4.update creates a bot that receives AI that same frame. A case opened by a shot creates a bot **after** AI, but later shots in that pass can hit it. Its opening shot is consumed; it cannot also hit the new bot.
- Chute, towel, jet/banana and set-piece bills created in W4.update move/hit this frame. Captain bills and helpers are created after projectile/pickup passes; their ordinary update starts next frame. Captain waves created in its state branch are likewise first advanced next boss tick.
- JavaScript `for...of foes` visits appended entries. A newly appended drop/melon from a controller receives its first update in the same pass. Use an indexed live-list loop if porting directly; iterating `foes.duplicate()` changes timings.
- Checkpoint/hold/bonus effects happen **after waves/objective evaluation**. H.over/D.over becomes an ending on the following frame. Their newly spawned/dead foes are still processed in the current W4 update.
- A clear initiated by the early end countdown does not return from the original base function: W4.update, combat, boss/jar and effects still run, though damage checks require play. Decide and document any native early-return cleanup instead of claiming exact final-frame parity.

## 3. Player, surfaces, camera, checkpoint and gates

### Geometry and movement

Source313–387,407–445,1010–1028. Highest crossed top wins with inclusive x, top≥oldFeet−1 and top≤newFeet+.5; `below` requires top≥queryY−2. Wall crossing ignores platforms/top≥feet−6 and holds14px from the crossed side. Inside-wall requires strict x bounds and y>top+4. Safe position updates only on ordinary solids with x strictly90px inside ends; boats count as solids despite nobot. All queries must use current bob/deck geometry.

Walk `.27`px/ms; ordinary jump−.98; gravity.0033, terminal1.5. Platform Down+freshJump gives vy.12/drop260ms. There is no W3 nodrop rule. Normal/split firing210/260ms; shot speed.78. Damage one heart, inv1500ms, lock420ms, knockback±.35 with `.992^dt` damping (zero at |vx|<.01). Revive within80px x/70px relative feet, cumulative1400ms, loses progress at.5×dt when unattended; restored hearts2/inv2200/celebration lock600. Power expiry and inv decay run even for down players before their return.

W4.pre iterates every live surface **in array order**:

- Deck: desired x=old camera+off, shift endpoints by dx; top=`deck.top+sin(levelT/420)*4`. Thus this frame's camera advance is reflected in the deck **next frame**, unlike W3's late camDX trailer.
- Bob: top=`bob0+sin(levelT/520+x0/97)*amplitude`, dy=current−previous.4-4 all amplitudes8. Source tests truthiness of bob, not existence.
- Grounded living player in old x span with tolerance1 and |feet−oldTop|<4 gets x+=dx+belt*dt; sets px=x; feet=newTop. No saved surface is required. This happens before base movement/wall clamp. Multiple matching overlapping surfaces may carry in sequence.
- Bots whose segment **is** this surface receive x+=dx/fy=newTop whenever dx or dy, including popped/bubbled/hopping bots. Belts alone do not carry bots. Do not import W3's skip-hop/pop and truthy-dx-only bot carry.
- No general item/crate/coin transport. A crate planted on a surface resolves its floor once at reset.
- Pedalo CPU grounded clamp to deck±30 precedes ordinary CPU motion. Living feet>water+20 rescue to deck center+(slot?40:−40), onG=true/onPlat=false/vy0, inv=0, ordinary hurt, vx0, Splash effects. Base player update then reduces any newly applied timers in this same frame. Normal fall check still exists later; do not replace it with this water rule in4-4.

Ordinary fall recovery starts safe.x clamped camera+70..camera+WV−70, searches up to60 rightward candidates20px apart for below(viewTop−200), requiring30px inside surface and x<camera+WV−40. Fallback below(x,−9999) or first surface. Places on surface, vy0/inv0, hurts normally, vx0. It does not rewind waves, gate or checkpoint.4-4 fall line618,4-5 fall576; water art is not an extra collision plane.

### Camera

Source634–650,781–787,1029–1045. Follow human players (`!cpu&&!remote&&!out`, without filtering their down flag); fall back to alive if no humans. Ordinary desired camera=max(current,min(front−WV*.45,back−60)), then lock and world−WV caps. Target speed≤.42, acceleration limit.0012 per ms, easing diff/240. Never reverse except explicit gate relocation.

Vertical remembers each camera participant's grounded/max falling feet; sample=min(remembered,feet+170), average extrema−GROUND+30 with source min/max bounds, target≤0, lerp min(1,dt/260). Keep this on steep4-2 descent/ascent and after its gate; gate does not reset camY or grounded-history state.

`BD.wiping` freezes horizontal camera **for all W4 stages** but not players/combat/timers/vertical follow. Gate busy also freezes horizontal. Auto advances `LV.auto*dt` only while play and no endT, except any live pause foe with state≠out reduces speed to0.4-4=.17,4-5=.15. No W3 levelT warm-up and no W3 camera-clamp squash recovery. Mini pause is checked after gate policy and before ordinary follow. It pins lock=min(existing,cam), hz.lock=true; once absent clears lock only if no active wave. H.on freezes horizontal outright; before it begins cap at hold.cam. CFG.boss initially caps at world−WV but is not an immediate boss start.

### Gates and checkpoint

Sources767–787,1047–1058. See exact gate inventories in §7.

- Normal gate caps camera at gate.x+40−WV. Trigger when front camera participant x>gate.x−150, **no started unfinished wave**, `!W4.busy()`, and no live `pause` foe. Ordinary non-wave bots are not checked separately. Automatic gate triggers cam≥gate.x−WV−4 **before** doing that frame's auto advance, ignoring wave/foe busy.
- Trigger sets busy, starts power sound and source wipe. On midpoint: passed=true/busy=false; bots/shots/bills cleared; foes retains only types with `ctl` (including any such dead controller); cam=to−(auto?40:60), camV=0, lock=null. Deck shifts immediately to new camera+off; it is not re-created.
- Relocate every player to deck.left+120+slot90 or to+140+slot90; feet=deck.top or below(newX,GROUND−2000).top, fallbackGROUND. Set x/px, vy/vx0, grounded=true, **onPlat=false unconditionally**, safe updated. Down players revive and get inv2000; all hearts3. Living players do **not** automatically receive invincibility or lose hurt lock. Set hz.check=true and checkpoint banner.
- Keep coins/items/crates/receipt progress, levelT, waves and setDone. Skipped-at waves are not forcibly marked done; they start next update. Preserve controllers instead of silently canceling their remaining drops.
- Camera checkpoint requires truthy CFG.check, !hz.check and cam≥check; all hearts3, revive down with inv2000, but no teleport/inv refresh for already living players. A gate sets the same check flag, so may suppress a later scalar checkpoint.4-4 check19744 follows set19508; auto pauses for Bailiff before reaching the checkpoint.
- Wipes use polish.js103–166: close520ms, label hold1050, callback1430, open1570, finish2170; cubic easing, focus clamped22–78% viewport width. lift/stairs/door/iris all use the same soft iris; fade is uniform. No separate instant elevator animation.
- Continue after all-down restores all players hearts3/inv2500 **in place** and keeps camera, timers, towels, boss/foes, waves, bonus multiplier, surfaces and pickups. Fresh replay must fully rebuild/reset them. Preserve original gates/style coordinates, including hidden sentinels.

## 4. Waves, ordinary bots, shots, money and pickups

### Wave and ordinary bot contracts

Sources362–372,479–556,652–663,926–935.

Waves start when cam≥at−2, lock=null for auto or cam+40 for normal. Add dt and dispatch while the **next authored** entry is due, never sort. Pair/CPU mate appends x2. Pair extras in4-2 at4390/11718 with delay3000 wait behind base3900; four4-4 groups have extra2000 behind base2200. Failed placement consumes entry. Complete after all dispatched and either auto, or no non-pop ordinary bots **and** !W4.busy. Completion unconditionally clears camLock; normal Go2200, auto no new Go. This may temporarily clear a mini lock until camera restores it next frame; do not force W3's boss-protected lock policy.

Ordinary spawn first delegates recognized types to W4. Otherwise search up to50 positions24px inward from camera±70 beyond screen. Eligible surface **solid only**, !nobot, width>200, candidate strictly30px inside, top between(viewTop+120,camY+600). Choose closest to average living feet. W3 accepts wide platforms/nospawn flags; W4 does not. No candidate means no ordinary bot.

Rush HP3/speed.11×(.9+random*.25)/stop0; throw/flat HP4/speed.075×same/stop230–400; initial cd900–1800, t0–400. mkBot used by cases starts entered=true, face−1; normal spawn does not. Unentered walks inward≥.1; entered when between camera+50 and camera+WV−50. Pursue past stop+10, retreat.6×speed when within stop−80. Throw released at220ms, finishes440ms, next cd1400–2800. Flat from feet−128/vxface*.42/g0; arc from feet−100/vxclamp(dx/900,±.5),vy−.78,g.0017.

Hops: existing hop skips AI and contact, interpolate duration520+distance*1.2 with sin arc70+max(0,oldFeet−newFeet)*.6. New hop when entered/walking, target distance>30, within26 of segment edge; adjacent nonplatform solid width>200, |height difference|<230, gap<230; land40px inside. **Hop candidates do not test nobot.** Newly started hop still reaches that frame's contact check. Without hop clamp to segment±22; entered screen clamp±40 happens earlier. Contact |dx|<44, feet in(botFeet−95,botFeet+24). Nonentered wait>6000 retires; pop gone>1300 removes; cull outside camera±400. No W3 12-second age/hitAge retirement, daze, tent rise, wellies stomp, ride/fly hook or W2 embedded-solid repair.

Pop drops4–6 coins, credits personal pops when owner supplied. No rewards for retirement/cull. Keep ordinary enemy order through bubble removal/reinsertion.

### Projectile precedence

Player shots first adjust debit homing toward nearest ordinary non-pop bot only if it is ahead in vx direction; vy acceleration.0012 clamped±.3. No custom foe/Captain homing. Move first; first-frame sweep x starts owner.x, otherwise prior shot.x. W4 intercept sees moved y and full horizontal sweep before anything else.

1. Custom foes in insertion order with hit handlers; controller/drop have none. First hit consumes shot and stops. Dead foes ignored.
2. Captain if live/not enter/down, swept body test; fixed1 or valve3, independent of shot damage.
3. Ordinary bot sweep x±34, new y strictly feet−112..feet; subtract s.dmg, flash90, shove6 in sign(vx or+.001), pop if≤0.
4. Legacy non-W4 boss branch exists but is not an authored W4 encounter.
5. Crate nonswept |dx|<34, y strictly feet−70..feet; subtract1 regardless damage, hit120, break at0.
6. Solid insideWall cleanup, then camera±40/viewTop−60..camY+580 cull.

Hostile bills update gravity→position→t, living-player tests |dx|<26 and y between feet−height*(crouch?.56:.86) and feet. It may hurt both players in one pass even after dead=true. No W3 tie effect. `big` is only artwork, not collision size. Descending offset6 surface/insideWall/fall cleanup, camera±60 cull. W4 helper `bill` uses vxclamp((targetX−x)/950,±.55), vy−.72−random*.1,g.0016; its ty argument is unused. Use source priority even for invisible ability zaps, not direct HP subtraction.

### Crates, drops, coins and finds

Crates HP3; break spawns item at feet−40, vy−.6. Item gravity.002/support offset26, age>300 and horizontal distance<40 collects **without a vertical test**. Heart +1 capped3; split/debit12000ms. No source item lifetime, despite blinking after9000. No W4 wellies crates.

Coins gravity.0024/support offset8, bounce−.45/vx*.7 until |vy|≤.15. At age>250, attract within110x/150y by up to.5*dt; collect within30x/height*.6 y, +1 personal/+1 kitty. Cull dead, age≥11000 or x≤cam−60. Bonus coins have keep=true and pre-motion caps age at5000; behind-camera culling still applies. This is not W3 stay=true behavior.

`updatePicks`952–962 before foe AI: living |dx|<42, feet>authoredY−120 and feet−height<authoredY, strict. Receipts persist source IDs1..3 immediately and kitty+=5, **no personal coins**. Every replay starts got=false even if saved; saved list deduplicates but £5 is repeatable each run. Unlike W3 there is no previously-collected alpha policy. Artwork center=(x,y−60+sin(levelT/200+x)*4); picked fades600ms then disappears. A newly picked item's t stays0 through this update. Card same collision, dash grant/banner/event. Native save can retain zero-based indices with one boundary adapter.

`stageClear`622–627 sweeps **all remaining coins**, including offscreen kept bonus coins, credits nearest living participant or player0, empties coins, revives down with one heart, emits one clear event carrying kitty. Normal completion does not require all receipts or crates. Do not add either to unlock criteria.

## 5. Custom foes and set pieces

Sources1091–1251. Foes are a separate list, not ordinary bot subclasses. `W4.busy` means live type.blocks and (type.ctl OR x within camera−250..camera+WV+250). `pause` affects camera/gates independently. `FOES.banana.blocksFn=true` is **unused**; busy never consults f.blocking. `foeDie` sets dead/dieT0, pop/bits at y−h*.6, drops `coins||4` (zero falls back4) at min(y,coinY||y)−60 and credits pops. Generic cleanup removes dead after>900ms or gone; no generic offscreen cull. Type-specific disappearance is important.

### Cases and luggage chute (4-1)

- Fixed cases: cfg.cases x/type, floor below(x,GROUND−400), HP2/h70/w34/t0/flip=x%2. Wave case spawn inside viewport at camera+(right?WV−90−random120:90+random120), floor below(x,viewTop+100); random rush/throw and flip. Both type.blocks=true.
- Proximity opens at |dx|<230 and |feet−caseY|<80. Shot sweep halfwidth34/y−70..y subtracts **1 regardless shot damage**, flashes90, opens at0. Opening marks case dead, bits/Surprise, creates entered ordinary bot at below(x,y−4), face−1. No case-opening coins or pop-credit. Opening does not hurt by itself.
- `drop` has no hit handler and does not block. Target nearest screen center or player0; x=clamp(playerX+(random−.4)*240,cam+60,cam+WV−60); floor below(x,viewTop). Starts viewTop−80, fall dur1100. Its y recalculates from **current** viewTop every tick with k²; not a stored launch y. At landing once: stomp/shadow/contact halfwidth50, vertical [floor−70,floor+4]. It does not contact during descent. After land age>500: dead, bits, one coin, no pop credit. Draw shadow only state fall.
- Chute controller blocks=true/ctl=true, invisible, n=sp.n||14/gap=sp.gap||900; next starts0. Per tick next−=dt; if≤0 and n>0 spawn **one** drop, n--, next=gap*(.7+random*.6), no catch-up loop. Gone when n≤0 and no live drop.4-1 uses14/gap800; last landed suitcase must finish its500ms retirement before controller stops blocking.

### Bailiff miniboss (4-1,4-2,4-3 hold,4-4,4-6)

- blocks=true/pause=true, not `host.boss`. Samples visible fractions[.6,.5,.75,.35], below(viewTop+100); reject platform; choose largest visible overlap>300 between surface and camera+90..camera+WV−90. Spawn right min(cam+WV+120,seg.right−70), left max(cam−120,seg.left+70). HP34 solo/46 pair, h200, cd1800, coins14.
- Enter at face*.12 until within camera±120. Walking faces nearest, moves.06 if distance>160, decrements cd, then equally random stomp/throw. Once action t>330 releases one attack; t>700 returns walk with cd1300–2300. Throw three big bills from x+face50,y−230 aimed player.x±110. Stomp two waves at x±70/vx±.4. Clamp entered to camera±80 then segment±60; fallback entered test camera±60.
- Waves advance **same foe tick they are created**, contact |dx|<24 and |playerFeet−foeY|<20; camera±60 cull. Body contact halfwidth66 with vertical overlap y−200..y+10. Shot swept halfwidth70/y−210..y, subtract s.dmg. No armor reduction despite prose saying armoured; no dizzy or health thresholds. Dead stops all updates, so existing waves stop collision immediately although painter may draw them through its fade.
- Actual art is `bot` sheet scaled1.75 plus source plates/cap,120px health bar, death fade600ms; not W3 Bailiff boss or Jar Thief. This same actor is the half-time towel miniboss.

### Melons (4-2)

Spawn right cam+WV+40, floor below(viewTop−400), fallback sample at cam+WV−40 but **keep original x**. HP1, y=floor, vx−(.2+random*.08), onG=true, coins2. Gravity.003 terminal1.4; vertical landing before horizontal motion, bounce−.35 if incoming vy>.4 else settle. Ground support feet±2; leave with vy.05. WallClamp reflects vx when movement clipped. Contact halfwidth34/y−52..y; shot halfwidth30/y−56..y; gone x<cam−100 or y>fall. Not a normal wave blocker.

Melons controller blocks=true/ctl=true, n=sp.n||12; first next0, then700–1600ms, at most one spawn per tick. Gone only after n exhausted and **no melon of any dead/live state remains**. Dead melon remains900ms; this differs from chute's !dead test.4-2 has14 controller melons plus four wave melons. Melons use procedural rotating green26px circle/stripes, not missing sprite art.

### Jet skis, inflatables and banana boat (4-4/4-5/4-6)

- Jet: blocks=true, HP3, coins5, y=jetY||water+18, start cam+WV+140 or cam−140; life16000–22000, cd1400–2300, screen slot. Without deck slot120+random*(WV−240); with deck choose side50%: left50+random*max(10,off−120) or right off+w+70+random*max(10,WV−off−w−120).4-5 right slot can be beyond the viewport; preserve rather than silently clamping onto the deck.
- Jet tracks slot with clamp((cam+slot−x)/300,±.5)*dt, faces nearest. Retarget probability **.003 per frame**, not dt/constant. Fires only inside strict screen bounds and cd≤0; resets1600–3000, throwT400, bill from x+face30,y−100. Life expiry exits.5 toward spawn side and gone beyond±200; lifetime retirement is not a kill/reward. No jet contact damage. Shot halfwidth60/y−120..y+10. Spray probability.08 per frame is cosmetic.
- Ring type selects available `fl-ring/duck/croc/unicorn`; none in4-6, so uses procedural ring fallback. Starts beyond±80, HP2/coins2/vx signed(.16–.24), feet at dynamic deck.top orGROUND. Move `(vx+LV.auto||equivalent)*dt`: source literally `(f.vx+(LV.auto||0))*dt`. Even if auto camera pauses, this extra auto speed remains. With deck feet=top−4−abs(sin(t/220))*10; no deck keeps initial feet. Contact halfwidth38/y−60..y; shot44/y−70..y. Gone camera±150. Rings do not block waves or camera.
- Banana: blocks=true/pause=true, source procedural440px hull with **four independent seats offsets−150,−50,50,150, each HP3**. No shared HP. Starts cam+WV+300, y=water+16. Enter toward camera+WV*.62 via max(−.4,(target−x)/400)*dt; within6 becomes fight. Fight x=target+sin(t/1400)*120. Seat cd initially1000–3000 then2200–4000, each throws bill from seatX−20/y−140 while fight, throwT400. Body has **no contact damage**.
- Seat shot swept width34/y−150..y−20 subtract s.dmg; dead seat drops4 coins and owner pop. When all seats dead during fight set out, drop10 extra coins, keep dead=false. Out moves+.6 until gone beyond cam+WV+500. Auto camera resumes because pause test excludes state out; `busy` still counts it while in extended bounds because f.blocking/blocksFn are ignored. Do not accidentally gate ride end on an empty but indefinitely retained banana.
- Source banana seat flash decays by16 **during draw**; move it to time-based visual update and declare the rendering correction. Render uses ordinary bot sheet for seated robots. No banana artwork asset exists.

### Towel grabbers and hold (4-3)

Grab blocks=true, HP3/coins4, floor below(screen center,viewTop+100), spawn outside±60, picks random free towel (!gone&&!held), speed.12. If target invalid/gone/held by another, choose nearest free; no target exits toward spawn side at.12 beyond±80. Within8 grabs, records mutual held/carry pointers. Carry speed.1 toward spawn side; crossing±60 marks towel.gone, clears held, gone foe, warning. Body contact40/y−100..y+10; shot36/y−112..y. A shot kill while carrying clears held, sets towel.back600, Saved text; generic foeDie alone does **not** release a towel, so hold-end explicitly does it. Do not copy grabbers into ordinary bot AI.

Hold activates cam≥hold.cam−2 **and every authored wave done**, resets clock150000; freezes camera. Four towels, next1500, alternating side state0→1 (first right). Each tick decrement clock/next/back; progress k=1−left/time. Once k>.5 spawn Bailiff (one attempted spawn per run, H.mini stays set even if towels reset). While left>3000 and next≤0: next=(2300−k*1100)*(pair?.8:1)*(.8+random*.4), choose grab50%/rush20%/throw15%/flat15%; at k>.5 additional opposite-side grab30%. Do not spawn ordinary wave objects for these.

If **all towels gone**, resets++, left=min(150000,left+40000), restore towel gone/held flags, mark all grabbers dead/dieT0 **without coins**, banner. This is not game over; remaining HP/ordinary bots/Bailiff are unchanged. It runs before left≤0 ending, so a simultaneous all-gone/timeout can extend instead of finish. At left≤0 set over, pop all live ordinary bots, foeDie all live hit-capable foes, release any carries, kitty+=10*count(!gone). A held towel still counts as not gone and is restored before display. Clear enters standard ending on next frame; no requirement to beat Bailiff first. Dying to contact and Continue retains the clock/towels, rather than starting another150 seconds.

## 6. Splash park bonus and Captain finale

### 4-S bonus

Source1007–1008,1026,1294–1303. Begins immediately at reset with100000ms; no start delay/auto-scroll. All258 authored coins spawn immediately at exact JSON coordinates, rest=true/t400/keep=true. There are183 base undulating positions plus75 high step coins. Preserve them, do not generate an approximate row.

Each world update left−=dt, then for each not-got gate any player's x>gate.x grants8000ms and increments multiplier (starts1; max9). It tests **all players**, not alive-only; several gates can fire in one tick. Clock ending then tests left≤0 OR any player's x>world−160=22688; set over; bonus=max(0,Math.round(left/1000))*mult added to kitty only; pop every live ordinary bot. D.over freezes clock; no repeat award. It does not call stageClear immediately or demand all waves/receipts/coins. W4.done sees D.over next frame and begins2.6s ending. Pending wave entries can still dispatch during ending because waves keep ticking.

`Math.round` half behavior for nonnegative remaining time must be matched. Eight time gates at2600,5200,7800,10400,13000,15600,18200,20800. The HUD calls this “Partner bonus xN”; source has no clickthrough checkout/integration and no partner ad logic to invent.

Source clear sweeps all kept future coins, including coins never approached after a timeout. A normal-path late clear therefore awards remaining not-behind-camera coins. This is an observable source scoring quirk, not proof that every coin was physically collected. Tests must distinguish collected, culled and clear-swept.

### 4-6 Captain Overcharge

Source1305–1379. Final start requires CFG.boss, no boss, cam≥world−WV−2 and **all waves done**; set to camLock=4974, x5972, y522, HP90 solo/120 pair, enter/t0, next1800, phase1, sink0/called{}, aimX0. It is not W3 Tout, W3 Bailiff or the legacy W1 boss. Entrance .25 left until x≤R−120, where L=5094,R=5602. Unconditional x clamp[L−40,R+300] snaps initial x5972 to5902 on first tick if still above that bound. Preserve enter immunity.

- Boss shot swept rectangle: s=1−sink*.35; x∈(boss.x−150s,boss.x+120s), y∈(boss.y−330s,boss.y−20). Normal subtract **1 ignoring projectile damage**. Phase3 only, final moved shot endpoint within strict60x/60y of valve=(x+70*(face<0?1:−1),y−120) subtract3. Passing through valve in a long sweep without endpoint near it is not triple damage. Do not enlarge/recenter hitbox from rendered bob/rear rotation, and do not bypass custom-foe priority.
- t and flash tick; shockwaves move first and hit |dx|<26, **player relative y>−30** (absolute feet>452), no grounded requirement. Cull [L−200,R+200]. `dizzy` exists but Captain neither decrements nor acts on it, and shot damage does not double.
- HP fraction phase uses >.66=>1, >.33=>2, otherwise3. Threshold transitions occur in late boss tick, so all shots in one projectile pass use the old phase. HP helper triggers separately <.8 right jet, <.5 left jet+right ring, <.25 right jet plus left jet in pair. Multiple thresholds may trigger together. No ordinary robot health backup groups.
- Drift faces nearest, target=R−150+sin(t/1500)*140, x approaches clamp(error/500,±.08). t>next chooses rear if phase≥2 and random<.4, else throw; t0/firedfalse. Throw t>380 emits3 bills phase1/4 later, all big from(x−60,y−300), target spread120 centered on player, W4 `bill` trajectory. t>900 returns drift,next=(phase3?1000:1500)+random1000.
- Rear t>700 enters charge, direction from which arena half boss occupies (not player position), speed.55. At x<L+60 for left or x>R−60 for right returns drift/t0/next1400 and emits **one** wave at x−dir30 travelling−dir*.4. Newly created wave moves next tick. Charge body contact only: |playerX−(bossX+dir60)|<60 and feet>GROUND−120=362. On boundary tick state already changed to drift, hence no charge contact. No body damage while enter/drift/throw/rear.
- `aimX=boss.x−20` is assigned at start of tick before movement; CPU shoots at this rather than exact x. Existing base CPU distance condition compares target to boss.x, so this aimX usually retains210 distance rather than legacy300.
- Down immediately clears own waves,18 coins at(x−60,GROUND−200), pops all ordinary bots, foeDie all hit-capable live foes, but does not clear existing hostile bills/controllers. Same frame's later boss tick starts sink: min(1,sink+dt/2400), y+=.03dt. After t>1800 create jar at(camera+WV/2,GROUND−220), vx−.1/vy−.9, not boss.x.
- Generic jar tick617–620 runs same frame as creation: gravity.0024, bounce atGROUND−30 with factor.4 while |vy|>.2, vx halves. A living player within50px x with jar age>600 collects **without vertical test**, then clear. Boss HP0 or sink alone is insufficient; keep holiday-pot jar presentation.
- Actual art is procedural pink flamingo, gold valve, scaled/rotated body, thief-sheet rider and captain hat, plus phase3 sparkle/shockwaves. **No META.sheets.captain or jetbot exists in any W4 page**. The optional sheet branches are inactive, so do not claim missing imported Captain art or substitute a newly invented sprite sheet for the authored fallback.

## 7. Exact stage inventories

The JSON is the full coordinate/wave/art source. Counts below are checks, not replacements for the full arrays. Entries are **spawn requests**, not guaranteed kills; placement can fail and jet/ordinary offscreen retirement exists. All stages have three receipts, all six housemates, and start300 except4-5 start360.

| Stage | Width / fall / auto px/ms | Solids / platforms | Panels / decor / front | Waves; base+pair requests | Crates | Scenes / gates |
|---|---|---|---|---|---|---|
| 4-1 |16470 /742 /none|14 /4|24 /0 /0|12;60+13|4|2 /1|
| 4-2 |16138 /882 /none|25 /0|29 /0 /0|10;54+10|3|2 /1|
| 4-3 |6776 /742 /none|7 /0|13 /0 /0|4;17+4|2|2 /1|
| 4-4 |40226 /618 /.17|50 /0|28 /0 /0|12;48+12|0|2 /1|
| 4-5 |36738 /576 /.15|1 +dynamic deck /0|0 /0 /0|10;29+10|0|2 /1|
| 4-6 |5712 /742 /none|7 /0|6 /2 /0|4;17+4|3|1 /0|
| 4-S |22848 /742 /none|46 /0|24 /0 /0|7;21+0|0|1 /0|

### 4-1 Arrivals

- Base requests rush26/throw13/flat10/case7/drop4; pair rush5/throw5/flat3. Wave at values:500,1700,2300,3000,4400,6100,9538,10938,12238,13738,14538,15732.
- Nine fixed cases at2000,3600,5300,6500,9838,12138,13138,14338,15438 with types exactly JSON (rush/throw alternating except the shifted ordering). Chute set5300 n14 gap800; Bailiff8638. Scalar checkpoint3900.
- Four belts:1500–2250 top420 speed+.07;4300–5100 top420−.08;10138–10938 top420+.09;13338–14138 top420−.09. Source styles9, including hidden sentinel7676–7716 top−5518/nobot1. Walkable tops282–482; multilevel mezzanines, not one flat airport lane.
- Gate lift x7616→to8854; callback cam8794, player0x8994. Scene threshold8235 (initial−1000). Gate directly skips camera positions; triggers pending set next step.
- Crates(2400,472,split),(7600,472,heart),(10538,472,debit),(13238,472,heart).
- Receipts(60,482),(12688,282),(13738,270). Exit requires cam≥15730, all waves done, no busy foe and both sets recorded, then standard ending. Intro4-intro.

### 4-2 Old town steps

- Base rush30/throw11/flat9/melon4; pair rush1/throw8/flat1. Wave at566,1841,3116,4390,5665,9169,10443,11718,13134,15400. Preserve unsorted pair tail at4390/11718.
-25 solids, no platforms,25 styles; four supplemental top steps appear **before** base terrain in source order. Walkable tops602 down to−658, one sentinel8140–8180 top−5518. `top:-538` does not override actual−658 top.
- Melons set6656 n14; checkpoint6798; Bailiff10448. Gate stairs8080→9318, cam9258/player9458; scene8699. Wave9169 starts after gate.
- Crates(2360,532,split),(7470,192,heart),(13268,−368,debit). Last query resolves actual top from `below`, not supplied−368.
- Receipts(−300,482),(4480,142),(14678,−568). First is unreachable under original x≥camera+30 with cam≥0; preserve metadata and log/fix explicitly (§10), do not certify “all three collected” from a teleported fixture.
- Normal exit at cam≥15398 plus all waves/set/foe conditions. No boss jar.

### 4-3 Sun loungers

- Base rush9/throw5/flat3; pair rush3/flat1. Waves500,1600,4038,5238. Walkable tops352,422,482; hidden sentinel2916–2956 top−5518,4 styles.
- Door2856→4094, cam4034/player4234; scene3475. No separate cfg.check or set list. Wave4038 starts shortly after callback.
- Hold camera5998,150000ms, towels6128/6288/6448/6608. Clock/defense, not distance to world end, is required. Unlimited towel reset rule, one half-time Bailiff, end bonus10 per retained towel.
- Crates(4138,472,split),(6368,472,heart); receipts(80,482),(5798,332),(1800,202). Some high receipts require actual jump routing.
- On clear4-clue source story remains here, **even though the old subtitle says World5 while progression actually next visits4-4**. Preserve executable campaign and text separately; do not skip4-4/4-5/4-6 based on that line.

### 4-4 Harbour chase

-27 ordinary quays +23 bobbing nobot solid boats, no platforms. Boat images A/B/C, all bob amplitude8. Authored neutral tops442/462/482; actual varies±8. Boat deck fractionsA=.45/B=.2/C=.5. Quay offset19.
- Base rush24/throw12/jet8/flat4; pair rush12. Waves1185,3949,6713,9872,13031,16585,22113,25272,28431,31590,34749,37514. Preserve four unsorted pair tails6713/16585/28431/37514.
- Auto.17, waterTop463, animated water528, front overlay554; jetY544; fall618. Bailiff19508 pauses auto; checkpoint19744. Source does not have mud, duck gates, invisible infinite deck or W3 squash.
- Fade gate25530→25620 triggers cam≥24788; callback cam25580 and player25760. Scene threshold25575, so destination belongs to second water palette. Wave25272 may be started only after skip; do not discard it.
- Receipts(7810,332),(18285,292),(33975,312); Dash card(11710,342). Must earn card from no skills on an input-driven jumping route, save it, use dash here and reload it in later levels. No crates.
- Normal exit at cam≥39486 plus all waves/sets/busy checks. Unlike W3 auto exit, unfinished waves or a surviving nearby blocking jet prevent end. Auto can reach endpoint while they retire/fight.

### 4-5 Pedalo panic

- Static starter solid[−400,900,482,nobot1], plus moving deck off210/w449/top482. Actual image576×234 anchored top−deckLine105; boat picture wider than collision. Initial player0 x330 (overrides level.start360), pair x420. Keep starter solid; it can affect early falls/support.
- Base jets18/rings11, pair jets10. Waves720,3240,6120,9000,12240,20880,24120,27360,30600,33480. Banana set16200. Checkpoint18000. All ordinary placement should delegate recognized types; no invented road/carrier bots.
- Auto.15; water516/jetY530/fall576. Splash rescue threshold536. Banana pauses until out state, then auto resumes; pending rings still move with+.15 even while paused.
- Iris20898→21498 triggers cam≥20156; callback cam21458/deckleft21668/player21788. Scene21198 switches to sea cave layers. Wave20880 skipped in camera space but dispatched next update. Receipts(7940,362),(19100,362),(29540,362).
- Normal exit cam≥35998/all waves/all sets/no busy foes; no Captain encounter in this stage. No crates/panels/platforms. Source optional fixed sea asset is not license to draw a generic landscape instead of coast/cave layers.

### 4-6 Captain Overcharge

-7 solids,4 raised jetty styles with finite **visual** bottom502, no platforms/gates/checkpoint.6 beach panels; lifeguard decor(1440,197),parasol(2513,222). Walkable tops342/362/412/422/482.
- Base rush5/throw5/jet4/flat3; pair rush3/flat1. Waves500,1700,2900,4000; Bailiff set2300; Captain arena begins cam4974 after all waves done. JetY/bossY522; no CFG.water key, so no generic water overlay from that field.
- Crates(1300,352,split),(2600,472,heart),(5212,472,debit); receipts(60,482),(1480,212),(3700,342). Boss card text Captain Overcharge, intro4-boss, clear then5-1 through campaign.
- Required end is Captain down → sinking → actual jar creation/age/pickup. No level-end or helper-kill shortcut.

### 4-S Splash park

-46 solid blocks =16 ground strips and30 raised steps in15 pairs at tops372/272; no holes between the contiguous authored step intervals, no platforms/crates/gates,30 mezz styles.24 splash paintings.
-7 waves at1500,4800,8100,11400,14700,18000,21300; base rush11/flat7/throw3, no pair extras. Normal wave locks remain active even though a clock runs.
-100s +eight8s gate extensions,258 exact coins, multiplier up to9, receipts(60,482),(4690,122),(21948,332), no Dash card. The name “sponsored dash” is its timer mode, not automatic dash-skill unlock.
- Timeout is successful bonus ending, not loss. Exit at x>22688 can end with waves unfinished. Clear-swept money must be audited separately from collected money. Source unlock after4-2, optional campaign bonus, music slot bonus.

## 8. Rendering, assets, text and sound

### Effective draw ordering

Source1469–1510 and final fix2192–2207: shake translation→bottom-anchored1.3× zoom→sky/parallax with camY correction→world translate−round(camY)→level layer→crates→items→coins→Captain→ordinary bots→custom foes→jar→down players first then living→shots→bills→particles→floating text→front→screen boss bar→HUD→Go/banner. Abilities wrap player drawing (auras/FX) and HUD; follow the shared native rendering seams but avoid duplicate effects.

Level layer803–822: scene.back layers, panels, waterTop fill, animated water, styled nonplatform nonhidden solid blocks, belts, dynamic deck, decor, towels, finds. Final fix disables drawFG and moves any original `level.front` **behind players after base level rendering**; all actual W4 front arrays are empty. Preserve this effective behavior, not disabled foreground code. Front still draws translucent waterFront, falling-drop shadows and screen-space hold/bonus/auto meters. Do not put warning shadows behind an opaque water overlay by changing this order.

Panels are at native image dimensions, clip to authored line from top−2000 through clip and ignore stage-mismatched sceneIndex. Parallax p[5] uses `(value||1)`. Block finite bottom is draw-only. Boat art spans collision width+70, left−35 and height preserving aspect; deck line fraction matches image key. Airport floor/mezzanines tile original floor/front textures; default ground rail=false, raised style entries without rail=false include rails. Harbour quays tile quay art anchored top−19; terraces use pave−22 with original face texture, suppress doors when CFG.face exists. Thus some old4-2 door coordinates remain stale but invisible under the active painted-face branch.

4-5 deck image centered on collision span, top−105.4-4 boat picture and source collider are not alpha-derived.4-2 high scene panels require negative camera/absolute coordinates without screenshot-based truncation. Sky gradient draw rectangle is world viewport while gradient itself is computed over VH540; do not arbitrarily normalize to415px.

Character drawSprite uses frames at native cell size, feet−(cellHeight−3), player anchor.45, bot/thief.5. Gameplay height differs from sprite cell height. Preserve run/rundiag shared stride, normal-size alpha-tested up-pose fallback, horizontal/diagonal/straight-up fire and held aim frames. No pixelation/downsampling filter on painted art. Source near-white flash overlays existing alpha. Move ordinary bot stride `_lx/_mv` mutation to visual-update phase; leave renderer pure.

### Imported asset shape

All seven use identical sheets: jp180×243, maya154×186, ama158×188, leo154×198, theo170×195, mei164×172; bot226×140, thief462×282. Shared character anim rows0..9 idle4/run8/jump4/shoot4/crouch4/up4/hit4/win6/diag4/rundiag8; bot walk6/throw4/pop4 rows0/1/2; thief run6/throw4/down4. Gameplay heights jp180/maya162/ama171/leo187/theo178/mei160. Preserve heads metadata for HUD portraits. Optional jetbot/captain sheets are absent, so inactive optional branches cannot justify new asset requirements.

`meta.imgs` is the authoritative content-addressed PNG/JPEG mapping. `dims` checked against real files. Important stage-local keys and exact sizes:

| Stage | Asset inventory (width×height) |
|---|---|
|4-1|bench223×56,carousel415×118,clouds877×90,floor952×64,front952×89,hallA/hallB952×635,islands499×56,palm50×536,pot99×130,stack112×174,suitcase70×92,trolley145×112,view200×69|
|4-2|clouds877×90,front952×73,hill635×952,islands499×56,lane952×635,palm50×536,pave952×63,pot99×130,sea1075×717|
|4-3|clouds877×90,front952×73,islands499×56,lane952×635,lifeguard119×285,lounger/towel179×68,palm50×536,parasol174×260,pave952×63,pool952×635,pot99×130|
|4-4|boatA329×134,boatB217×53,boatC244×103,clouds877×90,coast142×80,harbour/lane952×635,islands499×56,palm50×536,pot99×130,quay952×105,sea1075×717|
|4-5|cavefar1400×300,cavenear1600×260,clouds877×90,coast142×80,fl-croc/fl-duck/fl-unicorn112×75,fl-ring112×50,islands499×56,pedalo576×234,sea1075×717|
|4-6|beach952×635,clouds877×90,coast142×80,islands499×56,lifeguard119×285,palm50×536,parasol174×260,sea1075×717|
|4-S|clouds877×90,palm50×536,parasol174×260,pot99×130,splash952×635|

Imported but presently unused keys remain preserved. Keep original procedural foe drawings: jet hull + bot rider, Bailiff plates/cap, banana hull/seats, melon, fallback ring, flamingo/rider/hat and valve. Capture representative actual pixels before rendering implementation acceptance; this contract only verified file dimensions.

Music `playMusic`947–950 tries world4 (default), bonus (4-S), boss (Captain), victory (clear); MP3 unavailable falls back to existing procedural normal/boss loops. Do not invent licensed recordings. Readiness must account for current audio assets instead of treating a URL construction as proof a file exists. Preserve mute/pause/background behavior and power/warn/throw/stomp/pop/pick/hurt/revive/honk/win cues, without double-playing hit SFX where W4 wrapper and Captain both emit it.

Story source tails:4-1 before4-intro;4-3 after4-clue;4-6 before4-boss. `campaign_progression.gd` already stores those and4-S unlock after4-2. Keep all original42 stage IDs/menu/unlock relationships, six-world art/dialogue/credits/story data and optional bonus stages. A 4-3 subtitle is not the campaign routing authority. Clear/save fires at stageClear, not settlement; Enter after1.9s first settles then advances to map/next; Replay is separate, guarded while story plays.

## 9. Abilities and Dash compatibility that must be explicit

Source1667–1979,974–987,2130–2191. Existing shared abilities are reusable only through W4-aware host hooks.

- Base ordinary movement270px/s; Mei extra12%, active sugar extra60% (70% super), airborne Leo special+35% are **post-base nudges** after normal firing/motion, respecting walls/edges/insideWall. W4 has no spdMul function, so fallback1. Reusing W3 mud/tie or pre-applying speed modifies phase boundaries.
- Ama jump×1.09/active Mei×1.06 after base gravity when pre.onG and current airborne/vy<−.5. Leo held-jump fall cap.34 after base motion. New special begins after base firing; Mei cooldown clamp105ms then affects subsequent firing frames. W3 point order is similar here but its carry/squash mechanics are not.
- OWN.dash=true because updateDash2 exists in **all seven pages**. Shared dash branch disabled. W4 dash runs after finds and before hold/bonus/foes/bots/shots. If card picked this tick, input can immediately trigger it. Double-tap same direction<260ms or fresh Shift/P2Q; cooldown600ms; vx±1.1; inv=max(inv,260); no hurt-lock condition, no grounded condition, no direct attack. CPU/down skipped. Dash inv then protects against same-frame foes/bots/bills; moving it after pickups loses that protection. Next base step decays inv and consumes knockback velocity. Do not use generic650ms cooldown/ability dashT/locked guard. Touch can expose a native dash button as accessibility adaptation, with same edge semantics.
- Existing acquired slide, double-jump, ground-pound, wall-jump and super remain usable. Slide/pound/bubbles select **ordinary bots**, not custom foes; W4 own dash is separate. Theo crate kicks still emit ghosts; crate damage remains1. Shared slide can emit a ghost at a bot which a preceding overlapping custom foe intercepts, exactly like other shots.
- JP rain chooses ordinary bots/boss/random x, not custom foes, but falling projectiles naturally hit custom foes through W4 interception. Debit/Leo homing targets only ordinary bots. Maya shield intercepts bills, damages ordinary bots; Ama bubbles only ordinary bots; CPU special readiness crowd count only ordinary bots or an active boss, **not a Bailiff in foes**. Custom foes' credited pops still feed meter next player update.
- Football free-zap every180ms when not near an ordinary bot/boss can hit custom foes via their own policy. This is different from directly making all custom foes football proximity targets. Ghosts live>70ms then expire in wrapper; use source y/sweep/hit priority.
- **Captain source fy defect:** startW4Boss stores `y`, not `fy`. Shared hitBoss uses `boss.fy−120`, Maya/pound/ball proximity use `fy`; they produce NaN/miss or fail condition. Ama sets dizzy to3500 (unused by Captain) but its direct boss ghost has invalid y. JP rain remains usable; ordinary fired bullets remain usable; football incidental free-zaps may hit body. Native's current `boss.state.fy` accesses will fail or unintentionally repair this if blindly supplied. Implement a deliberate compatibility policy, with no invalid floats entering Godot. Exact policy: suppress invalid direct boss zaps and proximity tests while preserving non-targeted real shots. Proposed minimal functional repair (not implemented or decided by this audit): map Captain ability feet to its actual y and allow source-shot1/valve3 damage, documenting the broader special effectiveness; still do not grant unused dizzy damage/AI freeze. Keep this decision separate from exact-source assertions. See the proposed repair tests below and the transparent Binman precedent in `docs/BINMAN_PARITY.md:49`. Do not present a repaired interaction as source-identical.
- Base input final fix: player1 Z jump, Up aim, Space/X/K fire; player2 G jump/W aim/F or E fire. Standing human Up fires straight up (tiny signed vx .0001, vy−.78), split two angled extras, debit a second faster vertical shot **without homing**. Moving aim is diagonal; CPU retains base logic. Existing native controls should preserve these and mobile independent touch actions.

## 10. Source quirks, reliability corrections and decision ledger

Keep source arrays/content. Native corrections should be small, named and tested, not hidden difficulty redesigns.

| Source fact | Exact behavior / proposed treatment |
|---|---|
|Captain y/fy mismatch|§9. Required explicit policy before integrating shared abilities. Avoid Godot missing-key/NaN errors. A functional mapping is a proposed intentional mechanics repair, not exact parity or an implementation performed by this audit.|
|4-2 receipt x−300|No ordinary human route with cam≥0/x≥cam+30. Do not claim all-receipt parity from test teleport. Preserve authored metadata. Proposed local repair: an explicit native-only pickup anchor at x60/y482 for receipt1, retaining its identity and reward; this puts it in the same reachable starting-area secret position used by other W4 stages. Do not implement, delete, auto-award or report it as source parity from this audit.|
|Deck reset after base player floor lookup|Old dynamic deck can remain during `startLevel` initial below until W4.start removes/rebuilds it; starter solid makes ordinary4-5 spawn mostly safe. Native reset should establish fresh geometry before any floor query and never retain prior run surfaces. Declared reliability fix.|
|Bob surfaces retain prior top across source replay|bob0 is stable but raw SURF top may still be last-run top before first pre. Rebuilding from immutable authored rows produces deterministic fresh replay; name the correction.|
|Wipe clock runs in render, including paused/over|Freeze callback while paused/over, generation-guard menu/restart, execute once only; retain source timing/order otherwise. No stale callback teleports a new run.|
|Banana blocking flags unused|Auto resume on out, busy by live type.blocks/visibility until gone. Do not use f.blocking to release ordinary gates earlier unless explicitly changed.|
|W4 foe list append during update|New children update same tick. Port with deliberate ordered live-list iteration; a duplicate list is a timing change.|
|Draw mutates banana flashes/bot stride and samples randomness|Move visual state to update and use presentation RNG. Keeps simulation deterministic and painter pure; not screenshot-timing-identical to arbitrary browser frame rates.|
|Per-frame jet retarget/spray and Captain spray chances|Gameplay jet .003 is per source frame. Fixed34ms/physics timing changes stochastic frequency unless intentionally normalized; document choice and test using deterministic RNG injection. Cosmetic randomness can be separate.|
|4-S clear sweeps unvisited future coins|Preserve scoring unless intentionally repaired; distinguish collection/cull/sweep in tests and HUD claims. Timeout still clears.|
|No W3 stale-bot retirement or squash|Do not import conveniences silently. If observed native/source softlock needs bounded retirement/recovery, document trigger, evidence and effect separately.|
|Crate/item pickup and jar lack vertical tests|Preserve unless named accessibility/gameplay change; no made-up grounded requirement.|
|Source4-3 subtitle mentions W5|Keep actual campaign4-3→4-4→4-5→4-6→5-1. Subtitle/story audit may propose wording later; no automatic route skip.|
|Captured live fields versus native helpers|Ordinary source base player caches lock before fall, so that frame can retain its cached fire/animation eligibility; shared abilities re-read new lock. Shared host needs explicit override rather than accidental family conditional.|
|Source inactive legacy boss/debug paths|Do not port Jar Thief into W4 or use __bd.win (calls legacy bossDown even for Captain) as gameplay proof. Source manual skip/win/test hooks are not full-run acceptance.|

### Proposed defect-repair tests, separate from source-parity requirements

Neither proposal below is implemented or adopted by writing this contract. First retain executable-source tests that prove the original defect, then have the integration owner record any selected native behavior before accepting the repaired stage.

1. **Captain missing feet:** source fixture proves no `fy` field, Ama direct ghost y=NaN and positive-form bossShot rejects it; original Maya/pound/targeted-ball proximity checks fail. If native repair is selected, expose a current `fy=y` compatibility coordinate (or equivalent explicit ability adapter) that stays synchronized while Captain moves/sinks. Test all six characters without Godot missing-key/nonfinite values, Ama/Maya/pound/football targeted hit locations, custom foe interception before boss, fixed1/endpoint-valve3 damage irrespective requested damage and unchanged unused dizzy behavior. Do not broaden body/contact boxes or bind y to fixedGROUND. `BINMAN_PARITY.md:49` already documents a transparent native `fy=ground` repair for the analogous W1 Binman omission. That is a precedent for disclosing a functional repair, **not evidence Captain already has fy or that the two original NaN hit tests behave alike**: Binman's negative-form rejection accidentally accepts some NaN shots, while Captain's positive-form test rejects them.
2. **4-2 unreachable receipt:** source fixture asserts cam never negative, base x clamp≥cam+30 and receipt0x=−300, so strict42 proximity cannot succeed. If the proposed runtime anchor x60/y482 is selected, preserve the original JSON coordinate unchanged and keep one receipt identity, display, £5 kitty reward and save index. Input-only tests for all six characters must walk left from start300 with cam0, collect exactly once in that run, confirm no personal coin increment and verify save/replay deduplication with repeatable run reward. A replay/Continue must not duplicate the physical pickup or move later receipts. Do not pass an all-receipt route by teleporting to−300 or modifying camera minimum.

Open implementation decisions should be recorded in the eventual per-stage parity notes, not silently resolved by this document. Small safety changes for invalid data, duplicate clears, stale callbacks, deterministic reset and pure renderers are recommended. Broader hitbox/boss-power/receipt-location changes require explicit traceability to this ledger and faithful remaining content.

## 11. Worker ownership and integration plan

One parent/integration owner owns `main.gd`, shared registry/save/campaign/ability integration, test launcher and aggregate claims. Stage workers do not edit those concurrently. Newly proposed files only until API contract is agreed. Parallel slots are finite; run the batches in sequence, not seven competing host forks.

| Owner | Isolated files / responsibility | Acceptance before host registration |
|---|---|---|
|Shared W4 runtime owner|`world_four.gd`, focused runtime tests and integration document; source pre/camera/gates/finds/objective, surface identity|Reset/Continue, gate timing, early carries, all schema types; source-aware phase test|
|Shared W4 combat/foe owner|`holiday_combat.gd`, `holiday_foes.gd`, common ordinary/foe dispatch tests|x2 order, custom-before-bot hit precedence, busy/pause distinction, bubble order, coins/bills|
|4-1 Arrivals worker|`holiday_luggage.gd`, `holiday_bailiff.gd`, `arrivals_renderer.gd`, 4-1 focused/full-run tests|All cases/chute/Bailiff/conveyors/lift, three receipts, actual exit, six-character routes|
|4-2 Steps worker|`holiday_melons.gd`, `old_town_renderer.gd`, climb/full-run tests|Steep route, melon controller, stairs/check, shared Bailiff integration, declared receipt decision|
|4-3 Loungers worker|`holiday_loungers.gd`, `loungers_renderer.gd`, hold tests|150s real clock, theft/rescue/all-gone reset, halfway Bailiff, retained-towel bonus and clear|
|4-4 Harbour worker|`holiday_harbour.gd`, `harbour_renderer.gd`, auto/bob/card tests|23 moving solid boats, source pause/fade, real dash acquisition/persistence, all12 waves|
|4-5 Pedalo worker|`holiday_water_foes.gd`, `holiday_pedalo.gd`, `pedalo_renderer.gd`, ride tests|Deck lag/carry/rescue, jets/rings/four seats, out-state pause release, cave, complete ride|
|4-6 Captain worker|`holiday_captain.gd`, `captain_renderer.gd`, boss/approach tests|90/120HP exact body/valve/phases/helpers, named special policy, down/jar/clear|
|4-S Splash worker|`holiday_splash.gd`, `splash_renderer.gd`, timed bonus tests|258 coins/eight gates/clock/multiplier/end/cull/sweep, seven waves and receipts|

A shared holiday renderer base can be owned by one designated painter or runtime owner, with stage files consuming its stable API. Do not have each stage reimplement geometry or edit the shared dispatch. Shared water foes needed by4-4/4-6 can be completed before those stage acceptance runs; reuse through explicit interface, not copy divergent jets. Shared Bailiff needed across five scenes should have one owner. Stage workers can supply source-shaped serializable events and pure draw plans; integration consumes them at exact phase positions. Never add a stage ID to capability merely because one painter/controller now exists.

Suggested stages:

1. Common contracts/runtime, combat and4-1 renderer/luggage/Bailiff in parallel, parent integrates only4-1 after focused tests.
2.4-2 +4-3 +4-S isolated work; verify shared gates/timers/receipts and do not regress4-1.
3. Shared water foes +4-4 +4-5; integrate auto camera, early moving solids, card and native own dash before their full runs.
4.4-6 Captain + dedicated painter/boss tests; verify approaches and ability policy; then campaign/story/save sequencing across W4.
5. Full aggregate/import/resource-pack checks and device/human QA; do not conflate headless routes with mobile certification.

## 12. Acceptance checklist and preservation boundary

### Data and phase tests

- [ ] All42 catalogue IDs, original sources/art/story/fonts and all7 W4 JSONs retained; no mutation of imported source dictionaries or original web files.
- [ ] W4 metadata/body hash inventory unchanged; style/belt/bob application preserves source identity/order and source booleans.
- [ ] Phase trace proves early surface carry, base/ability order, camera/waves/objective, W4 checkpoint/sets/finds/dash/hold/bonus/foes, ordinary AI, custom-first shots, bills/pickups, boss/jar/all-down, late effects, wipe callback.
- [ ] Entered/nonentered/bubbled/hopping/popped bots on moving surfaces match W4 distinctions; no W3 mud/tied/wellies/retirement leaks.
- [ ] x2 pair lists concatenate unsorted; solo and CPU pair counts checked, failed placement recorded separately from kills.
- [ ] Proximity-open versus shot-open case same-frame ordering; live-list controller-child timing; boss helper/bill next-frame timing.
- [ ] Hitbox edges, swept-x/new-y tests, custom foe insertion priority, ordinary bot damage, fixed1 crates/cases/Captain, phase3 endpoint valve3 and invulnerability tested with real damage enabled.
- [ ] Distinguish no-contact jet/banana, landing-only drop, melon/grab/Bailiff/Captain charge/wave damage; no fictional ocean hitbox.

### Stage play and interruption tests

- [ ] Each stage uses actual input progression from fresh load through source objective, with no skip-to-boss, camera jumps, forced wave.done, fabricated score, direct boss HP0 or direct `_complete_level`.
- [ ] All six characters finish; stage route test can use explicit invulnerability for navigation but must report every masked damage/fall event and cannot certify difficulty. Separate normal-damage fixtures cover each mechanic and human playtesting remains required.
- [ ] 4-1 complete12-wave/9-fixed-case/chute/Bailiff/lift path, all crates and receipts reachable through inputs.
- [ ] 4-2 source negative receipt issue resolved/documented, full vertical route/melon controller/stairs/Bailiff and actual exit.
- [ ] 4-3 full150s hold, one half-time Bailiff, theft→rescue and all-gone extension, simultaneous timeout/reset ordering, score/personal split.
- [ ] 4-4 all23 bobs, all12 waves, auto pause/Bailiff/fade, three airborne receipts and Dash card from no skills with immediate use and disk reload.
- [ ] 4-5 deck support/one-frame camera lag, starter solid, splash rescue/death/Continue, all10 waves, all four banana seats/pop rewards/out exit, cave transition and delayed endpoint busy release.
- [ ] 4-6 approach four waves/Bailiff plus Captain full90HP and pair120HP, phase/body/valve/charge helpers, no source-fy runtime errors, sinking1800ms, jar age600ms actual pickup before clear.
- [ ] 4-S complete258-coordinate inventory, normal/non-auto wave locks, eight one-time clock gates and max9 multiplier, finish and timeout paths, no implicit skill grant, separate physical/clear-sweep accounting.
- [ ] Pause/focus loss freezes gameplay timers; Continue retains current run; Replay resets all source state; old wipe/callback cannot mutate a new stage; repeated clear/save does not double-credit.
- [ ] CPU/second-player modes eventually preserve source camera, revive, pair waves/HP and towel spawn acceleration. Solo-only milestone must remain labelled solo-only, not “whole game complete.”

### Art, story, sound and mobile acceptance

- [ ] Screenshot review of start/middle/destination/endpoint scenes with original artwork at native dimensions and correct crop/parallax; steep4-2, carousels,23 boats, cave darkness, towels/theft, jets/banana and Captain procedural details captured.
- [ ] Painter command tests assert effective foreground fix, warning-shadow layer, boss-before-bots-before-foes, player readability, no draw-state mutation, and image filtering/anchors.
- [ ] Distinct hold/bonus/auto HUD, real hearts/kitty/personal values, pickups/card fading, valve warning, boss meter and jar retained.
- [ ] Source4-intro/4-clue/4-boss and complete campaign4-1…4-6 plus optional4-S, reload/unlock/Continue/story replay behave correctly; W5 remains available only when its own implementation is honest.
- [ ] Run focused suites, then `bash scripts/verify-native.sh` and `bash scripts/verify-native-pack.sh <temporary pck>` after integration, under isolated test saves. Audit-only doc changes do not warrant claiming those suites were run here.
- [ ] Actual Android/iPhone exports, installation, multitouch/repeated input, notch/rotation/background/audio, performance/battery and human full playthrough remain separate release gates. A headless pass or packed resource file is not a signed app.

**Verified by this audit:** exact common source hashes, all seven metadata comparisons, inventories/line anchors, all71 stage image dimension checks and present native seams. Isolated Node VM probes executed unmodified extracted `bossBox`/`bossShot`, `updateDash2` and `updateDash`: Captain NaN shot miss, body fixed1, phase3 endpoint valve3 versus body-only sweep, own Dash activation while hurt-locked with600ms cooldown/260ms inv, down-player bonus gate granting time before timeout, and timeout setting the successful ending flag. All assertions passed. The optional read-only probe helper is `/tmp/audit_w4_source_probes.cjs`; it is not a gameplay harness, repository change or release test. **Not verified here:** executing W4 in Godot, a browser playthrough, pixel comparisons, native gameplay completeness, aggregate regression, exports/devices or release readiness. Only this new contract was written; no production capability or gameplay was changed.
