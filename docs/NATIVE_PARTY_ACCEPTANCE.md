# Native party integration: acceptance record

Updated 2026-11-09. This is implementation and automated progression evidence,
not a finished phone release or normal-difficulty certification.

## Implemented

All 42 stages have actual independent actors, source CPU decisions, per-actor
movement/abilities/rewards, down/revive/Continue behavior, party-scaled waves and
bosses, shared camera/objectives and one shared world frame. The implementation
does not step the entire game twice. The official map selector exposes Solo,
CPU partner and local-keyboard two-player choices, with persistent distinct cast
identities and deliberate map-only character changes.

Each world has passing full-route evidence across all seven stages and all six
CPU identities, using the documented fixed or next-housemate leader pairings.
That is 252 stage/CPU cases, **not every possible leader/mate combination**.
Most route drivers repeatedly apply invulnerability to both actors and may seed
previously earned skills; each world's report states the exact assistance.
Source catch-ups, fall damage, downs and clear/checkpoint rescues remain enabled.

## Evidence by world

The detailed machine-generated logs/reports named below are retained locally,
not published in this repository. The source tests, acceptance summaries and
reproducible launchers are tracked. See [validation](VALIDATION.md).

| World | CPU route evidence | Important boundary |
|---|---|---|
| 1 | 42 cases: `validation/world_one_party_*_cycle.log`, plus `PARTY_WORLD_ONE_ACCEPTANCE.md` | All rooftop CPU mates go down and are rescued by clear. Bus CPU obstacle contacts remain source behavior. |
| 2 | 42 cases: `validation/world_two_party_routes.json`, `WORLD_TWO_PARTY_SCENES.md` | Real pressure-pad and checkout crate/puzzle helper interactions are covered. One human pilot adjustment retained source AI. |
| 3 | 42 cases: `validation/festival_party_routes.log`, `FESTIVAL_PARTY_COMBAT.md` | Five Queue CPU mates go down. Original-JavaScript recovery fixtures confirm the inherited behavior. |
| 4 | 42 cases: `verification/holiday_party_cpu_acceptance.json`, `HOLIDAY_PARTY_ROUTES.md` | 24 CPU downings, 15 checkpoint and nine clear rescues. Evidence preserves the initial human-driver stall and successful final Captain reruns. |
| 5 | 42 cases: `verification/moving_day_party_cpu_acceptance.json`, `MOVING_DAY_PARTY_CONTRACT.md` | 67 source catch-ups, one CPU fall, zero downed frames under assistance. The corrected CPU Dash/aim guards were active. |
| 6 | 42 cases: `validation/billing_party_routes.json`, `BILLING_PARTY_ACCEPTANCE.md` | 172 catch-ups, zero downs under assistance. 82 physical receipts, not every optional receipt. |

W5 also has seven full scripted-local-P2 routes. Other local-P2 behavior is
covered by bounded actual-main/input fixtures. Synthetic controls are not a
physical keyboard, Bluetooth controller, online multiplayer or two-phone test.

## Reproducible checks

`scripts/verify-party.sh` runs focused actor/AI/input/bridge/world, menu, HUD,
selector and save tests. Three explicit selector restart probes share only that
suite's isolated data directory; every unrelated suite has its own save state.
`--full` adds serialized route tests; `--routes-only --world=1..6` selects one
world. Logs and loaded-source hashes are retained in its printed results folder.
The launcher rejects script errors and leaked objects even when Godot exits zero.

The original 252-route solo checkpoint remains separately recoverable at
`7c5593374ac4de75e870ceff9b89b435083675f2`; its complete frozen gate must not be
presented as having tested later UI/party edits. Current integrated focused and
full-gate results are recorded separately as they finish.

## Remaining release acceptance

- Human normal-health difficulty and survival, including CPU behavior on narrow
  routes and every leader/mate pairing where material.
- Two-human physical input, controller assignment and actual phone multitouch.
- Android/iOS exports, signing, device rendering/audio/performance/battery tests.
- Remaining presentation comparisons, final approved music, asset/font notices.
- Commune membership/access model, web export and arcade/app integration.

No store submission, public deployment or remote push is implied by these tests.
