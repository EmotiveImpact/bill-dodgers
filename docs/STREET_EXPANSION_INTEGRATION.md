# World 1 street expansion: focused host regressions

`godot/tests/test_street_expansion.gd` instantiates the real `main.tscn` and
exercises its combat, ability, objective and save adapters. It contains focused
fixtures, **not whole-level traversal or difficulty verification**. Whole-run
checks are separate suites. No device, touch accuracy, rendering fidelity,
packaging, publication or later-world completion claim follows from this suite.

## Covered contracts

- The actual 1-4, 1-5, 1-S and 1-6 stage files load their authored wave,
  checkpoint and crate counts without granting skills or starting a boss early.
- Small Print robots retain one HP and 60% scale. Their speed is 190-230 px/s
  in 1-4 and 380-420 px/s in 1-5, which adds the source auto-scroll speed of
  190 px/s. Sixteen same-seed spawns in each stage check the exact difference.
- Checkpoints trigger at the camera midpoint once, heal one heart to two, and
  preserve an existing three hearts. They do not fully refill damaged players.
- Knockout freezes the scene. Continue restores three hearts and 2.5 seconds of
  invulnerability in place, preserving motion, camera/lock, checkpoint flags,
  wave progress, robots, crates, shots, coins, receipts, score, ability state and
  secret coin progression. Binman calls, timers and all hazard arrays survive.
  Repeating Continue while already playing cannot heal again.
- The real park card at `(8497, 442)` earns Slide through the actual pickup/save
  path. Save reload retains it; revisits do not duplicate it. An unported World 2
  card cannot grant its skill or acquire a false completion record.
- Binman requires completed approach waves and starts with 260 solo HP.
  A fresh attempt resets the encounter, helper flags and hazards.
- 1-6 ability helpers queue invisible projectiles rather than damage directly.
  Collision order is helper robot, Binman body/lid, crate, then the later bin
  pass. Helper damage honors the requested amount, Binman ignores that amount,
  and a crate/bin loses one HP per consumed projectile. Ordinary impacts do not
  recursively queue more ghosts. Target direction determines the helper shove.
- A ghost survives exactly 70 ms and expires after that. Its final eligible
  frame still reaches the late bin collision pass before expiry. Theo's free
  ball zap is emitted after that pass and first collides on the following frame.
- Ghost viewport bounds are strict on every edge: `x > camera - 40`,
  `x < camera + view_width + 40`, `y > view_top - 60`, and
  `y < camera_y + 580`. Inside, equality and outside cases are tested both in an
  empty actual scene and against a real late bin. Equality/outside shots are
  culled before bin collision. The top threshold is normalized to the same
  float32 precision as native `Vector2` positions, so its represented equality
  cannot accidentally survive a float64 comparison.
- Ama can grant two damage to an open Binman in the same frame, after which the
  boss clears dizzy. It cannot bypass the closed lid.
- The final boss shot immediately pops remaining helpers before later shots in
  the same main step. These cleanup pops do not count as player kills. Defeat
  schedules the bus and directly clears strictly after 2.6 seconds, without a
  Jar Thief pickup. Saving/banking the clear happens once.
- Retained bins, falling recycling and ordinary hostile bills can land a lethal
  hit on the frame the down timer passes 2.6 seconds. The source clear wins over
  global knockout, revives the player to one heart and banks/saves once. Repeated
  Continue, step or clear calls cannot bank again. Each hazard is also tested
  before that threshold: knockout freezes the timer, then Continue allows the
  same encounter to clear normally. Direct damage outside a main step remains
  immediate, including after clear/reload.
- Deferred knockout does not allow zero-heart revival via a same-frame
  checkpoint, heart item, weapon item, coin or receipt. A later hostile bill
  ignores the down player. Continue restores normal pickup eligibility and
  only the living receipt pickup persists.

## Source anchors and deliberate difference

Original `game/1-{4,5,6}/index.html` and `game/1-S/index.html` remain untouched.
The shared source checkpoint rule is at line 734. Continue is at 1-4:1180,
1-5:1190, 1-S:1203 and 1-6:1270. The park pickup logic is at 1-4:824-841.
The auto-scroll addition to Small Print speed is at 1-5:799.

In `game/1-6/index.html`, ordinary shot order is at 529-548; Binman initialization
and lid collision at 897-904; hazard update and direct clear at 914-954; ghost
helpers at 1342-1347; late ball effects and 70 ms expiry at 1528-1555. The native
renderer omits ghost-marked projectiles, corresponding to the source draw
wrapper at 1607-1608. This suite checks the projectile flag and gameplay path;
it does not make a screenshot/pixel-parity claim.
The clear-frame race follows source `updatePlay` order at 632-673: boss update
and its possible clear precede global knockout. `stageClear` at 626 revives a
down player to one heart for the celebration.

The source Binman initializer omits `fy`, even though generic ability code reads
it. Native `binman.gd` intentionally supplies `fy = ground`. This repairs the
non-finite ability target/gates: source Maya, ground-pound and Theo boss gates
fail, while Ama's NaN-position zap can still reach the source hit path. Native
finite-position behavior is intentional, **not exact parity with that bug**.

## Fixture limits and execution

Fixtures inhibit unrelated source waves, explicitly mark completed waves only
to isolate the boss-entry gate, and place actors/hazards to test overlapping
collision targets. They do not establish that a player can naturally reach
those positions or defeat an unmodified encounter. Audio uses the existing
silent test adapter; audio quality is verified elsewhere.

Run with isolated save/config directories so personal progress is never used:

```sh
work=$(mktemp -d /tmp/bd-street-integration.XXXXXX)
mkdir -p "$work"/{home,cache,config,data}
HOME="$work/home" XDG_CACHE_HOME="$work/cache" \
  XDG_CONFIG_HOME="$work/config" XDG_DATA_HOME="$work/data" \
  godot --headless --path godot --script res://tests/test_street_expansion.gd
```

Validated on Godot 4.6.3: 259 checks, zero failures, with no engine script errors.
