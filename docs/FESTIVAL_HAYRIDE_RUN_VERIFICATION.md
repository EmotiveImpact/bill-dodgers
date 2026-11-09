# Hay ride: actual-input route verification

Scope: Godot 4.6.3 headless simulation of the real `main.tscn` / `main.step` path for **3-5**, all six housemates, plus a separate JP live-harvester/Continue route. This establishes assisted progression and source-contract coverage, not unassisted difficulty, touch controls, visual parity, native export, or device performance.

## Reproduce

From the repository root:

```sh
RUN_HOME=$(mktemp -d /tmp/bill-hayride-route.XXXXXX)
mkdir -p "$RUN_HOME/data" "$RUN_HOME/config" "$RUN_HOME/cache"
HOME="$RUN_HOME" XDG_DATA_HOME="$RUN_HOME/data" \
  XDG_CONFIG_HOME="$RUN_HOME/config" XDG_CACHE_HOME="$RUN_HOME/cache" \
  /usr/local/bin/godot --headless --path godot \
  --script res://tests/test_full_festival_hayride_run.gd > "$RUN_HOME/run.log" 2>&1
RC=$?
cat "$RUN_HOME/run.log"
test "$RC" -eq 0 && \
  ! grep -E 'SCRIPT ERROR|Parse Error|^ERROR:|ObjectDB instances leaked' "$RUN_HOME/run.log"
```

Optional arguments: `-- --character=jp --trace`; add `--no-live` to omit the supplementary live-harvester route. Without arguments, all six defeat routes and the seventh JP route run. Accept a sweep only when the process returns zero **and** the whole log has no script/parser errors, engine errors, or ObjectDB leak warnings. The script frees its actual main scene and awaits a frame before quitting.

## Test boundary and assistance

Every route selects its housemate, starts with a fresh isolated save, and loads the real supported 3-5. No capability override or substitute world/combat implementation is used. Autonomous scene physics is disabled solely because the test drives every real `main.step(1/60, controls)` itself. Audio uses a silent call-recording adapter, allowing assertions on actual boss/stage music selection without claiming audible mixer validation.

**The sole progression assist is player invulnerability renewed each frame.** No player/camera/velocity/facing teleport, enemy/harvester health write, actor deletion, pickup insertion, skill grant, charge refill, clock/wave manipulation, forced completion, or direct damage call is used. Selecting a character and clearing the isolated starting save are fixture setup, not earned progression. The controller uses only normal left/right movement, jump, crouch, and fire; no special ability or earned movement skill is needed.

The controller rides near camera+300. It crouches before each branch's source collision margin, and takes ordinary directional taps to turn rather than writing `face`. It begins each receipt jump before entering horizontal pickup range, then waits in the air near the stationary world-space center. After landing, normal movement restores its position on the moving deck. Once the harvester appears, the defeat routes turn left and continue firing ordinary shots until it is dead.

The no-shoot JP route follows the same authored course and earns all three receipts. After the harvester appears it deliberately walks left off the real moving deck three times. Production fall recovery clears invulnerability, costs one heart each time, and eventually causes a genuine knockout. The test invokes the same Continue callback as the UI, verifies three-heart revival and unchanged live encounter state, then completes the route. It never sets hearts or game-over mode itself.

## Coverage and assertions

- The sole live support is the copied `[60,540,402]` trailer, present before initial floor lookup. Player spawn is `(300,402)`. Source `onPlat=false` initialization is preserved; the test does not invent initial `onPlat=true`. `nodrop`, `nospawn`, trailer style, zero initial delta, and immutable imported metadata are checked.
- Source width34000, auto `.17`, fall line572, zero static solids/crates/authored coin rows, eighteen branch ranges, exact receipt centers, sixteen wave thresholds,39 solo entries and62 authored pair entries. Pair counts are metadata evidence, not a two-player playthrough.
- Strict1.8-second warmup;170px/s scrolling; late deck movement by current camera delta; grounded player movement by the **previous** deck delta; no airborne carry. Camera assertions allow0.003px for single-precision Vector2 rounding at large world coordinates, not a changed speed. No auto movement during wipe or ending.
- All eighteen branch spans traversed while crouching, with zero source collision-geometry contact frames. All three receipts are actually collected while airborne at `(8000,212)`, `(20000,212)`, `(30000,212)`. Receipt-frame score changes must come only from real coin pickups; receipts themselves grant no money.
- Every wave entry dispatches an actual actor:23 drone-carried bots and16 flyers, zero failed placements. Real420ms carrier hops retain the live deck identity and source `camDX*30` lead. Tests observe completed landings, carrier detachment on hop and on ordinary pop, and simulation-owned exit-drone cleanup after2.6 seconds.
- Actor outcomes are separately classified as pop,12-second retirement, offscreen cull,6-second unentered timeout, genuine scene cleanup, or still alive at clear. Unknown removals and an unbalanced ledger fail. A pop is not confused with retirement or scene deletion.
- Actual player-x checkpoint13300 fills hearts and sets1.5-second immunity. The same source crossing starts `Later that evening`, a fade wipe. The1.43-second midpoint moves the camera to14500, preserves player/deck relative offsets and feet, and clears ordinary actors/projectiles. The wipe completes at2.17 seconds.
- The separate70-HP harvester spawns at camera15000 while `main.boss` stays null. Real pause freezes runtime, player, camera, enemies, projectiles and coins. Each of the six defeat routes inflicts exactly70 one-HP ordinary-shot hits. The observer retains references to fired bullets because main removes dead shots before returning; it matches consumed shots in the harvester's source hit region to HP changes.
- The lethal frame leaves `dead=false` and drops no coins. The next late frame marks death, resets its clock and emits fourteen coins at deck.left+80/302, including the source drop helper's ±15px horizontal scatter. Actual music calls switch to boss music on spawn and back to stage music on death.
- Retreat is300px/s plus camera movement, followed only after strict `t>3` by the source done sentinel. A completed harvester never respawns. Source `updateHarv` continues ticking/retreating this nonempty sentinel and periodically replaces it again; the test deliberately does not impose a new frozen-sentinel rule.
- The supplementary route proves real fall recovery against the moving support, actual knockout/Continue preservation, and distance clear with harvester still at70HP plus eight live ordinary actors. It does not manufacture a boss-clear gate or an all-enemies-dead gate.
- Source distance threshold33260 and2.6-second final countdown produce real clear. Disk reload verifies earned stage clear, all three receipts, no unearned skills, and banked score.180 additional steps cannot change the clear save or bank twice. A fresh load after the translated full run restores the original deck, zero deck delta, empty harvester and fresh run receipts while preserving previously earned receipts on disk.

Contact counts below mean player/enemy **geometric overlap frames**, not damage calls or unique enemies. Invulnerability masks those overlaps. These routes therefore do not demonstrate a hitless or normally survivable controller. The supplementary route's intentional falls still apply real damage because source recovery explicitly clears immunity.

## Recorded sweep

2026-11-09: **all seven routes PASS**, process exit0, strict log scan clean. No runtime changes were needed by this test owner.

| Route | Ticks | Pops | Retired | Scene cleanup | Live at clear | Hops / landed | Contact frames | Score |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| JP defeat |11606|38|0|1|0|5 /4|44|110|
| Maya defeat |11606|38|0|1|0|4 /3|54|55|
| Ama defeat |11605|39|0|0|0|5 /4|69|54|
| Leo defeat |11606|39|0|0|0|3 /2|40|54|
| Theo defeat |11606|38|0|1|0|5 /4|44|60|
| Mei defeat |11605|38|0|1|0|6 /5|127|55|
| JP live/Continue |11606|0|21|10|8|22 /22|10675|0|

Every route has39 actual spawns, zero failed placements, zero offscreen culls, zero unentered timeouts and zero unknown removals. Every route earns3 receipts with3 jumps and traverses18 branches without geometric collision. Defeat routes have zero falls; the extra route has exactly3 intended falls and a real Continue. All six defeat routes deal70 harvester damage through70 ordinary shot hits and emit14 death coins.22 exit drones are observed/cleaned in JP, Maya, Theo, Mei and the supplementary route;23 in Ama and Leo.

Zero-based wipe start/midpoint/end:4698/4784/4829 for JP, Maya, Leo, Theo and the extra JP route;4697/4783/4828 for Ama/Mei. Harvester spawn:5006 or5005 respectively. All six defeats reach lethal frame6365, death6366, and first done sentinel6547. Ending starts11450, or11449 for Ama/Mei, with clear156 frames later. Whole-route simulation time is approximately193.43 seconds (193.42 for Ama/Mei), excluding pause-freeze probes and postclear checks.

The initial fixture assumptions were corrected to match inspected source behavior: initial `onPlat=false`, same-frame checkpoint/wipe start, ±15px coin scatter, large-coordinate float rounding and main's late dead-shot removal. No assertions were removed to conceal a runtime defect; the final assertions target the actual source behavior.

## Remaining boundaries

This is a solo simulation acceptance suite. It does not establish human/CPU co-op, touchscreen usability, audio playback quality, screenshot or framebuffer equivalence, Android/iOS packaging, signing, real-device frame rate, or unassisted balance. Those remain separate acceptance work. No push, deployment, signing, or repository-visibility change was performed.
