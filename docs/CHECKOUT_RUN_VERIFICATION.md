# Checkout puzzle: ordinary-input progression verification

Status: **all six housemates pass the integrated ordinary-input 2-6 progression suite**, 2026-11-09, Godot 4.6.3. Each run completes the actual approach, three-phase puzzle, receipt climb, jar collection and persisted clear. Invulnerability is explicitly enabled; this is progression evidence, not difficulty or device certification. The initial pre-integration invocation correctly refused to run while 2-6 was preview-only.

## Scope and source

Owned files are `godot/tests/test_full_checkout_run.gd` and this report. The active source is `game/2-6/index.html:1200–1367`, with the shared projectile/jar order documented in `CHECKOUT_BOSS_PARITY.md` and `WORLD_TWO_IMPLEMENTATION.md`, section 5. The source's active checkout object is TB, not the copied dormant Jar Thief `boss`.

The suite instantiates the real main scene and steps it at 60 Hz with ordinary left/right, jump, down, aim, fire and special inputs. The only gameplay assist is explicit player invulnerability before each frame. It starts from a fresh isolated save with no earned movement skills. It does not teleport, change boss HP/phase/timers, alter waves or enemies, spawn or move crates, create platforms, synthesize hits, or grant clear/save tokens. Read-only controller snapshots select the route and collect evidence.

**Invulnerability may suppress scanner bagging. This progression run cannot replace the isolated real-damage, shield-but-bagged, mash/release and bag recovery fixtures. It is not a difficulty, mobile touch, renderer or device certification.**

## Executed route and assertions

- Complete all three authored approach waves and dispatch/defeat all 14 actual enemies: five rush, three throw, four cart, one drone and one security bot. No abandonment counts as a kill.
- Collect the three actual lane receipts at (1100,390), (2900,390), (3500,390), using source body-overlap rules.
- Reach the camera endpoint legitimately; observe the stationary 70-HP solo TB boot for strictly more than 1.4 seconds. Keep `host.boss` null throughout, preserving shared special auto-target blindness.
- Fire real projectiles and activate the current housemate's naturally charged special during phase 1 while its HP remains 70. Observe three complete actual scanner tells, harm windows and completion transitions before phase 2.
- Ground-pick, carry and auto-throw three distinct boss crates. Observe every fall/ground/carry/fly/on state, exact 650 ms sine-arc flights and all three tray targets, including x4906 beyond the level width. Freeze must follow actual completed flights.
- Damage only during genuine freeze windows using real shots and fixed source damage. Each normal frozen hit is checked for 2/3 damage (or floor truncation) and exactly one boss-hit credit. Reach the 21-HP floor, then observe freeze expiry and the subsequent phase-3 transition. Every tested housemate required two genuine crate batches and two freezes, totaling six completed crate flights. No reset or manually extended freeze is used.
- Observe the immediate helper pair and all three receipt stairs created at strictly more than 600 ms intervals. Land on each actual one-way surface in order before firing from the top to defeat TB. Normal screen hits are checked for exactly 3 damage and one boss-hit credit. No body-chip shortcut substitutes for this route.
- Observe defeat cleanup without an early clear, the delayed jar spawn and source same-frame jar physics. Demonstrate rejected young-jar horizontal overlap, then collect through the real age-gated horizontal condition, including a vertical separation greater than 50 px.
- Verify the actual completion pathway, banked loose coins, persisted 2-6 clear and three receipts after disk reload, no unearned skills, and no duplicate rewards over 180 post-clear updates.

## Running

Use Godot 4.6.3 with a dedicated temporary HOME and XDG cache/config/data directory. From the repository root:

```sh
work=$(mktemp -d /tmp/bd-checkout-run.XXXXXX)
mkdir -p "$work"/{home,cache,config,data}
HOME="$work/home" XDG_CACHE_HOME="$work/cache" \
XDG_CONFIG_HOME="$work/config" XDG_DATA_HOME="$work/data" \
godot --headless --path godot --script res://tests/test_full_checkout_run.gd
```

Append `-- --jp-only` for JP, `-- --character=maya` for one housemate, or `-- --trace --trace-limit=160` for bounded diagnostics. The route is bounded at 24,000 simulated frames per character, never an unbounded wait.

## Evidence

Final all-six run: `/tmp/bd-checkout-final.AkCUSw/full.log`. All six reported PASS, process exit 0, no parse/runtime errors or leaked-object warning. This strengthened final run also checks each applicable fixed-damage hit and prevents a premature in-memory saved clear.

| Housemate | Simulated frames | Jumps | Aim-input frames | Duck-input frames | Final banked score |
|---|---:|---:|---:|---:|---:|
| JP | 3495 | 20 | 31 | 125 | 133 |
| Maya | 3500 | 20 | 32 | 125 | 129 |
| Ama | 3477 | 17 | 32 | 125 | 129 |
| Leo | 3520 | 20 | 31 | 124 | 129 |
| Theo | 3497 | 20 | 31 | 125 | 128 |
| Mei | 3462 | 21 | 43 | 125 | 129 |

For every housemate:

- 3/3 approach waves, 14/14 actual enemies spawned and genuinely defeated, receipts `[0,1,2]`.
- 3/3 complete phase-1 scanners; actual low y448 and high y332 observed. Ordinary shots and the naturally charged housemate special run without reducing phase-1 HP. `host.boss` remains null, codes remain empty and dizzy remains zero.
- Two batches of kinds0/1/2, six full crate lifecycles, six verified sine-arc flights, two real error freezes, exactly49 damage to the phase-2 floor of21HP.
- All three live receipt surfaces generated and landed on in order. Real phase-3 screen shots defeat TB and source cleanup pops the helper pair.
- 36 frames of horizontal jar overlap rejected while too young. Actual collection occurs with a150.58px vertical separation for five housemates and160.08px for Mei, proving this route uses the source horizontal-only pickup condition rather than an invented vertical restriction.
- Real saved checkout clear, all three persisted receipts, no earned skills, exact one-time banked reward, and unchanged save/score through180 further updates.

The earlier detailed JP trace is `/tmp/bd-checkout-jp.tgZ0oG/run.log`. It records boot frame1693, phase2 frame2318, freezes2439/2925, floor3147, phase3 frame3148, actual stair landings3214/3251/3288 and defeat3368. Initial parse/preview refusal was `/tmp/bd-checkout-parse.OTn9Nk/parse.log`.

### Isolated regression fixture repaired and passing

The initial integrated isolated-suite attempt encountered an inherited `checkout` member redeclaration in its `RuntimeWorld` fixture. The integration owner repaired the fixture to use the controller supplied by the real world reset. The subsequent `test_checkout_boss.gd` run reports **207 checks, 0 failures**, with no errors, verified in `/tmp/checkout-fixture-fix.log`. The former parse failure is resolved. These isolated contracts complement the invulnerable progression run, particularly the real-damage bag behavior that the full-run assist cannot exercise.

The integration owner also reports 149 real-damage/lifecycle main-scene checks passing at this point. That separate suite is owned and documented by the integration worker; its final evidence remains independent of this six-housemate report.

No runtime files, deployment settings, exports or commits were changed by this test owner. The integration owner remains responsible for registration in the aggregate native suite, packed verification, visual/device checks, next-stage UI handoff and honest capability promotion. This report does not certify those separate steps.
