# Big top actual-main integration fixtures

`godot/tests/test_big_top_integration.gd` exercises the enabled native 3-4 through the actual `main.tscn` scene and production step, runtime, combat, movement skills, painter and save store. These are **explicit isolation fixtures, not full-input routes or progression evidence**. The separate route suite owns whole-course reachability. There are no device, installation, signing, publication or visibility claims.

## Scope and instrumentation

The tests suppress scheduled waves, clear initial authored coins, place actors/cameras, set spotlight phases/HP and prepare enemy/boss states to isolate precise seams. A wall-precedence case places a lamp inside an existing authored solid; it does not alter collision geometry. A final-distance fixture marks waves complete and advances the clear timer, deliberately without earning the card or defeating the mini. These setups must not be described as gameplay achievements.

The scene receives a main-script subclass that counts `_save_progress` calls and always invokes `super`; no production behavior is replaced. A painter subclass records wrapper calls and always draws through `super`. Audio is replaced with the existing test event logger. No production files are changed by this suite.

## Verified contracts

- All six selectable housemates use the actual World 3 runtime and Big top painter. Live trapeze dictionaries/rows retain reference identity and `nospawn`. Bots carry in the late phase; the player consumes the preceding frame's displacement. Ordinary jump/drop and ability/skill floor queries consume live geometry, and normal/skill wall queries agree. Imported metadata stays unchanged.
- Ordinary bot, boss and crate hits, solid removal and high-camera removal precede spotlight collision, for ordinary and ghost shots. Switch boundaries are strict; each shot costs one HP regardless of multiplier; excess activation-frame shots are consumed and repeat the source power event. Already-on switches pass later shots.
- Actual late Theo ball effects produce a ghost after the lamp phase; the ghost can hit the lamp only on the next frame.
- Lamp activation cannot double damage already resolved earlier that frame. Late dazzle refreshes to 250ms, doubles the next frame's shot, and exact expiration before a shot removes the multiplier. Beam angles just inside/outside both edges and dy zero/positive are tested with actual main steps.
- All six housemates trigger the strict x5600 checkpoint without teleporting to the presentation y. All six acquire the actual ground-pound card, read it from the isolated save file, reload the stage and use the persisted pound without injecting an earned skill.
- Actual camera8040 triggers the solo 60HP ground Ringmaster. Its down celebration persists at exactly1.8 seconds and dismisses just afterward. Pause freezes runtime; Continue retains it; fresh loading resets lamps/mini. Ground-height endpoint clear has no card, altitude or miniDone requirement. Repeated completion produces exactly one save call and one score settlement. Returning to the map works.
- Actual CanvasItem drawing executes the painter. Native `draw_level` and `draw_mid` are contiguous before crates/actors, so the split helpers preserve the source's final `drawFinds` phase in `drawLevel`. The combined plan contains one source card before collection and none afterward. Real wrapper order is level → finds → crates → player. Drawing does not mutate simulation or RNG. This is draw-path/order coverage, not pixel or device visual parity.

## Independent source audit

Assertions were checked against `game/3-4/index.html`, not solely copied from native implementation:

- 528–547: ordinary shot priority, wall filtering and strict camera bounds.
- 951–972 and1534 onward: surfaces/checkpoint/spots/ropes/finds draw order, then gameplay objects.
- 1175–1179: player carry reads previous deltas and checks current horizontal bounds.
- 1182: ordinary end eligibility has no altitude/card/miniDone condition.
- 1216: existing dazzle decays and skips bot AI before shot damage.
- 1262–1283: exact receipt/card centers, strict pickup rectangle, persisted skill and find drawing.
- 1294–1327: finds/checkpoint/late movers, late bot carry, spotlight switch and beam, then mini trigger.

## Validation

Godot4.6.3 headless, with isolated HOME/XDG directories:

`HOME=/tmp/big-integration-home XDG_DATA_HOME=/tmp/big-integration-xdg /usr/local/bin/godot --headless --path godot --script res://tests/test_big_top_integration.gd`

Final result: **128 checks, zero failures**. The entire log was scanned for parse/script errors, `ERROR:`, `FAIL:` and leak diagnostics, independently of exit status. No such diagnostics appeared.

Earlier development assertions incorrectly required finds inside a particular native helper. Reviewing the complete main draw chain showed no intervening drawable; those assertions were replaced by composite-plan and actual-call-order checks. No production defect is claimed from that helper split.
