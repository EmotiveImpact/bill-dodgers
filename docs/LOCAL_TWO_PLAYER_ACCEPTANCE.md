# Native local-two-player acceptance

Updated 2026-11-09. Godot 4.6.3 headless, Jean Phil + Maya, local `p2`
mode. These are **automated synthetic key-event tests**, not two people playing,
physical keyboard rollover, Bluetooth controllers, phone multitouch, or device
release acceptance. No production code or existing tests were changed here.

## Passing evidence

- `test_local_two_player_engine.gd`: **168 checks** across all six world
  families. Independent opposing movement, jumps, aim and owned shots pass
  through `Input.parse_input_event`, physical-key polling and the real main
  physics callback. Focus-loss pause, held-input suppression, resize, fresh
  replay, downed-human camera framing, rescue timing, all-down/Continue and
  clear settlement are covered.
- `test_local_two_player_transitions.gd`: **45 checks** at W2–W6 scene
  midpoints. A pending wipe pauses, resumes on normal 60Hz frames, relocates
  both stable slots once, and retains independent P2 input afterward. W2/W4
  revive the downed actor. W3/W5 preserve down state. W6's checkpoint door
  raises hearts to two but preserves down state, matching original source.
- `tests/test_local_two_player_source_contract.py`: **4 tests** checking
  original executable keyboard, camera and rescue rules across six worlds,
  the two-human pressure-pad duration, and the event driver's single native
  frame call. These source checks are separate from runtime evidence.

### Complete key-event routes

`test_local_two_player_routes.gd` uses two independent read-only actor views
and two independent input decisions. It calls the production physics callback
once per simulated frame. It does not bind an actor facade to generate controls,
call CPU AI, or step the complete game once per player.

| Stage | Frames | Source waves | Observed shots P1/P2 | Earned pops P1/P2 | Additional outcome |
|---|---:|---:|---:|---:|---|
| 1-1 | 6,314 | 12/12 | 566/458 | 44/48 | Source 90HP party boss and real jar clear |
| 2-1 | 5,993 | 11/11 | 602/451 | 27/37 | All three receipts and both-player lift transition |
| 2-2 | 5,727 | 10/10 | 485/415 | 28/26 | All three receipts, scene transition and both players on all five pressure pads |

All three save the actual clear, retain source metadata and complete every
authored pair wave. No observed enemy remains undefeated. W1 includes boss
reinforcements beyond its 87 authored wave enemies; W2 observes exactly 64 and
54 authored enemies respectively. W1's optional receipts were not collected.

The final W1 pilots use different 220px/170px combat standoffs and produce 364
frames with distinct controls. W2 pilots independently follow the same route
and often converge; their distinct-control counts are 33 and 47. This is not
coverage of arbitrary human strategies or every housemate pairing.

## Assistance and boundaries

The full routes repeatedly set **both actors' invulnerability to 999 seconds**.
No skills are seeded, and there are no actor teleports, forced damage/kills,
wave edits, forced down/revive, objective writes or forced clears. Audio is
replaced with the existing silent test adapter. The logs print these assists.
All three routes recorded zero downs, revives/checkpoint rescues, clear rescues
and CPU catch-ups. This does not establish normal-health survival or difficulty.

The bounded fixtures deliberately set actor positions, camera and down/all-down
states, and invoke clear settlement. Transition fixtures also mark prerequisite
waves complete, spend W3's checkpoint, explicitly start W4/W5's authored wipe,
and finish W6's initial intro wipe. Their midpoint clocks then run normally.
They are **not** additional complete routes. W1 has no scene wipe in its tested
street route; menu/replay and clear transitions are covered separately.

### Initial pilot failure, not a production defect

The first 2-2 attempt borrowed the solo/CPU route pilot and stalled on pad 0
after 4,000 frames. Original source gives local humans a **2.6s** gate hold,
versus **5.2s** for solo/CPU. From x1900 to the pilot's x2580 crossing target,
travel at 270px/s takes 2.519s. Its old 0.35s safety reserve demanded 2.869s,
so it never issued a crossing input. A new test-only human pilot uses a 0.04s
reserve. The production gate timer and gameplay are unchanged; the complete
route then passes. The original failure is retained as
`validation/local-two-player/2-2-initial-pilot.{log,json}` and is reproducible
with `--level=2-2 --legacy-aisle-pilot --max-ticks=4000` (expected exit 1).

## Reproduction and source basis

Run from the repository with a fresh writable HOME/XDG directory per process:

```sh
work=$(mktemp -d)
HOME="$work" XDG_DATA_HOME="$work/data" XDG_CONFIG_HOME="$work/config" \
  XDG_CACHE_HOME="$work/cache" godot --headless --path godot \
  --script res://tests/test_local_two_player_engine.gd
# Repeat with a fresh directory for test_local_two_player_transitions.gd.
# Routes: test_local_two_player_routes.gd -- --level=1-1 (also2-1 and2-2).
# Omitting --level runs all three. --output=/absolute/path.json writes results.
python -m unittest discover -s tests -p test_local_two_player_source_contract.py
rm -rf "$work"
```

Evidence lives in `validation/local-two-player/`: the focused logs, per-stage
JSON/logs, source-contract result, Git HEAD and source SHA256 manifest. The
candidate has working-tree changes; HEAD alone is not a snapshot of this code.
The post-run checksum check found a subsequent change to `campaign_map.gd`;
the gameplay modules and these new tests still matched. The manifest is retained
unchanged. A final integrated gate must include the later map/UI edits.
Reject engine script errors or leaked objects even if Godot exits zero.
The existing aggregate launchers were intentionally not edited.

Original-source basis: `game/{1..6}-1/index.html` patched input wrapper,
`inputFor`, `updatePlayer` and `updatePlay`; W2 `sceneUpdate` and `lvUpdate`;
W3 `sceneJump`; W4 gate relocation; W5 `sceneChange` in `game/5-2/index.html`;
and W6 door transition. The native counterparts are `party_input.gd`,
`party_session.gd`, `party_runtime.gd` and each world's scene adapter.

No production defect was found in this bounded work. Physical simultaneous
input, normal difficulty, remaining local-P2 routes/identities, rendering,
audio and Android/iOS device acceptance remain open.
