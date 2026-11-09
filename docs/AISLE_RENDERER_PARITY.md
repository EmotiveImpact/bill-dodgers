# Aisle seven / Frozen foods renderer

`godot/src/aisle_renderer.gd` implements the **2-2** visual layer. It extends `supermarket_renderer.gd` without changing that file, the host, the runtime, or the native-stage registry. The painter's `supports("2-2")` is a rendering capability, not permission to award completion or save progression.

## Source inspected

- `docs/WORLD_TWO_IMPLEMENTATION.md`, including world-camera, seconds conversion, scene and hazard contracts.
- `game/2-2/index.html`: shared RNG/rounding helpers at 727–735; box/gate/plate/button/drop/ice/belt hooks at 910–980; foreground and crop/tile helpers at 1147–1168; executable 2-2 hooks at 1170–1220; draw order at 1310–1335.
- Original imported aisle, freezer and strip-door image pixels and `godot/content/levels/2-2.json`.

The three imported paintings are unchanged. The aisle and freezer are each 651×461; the strip doorway is 242×330. No substitute image generation, pixel-grid reskin, or terrain recolouring was used.

## Implemented painting and geometry

- **Background scenes:** scene 0 uses the aisle painting; scene 1 uses the freezer painting. Painting top is `482 - 0.82 × image_height - camera_y`, with the source's independent destination rounding. The aisle ceiling crops `(0,0)–(.45,.22)` to exclude the painted number 7; the freezer ceiling uses its full width. Both ceiling layers use 0.6 horizontal parallax and a height of `0.22 × image_height`. The wall and painted floor crop `(0,.22)–(1,1)` and use 1.0 parallax at original pixel dimensions. Alternating tile copies are mirrored.
- **Hanging aisle signs:** original procedural 120×150 green/gold signs, numbers 7 and 8, at 0.8 parallax, 1500px spacing and the authored 500px offset. Draw order is ceiling, hanging sign, wall.
- **Island shelving:** each authored island is 236px tall and filtered at the 10400 scene boundary. Aisle bay crop is `(.065,.46)–(.345,.775)`; freezer-door crop is `(.045,.27)–(.37,.76)`. Bays are scaled to 226px high, repeated with seed-dependent alternating reflection, and clipped to the island's width without squeezing its last bay. Source green/silver cap, side framing, dark edges, 12% interior tint, and ground shadow are retained. The painter never creates collision surfaces; the authored platform tops remain runtime-owned.
- **Strip doors:** the original image appears once at the scene boundary in scene 0, at source native scale with its 8px contact shadow. If that optional texture is absent, the source nine swaying strips and FROZEN placard are available as a diagnostic fallback, using the 500ms sway divisor.
- **Floor:** this stage does not call the shared `floorTiles` helper. Its floor is part of the original aisle/freezer painting. No generic checkerboard is drawn over it.
- **Foreground:** source low bollards at 1.3 parallax and 2300px spacing, with the requested width 34 clamped to body width 30. Aisle bollards are pale with a green band; frozen bollards are blue without a band. They do not become tall foreground pillars.

## Shared hazard visuals

`build_mid` paints controls, floor overlays, inherited trolleys if supplied, and falling objects. The inherited `draw_mid` then calls the host's pickup callback once, after these commands.

- **Sliding gates:** source 72×(height+8) shelf artwork, rails and source-rounded lift `open × (height+40)`. For the authored 560px gates this means 600px of total travel. Product widths, heights, colours, highlights and labels reproduce the source uint32 RNG, not Godot's random stream. The 560px fixture contains 31 products; geometry is cached without changing runtime state.
- **Countdown ring:** shown only if gate open is positive, held is false and remaining timer is positive. Radius 16, width 5, start angle −1.57, source sweep constant 6.283. The divisor stays **5.2 seconds**, including the half-ring at a two-human 2.6-second timer. A 6.5-second shot timer caps the ring at full. The painter does not advance gates or timers.
- **Pressure pads:** released 96×10 at y−7; pressed 96×6 at y−3, with the source five grooves. The yellow arrow flashes at 400ms intervals only when the matching gate is strictly below 0.5 open.
- **Buttons:** 44×44 bordered casing, 13px light radius and white glint. The 300ms green blink is overridden by hit-white, then by open-green when a matching gate is strictly above 0.5. The painter only reads the controller's hit timer.
- **Ice:** 6px translucent reflection line at the authored zone top with 26×2 white glints every 90px and the source modulo offset. The frozen-floor texture remains visible beneath it.
- **Belts:** source 20px frame, 24px repeating tread, direction arrows and metal endcaps are available for the shared floor hook. No belt is authored in 2-2. Tests inject a local read-only fixture to verify negative-speed wrapping without modifying the imported level.
- **Falling boxes/icicles:** warning shadow grows from radius 14 to 34 and alpha 0.15 to 0.45. The outlined exclamation flashes every 120ms at view-top+100 while age is below warning duration. At the inclusive 950ms boundary the source 64×58 seeded box or 28×70 icicle is drawn. Box bottom is rounded as in source; icicle motion keeps fractional y. Dead entities are skipped. Spawn targeting, gravity, damage and removal remain controller-owned.

Common W2 enemy drawing, security cap/tint/health, cart/drone overlays, sprite caching, pickup callback, and source scene iris are inherited from `supermarket_renderer.gd`. Player back/front hooks remain empty: 2-2 is not the 2-4 riding stage.

## Host/runtime interface

Public entry points are inherited `draw_sky`, `draw_level`, `draw_mid`, `draw_enemy`, `draw_player_back`, `draw_player_front`, `draw_front`, `draw_hud`, with overridden pure command builders `build_sky`, `build_level`, `build_mid`, `build_front` and `supports`.

The host supplies:

- `level_id`, `level`, `meta`, `images`, shared `sheets.bot`, `camera`, `player`, `elapsed`, and `font`.
- `view_width()` and `view_top()`.
- The existing bottom-anchored 1.3× world-camera transform. All returned geometry is in absolute world coordinates with source snap compensation. Reset to logical 960×540 coordinates before drawing the inherited HUD/iris.
- CanvasItem drawing methods. The local outlined-text primitive additionally uses `draw_string_outline`; the outlined control casing uses `StyleBoxFlat`. Other primitives delegate to the existing command drawer.

The runtime may be a live object or a snapshot dictionary:

- `scene_index`, `elapsed`, `hazards`, `entities`.
- Optional `hazard_controller`, with `gates`, `plates` and `buttons` arrays. These arrays may also come from a snapshot dictionary.
- Gate: `{x, floor, h, id, open, timer, held, q}`. `q` is a collider identity owned by the runtime and is not read or changed here.
- Plate: `{x, y, id, on}`.
- Button: `{x, y, id, hit}`.
- Drop entity: `{k: "drop", p: Vector2, top, vy, warn, t, kind, dead}`. `vy` is not changed. Legacy `x/y` positions are accepted for isolated source fixtures.
- Inherited iris fields: `wiping`, `wipe_elapsed`, `wipe_kind`, `wipe_label`, `wipe_focus_start`, `wipe_focus_end`.

All dynamic timers and elapsed clocks use **seconds**. Imported hazard tuples remain lossless source data; the optional belt tuple's speed remains px/ms and is converted only for its cosmetic tread offset.

If the optional hazard controller is absent, authored gates/plates/buttons are painted with closed/unpressed defaults. This fallback cannot create physical surfaces, start timers, solve a puzzle or promote a stage. A present controller with empty arrays is respected rather than replaced with fallback controls.

## Verification and limits

Passed under Godot **4.6.3**, with isolated writable HOME/XDG directories:

- `godot --headless --path godot --script res://src/aisle_renderer.gd --check-only`
- `godot --headless --path godot --script res://tests/test_aisle_renderer.gd`: **673 assertions, zero failures**.
- Existing `test_supermarket_renderer.gd`: **289 assertions, zero failures**, without editing the parking renderer or its suite.

The aisle suite checks exact crop rectangles, image dimensions, fractional/negative camera rounding, mirrored seams, clipping, scene filters, source RNG product fixtures, gate/plate/button timing boundaries, ice/drop geometry, missing-controller fallback, dictionary/live-object contracts, original META immutability, deterministic repeated draws, no global RNG consumption, inherited enemy/iris dispatch and cache cleanup. Five real Node2D draw cycles exercise both scenes and all new CanvasItem commands, including outlines, countdown polylines and the missing-strip fallback.

These are geometry/resource/command tests, **not framebuffer screenshot comparison, device rendering, performance validation, an input-driven stage clear, export verification or release evidence**. Godot's font/outline rasterization, integer StyleBox corner radii and sampled arc curves can differ slightly from browser Canvas rendering; visual comparison remains outstanding. No completed phone playthrough or device QA is claimed.

The shipped aisle/freezer images are required for painted islands. If a painting is missing, the native painter uses an explicit plain fill rather than porting the source's unused generic `shelfArt` fallback. All shipped resources are present and covered by dimension checks. This is a documented degraded-resource difference, not replacement artwork in the normal scene.

This component does not edit save support, host dispatch, hazard physics, source assets or public/deployment settings. Integration and legitimate gameplay verification belong to their respective owners.
