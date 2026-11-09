# Original web game: finite boss feet

Implemented locally on 2026-11-09, alongside party continuity. No deployment.

Shared abilities target `boss.fy`; three original boss controllers omitted it.
That made targeted shots/proximity checks use `undefined`/`NaN`, even though the
bosses had valid native collision coordinates. The repair adds only that shared
coordinate contract in all seven duplicated controller copies per world:

- `game/4-{1..6,S}/index.html`, `startW4Boss`: a live `fy` getter returns `y`.
  It remains correct while Captain Overcharge sinks. The visual bob remains
  cosmetic, exactly as the source body collision treats it.
- `game/5-{1..6,S}/index.html`, `startKing`: `fy: GROUND`. The Cardboard King's
  boxes, crown and all three phase shapes continue to use the same floor.
- `game/6-{1..6,S}/index.html`, `startBoss`: a live `fy` getter returns
  `GROUND + yo`. It follows Sir Charge through floating, dizziness, landing and
  the down state, including the source controller's early-return branches.

No stage `META`, authored receipt coordinate, phase threshold, HP, movement,
collision box, damage multiplier, timer, encounter route or artwork was edited.
The existing source `updateShots`/`bossShot` still judges each helper shot.

## Dedicated regression

`node tests/test_web_boss_feet.mjs` executes the shipped boss and shared ability
functions in small deterministic fixtures for all 21 controller copies. It checks:

- Finite initial feet, Captain sinking, Sir Charge float/dizzy/down synchronization.
- All three phases and unchanged solo/paired starting HP.
- Captain body-one and endpoint-valve-three damage.
- King body-one, armor rejection and dizzy-crown-four damage.
- Sir Charge body-one/dizzy-two damage and an airborne boss remaining beyond
  the ground-pound range.
- Actual Maya shield, Ama bubble, ground-pound and Theo ball target predicates
  generate finite helper shots. JP/Leo/Mei branches remain finite and unchanged.
- Down bosses remain excluded from shared targeted abilities.

These are source-function regressions, not complete human-input boss runs or
visual/difficulty acceptance. The original `META` and map data remain byte-for-
byte identical to the pre-repair checkout. Native importers can consume the
updated source HTML, but tests that assert the old missing-feet bug should be
updated deliberately rather than treating that defect as parity.

## Deferred source defects

The negative first-receipt coordinates and World 6 doorway-void receipts were
not moved. They need ordinary-input pickup/replay acceptance and an explicit
source-data decision. Binman's feet/interception behavior, Hay ride floor-order
initialization and delayed callback lifetime repairs also remain separate work.
See `WEB_NATIVE_FIX_LEDGER.md` for the broader audit; this document records only
the three JavaScript fixes actually made here.
