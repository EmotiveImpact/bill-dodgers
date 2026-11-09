# Native story playback

## Content provenance

`node scripts/extract-story.mjs` generates `godot/content/story.json` from the
checked-in `game/cutscenes/cs.js`. `--check` verifies the generated file exactly.
The export contains all six worlds, 21 scene definitions (including title variants),
and 193 shots, without rewriting dialogue, coordinates, timing, or metadata.
`source_sha256` hashes the complete source; `definition_sha256` hashes the evaluated
prefix. The crisp/IOU helper objects are evaluated, so their expanded data is retained.

The boundary is the unique `/* Bill Dodgers cutscene player.` marker after the
scene IIFE closes. No DOM runtime is evaluated. Node creates a new realm with a
realm-local empty `window`, no host objects, require, filesystem, network, or timers,
a one-second timeout, and disabled string/WASM code generation. This is exclusively
for trusted repository code; Node vm is not a security sandbox for arbitrary input.

## API and integration

Add `StoryPlayer` (`src/story_player.gd`) as a child of a screen-space overlay at
960×540 logical resolution, after its `_ready` runs. `play(scene_id) -> bool` accepts
any exported scene; invalid names return false. `playing` exposes active state.
`finished(scene_id, skipped)` fires exactly once per session. `stop()` and `skip()`
finish with skipped=true. `set_paused(bool)` freezes both timing and advancement.
The parent owns pausing/resuming gameplay and marking scenes seen in the save.
Replacing an active story emits its skipped result before starting the new story.

Tap Next, or press Enter/Space/Right, to advance dialogue. Escape or Skip story exits.
Silent beats advance after their original hold (default 1800 ms), and can also be
advanced manually. Text is immediately complete, without requiring fast reading.
All of `1-intro`, `1-clue`, and `1-boss` are selectable through `play` and contain
full original dialogue and inserts. The source 1-1 page automatically plays only
1-intro and offers it again through Story; it does not bind the other two scenes
to 1-1 completion. Integrating those automatically would change the original flow.

## Implemented presentation

- Original local background paintings, sprite sheets and props from assets/cutscenes.
- Original camera crop/aspect and eased pans; actor motion, delays, arrival states,
  sprite animations, held frames, one-shot animation, facing, depth ordering,
  opacity/fade-in, appear/hide, hop/bob, carried props and prop rotation/spin.
- Keep, drop and set inheritance resolves before playback; arrival positions and
  animations carry into the next shot, along with camera endpoints.
- Freeze-frame timing and tint, captions, speaker names, dialogue and title cards.
- Original World 1 bin silhouette geometry adapted to Godot primitives, animated lid.
- All textual receipt, phone, tag and card inserts in a high-contrast native panel.

## Deliberate presentation gaps

This is a native readable story player, not pixel-identical browser playback.
It does not yet reproduce synthesized music/blips/stings, typewriter text, comic
wipes, particles/crumbs/bills/confetti, portrait moods, shadow/glow/rim/eye effects,
silhouette recoloring, spotlight/vignette/lightning, speed lines, final fade-out,
prop wobble or carried-prop flap/mirror. Insert illustrations/signatures, decorative
paper/phone layouts and scrolling receipts are replaced by complete static text.
Bin details are simplified; non-bin procedural boss shapes in later worlds are
not drawn yet. All unsupported fields remain intact in the export. Later worlds
are content-preserved and API-selectable, but not claimed visually complete.
Fixed landscape coordinates rely on the parent viewport scaling/letterboxing;
there is not yet a separate portrait story layout or auto-dialogue mode.

## Verification

- `python3 -m unittest tests/test_story_extract.py`: exact regeneration, hashes,
  world/scene/shot counts, unicode content, background assets and runtime boundary.
- `HOME=/tmp/bd-story-home XDG_DATA_HOME=/tmp/bd-story-home XDG_CACHE_HOME=/tmp/bd-story-home godot --headless --path godot --script res://tests/test_story.gd`:
  all World 1 shots, lifecycle/finished signals, pause, skip, carry/drop/set and
  frame traversal. Passed on Godot 4.6.3.
- Headless tests establish execution/data correctness, not final on-device visual
  parity. A touch-device visual pass remains necessary.
