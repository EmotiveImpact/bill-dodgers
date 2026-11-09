extends RefCounted
## Shared runtime/save capability registry. Importing a stage is not support.
const WORLD_ONE := ["1-1", "1-2", "1-3", "1-4", "1-5", "1-6", "1-S"]
const WORLD_TWO := ["2-1", "2-2", "2-3", "2-4", "2-5", "2-6", "2-S"]
const WORLD_THREE := ["3-1", "3-2", "3-3", "3-4", "3-5", "3-6", "3-S"]
const WORLD_FOUR := ["4-1", "4-2", "4-3", "4-4", "4-5", "4-6", "4-S"]
const WORLD_FIVE := ["5-1", "5-2", "5-3", "5-4", "5-5", "5-6", "5-S"]
const WORLD_SIX := ["6-1", "6-2", "6-3", "6-4", "6-5", "6-6", "6-S"]
const SUPPORTED := WORLD_ONE + WORLD_TWO + WORLD_THREE + WORLD_FOUR + WORLD_FIVE + WORLD_SIX

static func supports(id: String) -> bool:
	return id in SUPPORTED

static func family(id: String) -> int:
	return 1 if id in WORLD_ONE else (2 if id in WORLD_TWO else (3 if id in WORLD_THREE else (4 if id in WORLD_FOUR else (5 if id in WORLD_FIVE else (6 if id in WORLD_SIX else 0)))))

static func source_ability_shots(id: String) -> bool:
	return id == "1-6" or id in WORLD_TWO or id in WORLD_THREE or id in WORLD_FOUR or id in WORLD_FIVE or id in WORLD_SIX
