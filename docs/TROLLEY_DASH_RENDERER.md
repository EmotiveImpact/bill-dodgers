# Trolley dash renderer

Implemented in `godot/src/trolley_dash_renderer.gd`, extending the shared aisle/supermarket painter. This module supplies 2-4 drawing only. Capability promotion, camera/controller integration, sprite positioning, input-driven completion and saved progress are owned by the host integration, not by this renderer.

## Source contract

The implementation reads the actual `game/2-4/index.html`:

- Lines 1170–1212: aisle selection, ceiling/sign placement, boundary posts, floor speed lines, elapsed/par/progress HUD and foreground bollards.
- Lines 888–910 and 1231–1244: trolley geometry and the rear → raised player sprite → clipped front sandwich.
- Lines 913–948 and 959–974: low signs, block variants, boost arrows and autonomous trolleys.
- Lines 1053–1068: ceiling and `painted()` placement. Source images are the six original 651×371 JPGs referenced by `content/levels/2-4.json`.
- `WORLD_TWO_IMPLEMENTATION.md`: source units, immutable hazard tuples and the variable-camera ride contract.

Painting selection uses each tile's world origin: `max(0, floor(tile_x / 3200)) % 6`. The full image is drawn at its original 651×371 size, without mirroring, cropping, downsampling or an added pixel-grid effect. Floor alignment uses `.777 × image height` and the original screen rounding. The visual aisle change consequently occurs at the first tile boundary after each 3200-pixel threshold. Ceiling lights move at 0.6× camera speed, numbered signs at 0.8×, and bottom bollards at 1.25× every 3100 pixels.

The painted floor stays intact. Its 60×3 white speed lines repeat every 180 world pixels and follow camera position. No new speed-dependent streaks or moving-deck geometry are introduced.

## Layers and interfaces

`draw_sky`, `draw_level`, `draw_mid`, `draw_enemy`, `draw_player_back`, `draw_player_front`, `draw_front` and `draw_hud` retain the shared renderer interface. Each local pass has a pure `build_*` counterpart returning draw commands. Existing shared bot/security/cart/drone art and scene iris helpers remain inherited. `draw_mid` calls the supplied pickups callback exactly once after obstacles and autonomous trolleys.

World commands use absolute world pixels and the existing host's bottom-anchored 1.3× camera transform. HUD commands use logical 960×540 UI coordinates after that transform is reset. `camera.y - source_round(camera.y)` preserves source vertical snapping on world layers; sky/ceiling commands retain source screen-space behavior.

Player wrappers accept the existing `draw_player_back(host, host.player)` / `draw_player_front(host, host.player)` calls, where `host.player` is a `Vector2` of absolute feet. They read host face, grounded state, player animation, hearts and elapsed time. A dictionary with `p`, `face`, `on_ground`/`grounded`, `act`/`animation` and `down` is also accepted.

Required host sandwich:

1. Draw the trolley rear at rounded `(player.x - 60, feet - 104 + bob)`, using source 0.95 alpha.
2. Draw the player sprite with feet shifted upward by exactly 30 pixels. Do not alter player physics, collision feet, support surfaces or projectile origins.
3. Draw the trolley front only in its source 120×30 strip, starting 12 pixels below the trolley image origin, equivalent to `feet - 92 + bob`.

Bob is `sin(host.elapsed × 1000 / 60)` only for grounded running players. Down players have no trolley wrapper. The front is clipped as geometry, including stroke width and mirrored handles, so no clipping or transform state leaks into the host. Its wheels, lower frame and basket base do not cover the sprite. Source draw-time random dust is deliberately omitted: drawing never consumes gameplay RNG or creates particles.

## Hazards and runtime state

All 36 blocks, 14 low signs and seven boost zones are read unchanged from `runtime.hazards`, falling back to `host.level.hz`. The renderer does not create hazard colliders or supporting platforms.

- Wet signs use source 70×88 procedural art because 2-4 ships no `wet` image. The existing painted-image branch is supported if supplied.
- Pallets retain nine box pieces, including the clipped top row. Cones keep both cones and their barrier. Procedural art is clipped to the source offscreen-canvas dimensions, including negative/top/right overflow.
- Low signs end at `floor - clearance`, keep source 120×64 art and all three palettes, with their ceiling rods.
- Each 800-pixel boost has 12 chevrons at 70-pixel spacing. Its alternating colour uses source 120 ms phase and world-x offset.
- Autonomous trolleys come only from `runtime.entities`; shared painting preserves direction, feet anchor and source 50 ms wobble. The renderer does not spawn, update or despawn them.

`runtime.course_controller` may be an object or dictionary. Its `boost` flag controls the HUD outline and label. All visual elapsed clocks use `host.elapsed`, the source `levelT`, rather than the potentially later-updated general runtime clock. `course_controller.speed` remains a physics/controller value in pixels per second; the source HUD does not display it. No countdown, par-time defeat, fixed arena or moving deck is invented.

The HUD shows floored elapsed `m:ss`, the literal `par 3:30`, the 250 ms flashing “Reduced aisle! Faster!” label while boosted, and progress `min(1, camera.x / (world_width - view_width))` with the source 30×26 trolley icon. It remains available during play and clear, and continues counting after 3:30.

If one secondary aisle painting is missing, source `aisle0` is used. If `aisle0` itself is missing, an explicit neutral fill is shown rather than unrelated replacement art. The obsolete source procedural shelf fallback is not reproduced; shipped original painting availability is covered by tests.

## Verification

Run from the repository root:

```sh
HOME=/tmp/bd-godot-home \
XDG_CONFIG_HOME=/tmp/bd-godot-config \
XDG_DATA_HOME=/tmp/bd-godot-data \
XDG_CACHE_HOME=/tmp/bd-godot-cache \
godot --headless --path godot --script res://tests/test_trolley_dash_renderer.gd
```

Godot 4.6.3: **1,964 assertions, zero failures**. Coverage includes:

- All six original image sizes and full source regions; modulo-six selection, fractional-camera rounding, ceiling/sign/layer order and tile-seam posts.
- Every authored block, low sign and boost; exact art bounds, clipped pallets/cones, warning geometry, palettes and clocks.
- Autonomous trolley state, dead removal, layer order and pickup callback.
- Both player facings across idle/run/crouch/jump/shoot, grounded and airborne; source rear alpha, bob, exact front clipping, full-thickness mesh, host `Vector2` and participant dictionary contracts, and down/clear behavior.
- Elapsed/par/boost/progress HUD, source clock vs stale runtime clocks, object/dictionary course states and continued timing past par.
- Immutable metadata, hazards, actor/camera state and untouched global RNG; deterministic repeated commands and inherited cache cleanup.
- Seven real headless `Node2D._draw` callbacks exercising every hazard kind, player layers, images, shared security bot, text and iris.

These are command/geometry and headless CanvasItem checks, not screenshot, device or input-driven full-stage verification. There is no commit, deployment or visibility change in this renderer work.
