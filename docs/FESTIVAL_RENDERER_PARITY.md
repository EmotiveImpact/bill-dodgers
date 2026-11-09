# Festival field renderer: 3-1

## Scope and evidence

`godot/src/festival_renderer.gd` supports **3-1 only**. It is a pure presentation module for the imported festival paintings, field geometry, tents, mud, checkpoint, receipts, ordinary robots, Wristband seller, loot and projectiles. It does not enable a stage, advance clocks, update actors, collect anything, change a save, move the camera, spawn enemies or publish the game.

Source is the executed shared World 3 runtime in `game/3-1/index.html`, particularly lines 244–309, 684–697, 817–852, 951–1074, 1133–1140, 1256–1282, 1343–1348, 1407–1483 and 1527–1555. Authored placement and asset resolution come from `godot/content/levels/3-1.json`. The door transition uses the current shared `game/polish.js`, not the obsolete decorative door wipe.

Run the focused suite with isolated writable user directories:

```sh
mkdir -p /tmp/festival-renderer-env/{home,cache,config,data}
HOME=/tmp/festival-renderer-env/home \
XDG_CACHE_HOME=/tmp/festival-renderer-env/cache \
XDG_CONFIG_HOME=/tmp/festival-renderer-env/config \
XDG_DATA_HOME=/tmp/festival-renderer-env/data \
godot --headless --path godot --script res://tests/test_festival_renderer.gd
```

Result on Godot 4.6.3: **1,192 assertions passed**. This includes actual `CanvasItem._draw()` callbacks at eight camera positions and two vertical offsets, original texture reads, nearest-filter texture submission, cropped robot hit-flash frames and seller tint generation. It is **not framebuffer, screenshot, browser comparison, difficulty, mobile performance or device evidence**. Full host integration and gameplay tests belong to their own suites.

## Host API and exact phase order

The host applies the same bottom-anchored 1.3× world transform as existing native renderers. Commands use absolute world pixels; simulation clocks are seconds. All `build_*` methods return inspection-friendly commands and the corresponding `draw_*` methods submit them to the host. `supports`, `clear_cache`, `draw_sky`, `draw_level`, `draw_mid`, `draw_enemy`, `draw_player_back`, `draw_player_front`, `draw_front` and `draw_hud` retain the existing renderer API.

Source ordering is important:

1. `draw_sky(host, runtime)`: gradient and drifting sky, compensating for the fact that the source draws the sky before the vertical camera translation.
2. `draw_level(host, runtime)`: far painting, land painting, middle-distance props, ground painting, back decor, tents, surfaces, mud and checkpoint.
3. `draw_mid(host, runtime)`: source receipt finds, the final phase of source `drawLevel`. An optional callable replaces this phase exactly once. Alternatively call `draw_finds(host, runtime)` explicitly. Do not call both.
4. `draw_crate` for each intact crate; `draw_item` for each item; `draw_coin` for each coin. **Items precede coins** in World 3.
5. `draw_boss(host, runtime)` **before** ordinary `draw_enemy` calls. Source `drawWorld` lines 1538–1539 specify this order.
6. Jar, if a future supported stage actually has one. **3-1's mini encounter has no completion jar**, so this renderer does not fabricate one.
7. For each player: `draw_player_back`, the host's character sprite, then `draw_player_front`. The first draws the source floor-relative shadow; the last draws the optional power ring and solo P1 tag.
8. Player shots, then enemy bills. `draw_bill(host, bullet)` dispatches tied projectiles to `draw_band` and draws ordinary/big rotating bills with their original colored rectangles. The host still owns player-shot presentation.
9. Particles and floating messages, followed by `draw_front` for stage hints and cheers.
10. Reset to logical 960×540 UI coordinates. `draw_hud` supplies the seller health/name and current shared iris transition. Shared player/kitty HUD, banners, touch controls and their stacking remain the host's responsibility.

The subclass reuses command primitives, nearest filtering, rounded shapes, outlined text and the shared iris from existing renderers. It overrides every stage-dependent scene/enemy/front path; no supermarket walls, bollards, security caps or trolley objects are inherited into the field.

## Runtime inputs

- `runtime.scene_index`, `elapsed`, `tents`, `checkpoint_done`, `cheer`, and shared wipe fields are read-only.
- `runtime.surfaces(host)` returns stable dictionaries containing `row: [x0, x1, top, properties?]`, `plat` and copied surface property keys. Dictionary snapshots with `surfaces` or `live_surfaces` arrays are also accepted. Static META is used only when no live snapshot is available.
- Each tent provides `x`, `y`, `kind` and `shake` in seconds.
- Boss state is read from `host.boss.state`, or a supplied runtime `boss` snapshot. Fields are `x`, `fy`, `state`, `t`, `face`, `flash`, `dizzy`, `kind`, `name`, `hp`, `max`, `waves`, `hop` and `jar`.
- Robots provide `p`, `face`, `state`, `t`, `flash`, `gone`, `rise`, `type`/`kind`, `stride`, `visual_move` and optional `dz`. Stride and movement direction are updated by the simulation, never by drawing.
- Receipts use `host.receipts` entries with **unshifted authored** `position`, `taken` and `previously_collected`. The saved flag dims a still-reacquirable receipt to 45%; `taken` hides it immediately for the current run. The fallback metadata definitions are available only when the host does not provide an array.
- Coins/items/bills use absolute `p` and `age` seconds; source-style `x/y/t` snapshots are also accepted. Crates use `p`, `broken` and an optional simulation-owned `visual_jitter` offset.
- Player hooks use the supplied feet `Vector2`, `host.character`, `host.power`, original META heights and `host.world_three.below` when available. This milestone is solo; second-player/revive painting is not implemented.

## Painting and geometry contracts

### Resolution and camera

Source `IW/IH` divides each image's **actual pixel size by that image's `META.hi`**, not a universal 1.3. In particular, the gate is 344×198 pixels with `hi=1.612903…`, giving 213.28×122.76 world pixels; the authored `dims` entry is not an exact substitute. All source images are already cut into sky/far/land/ground layers. The renderer samples each complete imported image and does not crop the painting a second time.

The two scenes both have `paintTop = round(482 - 635 × 0.81 + 14) = -18`.

| Layer | Field A world dimensions | Field B world dimensions | Horizontal factor |
|---|---:|---:|---:|
| Sky | 952×415 | 952×375 | 0.05 plus 2.5 px/s drift |
| Far | 952×217 | 952×190 | 0.16 |
| Land | 952×450 | 952×458 | 0.5 |
| Ground | 952×217 at y=400 | 952×209 at y=407 | 1.0 |

Parallax rounds the first tile offset once, advances by the rounded tile width and mirrors alternating global tile indices. The sky clamps its y to prevent its empty lower strip from rising above the land: `max(top - camY × .12, top - camY + land_top - sky_clean)`. Land and objects compensate for the source's independently rounded vertical camera translation. A missing explicit scene index falls back to camera-center selection at `scene.to || scene.x`, so the second scene begins at center x=7900, not checkpoint trigger x=7000.

### Props, surfaces and mud

The objects named `L3.fg` are **middle-distance props behind the ground/player**, at 0.78 parallax and 0.72 size. Their source `brightness(.9) saturate(.92)` filter is applied in cached sRGB texture variants. They are not enlarged foreground occluders.

Tents use their original 278×148 paintings, center on authored x and extend to feet y+4. Shake reads `sin(shake / .020) × 3`. Back decor uses individual asset scaling and source mirrored-edge rounding.

Bales use the original 120×54 tile, with 60-pixel alternate-row staggering and actual clipping to each solid span and configured base. Crops remove pixels rather than compressing an entire bale into the remaining width. Ground colliders are not drawn over the ground painting. Vanroof one-way surfaces deliberately have no platform strip; their caravan image supplies the roof art.

Mud has the original four-pixel cells, sixty-pixel end-opacity ramps, 26-pixel depth, seeded puddle positions and one-pixel white glints. A private per-strip Park–Miller calculation reproduces the source deterministic decoration without reading or consuming the gameplay RNG. Negative leading-cell CSS alpha is clamped to zero, matching the valid range of an alpha component.

Checkpoint pole height is 200 pixels, its flutter uses a 150ms clock, and its flag x stays unrounded just as in source. Saved/unsaved state is read from the runtime.

### Actors, finds and objects

Receipts use authored y plus `sin(level_time / .2 + receipt_number) × 4`, a 20-pixel animated glow, 18×28 paper, four gray lines and three bottom teeth. No World 1/2 `-60`/`-40` shift is introduced.

Robots use the original 226×140 sprite grid, source idle frame 5 and stride/9 walk frames, 110ms throw/pop frames and 800–1300ms pop fade. Tent emergence displaces the sprite down by `rise_seconds × 240` and clips it at `feet + 2`; it does not move the collision body. Dizzy marks precede the sprite and flat-bill markers follow it. Hit-flash whitening retains the original pixel alpha.

The seller uses the original 462×282 thief frames, 70ms entry/charge frames, 130ms walk frames, 160ms throw/stomp frames, 220ms dizzy frames and 300ms down frames. The source's warm-color predicate is `r > g + 18 && g > b`. Only these pixels change to `(r×.55 + b×.2, g×1.15, b×.6 + r×.25)`, with byte clamping and ties-to-even rounding. Hit flash overlays 70% white after tinting. This is not the World 2 security tint/cap. Shockwaves stay grounded at 482 and retain their 50ms sine animation. The bottom 420-pixel bar uses the actual 60/80-HP state's ratio and disappears when down.

Wristbands use the original 13×9 ellipse, five-pixel color stroke, two-pixel partial highlight, cream clasp and 70ms rotation. Source `drawBill` supplies screen x to `drawBand`, so the color bucket intentionally depends on `(world_x - camera_x) / 50`, including correct negative modulo. Ordinary/big bills rotate every 90ms unit and retain all original rectangular ink details.

Wellies are the source green four-rectangle boot, including its dark sole. Heart pixels, split/debit badges, item bob/blink, source 68×64 crate artwork and spinning 1.3× coin geometry are included. Player shadow, power ring and solo P1 tag are separate from the host character sprite.

## Deliberate purity fixes and remaining work

- The source updates robot stride/direction and some actor bookkeeping during drawing. The renderer only reads simulation snapshots. Repeated calls produce identical commands and leave META, actors and global RNG unchanged.
- Source crate-hit shake uses `Math.random()` during drawing. The port accepts a simulation-supplied offset and otherwise uses zero. It never consumes RNG just because a frame is painted.
- Seller and filtered prop texture variants are cached; `clear_cache()` releases all variants and nearest-filter wrappers. Tent clipping reconstructs the complete frame before hit-flash filtering, avoiding fractional region truncation and incorrect shared cache keys.
- Only the shipped 3-1 painted path is implemented. Missing paintings are not silently replaced with unrelated procedural scenery. Later World 3 darkness, banners, spotlights, movers, drones/carriers, crowd painting, trailer, Harvester, big-top and Ticket Tout cutouts remain unsupported.
- Full character animation, player-shot effects, particles/floats, shared player/kitty HUD and transition/control overlay ordering still require host-level review. Second-player/down/revive overlays are outside this solo slice.
- No screenshot, graphics-backend visual comparison, browser parity or real-device test has been claimed. Headless command and draw-callback checks establish geometry, data flow and draw-call validity only.
