# Remaining World 1 street progression

`godot/tests/test_remaining_street_runs.gd` runs the native main scene through
the park (1-4), back alleys (1-5), and late shop dash (1-S), for all six
housemates. It reads the imported layouts without replacing or modifying them.

## Scope and limits

This is a deterministic, bounded **progression test**, not difficulty, visual,
audio, touch, mobile-device or human playtesting. Invulnerability is the only
gameplay assist. The controller supplies the same move, jump, duck, aim, shoot
and power inputs consumed by normal gameplay. It never teleports actors, changes
damage, supplies enemies, alters wave state or invokes completion.

Each character begins with a fresh isolated native save. The test collects the
park's real slide card, checks its immediate disk save, reads that save back,
loads the alley normally, and uses the earned slide with a run-then-duck input.
It never inserts a skill into the saved or runtime skill list. All three clears
must be earned by the native objective and survive the native save reader.

## Source contract

Reviewed against `game/1-4/index.html`, `game/1-5/index.html`,
`game/1-S/index.html`, and their imported `godot/content/levels/*.json` META:

- **Park:** width 14,400; ten waves; six solid raised props; source slide-card
  coordinates (8497, 442). Pickup uses the source strict horizontal and
  feet/body vertical overlap tests. Navigation jumps from the approach to each
  imported solid and descends elevated props to fight ground robots.
- **Back alleys:** width 40,000; fourteen waves; 52 source obstacle props;
  190 px/s forced scroll. The camera must advance on every eligible frame,
  including live combat, without acquiring an ordinary wave lock. The route
  crosses every obstacle and exercises actual jumps across at least 50 above
  their top. Source automatic wall-lift remains available for missed approaches.
- **Late shop dash:** width 22,000; four waves; seventeen original awnings;
  250 px/s forced scroll. The test observes all 39 eight-coin rows as they are
  generated, checking all four source height patterns, 46-pixel coin spacing,
  560-pixel row spacing and initial resting state. The controller jumps toward
  high coin rows. It counts collection of references to genuine native row
  coins, excluding expired/off-screen coins and the final clear-screen banking.
- **All three:** every source wave must start at its camera trigger and issue
  every configured spawn before finishing. Completion requires the last camera
  position and all waves done, then the source 2.6-second end timer. At 60 Hz,
  the clear occurs 155 ticks after the first ending frame. No boss is expected.

## Verified results

Godot 4.6.3, headless, fixed 1/60-second input steps, isolated HOME/XDG save state:

| Housemate | Park ticks | Alley ticks | Bonus ticks | Alley props crossed above top | Bonus row coins collected |
| --- | ---: | ---: | ---: | ---: | ---: |
| Jean Phil | 5,578 | 11,563 | 4,900 | 52 / 52 | 310 |
| Maya | 5,797 | 11,555 | 4,912 | 50 / 52 | 305 |
| Ama | 5,980 | 11,598 | 4,912 | 52 / 52 | 304 |
| Leo | 5,775 | 11,681 | 4,896 | 52 / 52 | 305 |
| Theo | 5,667 | 11,546 | 4,909 | 51 / 52 | 305 |
| Mei | 5,237 | 11,518 | 4,886 | 52 / 52 | 306 |

All 18 runs passed. Every housemate collected the actual card, persisted and
reloaded slide, used the reloaded slide, crossed all 52 alley props, completed
10/14/4 waves, and saved all three clears. No source geometry was changed. Final review restored the source tiny-bot
auto-scroll speed bonus in the alley (380–420 px/s); these results are from
the complete rerun after that correction.

Run with the isolation used by `scripts/verify-native.sh`:

```sh
work="$(mktemp -d)"
mkdir -p "$work/home" "$work/data" "$work/config" "$work/cache"
HOME="$work/home" XDG_DATA_HOME="$work/data" \
XDG_CONFIG_HOME="$work/config" XDG_CACHE_HOME="$work/cache" \
godot --headless --path godot --script res://tests/test_remaining_street_runs.gd
```

Append `-- --jp-only` for a focused Jean Phil route during debugging. The
default runs all six housemates. The simulation stops after at most 60,000
steps per stage and reports remaining enemies if a route does not finish.
