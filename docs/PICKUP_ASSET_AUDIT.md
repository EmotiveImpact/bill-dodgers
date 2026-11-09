# Coins, crates and extras audit

Audit date: 9 November 2026. Scope: original Canvas source and current native Godot implementation, all 42 stages. No source artwork replaced, no external assets generated or purchased, no deployment.

## Findings

The loot is implemented gameplay, not decorative placeholders:

- **116 authored breakable crates:** 52 hearts, 41 Split Shot, 20 Direct Debit and 3 festival wellies. Every authored crate appears in its native runtime on a real supporting surface, with its original content. Twelve stages intentionally have no crates; crates were not dropped during the port.
- **2,624 path coins:** 312 streamed World 1 bonus coins plus 2,312 explicit authored coins expanded from rows/arcs/lists. This excludes random enemy drops, character-special money and objective/time bonuses. Empty path-coin columns do not mean a stage has no money: enemy drops remain active.
- **126 optional receipts:** three per stage. Their original arrays are retained byte-for-value in imported metadata. Nine impossible source placements already have explicit native display/contact repairs, listed below.
- **Six permanent skill cards:** Slide (1-4), Double Jump (2-5), Ground Pound (3-4), Dash (4-4), Wall Jump (5-4) and Super (6-4). The native registry matches source coordinates exactly. These are acquired, not automatically unlocked.
- **Six bonus stages:** native timed/distance objectives and rewards exist; their coin inventories are included below. Special mechanics such as checkout carry-crates, festival spotlights/wellies, holiday towels/time gates, moving-day furniture/lifts and billing machines are separate real world systems, not extra power-up types.

This is correctness evidence, **not final art approval**. The rectangular spinning coin, pixel heart, wooden question-mark crate, x3/DD badges and green welly are source-faithful procedural art. Restoring them does not establish that the coins or boxes look polished enough for the finished mobile game.

## Verification performed for this audit

1. `python3 -m unittest discover -s tests -p test_pickup_source_inventory.py -v`: **4 tests passed**. Reads the original HTML independently of the importer; checks all 42 crate/receipt/card/coin placement arrays, per-stage counts, all crate support, and shared original pickup rules.
2. `godot --headless --path godot --script res://tests/test_pickup_inventory.gd`: **19,599 checks passed**. Uses the actual six scene runtimes and combat implementations with a small host adapter, no main scene, textures or audio. Checks every crate's source content/support/three-hit opening/single release/actual heal or power award, every spawned path coin's coordinates, collection of every coin at all six character heights, pickup delays, expiry/offscreen boundaries and personal/shared credit. It also verifies that down players cannot consume another player's heart or coin.
3. Existing small regression suites also passed: World 1 scene state (65 checks), movement skills (83), supermarket combat (115), festival combat (135), billing combat (47) and shared loot renderer (85). These regression suites use small focused fixtures.
4. Initial run was red with exactly two W1 boundary failures. `combat.gd` now removes a coin at age **11.0 seconds** and at **camera x minus 60**, matching source `c.t < 11000 && c.x > cam - 60`. Regression cases cover equality and both sides; all six families now pass.
5. After repairing W1 per-run receipt initialization, `test_receipt_replay.gd` passed **3,680 actual-main checks**: all seven W1 stages × six heroes × two direct-contact runs (252 receipt contacts), plus four CPU/P2 shared-pickup fixtures. Previously saved receipts reappear, grant £5 shared run score once per receipt per run, stay out of personal coin counters, retain unique disk history and never grant a clear, skill or premature banked reward on reload.

These tests place a player in contact to isolate collection. They do **not** prove every coin or crate can be reached during an ordinary uninterrupted run, or that all coins fit an optimal route before camera culling. Main-scene playthrough, real input, natural difficulty, touch readability and phone performance were not rerun by this audit. Existing full-route and local-collectible suites remain separate evidence, with their explicit invulnerability/fixture limits.

Run headless tests with isolated writable HOME/XDG directories, as `scripts/verify-native.sh` does. The initial direct launch without those directories failed before any test because Godot could not create its user/cache directory; the isolated launches above passed.

## Effects and persistence

| Item | Actual behavior | Persistence |
| --- | --- | --- |
| Coin | One Kitty unit; 250ms spawn delay; attraction within 110px horizontally/150px vertically; collection uses each character's height; bounced coins settle 8px above a surface. Ordinary drops expire at 11s or behind camera. | Run score is banked at stage clear. Remaining live coins are swept at clear, as in source. Not a per-coin disk save. |
| Heart crate/drop | Three ordinary projectile hits open a crate; released item pops upward and settles. After 300ms it restores one heart, capped at three. | Current run only. |
| Split Shot | A released x3 item grants three-shot spread for 12s. Current native firing code implements horizontal, diagonal and upward variants. | Current run only; another weapon pickup replaces the existing timed power. |
| Direct Debit | A released DD item grants homing ordinary horizontal/diagonal shots for 12s; source upward variant adds its faster extra shot. | Current run only. |
| Wellies | Three crates across festival field/night. Twelve seconds of mud protection and landing stomps; no extra weapon was invented. | Current run only. |
| Receipt | Source-specific contact rules. W1/W2/W4 add £5; W3/W5/W6 are zero-reward collectibles. | Identity saved immediately; native storage uses indices 0–2. |
| Skill card | Grants the corresponding movement/special capability to the run and party. Source stage-specific movement variants remain intact. | Skills saved immediately and read on later stages/restarts. |
| Objective/bonus money | Holiday saved-towel rewards, holiday dash time multiplier and billing dash time bonus have real score paths; bonus coin clear/timeout settlement also runs. | Banked on clear with the run's Kitty. |

**Inherited source oddities:** released hearts/powers check horizontal proximity only, so a player vertically separated from an item can collect it. Items blink after nine seconds but have no general eleven-second expiry. Ordinary coins and authored bonus coins have different lifespan policies. These are preserved source behavior, not evidence of missing native collision or art. Changing them should be an explicit gameplay-design decision.

**Repaired native/source difference:** W1 previously marked saved receipts as already taken, contrary to original `picksStart()` resetting `got: false`. `main.gd` now initializes new-run receipt state to `taken: false` for every world while retaining `previously_collected` and deduplicated saved history. The 3,680-check actual-main replay suite above verifies W1 repeat collection, exact once-per-run rewards, save/HUD behavior and both pair modes. This restores source behavior rather than inventing a new reward.

Source paths: `game/<stage>/index.html` (`META.level`, `updateCoins`, crate projectile collision, `fire`, pickup/secret code and each world's update hooks). Native paths: the six `*combat.gd` files, `world_one.gd` through `world_six.gd`, `main.gd` (`collect_level_pickups`, `_collect_receipts`, `_fire`, `_complete_level`), `movement_skills.gd`, `abilities.gd`, `save_store.gd` and `party_session.gd`.

The save hooks and weapon firing/wellies behavior were read in the actual implementation. The inventory suite directly exercises grants, coin credit and crate behavior; the follow-up actual-main W1 suite exercises receipt replay, disk persistence and personal/shared HUD accounting. Shooting and full traversal suites were not rerun here. Existing `test_world_five_collectibles.gd` and `test_world_six_collectibles.gd` contain physical receipt/card and reload checks, rather than only import checks; this audit did not rerun those larger suites.

## All-stage placement inventory

Each crate entry is **type `(x, authored y → native floor y)`**, in source order. The authored y is the floor-lookup starting height, not the rendered box top. The box bottom is at native floor y and its source art is 64px tall. `H` = heart, `S` = Split Shot, `D` = Direct Debit, `W` = wellies. A dash means no source-authored crate/path coin in that category, not an unimplemented feature. Every row also has three receipts.

| Stage | Crates | Source coordinates → supported native floor | Path coins |
| --- | ---: | --- | ---: |
| 1-1 | 6 | S (2097, 482 → 482); H (4493, 482 → 482); D (7154, 482 → 482); H (9550, 482 → 482); S (11680, 482 → 482); H (13227, 482 → 482) | 0 |
| 1-2 | 6 | S (2197, -102 → -92); H (7124, -242 → -232); D (8881, -572 → -562); H (10949, -552 → -542); S (15541, -332 → -322); H (18530, -392 → -382) | 0 |
| 1-3 | 0 | — | 0 |
| 1-4 | 5 | S (2313, 482 → 482); H (4772, 482 → 482); D (7504, 482 → 482); H (9963, 482 → 482); S (12149, 482 → 482) | 0 |
| 1-5 | 3 | S (8352, 482 → 482); H (18168, 482 → 482); D (27983, 482 → 482) | 0 |
| 1-6 | 2 | S (900, 482 → 482); H (2917, 482 → 482) | 0 |
| 1-S | 1 | S (10631, 482 → 482) | 312 |
| 2-1 | 5 | S (2200, 472 → 482); H (5500, 472 → 482); D (9100, 472 → 482); H (12100, 472 → 482); S (14500, 472 → 482) | 73 |
| 2-2 | 5 | S (1650, 472 → 482); H (5800, 472 → 482); D (8900, 472 → 482); H (11400, 472 → 482); S (13200, 472 → 482) | 70 |
| 2-3 | 5 | S (1500, 472 → 482); H (4000, 112 → 122); D (6600, 232 → 242); H (10000, 362 → 372); S (12500, 112 → 122) | 40 |
| 2-4 | 0 | — | 243 |
| 2-5 | 5 | S (1550, 472 → 482); H (4900, 472 → 482); D (9500, 472 → 482); H (12750, 472 → 482); S (14000, 472 → 482) | 46 |
| 2-6 | 3 | H (1300, 472 → 482); S (2600, 472 → 482); H (4282, 472 → 482) | 25 |
| 2-S | 1 | S (4500, 472 → 482) | 128 |
| 3-1 | 7 | W (1300, 472 → 482); H (4100, 472 → 482); S (6500, 472 → 482); W (8650, 232 → 246); H (10200, 472 → 482); D (11900, 222 → 246); H (14600, 472 → 482) | 29 |
| 3-2 | 5 | H (2680, 472 → 482); S (9640, 472 → 482); H (16040, 432 → 482); D (23000, 472 → 482); H (27000, 472 → 482) | 80 |
| 3-3 | 6 | H (1300, 472 → 482); W (4400, 472 → 482); S (7600, 472 → 482); H (10800, 232 → 322); D (13220, 232 → 319); H (14000, 472 → 482) | 15 |
| 3-4 | 5 | H (1200, 472 → 482); S (3500, -228 → -218); H (6200, -288 → -278); D (8800, 472 → 482); H (11000, -348 → -338) | 20 |
| 3-5 | 0 | — | 0 |
| 3-6 | 3 | H (1300, 472 → 482); S (2500, 472 → 482); H (3300, 472 → 482) | 0 |
| 3-S | 0 | — | 179 |
| 4-1 | 4 | S (2400, 472 → 482); H (7600, 472 → 482); D (10538, 472 → 482); H (13238, 472 → 482) | 0 |
| 4-2 | 3 | S (2360, 532 → 542); H (7470, 192 → 202); D (13268, -368 → -358) | 0 |
| 4-3 | 2 | S (4138, 472 → 482); H (6368, 472 → 482) | 0 |
| 4-4 | 0 | — | 0 |
| 4-5 | 0 | — | 0 |
| 4-6 | 3 | S (1300, 352 → 362); H (2600, 472 → 482); D (5212, 472 → 482) | 0 |
| 4-S | 0 | — | 258 |
| 5-1 | 3 | H (3980, 142 → 152); S (9080, -518 → -508); D (13940, -1178 → -1168) | 0 |
| 5-2 | 0 | — | 0 |
| 5-3 | 2 | H (520, -848 → -838); S (300, -2168 → -2158) | 0 |
| 5-4 | 3 | H (5700, 232 → 242); S (12100, 232 → 242); D (13800, 472 → 482) | 0 |
| 5-5 | 0 | — | 0 |
| 5-6 | 2 | H (3000, 472 → 482); S (3300, 472 → 482) | 0 |
| 5-S | 0 | — | 484 |
| 6-1 | 5 | S (2400, 472 → 482); H (5200, 472 → 482); D (6700, 472 → 482); H (10400, 472 → 482); S (13300, 472 → 482) | 95 |
| 6-2 | 5 | S (2300, 472 → 482); H (5000, 472 → 482); D (7600, 472 → 482); H (11971, 472 → 482); S (12491, 472 → 482) | 72 |
| 6-3 | 6 | S (2600, 472 → 482); H (5600, 472 → 482); D (6600, 472 → 482); H (9000, 472 → 482); S (12500, 472 → 482); H (14800, 472 → 482) | 111 |
| 6-4 | 0 | — | 165 |
| 6-5 | 0 | — | 28 |
| 6-6 | 3 | H (1300, 472 → 482); S (2900, 472 → 482); H (4282, 472 → 482) | 12 |
| 6-S | 2 | S (3000, 472 → 482); S (8000, 472 → 482) | 139 |

All original coordinate arrays remain in `game/<stage>/index.html` and generated `godot/content/levels/<stage>.json`. The independent Python contract detects changed, missing or reordered arrays.

## Permanent card coordinates

| Stage | Card | Source/native location |
| --- | --- | --- |
| 1-4 | Slide | (8497, 442) |
| 2-5 | Double Jump | (8850, 232) |
| 3-4 | Ground Pound | (5700, -358) |
| 4-4 | Dash | (11710, 342) |
| 5-4 | Wall Jump | (3560, 482) |
| 6-4 | Super | (369, -5632) |

## Explicit source placement repairs already present

Receipt numbers below are the human-facing numbers 1–3. Imported source metadata is not rewritten; runtime receipt identity is preserved.

| Stage / receipt | Original | Native contact/display anchor | Reason |
| --- | --- | --- | --- |
| 4-2 / 1 | (-300, 482) | (60, 482) | Original is behind nonnegative-camera player clamp. |
| 5-1 / 1 | (-250, 482) | (60, 482) | Same clamp issue. |
| 5-2 / 1 | (-250, 482) | (60, 482) | Same clamp issue. |
| 5-4 / 1 | (-250, 482) | (60, 482) | Same clamp issue. |
| 5-6 / 1 | (-250, 482) | (60, 482) | Same clamp issue. |
| 6-1 / 3 | (8090, -988) | (8440, 412) | Original was over a door void, 1400px above the playable floor. |
| 6-2 / 2 | (6530, -988) | (6880, 412) | Same door-void issue. |
| 6-2 / 3 | (9830, -988) | (10180, 412) | Same door-void issue. |
| 6-3 / 2 | (7820, -988) | (8180, 412) | Same door-void issue. |

No additional crate relocation was needed in this audit. A supporting floor alone is not proof of an enjoyable or universally reachable route.

## Bonus-stage semantics

- **1-S:** 39 streamed eight-coin patterns (312 total), 250px/s auto-scroll, source wave/distance ending and settlement. Not a fixed countdown stage.
- **2-S:** 128 path coins, one Split Shot crate and three receipts. Source contains a 100s metadata field but does not activate that timer. Native correctly ends by waves/distance, not an invented timeout.
- **3-S:** 179 coins, three zero-reward receipts and source 90s/empty-inventory endings. Behind-camera losses can empty the inventory; “all collected” source wording is not proof every coin was picked up. The timeout banks remaining live coins at clear.
- **4-S:** 258 coins, 100s initial clock, eight time gates adding 8s and increasing the bonus multiplier, then finish/timeout and settlement.
- **5-S:** 484 coins, source 150s clock or distance ending, conveyor layout and settlement.
- **6-S:** 139 coins, two Split Shot crates, source 110s dash and finish/time bonus.

## Art polish still to do

No missing heart/Split Shot/DD/wellies pickup implementation was found. Exact visual quality, contact readability and complete VFX polish are still unfinished; source fidelity and finished presentation are different goals. W1/W2 now use `shared_loot_renderer.gd`; W3–W6 use the festival-family shared crate/item/coin painter (with a W5 persistent-coin override). Existing source-like visuals are not an approved redesign.

Compatible proposed next work, without changing reward balance or placement:

1. Give coins a clearer rim/highlight and recognizable face at phone size, retain the rotating silhouette, and strengthen the pickup sparkle/short sound cue without hiding hazards.
2. Improve question-mark crate material, lighting and three-hit crack feedback while retaining the 68×64 source footprint, collision, spawn points and mystery contents. W3–W6 currently default crate shake to zero unless supplied a visual snapshot.
3. Make released power badges distinguishable by shape/icon as well as color: x3 spread, DD homing cue and boots. Improve heart silhouettes and contrast against painted backgrounds; do not rely on tiny letters alone.
4. Review receipt/card halos and collection feedback against busy scenery. Check the saved/unlocked state is clear without making collectibles larger than their visible contact expectations.
5. Compare an unchanged source-faithful version with a coordinated polished variant on real phone-size screenshots and actual devices. Approve that direction before treating any replacement art as final.

No new art or asset purchase is included in this audit. Natural-play pickup placement, phone legibility, accessibility, performance and exact final VFX remain acceptance work rather than hidden claims of completeness.
