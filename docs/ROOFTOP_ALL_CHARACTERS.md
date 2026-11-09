# Rooftop progression with all six housemates

`godot/tests/test_full_rooftop_run.gd` now runs the original 1-2 rooftop route
with Jean Phil, Maya, Ama, Leo, Theo and Mei by default. `--jp-only` retains a
focused Jean Phil run. This changes only the test driver, not gameplay or the
original web source.

## Verified scope

Each character starts with a fresh isolated native save and no unlocked skills.
The driver sends ordinary left/right, jump, fire, duck, aim and charged-special
inputs to the native `step()` function at 60 Hz. Invulnerability is the only
progression assist. It never changes player position, velocity, health, enemy
state, wave progress, level geometry, ability meter, exit timer or completion.

Each run must:

- Start and finish all eleven source waves in order, with every scheduled spawn
  consumed by the native wave system. Normal enemy behavior, including the
  existing offscreen-arrival timeout, is unchanged.
- Visit all 56 original route waypoints, complete both fire-escape climbs, and
  actually land on all fourteen roofs and all twelve crumbling slates.
- Activate that character's own special, jump normally, and finish with zero
  falls or fall-safe recoveries. The imported geometry must remain unchanged.
- Reach the source camera endpoint before the native exit timer starts, then
  clear after the actual 155 subsequent 60 Hz updates. This is the source
  2.6-second timer, including the update that starts it.
- Persist the earned 1-2 clear to disk and read it back, without acquiring
  unearned movement skills or creating a boss.

A run is bounded at 36,000 simulated updates per character. The final six-character
suite completed in 17 wall-clock seconds on Godot 4.6.3 in this environment,
comfortably inside the existing 120-second per-engine-call verification limit.
It also passed the focused `--jp-only` check.

| Character | Updates | Jumps | Special activations | Waves | Waypoints | Falls |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Jean Phil | 8,456 | 67 | 8 | 11/11 | 56/56 | 0 |
| Maya | 13,502 | 148 | 8 | 11/11 | 56/56 | 0 |
| Ama | 13,382 | 85 | 9 | 11/11 | 56/56 | 0 |
| Leo | 8,560 | 82 | 6 | 11/11 | 56/56 | 0 |
| Theo | 9,929 | 89 | 8 | 11/11 | 56/56 | 0 |
| Mei | 8,204 | 73 | 6 | 11/11 | 56/56 | 0 |

Every row also reached 14/14 roofs and 12/12 slates, and used the 155-update exit.

## Driver adjustments

The former Jean Phil-only driver could wait for coin rain to hit enemies that
ordinary level shots could not reach. That concealed routing limitations with
other housemates. The shared driver now uses normal controls to:

- Step down from a chimney before shooting a lower enemy, including when a fight
  has pulled the character back onto an already visited chimney.
- Jump around a chimney blocking the firing line and line up more closely for
  upward shots. A combat jump or active glider stays over its current safe roof.
- Retreat to lure an off-roof flyer over solid footing before approaching and
  aiming upward.
- Wait on a solid roof while a wave's camera lock leaves the next landing out of
  reach. It does not enter a crumbling-slate crossing during that wait.
- Leave slates early enough for their real 0.65-second collapse timer, and step
  down onto a lower roof instead of making an unnecessary long jump from a
  chimney into the following gap.

These are route-driver changes, not host bug fixes. No completion gate was
relaxed; disk persistence, wave order, roof/slate landings and immutable geometry
now have additional assertions.

## Reproduce

Run the complete verification from the repository root:

```sh
bash scripts/verify-native.sh
```

Or, after the generated content and resources exist, run only this suite with
isolated save/cache paths:

```sh
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export HOME="$work/home" XDG_CACHE_HOME="$work/cache"
export XDG_CONFIG_HOME="$work/config" XDG_DATA_HOME="$work/data"
mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"
timeout 120s godot --headless --path godot \
  --script res://tests/test_full_rooftop_run.gd
# For a focused run, append: -- --jp-only
```

This is automated solo progression coverage with invulnerability. It does not
establish difficulty balance, full visual/audio fidelity, human playability,
co-op behavior, phone performance or signed iPhone/Android build readiness.
