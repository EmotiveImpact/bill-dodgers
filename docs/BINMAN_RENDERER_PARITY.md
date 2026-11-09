# Native Binman Bot rendering

`godot/src/binman_renderer.gd` renders the level 1-6 boss in Godot. Its
reference is the gameplay in `game/1-6/index.html`, specifically
`sceneBossDraw`, `drawBinmanShape`, `drawBin`, and the boss health-bar block
inside `drawWorld`. There are no `binBody` or `binrender` functions in this
version of the level source.

This is a source-geometry port, not a claim of screenshot, device, or complete
gameplay parity. Boss simulation and the painted street are separate modules.

## Preserved source artwork and geometry

The original 1-6 metadata contains `st0`, `st1`, `st2`, and `drone` images,
but **no Binman or thrown-bin sprite sheet**. The web game therefore uses its
procedural fallback. This renderer implements that actual fallback, rather
than reusing the Jar Thief or displaying a generic collision rectangle:

- The 210-pixel-wide, 300-pixel-tall pose has separate brown boots, dark green
  shell, inset green panel, orange reflective stripe, and yellow highlight.
- Six ribs on each arm and the active hand retain the original signed-width
  geometry, facing direction, arm pivot, throw/roll windup, and idle swing.
- Enter/walk boot oscillation is `sin(t / 0.12) * 6`; throw/roll arm windup
  reaches 1.6 radians over 0.4 seconds. Slam has the source idle arm swing.
- The mouth grows with lid openness. The two yellow eyes and 70-pixel
  translucent glow appear strictly above lid openness 0.3, in the original
  eye/glow/lid paint order. The lid rotates up to 1.2 radians at its hinge.
- Defeat rotates the complete procedural body, including limbs and lid, by
  up to `-0.35 * face` radians over 0.5 seconds. The shadow and axis-aligned
  hurt flash remain outside that rotation, matching the source.
- Each shockwave has four cream rectangles with the original direction,
  heights, offsets, and 0.05-second sine motion. Rolling-bin AI markers are
  skipped, so they never create a second shockwave.
- Airborne and rolling wheelie bins rotate their body, panel, lid, and two
  wheel centers together. Recycling rain keeps all three source colors,
  36-by-28-pixel rectangles, and translucent highlights.
- The source health HUD is in unzoomed 960-by-540 coordinates: a rounded
  frame at `(266, 496, 428, 26)`, 420-pixel proportional fill at `(270, 500)`,
  and the left-aligned `Binman Bot` label at `(278, 484)`. Defeat hides the
  entire bar and label. It uses the host's original Silkscreen WOFF2 font.

The source JPEGs, PNGs, fonts, metadata, and web game are unchanged. No art is
downsampled, replaced, rasterized into a low-resolution buffer, or sent through
a pixel-grid effect. The street renderer owns the painted 1-6 background.

## Runtime contract

- `draw_world(host, boss)` runs inside the host's world camera/zoom transform.
  `draw_hud(host, boss)` runs after the host restores UI coordinates.
- `boss` may be the runtime object with a `state` dictionary, or that dictionary
  directly. `null` and an empty dictionary draw nothing.
- The state supplies `x`, `fy`, `state`, `t`, `face`, `flash`, `lid`, `lid_t`,
  `hp`, `max`, `dizzy`, `waves`, `bins`, and `rain`. Times are **seconds** and
  positions are absolute world pixels. `fy` falls back to the metadata ground.
- The host supplies `camera`, `images`, `meta`, and `font`. The renderer never
  replaces or resets the host's canvas transform. Rotation is applied to
  geometry mathematically, including texture vertices when sprites exist.
- World X snapping reproduces `Math.round(worldX - camX)` under the native
  world transform. World Y compensates for the source's independently rounded
  camera. Negative half values use JavaScript rounding rather than Godot's
  different default rounding.
- Pure `build_world_commands` and `build_hud_commands` methods expose the draw
  plans for regression tests. Drawing never advances time, consumes random
  numbers, mutates state, removes hazards, or changes level metadata.
- `clear_cache()` releases cached texture wrappers at a level change.

The optional original `binman` atlas branch is also implemented for metadata
that supplies it: four native-size frames per row, source 160/210ms animation,
walk/throw/open rows, facing flip, defeated pose, and its separate hurt-flash
geometry. The optional original `bin` image uses its full native dimensions.
These branches are tested with synthetic resources, not claimed as artwork
present in the game. They do not use a substitute character image.

## Deliberate repairs and rendering limits

1. The source optional sprite branch can select a negative open-frame index
   when a backup event opens the lid for 2.4 seconds. The native branch clamps
   this to frame zero. The present procedural source is unaffected.
2. The source health helper's fixed arc radius can cross its own edge at very
   low HP. The native fill retains the exact proportional width while reducing
   only its corner radius when needed to form a valid simple polygon.
3. Ellipses/circles use 64-point polygons, and HUD corners use eight segments
   per quarter-circle. These preserve source bounds and colors but are not a
   pixel-identical browser Canvas rasterizer. Font outlines use Godot's integer
   outline size. Antialiasing and text rasterization still need visual review.
4. This renderer does not independently decide whether hazards are dead or
   offscreen. The simulation owns their removal, as in the source.

## Verification

Run from the repository root after importing the content:

```sh
godot --headless --path godot --script res://tests/test_binman_renderer.gd
```

The focused suite passes **159 assertions** on Godot 4.6.3. It checks every
procedural pose in both directions, source coordinates/colors, camera snapping,
lid thresholds, articulated arms, down rotation and flash, moving hazards,
layer order, deterministic paused plans, health states, font and imported image
dimensions, and optional original texture frame/UV behavior. A real Node2D
draw callback exercises every pose and the optional texture branches without
Godot script/drawing errors.

This is headless geometry/resource/API verification only. No screenshots,
human visual comparison, iPhone/Android render or performance tests, or
difficulty/full-game completion claims are implied.
