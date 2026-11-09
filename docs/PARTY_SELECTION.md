# Native official character selection

## Player flow

The native selector now ports the original full-screen stage selection from
`game/1-1/index.html` (the final `drawSelect`, `pickCard`, `updateSelect` and
`cycleMode` definitions), rather than the former head-portrait modal.

The first genuine map **Play** opens the selector when the save has no explicit
confirmed choice. **Start** confirms the party and starts the already-selected
level. Later stages and app restarts retain that choice without another title or
selector. The map's **Change character** button deliberately reopens selection;
its Start confirms changes and returns to the same map card. There is no
in-game character picker. Gameplay **Menu → Level map** returns to the map.

The screen preserves the original six colored arched doorways, full-body source
actors, idle/win animation frames and timing, name strips, gold P1 and pink
CPU/P2 markers, mode pill and Start button. Its staged flow is P1, mate, Start.
The mode pill cycles **Mate: computer → Mate: player 2 (keys) → No mate, solo**.
Left/Right or A/D move the cursor, Enter/Space choose or start, F changes mode,
and Backspace/Escape step back. Back and Cancel also have native touch buttons.

Two players means two local players on one keyboard, not online multiplayer or
a second set of phone touch controls. P1 uses arrows, Z jump, Space/X/K shoot,
C special and Shift/Q dash. P2 uses A/D, W aim, S duck, G jump, F/E shoot,
R special and T dash. P1 touch controls do not drive P2.

## Intentional native adaptations

- Selection is attached to the campaign map, not reinserted before every stage.
- The original 1-1 street backdrop is used consistently, rather than loading a
  prospective gameplay stage solely to paint the selector background.
- Extra Back and Cancel touch buttons provide safe map navigation.
- All edits remain a draft until Start. Cancel, or backing out of the first
  step, restores the map without changing saved identities, mode or progress.
- Choosing the other slot's housemate swaps identities, preserving the native
  distinct-cast policy. Source stage selection instead clears/reasks that slot.
- Solo deactivates the mate while preserving a remembered valid partner.

These deliberate changes mean this is a source-based native port, not a claim
of pixel-identical browser rendering or identical save/navigation behavior.

## Persistence and safety

`friend`, `party_mode`, `party_mate` and `party_confirmed` are written atomically
with the native save. Only a successful official-screen confirmation sets
`party_confirmed` to true. Only JSON booleans are accepted for that marker;
missing and malformed markers are false. Old or absent choices therefore get
one explicit confirmation on their next map Play. Fresh selection defaults to
CPU partner, matching the source. Main's direct campaign-start API remains
available without this map-owned gate for existing test and internal routes.

Only `solo`, `cpu` and `p2` are accepted as saved modes; paired modes require
valid distinct cast IDs. Mode type checking rejects booleans, numbers, arrays
and objects without a script error. Startup restores the chosen party before
stage entry. Confirmed **New story** resets progress but retains identities,
mode and the explicit confirmation marker.

Selection cannot grant or change clears, receipts, skills, story-seen state,
Kitty, locks or credits eligibility. A failed save leaves the previous host
party unchanged. Native saves remain separate from browser saves.

The separate development/free-play picker follows the same duplicate-slot swap
policy. Its hook rejects gameplay-time requests and invalid cast IDs.

## Layout and assets

At the 960×540 logical viewport, the six doorways preserve the source positions
and 138×290 geometry. Mode and Start preserve their 300×44 geometry. All
interactive map and selector targets are at least 44×44 logical pixels and fit
the safe bounds. The map's stage rows are 44 high with 46-pixel spacing, including
the seventh bonus row and Close. World and stage rows do not overlap.

The actors use original full sprite frames and anchors, not cropped head
portraits. Selected actors use win frames at 160 ms; others use idle frames at
200 ms. Logical geometry and cloud-desktop rendering do not certify physical
phone touch size, device safe insets, rotation or performance.

## Verified on Godot 4.6.3, 2026-11-09

- `test_party_selection.gd`: **566 checks, zero failures**. Real
  `Input.parse_input_event` touch/key events through production controls;
  first-Play gate and selected-level continuation; transactional drafts and
  cancellation; staged choices and both swap directions; CPU/P2/Solo;
  source doorway/full-frame animation geometry; focus suspension; real chosen
  actors in 1-1 and 1-2; independent P2 polling; Menu → Level map and Next level
  retention; startup restoration; New story; all 42 stage-button bounds and
  actual bonus-row taps in all six world panels; free-play swap and guards.
- Separate fresh processes reading exact GUI-generated saves: P2 **11**, CPU
  **10**, Solo **9** checks, all passing. Each enters a real stage through the
  map without reselection and verifies the restored mode and actors.
- `test_save_presentation.gd`: **187 checks, zero failures**, including all
  108 mode/cast-pair combinations, invalid and duplicate values, legacy saves,
  strict confirmation-marker validation, and progression separation.
- `test_campaign_map.gd`: **26**, and `test_campaign_map_integration.gd`:
  **47** checks, all passing with enlarged targets and the official selector.
- `test_campaign_integration.gd`: **53**, and `test_campaign_completion.gd`:
  **308** checks, all passing. The former explicitly confirms Solo through the
  visible screen on first Play and recursively finds the paused menu controls.
  The latter retains its synthetic accounting/progression assertions.

The Next-level test uses an explicit synthetic clear only to reach settlement.
The six-world panel test uses a completed presentation fixture. Those tests do
not establish full gameplay routes, balance or human difficulty. World-specific
party gameplay acceptance is documented separately.

The selector suite restores previous save bytes exactly. Always use isolated
HOME/XDG directories so interruption cannot affect personal saves or concurrent
suites. `scripts/verify-party.sh` isolates every process except the selector and
its three restart probes, which intentionally share their generated snapshots.

```sh
work=$(mktemp -d)
export HOME="$work/home" XDG_DATA_HOME="$work/data"
export XDG_CONFIG_HOME="$work/config" XDG_CACHE_HOME="$work/cache"
mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
godot --headless --path godot --script res://tests/test_save_presentation.gd
godot --headless --path godot --script res://tests/test_party_selection.gd
for mode in p2 cpu solo; do
  godot --headless --path godot --script res://tests/test_party_selection.gd -- --restart-check "$mode"
done
```

## Genuine native visual capture

`godot/tools/capture_party_selection.gd` refuses headless capture. The bounded
cloud Linux desktop OpenGL run on 2026-11-09 produced five 1280×720 images:

- `native-official-character-p1.png`, 15:11:42 UTC.
- `native-official-character-mate.png`, 15:11:43 UTC.
- `native-official-character-cpu-ready.png`, 15:11:43 UTC.
- `native-official-character-local-p2.png`, 15:11:44 UTC.
- `native-official-map-return.png`, 15:11:44 UTC.

Artifacts are under the workspace's `native-artifacts/screenshots/party/`.
These are actual Godot renderer captures, not original-browser screenshots or
mockups. The source actors, colored doors, labels, markers and controls were
visually inspected. The desktop driver warns only that VSync mode cannot be
changed; capture completes without script errors. The older `native-party-*`
images depict the superseded portrait modal and must not illustrate this screen.

This is not an iPhone/Android install, physical-device acceptance, online-play
claim or store-ready release certification.
