# Festival after-dark actual-input verification

Verified 2026-11-09 with Godot4.6.3 headless, all six housemates. The test never bypasses the native support gate.

`godot/tests/test_full_festival_night_run.gd` loads the actual main scene, disables automatic physics, and supplies movement, jump, crouch, aim and shoot controls at 60 Hz. Explicit per-frame invulnerability is the sole progression assist. It does not write player/camera coordinates, boss/enemy health, receipt flags, wave indexes, or runtime objective state. Every housemate begins with an isolated fresh save and no learned skills.

The route physically climbs the authored bale steps and all three camper roofs, overlaps receipts at (5450,222), (10650,222), (13300,222), jumps fires using normal input, traverses mud, triggers the real checkpoint and fade, waits for actual Bailiff throw/charge/stomp patterns before shooting, defeats and dismisses the miniboss, dispatches all ten waves, and awaits the real timed exit. The final route has zero fire contacts and zero falls for every housemate, asserted and counted explicitly. Earlier navigation attempts did contact the8650fire during the Bailiff down animation and fell near14693; the final controller keeps fire avoidance active during down and jumps70px before a fire instead of95px. Only ordinary input timing changed. Invulnerability means these results are not evidence of unaided difficulty balance.

Source quirks retained: stage width15400 although final solid extends to15800; 48 solo entries versus65 pair entries; failed spawn placements consume entries; unseen entrants can time out after6seconds and stale bots retire after12seconds despite the source comment saying14. Mini starts at camera7740 but owns lock8000; checkpoint/fade trigger uses living-player x>7000 and callback moves camera to7900. Receipt centers are not ground feet and award no money. Three authored coin rows each contain five seeds, totaling15; their coordinates are checked separately from earned/drop coins. The70HP solo Bailiff (95HP pair) has no jar reward.

Accounting verifies dispatches minus placement failures plus boss summons equal observed bots, and classifies pops, stale retirements, entry timeouts and other removals. Postclear steps cannot duplicate saved score. Disk reload must retain the actual clear and all three receipts.

Execution must use isolated HOME and XDG directories under /tmp. A zero process exit alone is not sufficient: script errors, parse errors, resource leaks and orphan warnings invalidate the run. This is headless functional evidence only, not native-device, difficulty, graphical or visual-parity evidence.

## Final run results

Every character:10/10 waves,48/48 entries,0 placement failures,4 boss summons,52 observed bots,3 receipts,15 exact coin seeds,15 bale landings,all3 roof landings,70 boss damage,0 fire contacts,0 falls. No camera culls or scene removals occurred. All observed non-pop removals were identified6-second entry timeouts; all retirements satisfied the actual12-second since-hit predicate.

| Housemate | Ticks | Pops | Retirements | Entry timeouts | Score |
| --- | ---: | ---: | ---: | ---: | ---: |
| JP | 8817 | 44 | 6 | 2 | 224 |
| Maya | 9486 | 44 | 6 | 2 | 204 |
| Ama | 10554 | 43 | 5 | 4 | 205 |
| Leo | 8817 | 44 | 6 | 2 | 214 |
| Theo | 8817 | 44 | 6 | 2 | 214 |
| Mei | 8909 | 44 | 5 | 3 | 192 |

All six observed enter,walk,stomp,charge,throw,down and live shockwaves. Shots are withheld until the real boss has shown charge,throw and shockwaves; no animation/state/time is assigned. Exit completion follows156 simulated frames after the ending predicate first activates. No special ability or learned skill is required. The route does not collect the wellies item and does not claim a wellies stomp; those are separate field/rules coverage.

These routes use direct fresh-save level loads. The parent campaign integration fixture separately verifies the3-clue handoff with explicit prerequisite progression; this route does not forge prerequisite clears or story state.

Reproduce from the repository root:

```sh
home=$(mktemp -d /tmp/bill-dodgers-night-XXXXXX)
HOME="$home" XDG_DATA_HOME="$home/data" XDG_CONFIG_HOME="$home/config" \
  /usr/local/bin/godot --headless --path godot \
  --script res://tests/test_full_festival_night_run.gd > "$home/run.log" 2>&1
status=$?
cat "$home/run.log"
if grep -Eiq 'SCRIPT ERROR|Parse Error|ERROR:|WARNING:|leaked|Orphan' "$home/run.log"; then exit 2; fi
exit "$status"
```

Use `-- --character=ama --trace` for a single character with detailed input-route evidence, or `-- --jp-only` for JP. Final logs were checked for engine/script/resource errors rather than trusting exit status alone.
