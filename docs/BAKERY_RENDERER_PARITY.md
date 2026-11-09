# Bakery renderer parity

`godot/src/bakery_renderer.gd` is the isolated **2-5 Bakery** painter. It extends `aisle_renderer.gd` to reuse the shared World 2 control, belt, drop, trolley, enemy and iris helpers. This module itself does not enable a stage, change runtime physics, award a card, or write progress.

## Source audit

Read `game/2-5/index.html:1170–1229`, the shared `lvDrawMid`, `blockArt`, `drawBelt`, `crop`, `tileRow`, `fgPillars`, and the source draw order. Compared the authored geometry in `godot/content/levels/2-5.json` and the bakery requirements in `WORLD_TWO_IMPLEMENTATION.md`. Visually inspected all four original imported paintings: bakery 651×461, swing 277×320, table 165×116 and wet sign 71×86. No original resource was modified or resampled.

## Painting and geometry

- The bakery background preserves the original pale fill, green ceiling fill and three independent bands: roof `(0, 0, 651, 32)` at 0.4 parallax; pipes `(0, 32, 651, 28)` at 0.7; wall at 1.0. Scene zero uses `(23, 60, 368, 401)` for ovens/racks, scene one `(293, 60, 358, 401)` for the deli. Band heights, independent crop rounding, alternate mirroring, fractional camera rounding and the `ground − 0.82 × image height` anchor follow source. No replacement grid covers the painted floor.
- Ovens use `(85, 138, 215, 191)`, resized to 281×250, centered at each authored oven x + 120, bottom at ground − 4. These centers coincide with all 13 flame hazards. Ovens are painted before the conveyors and only in the bakehouse scene.
- Worktables keep the original 165×116 image and 159-pixel stride, alternating reflection, at y = 370. The source's final table can overhang the logical counter range; it is not clipped or compressed. If the table image is absent, the source steel table/tray/dough fallback is available.
- The climbable rack uses `(296, 152, 88, 177)`, resized to 96×194 and repeated at x = 7500 and 7596, top y = 292. It appears only in the bakehouse.
- Deli counters use `(384, 184, 267, 138)` resized to 224×116, top y = 366, plus the original top trim at y = 362. The last tile is clipped, not squashed. A clipped mirrored tile uses the right edge of the original crop. Counters are selected on the appropriate side of the scene boundary.
- All four authored elevated conveyors retain three ground-reaching legs, feet, a brace at 55% of the support height, bed, rails, 24-pixel roller animation and 120-pixel bread animation. The common belt surface is drawn later in the mid layer, as in source. Speeds remain source px/ms and the painter converts host seconds to milliseconds. Negative movement wraps both periods correctly.
- The original swing painting is centered on x = 9400 and ends at ground + 4. It is hidden after the transition; its source procedural fallback retains the separate 260×320 canvas and ground anchor. The shared iris and actual label **Shop floor** are inherited. Scene movement and the landing at x = 9820 / y = 370 remain runtime responsibilities.
- The authored flour zone spans x = 10800–12200 with its white floor strip, 60-pixel-spaced mounds, tilted sack, label and adjacent spill. Source has no player flour tint, so none is invented.
- The two wet-floor signs preserve the original 71×86 image at x = 12600 and 14250. Those visual dimensions intentionally differ from the 62×84 collision tuple. The original triangle fallback uses a 70×88 canvas only when the image is missing.
- Foreground remains the source low, pale 30-pixel-wide bollard with green band in both scenes and alpha 0.94. No full-height pillar occludes play.

## Flames, ordering and state

`build_mid` retains source hazard order, then shared entities and the single host pickup callback. Controls and entity helpers receive read-only temporary snapshots so their common belt pass is not painted twice. The stage-owned conveyor art remains in the level pass, behind ordinary crates and the shared mid layer.

Every bakery animation reads **host.elapsed**, the source `levelT` equivalent. A stale or different `runtime.elapsed` cannot shift a flame or conveyor. The renderer's static `flame_phase(hazard, elapsed)` returns source **milliseconds**; this is an internal painter helper, separate from the course controller's seconds-valued helper.

Flames preserve:

- authored 2600 / 2200 ms periods and offsets;
- a warning only when phase is strictly greater than period − 700 ms, with 90 ms red/orange blinking from the global level clock;
- active strips only below 1000 ms, growing during the first 150 ms and shrinking after 850 ms;
- nine strips, the four original colors, 40 ms width oscillation, and visual height 175 × ramp;
- the source ten-pixel oven-door offset, so the maximum painted tip is 185 pixels above the hazard floor even though gameplay harm height is 175;
- `L.noGrate = true`: only a 68×5 translucent shadow below each jet, never floor grates.

The high double-jump card remains at the authored `(8850, 232)` and is painted by the shared host. This painter never duplicates it or grants it. No renderer method moves players, changes hazards or scenes, advances clocks, calls global RNG, emits simulation particles, or modifies imported metadata or saves.

**Deliberate deterministic difference:** source `drawLevel` randomly appends rising flour dust to `parts`. That render-count-dependent particle emission is omitted. The visible source flour coating, mounds and sack are retained. Any future dust belongs to a separately owned cosmetic system, not the gameplay RNG or draw pass.

Texture rendering reuses the parent's original-resolution, per-texture nearest sampler, matching the source canvas's `imageSmoothingEnabled = false`. There is no extra pixel-grid shader, downsampling or new painting. This preserves source sampling; visual/device quality is not certified by a headless test.

## Verification

With isolated writable HOME and XDG paths, under Godot **4.6.3**:

```sh
godot --headless --path godot --script res://tests/test_bakery_renderer.gd
godot --headless --path godot --script res://tests/test_aisle_renderer.gd
godot --headless --path godot --script res://tests/test_supermarket_renderer.gd
```

- Bakery: **1,072 assertions, zero failures**.
- Aisle regression: **673 assertions, zero failures**.
- Shared supermarket renderer regression: **289 assertions, zero failures**.

The bakery suite checks original image dimensions, exact crops, positive/fractional camera coordinates, parallax and scene filtering, clipped/mirrored deli tiles, authored support heights and overhangs, source fallback geometry, bread/roller periods, flour/wet geometry, flame warning/ramp boundaries, no-grate rendering, shared callback order, host-clock authority, no mutations or RNG consumption, bots, iris and cache cleanup. It also executes the actual renderer through Node2D draw callbacks across both scenes and the missing-image fallbacks.

These results are command/geometry and real callback checks only. No framebuffer comparison, screenshot parity, physical Android/iOS run, full stage completion, export, deployment or release is claimed here. Integration, progression and full-run evidence belong to their separate tests and documents.
