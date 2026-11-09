# Bill Dodgers native-engine port

This is a **Godot 4.6 native 2D port in progress**, not a WebView or a finished mobile game.
The original Canvas game in `../game/` has separate authorized local continuity and boss-targeting fixes. Its deployed site and web build command are unchanged; the native feature branch has an exact-branch Vercel deployment guard.

## Run

For Windows/macOS cloning, setup and editing instructions, start with
[Editing on another computer](../docs/EDITING_ON_ANOTHER_COMPUTER.md). The shortest
preparation is `python3 scripts/prepare-native.py --godot /path/to/godot`, run from
the repository root, then import `godot/project.godot` and press F5.

1. Install/open Godot 4.6.x (tested with 4.6.3), Python 3 and Node 18 or newer.
2. From the repository root, run `bash scripts/verify-native.sh`. This imports the original content, extracts story data, builds native procedural audio resources and runs all headless regressions. No package manager, downloaded artwork or network connection is needed.
3. Run `bash scripts/verify-party.sh` for isolated party/menu/selector checks, or add `--full` for serialized assisted route matrices. Use `--routes-only --world=5` to target one world.
4. Open `godot/project.godot` and run the project, or run `godot --path godot`.

For a content-only rebuild without tests:

```sh
python3 scripts/import-godot-content.py
node scripts/extract-story.mjs
godot --headless --path godot --script res://tools/build_audio.gd
godot --headless --path godot --editor --import
```

Imported source assets/content and Godot caches are ignored, avoiding another committed copy of the artwork. Regenerate them before opening, packaging or sharing a runnable project. The new original soundtrack `.res` resources and provenance manifest are retained separately, so running the game does not require music-composition dependencies. Full artwork import is serialized to bound editor/CI memory, with no gameplay threading change.

## Playtest controls

Choose Story mode/Continue for the painted campaign map and source unlock/next-stage/story rules, or Free play / stage previews to inspect any stage. First map Play opens the original six-doorway, animated full-body selector once; Change character reopens it deliberately on the map. Confirmed cast/mode choices persist across stages and restarts. All six world runtimes are integrated. Physical-phone validation remains open.

Select any of six housemates. Keyboard: left/right or A/D to move, Z to jump, down/S to duck, Up to aim, Space/X/K to fire, C for a charged special and Escape to pause. Up does not jump. Touch uses the selected translucent joystick and original graphical jump/fire/special/earned-dash buttons. The special ring shows charge and active duration. Menu consolidates pause, sound, story replay and return to the map without covering P2 health. A classic pad remains an internal tested alternative, not the default. Story has Next and Skip controls. Completing the verified main campaign opens original credits.

## What is working

- Six-world picker and all 42 original level IDs, titles, descriptions and JSON metadata.
- Original artwork, map images, sprite sheets, story images and bundled fonts preserved by a deterministic content-addressed importer. Painted art is not downsampled or given a pixel-grid effect.
- Level 1-1 solo playtest: all twelve source waves, six robot variants, original wave camera locks, standing/crouched/upward/diagonal shooting, crates, pickups, coins, checkpoints, Jar Thief state machine, jar pickup and native completion/save. Completion cannot be granted by simply reaching the level end or defeating the boss without collecting the jar.
- Level 1-2 rooftop playtest: original roof/fire-escape artwork and parallax, all eleven waves, enemy roof/chimney hops, twelve crumbling slates, source fall-safe recovery and the all-waves + 2.6-second exit.
- Level 1-3 bus playtest: all twelve ordered fights, scooter arrivals, all twenty-five source bridges/branches with duck warnings and collision, original moving town/bus artwork, source timed exit and preserved encounter state on Continue.
- Level 1-4 park playtest: all ten waves, raised source routes and original paintings, real slide-card acquisition, immediate save and subsequent use.
- Level 1-5 alley chase: all fourteen waves, fifty-two obstacles, dusk overlay and source forced-camera/anti-crush behavior.
- Level 1-S bonus shops: four waves, seventeen awnings, all thirty-nine eight-coin rows/arcs and native timed settlement.
- Level 1-6 Bin day: two approach waves and the dedicated 260-HP, three-phase Binman Bot. Hinged lid armor, thrown/rolling destructible bins, helpers, slam waves, recycling rain, original procedural art and direct timed clear. See BINMAN_PARITY.md for source-bug repairs and exact behavioral boundaries.
- Level 2-1 Car park: all eleven waves, 52 source enemies with distinct security/cart/drone behavior, two parking scenes, actual lift transition, full-heal checkpoint, fifteen runaway trolleys, 73 authored coins, all three receipts and the source timed exit. All six housemates complete input-driven progression tests with explicit invulnerability.
- Level 2-2 Aisle seven: all ten waves and 43 enemies, seven sliding gates, five pressure plates, two shot buttons, ice momentum, warned falling boxes/icicles, the frozen-foods transition/checkpoint and all three receipts. All six housemates complete input-only routes; invulnerability isolates progression.
- Level 2-S Sample sprint: both waves, 128 authored coins, nine decorative stalls, the split crate, three receipts and actual distance/wave exit. All six housemates pass. The unused source 100-second timer remains inactive, verified separately after 105 seconds idle.
- Level 2-3 Stockroom scramble: all eleven waves/46 enemies, six rack towers, nineteen platforms, three conveyors, warned falling stock, actual goods-lift scene policy and gap pallets. All six housemates collect three receipts and clear with zero falls in input-driven progression tests using explicit invulnerability.
- Level 2-4 Trolley dash: original variable-speed camera, seven boost zones, thirteen waves/40 enemies, thirty-six block jumps, fourteen duck signs, eleven runaway trolleys, three receipts and actual timed exit. All six housemates pass with explicit invulnerability; recorded block/trolley contacts are not a damage-free claim. The 3:30 par display is not a deadline.
- Level 2-5 Bakery: eleven waves/45 enemies, all thirteen ovens, four conveyors, flour/wet signs, nine platforms and real swing-door/checkpoint flow. All six housemates earn the double-jump card from no skills, use it during the route, and use it again after disk reload.
- Level 2-6 Self-checkout: three approach waves/14 enemies, scanner jump/duck and bag-mash rules, carried crate puzzle, frozen body/screen damage, receipt stair growth and the actual age-gated jar clear. All six housemates pass full input-driven progression with explicit invulnerability. Separate real-damage tests cover bags and shields.
- Level 3-1 Festival field: all ten authored waves, sixteen tents, eighteen bale surfaces, three van roofs, mud and real wellies pickups/stomps, Food village iris/checkpoint, three zero-reward receipts and the 60-HP Wristband seller. All six housemates pass actual input-driven progression with explicit invulnerability. Source placement failures and timed retirements are accounted for, not reported as kills.
- Level 3-2 Queue jump: fifteen waves/51 entries, source 140-pixel/second auto-scroll, six gaps, six low banners, five solid crowd conveyors, arena iris/checkpoint, all three receipts and the real timed distance ending. All six input routes pass with no falls or banner collisions; other invulnerability-masked contacts are reported separately.
- Level 3-3 After dark: ten waves/48 entries, fifteen tents, five fires, source fade/checkpoint, three receipts and the 70-HP Bailiff. All six input routes pass with zero fire contacts or falls. Original night paintings, layered fire blending, shader light holes, fireworks and source sound are implemented; physical-device graphics/performance remain unverified.
- Level 3-4 Big top: nine waves/31 entries, 49 platforms, four live trapezes, six two-hit spotlights, upper receipts, ground-pound card and the 60-HP Ringmaster. All six input routes earn and reuse the card, land/carry all four trapezes, activate a spotlight, reach the upper pickups and clear with zero falls. Dazzle timing/double damage is verified separately in real-main fixtures.
- Level 3-5 Hay ride: one live tractor trailer, sixteen waves/39 carrier and flying enemies, eighteen low branches, three airborne receipts, dusk/checkpoint and separate 70-HP harvester. All six input routes defeat it using ordinary shots; an additional real-fall/Continue route verifies source distance completion with it alive. Native replay binds the deck before floor lookup to avoid the original reset-order bug. Cosmetic draw-time tractor exhaust remains pending along with other particle polish.
- Level 3-6 Ticket Tout: three approach waves, the full 160-HP seven-animation encounter, barrier/bale/stage routes, wristband/surf/slam phases and source jar attraction/collection ending. All six input routes collect all three receipts, exercise the real phases and persist their clear with explicit invulnerability.
- Level 3-S Festival bonus: all 179 authored coins, three zero-reward receipts, four partner stalls, source empty-inventory/90-second endings and actual remaining-coin settlement. All six input routes pass without invulnerability; an additional idle route verifies timeout banking and the pre-settlement banner. Camera-cull losses are recorded rather than described as collected.
- All six animated housemates and their source specials, core passives, charge rules and explicitly supplied super scaling. This does not unlock unearned skills.
- Source movement-card mechanics (slide, double jump, ground pound, dash, wall jump and super) with stage-specific variants and saved-skill support. No skills are auto-unlocked; card acquisition is gated off in unported previews. The park awards slide, the bakery awards double jump and the Big top awards ground pound at their actual source locations, with saved use in later stages.
- Native playback of the source story: all 21 scene definitions and 193 shots extracted, original art/dialogue/camera/actors, pause, skip and replay. Level 1-1 opens with its source intro. Some visual effects and later-world procedural boss shapes remain incomplete.
- All 19 shared source procedural sound effects, the World 3 firework sound and both complete normal/boss fallback music loops. Build-time audio generation avoids first-use music synthesis during gameplay. Missing source MP3 recordings are not invented.
- Multitouch controls, focus/background pause, explicit resume and touch release after pause/rotation. Paused stories cannot bypass the pause overlay or leave disabled controls on replay.
- Source campaign unlock/bonus order, animated painted map and next-stage routing, with intro/boss/clue story hooks and guarded campaign entry. The official character-selection flow is deliberate and never repeats automatically before every stage. Some exact compositing differences remain documented.
- Receipt collection, separate atomic native saves, sanitized progress and corrupt-save recovery. Existing browser saves are not modified or migrated.
- Worlds 4, 5 and 6 now have dedicated runtime, combat, boss and renderer integrations. All 42 World 4 housemate/stage routes pass with all receipts and source objectives. All 42 World 5 routes pass with all three receipts, sofa transitions, lift floors, van duration and King phases. All 42 World 6 routes pass; a separate 2,580-check collectible suite covers all receipts/cards, while full-route receipt collection varies by stage. The complete solo aggregate passes across all 252 character/stage combinations. These are not a completed-game or phone-performance claim.
- Original source credits and full 36-main-stage campaign/story/ending routing are tested with explicit synthetic UI fixtures. Source HUD hearts/special/Kitty, character projectiles/auras and timed banners are restored.
- Eighteen provisional original music cues are bundled separately from the preserved source sound effects. They are replaceable prototypes, not approved final arrangements; the user has requested more distinct genres and a stronger UK garage direction. Listening and device balance remain open.

## Not implemented or verified

- Finish expanded complete-game acceptance, independent review, remaining presentation comparisons and source/native fix reconciliation.
- Complete physical two-human/gamepad acceptance and finished accessibility/settings. Actual independent actors, source CPU AI, revive, per-actor rewards/abilities and all six world adapters are integrated. Every stage has all-six-CPU-identity assisted progression evidence, not a 36-pair cross-product or proof both actors survived. Reachable Solo/CPU/local-keyboard-P2 selection is implemented. See `../docs/NATIVE_PARTY_ACCEPTANCE.md`.
- Exact visual/animation/VFX fidelity, tuned difficulty, listening QA, human full-run playtesting or a claim of complete unassisted six-world acceptance. The automated supported-stage traversals use invulnerability to isolate progression and are not difficulty validation.
- iPhone/Android installation, device graphics/input/performance/battery tests, signed builds, store listing, approval or deployment. A resource pack is not an APK or IPA.
- Production Commune membership/authentication, purchase receipts or store entitlement integration. The full-content development port does not treat local flags as membership; the deployed public web game is unchanged.
- Asset/font provenance and redistribution notices. The source repo has no rights inventory. The original Silkscreen and Pixelify Sans WOFF2 fonts load through Godot and are used for native game/story text; full verified OFL notices are bundled in `godot/legal/` and the read-only Licenses view. Supplied-art provenance and final distribution acceptance remain open; see `../docs/ASSET_RELEASE_NOTICES.md`.

## Native exports

For the separate browser demo, see [Godot Web demo](../docs/GODOT_WEB_DEMO.md).
It exports this engine project and does not replace the original Canvas web site.
The Web preset, template-aware export helper and browser-foundation regressions
are included; actual iPhone/Safari acceptance remains separate.

The Android and iOS development presets use a provisional `.preview` application ID and contain no credentials. They are setup groundwork, not verified installable builds.

- Android needs matching Godot export templates, Android SDK/JDK and a debug/signing setup. Open Export in Godot, resolve its requirements, then export the Android Native Preview preset.
- iOS needs matching Godot export templates plus macOS/Xcode and the user's chosen Apple team/signing configuration. Export the iOS project, finish signing in Xcode and test on an iPhone.
- Run `bash scripts/verify-native-pack.sh /tmp/bill-dodgers-preview.pck` after the normal verification to validate the exported resource pack in an asset-free harness. It checks original fonts, native startup/story and all 22 audio resources without synthesis fallback.
- Export filters include the generated level/story JSON, sprite metadata and native generated audio resources. Tool/test scripts and the JavaScript reference are excluded.
- Keep credentials out of Git. Do not submit this playtest as a completed game. Final app identifiers, names, store access/payment model and asset rights must be confirmed before release.

See `../docs/NATIVE_PORT_PLAN.md` for acceptance gates and the individual parity documents for known behavior differences.
