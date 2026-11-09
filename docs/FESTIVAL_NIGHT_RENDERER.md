# After dark native painter

Implemented in `godot/src/festival_night_renderer.gd` and `festival_night_overlay.gd`. This is stage 3-3 presentation only, not a capability promotion or a completed device/playthrough assessment. Source metadata is read-only.

## Source and content

Audited original `game/3-3/index.html`: source helpers/art at 732–752 and 807–812, paintings at 835–852/880–886, level order at 952–966, night bale filtering at 994, lanterns at 1034–1037, dark front at 1135–1161, and the 3-3 imported metadata. The superclass supplies original cutout tents, 1.3/per-image sizing, alternating painted parallax tiles, scene-specific crops, cutout campers, clipped bales, receipts/checkpoint and Bailiff's selectively tinted thief frames/animations/HUD. Night does not add stars over paintings: source returns into the painted sky first.

The two original scenes are campsite and fieldAnight; their sky factors are .13/.1, land .5, far .16, ground 1, and explicit drift zero. Source night gradient is #060a1f/#16204a/#2b2f5e. Foreground-list cutouts still paint behind actors at .78 parallax with inherited brightness(.9)/saturate(.92).

All 15 authored tent cutouts are used unchanged. The fifth authored `1` is NOT an active tent glow flag: original TENTS mapping discards it. Only an explicit live `tent.glow` activates a 120/.7 light. Existing glow-colored pixels in original tent paintings are retained. Lantern posts and five-color lantern body use original geometry; painted flags are not duplicated. Bales apply brightness(.5), saturate(.7), and both source hue rotation matrices (200 then 160 degrees), not a flat translucent color wash. Variants are cached, so pixel filtering is not per-frame work.

Fire procedural artwork uses original Park–Miller seeded RNG, exact conditional random consumption, rounded blocks, logs and core. Four cached 90×110 textures advance at 110ms. Original campfire cutout is drawn at feet+6; its flame pass samples (18,0,54,92), draws at x−27/feet−128, with real additive blending and alpha .55. If a cutout is unavailable, the full ordinary fire canvas remains the source fallback.

## Integration: two ordered world overlays

A single Godot CanvasItem cannot switch blend material between its immediate draw calls. Do not approximate the additive operations with ordinary translucent rectangles or put every night pass above the UI.

1. Instantiate two `FestivalNightOverlay` Node2D roots as children of the main actor-drawing Node2D.
2. `level_overlay.configure(host, night_renderer, "level")` sets show_behind_parent. `front_overlay.configure(host, night_renderer, "front")` stays above parent.
3. After simulation, call each `refresh(world_three)`. The level root builds sky+level; front root builds front. Each batches ordinary commands and splits special materials into separate ordered child CanvasItems. Resources/primitive draw targets are forwarded through a small draw proxy; no gameplay state is changed.
4. Skip main's original night sky/level/front draws AND any opaque whole-screen main-parent background fill, otherwise that fill hides the behind-parent level root. Keep actor/finding/pickup drawing in main, preserving source order. UI belongs in the separate CanvasLayer. Place night touch controls in the existing UI overlay, not the now-darkened parent actor CanvasItem.
5. The roots mirror the host bottom-anchored 1.3 zoom and fractional camera rounding. They hide and clear retained commands when stage is not 3-3 or mode is outside play/paused/clear/over. Host should still refresh or explicitly hide them on menu/reload paths.

The generic renderer `draw_commands` accepts a host `draw_festival_material(command, ShaderMaterial)` hook only for clients directly drawing these command arrays; the provided overlay avoids needing that hook. A material command must be replayed from that CanvasItem's `_draw` using `renderer.draw_material_command(canvas, command)`. Ordinary level rendering must not silently skip additive commands.

## Dark compositing and runtime contract

No full-screen GDScript pixel loops. GPU shader computes source destination-out equivalently: start alpha `max(0,1-flash_time/.6)*l3.dark`, then multiply by `(1-hole_alpha)` for every active radial hole. Each hole is flat through radius .15 and linearly falls to zero at its outer radius. Overlapping holes multiply, rather than adding/clamping intensities.

Lights: all players at feet−90 radius230; fires feet−60 radius240+sin(elapsed/.07)*10; lantern x+15/y+20 radius150 alpha .9; explicitly glowing tents feet−50 radius120 alpha .7; player shots radius60 alpha .8; non-pop bots feet−90 radius70 alpha .5. Source darkness canvas is 738×420 at view_top, including camera fractional snap. Offscreen holes are excluded only when they cannot intersect this finite canvas. Shader uniform budget is 128 visible holes; exceeding it asserts instead of silently losing lights. This is a documented capacity bound, not a mobile performance certification.

Then additive fire gradient uses radius10–200 and source orange/.35, followed by ordinary red eyes, fireworks and undarkened cheer/hint. Fireworks preserve source displacement `s*t*120`, gravity `t*t*40`, 4px size and alpha `1-t/1.4`. HUD is separate. The inherited wipe respects `wipe_kind="fade"` and source timing/label, so stage 3-3 has actual full-screen alpha fade rather than iris.

Read runtime fields: elapsed seconds, scene_index, tents, surfaces, checkpoint_done, boss/cheer, wipe fields, and `stage_data.flash_time` seconds plus `stage_data.fireworks=[{x,y,col,t:seconds,s:[Vector2]}]`. Host actor state uses player absolute feet, enemies with p/state, bullets with p/enemy; optional players/shots arrays are supported. No render RNG, clocks, scene changes, projectile motion, or other game mutation occurs. Draw texture/material caches are renderer-local.

## Verification and limits

`godot/tests/test_festival_night_renderer.gd` checks both paintings/night gradient, all fifteen tent camera locations, lanterns, conditional tent holes, shot/live-bot filtering, source fire crop/frame/RNG behavior, multiplicative alpha/overlap/radius math, flash, fireworks, source fade, brightness filter, metadata immutability, repeated-build determinism, and real CanvasItem callback execution for ordinary/material passes and two-overlay lifecycle.

Run using `/usr/local/bin/godot --headless --path godot --script res://tests/test_festival_night_renderer.gd` with HOME, XDG_CONFIG_HOME, XDG_DATA_HOME and XDG_CACHE_HOME redirected to writable isolated directories. Editor import and tests must have clean engine/script/leak log scans. Headless callback tests do not validate framebuffer pixels or compile GPU shaders on a handset. No visual screenshot equivalence, export, phone performance, handset behavior or entire-stage playthrough claim is made.
