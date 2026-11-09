# Rooftop artwork renderer

`godot/src/rooftop_renderer.gd` ports the painted scene in
`game/1-2/index.html`, principally `drawSky`, `drawClimb`, `drawLevel`, and the
non-debug part of `drawFront`. It is a native Godot CanvasItem renderer, not a
WebView, screenshot, generated replacement image, or collision visualization.
The original embedded artwork is loaded through the existing deterministic
importer. This module does not edit or downsample it.

## Integration

Create one renderer with `preload("res://src/rooftop_renderer.gd").new()`.
During the host's `_draw`, after applying its existing camera/1.3 zoom transform:

1. For level `1-2`, call `renderer.draw_scene(host, world_one)` instead of the
   generic preview background and grey collision strips.
2. Draw shared checkpoints, receipts, crates, coins, actors and projectiles using
   their existing systems. The renderer does not duplicate these objects.
3. After the actors, call `renderer.draw_front(host, world_one)`. It draws only
   the source delayed fire-escape hint, not obstructing foreground props.
4. Optionally call `renderer.clear_cache()` when loading a new level to release
   the per-texture filter wrappers immediately.

No child CanvasItem, secondary viewport, shader, image conversion, or transform
reset is required. Calls must run inside the host's draw callback. This renderer
is specifically for `1-2`; the caller selects the appropriate renderer.

Required host members for `draw_scene`:

- `images`: original imported `Texture2D` resources keyed by the source names.
- `meta.dims`: original `[width, height]` values; `meta.ground` is normally 482.
- `level`: source `roofs`, `ridge`, `climb` and `decor` arrays, unchanged.
- `camera: Vector2`: horizontal position and the source vertical offset.
- `view_width()` and `view_top()`: world-coordinate viewport bounds. The source
  virtual height is 540 and the zoom is already applied by the caller.
- The normal `CanvasItem` drawing methods.

`draw_front` additionally reads `mode`, `elapsed` in seconds, `hearts`,
`player: Vector2` in absolute feet coordinates, and `font: Font`.

The scene argument can be omitted for a static art preview. Otherwise it exposes
`crumbles: Array` containing `{row: [left, right, top], t: seconds, fall: seconds}`.
This is the contract implemented by `world_one.gd`. Rendering never advances or
changes this state, the imported level arrays, or the gameplay random generator.

## Source behavior preserved

- Three-stop continuous sunset gradient: `#5b4a8a`, `#e98a6a`, `#f6c27a` at
  source heights 0, 270, 540. Gradient bands use interpolated vertex colours.
- The original 1306 × 366 sky painting, alternating mirrored tiles, source
  rounding and 0.12 horizontal / 0.08 vertical parallax. Background positions
  compensate the host's world camera so they remain in the source sky space.
- Both 158 × 101 distant roof rows, at 0.30 and 0.42 horizontal parallax, with
  the second row offset half a tile and 40 pixels lower at 0.85 opacity. Haze
  gradients, the dark lower fill, and original layer order are retained.
- Original sky linear filtering and non-sky canvas nearest filtering, through
  `CanvasTexture` wrappers. Original image resources and pixel dimensions are
  unchanged; the host's own filter is not modified.
- Both climbing-house placements. The initial house has a mirrored duplicate
  to its **left**, its own shadow, and the regular unmirrored house to its right.
  The second climb is not mirrored. Their clipped repeating facade extensions,
  alley back fills, courtyard brick wall, gate and paving follow the source.
- All fourteen roof runs restart their 332 × 212 roof painting and 332 × 126
  front painting at that roof's original left edge. Facades are drawn first,
  with the source four-pixel overlap below the roof painting. Side shadows and
  the camera-bottom clip are preserved.
- Tiles crossing a roof or climbing-house boundary are cropped with matching
  source texture regions. They are never stretched to fit or painted over a
  neighbouring gap. No full-screen scaling of individual paintings is used.
- Every source chimney, aerial, tank, pigeon, washing line, landing, ladder and
  slate decoration uses its original location, native size and mirror flag.
- A slate is matched with `abs(row[0] - 6 - decor_x) < 2`. Its **decor** origin
  is retained, rather than snapping it to collision coordinates. Falling art
  moves by `fall² × 1200` pixels and fades by `1 - fall / 0.7`; it is hidden
  after 0.7 seconds. Collision rows remain untouched.
- Pixel snapping uses JavaScript-compatible `floor(value + 0.5)`, including
  negative half values. Artwork compensates the host's fractional vertical
  transform to match the source `-Math.round(camY)` translation.
- The source `bd-fixes` removal of camera foreground props remains in effect.
  The renderer never interprets `level.front` as foreground scenery. Debug
  collision lines are not enabled by this production renderer.

## Deliberate differences and validation limits

- Pre-fall slate shake is a deterministic bounded ±2-pixel oscillation instead
  of `Math.random()`. It preserves the source movement range, cannot perturb
  gameplay randomness, and freezes when scene time is paused.
- The tutorial arrow bob uses gameplay elapsed time, not browser wall time.
  Text uses the host's current font and Godot text metrics/outline. The host
  uses the original bundled Silkscreen font through Godot's native WOFF2 importer;
  exact text rasterization is not claimed.
- Godot's canvas/gradient/filter rasterization may differ from browser Canvas
  at subpixel boundaries. Mathematical source geometry and texture identity
  are tested; this is not a claim of pixel-identical output.
- The present runner cannot initialize its graphical X socket. **No screenshot
  comparison, graphical playthrough or device rendering QA has been completed.**
  Headless draw-callback execution does not validate rendered pixels.

## Focused regression suite

After the normal content import, run:

```sh
godot --headless --path godot --script res://tests/test_rooftop_renderer.gd
```

Use the repository verification script's temporary `HOME`/`XDG_*` directories
when running in a restricted workspace. The test uses a standalone host and
does not load or modify personal game saves.

The suite checks original resources and dimensions, all decoration locations,
all roof starts, layer order, clipping on both axes, mirrored cropping, source
rounding, both distant parallax rows, sky tile-boundary mirror parity, climbing
house variants, slate shake/fall/fade/reset, state immutability, missing assets,
tutorial lifecycle and foreground removal. A recording host verifies actual
draw calls and filter wrappers. A real headless Node2D exercises CanvasItem
drawing at courtyard, roof, crumble, second-climb and late-level camera points.

`build_scene`, `build_front` and `draw_commands` are separated so geometry can
be inspected without a graphical backend. They return/consume ordered commands;
they are not an alternate asset pipeline. `clipped_region` is the tested
destination/source crop helper used by every partial tile.
