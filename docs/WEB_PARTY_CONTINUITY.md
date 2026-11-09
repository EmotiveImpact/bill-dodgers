# Original web game: party continuity

Implemented locally on 2026-11-09. No push, deployment or access-policy change.
This repairs the original Canvas game, not the separate Godot port.

## Behavior

- The map now has **Change character** in the top bar and level card. Its chooser
  sets the actual P1, distinct CPU/local P2 mate, and solo/CPU/P2 mode, rather than
  changing only the map walker. Changes apply with Done/Play; Cancel, Escape and
  clicking the backdrop discard the draft.
- The first map Play opens the chooser if no party has been confirmed. Later
  stages, reloads and Play again use the saved party without another stage title
  or selection screen. The existing main title/menu remains the session entry.
- A first-time direct stage URL still offers its initial title/selection, seeded
  from the legacy walker and mode. Starting that stage persists the party.
- Character changing is available before play/on the map, not during gameplay.
  Play again directly restarts with the current party.
- Stage startup waits for assets, fonts and any opening story. Story playback
  also suspends stage simulation/input instead of running gameplay behind it.
  Existing clear/settle/Next level/map/credits routes remain intact.
- Browsers can keep Web Audio suspended after automatic navigation. The next
  actual gameplay key or pointer gesture resumes it without reopening a menu.

## Storage and scope

`game/party.js` owns a version-1 `bd-party` record with `p1`, `p2`, and `mode`.
It validates all six characters and modes, removes the mate in solo, and repairs
invalid or duplicate mates. It mirrors P1 into the existing `bd-save.friend` and
mode into `bd-mode`, merging rather than replacing the campaign save. Cleared
levels, coins, seen stories, receipts and skills keep their existing identities.
Legacy saves without `bd-party` remain valid and become chooser defaults.

A session-storage copy handles unavailable or unwritable persistent storage,
including an older local party left behind after a quota error. If both storage
APIs are disabled, the current page still works, but cross-page persistence
cannot be guaranteed. The map does not trap the player in a Play/chooser loop.
The explicit Start again/New story actions keep their existing progress-reset
meaning; a saved party is retained, and can be changed explicitly on the map.

Files: `game/party.js`, `game/index.html`, every
`game/{1..6}-{1..6,S}/index.html`, and the separate tests listed below.
All original stage `META` and map `GAME`/`MAP4`/`IMG` data are unchanged.

## Verification

- `node tests/test_web_party.mjs`: 108 character/mode combinations; legacy,
  malformed and unavailable storage; stale-local/session fallback; campaign and
  skills preservation; all 42 stage contracts; all 208 inline scripts parse.
- `node tests/test_web_runtime.mjs`: each of the 42 actual stage scripts boots in
  its own small Node process, plus solo and local P2 startup in one representative
  stage per world (54 startup cases total). It verifies saved actor identities/CPU role,
  campaign preservation, opening-story gating and the original Next/credits
  destinations. Stage 1-2 also exercises clear/settle/keyboard-next. DOM, images,
  audio and Canvas are stubs. This is simulation evidence, not rendered gameplay.
- Both `node scripts/build-web.mjs --all` (42 stages) and the default public build
  (14 stages) passed. Each includes the shared helper. Clean Next/credits links,
  public world filtering and the membership-lock script remain in place.
- Actual Chromium UI verified the map chooser, cancel rollback, duplicate-mate
  blocking, Mei/CPU Ama persistence, the opening story, and direct gameplay with
  the correct portraits, HUD and actors. The first phase of the real-browser
  regression also passed initial Play interception and pre-story simulation gating.
- Extended real-browser regression is **not yet accepted**: a renderer was
  terminated during concurrent memory pressure; a later bounded run's result was
  not verified. Do not infer a complete browser/device pass from unit tests.

`tests/web-party-browser.html` is a dependency-free local browser runner. Serve
this repository, open `/tests/web-party-browser.html`, and click Run regression.
It keeps one active iframe and replaces it between independent cases. By default
it boots one representative stage per world; `?all=1` adds every stage. Use
`?root=../dist/` for the build output (and append `&all=1` if desired). It exercises
cancel/Escape, CPU/P2/solo, clear/map/next, replay, reload, legacy direct entry and
public membership blocking. It backs up/restores local test-origin saves and
keeps completed checkpoints in `web-party-test-results` if a run is interrupted.
The optional `test_web_party_browser.mjs [game|dist] [--all]` launcher needs
Playwright and Chromium. Launching Chromium from the restricted shell here was
unavailable; the existing desktop browser was used instead.

## Rebuild caveat

The upstream `map4/build_full.py`/injection source is not in this checkout. A
wholesale replacement of `game/` can overwrite these repairs. Preserve the
shared helper and integration changes (or port them into that upstream generator)
and run these regression checks after any regenerated game import.
