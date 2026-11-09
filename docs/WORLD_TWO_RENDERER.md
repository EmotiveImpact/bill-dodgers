# World 2 parking renderer

`godot/src/supermarket_renderer.gd` implements the **2-1 Car park** visual layer. This document does not promote another stage, validate a level clear, or claim screenshots, mobile rendering, performance, exports or releases.

## Source and supported content

Audited the executable `game/2-1/index.html` shared drawing hooks and stage hooks, plus `game/polish.js` parallax and iris code. Inspected the actual imported `topdeck` and `carpark` paintings. Original imported resources remain unchanged.

- Top deck: source 0.164–0.493 horizontal sky/town crops, separate 0.05/0.2/1 parallax, 0.47 deck cut, native texture dimensions, mirrored tile alignment and all three restored lamp heads.
- Surface scene: 0.262-width plain frontage at 0.3 parallax, source drifting sky strip, floor/bay lines, lamps/glow, one entrance at doors 15580, and the painted lift at scene boundary 7600. Cars and shelters are filtered by scene. Car roofs remain exclusively runtime collision data.
- Runaway trolley: original 120×106 procedural wire basket, 14 mesh lines, handle, frame and wheels; direction reflection and 50 ms sine wobble. Reads absolute feet/velocity and second-based age. Runtime owns warnings and spawning; renderer cannot activate a spawner or damage a player.
- Enemies: shared bot sheet with source movement-stride frames, pop fade and 70% white flash, cart overlay, drone propeller/red marker/ground shadow, security 1.66× scale/tint/uniform stripe/peaked cap/health bar. No Bailiff attacks, substitute drone image, or render-time mutation of enemy animation.
- Foreground: source low bollards only. No full-height pillars.
- Iris: source 0.52 s close, 1.05 s labelled hold, 0.6 s open; fade/label timings and captured departure/arrival focus. Runtime alone owns the 1.43 s scene callback. Pure plans at the callback remain fully covered, and the overlay is absent at 2.17 s.

Texture sampling uses per-texture nearest-filter wrappers, without changing host CanvasItem state or source textures. Cached sprite variants preserve transparency. Original Canvas source-atop tint is reproduced numerically to 8-bit image precision. Soft radial gradients use 96-segment vertex-colour rings, rather than a new raster painting.

## Integration contract

Host draws with its world camera and bottom-anchored 1.3× zoom:

1. `draw_sky(host, runtime)` compensates the vertical camera because original sky runs before vertical translation.
2. `draw_level(host, runtime)` paints parking props and scene geometry.
3. Ordinary crates.
4. `draw_mid(host, runtime, pickups_callable)` paints trolleys, then invokes host-owned pickups exactly once.
5. Items/coins, enemies via `draw_enemy(host, bot) -> bool`, then player.
6. Player back/front hooks are intentionally empty for 2-1, which has no ride trolley. They do not claim support for 2-4.
7. Shots, bills and effects, then `draw_front`.
8. Reset to logical 960×540 UI coordinates; ordinary HUD/controls; `draw_hud` last for iris.

Runtime is read-only: `scene_index`, `entities`, `elapsed`, `wiping`, `wipe_elapsed`, `wipe_kind`, `wipe_label`, `wipe_focus_start`, `wipe_focus_end`. Trolley entities use `{k, p, v, t, dead}`. Bot state includes `p`, `kind/type`, `state`, `t`, `gone`, `flash`, `face`, `hp/max_hp`, `big`, `base_y`, `stride` and `visual_move`. Texture sources are `host.images` and the existing shared `host.sheets.bot`.

Each draw pass has a pure `build_*` command counterpart for regression tests. Rendering does not call random generators or advance runtime state. The source's rare trolley cosmetic dust emission is not emitted from draw calls. Missing-topdeck procedural fallback skyline/town/deck art is not implemented; the shipped imported asset is required and checked. No other supermarket-stage painter is claimed.

## Verification

Run with isolated HOME/XDG paths:

`godot --headless --path godot --script res://tests/test_supermarket_renderer.gd`

The suite checks 289 assertions covering original dimensions, crop rounding, fractional camera/negative-half rounding, seam reflection, scene filtering, car fallback variant, trolley geometry/direction/wobble, bot frames/scales/tints, source alpha within one 8-bit step, draw-order callback, all iris phases and mutation-free repeated draws. It executes primitives on a real Node2D draw callback under Godot 4.6.3 headless to catch invalid commands. It does **not** provide framebuffer screenshots or visual/device QA.
