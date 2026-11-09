# Native campaign host integration

This adds an explicit **Play campaign** entry while retaining the development stage picker. The current campaign view is a native grid, not a recreation of the source painted/animated map. All six stage families are now integrated; this does not claim co-op or complete presentation/device parity. Native credits and the full main-stage ending route are covered separately in CREDITS_PARITY.md.

## Behavior

- Campaign decisions come from `campaign_progression.gd`, using the actual imported catalog and shared native capability registry. Only unlocked, implemented stages can start as campaign play, including through direct method calls.
- Normal clears retain the existing objective-only guard, save, receipt/skill history and exactly-once kitty accounting. The campaign view additionally validates prerequisite chains; earlier development clears are not deleted or silently granted a route.
- Bonuses follow the six actual map edges, with no invented receipt requirement. The Next level handoff focuses the first open uncleared main stage, not simply the numeric successor and not a bonus before an unfinished main stage.
- World 1's boss opens World 2. World 2's boss focuses the implemented 3-1 field and its source introduction. The verified main-stage chain now continues through Worlds 4–6 and the original final story/credits. Starting a native stage never grants an automatic clear. Unknown IDs still fail closed.
- Unseen first-stage introductions and boss scenes play before native gameplay. Clue scenes play after relevant clears and replay after later clears despite their seen flag. Skipping returns to the correct play/clear state; pausing or leaving a story cannot preserve a stale modal overlay.
- Pause, knockout and the in-game Map button retain campaign context. An explicit Stage previews button returns to the development picker. Direct `load_level` calls are development mode and do not silently adopt campaign rules or stories.
- Stale settlement/next callbacks cannot replace active gameplay. Earned skills, original receipt IDs and separate native disk saves remain unchanged.

## Verification and limits

`test_campaign_integration.gd` currently passes 52 real-main GUI/save fixtures in an isolated HOME/XDG directory. It dispatches actual touch-to-mouse GUI events, tests fresh/locked/bonus/next-world/preview routes, introduction pause and exit, repeated clues, boss stories, knockout-to-map, disk saves and stale clear callbacks. Independent review found a queued double-entry bug; the host now rejects active-run re-entry and stops old story playback before intentional replacement. Two real queued mouse and touch presses were independently rechecked. Review also found the story Control swallowing visible pause buttons; pausing now hides that overlay, and resume restores it. Actual dispatched touch tests cover Resume and focus-out to Back to worlds. It explicitly seeds progress or calls completion in focused fixtures; those are not full gameplay proofs. Independent per-stage input-driven tests remain the objective evidence.

The existing native smoke suite also passes after this integration. Campaign rule tests are separate (859 checks). Aggregate/packed revalidation and independent host review are required before including this work in a checkpoint.

Presentation timing is currently adapted: native stories open immediately rather than using source 250 ms entry and 2600 ms post-clear delays. Native buttons provide the route instead of the source keyboard 1900 ms continue gate. The pure rule module records those exact source timings for later presentation integration; this host does not claim to implement them. The final 6-6 ending/credits path is not reachable until its actual gameplay is ported and verified.

The campaign-only checkpoint passed eight Python tests, 50 Godot suites, 99 asset-free packed-runtime checks and 140 prebuilt-audio checks. With 3-1 gameplay integrated, the clean checkpoint passes 56 Godot suites, 109 packed-runtime checks and the same importer/audio suites. No device or framebuffer validation is claimed.
