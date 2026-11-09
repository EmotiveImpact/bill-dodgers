# Stockroom renderer parity

Implemented 2026-11-09 in `godot/src/stockroom_renderer.gd`. This is a source-grounded painter for **2-3 only**, extending `aisle_renderer.gd` to reuse the common World 2 controls, belt/drop art, bots, pickup callback and scene iris. No changes to shared painters, physics, main routing, registry, save validation or stage completion are included in this chunk.

## Source and coordinates

- Stage drawing: `game/2-3/index.html:1170–1271`.
- Shared art: `blockArt`/`drawBelt` at 963–979; `fgPillars`, `crop`, `tileRow` at 1147–1168; shared drop drawing at 941–945.
- Imported data and original images: `godot/content/levels/2-3.json`, including `stockroom` (868×614), `mezz` (1186×706), `glift` (329×380) and dormant `pallet` (240×268).
- Runtime contract: `docs/WORLD_TWO_IMPLEMENTATION.md`. World pixels remain source-sized. The host provides the 1.3× bottom-anchored transform, camera, source metadata/images, and seconds-based runtime clocks. Source rounding remains `floor(value + 0.5)`, including negative values and fractional camera offsets.

The source images were inspected directly. The painter uses those original imported paintings and their source crops. There is no low-resolution replacement scene, pixel-grid overlay, new tileset or enlarged image-derived collision geometry. Nearest sampling matches the original canvas's disabled image smoothing, not an additional pixelation effect.

## Implemented composition

### Sky and both scenes

- Downstairs: full-width stockroom roof crop 0–17% at horizontal factor 0.3; the remaining 83% at 0.55; top anchor `482 + 10 − 0.8 * image_height − camera_y * 0.5`; original dark overlay after both layers.
- Upstairs: original mezzanine roof 0–30% at 0.6, racking 30–86% at 0.85 and mesh floor 86–100% at 1.0. The source 90%-height anchor, rounded crop offsets and alternating horizontal mirrors are preserved.
- Missing-mezz fallback retains the source reduced stockroom wall, darker overlay, 300-pixel truss spacing, hanging lamps, yellow rail and kick plate. The lamp glow uses the source's two different radial-gradient centres, clipped to its 300×400 fill area. Its generated texture is cached separately from simulation state.
- Missing stockroom painting returns the source dark background fill, including when mezzanine art exists.

### Racking, stock and traversal art

- All six authored towers are painted: `(3000,4400,360)`, `(4650,5600,240)`, `(6000,7400,240)`, `(7700,8800,360)`, `(10500,11700,480)` and `(12100,13000,360)`.
- Rack rows use original stockroom crops A `(141,200,293,98)`, B `(141,298,293,87)`, and top beam `(141,182,293,18)`. Rows remain 120 pixels high and 359 pixels wide before clipping. The source row-dependent alternating crop/mirror sequence is preserved, along with blue uprights, the 16-pixel painted deck and 6-pixel base.
- Wrapped stock uses original crop `(278,390,143,77)`, with 110-pixel rows and 204-pixel tile width. Mirror phase continues across rows. Partial right and upper tiles crop the correct source region; they are not compressed to fit.
- The painter treats source offscreen art canvases as clip bounds. This also preserves the 5-pixel top row on the authored 115-pixel stock platform, clipped pallet boxes/highlights/feet and the last goods-lift fallback stripe.
- All 19 authored one-way platform rows are considered. Actual runtime surfaces take precedence when supplied. Empty-end-bay uprights, bolt slots and orange beams keep the source 156-pixel width and exact tower-side alignment. Conveyor platform rows do not receive an extra ladder paint pass. Nearby independent ladder rows still paint, including the source overlap near 7400–7700.
- The three source belts use their original mid-layer tread animation, directions and arrows. This painter supplies the paired blue support legs down to the floor.
- The 9000–9440 hoist opening remains separate from both floor segments, with alternating 24-pixel outer-edge safety bands. Downstairs concrete markings and upstairs paired grating rows are scene-dependent.
- Both gap platforms `[9110,9200,452]` and `[9270,9340,422]` have source chains starting at visible-top minus 10. Their platform art calls the procedural pallet equivalent. The imported `pallet` image is deliberately not drawn. These are static paintings, not pendulums, moving collision bodies or time-driven platforms.
- The original `glift` painting is anchored at `scene_x − 20 − image_width/2`, `482 − image_height + 4` and appears downstairs only. Its 200×380 procedural fallback is also preserved.

### Shared layers and foreground

- `build_mid` is inherited from the aisle painter and reads `runtime.hazards`, `runtime.hazard_controller` controls and `runtime.entities` drops. Warning shadows use their stored landing tops, including elevated rack tops; warning flashes precede the falling 64×58 source box at the inclusive 950 ms boundary.
- Bot/security/drone drawing, pickups and the “Top floor” iris remain shared. Player back/front calls remain empty; no trolley-ride wrapper is added.
- Foreground uses the source low 30×46 bollards with dark fill, blue highlight and yellow safety band at the bottom edge. No tall foreground columns obscure the climb.
- Drawing is read-only. It does not change runtime clocks, hazard state, source metadata or simulation RNG.

## Interface and integration boundary

The inherited renderer API remains `supports`, `draw_sky`, `draw_level`, `draw_mid`, `draw_enemy`, `draw_player_back`, `draw_player_front`, `draw_front`, `draw_hud`, and command builders `build_sky`, `build_level`, `build_mid`, `build_front` plus shared bot/HUD builders. The only supported ID is `2-3`.

`build_level` accepts the live `runtime.surfaces(host)` provider, a snapshot `surfaces` array of `{row, plat}`, or the immutable authored `level.plats` fallback. Present empty surface arrays remain empty. Runtime `scene_index`, `elapsed`, `hazards`, `entities` and the existing hazard-controller shape are unchanged.

The source `sceneLand: 0`, landing/camera behavior, movement, gap recovery, hazard damage and actual level completion remain runtime-owner responsibilities. This renderer does not substitute a default landing distance or invent a lift platform. The source debug surface overlay is not enabled as production art.

## Verification

`godot --headless --path godot --script res://tests/test_stockroom_renderer.gd` passes **714 assertions, zero failures**, using Godot **4.6.3** with isolated writable HOME/XDG directories.

Existing renderer regressions also pass without shared-file changes: supermarket **289**, aisle **673**, and shopping street **687** assertions, all zero failures. The parent integration owner retains aggregate-suite registration and full-project/package verification.

Coverage includes original dimensions and crop rectangles, background parallax/mirror phases across fractional cameras, original-resolution band sizes, all six tower coordinates, clipped/scaled tile ratios, left/right ladder alignment, three belt support/paint boundaries, both scene floors, exact gap and pallet geometry, live surface precedence, drop timing/landing shadows, lift visibility/fallback, foreground colors/heights, inherited bot/iris methods, read-only state/RNG and cache cleanup. Actual headless `Node2D._draw` callbacks execute the renderer across nine stockroom/mezzanine views and both missing-asset fallback branches, including textures, polygons, text, warnings, shared sprites and the scene iris.

These checks certify command geometry and native draw dispatch. They are **not** screenshot comparison, visual device QA, performance certification, a legitimate controller-driven clear, completion support or Android/iOS export validation. Those remain integration/release responsibilities.
