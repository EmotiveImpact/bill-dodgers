# Festival hay ride runtime extension

Implemented `festival_hayride.gd`, an isolated subclass of the existing queue auto-stage rules. This is a runtime/component acceptance report, not a whole-stage native/device playthrough or capability promotion. No shared runtime/main/registry files changed by this component owner.

## Integration contract

- Construct/reset alongside stage extensions. `reset(host)` deliberately retains the queue signature. It clears event/branch state and harvester only on a **fresh** run, not Continue.
- After shared solids/platforms are copied, call `bind_trailer(host,runtime)` **before the initial floor lookup**. It binds the exact existing surface dictionary, sets initial dx zero, and preserves nodrop/nospawn/style. Source `[60,540,402]` supports start x300/query392 at feet402. This repairs the source replay initialization ordering bug without changing active-run carry.
- Route stage3-5 through inherited `auto_displacement`, `end_ok`, `scene_can_start`, `squash`, `events_tick` and `banners_tick`. Shared runtime still owns checkpoint/wipe/objective. Auto is170px/s, strict elapsed>1.8s, paused/wiping/end/living-boss guarded. Do not call the queue jarRunner clock for this stage.
- Late order: finds, scenes, events, coins/timers/tied, checkpoint, branches, moving surfaces, `trailer_tick`, other late world phases, mini/main trigger, `harvester_tick`. Trailer tick adds current camDX, then carries attached nonpop/nonhop bots only when dx is truthy. Zero dx intentionally does **not** snap bot y. Player carry remains the shared previous-frame surface delta, before old-camera clamp.
- At the guarded scene midpoint call `scene_translate(camera_delta,runtime)` when shifting players/camera and before clearing enemies/projectiles. Deck and unfinished harvester shift together; dx is untouched. Source dusk/check13300, fade destination14500. Preserve vertical state and relative offsets. Shared runtime owns run-generation/pause protection.
- Harvester is **not** host.boss and is never an objective gate. Auto end may clear with a live harvester, live enemies and incomplete waves. Camera threshold33260;2.6s strict countdown remains shared policy. This component does not manufacture completion.
- `snapshot().harvester` is a deep copy `{x,hp,max,flash,t,dead,done?}` with seconds. Painter uses live runtime.trailer and stage_data.harvester. Combat already owns ex_drones `{p,age,born,dir}` and simulation-only pop detach/cleanup, plus enemy stride/visual_move. Do not duplicate drone lifetime ownership in the painter.

## Exact harvester behavior

Source `game/3-5/index.html`1321–1338: camera>=15000 spawns at camera−420,70 solo/91 pair HP, independently of ordinary bosses. Tick clock/flash first. Alive follow adds camDX, approaches deck.left+(sin(t/2.6)>.6?40:−60) at50px/s. Late surviving player shots hit only x in(h.x−340,h.x+10) and y>deck.top−300, with no lower y bound and no swept collision. Each consumes one HP, flashes80ms and pushes six pixels regardless ghost damage. Later shots see the changed x. No immediate lethal return: further shots/contact/random bill still execute; death drops happen next late frame.

Death resets clock, drops14 coins at(deck.left+80,deck.top−100), emits source shake14/five debris positions/text/music event, retreats300px/s plus camDX; after strict t>3s uses the source done sentinel. Done sentinel remains nonempty so never respawns. Contact uses player.x<h.x+30 and strict vertical distance<60, hurt from player.x−60. Random big bill probability dt/2.6, position(h.x−120,deck.top−280), vx250..450,vy−400,gravity1400. Shared combat performs ordinary damage guards/projectile motion.

18 branch tuples and three stationary receipt centers(8000,212),(20000,212),(30000,212) come from immutable metadata. No world solids, authored coins or crates are introduced.

## Verification

`godot/tests/test_festival_hayride.gd`:75 checks passed using Godot4.6.3 headless and isolated HOME/XDG directories under /tmp; strict log scan rejects parse/script/errors/leaks and failing assertions even on exit0. The isolated test enables3-5 through a tiny runtime supports override, using production geometry/carry/recovery and actual FestivalCombat. It is not a substitute for parent true-main routing tests.

Coverage includes pre-spawn deck lookup, initial nodrop,170px/s warmup, late deck versus previous-frame player carry, airborne exclusion, zero-dx bot quirk, all18 branch bounds/crouch, scene offsets/dx, fresh translated reset, paused/Continue encounter retention, metadata/snapshot immutability,70/91HP, fixed-one ghost hits, strict y edge/hostile exclusion, deferred lethal/drop/sentinel, and actual production dispatch of all16 authored waves39 solo/62 pair while earlier enemies remain alive. Carrier tests prove420ms hop onto same live surface, source camDX*30 lead, simulation detach-on-pop and2.6s cleanup.

An independent Node VM probe extracted and executed the original `updateHarv` function (not a translated reimplementation): two shots yield hp0/x88 without death; next34ms frame yields x77.8 and14 coins at(240,302); exactly3000ms does not complete,3001ms does. These results match native tests. Source numeric time conversion is milliseconds to seconds, speeds multiplied1000 and acceleration multiplied1e6.

Remaining acceptance belongs to host/painter integration: actual six-housemate input route, jump/fall recovery during full camera motion, checkpoint/dusk callback in true-main, receipt acquisition, ghost hit ordering through ordinary combat, clear with live harvester, save/Continue/menu progression, visual QA and real-handset/export validation. No device, export, push, deployment, signing or visibility change was performed.
