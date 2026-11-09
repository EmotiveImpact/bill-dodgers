# 2-S shopping-street renderer

`godot/src/shopping_street_renderer.gd` is the isolated **2-S Sample sprint** painter. It extends `supermarket_renderer.gd` without changing that parent, the runtime, host, registry, collision, or imported content. `supports()` accepts only `2-S`. This change does not register or promote the stage.

## Executable source, not the level comment

Audited `game/2-S/index.html`, especially:

- Lines 1170–1186: stage painting hooks and the empty `L` extension object.
- Lines 1147–1168: actual foreground, independent crop rounding, alternating mirrored tile helpers.
- Lines 913–949 and 1092–1101: shared mid-layer ordering and receipt drawing.
- Lines 883–885, 1255–1275 and 1276–1299: optional stage HUD, ordinary shared HUD, and camera/draw order.
- Original embedded `META.level`, checked equal to `godot/content/levels/2-S.json`.

The original street and all four transparent stall images were inspected directly. They remain unchanged:

- Street: 1503×894, split at 0.855. Independently rounded crops are `(0, 0, 1503, 764)` for the shops and `(0, 764, 1503, 130)` for the pavement.
- Shop row: 0.55 horizontal parallax, native dimensions, alternate horizontal reflections. Source vertical placement is `round(482 - 30 - 0.855 * 894 - cameraY)` before the rounded world-camera translation.
- Pavement: 1.0 horizontal parallax at y452, following the rounded vertical world-camera translation. Grey `#9aa3b4` underfill starts at ground482 and extends540px, as in source. Missing street leaves only the `#4aa3e8` sky fallback and skips the level/stalls pass.
- Nine stalls at `700 + 900*k`, k0–8, cycle `stall0`–`stall3`. Every painting is270×298. Placement is ground minus image height plus6, with254×8 contact shadows at ground minus2. Stalls neither mirror nor parallax away from their world coordinates. Missing stall images omit their shadows too.
- The source's padded `inView` comparisons are retained. The inherited texture helper additionally omits textures wholly outside the visible canvas; this changes no visible pixels.

Stalls are decoration. Original geometry is one ground solid `[-400, 9400, 482]` and no platforms. The renderer does not add stall roofs, collision, spawners, pickups or freezer mechanics.

### Foreground difference from parking

Although the stage comment calls these “street lamp posts,” the executable `fgPillars` helper draws **low bollards**, not tall posts. The street requests width12, but the helper clamps the drawn body to20px while retaining12px for its culling test. It uses period2100 rather than parking's2300, offset900, parallax1.3, a dark `rgba(20,24,40,.92)` body and warm `rgba(255,214,150,.55)` highlight. The body starts at y502 with height46; its elliptical cap has radius10×6. These details are deliberately preserved rather than inferred from the comment.

### HUD and shared pickups

The stage comment advertises “100 seconds,” and META contains `timer:100000`, but executable2-S assigns no `L.hud`, `L.update`, timer-expiry or countdown hook. Shared `LVS.timer` is elapsed time. This painter adds **no countdown or timed failure condition**.

The ordinary shared player/hearts/coins/kitty/level-ID HUD remains host-owned. The inherited optional scene iris remains compatible, but2-S has no authored scenes and does not initiate it. Tests exercise synthetic iris states only to verify the inherited drawing interface.

The authored22coin rows contain128coins. Three receipts are at `(2000,362)`, `(5300,362)` and `(8200,482)`. Coins, crate/items and receipt state remain in the existing host/runtime. Shared receipt rendering uses its W2 y−40 anchor,260ms four-pixel bob and900ms collection fade; it is not replaced or duplicated by this painter. `draw_mid(host, runtime, pickups_callable)` preserves the inherited ordering and invokes the host-owned pickup drawing once. There are no authored mid-layer hazards in2-S. The shared entity command path remains available without inventing any.

## Host interface

The module overrides `build_sky`, `build_level`, `build_mid` and `build_front`. Inherited `draw_*` entry points dispatch to these builders. Shared bot sprites, rush/cart overlays, source nearest texture sampling, command execution and scene-iris helpers are unchanged. Player back/front hooks remain empty because this level has no player ride trolley.

Use the existing world transform: bottom-anchored1.3× zoom, absolute world coordinates, and second-based runtime times. The painter compensates sky placement separately from world geometry to reproduce source rounding, including fractional vertical camera positions.

Host fields: `level_id`, `level`, `meta`, `images`, `sheets`, `camera`, `player`, `elapsed`, `font`; methods `view_width()` and `view_top()`; normal CanvasItem drawing methods. Shared runtime state, if present, uses the parent's `entities`, `wiping`, `wipe_elapsed`, `wipe_kind`, `wipe_label`, and captured iris focus fields. No extra2-S runtime fields are required.

Draw order remains sky → level → ordinary crates → shared mid/pickups → items/coins → enemies/player → effects → foreground → reset to UI coordinates → ordinary HUD → optional iris. Texture commands may be cached by the parent; building/drawing never advances gameplay clocks or changes imported metadata.

## Verification

Focused command, using writable temporary HOME/XDG directories:

```sh
work=$(mktemp -d /tmp/bill-shopping-renderer.XXXXXX)
mkdir -p "$work"/{home,cache,config,data}
HOME="$work/home" XDG_CACHE_HOME="$work/cache" \
  XDG_CONFIG_HOME="$work/config" XDG_DATA_HOME="$work/data" \
  godot --headless --path godot \
  --script res://tests/test_shopping_street_renderer.gd
```

Godot4.6.3 results: **687 assertions, zero failures**. Checks cover original dimensions and geometry, crop boundaries, mirrored joins, nine fractional-camera placements, four stall variants, both padded visibility boundaries, source foreground culling/width/colors/period, shared authored enemy rendering, callback ownership, timer inactivity before/at/after100seconds, inherited iris compatibility, missing-image behavior, support filtering and mutation-free repeated drawing. Actual Node2D draw callbacks exercise all four stall images, shared bot/cart commands, pickup callback and synthetic iris phases.

The unchanged supermarket renderer suite also passes its289 assertions. The original embedded2-S metadata and imported level object compare equal.

These are headless geometry, resource and CanvasItem-command checks. They do **not** certify framebuffer screenshots, mobile/device appearance, performance, packed exports, a stage clear, difficulty or registration. Register the suite in aggregate verification and wire the painter only through the separately reviewed stage-integration work.
