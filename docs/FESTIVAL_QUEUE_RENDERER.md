# Queue jump painter (3-2)

The queue-specific painter extends `festival_renderer.gd` and supports only `3-2`. Parent integration selects this painter. No shared renderer, runtime, main, source HTML or imported metadata is changed by this implementation.

## Source and scope

Reference: `game/3-2/index.html`, source Canvas functions `barrierArt` (800–804), scene layers (828–850), `drawSky` (881–887), `drawLevel` (951–971), `drawSurf` (982–1005), `drawBanner` (1062–1069), and `drawFront` (1133–1143). All textures are existing original imported assets, not generated substitutes. Metadata is `godot/content/levels/3-2.json`.

- Field B and crowd scenes retain source per-image high-resolution factors and complete pre-cut sky/far/land/ground textures. Field B ground is y407; crowd ground is y426. Source paint top is -18. Camera translation snap, alternating global mirrored tiles, .05 sky / .16 far / .5 land / 1 ground parallax, sky bottom-lock and 2.5px/s sky drift are inherited. The queue override supplies the original dusk gradient.
- Painted scenes already contain their background flags and speakers. Those redundant decor objects are intentionally suppressed, matching source drawLevel.
- Barriers reconstruct the original 120×112 procedural art with its exact bars, highlights and clipped feet. Each complete canvas is scaled into the authored surface width and `(base-top+4)` height. An 80px barrier therefore compresses its full120px art, unlike bale tiles which crop.
- Crowd conveyors use original `crowdband` in globally aligned96px sections, with both source depth rows (-26 and30), .37×517 second-row phase,170ms bob, fractional source wrapping and actual edge clipping. Second-row CSS brightness(.62) is computed in sRGB bytes on a private duplicate of the whole source image. Alpha and source textures remain unchanged. Cached full-image shading avoids truncating fractional crop boundaries.
- Low banners preserve fourteen-pixel endpoint extensions, two-tone poles, six alternating panels,260ms flutter, highlight, shade and centered DUCK label. They draw before checkpoint artwork.
- Stepped bale crops, tent art (none authored in3-2), checkpoint flags, finds, crates, items, coins, ordinary robot movement-driven sprite animation and player helpers are inherited.
- The fleeing robot is source presentation, not a gameplay enemy. It uses the70ms six-frame walk clock, left facing and50% alpha. Its fixed screen x is WV−70 even during ending: the original min expression prevents positive end_run from moving it forward. It stands on the highest eligible surface below viewTop, with ground fallback over gaps. The full jar uses original1.2× geometry and90ms bob. It appears only in play.
- The original nine-second auto-run hint is inherited. Start/checkpoint/crowd-surf/end notices are delivered by the runtime/host status path. Source animated shared HUD/banner presentation remains a broader host-level gap; the queue painter does not claim to implement it. The existing iris overlay and scene label are inherited unchanged.

## Runtime boundary and purity

`build_*` returns pure draw plans. Runtime supplies `elapsed`, `scene_index`, `checkpoint_done`, current surfaces and `stage_data.end_run` (seconds). Host elapsed equals runtime elapsed by the integration contract, so crowd and inherited actor clocks read that same stage time. No clock, collision surface, actor, imported metadata, gameplay RNG or pickup state changes during drawing. Actual draw calls only populate renderer-owned texture caches. `clear_cache()` releases those caches.

## Verification

`godot/tests/test_festival_queue_renderer.gd` passes253 assertions with Godot4.6.3 headless. It checks original crop bounds and source/destination scale, mirrored parallax at fractional cameras, barrier compression versus bale clipping, both crowd rows and wrapping, animated banners/crowd/runner and movement-driven ordinary bot frames, source runner support/end behavior, dusk, original hint, iris cover/label/radial stages, stable repeated plans, metadata/runtime/RNG purity, original-image preservation while creating shaded art, cache release, and real Node2D draw callbacks.

Run with a writable HOME/XDG, for example:

`HOME=/tmp/bd-godot-home XDG_DATA_HOME=/tmp/bd-godot-data XDG_CONFIG_HOME=/tmp/bd-godot-config XDG_CACHE_HOME=/tmp/bd-godot-cache /usr/local/bin/godot --headless --path godot --script res://tests/test_festival_queue_renderer.gd`

Inspect logs for SCRIPT ERROR and ERROR even when Godot exits0. No framebuffer screenshot, GPU/browser visual comparison, phone installation or device playthrough is claimed. Command geometry and successful headless CanvasItem execution do not certify visual parity.
