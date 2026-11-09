# Ticket Tout actual-main integration

Verified 2026-11-09 with Godot 4.6.3: **240 checks, zero failures** in `godot/tests/test_ticket_tout_integration.gd`.

The suite instantiates the production `main.tscn`, uses its real `step`, input dispatch, physics callback, CanvasItem callbacks, GUI buttons, story player and native save file. Observational subclasses delegate to production behavior while recording phase order, rendering, audio requests, events and save calls. It does not replace the encounter with a stub boss.

## Verified host behavior

- Native 3-6 selects `world_three`, `festival_combat`, source ability-shot routing and `festival_tout_renderer`, separately from Worlds 1 and 2. It loads the original eight solids, single cases platform, three crates, three receipts and ten solo approach entries.
- All three approach waves must be done. Camera 3659.999 cannot start the encounter; 3660 can. The full arena lock is 3662. The late start creates the original non-mini Tout, and the same frame's boss update clamps its entrance x from 4560 to 4310. Warning and boss music start once.
- Killing the final approach enemy in the projectile pass does not release its wave until the following frame. The subsequent wave pass releases it before the late main-boss trigger.
- The real host phase trace is motion, carry, after-motion, pre-combat ability, camera, waves, objective, bots, bubbles, shots, pickups, world, finale, boss, jar, movement snapshot, late ability effects, finish. Newly thrown wristbands and football-created ghost shots wait for the next appropriate combat pass.
- Solo HP is 160. An explicitly supplied participant-count adapter verifies 220 HP and thirteen pair-wave entries. This is scaling coverage, **not a claim of playable native co-op**.
- Numeric stage index zero binds the actual live `[4040,4290,354]` cases platform, preserving its ground base of 482. The host reaches the 800ms, 160px stage hop; the 900ms, 140px targeted slam; the 320ms landing pose; and both 460px/s shockwaves. The one-way stage is shared by player, skill and ability collision queries. Ties do not prevent the source Down+fresh-Jump drop-through branch.
- Boss movement snapshots occur after the boss has moved and only once per distinct simulation time. Stationary frames return to the idle snapshot. Repeated zero-delta calls cannot resample the same time.
- Half-health dizzy is strictly below 80/160, triggers once, and lasts 2.6 seconds. Ordinary and ghost projectiles ignore their nominal damage payload for Tout: one damage normally, two while dizzy. Bot-before-boss-before-crate precedence and enter/down immunity are exercised through the real projectile loop. Strict shot, body-contact and shockwave collision edges are tested.
- All six housemates shoot through actual controls and real ScreenTouch-to-physics dispatch. Cooldown, release, crouch avoidance, ordinary damage, invulnerable-but-still-tied behavior, earned-slide defense and special activation are covered. Maya shield and Ama bubble cancel incoming bands before contact; the other specials do not invent such protection. Maya's alternate-hit passive and exact shield-expiry boundary are tested separately.
- Every housemate collects all three receipts at the original centers `(1820,312)`, `(2000,252)`, `(4170,282)`. The exact 42px horizontal edge is excluded. Collection writes original indices once with no money award. Fresh replay resets live collectibles and retains saved collection markers.
- A final actual shot causes defeat and sixteen coin drops but no completion. The jar appears only after the strict 1.5-second down delay, then receives the same frame's jar physics. Attraction reads the **previous** jar age and requires `t > 1.4`, moves at 120px/s, and precedes jar velocity/gravity/age updates.
- Jar pickup requires age strictly over 600ms and horizontal distance strictly under 50px, without a vertical-distance condition. Lethal damage before jar collection leaves no living collector and cannot falsely complete the level. Continue preserves that same jar and permits a later genuine pickup.
- Focus pause releases held touch input and freezes the encounter, clocks and RNG. Real Resume and Continue GUI taps preserve boss/jar identity and run generation. Fresh replay resets the encounter, clocks and camera lock. Stale generation callbacks and menu-invalidated late magnet calls cannot mutate a new/inactive run. The physics callback clamps long frames to 34ms.
- Real world drawing orders Tout, bots, jar, players, wristbands and foreground, with the jar drawn exactly once per world callback. The actual SceneOverlay callback draws the Tout health meter. All seven original Tout strips are exercised through mirrored/flashed host draw callbacks. Rendering leaves measured player, boss, world, combat, pickup, ability, skill, save and RNG snapshots unchanged. Leaving the stage clears the flash cache and restores the next stage's painter.
- Campaign entry respects prerequisites and opens the original `3-boss` story. Duplicate entry cannot bypass it. A real jar pickup saves completion once and banks existing score plus scattered coins once. There is no invented post-clear story. The real Next level GUI focuses World 4, whose implemented 4-1 is now playable without an automatic clear. Replay starts a fresh approach without the already-seen boss story or a stale jar.

## Scope and limitations

These are **focused actual-main fixtures**, not an input-only completion route. Tests explicitly suppress or mark approach waves, place actors and shots, choose HP/attack states, seed earlier campaign clears, and set boundary ages to isolate behavior. Hop final-step boundary fixtures avoid conflating floating-point accumulation with the intended final host step. The separate full-route suite must establish input-only completion; isolated controller and painter suites are additional evidence, not substitutes for this host wiring coverage.

Headless CanvasItem callbacks verify dispatch, command execution and read-only simulation behavior. They do not verify framebuffer appearance, physical touch hardware, performance, mobile exports, signing or device readiness. Native two-player controls are not asserted. This slice changes only this test, its UID and this document; it does not modify source HTML, imported metadata, assets or production code.

## Reproduce

From the repository root, use writable, isolated directories so the suite never writes a normal user's save:

```sh
mkdir -p /tmp/tout-test-home /tmp/tout-test-data /tmp/tout-test-config /tmp/tout-test-cache
HOME=/tmp/tout-test-home \
XDG_DATA_HOME=/tmp/tout-test-data \
XDG_CONFIG_HOME=/tmp/tout-test-config \
XDG_CACHE_HOME=/tmp/tout-test-cache \
/usr/local/bin/godot --headless --path godot \
  --script res://tests/test_ticket_tout_integration.gd \
  > /tmp/tout-test.log 2>&1
status=$?
cat /tmp/tout-test.log
if grep -E 'SCRIPT ERROR|Parse Error|^ERROR:|ObjectDB instances leaked|FAIL:' /tmp/tout-test.log; then
  exit 1
fi
exit "$status"
```

The final full log must be checked even when Godot exits 0. This verification did not commit, push, deploy, export, sign or change repository visibility.
