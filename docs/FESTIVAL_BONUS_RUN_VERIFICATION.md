# Festival bonus 3-S: full native input routes

Verified 2026-11-09 using Godot4.6.3 headless. `res://tests/test_full_festival_bonus_run.gd` passes one independent full idle run and six full character routes through the actual native main scene and production3-S runtime. All runs use normal `game.step` controls at1/60second intervals. They do not modify actor positions, camera, clocks, waves, collision geometry, inventory, health, abilities, native support, money or completion after fresh setup. **No invulnerability or other gameplay assist is used.**

Fresh setup selects the character and initializes an isolated empty-skill save with£13 already in the shared jar. A save-counting subclass observes `_save_progress` and delegates unchanged to production, so the tests verify both actual saved results and exactly one write per receipt/clear. Silent audio is the only service adapter. These are deterministic headless input tests, not human difficulty or handset QA.

## Results

All six moving routes collect the three real receipts, land on all16 authored bale surfaces and all three one-way caravan roofs, perform19 actual jumps, and retain three hearts with zero invulnerability. They use no earned skill and no activated special. JP's ordinary passive coin magnet remains active as authored.

| Route | Input ticks | Bonus clock at clear | Reason | Physically picked | Camera-culled | Fell below stage | Swept on clear | Run bank |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| Idle Maya |5401|90.016667s|timeout|0|0|0|179|£179|
| JP |1892|31.516667s|empty|179|0|0|0|£179|
| Maya |5401|90.016667s|timeout|136|21|20|2|£138|
| Ama |5401|90.016667s|timeout|136|21|20|2|£138|
| Leo |5401|90.016667s|timeout|141|17|20|1|£142|
| Theo |5401|90.016667s|timeout|141|17|20|1|£142|
| Mei |5401|90.016667s|timeout|139|21|17|2|£141|

Each row accounts for exactly179 authored coins. Bank is physical pickups plus the final sweep, never camera/fall removals. Cleared receipt saves are `[0,1,2]` for the six moving routes and absent for idle. Reloaded shared-jar totals are the run bank plus the original£13. Exactly four real progress-save calls occur per moving run, one for each receipt and one clear; idle performs one clear-save call. Another180 post-clear input updates neither write progress again nor change money.

## What the routes prove

- The initial player and camera are the actual source positions. Native support and production painter dispatch are asserted, never bypassed.
- All25 solids and three platforms are used unchanged. Normal direction/jump controls climb the actual stepped bales and reach the roofs; actual body overlap obtains each receipt. Receipt events never add money.
- The scripted waypoint path passes every source bale and roof. JP finishes on the final descent before the optional last parking waypoint because his passive magnet has already collected all179 coins. His source early-empty clear occurs on tick1892, but its timer intentionally remains at the preceding frame's31.516667seconds. Other characters reach the final parking waypoint, then receive empty controls until the real timeout. No clock is jumped.
- Exactly179 coins appear once at their authored row/arc coordinates. Tracking follows live coin dictionaries through shared physics and filtering. Collected coins, behind-camera removals, and coins whose attraction release lets them fall below y882 are separate outcomes. Final score deltas independently validate physical pickup and sweep counts.
- The stage never invents waves, a boss or a normal width-based ending. The source `noEnd` rule remains in force.
- Every clear banner preserves the amount *before* the host sweep. Idle specifically says£0 despite banking£179. The timeout therefore cannot be described as “you collected179 coins.”
- Imported metadata, empty skills and normal persistent saves are checked. No forced reward or synthetic completion replaces the actual bonus hook.

## Independent idle behavior

The idle test starts a fresh Maya run and sends no movement, shooting, jump or special controls for5401 frames. Player/camera never move, hearts remain three and every authored coin survives until timeout. It banks all179 through the real host's source-compatible completion sweep. The test uses Maya because JP's passive magnet would genuinely collect some nearby coins even without input; that would not be a zero-pickup fixture.

At1/60second floating-point stepping, the accumulated clock after5400 ticks is just below90, so the inclusive90-second condition executes on tick5401 at90.0166666666628seconds. The focused host suite separately verifies an exact90.0 boundary with chosen clock fixtures. The idle route does not set any clock.

## Reproduction

Use separate writable HOME/XDG roots for concurrently running suites. From the repository root:

```sh
run_root=$(mktemp -d /tmp/festival-bonus-routes.XXXXXX)
mkdir -p "$run_root/home" "$run_root/data" "$run_root/cache"
HOME="$run_root/home" XDG_DATA_HOME="$run_root/data" \
XDG_CACHE_HOME="$run_root/cache" /usr/local/bin/godot --headless \
  --path godot --script res://tests/test_full_festival_bonus_run.gd \
  > "$run_root/test.log" 2>&1
status=$?
cat "$run_root/test.log"
if grep -Eq 'SCRIPT ERROR|Parse Error|^ERROR:|ObjectDB instances leaked|FAIL|blocked' "$run_root/test.log"; then exit 1; fi
exit "$status"
```

Optional arguments after `--`: `--jp-only`, `--character=maya` (or another valid character), and `--trace`. Every selection still includes the independent idle run. An unknown character fails rather than silently skipping coverage.

Related evidence: [FESTIVAL_BONUS_INTEGRATION.md](FESTIVAL_BONUS_INTEGRATION.md) documents182 focused actual-host checks; [FESTIVAL_BONUS_PARITY.md](FESTIVAL_BONUS_PARITY.md) documents isolated rules/painter/source-function evidence.

No claim is made of screenshot parity, physical-device performance or touch ergonomics, playable co-op/CPU, signed distribution, World4–6 completion or a finished six-world release. The current campaign boundary remains World4-1.
