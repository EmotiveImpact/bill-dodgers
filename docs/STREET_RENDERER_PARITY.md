# World 1 remaining street scene rendering

`godot/src/street_renderer.gd` ports the environment rendering for **1-4 Park**, **1-5 Back Alley Chase**, **1-S Late Shop Bonus** and **1-6 Bin Day**. It reuses the rooftop renderer's native texture/filter command executor. It neither replaces imported paintings nor changes gameplay/collision data.

## Source mapping

- `game/1-4/index.html:888–908`: tile-run `drawSky`, `drawLevel`, `drawFront`.
- `game/1-5/index.html:888–925`: the same scene plus `levelDraw` obstacle paintings and dusk overlay.
- `game/1-S/index.html:888–943`: the same scene plus striped awnings and the timed partner strip.
- `game/1-6/index.html:888–893,1003–1004`: nonrepeating chunk paintings and checkpoints. Binman rendering is a separate module, not part of this renderer.
- All four pages' `drawChecks` at lines 780–789: flag geometry, hit state and animation.
- All four pages' `bd-fixes` clears `LV.front`. Imported foreground metadata is intentionally ignored. No sweeping lamp posts or leaves are restored.

There is no separate `sceneDraw` implementation in these four source pages. The alley's painted garden gates remain in its original background images, rather than being replaced by invented interactive gates.

## Preserved scene behavior

### Park, Alley and Late Shop Bonus

- Original `t0` and `t1` paintings repeat at their metadata widths, currently **948×540** each. They alternate by key, not by mirroring. There is no extra horizontal parallax factor: this source uses full camera speed.
- `drawSky` precedes the source's vertical camera translation. Background paintings therefore use `camera.y` under the host world transform and remain screen-fixed vertically.
- Each painting join gets the original **491×459** tree, offset by `tree.width × 0.44`, at `GROUND − tree.height + 8`. Odd-numbered joins reflect the tree.
- Park decor uses the original key, origin, dimensions and reflection flag. Benches, hedges, urns, picnic tables and the climbing frame provide the source artwork for their collision surfaces. No generic gray collision bars are drawn.
- Alley adds all **52** source `LV.obs` paintings, centered on their source x coordinate. Odd-width bins retain their half-pixel origin. Obstacle feet are `GROUND + 4`, not their collision top. The original 18%-alpha dusk rectangle covers y=0 through `GROUND − 160`, after flags and obstacle paintings.
- Bonus adds all **17** awnings. Each has ten alternating green/cream **26×18** stripes, the **4px** dark underside and two **4px** support posts. Both source heights, y=282 and y=342, are preserved. The stripe loop retains the source's overhang behavior if a future width is not divisible by 26.
- Bonus's original partner text, 340×34 rounded strip, 17px radius, 2px gold outline, six-second duration and final 600ms fade are retained. It uses the host's bundled Silkscreen. Its source y=80 is deliberately unchanged: the standard bottom-anchored 1.3× view clips this strip. No replacement branding or new screen position is invented.

### Bin Day

- `st0` and `st1` draw at **2048×540**, at x=0 and x=2048. `st2` draws at x=4096 at its original **59×540** dimensions. It ends exactly at world x=4155.
- The source chooses the current and next chunk only. Chunks do not wrap or stretch to fill the screen or the final chunk width.
- Gates, trees, street surfaces and the yard remain inside the original paintings. There are no added seam trees, collision bars or foreground props.
- Binman, moving bins, rain and shockwaves are not owned by this file.

### Checkpoints and camera

- Flags retain the 6×150 pole, gold cap, white marker, source triangle and 3px sinusoidal flutter. Source millisecond time is converted to native seconds without advancing random state.
- Hit flags read `host.combat.checks`; metadata gives inactive flags when no combat object is supplied.
- Flag feet come from the highest source surface below x, using `world_one.below` when supplied. In particular, the Alley flag at x=19631 stands at **y=398** on an obstacle, not at ground y=482.
- Camera-relative JavaScript `Math.round` semantics are retained, including negative half values. World art compensates once for the source's rounded vertical translation; background art does not.
- Original texture rectangles and source pixels are preserved. Off-screen paintings are culled, and the host CanvasItem viewport supplies clipping; paintings crossing the viewport edge are not resized or reconstructed. These four source scenes do not use per-surface texture clips.
- Rendering does not mutate level metadata, combat state or the World 1 simulation.

## Host integration

The host is already in its camera/zoom transform. It supplies:

- `level_id`, `meta`, `level`, `images`, absolute-x/offset-y `camera`, `elapsed` in seconds, and the existing `font`.
- `view_width()` and `view_top()`.
- Optional `combat.checks`; an optional `world_one` passed to the renderer provides exact surface lookup.

Use `draw_scene(host, world_one, pickups_callable)` before actors and `draw_front(host, world_one)` after actors/projectiles. `supports(id)` identifies the four owned stages. `clear_cache()` releases the shared painter's cached CanvasTexture wrappers. `build_scene`, `build_background` and `build_front` expose deterministic commands for geometry tests.

Do not draw the host's shared checkpoint loop a second time on these stages. Generic collision-platform art must also be disabled. The renderer does not draw collectible receipts, skill cards, dropped items, coins or destructible crates.

The optional `pickups_callable` implements the source's shared-pickup layering: backdrop/trees/decor, then the callback for receipts/skill cards, then checkpoint flags and the Alley obstacles/dusk pass or Bonus awnings. Invoke it without arguments and suppress the host's later duplicate receipt/card pass. The callback runs exactly once. If omitted, `draw_scene` draws the complete environment normally; `build_scene` always retains the complete command list for callers/tests.

## Verification and limits

Focused command/resource tests:

```sh
mkdir -p /tmp/bd-street-renderer/{home,cache,config,data}
export HOME=/tmp/bd-street-renderer/home
export XDG_CACHE_HOME=/tmp/bd-street-renderer/cache
export XDG_CONFIG_HOME=/tmp/bd-street-renderer/config
export XDG_DATA_HOME=/tmp/bd-street-renderer/data
godot --headless --path godot --script res://tests/test_street_renderer.gd
```

Godot **4.6.3** passes **1,143 assertions**: every imported resource's full dimensions, camera/paint repeats, both join-tree reflections, every Park decor entry, all Alley obstacles, all Bonus awnings, background fills, dusk order, flag surface/hit/animation, the narrow final Bin Day chunk, partner fade/font, pickup-callback ordering, metadata immutability and actual headless CanvasItem draw callbacks across all four stages. Original representative source paintings were also inspected directly.

The headless engine does not provide screenshot/rendered-pixel proof. This is **not screenshot parity, on-device rendering/performance verification, human full-run testing or difficulty validation**. Godot font rasterization and the rounded-strip StyleBox antialiasing have not been compared pixel-for-pixel with browser Canvas. Stage runtime progression, ability cards and Binman behavior are tested by their respective owners.
