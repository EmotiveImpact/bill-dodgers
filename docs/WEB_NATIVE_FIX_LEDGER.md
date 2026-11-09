# Web and native fix ledger

Updated 2026-11-09. The original Canvas game now has authorized local party
continuity and three boss-feet repairs. Its web build script, Vercel configuration
and deployed site are unchanged. Godot remains a separate implementation; a native
fix does not automatically repair the deployed website.
The repository remains public as requested. No publication or visibility change
is part of this work.

## Original source fixes and backport status

The native implementation repairs these deliberately rather than emulating broken
values. Applied web changes are explicitly distinguished from deferred candidates.

| Finding | Original source | Native treatment | Web status |
|---|---|---|---|
| Binman omits the feet coordinate used by several shared specials. NaN comparisons also give Ama's ghost unusual interception behavior. | `game/1-6/index.html`, `sceneBossStart`, shared ability `hitBoss`/proximity hooks. Detailed evidence: `BINMAN_PARITY.md:49`. | Finite `fy=ground`, real projectile interception and normal height checks. Boss armor and phase rules retained. | Not changed. Backport must test helper interception as well as the newly effective powers. |
| Fresh Hay ride can query a floor before its only moving trailer deck is bound. | `game/3-5/index.html`, `TRAILER`, reset/start floor ordering. `FESTIVAL_HAYRIDE_PARITY.md`. | Binds live deck before initial floor query; source moving/carry/harvester rules remain separate. | Not changed. Reorder initialization without adding fake static ground. |
| First Old town receipt is at x=-300, behind the permanent player/camera clamp. | `game/4-2/index.html`, `META.level.receipts[0]`, base player clamp. `WORLD_FOUR_IMPLEMENTATION.md`, source defect section. | Runtime-only x=60/y=482 anchor, original imported data and receipt ID retained. No personal coin increment; native receipt reward remains separate. | Not changed. Author a reachable anchor and test ordinary input pickup/replay, not a teleport fixture. |
| Captain stores `y` but shared abilities read `fy`, silently missing targeted powers. | `game/4-1/index.html:1305–1356` shared Captain controller; all W4 copies. `HOLIDAY_CAPTAIN_PARITY.md`. | Synchronized `fy=y` including sinking. Body damage stays one; endpoint valve damage stays three. Unused source dizzy AI behavior remains unchanged. | Applied locally in all seven W4 controllers, with a live read-only fy alias and actual-JS special/phase tests. Not deployed. |
| Several Moving day stages put receipt 0 at x=-250, also behind the clamp. | `game/5-1`, `5-2`, `5-4`, `5-6`, authored receipt 0. `WORLD_FIVE_IMPLEMENTATION.md`. | Runtime-only x=60, original y and ID retained. All six characters' ordinary input repair routes tested; reward stays zero. | Not changed. Preserve save identity and verify repeated runs cannot duplicate a physical pickup. |
| Cardboard King omits `fy`, although shared targeted specials require it. | `game/5-*/index.html`, `startKing`, shared abilities. `WORLD_FIVE_IMPLEMENTATION.md`. | Finite ground feet coordinate. Body/crown/dizzy damage, armor and phase gates unchanged. | Applied locally in all seven W5 controllers, with finite ground feet and actual-JS armor/crown/phase/special tests. Not deployed. |
| Sir Charge stores a vertical offset but omits shared ability feet. | `game/6-*/index.html`, `startBoss`, `updateBoss`, shared abilities. | Finite current `fy=ground+yo`, synchronized as the boss floats; all 42 solo stage/character routes pass. | Applied locally in all seven W6 controllers as a live getter, with floating/dizzy/down/phase/special tests. Not deployed. |
| Unguarded delayed callbacks can outlive pause or a replaced encounter. | Binman's delayed throws, King's helper/double-stomp timeouts and source scene callbacks. See the individual parity documents. | Run-local simulation clocks and generation guards. Paused/dead/replaced runs do not execute stale work. This is an explicit reliability adaptation. | Not changed. A web backport needs cancellation/lifecycle guards in its own timer system. |


## Party continuity in the original web repo

All 42 stage pages now retain a confirmed solo/CPU/local-P2 party through reload,
replay and next-stage navigation. The map's explicit Change character control
sets actual players, not only its walker. Opening story playback gates simulation;
the main title remains the appropriate session entry. Source META and receipt IDs
are unchanged. See `WEB_PARTY_CONTINUITY.md` and `WEB_BOSS_FEET_REPAIRS.md` for exact
files, 108 selection/storage checks, 54 runtime starts, 21 boss regressions, both
builds and the narrower actual-browser evidence. Extended browser acceptance is
still incomplete; no site deployment is implied.

## World 6 receipt and final-boss repairs

World 6 keeps its imported source rows and zero-based save identities unchanged.
Four original receipts are on 1,400 px-high doorway void sentinels skipped by scene
transitions. Runtime anchors move only these rows onto clear floor 60 px beyond
actual door arrival: 6-1 receipt 3 (8090,-988)→(8440,412); 6-2 receipt 2
(6530,-988)→(6880,412) and receipt 3 (9830,-988)→(10180,412); 6-3 receipt 2
(7820,-988)→(8180,412). All six characters' ordinary-input local arrival/pickup,
zero reward, original identity, immutable META and replay persistence are covered
by `test_world_six_receipts.gd`. The separate `test_world_six_collectibles.gd`
also verifies all 21 receipts and Super-card pickup/use/replay for all six
characters from explicit source-support fixtures. A distinct 42-route matrix
verifies ordinary-input whole-stage progression, not every optional detour.
See `WORLD_SIX_IMPLEMENTATION.md` for exact anchors and verification limits.

Sir Charge's native feet alias is `fy=ground+yo`, including airborne/dizzy/down
states. Actual W6 body damage, phase thresholds and jar age stay source-specific.
The Sir Charge feet contract is now also fixed in the original Canvas source.
Receipt relocations remain native-only, and no changes have been deployed.

## Native-only defects repaired

- Android automatic Back exit conflicted with the native pause handler. The
  Godot project now disables automatic exit; in-engine Back/pause/resume tests
  pass. No physical Android Back gesture has been tested yet.
- Godot GUI-consumed drag events left a held game action active until finger
  lift. Existing contacts now update before GUI dispatch. New presses still
  belong to GUI first. This is not evidence of the same bug in browser input.
- The initial native HUD omitted the source portrait/hearts/special/Kitty
  presentation. The source artwork and bars were restored and captured in the
  running native game. Further HUD and user-selected control refinements remain
  under active review.
- Generic native shot circles and partial ability visuals were implementation
  omissions, not missing original assets. Source-backed native renderers are
  being verified. They do not require changing the original Canvas artwork.

- The native ordinary texture flip added a width to a destination that Godot
  already flips in place. This created alternating gaps in backgrounds and moved
  mirrored sprites. Rooftop/bus/street, supermarket, festival/Tout and Holiday
  paths are corrected, including the housemate's asymmetric 0.45 foot anchor.
  Real OpenGL pixel comparisons and before/after captures are documented in
  `TEXTURE_MIRRORING_PARITY.md`. Canvas itself did not have this native API bug.
- A generalized later-world passive movement call ran World 2's stateful ice/
  flour recurrence twice and incorrectly applied World 5's sofa carry factor to
  the extra passive nudge. Only World 3 defines the source `spdMul` wrapper.
  The native wrapper now preserves that exact distinction. The actual-host
  `test_passive_movement_order.gd` covers ice state, flour, sofa and W3 ties;
  the six Bakery input routes were rerun successfully. This was a native
  regression, not an original-source defect or a proposed web backport.
- Native generic pickup discs and plain crates omitted existing source artwork.
  `shared_loot_renderer.gd` now renders pixel hearts, coin spin, power badges,
  expiry blinking and detailed crates. Simulation remains separate; cosmetic
  hit jitter uses a deterministic hash instead of consuming gameplay randomness.
- W1 native coin cleanup used the wrong equality at the 11-second lifetime and
  camera-minus-60 boundary. It now matches the source strict live range. The
  all-stage pickup fixture checks 19,599 source-placement/contact/effect cases;
  this does not establish natural-input reachability of every optional pickup.
- W1 native receipt initialization incorrectly hid previously collected receipts.
  Source pickups reset each run while saved identity history remains deduplicated.
  The native fix now permits replay pickups and the source shared £5 reward once
  per receipt per run, without personal coins or duplicate saved identities.
  `test_receipt_replay.gd` passes 3,680 actual-main checks, including all seven W1
  stages and six heroes over two direct-contact fixture runs plus CPU/P2 cases.
- Native CPU actors inherited human-only Dash and vertical-aim behavior. The host
  now uses the actual active actor's CPU flag in movement, firing and animation,
  preserving source diagonal CPU aim. `test_party_cpu_skills.gd` passes 78 checks.
  The affected World 5/6 all-six-CPU route matrices were rerun successfully.

See `NATIVE_GAMEPLAY_AUDIT.md` and `PLAYER_HUD_PARITY.md` for verified scope and
limits. Unit/command tests are not phone testing or a complete visual comparison.

## Two separate web routes

1. **Keep the existing Canvas website.** Backport the confirmed source defects
   in JavaScript, preserve its content filtering, then test the original game
   and deploy only with authorization. Shared design decisions such as clearer
   controls can be implemented independently in both renderers. GDScript itself
   is not a patch for the Canvas engine.
2. **Export the Godot implementation for the web.** This could share the same
   GDScript gameplay and native fixes, but it is a new web build. It needs the
   matching web export templates, an actual export, browser graphics/audio/input
   and load/memory testing, and hosting compatibility review. No web export has
   been produced or validated here. Do not replace the current website merely
   because a native resource pack passed.

An original Canvas backport and a Godot web export are different deliverables.
Neither has been published by this implementation.

## Planned Commune arcade acceptance

The user has proposed Godot for the web at the end of the port, for the
ourcommune arcade and games that can be opened from the app. Treat this as a
planned next acceptance track, not a migration already performed.

- Export a versioned Godot web test build without replacing the current route.
  Verify the chosen hosting environment, graphics requirements, audio start,
  fullscreen, browser Back, keyboard/controller/touch input and orientation.
- Define a small game manifest: stable game ID, title/art, version, entry URL or
  package reference, supported controls, save schema and platform requirements.
  Distinguish loading a web game from installing another native executable.
- Test arcade launch/return and app WebView or native-player alternatives on
  actual devices. Do not assume a desktop browser pass certifies an embedded
  mobile browser or a Godot native package.
- Keep membership checks in the trusted Commune service. Review the current
  authentication/entitlement implementation first. Never put account secrets or
  an authoritative paid-access flag into a downloadable game bundle.
- Define explicit save ownership, cross-device sync/conflict rules, offline
  behavior and backward-compatible migrations. Existing browser saves must not
  be overwritten by a new native/web save scheme without a tested migration.
- Measure initial download, cached launch, texture memory, stage switches,
  sustained frame time and pause/resume. The latest verified approximately278MiB native
  resource pack is not a measured or optimized web download budget.
- Review the chosen store policies and content/download model before promising
  arbitrary game imports inside the phone app. No account, payment, licensing,
  hosting or public-distribution change is authorized by this planning note.

The initial deliverable should be a working, isolated arcade integration test,
followed by an explicit migration/distribution decision once its evidence is
available.

## Membership is separate

The original web README describes Worlds 1–2 as free and Worlds 3–6 as
member-only. The current public source and full-content Godot development build
do not enforce a paid entitlement. The earlier Commune inspection found that
production billing/entitlement wiring was not implemented; a local flag, login
or household membership must not be presented as proof of payment.

Before distributing a replacement web build, decide its content/access model
and verify current server-side authorization. Before distributing phone builds,
also decide the applicable store access/payment flow. This ledger does not grant
permission to change membership, accounts, payment integrations, sharing or the
live site.
