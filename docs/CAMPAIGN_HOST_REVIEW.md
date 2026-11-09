# Campaign host review

Reviewed on 2026-11-09 against the native campaign integration and its follow-up
entry/pause fixes. This is a focused host-flow review, not approval of a finished
map, all six worlds, difficulty, or mobile device behavior.

## Result

Two reproducible lifecycle bugs were found and fixed by the host owner during
review. Both fixes were independently retested through actual dispatched mouse
and touchscreen events. No remaining progression or coin-banking blocker was
found in the currently supported World 1 / World 2 campaign flow.

### Fixed: duplicate stage entry while an introduction is playing

The host connects menu buttons with deferred callbacks. Two complete click
sequences on the campaign's fresh `1-1` button before the next process frame
could therefore queue two starts. Originally the second start reloaded gameplay
without stopping the introduction. The observed state was `mode == "play"`,
`story.playing == true`, hidden game UI, and unpaused game audio. A repeated
direct `start_campaign_level("1-1")` call produced the same inconsistency.

`start_campaign_level` now rejects entry outside menu/clear mode and while a
story is playing. Intentional `load_level` replacement validates its target
first, then stops the previous story before resetting the run. Retests with two
queued mouse clicks and two queued touchscreen taps both preserve story mode,
hidden game UI, paused audio and a frozen gameplay clock. Invalid replacement
also leaves an interrupted introduction intact.

### Fixed: pause controls blocked by the story's input panel

Reproduction: start the fresh campaign introduction, simulate application focus
loss, then tap the visible Resume or Back to worlds button. Both mouse and touch
originally remained in pause mode. Increasing the game UI's drawing `z_index`
did not change input ordering: the story's later, full-screen Control still
intercepted those events.

The host now hides the active StoryPlayer while paused and restores it only when
resuming a still-playing story. Actual mouse and touch Resume taps now resume
the story. Pausing again and tapping Back to worlds stops it and returns to the
campaign menu with no active campaign run or stale elevated UI. A tap at the
hidden story-skip position cannot dismiss the paused story. Post-clear story
pause/resume also returns to clear mode rather than live gameplay.

## Source semantics and presentation choices

- Main and bonus unlocks, the first-open-uncleared-main handoff, and world
  transitions agree with the normal source journey. Source references:
  `game/index.html:105-113`, `:234`, and `:478-480`. Receipt counts are not gates.
  The stricter validation of development/forged clear history is deliberate and
  documented in `CAMPAIGN_PROGRESSION.md`, not described as exact source save
  behavior.
- The before/after story hooks match the current supported stages: unseen
  introductions and boss scenes on entry, clue scenes on every clear. See
  `game/1-3/index.html:1841-1854` and `game/2-6/index.html:2238-2251`. Marking seen
  at playback start, including a subsequently skipped scene, matches the source.
- The native host starts scenes immediately rather than after the source's
  250 ms entry or 2600 ms post-clear delays. This changes presentation timing,
  but the review found no content loss or invalid progress caused by that
  choice. The whole scene is available, gameplay is frozen, post-clear playback
  returns to the existing clear UI, and no delayed callback can fire after
  navigation. Banking already occurs once on the objective clear, as in the
  source. Reintroducing timers is not necessary to fix the two lifecycle bugs.
- Source keyboard continuation is still missing from the host. The source
  accepts Enter/Space after 1900 ms to settle, then uses the next press to return
  to `#map&next`; the native clear UI currently relies on its buttons. See
  `game/1-3/index.html:1209-1213` and `:1810-1835`. This is a keyboard-flow gap,
  not a touchscreen progression blocker. The smallest faithful addition is an
  explicit clear clock and settled state, guarded Enter/Space handling using
  `Campaign.can_continue`, and input consumption before GUI focus can activate
  Play again. Retest keys during/after stories and repeated key events.
- The native grid and target arrow are a functional map handoff, not the
  original painted map, walking/path-reveal presentation, or full menu parity.
  The separate development story library remains a preview feature.

## Completion and capability boundary

`main.gd::_complete_level` accepts only play mode and a registered native stage.
It changes mode before banking and clears loose coins once. Repeated clear,
settlement and next callbacks did not duplicate the bank. Calls during an active
clue could neither settle nor navigate past the story. Returning from that clue
preserved clear mode and the same banked total.

The host still relies on its actual objective controllers for a genuine clear;
calling the private completion helper in a test is not evidence of completing a
level. Code inspection confirmed the wave/timed-exit checks, separate bus exit,
boss events, and checkout's actual jar-collection path. This review did not rerun
the full input-driven stage suites.

The real support registry remains Worlds 1 and 2 only. Completing World 2 routes
to a visible, disabled `3-1` boundary instead of opening a preview, skipping to a
bonus, or granting a clear. Preview completion remains rejected. Pure rules
tests that inject all 42 IDs exercise hypothetical future capability only.

When later capabilities are actually enabled, the host will need the associated
story/credits behavior. In particular, it currently maps a `credits` route back
to the campaign menu and uses only the last scene from a per-level replay list.
Neither is reachable as a current native campaign ending: `6-6` remains
unsupported. These are future capability gates, not evidence that the current
World 2 boundary is broken.

## Verification

All checks used Godot 4.6.3 with disposable writable HOME and XDG cache, config,
and data directories. No personal save was read or changed.

- Campaign host integration: **45 checks, 0 failures**.
- Campaign progression: **859 checks passed**.
- Story tests: **passed**.
- Native smoke tests: **passed**.
- Independent external host probe: **20 checks passed**; a second overlapping
  20-check variant also passed. These added real same-frame duplicate mouse and
  touch input, actual paused-story Resume/Map input, focus loss, clue interruption,
  repeated accounting/navigation, and invalid/valid story replacement.

The focused tests use explicit completion/save fixtures where stated. They do
not establish human playability, all-character full-run completion, renderer
fidelity, touchscreen hardware behavior, or signed iPhone/Android builds. The
aggregate suite and full stage progression were left to the separate isolated
verification run. This reviewer made no shared runtime/test edits and did not
stage, commit, push, or deploy.
