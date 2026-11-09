# Native texture mirroring audit

Verified with Godot 4.6.3 on 9 November 2026. This is a drawing-only correction. Source web files, sprite assets, gameplay coordinates, collision shapes, clocks and progression are unchanged.

## Engine contract and defect

`CanvasItem.draw_texture_rect_region(texture, Rect2(x, y, -w, h), source)` draws a horizontally reversed image **inside `[x, x + w)`**. Negative width does not move the rectangle left to `x - w`.

The port had translated `x += w` before negating the width, copying Canvas 2D's `translate(x + w); scale(-1, 1)` convention into an API with different semantics. This displaced mirrored paintings/sprites by an entire destination width. Repeated normal/mirrored tiles had gaps and overlaps; character art no longer aligned with its feet, projectiles or collision position.

An actual GL framebuffer fixture directly proves the engine contract with an asymmetric, four-colour atlas. It checks the original left edge, reversed right edge and absence of any paint to the left of `x`. This is not inferred from negative `Rect2` bounds or headless draw calls.

## Source anchor audit

The correction is scoped to sites whose builders already calculate the **positive-size destination's left edge**:

| Path | Source contract | Native correction |
| --- | --- | --- |
| Rooftop | `game/1-2/index.html:893`: alternating sky occupies the same `xx..xx+w` tile. `drawClimb` at line 909 reflects the first house to the **left** of X0, so its left bound is X0 minus image width. Decor at line 947 occupies its original left bound. | Keep the built rectangle's x; negate width only. Preserve the first house's distinct left-side placement and mirrored clipping math. |
| Bus | `game/1-3/index.html:937`: town tiles retain their tile interval. Line 948 centers each scooter on its x even when its facing transform is negative. | Uses the corrected rooftop command painter. No change to its centered scooter or town builders. |
| Street | `game/1-4/index.html:897,900`, shared with 1-5/1-S: join trees and decorations reflect within their existing image span. | Uses the corrected rooftop painter. No change to source tree offsets or decor coordinates. |
| Supermarket | `game/2-1/index.html:1165-1168`: pre-flipped image copies retain tile intervals. Lines 680-689 use the sprite's translated center. Line 854 uses rounded 1.66x security-bot dimensions. | Keep the builder's left edge for ordinary textures and bot/flash variants. In particular the 375-pixel security sprite retains its distinct mirrored left x=113 versus normal x=112 at feet x=300. |
| Festival | `game/3-1/index.html:831`: mirrored tile still starts at x. Line 1049 centers cut decorations. Lines 1481-1482 use centered bot sprites, including clipped tent emergence. | Preserve positive destination bounds and existing mirrored source-region clipping, then negate only width. Preserve variant source-frame cropping. |
| Ticket Tout | `game/3-6/index.html:1415-1420`: each animation's authored `f.ax/hi` anchor is distinct from half its frame width. | The builder already uses `x + anchor_x - width` when flipped. Keep that bound for normal and flashed frames; do not replace it with a centered anchor. |
| Main player/common sprite | `game/1-1/index.html:683-690,924`: translated feet, player anchor 0.45, followed by horizontal reflection. Common non-player sprites use 0.5. | Mirrored left edge is `feet.x + width * anchor - width`, while normal left edge remains `feet.x - width * anchor`. Keep existing native scaling, source frames, height, padding and right-facing calculations. |

The main change preserves existing continuous native scaling. It does not claim to fix every subpixel rounding difference between Canvas 2D and Godot. Story actors and map painters already use explicit negative transforms with positive-size rectangles and were not changed by this audit. The separately verified holiday override was left intact.

## Regression coverage

`godot/tests/test_texture_mirroring.gd`:

- 160 headless command checks across rooftop, street, bus, supermarket tiles/bots/security flash, festival sprites/tint/flash, and Tout sprites/flash.
- Three adjacent normal/mirror/normal atlas tiles, an asymmetric mirrored crop, unchanged command snapshots, unchanged opacity and original left/top bounds.
- A real-render run adds framebuffer checks: **175 checks, zero failures**, all ten production strips exactly match their fixed-position reference pixels.
- The pre-fix version failed 30 command checks and showed missing middle tiles and displaced crops in the actual framebuffer. The same fixture passes after the four command-painter corrections.

`godot/tests/test_sprite_mirroring.gd`:

- Calls the real production `main._sprite` method for all six original housemates facing left and right, with their individual sheet dimensions and scaled asymmetric anchors.
- An independent reference draws positive rectangles under a negative transform, matching the original Canvas operation order instead of reusing the production rectangle.
- **21 real-render checks, zero failures**, with zero differing character pixels in all twelve comparisons. The images show frame bounds and feet axes. The right-facing half remains unchanged.
- Headless mode checks six resources and actual draw callbacks only (seven checks); it explicitly skips pixel claims.

Existing renderer suites also pass with strict scans for `SCRIPT ERROR`, `Parse Error`, `ERROR`, leaked objects and still-in-use resources: rooftop, bus, street, supermarket, aisle, shopping street, stockroom, bakery, trolley dash, checkout, festival, queue, night, big top, hayride, Tout, festival bonus, holiday, captain, moving day and billing. This validates the shared-painter impact, source anchors and clipping contracts rather than only the new synthetic atlas.

## Reproduce

Run the two test scripts with `--headless --path godot --script res://tests/test_texture_mirroring.gd` or `res://tests/test_sprite_mirroring.gd` for command/resource checks. Use isolated writable `HOME`/XDG directories as in `scripts/verify-native.sh`.

For framebuffer proof, run on an available desktop rendering backend **without `--headless`**:

```sh
godot --audio-driver Dummy --path godot --script res://tests/test_texture_mirroring.gd -- /absolute/output/native-mirroring-after.png
godot --audio-driver Dummy --path godot --script res://tests/test_sprite_mirroring.gd -- /absolute/output
```

The first argument is a PNG path for the atlas suite and an output directory for the player suite. Both report a nonzero exit code on assertion failure. A successful engine exit alone is insufficient: also scan its log for script/parse/runtime errors and leaks.

Actual captured artifacts for this audit are under `../native-artifacts/screenshots/mirroring/`:

- `native-mirroring-before.png`
- `native-mirroring-after.png`
- `native-sprite-mirroring.png`
- `native-sprite-reference.png`

Logs are under `../native-artifacts/mirroring/`. The GL backend is Mesa llvmpipe via X11. Its unsupported-VSync warning is recorded. These are real desktop framebuffers, not iPhone/Android validation, GPU-performance measurements, or proof of overall visual parity.
