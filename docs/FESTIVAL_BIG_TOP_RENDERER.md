# Stage 3-4 Big top painter

The separate `festival_big_top_renderer.gd` extends the shared festival command painter and selects only 3-4. This is a rendering implementation, not a campaign promotion or device/visual parity certificate. Original HTML and imported level metadata are unchanged.

## Source and coordinates

Implementation follows `game/3-4/index.html`: sky/interior 881–949, level ordering 951–973, truss/trapeze/cases/bleachers/ring 1013–1022, decorative poles 1043, spotlight 1076–1083, finds 1277–1284, shared boss frames/tint and HUD. Exact executable functions, not stage-description prose, determine the geometry.

The existing bottom-anchored host transform stays in use. Sky commands add camera Y because source draws them before its vertical world translation. World commands retain fractional-camera snap compensation. Backdrop dimensions and pole/floor sizes use `META.dims` (1474×900, 28×908, 1474×104), not an approximation from imported pixel dimensions divided by hi. Texture source crops remain native pixels.

- Interior tiles at 0.16 horizontal and 0.3 vertical parallax, without mirrored alternation; upper fill is the original dark-red ceiling.
- King poles at 760px spacing, +180 horizontal offset, 0.55 parallax, 0.82 RGB brightness. Their repeated upward crop is the middle 30–70% of the native texture. Both backdrop and poles use cached linear-filter CanvasTextures; normal world art remains nearest-filtered.
- All 49 platforms read live surface rows, including four gold trapezes. Trusses use exact 22px braces and lower rails. Cases stack every 64px; bleachers have authored seats; ring-floor texture tiles are clipped to the solid's authored extent and current viewport bottom. All five procedural decor poles retain their 2000px height.
- Eight rope segments run from current live mover edges ±6 to immutable authored platform edges ±6 at viewTop−20. The painter neither steps movers nor reconstructs their phase.
- Six spotlights read `on` and seconds-valued `t`. Beam angle is sin(t/0.9)×0.6, length760 and half angle0.2. Beam origin is fixture Y+12, while both far vertices use fixture Y. Beam alpha is0.18 with ordinary alpha blending, exactly as source; no new material-pass dependency. Fixtures retain stem, bordered rounded body, lit/unlit lens and 400ms blinking Shoot label.
- Existing receipt, checkpoint, enemy, Ringmaster `tout` selective per-pixel tint, animation and HUD builders are inherited. The authored checkpoint presentation is at −278. The overridden finds builder adds the ground-pound card at (5700,−358), 180ms/5px bob, original down arrow and 40×56 bordered card. The three receipts remain at authored upper centers. No relocation or navigation compensation is performed.

## Host contract

Use `build_sky`, `build_level`, and inherited draw hooks as for the other festival painters. `draw_mid` calls the overridden `build_finds`, preserving finds before crates/items/actors. Do not draw the host's generic skill-card graphic as well.

Read `runtime.surfaces(host)` or the supported live-surfaces snapshot. Ordering must remain solids followed by platforms, as the runtime contract requires. Spotlight dictionaries are `{x,y,on,t,...}` with t in seconds, available as `runtime.spots` or `runtime.stage_data.spots`. Elapsed and checkpoint_done are shared runtime fields. Skill collection reads runtime.skill_collected when supplied, otherwise host.movement_skills.card_collected. Boss state follows the existing festival boss contract. Imported sheets and textures use existing host resources.

All builders are read-only. Only texture caches change during actual drawing. No movement, timer advancement, RNG draws, pickups or combat mutations occur in painting. Existing standard command dispatch suffices, with a narrowly overridden linear texture command path. No overlay, shader, shared renderer, main/runtime or capability registry edits are included in this slice.

## Verification

`test_festival_big_top_renderer.gd`: **95 checks, zero failures** under Godot4.6.3 headless. Tests cover every authored platform's live position, four moved trapezes/eight ropes, all six spotlights off/on and source cone geometry, upper-camera parallax and pole source crop, skill center/bob/collection, checkpoint height, all receipt cameras, Ringmaster tint/throw frames/name/HP/dizzy HUD, immutable source/runtime and repeat-command purity. Five actual CanvasItem draw callbacks exercise imported textures, linear CanvasTexture cache, ring/bleachers/cases, ropes/beams, finds, boss and HUD.

Run with isolated HOME/XDG directories under `/tmp`; reject parse errors, script errors, any `ERROR:`, leaks or orphan diagnostics independently of process status. The successful run emitted only the engine version and `festival big top renderer: 95 checks, 0 failures`.

Headless command/callback checks do not demonstrate framebuffer appearance, device performance, input-driven whole-route completion, difficulty, all-housemate card accessibility or export/signing. Those remain separate integration/acceptance work.
