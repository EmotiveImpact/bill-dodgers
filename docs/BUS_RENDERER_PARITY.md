# Level 1-3 native bus scene renderer

`godot/src/bus_renderer.gd` ports the scene-specific rendering from
`game/1-3/index.html`: `drawSky`, the optional `drawBG` dim overlay,
`drawLevel` and the obstacle/warning part of `drawFront`.
It consumes the original imported resources without resampling or replacing
their pixels. No generated illustration, reduced-size intermediate bitmap,
generic platform slab or new foreground prop is used.

## Integration contract

The host supplies `images`, `meta`, `level`, `camera: Vector2`, `font`,
`view_width()` and `view_top()`. Images are the imported `Texture2D` resources.
Before drawing, apply the same bottom-anchored zoom/world-camera transform
as the existing main scene:

```gdscript
draw_set_transform(
    Vector2(-camera.x * ZOOM, 540 * (1 - ZOOM) - camera.y * ZOOM),
    0, Vector2.ONE * ZOOM)
bus_renderer.draw_scene(self, bus_ride)
# Draw gameplay actors, items, projectiles and effects here.
bus_renderer.draw_front(self, bus_ride)
```

The scene argument is an object or dictionary with these read-only fields:

- `drive`: travelled source distance in pixels, not seconds.
- `obstacles`: dictionaries with `k` (`bridge` or `branch`), `x`, and `w`.
- `scooters`: dictionaries with `x`, `y`, and `face`.
- `warn_time`: remaining warning time in seconds.

`bus_ride.gd` owns advancing those fields, collision, wave scheduling, reset,
pause and completion. Rendering never advances timers, consumes random numbers,
modifies collision metadata or changes the scene object.

`build_scene(host, scene)`, `build_front(host, scene)` and
`build_background(host, scene, dim)` return testable draw commands. Null scene
state produces the stationary level artwork. `draw_commands(host, commands)`
replays the commands. `clear_cache()` releases cached CanvasTextures when
changing levels. `town_at(host, index)` exposes the source painting selection.

`build_background` uses the same world-camera/zoom contract as all other
builders. Its optional dim overlay covers that view. It is not a separate
unzoomed menu canvas API, and this renderer does not replace the game's menus.

The bus source draws fixed arena x coordinates without subtracting `cam`;
commands compensate for the host's horizontal camera transform. Level art
also compensates for the source's `Math.round(camY)`, including negative
half-rounding. The sky is painted before the source's vertical translation,
so its commands compensate for the entire vertical camera, not just rounding.

## Preserved scene details

- The three-stop sunset has its middle stop at 55%, unlike the rooftop
  renderer's 50% gradient. Colour stops are `#5b4a8a`, `#e98a6a`, `#f6c27a`.
- The 1536×430 skyline is drawn once at `ROOFY - 390`. Its offset is
  `min(width - WV, drive * 0.006)`, rounded as in JavaScript. It stops at
  the image edge and never wraps or tiles.
- Town paintings use the original 815×620 art and source 0.7 drive parallax.
  Batch selection uses unrounded distance, while placement uses rounded
  distance before signed remainder, preserving the source boundary behaviour.
- `embank` is inserted once at batch 1. Later town indices account for that
  insertion. Single-town batches alternate horizontal reflection, including
  the embankment. The multi-town source branch does not reflect paintings
  and places the original 428×400 tree with its trunk on each seam.
- The dark street fill below the town, source 330×507 back-bridge piers,
  700×385 red bus at `[19,146]`, `round(sin(drive / 40) * 1.2)` bus bounce,
  167×150 centre-anchored scooters and translucent overhead roof shadows
  preserve their order and coordinates.
- Bridges/branches are a separate front pass after actors. The 358×132 bridge
  lip and 237×200 branch canopy retain the original offsets. The warning
  text/triangle uses the source 200 ms blink phase and gold/dark outline.
- Every scene texture uses the source 1-3 nearest canvas sampler through a
  cached CanvasTexture. This changes sampling only, not image resolution or
  asset data. The rooftop renderer's public command executor is reused for
  textures, gradients, rectangles and text, without editing that renderer.
- If images are unavailable, only the original source's bridge beam,
  branch/leaf and scooter shapes are used. The normal imported-art path
  does not use these fallbacks. Offscreen paintings are skipped, not resized.
- `bd-fixes` removed the sweeping foreground lamp/leaf layer in the original
  game. It stays removed regardless of imported `level.front` metadata.

Shared players, enemies, drones, pickups/receipts, checkpoints, HUD, particles
and gameplay effects remain the host/combat systems' responsibility. Source
`drawFront` calls shared `drawChecks()` after obstacle rendering; this renderer
does not duplicate it. The actual 1-3 source metadata contains no checkpoints.
Warning text uses the host's original bundled Silkscreen font through Godot's native WOFF2 importer. Browser/Godot text rasterization and outline placement have not received visual comparison.

## Verification and limits

Run after the repository's content import:

```sh
godot --headless --path godot --script res://tests/test_bus_renderer.gd
```

Use isolated writable `HOME`/`XDG_*` directories, as in
`scripts/verify-native.sh`, when running in a restricted environment.

The focused suite checks all 11 imported resources and full dimensions,
source sunset stops, sky position/cap, multiple town batches and reflection,
one-off embankment, multi-town join trees, bus bob, obstacle front/back layering,
scooter reflection, shadows, fractional camera math, warning blink/text/arrow,
missing-image fallbacks, state immutability and native CanvasItem draw calls.

Headless draw callbacks and command geometry are not screenshot comparisons.
Graphical screenshot QA is unavailable in this runner after its X socket
setup failed. No visual-perfect, normal-input full-level, difficulty,
mobile performance or device-export claim follows from these renderer checks.
Integrated progression and normal-input full-run validation remain separate
acceptance gates.
