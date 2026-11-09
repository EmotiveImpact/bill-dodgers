# Hay ride painter

Implemented `godot/src/festival_hayride_renderer.gd`, an isolated subclass of the festival painter, for **3-5 only**. No host, capabilities, simulation, imported metadata or HTML changed by this painter task.

## Executable source and active assets

Source is `game/3-5/index.html`. Shared source anchors: scene painting 831–850, level ordering 950–973, oak/cutout decor 1030 onward, trailer 1096–1117, harvester 1118–1131, front 1135 onward, health 1167, detached drones 1204–1210, carrier/flying underlays 1238–1256, receipts 1276 onward, player/bot wrappers 1453–1486.

The actual metadata selects painted `lane` and `lanedusk` scenes. Their sky/far/land/ground layers contain the road and hedgerows. Eighteen `cut:oak` records alternate mirroring over the eighteen untyped low-clearance hazard rows. Procedural `drawLane`, `branch`, wheels and fallback tractor/harvester bodies are **not active** with these source assets and are not substituted. The painted trailer includes its wheels. The untyped hazard rows do not invoke the source `banner`/DUCK painter; adding eighteen synthetic warning signs would change the source. Runtime hazard hits, scene labels, warning banners and audio remain host responsibilities.

## Implemented commands and ordering

- Source lane gradient under both scenes; inherited scene sky lock, drift, mirrored parallax, far/land/ground and oak cutouts. Authoritative `dims` applies to cutouts (not raster dimensions divided by hi where rounding differs).
- Trailer deck geometry from live surfaces: painted width `(x1-x0)/0.858`, height using trailer 560:180 dimensions, top anchored at 0.469 height, 90ms bob. Tractor follows painted trailer right edge minus14, with independent70ms bob. It is inserted after checkpoint, before the host's existing finds/mid callback.
- Carrier uses source top60% of drone image, excluding parcel, at robot feet minus118. Both carrier and hanging robot rotate by `sin(levelTime/260ms+x*.01)*.06`; drone mirrors when facing right. Hanging robot walk frame1 and source110ms throw frames retained. No carrier shadow. Flat marker still draws after underlay.
- Flying drone uses full painting, source feet minus150, mirror, brightness2 flash and unchanged shadow. Pop uses ordinary robot sprite/fade **with source rotor retained**. Ground robots retain inherited pure stride snapshot, rise clipping and dizzy art.
- Departing drones use position plus direction×age×220, vertical minusage×160 minusage²×20, source direction×.12 rotation, mirror and top60% crop. At age2.6s they are omitted without modifying the collection.
- Harvester remains source painted440×238 body, top relative to live deck,80ms bob, brightness1.8 and opacity.7 flash. No invented attack animation: source lunges and death retreat are runtime x changes using the same painting. Dead body remains until runtime retires it offscreen. Health uses420px width, minimum8px, exact label, and disappears at hp≤0.
- Inherited live-surface player shadow, floor power ring, tags, checkpoint, three receipt shapes and HUD fade. Harvester and departing drones precede inherited foreground/hint. Health is placed before the shared screen wipe.

## Host/runtime boundary

Use inherited `draw_*` methods: their virtual build calls dispatch to this subclass. Select this instance for3-5 and preserve the existing source draw order. `draw_enemy`, `draw_player_back` and `draw_player_front` therefore use these builders without editing main.

Inputs are seconds-based `host.elapsed`, runtime elapsed/scenes/wipe/live surfaces, `runtime.stage_data.harvester`, and `host.festival_combat.ex_drones` with `{p,age,born,dir}`. Tests may supply `runtime.ex_drones`. Robot `stride`/`visual_move` are combat-owned. Pop detachment and departed-drone cleanup already belong to `FestivalCombat`; renderer never advances them.

Rotated textures are submitted as four-vertex textured polygons with UV crops, preserving the host's current transform. This uses standard CanvasItem `draw_polygon(points,colours,uv,texture)`, **no new blend/material layer**. A recording proxy must accept the optional UV and texture arguments; the night overlay's two-argument proxy is not a suitable wrapper for these commands. Main's Node2D accepts them directly. Flash brightness textures and inherited white-flash variants are cached, cleared by `clear_cache`.

Source trailer painting also emits random exhaust particles inside its draw callback. This renderer intentionally performs **no RNG or particle mutation**. If exhaust is required, the host must emit the equivalent particles from a simulation-owned visual-effects tick; do not add draw-time random calls. This isolated painter does not claim that host effect is integrated.

## Verification

`godot/tests/test_festival_hayride_renderer.gd`: **72 checks, zero failures**, Godot4.6.3 headless, isolated HOME/XDG/TMPDIR, strict output scan for script errors, warnings, leaks/orphans and failures (not merely exit status).

Coverage includes executable HTML numeric anchors; both scene asset sets/palette; far/road/hedge layers; all eighteen authored oaks; live deck width/height/camera snap; flash brightness/opacity; detached flight/crop; carrier mirroring/shadow/frame; fly/pop/rotor/fade; stride/rise clip; live player shadow/tag; health min/half/dead states; dead body; fade rather than iris; three receipts/checkpoint; read-only snapshot assertions; and **real CanvasItem `_draw` callbacks** including rotated/brightened textures.

This is command/numeric and rendering-API validation, not screenshot comparison, device testing, gameplay completion, visual parity certification or capability promotion. Full integrated acceptance remains the host owner's responsibility.
