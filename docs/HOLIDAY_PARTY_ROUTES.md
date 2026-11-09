# World 4 CPU route acceptance

## Harness

`godot/tests/test_full_holiday_party_runs.gd` runs admitted production main
sessions across all seven World 4 stages. P1 uses the existing solo holiday
ordinary-input controller. The Captain controller in
`holiday_party_captain_controls.gd` is extracted from the existing solo Captain
route. P2 uses the unmodified production `CompanionAI`, including source
catch-up behavior, normal targeting, movement, firing and special decisions.

The default first pass is human JP with CPU Maya. `--all-cpu` exercises all six
CPU identities. CPU JP uses human Maya because the source rejects duplicate
housemates; every other CPU identity uses human JP. This matrix is not all 30
ordered housemate pairs and does not test independent two-human route control.

The sole gameplay assist is refreshed 999-second invulnerability for both
actors. Source falls and pedalo water recovery explicitly clear that protection
before applying damage, so these can still cause downed actors. No health,
position, camera, source geometry, wave, enemy, timer, pickup, ability meter,
CPU-state or completion modifications occur inside the route loop. Source
midpoint/fall/water/catch-up relocation is retained and distinguished from human
navigation. Input choices may be adapted in the test driver if a party encounter
needs a different firing lane; any such adjustment must stay ordinary input and
be documented below. Game mechanics or source CPU changes require a separately
proven defect and regression fixture.

## Acceptance checks and observations

Every run checks actual mode admission, distinct identities, exact source g+x2
wave order, one shared clock, final restored P1 facade, all authored waves and
entries, all three physical receipts, source gates/set pieces, saved normal
clear and unchanged imported metadata. Stage-specific checks cover physical
Dash acquisition/shared unlock, all eight sponsored time gates, the hold and its
half-time Bailiff, and the 120-HP Captain's three phases and physical jar. A CPU
must emit an observed owned shot; actual earned pops are recorded without an
invented per-stage kill quota. Captain routes also require a real CPU boss-hit
tally. The initial JP+Maya pass exposed zero CPU pops on the pedalo despite 397
observed CPU shots and 38 personal coins. Source W4 CPU lacks custom low-foe
aiming/ducking, so that result is disclosed rather than altering its behavior.

Per-route JSON records report:

- tick count, wave/entry counts, physical receipts, gates and set pieces;
- both actors' pops, personal coins, observed projectile counts, jumps and Dash;
- source CPU catch-up event count, deduplicating stale event identities when a
  water hit downs the CPU before its next controls call;
- downed frames/events and nearby, checkpoint or clear rescues separately;
- normal fall/water recoveries and actual health lost despite the assist;
- Captain HP, accumulated damage, observed states/phases and owned boss hits;
- final mode, actor positions, camera and any acceptance failures.

Observed projectile counts include shots surviving the frame's collision pass,
so they are a lower bound on emitted projectiles, not an exact firing counter.
Catch-up counts are not proof of pathfinding. Successful assisted routes do not
establish normal-health difficulty, human playability or physical device/input
acceptance.

## Running

Use one bounded Godot process with an isolated writable HOME and XDG directories.
Do not overlap the matrix with a pack export or other memory-heavy suite.

```sh
work=$(mktemp -d)
export HOME="$work/home" XDG_DATA_HOME="$work/data"
export XDG_CONFIG_HOME="$work/config" XDG_CACHE_HOME="$work/cache"
mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
# Seven JP+Maya routes first.
timeout 300s godot --headless --path godot \
  --script res://tests/test_full_holiday_party_runs.gd -- \
  --output=/tmp/holiday-cpu-jp-maya.json
# Then all 42 source-stage/CPU-identity combinations in one process.
timeout 900s godot --headless --path godot \
  --script res://tests/test_full_holiday_party_runs.gd -- \
  --all-cpu --output=/tmp/holiday-cpu-matrix.json
```

Filters: `--stage=4-4`, `--cpu=ama`, `--trace`, `--max-ticks=60000`.
JSON output is overwritten after each completed attempt so interrupted runs do
not discard already-finished evidence. A 120-second no-progress bound stops
stalled routes, except the source's active 150-second towel hold.

## Completed results

**42/42 unique stage/CPU combinations have passing evidence**, covering seven
stages and all six CPU identities. These rows total 383,759 fixed simulation
ticks, 354 waves, 1,794 authored pair entries, 126 physical receipts, 30 manual
gates, 42 set pieces and 42 saved normal clears. Each of the six sponsored runs
also crossed all eight bonus gates. Each Captain run consumed the full 120 HP,
visited all three phases and all six observed states, collected the physical
jar and recorded actual CPU-owned boss hits.

The acceptance file is
[`verification/holiday_party_cpu_acceptance.json`](verification/holiday_party_cpu_acceptance.json).
It combines **36 non-Captain rows from the first full matrix** with **six Captain
rows from the final Captain-only matrix**. Every row names its original evidence
file. This is passing coverage across these runs, not a claim that the first
single-process 42-route attempt passed unchanged. Raw evidence is retained:

- `verification/holiday_party_first_matrix.json`: 41/42 passed. The remaining
  CPU-JP Captain route stalled in the human driver's ordinary-input approach.
- `verification/holiday_party_captain_driver_stall.json`: isolated reproduction
  of that human-controller stall, with the live enemy and actor geometry.
- `verification/holiday_party_captain_jp_repair.json`: isolated passing rerun
  after the input-only driver repair.
- `verification/holiday_party_captain_final_matrix.json`: all six Captain CPU
  identities passed with the final driver, in 4,511–5,188 ticks each.

Final accepted CPU observations:

| CPU | Pops | Catch-ups | Downs | Downed frames | Checkpoint rescues | Clear rescues | Captain hits |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| JP | 152 | 4 | 5 | 20,518 | 3 | 2 | 70 |
| Maya | 143 | 4 | 2 | 8,258 | 1 | 1 | 44 |
| Ama | 138 | 3 | 4 | 15,710 | 2 | 2 | 63 |
| Leo | 153 | 6 | 5 | 17,083 | 3 | 2 | 56 |
| Theo | 156 | 3 | 4 | 15,411 | 3 | 1 | 55 |
| Mei | 135 | 0 | 4 | 13,260 | 3 | 1 | 71 |

Across the accepted rows the CPUs earned 877 pops and 1,397 personal coins,
produced at least 8,986 owned shots, had 60 normal fall recoveries and 34 water
recoveries, and lost 83 actual hearts despite the invulnerability assist. All
24 downings occurred on the harbor or pedalo. Source checkpoint healing rescued
15; normal clear rescued nine. The ordinary-input human driver did not stop for
proximity revivals, so none occurred in these route runs. Actual-main fixtures
separately exercise that revival path. Humans had eight fall recoveries and
seven actual hearts lost, but no downings.

These observations expose source companion limitations rather than mask them:
all six CPUs fell and went down on the harbor; five went down on the pedalo;
JP, Ama, Leo and Theo recorded no pedalo pops. Source AI was not changed to make
the acceptance metrics look better. The party cleared while companions were
sometimes down and relied on source checkpoint or clear healing.

### Human Captain driver repair

The extracted solo driver only considered bots within 450 px horizontally and
70 px vertically. Pair wave timing let the human descend before a late flat bot
on the 362 px roof was defeated. In the isolated failure, the camera was locked
at x=1,741.775, the human stood at (2,449.774, 482), and the last live four-HP flat
bot stood at (1,799.36, 362). The original driver kept walking into the right
camera boundary; the source CPU's standing horizontal shot could not reach the
roof either.

`holiday_party_captain_controls.gd` now remembers that visible elevated bot and
uses ordinary human walk, jump, aim, shoot and special inputs to approach its
actual platform. It holds that approach through the jump until the human is at
the firing height, or the target is defeated. The final six runs used 119–124
such input frames each. No actor, CPU, enemy, surface, camera, wave or game
production code was modified for this repair. The final Captain reruns had no
falls, water recoveries, catch-ups or downed frames.

### Initial JP+Maya pass

Initial JP+Maya: **7/7 natural clears**, all source pair wave entries and all 21
physical receipts. The initial harness reported 6/7 acceptance because it also
required a CPU pop on every stage, an unsupported condition removed after the
source aiming audit. The unchanged initial output, including that failed
assertion, is retained in
`verification/holiday_party_initial_jp_maya.json`.

The source CPU remains unchanged. On 4-4 Maya had 16 normal fall recoveries,
eight hearts lost, two downings and 8,360 downed frames, with one checkpoint
rescue and one clear rescue. On 4-5 she fired 397 observed shots, earned 38
personal coins and zero pops, with six water recoveries, one downing, 2,493
downed frames and one checkpoint rescue. On 4-6 she landed 58 real Captain hits
and earned four pops; the actual 120-HP Captain traversed all three phases and
all attack states before the normal jar clear.

The initial and later Maya results differ because a sequential matrix uses a
different ordinary RNG history. Both raw runs are preserved. Assisted clear
counts are not evidence that the companion navigated every obstacle
independently or stayed alive throughout every route. Normal-health balance,
all 30 ordered housemate pairs, full two-human routes, physical controller/touch
behavior, rendering, mobile export and deployment remain outside this evidence.
