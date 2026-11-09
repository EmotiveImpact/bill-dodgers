# Festival bonus 3-S: isolated native rules and painter

## Scope

`godot/src/festival_bonus.gd` supplies the source bonus's early inventory test and late timer. `festival_bonus_renderer.gd` extends the existing festival painter with the four authored Partner stall signs and the timer HUD. All content comes from the imported `game/3-S/index.html` metadata and original painted assets. This change does not modify shared dispatch, capability/save gates, campaign routing, host completion, or imported data.

The original title says “partner stalls,” but the executable stage is a coin run. It has no can-shooting game, second-human requirement, enemies, boss, physical tents, crates, mud, fires, duck hazards, movers or spotlights. The four signs are decorations, not interactive stalls. Painted scenery can contain tents without adding live tent entities.

## Exact source behavior

Source references below are the original HTML's executable line numbers, not descriptive menu text.

- World width 9,200; player starts at x300; ground482; fall882. Twenty-five solid rows include sixteen stepped bale rows. Three one-way, `nospawn` van roofs span2032–2352,5632–5952,7432–7752 at feet246. Painted roofs intentionally have no separate platform graphic.
- `levelUpdate`1294–1298 runs finds and scenes, then events, then checks for no remaining `stay` coins **only if the authored coins were previously started**. The empty branch clears and returns before all later level phases. First update creates all179 coins at age300ms, zero velocity, resting and staying. The first pickup update has already happened, so those coins cannot be collected until the following frame.
- The179 coins comprise nine low rows of8, eight sinusoidal arcs of10, and three rooftop rows of9. Shared `WorldThree._authored_coins` retains exact coordinates. The bonus module does not spawn a duplicate inventory.
- `updateCoins`559–569 handles age, attraction, physical collection and filtering before `levelUpdate`. `stay` bypasses the11-second lifetime limit, but not death/fall or the strict `x > camera - 60` filter. Behind-camera coins disappear without award. No `stay` coins after this filtering is enough for the “All collected!” branch, even if none was physically collected. Loose non-stay coins do not block that branch.
- `levelUpdate`1324–1327 performs jar attraction, then advances the bonus timer while `state === 'play'`. At `timerT >= 90000`, it clears immediately. The timer runs before the base `updateBoss` and `updateJar` calls at669–672. It must not move to the earlier ordinary objective phase. `noEnd` makes `endOK`1182 false, so reaching the right edge cannot start the normal2.6-second ending.
- `stageClear`623–629 sweeps **every coin still in the array**, including distant uncollected coins. Both bonus banners capture the old kitty total **before** that sweep. The event and clear screen receive the final swept amount. This source defect is deliberately retained: idling for90seconds banks all179 coins. Coins previously removed by camera culling are not resurrected. Do not replace the sweep with a physical-collection-only reward while claiming source parity.
- Receipts are exactly(2000,182),(5600,182),(7400,182), with strict42px horizontal and body bounds. `updateFinds`1268–1276 records the receipt and emits its event, but awards£0. The existing shared receipt logic owns collection and save persistence.
- Source `stageClear` attributes the sweep to the nearest living participant, with a first-player fallback; native host completion currently supports solo total banking. A two-participant pickup fixture is covered here, but pair clear attribution, CPU, networking and playable co-op are not implemented or certified by these files.

## Integration contract

1. Instantiate the bonus extension in `WorldThree` and call `bonus.reset(host)` after incrementing the new run generation, as with other extensions. `host.world_three` must already reference this runtime. Expose `bonus.snapshot()` through `stage_data` for3-S.
2. In `after_pickups`, immediately after shared finds/scenes/events and immediately **before** `_authored_coins`, call `bonus.before_authored_coins(host, self)`. If nonempty, apply the banner/sub, call the ordinary capability-gated host completion path once, and **return from `after_pickups`**. This is the source early return; it must not advance the timer or other late phases that frame.
3. If no early event, retain shared `_authored_coins` and the later phases. After jar attraction, call `bonus.late_tick(dt, host, self)` at the end of `levelUpdate`, before the host's boss/jar ticks. Consume any returned event through the same host completion path.
4. Returned events have `type: clear`, `reason: empty|timeout`, `banner`, `sub`, `timer_elapsed`, `score_before_sweep`, and `remaining_coins`. Do not award `remaining_coins` from the event. The normal `_complete_level` path already sweeps inventory and saves; awarding here would double-count.
5. Use `FestivalBonusRenderer` for3-S and provide the shared runtime/snapshot. Its HUD reads `stage_data.timer_elapsed` in seconds, never host wall time. It also accepts a direct bonus snapshot for isolated rendering tests.
6. Preserve the normal runtime and native capability gates. Test-only support overrides in this suite are not a production shortcut. Add production/campaign support only after the parent's integration checks.

Both hooks require the matching host, current runtime generation, `runtime._can_step(host)`, exact `host.mode == 'play'`, a nonzero timer and an unreported completion. The source timer has no checkpoint or per-character reset. Continue resumes the same clock and inventory; a fresh run resets both through their existing owners.

## Painter

The inherited painter supplies the `fieldB_sky`, `fieldB_far`, `fieldB_land`, `fieldB_ground` layers, source hi factors, alternating mirrored tiles, drift, sky lock,0.16/0.5/1 parallax, behind-player0.78 mid-prop scroll and0.72 size, clipped120×54 staggered bale tiles, caravan/loo cutouts and receipt art. Ground and van-roof surfaces are intentionally invisible over their original paintings.

`drawDecor`1029–1050 supplies four signs at500,2600,5000,8000, all y362. Each uses its original palette index,230×56 rounded board,3px pale border,8px post to the ground, and “Partner stall” text at13px. The palette field is not a flip flag. These sign commands are inserted in the same back-decoration phase as the source, before bale surfaces and actors.

`hudExtra`1165–1168 supplies the fixed logical960×540 timer: rectangle(410,78,140,38), radius12,2px border; centered22px text at(480,98). Display uses `max(0, ceil(90 - timer_elapsed))`. At displayed seconds≤10, border changes to `#ff8f8f` and text to `#ffb3b3`; otherwise both are source gold. Any shared wipe still overlays it. Repeated paint does not advance the timer, collect items, write saves or change metadata. Inherited source coin rendering retains the after9-second blink even for permanent stay coins.

## Explicit reliability distinctions

- Per-run generation/host guards reject a stale extension after navigation or reset. No wall-clock callback can complete a newer run, and repeated calls cannot emit duplicate clear events. These are lifecycle reliability guards, not changes to active-run timing or reward policy.
- Rendering reads simulation snapshots only. Source clock advance, collection and completion remain simulation work. No timer increment, random art substitution or gameplay fix is hidden inside painting.
- No source reward defect was “fixed.” The surviving-inventory sweep and misleading pre-sweep banner amount are intentionally tested as actual executable behavior.

## Verification performed

Using Godot4.6.3 headless, isolated writable HOME/XDG directories, and rejection of `SCRIPT ERROR`, `Parse Error`, `^ERROR:` or `ObjectDB instances leaked` even when exit status is0:

- `res://tests/test_festival_bonus.gd`:256 checks. Source constants, all179 exact coin positions, real shared coin pickup/filter logic, early/late ordering, inclusive timeout/strict collection bounds, idle timeout at2,648×34ms =90.032seconds, empty inventory, loose-coin sweep, camera-only deletion, zero-reward receipt boundaries, no width clear, pause/Continue, fresh reset, old host/generation rejection, metadata immutability and a two-participant pickup fixture. Completion uses an explicitly labeled test adapter, not a production save or playable route.
- `res://tests/test_festival_bonus_renderer.gd`:145 checks. Original assets, layer order, dimensions/scaling, all16 bale surfaces, three roofs/caravans, four sign palettes/geometry/culls, receipt art/taken state, timer rounding/urgency/position, stay-coin blink, wrong-stage inactivity and repeated-draw purity. Commands are submitted by an actual headless `CanvasItem._draw`, not only inspected as arrays.
- Four fresh Node24 VM probes executed the original extracted `stageClear`, `updateCoins`, `updateFinds`, `levelUpdate` and `endOK` functions with surrounding services stubbed: idle timeout90,032ms banks179 and emits one clear event with179 while banner says£0; early empty at89,990ms preserves clock and sweeps one loose coin from£7 to£8; behind-camera cull clears with£0 and no width end; receipt pickup emits `bd-receipt` and gives£0. These are narrow source-function probes, not a browser playthrough.

Not claimed: a native production save, full input-driven bonus route, every-character receipt accessibility, framebuffer/screenshot parity, real handset performance, multiplayer/CPU, signed exports or a complete-game release. Parent integration/aggregate tests and device visual QA remain separate acceptance gates.
