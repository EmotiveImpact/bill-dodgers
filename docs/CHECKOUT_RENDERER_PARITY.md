# Checkout painter: source composition and verification

Status: isolated painter implemented and verified in Godot 4.6.3 on 2026-11-09. This document covers painter command geometry and real headless CanvasItem callbacks. It does **not** claim screenshots, visual review on a device, playability, complete gameplay, export or deployment. Runtime integration and progression acceptance are owned separately.

Files:

- `godot/src/checkout_renderer.gd`
- `godot/tests/test_checkout_renderer.gd`
- This document

## Source and interface

Evidence is the executable `game/2-6/index.html`: till art 1178–1198, TB and its geometry 1200–1286, original boss mid/foreground/HUD 1287–1325, checkout painting/lanes 1327–1353, the second mid wrapper 1356–1367, jar icon 267–274, drawJar 1426–1430, and world draw order 1455 onward. Shared crop/tile and low foreground helpers are 1147–1168. Stale comments describing barcode attacks or stock rain do not authorize adding either.

The painter extends `aisle_renderer.gd` to reuse shared belts, controls, entities, W2 bot art, texture filtering, white hit flash, primitive commands and scene iris. It supports only `2-6`. All inputs are read-only. Timers are seconds, coordinates absolute world pixels, and the host supplies the existing bottom-anchored 1.3× world camera.

The normal callback interface is unchanged:

- `build_sky/level/mid/front/hud(host, runtime)` and inherited `draw_*` methods.
- `build_checkout_mid(host, runtime)` isolates TB commands from shared mid commands.
- `draw_mid(host, runtime, pickups)` explicitly draws shared mid, calls pickups once, then draws TB, paper steps, every boss-crate state and every bag. The source places `drawPicks()` before `L.mid()`. `build_mid` returns the combined command list without running callbacks.
- `build_jar/draw_jar(host, runtime)` is the one extra host seam: call after enemy actors, before player wrappers/sprite. It must not run in generic `host.boss` drawing.
- `build_player_back/front` returns empty arrays. Inherited draw wrappers do nothing. Bags and carried crates already draw in source mid order and must not be repeated over the player.

Runtime state comes from `runtime.checkout.snapshot()` or a detached snapshot dictionary with `boss`, `jar` and `players`. If runtime is omitted, the painter finds `host.world_two.checkout`. It never reads generic `host.boss`, runs input/physics, changes progress, or consumes random numbers. It reads `host.elapsed` for source `levelT` visual animation, and the controller's seconds for beam/down/jar clocks. Shared W2 hazard commands retain the existing runtime elapsed contract.

A posed boss command contains local art commands plus its source transform. The executor temporarily composes that pose with the existing 1.3× world camera, then restores the world transform before paper, crates, bags, enemies or players. HUD commands use logical 960×540 coordinates after the host resets its transform.

## Original paintings and exact placement

The required imported resources are retained without substitutes:

- Checkout: 651×461. Crop bands are `(0,0,651,46)`, `(0,46,651,76)`, and `(0,122,651,339)` at parallax `.4`, `.7`, and `1`. Independent source start/extent rounding is preserved. Only the first two bands alternate mirrored tiles; the final band's lane numbers remain readable.
- Boss: 404×400, fitted to 364×360 and centered at local x13 in the original 390×360 till canvas. Canvas origin is `(4565,132)`, making the actual fitted image start `(4578,132)`. The painting is not stretched to the 250×340 logical body.
- Boss screen overlays: local `(150,50,108,68)`, world `(4715,182,108,68)`. Painted tray geometry remains `(4816..4935,354)` in the original image, rather than a new procedural tray or collider.
- Crate0/1/2: 64×73, 64×62 and 64×75, drawn at original size from bottom-center `p`. All `fall`, `ground`, `carry`, `fly`, and `on` states share this anchoring; only falling crates add a 30×6 radius ground shadow. The target at x4906 is intentionally not clamped to world width4900.
- Five checkout lanes retain the cropped row `(20,256,436,101)`, scaled to380×88 at ground−96, alternating mirrors, original hanging numbered signs and row shadows. The arena has the original738×6 yellow stripe with nineteen alternating dark20px bands.

The original painting supplies the angry face. Phase2 adds an amber glaze; phase3 adds a red glaze. Frozen takes precedence and flashes the red ERROR screen on the source250ms clock. Hit flash whitens the painting by70% without whitening newly drawn overlays. Mouth glow and its pale core keep their original rectangles.

Down state preserves crossed eyes, sink `min(60,t×50)`, rotation `min(.1,t/6)` about local `(195,340)`, and opacity `max(.35,1−t/2.5)`. Empty source `codes` and `dizzy` stay empty/inactive. The painter tolerates these inherited fields but never creates attacks or activates them.

Missing imported art has a neutral/degraded procedural fallback rather than an unrelated substitute image. Those missing-asset fallbacks are not a claim of full source visual parity; shipped assets and their exact dimensions are asserted in the tests.

## Scanner, receipt, bags, jar and HUD

- The high/low window tell is66×12 at world x4711 and y258/272, alternating every150ms while fight-state beam time is below900ms.
- The front warning flashes every120ms below900ms, from the left screen edge to `round(tillLeft−camera.x)`, with the source Jump!/Duck! instruction. Active red has20/8/2px layers.
- At exactly900ms the front switches to red, while controller harm remains strictly after900ms. At1450ms the beam becomes invisible. These visual/collision boundary differences are intentional source behavior.
- All three90×14 paper steps retain `(4385,412)`, `(4465,347)`, `(4545,282)`, their shadows, printed lines and edges. The curved white6px feed uses the original quadratic endpoints/control point. Controller receipt surfaces and painter positions are compared directly.
- All bagged participants draw before sprites: the full-height `.8` bag silhouette, both green handles, and the `.45`-height green logo. Bag drawing does not move the player, hide the sprite, or depend on a health-damage result.
- The completion jar uses the source shared procedural icon at scale2, unrounded world x, a140ms vertical bob,100ms glow pulse and no bob/glow once collected. It draws after helpers and before players.
- Source boss HUD remains at the bottom:428×26 outlined frame at `(266,496)`,420×18 health fill at `(270,500)`, and left-aligned “Giant self-checkout” at `(278,484)`. It disappears only when TB is absent/down. Shared scene iris remains available without inventing a checkout transition.
- Foreground approach bollards remain low30px art with the source1.3 parallax/red band. The source `until` limit removes them from the boss arena.

The source occasionally emits smoke particles and consumes `Math.random` during down-state painting. This renderer deliberately omits that draw-time effect so repeated renders cannot modify the simulation or its random sequence. This is a documented cosmetic difference, not a newly invented deterministic attack or gameplay effect.

## Verification

Run from the repository root:

```sh
HOME=/tmp/godot-checkout-painter \
XDG_DATA_HOME=/tmp/godot-checkout-painter/data \
XDG_CONFIG_HOME=/tmp/godot-checkout-painter/config \
godot --headless --path godot --script res://tests/test_checkout_renderer.gd
```

Result: **542 assertions, 0 failures** with Godot4.6.3. Assertions cover original resource dimensions, source crop regions/parallax/mirror policy, fractional camera snapping, all five lanes, exact boss/tray/screen placement, phase/frozen/mouth/flash/down layers, both scanner heights and exact warning/red/expiry boundaries, all crate states, paper/controller geometry, bags, jar, source HUD, foreground exclusion, generic-boss separation, callback ordering, detached/live snapshots, no state/geometry/RNG mutation and cache cleanup.

Actual Node2D `_draw` callbacks exercise nine states: approach, enter, low warning, high warning, active beam, frozen hit flash, phase3 stairs, transformed down and jar. They include shared security-bot drawing and verify pickups → checkout mid → enemy → jar → player → front beam → HUD ordering. This is drawing-API execution evidence, not screenshots or mobile-device validation.
