# World 6 CPU party acceptance evidence

## Result and limits

**42/42 complete CPU-party routes passed** using all six leaders across all seven
World 6 stages. Each run uses the next distinct housemate as the source CPU mate.
The final matrix ran after the shared CPU stationary-diagonal aim and no-human-Dash
guards were repaired. The earlier seven-route smoke is not substituted for this matrix.

The leader is driven by ordinary movement, jump, aim, fire, duck and special
controls through production main.step. The mate uses production CompanionAI and
PartySession. The only gameplay assist is 999 seconds of invulnerability refreshed
for both actors each frame. Normal fall recovery can clear that protection.

The runner never edits actor positions, health, wave progress, enemy HP, timers,
pickups or clear state. Authored door warps, source CPU catch-up relocation and
source fall recovery are game mechanics and remain enabled. These results are
**not normal-difficulty, no-catch-up, complete-collectible, two-human full-route,
physical controller, multitouch, phone/export or deployment certification**.

## Final matrix totals

- 355,519 simulation frames at 1/60 second.
- 420 waves; all 1,698/1,698 authored base-plus-pair entries spawned.
- 82 physically collected receipts, with every native repaired door-void receipt collected and persisted in its applicable run.
- Every authored door, Franker/Jammer defeat, hold, climb Super card, cradle ending and coffee finish passed the stage checks.
- All six Sir Charge runs traversed all three phases, collected the real jar and saved the clear.
- The climb Super card was physically collected and shared to both actors in all six runs.
- 172 source CPU catch-up relocations. They are not credited as pathfinding.
- Leader/CPU down events: [0, 0]; down frames: [0, 0].
- Leader/CPU live revivals: [0, 0]; clear-time rescues: [0, 0].
- Observed leader/CPU heart reductions despite assistance: [0, 0]. This is a health-change measure, not a count of falls.
- Leader/CPU pop credits: [845, 1169]; personal coins: [8164, 2873].
- In every run the sum of personal coins exactly equalled shared kitty. W6 receipts do not fabricate coin rewards.

## Per-leader coverage

| Leader + CPU | Cleared | Frames | Catch-ups | CPU down events | Live revivals | Clear rescues |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| jp + maya | 7/7 | 61075 | 28 | 0 | 0 | 0 |
| maya + ama | 7/7 | 60577 | 28 | 0 | 0 | 0 |
| ama + leo | 7/7 | 58738 | 32 | 0 | 0 | 0 |
| leo + theo | 7/7 | 61463 | 23 | 0 | 0 | 0 |
| theo + mei | 7/7 | 57735 | 25 | 0 | 0 | 0 |
| mei + jp | 7/7 | 55931 | 36 | 0 | 0 | 0 |

## Supporting tests and reproducibility

- `test_billing_party.gd`: 163 passing scoped world/combat/boss/bridge checks.
- `test_billing_party_host.gd`: 81 passing real-main phase/lifecycle/input checks. Production start and step are inherited unchanged.
- `test_party_cpu_skills.gd`: 78 passing shared CPU Dash/aim guard checks (owned by the integration work).
- `test_billing_party_source_contract.py`: 2 passing tests compare eight executable blocks across all seven W6 pages.
- Retained solo WorldSix 124, BillingCombat 47 and SirCharge 37 focused checks pass.
- Full solo regression: 42/42 clears, 404,223 frames, 420 waves and 76 physical receipts with the existing invulnerability-only assist.

Run with an isolated writable HOME and XDG directories, as scripts/verify-native.sh does:

```sh
godot --headless --path godot --script res://tests/test_full_billing_party_runs.gd -- --all-characters --report=/tmp/billing_party_routes.json
```

Evidence: `docs/validation/billing_party_routes.json` and `.log`,
`billing_party_focused.log`, `billing_party_host.log`, and
`billing_solo_regression.log` in the same directory. Every route JSON entry stores
the hashes of the runtime source files loaded for this matrix. Full stage records
include owner pop/coin counts, CPU shot frames, catches, downs, live revivals and
clear-time rescues. The public mode-selection UI and hardware acceptance remain
separate integration work. See BILLING_PARTY_CONTRACT.md for scheduler/state ownership.

After the matrix, all six listed Godot focused suites were rerun successfully
against the latest tree. The three W6 adapter source hashes still match the
matrix. The integration owner confirmed intervening main.gd changes only concern
menu/fallback-campaign character selection; no gameplay phases changed.
