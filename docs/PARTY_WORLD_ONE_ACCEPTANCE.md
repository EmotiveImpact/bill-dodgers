# World 1 party progression evidence

## Scope

These are internal Godot integration tests, not release or device acceptance.
The UI offers local pair modes without claiming finished mobile co-op. A second actor uses the
normal actor movement, ability and damage paths; one shared frame advances waves,
projectiles, scene timers, camera, boss and objectives. The tests do not run the
whole game step twice.

All route tests use only normal leader control dictionaries after level setup.
Both actors receive explicit invulnerability as a progression assist. They do not
teleport actors, restore hearts, edit damage, skip waves, alter imported geometry,
fill ability meters, advance timers or force completion. CPU intent is the ported
source AI. This does **not** prove difficulty, survival, physical input or mobile
performance. Source fall recovery can intentionally reset invulnerability and
hurt an actor even in these assisted tests.

## Route drivers

- `test_full_party_rooftop_run.gd`: 1-2, all 56 route waypoints, 14 roofs and 12
  crumbling slates, all 11 waves, both escape climbs, zero leader falls, timed
  exit, original geometry and actual persisted clear.
- `test_full_party_bus_run.gd`: 1-3, source 12-fight / 25-obstacle ordering, leader
  ducks every obstacle, no leader obstacle hit, fixed camera, final timed exit.
  CPU obstacle hits are counted separately.
- `test_remaining_party_street_runs.gd`: 1-4, 1-5 and 1-S, all 10/14/4 waves,
  actual park slide card and disk reload, all 52 alley obstacles, actual bonus
  coin rows and pickups, forced-scroll continuity and persisted clears.
- `test_full_party_binman_run.gd`: 1-6, two complete party-scaled approach waves,
  actual 340-HP boss and all three phases, five party threshold helpers, throw /
  roll / slam attacks, bins, shockwaves, recycling, lid collisions, ordinary and
  special attacks, source direct down-to-clear timing and persisted clear.

Each accepts `--jp-only` or `--character=leo` after Godot's `--` separator.
`--cycle-mates` chooses each leader's next housemate in the source character list:
JP+Maya, Maya+Ama, Ama+Leo, Leo+Theo, Theo+Mei, Mei+JP. Without the flag, the mate is
Maya except Maya's mate is Theo. Logs state the actual mate, observed CPU special
activations, CPU deaths, down frames, nearby revives and final clear rescue.

## Completed first matrix

Every leader cleared each of the six stages above through the real native
runtime. The initial rooftop pilot failed because CPU contact can start a shared
slate timer before the leader arrives. The test pilot now reads the live warning
time and sends an ordinary jump before it expires. Leo's solo pilot also needed
safer launch and landing controls at changed pair-combat charge timings: it now
launches the glider from a broad solid roof and lands using the real down input
before resuming the escape climbs. No gameplay physics or source AI was changed
to make those pilots pass.

The original six-leader solo matrix across all seven W1 stages also remained
green after the scene and combat adapter changes. Its explicit invulnerability
assist has the same limitation as the pair tests.

## Source behavior that the tests do not hide

The original CPU does not have a special bus-obstacle duck routine. The current
JP+Maya bus run records all 25 CPU obstacle contacts while the human pilot ducks
all 25. This is logged separately rather than silently adding better AI.

A CPU can fall, go down and remain behind if the leader does not return to help.
Source stage clear rescues a downed mate. For example, the first Leo+Maya rooftop
run that met every zero-leader-fall assertion recorded one CPU death and 15,622
CPU-down frames before final clear rescue. A green progression result therefore
must not be described as proof that both actors survived or independently
traversed every support. Dedicated proximity-revive and all-down/Continue
fixtures cover those mechanics separately.

## Completed all-CPU-identity cycle

The six next-housemate pairs also pass every one of these six stages: 36 route
cases. Each rooftop leader reaches every support with zero falls. Every CPU
identity activates its own actual special at least once across this cycle; each
uses its own special three times in the Binman encounter. All source-scaled
Binman cases exercise 340 HP, the three phases and all five helpers.

With the explicit invulnerability assist, there are no CPU deaths in the bus,
park, alley, bonus or Binman cycle runs. All six rooftop CPUs eventually go down
and are rescued by stage clear. Those counts remain in the test output and are
not hidden by checking only health after clear.

Verification logs are `/tmp/party-cycle-roof.log` (6 cases) and
`/tmp/party-cycle-other.log` (30 cases). Both completed with no failed assertions,
script errors, engine errors or leak warnings. The first six-leader matrix is
separate, with the Leo rooftop zero-fall pilot rerun recorded in
`/tmp/party-roof-leo3.log`.

## Separate acceptance

Reachable selection and the other five world adapters now have separate evidence
in `NATIVE_PARTY_ACCEPTANCE.md`. Human P2 input throughout a route, controller
mapping and real multitouch/device tests remain separate requirements. Synthetic key events
are not physical keyboard or controller validation. The existing complete-game
save and campaign checks must remain green after those integrations.

The additional 1-1 six-CPU identity cycle is preserved in
`validation/world_one_party_street_cycle.log`; the six other stages are in
`validation/world_one_party_rooftop_cycle.log` and
`validation/world_one_party_other_cycle.log`. Together these record 42 cases.
