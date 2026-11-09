# Ticket Tout actual-input route verification

Verified 2026-11-09 with Godot 4.6.3 headless. All six solo housemates pass the actual `main.tscn` 3-6 route in `godot/tests/test_full_ticket_tout_run.gd` without bypassing native capability gates. This is functional simulation evidence, not a browser comparison, screenshot assessment, iOS/Android device test, export/signing check, or difficulty/playability claim.

## Test scope and restrictions

Each housemate starts from the actual `(300,482)` spawn, an isolated fresh save and no learned skills. Automatic physics is disabled and the test sends ordinary left/right, jump, aim and shoot inputs through `game.step(1.0/60.0, controls)`. Navigation can issue the ordinary down+jump drop input when appropriate. It does not invoke damaging abilities or grant skill cards. The only progression assist is explicitly refreshing invulnerability. It never writes player/camera positions, enemy or boss HP, waves, objective timers, receipt flags, stage/hop state, jar state or native capability gates. Pause and Resume use the existing UI callbacks.

The full physical route crosses and lands on both authored barriers, both bale surfaces, and the stage platform. Receipt overlap must occur at the exact source centers `(1820,312)`, `(2000,252)`, `(4170,282)` and award no currency. All nine surfaces are physically visited; each run uses five actual jumps and zero fall recoveries.

All three real approach waves at camera 400/1500/2600 must start, consume all ten solo entries and finish. Thirteen pair entries remain intact in imported metadata, but pair gameplay is not tested. Boss creation must wait for completed waves and camera >=3660. It must create the actual non-mini 160-HP Tout with arena lock 3662 and the source first-tick entry clamp to x4310.

The controller holds fire until real attacks are observed, reduces HP through normal projectile collision, and holds fire again around the middle and low-health thresholds. It changes input timing and position instead of assigning HP, stage state, cooldowns, randomness, animations or helper state. Every run observes:

- Ground three-wristband throws and 420 px/s stomp shockwaves.
- Numeric `l3.stage = 0` ascent to `(4165,354)`, 0.8 seconds and height160, selecting the source `surf` strip.
- A full nine-second stage countdown, five-wristband stage throws, and the normal 0.9-second/height140 return slam with 460 px/s shockwaves.
- The real below-half-health 2.6-second dizzy interval and damage while dizzy.
- Both source helper thresholds, totaling four additional solo robots.
- Below-one-third-health 0.85-second/height230 jump-slams and four-wristband throws.
- All seven animation selections: walk, hide, stomp, throw, surf, dizzy and down. The simulation-owned movement snapshot agrees with each updated boss position/time. This does not by itself establish rendered pixel parity.
- At least160 HP of real projectile damage, actual boss down, delayed jar spawn and jar pickup as the sole clear event. Ordinary timed ending remains disabled throughout.

The source low-health jump-slam condition does not require ground level. Maya and Ama additionally exercise a 0.85-second low-health jump starting from stage height354. It is distinct from the 0.9-second timed return. The test classifies these by the actual hop duration and validates both, rather than incorrectly assuming every hop beginning at354 is the timed return. No runtime behavior was changed for this distinction.

## Jar, pause and persistence

Boss death must leave play active and the jar absent. The jar appears after the actual down delay. Every run stays away long enough to exercise age >1.4-second attraction; each subsequent observed x increment must match **magnet first, then jar physics**, using the previous jar age. No clear is allowed while the jar is uncollected, and ages <=0.6 seconds cannot collect. Final overlap is within50px and the live jar's `got` flag accompanies clear. These full routes deliberately collect after1.4seconds; close-overlap threshold boundary fixtures remain the isolated finale/boss suites' responsibility.

During the first stage landing, Pause freezes player/camera, boss, waves, robots, bullets, score and world time for60 attempted simulation steps, including attempted movement/fire/special input. Resume keeps the same live encounter. The final disk save must contain the real3-6 clear, receipts `[0,1,2]`, no unearned skills and exactly the earned score. Another180 postclear steps must not change score or the saved settlement. This route does not manufacture prerequisite campaign clears or claim story/campaign transition coverage.

## Final six-character results

All six: 3/3 waves, 10/10 entries, **0 failed placements**, **4 helpers**, **14 observed robots**, all three receipts, all nine surfaces, five jumps, zero falls,160 boss damage, paused-stage stability, all required attacks and seven animation selections. No6-second entry timeouts, camera culls or unclassified removals occurred. Every retirement satisfies the actual source >12 seconds since last hit, not the stale14-second source comment. All observed actors are accounted for as popped or retired; retirement is not mislabeled as a kill.

| Housemate | Simulation ticks | Pops | Source retirements | Jar pickup age (s) | Magnet frames | Banked score |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| JP | 13654 | 10 | 4 | 5.067 | 219 | 65 |
| Maya | 9584 | 10 | 4 | 3.267 | 111 | 56 |
| Ama | 9576 | 12 | 2 | 5.000 | 215 | 65 |
| Leo | 13690 | 9 | 5 | 5.017 | 216 | 57 |
| Theo | 13641 | 10 | 4 | 5.067 | 219 | 60 |
| Mei | 9339 | 12 | 2 | 2.867 | 87 | 72 |

The suite processes69,484 active simulation ticks across the six routes, plus pause/postclear checks. Per-character differences are expected from actual passive movement, collision geometry and deterministic encounter timing. No special activation or learned skill is needed.

### Contact and assistance limits

Invulnerability prevents HP loss and knockout. It does not suppress tied legs, source movement/camera rules, collision, actor retirement or jar timing. The route is intentionally not an unaided survival run. Long holds used to observe attacks create many potential contacts; do not call it a no-hit route.

The following are sampled contact counters, not damage totals or unique hits. Enemy/body/wave values count overlapping actor-frames after the actual update. Boss body sampling excludes enter/down/hop snapshots; a hop landing frame still returns before damage, so the samples can include potential rather than applied contacts. Hostile-projectile counts observe a removed projectile overlapping the player after its update. Tied frames count the real runtime tie timer, which still activates despite invulnerability. These samples are diagnostic rather than an exhaustive instrumentation of every harm call.

| Housemate | Enemy body frames | Tout body frames | Shockwave frames | Projectile contacts | Tied frames |
| --- | ---: | ---: | ---: | ---: | ---: |
| JP | 259 | 2590 | 211 | 20 | 910 |
| Maya | 245 | 1454 | 92 | 20 | 924 |
| Ama | 293 | 1459 | 99 | 22 | 1056 |
| Leo | 759 | 2576 | 210 | 20 | 914 |
| Theo | 259 | 2589 | 211 | 20 | 910 |
| Mei | 574 | 1456 | 114 | 20 | 792 |

## Reproduce

From the repository root:

```sh
home=$(mktemp -d /tmp/bill-dodgers-tout-XXXXXX)
HOME="$home" XDG_DATA_HOME="$home/data" XDG_CONFIG_HOME="$home/config" \
  /usr/local/bin/godot --headless --path godot \
  --script res://tests/test_full_ticket_tout_run.gd > "$home/run.log" 2>&1
status=$?
cat "$home/run.log"
if grep -En 'SCRIPT ERROR|Parse Error|^ERROR:|ObjectDB instances leaked' "$home/run.log"; then exit 2; fi
exit "$status"
```

Use `-- --character=ama --trace` for a single housemate and detailed route/spawn/boss evidence. Unknown housemate arguments fail explicitly. The verified final all-six run exited0 and had no script errors, parse errors, engine errors or leaked ObjectDB instances. Only this new route test, its UID and this report are owned by this verification work; no shared runtime code, source HTML, deployment or repository visibility was changed.
