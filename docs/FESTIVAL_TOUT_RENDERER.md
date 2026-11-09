# Stage 3-6 Ticket Tout painter

`godot/src/festival_tout_renderer.gd` is an isolated, read-only festival painter for 3-6. It uses the seven original painted animation strips, not a tinted thief or a rescaled static cutout. This slice does not change source assets, imported metadata, shared simulation, host dispatch or capability registration.

## Source contract

The implementation follows `game/3-6/index.html`: dusk/painted sky 879–886, layer/level order 951–973, barriers/bales/cases 994–1017, boss phases 1350–1395, `toutMove` 1396–1406, anchored painted frames 1417–1423, jar 1495–1499, and world/HUD order 1527–1557. `content/levels/3-6.json` preserves `META.l3.toutfr` and per-image `META.hi`.

Every strip has four frames and hi=1.3. Crops use native texture pixels; display dimensions and foot anchors divide by the asset's hi.

| Move | cw | ch | ax | ay |
| --- | ---: | ---: | ---: | ---: |
| walk | 322 | 457 | 173 | 455 |
| throw | 287 | 432 | 181 | 431 |
| stomp | 339 | 406 | 154 | 404 |
| dizzy | 260 | 464 | 118 | 462 |
| down | 358 | 430 | 181 | 429 |
| surf | 346 | 241 | 155 | 239 |
| hide | 332 | 488 | 154 | 487 |

The source frame rectangle is `(frame*cw,0,cw,ch)`. The world anchor is `(camera.x+round(b.x-camera.x),round(b.fy)+camera.y-round(camera.y))`, using JavaScript-style round. A left-facing sprite starts at `anchor.x-ax/hi`; a right-facing one starts at `anchor.x+(ax-cw)/hi` and flips horizontally. Both start at `anchor.y-ay/hi`. No common crop, centered fallback, whole-rectangle rounding or generic tint changes these anchors. Flash uses CSS-equivalent brightness(2): double/clamp RGB, retain alpha. Only draw-time texture caches change.

### Phase selection

All native clocks are seconds. `tout_move(b,elapsed)` preserves this priority:

1. Down: frame floor(t/0.28), capped3; any existing jar pins3, including a collected jar.
2. Hop: non-slam uses surf floor(t/0.14)%4; slam uses stomp0/1/2 at hop fractions below0.12, below0.7, or thereafter.
3. Landing `land_t>0`: stomp3.
4. Dizzy: floor(t/0.17)%4.
5. Throw: floor(t/0.16), capped3.
6. Ordinary stomp:0 below0.16,1 below0.32,3 thereafter. Stomp2 belongs to the descending slam, not the ordinary stomp sequence.
7. Enter/charge/moved: walk floor(elapsed/0.15)%4.
8. Idle: c=floor(elapsed/0.26)%12; hide1 at c5, hide2 at c8–10, otherwise hide0.

Hide3 exists in the authored strip but is never selected by the shipped `toutMove`. The tests exercise that crop as an asset/draw-path check, not a reachable gameplay phase. A tiny division epsilon prevents converted-second representation from delaying an exact millisecond boundary.

The source renderer updates `moved` once per `levelT`: `abs(b.x-(b.px if present else b.x))>0.05`, then stores x as px. Native simulation must update `boss.state.moved` once after boss movement per simulation frame, with false on the first sample, so drawing remains pure. The painter reads that Boolean (or `visual_move` as a compatibility fallback); it never advances px, pxT, walkT or animation clocks. Simulation owns native `hop={t,duration,slam,...}`, `land_t`, and nested `jar`.

## Scene, geometry and layer ownership

- Inherited scene builders draw the original crowd sky/far/land/ground. Dusk is #3b3270 → #d8668a → #f7b267; land parallax is the authored0.45, far0.16, ground1. The parent retains sky locking, drift, alternating tile mirroring and fractional-camera compensation.
- Suppress redundant back-layer speaker/flag props exactly as source when using the painting. Authored mid-distance loos/bales props stay behind actors via the inherited builder.
- Reuse the Queue painter's source barrier geometry and the Big Top painter's case geometry. The stage is platform index **0**, `[4040,4290,354,{base:482,style:"cases"}]`, producing two64px case tiers. Read the live surface rows without changing collision or assuming index0 is false. Parent bales and invisible painted-ground behavior remain intact.
- Receipts remain at `(1820,312)`, `(2000,252)`, `(4170,282)`; inherited finds/coin/item/crate/enemy/wristband/player overlays and boss HUD keep their source behavior. No extra checkpoint, ending runner or collectible is invented.
- `build_boss` reuses the shared shadow/shockwave commands and replaces only the generic thief command. Order is shadow → Tout → shockwaves. A hopping boss casts its shadow on ground482; otherwise shadow follows fy, including stage354.
- `build_jar` is a separate world pass. Uncollected jar center has `sin(t/0.14)*2` vertical bob, glow radius44+sin(t/0.1)*4, and full jarIcon scale2. Collected jars remain visible without bob or glow. The center is not pixel-rounded, matching source. The painter does not spawn, move, attract, collect or settle the jar.

## Host integration

Select this painter for 3-6 and load ordinary `host.meta`, `host.level`, `host.images`, sprite sheets and font as with other festival painters. Boss lookup accepts the existing `runtime.boss` object/state dictionary. Standard inherited wrappers continue working.

World order must remain:

`draw_sky → draw_level → draw_mid/finds → crates → items → coins → draw_boss → bots → draw_jar → players → shots/bills/effects → draw_front`.

Call `draw_jar(host,world_three)` once after bots and before players. Do not also draw a generic jar. After resetting the world transform, the inherited `draw_hud` draws the Tout's exact name and420px HP meter, gold while dizzy and absent when down. Do not duplicate this bar in the host.

Only this renderer, its isolated test and this document belong to this slice. The integration owner remains responsible for simulation-owned `moved`, dispatch, full-run tests and any capability promotion.

## Verification

`godot/tests/test_festival_tout_renderer.gd`: **336 checks, zero failures** under Godot4.6.3 headless. The suite verifies source-code phase/anchor markers, all seven exact metadata records and four-frame dimensions, all28 nonempty original crops, both facing directions and fractional world anchors, phase boundaries/precedence, stage0 cases and route obstacles, original scene/parallax, receipts, shadow/shockwave ordering, HUD, jar bob/collection presentation, and actual boss-controller stage-hop/down/jar snapshots. It confirms repeated builders do not change runtime, metadata or RNG.

At least56 actual CanvasItem callbacks exercise each original crop normally and flashed/mirrored. Flash caches remain separate from the original pixels and clear on reset. The callbacks execute headless draw commands; they do not certify framebuffer appearance, physical-device rendering or performance. Whole-route playability, controls, difficulty, mobile exports and release readiness require separate checks.

Related regressions also pass: shared festival renderer1192 assertions, Queue renderer253, Big Top renderer95, and festival boss116. Headless editor import completes without script/parse/error/leak diagnostics and generates both new script UIDs. These are focused renderer/controller checks, not the complete native verification aggregate.

Run with writable, isolated HOME/XDG directories and `/usr/local/bin/godot --headless --path godot --script res://tests/test_festival_tout_renderer.gd`. Scan the complete log for `SCRIPT ERROR|Parse Error|^ERROR:|ObjectDB instances leaked` even if the process returns0. No commit, push or deployment is part of this slice.
