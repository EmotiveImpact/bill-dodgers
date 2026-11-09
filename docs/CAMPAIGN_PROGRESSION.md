# Native campaign decisions

`godot/src/campaign_progression.gd` is a pure, deterministic campaign rules module.
It reads no files, changes no scene, starts no timer, banks no coins, awards no
skills and mutates none of its arguments. The native UI/runtime supplies its
save, imported catalog and actual supported-stage registry. The module does not
make the remaining worlds playable.

## Verified source rules

Sources are the original `game/index.html` and the `bd-flow`, `bd-clear`, and
story wrappers in each `game/<id>/index.html`. The independent regression reads
the actual `MAP4` JSON and each stage's story hook, rather than trusting a copy
of this document. Embedded base64 image lines are never printed.

- `game/index.html:81` contains `MAP4.order` and `MAP4.edges`. Main stages run
  1-1 through 1-6, then 2-1 through 2-6, continuing through 6-6. Each world's
  bonus appears after its boss in **map order**, but that is not the normal
  next-stage order.
- Main stage 1-1 has no prerequisite. A main stage after the first needs its
  preceding main cleared. Each world's boss opens the bridge and the next
  world's first main stage. World completion means the boss was cleared; it
  does not require its optional bonus.
- Bonus requirements, directly from the authored branch edges:

  | Bonus | Required clear | Required receipts |
  | --- | --- | --- |
  | 1-S | 1-1 | 0 |
  | 2-S | 2-1 | 0 |
  | 3-S | 3-3 | 0 |
  | 4-S | 4-2 | 0 |
  | 5-S | 5-3 | 0 |
  | 6-S | 6-1 | 0 |

  **There is no receipt unlock requirement in this source map.** Receipts are
  collectibles, not keys, purchases, membership entitlements or boss gates.
  Source receipts use 1..3; existing native saves use 0..2. This module takes
  the native format only and does not migrate or read browser storage.
- `game/index.html:234` chooses the first open uncleared stop in map order for
  its glow (`nextUp`). `:478-480` handles `#map&next` differently: find the first
  open uncleared **main stage**, excluding bonuses, then fall back to `nextUp`
  only if no main remains. Replaying an old stage therefore does not imply
  going to its numerical successor. A still-open 1-S never diverts the normal
  journey from 1-6 to 2-1.
- `game/2-6/index.html:2207-2232` is the full-game completion-flow wrapper.
  Every stage except 6-6 goes to `../index.html#map&next`. Stage 6-6 goes to
  `../index.html#credits`, labelled "The end", even if bonuses remain.
  Source keyboard continuation needs `stateT >= 1900`, settled card phase
  `>= 1`, and no active cutscene. `can_continue` represents these conditions in
  seconds, with an inclusive 1.9-second threshold.
- The per-stage `bd-clear` listener records the clear, adds the run's kitty,
  and updates the last map location. Coin banking and runtime objective
  verification remain outside this pure module. A clear flag does not mean
  the settlement animation has finished.

## Story decisions

The hooks are identical across all six worlds:

| Trigger | Scene | Source repeat policy |
| --- | --- | --- |
| Enter x-1 | x-intro | Only automatically if unseen |
| Enter x-6 | x-boss | Only automatically if unseen |
| Clear x-3 | x-clue | Every clear, including replays |
| Clear 6-6 | 6-ending | Every clear, including replays |
| Finish 6-6 | Credits | After gameplay/story/settlement navigation |

Bonus stages have no automatic story hook. Before-scenes start after 250ms;
post-clear scenes start after 2600ms in the source. Constants
`BEFORE_STORY_DELAY`, `AFTER_CLEAR_STORY_DELAY`, and `CONTINUE_DELAY` expose these
source times in seconds. The caller owns scheduling and cancellation on leaving
or restarting a stage, must stop timers while paused, and must not navigate
through an active story.

Source wrappers mark scenes seen when playback starts, including subsequently
skipped scenes. `record_scene_started` returns that save change. The per-level
Story button offers its before-scene even if unseen, followed by its after-scene
only if seen. The title's story library orders each world's intro, clue, boss,
and finally 6-ending, filtering seen scenes; an empty library falls back to
1-intro. Title attract loops and credits are not story scene IDs. A new-story
intro can be played before showing the campaign map, as in `startStory()` at
`game/index.html:722`; marking it seen prevents duplicate playback on 1-1.

The module returns scene IDs that exist in imported `content/story.json`.
It does not render cutscenes or credits, wait for animations, or assume a missing
scene played successfully. Source story wrappers are at 2-6 lines 2238-2251,
1-3 lines 1841-1854, and 6-6 lines 2619-2632.

## Native hardening, deliberately not source-map behavior

The browser map's `edgeOpen`/`isOpen` (`game/index.html:110-113`) trusts truthy
`save.cleared` values on **any adjacent edge**, with no verified predecessor
chain. It also exposes `save.preview`, free play and "Mark as cleared"
(`:422-426`, `:465-466`, `:691-695`). Those are development/free-play controls,
not proof of normal campaign completion. They are not reproduced as campaign
bypasses.

Native campaign validation is stricter:

1. Only actual boolean `true` clear values count. Numeric/string truthiness,
   unknown stage IDs, gate IDs and preview/free-play flags grant no progress.
   A present schema must be finite numeric 1 (JSON's 1.0 is accepted).
2. `native_cleared` keeps supported native clear records, including legitimate
   out-of-order clears made through the development stage picker.
   `verified_cleared` is a separate derived set: each clear needs a real catalog
   entry, actual native support and its predecessor already verified. Bonuses
   use their branch prerequisite, not all main stages in the world.
3. Old development clears **are not deleted** or silently rewritten. Snapshot
   is read-only. `record_clear` deep-copies the input and adds its one accepted
   clear without pruning history. Out-of-order native clears can contribute to
   campaign progress once their prerequisite chain is legitimately present.
4. Catalog order, kind labels, save `last`, receipt counts and cached map
   rendering fields cannot rewrite the canonical source graph. Missing,
   conflicting-world or duplicate catalog entries fail closed. The trusted
   runtime support list is supplied by code, not taken from player save data.
5. An unlocked stage can still be unported. After a complete supported World 2,
   the next destination is **blocked 3-1**, not 1-S, 2-S, credits or a different
   supported stage. This preserves the source next-main decision while honestly
   exposing the native implementation boundary. Unsupported clears cannot open
   later worlds or unlock credits.
6. `record_clear` requires explicit `legitimate_clear=true` and
   `campaign_run=true`, native support and normal unlock eligibility. Its
   defaults grant nothing. Runtime objective code is responsible for the first
   assertion; this module cannot independently verify combat or physics.
   Importing source geometry or reaching an unfinished preview's right edge
   is never sufficient evidence.
7. Normal campaign story eligibility follows validated stage entry/completion.
   Forged future `seen` flags cannot unlock later campaign library entries.
   A separate explicit development story library may still preview all imported
   scenes; it must not be confused with this campaign library.

This is defensive local validation, **not cryptographic anti-cheat or a
membership/paywall system**. A wholly forged, consistent boolean prefix for
supported levels is indistinguishable from real progress in a local JSON save.
The original web game, source files, browser save and deployment are unchanged.

## API and integration

All APIs are static. `supported_ids` accepts an Array/PackedStringArray of exact
stage IDs or a Dictionary whose supported entries are boolean `true`. Snapshot
and story-library helpers default to `NativeLevels.SUPPORTED`. Other helpers
require the explicit registry to make boundary choices visible at call sites.

- `snapshot(save, catalog, supported_ids=NativeLevels.SUPPORTED)` returns:
  - `levels[id]`: `id`, `world`, `title`, `label`, `bonus`, `requires`,
    `receipts_required` (always 0), cleaned `receipts`, `available`, `supported`,
    `unlocked`, `playable`, `native_cleared`, `cleared`, `status`, `reason`, and
    `play_label`. `cleared` means verified campaign clear, not just stored clear.
  - `unlocked` and `playable` ordered arrays; distinct `native_cleared` and
    `verified_cleared` dictionaries; cleaned receipts and `receipt_count`.
  - Six ordered `worlds` entries with world number, name, label, unlocked,
    completed, main_cleared, main_total, and bonus_cleared.
  - `story_complete`, `credits_unlocked`, `menu_label`, `schema_valid`, and
    `next_route` (the map's next decision without a completion origin).
- `level_state(save, catalog, supported_ids, level_id)` returns the matching
  level dictionary, or `{}` for an unknown stage.
- `next_route(save, catalog, supported_ids, from_level="")` returns `kind`
  (`level`, `blocked`, `credits`, or `map`), `level_id`, `label`, `reason`,
  `world_completed` and `next_world`. Supplying an unverified completion origin
  returns `map`/`unverified_origin`. Supply 6-6 only on its verified completion
  path; a normal map visit after story completion still offers unfinished bonuses.
- `record_clear(save, catalog, supported_ids, level_id,
  legitimate_clear=false, campaign_run=false)` returns `accepted`, `reason`, a
  deep-copied `save`, `newly_cleared`, `after_scenes` and `route`. Replays are
  accepted but `newly_cleared=false`; that is not a coin-banking decision.
- `story_before_level(...)`, `story_after_clear(...)`, and
  `story_replay_for_level(...)` take the four level-state arguments above and
  return ordered scene-ID arrays. Call after-clear only on an actual current
  completion event, not whenever a previously cleared level is loaded.
- `story_library(save, catalog, supported_ids=NativeLevels.SUPPORTED)` returns
  the canonical seen scene list, or the source 1-intro fallback.
- `record_scene_started(save, catalog, supported_ids, scene_id)` returns
  `accepted` and a copied `save`, marking only an eligible campaign scene.
- `can_continue(clear_elapsed_seconds, settled, story_playing)` represents
  the source keyboard transition guard. The caller must also enforce current
  clear mode, pending after-clear story ordering and single navigation.

Recommended UI separation: keep the existing explicitly labelled **development
stage picker** independent. A normal Campaign view uses `playable`, not merely
`unlocked`, for launching stages, and keeps a per-run campaign/development
mode. Only actual objective completion enters clear mode. Apply progression
once, bank a run once in the runtime, play any post-clear scene, settle, and
follow the returned route. `blocked` returns to a clear native-boundary message
without auto-starting a layout preview. Credits need their own UI renderer.
Map geometry, islands, camera moves, walker animation, path reveals and banners
are presentation work, not functionality claimed by this module.

## Verification

Run with disposable Godot user/config/cache directories, so no personal save is
read or written:

```sh
work="$(mktemp -d)"
mkdir -p "$work/home" "$work/cache" "$work/config" "$work/data"
HOME="$work/home" XDG_CACHE_HOME="$work/cache" \
XDG_CONFIG_HOME="$work/config" XDG_DATA_HOME="$work/data" \
godot --headless --path godot --script res://tests/test_campaign_progression.gd
```

The tests independently compare all 42 canonical IDs, all branch requirements,
all 42 completion routing hooks and all 19 campaign story hooks with the source.
They cover a fresh save; every main-stage prefix; every world's bonus boundary;
all world transitions; zero/all/malformed receipts; final boss versus bonus
fallback; all stages complete; replay; support holes; blocked World 3; orphan and
forged clears; bad schema/types/catalog entries; scene start/seen/repeat policy;
1.9-second timing boundaries; and argument/save immutability. Full six-world
rules tests explicitly inject all 42 supported IDs as **hypothetical future
capability**, not a claim those stages are implemented. Current capability
checks use the real `NativeLevels.SUPPORTED` registry.

Tests do not prove an input-driven run, map visuals, rendering, device behavior,
credits layout, coin settlement, disk save durability or the completeness of
later-world gameplay. Those require the corresponding runtime/integration tests.
