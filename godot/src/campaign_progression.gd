extends RefCounted
## Pure campaign decisions. No file IO, scene changes, timers, awards, or preview bypass.
## Callers supply the catalog and the actual runtime support registry, never save flags.
const NativeLevels = preload("res://src/native_levels.gd")
const BEFORE_STORY_DELAY := 0.25
const AFTER_CLEAR_STORY_DELAY := 2.6
const CONTINUE_DELAY := 1.9

# Exact MAP4.order (without HOME), not catalog order or a numeric next-level guess.
const ORDER := [
	"1-1", "1-2", "1-3", "1-4", "1-5", "1-6", "1-S",
	"2-1", "2-2", "2-3", "2-4", "2-5", "2-6", "2-S",
	"3-1", "3-2", "3-3", "3-4", "3-5", "3-6", "3-S",
	"4-1", "4-2", "4-3", "4-4", "4-5", "4-6", "4-S",
	"5-1", "5-2", "5-3", "5-4", "5-5", "5-6", "5-S",
	"6-1", "6-2", "6-3", "6-4", "6-5", "6-6", "6-S",
]
# Incoming path requirements collapsed from MAP4.edges (gates are presentation).
const REQUIRES := {
	"1-1": "", "1-2": "1-1", "1-3": "1-2", "1-4": "1-3", "1-5": "1-4", "1-6": "1-5", "1-S": "1-1",
	"2-1": "1-6", "2-2": "2-1", "2-3": "2-2", "2-4": "2-3", "2-5": "2-4", "2-6": "2-5", "2-S": "2-1",
	"3-1": "2-6", "3-2": "3-1", "3-3": "3-2", "3-4": "3-3", "3-5": "3-4", "3-6": "3-5", "3-S": "3-3",
	"4-1": "3-6", "4-2": "4-1", "4-3": "4-2", "4-4": "4-3", "4-5": "4-4", "4-6": "4-5", "4-S": "4-2",
	"5-1": "4-6", "5-2": "5-1", "5-3": "5-2", "5-4": "5-3", "5-5": "5-4", "5-6": "5-5", "5-S": "5-3",
	"6-1": "5-6", "6-2": "6-1", "6-3": "6-2", "6-4": "6-3", "6-5": "6-4", "6-6": "6-5", "6-S": "6-1",
}
const WORLD_NAMES := ["Your street", "The big shop", "Festival weekend", "Group holiday", "Moving day", "The Bill-ding"]
const BEFORE_SCENES := {
	"1-1": "1-intro", "1-6": "1-boss", "2-1": "2-intro", "2-6": "2-boss",
	"3-1": "3-intro", "3-6": "3-boss", "4-1": "4-intro", "4-6": "4-boss",
	"5-1": "5-intro", "5-6": "5-boss", "6-1": "6-intro", "6-6": "6-boss",
}
const AFTER_SCENES := {"1-3": "1-clue", "2-3": "2-clue", "3-3": "3-clue", "4-3": "4-clue", "5-3": "5-clue", "6-3": "6-clue", "6-6": "6-ending"}

static func snapshot(native_save: Dictionary, catalog: Dictionary, supported_ids = NativeLevels.SUPPORTED) -> Dictionary:
	var entries := _catalog_entries(catalog)
	var support := _support_set(supported_ids)
	var valid_schema := _valid_schema(native_save)
	var raw_clears := _dictionary(native_save.get("cleared")) if valid_schema else {}
	var raw_receipts := _dictionary(native_save.get("receipts")) if valid_schema else {}
	var state := {"levels": {}, "unlocked": [], "playable": [], "native_cleared": {}, "verified_cleared": {}, "worlds": [], "receipts": {}, "receipt_count": 0, "schema_valid": valid_schema}
	for id in ORDER:
		var world := int(id[0])
		var available := entries.has(id)
		var supported := support.has(id)
		var prerequisite: String = REQUIRES[id]
		var unlocked: bool = prerequisite.is_empty() or state.verified_cleared.has(prerequisite)
		# Keep legitimate out-of-order development clears visible, without granting paths.
		var native_cleared := supported and _is_true(raw_clears.get(id))
		var cleared: bool = available and unlocked and native_cleared
		if native_cleared: state.native_cleared[id] = true
		if cleared: state.verified_cleared[id] = true
		var playable: bool = available and supported and unlocked
		if unlocked: state.unlocked.append(id)
		if playable: state.playable.append(id)
		var receipts := _receipt_indices(raw_receipts.get(id)) if available and supported else []
		if not receipts.is_empty(): state.receipts[id] = receipts
		state.receipt_count += receipts.size()
		var status := "unavailable" if not available else ("preview" if not supported else ("locked" if not unlocked else ("cleared" if cleared else "ready")))
		var reason := "Missing catalog entry" if not available else ("Layout preview; native campaign not implemented" if not supported else ("Clear %s to open this stage" % prerequisite if not unlocked else ""))
		var title = entries.get(id, {}).get("title", id)
		if not title is String: title = id
		state.levels[id] = {"id": id, "world": world, "title": title, "bonus": id.ends_with("-S"), "requires": prerequisite, "receipts_required": 0, "receipts": receipts, "available": available, "supported": supported, "unlocked": unlocked, "playable": playable, "native_cleared": native_cleared, "cleared": cleared, "status": status, "reason": reason, "play_label": ("Play again" if cleared else "Play") if playable else "", "label": "%s  %s" % [id, title]}
	for world in range(1, 7):
		var main_clears := 0
		for n in range(1, 7):
			if state.verified_cleared.has("%d-%d" % [world, n]): main_clears += 1
		state.worlds.append({"world": world, "name": WORLD_NAMES[world - 1], "label": "World %d: %s" % [world, WORLD_NAMES[world - 1]], "unlocked": state.levels["%d-1" % world].unlocked, "completed": state.verified_cleared.has("%d-6" % world), "main_cleared": main_clears, "main_total": 6, "bonus_cleared": state.verified_cleared.has("%d-S" % world)})
	state.story_complete = state.verified_cleared.has("6-6")
	state.credits_unlocked = state.story_complete
	state.menu_label = "Story complete" if state.story_complete else ("Start story" if state.verified_cleared.is_empty() else "Continue story")
	state.next_route = _next_route(state, "")
	return state

static func level_state(native_save: Dictionary, catalog: Dictionary, supported_ids, level_id: String) -> Dictionary:
	return snapshot(native_save, catalog, supported_ids).levels.get(level_id, {})

static func next_route(native_save: Dictionary, catalog: Dictionary, supported_ids, from_level: String = "") -> Dictionary:
	return _next_route(snapshot(native_save, catalog, supported_ids), from_level)

# Runtime must explicitly attest an actual objective clear and a normal campaign run.
# This API does not prove gameplay, bank coins, award skills, or write a save.
static func record_clear(native_save: Dictionary, catalog: Dictionary, supported_ids, level_id: String, legitimate_clear: bool = false, campaign_run: bool = false) -> Dictionary:
	var result := {"accepted": false, "reason": "", "save": native_save.duplicate(true), "newly_cleared": false, "after_scenes": [], "route": {}}
	var state := snapshot(native_save, catalog, supported_ids)
	if not state.schema_valid: result.reason = "invalid_schema"
	elif not legitimate_clear: result.reason = "objective_not_completed"
	elif not campaign_run: result.reason = "not_campaign_run"
	elif not state.levels.has(level_id): result.reason = "unknown_level"
	elif not state.levels[level_id].available: result.reason = "missing_catalog"
	elif not state.levels[level_id].supported: result.reason = "not_native_supported"
	elif not state.levels[level_id].unlocked: result.reason = "locked"
	else:
		result.accepted = true
		result.newly_cleared = not state.native_cleared.has(level_id)
		# Preserve existing legitimate native development clears; never prune the caller's save.
		var clears := _dictionary(result.save.get("cleared")).duplicate(true)
		clears[level_id] = true
		result.save.cleared = clears
		result.save.schema = 1
		result.route = next_route(result.save, catalog, supported_ids, level_id)
		result.after_scenes = story_after_clear(result.save, catalog, supported_ids, level_id)
	return result

static func story_before_level(native_save: Dictionary, catalog: Dictionary, supported_ids, level_id: String) -> Array:
	var state := snapshot(native_save, catalog, supported_ids)
	if not state.levels.get(level_id, {}).get("playable", false): return []
	var scene: String = BEFORE_SCENES.get(level_id, "")
	var seen := _dictionary(native_save.get("seen")) if state.schema_valid else {}
	return [scene] if not scene.is_empty() and not _is_true(seen.get(scene)) else []

# Source post-clear scenes replay on every clear; seen is NOT a suppression flag here.
static func story_after_clear(native_save: Dictionary, catalog: Dictionary, supported_ids, level_id: String) -> Array:
	var state := snapshot(native_save, catalog, supported_ids)
	var scene: String = AFTER_SCENES.get(level_id, "")
	return [scene] if state.verified_cleared.has(level_id) and not scene.is_empty() else []

static func story_replay_for_level(native_save: Dictionary, catalog: Dictionary, supported_ids, level_id: String) -> Array:
	var state := snapshot(native_save, catalog, supported_ids)
	if not state.levels.get(level_id, {}).get("playable", false): return []
	var scenes: Array = []
	if BEFORE_SCENES.has(level_id): scenes.append(BEFORE_SCENES[level_id])
	var after: String = AFTER_SCENES.get(level_id, "")
	if not after.is_empty() and state.verified_cleared.has(level_id) and _is_true(_dictionary(native_save.get("seen")).get(after)): scenes.append(after)
	return scenes

static func story_library(native_save: Dictionary, catalog: Dictionary, supported_ids = NativeLevels.SUPPORTED) -> Array:
	var state := snapshot(native_save, catalog, supported_ids)
	var seen := _dictionary(native_save.get("seen")) if state.schema_valid else {}
	var scenes: Array = []
	for world in range(1, 7):
		for suffix in ["intro", "clue", "boss", "ending"]:
			var scene := "%d-%s" % [world, suffix]
			if _is_true(seen.get(scene)) and _scene_eligible(state, scene): scenes.append(scene)
	return scenes if not scenes.is_empty() else ["1-intro"]

# Mark at playback START, including scenes the player subsequently skips (source parity).
static func record_scene_started(native_save: Dictionary, catalog: Dictionary, supported_ids, scene_id: String) -> Dictionary:
	var state := snapshot(native_save, catalog, supported_ids)
	var result := {"accepted": false, "save": native_save.duplicate(true)}
	if not state.schema_valid or not _scene_eligible(state, scene_id): return result
	var seen := _dictionary(result.save.get("seen")).duplicate(true)
	seen[scene_id] = true
	result.save.seen = seen
	result.save.schema = 1
	result.accepted = true
	return result

# bd-flow keyboard boundaries: phase >= 1, 1900ms inclusive, no active story.
static func can_continue(clear_elapsed: float, settled: bool, story_playing: bool) -> bool:
	return is_finite(clear_elapsed) and clear_elapsed >= CONTINUE_DELAY and settled and not story_playing

static func _next_route(state: Dictionary, from_level: String) -> Dictionary:
	var route := {"kind": "map", "level_id": "", "label": "Back to map", "reason": "", "world_completed": 0, "next_world": 0}
	if not from_level.is_empty():
		if not state.verified_cleared.has(from_level):
			route.reason = "unverified_origin"
			return route
		if from_level.ends_with("-6"):
			route.world_completed = int(from_level[0])
			route.next_world = route.world_completed + 1 if route.world_completed < 6 else 0
		if from_level == "6-6":
			route.kind = "credits"
			route.label = "The end"
			return route
	# First open uncleared MAIN, then source nextUp bonus fallback. Never skip an
	# unported or absent main destination to offer an unrelated supported bonus.
	var target := ""
	for bonus in [false, true]:
		for id in ORDER:
			var item: Dictionary = state.levels[id]
			if item.bonus == bonus and item.unlocked and not item.cleared:
				target = id
				break
		if not target.is_empty(): break
	if target.is_empty():
		route.reason = "all_stages_cleared"
		return route
	route.level_id = target
	route.label = "Next level"
	var item: Dictionary = state.levels[target]
	route.kind = "level" if item.playable else "blocked"
	if not item.available: route.reason = "missing_catalog"
	elif not item.supported: route.reason = "not_native_supported"
	return route

static func _scene_eligible(state: Dictionary, scene_id: String) -> bool:
	for id in BEFORE_SCENES:
		if BEFORE_SCENES[id] == scene_id: return state.levels[id].playable
	for id in AFTER_SCENES:
		if AFTER_SCENES[id] == scene_id: return state.verified_cleared.has(id)
	return false

static func _is_true(value) -> bool:
	return value is bool and value

static func _valid_schema(value: Dictionary) -> bool:
	var schema = value.get("schema", 1)
	return (schema is int or schema is float) and is_finite(float(schema)) and float(schema) == 1.0

static func _dictionary(value) -> Dictionary:
	return value if value is Dictionary else {}

static func _support_set(ids) -> Dictionary:
	var result: Dictionary = {}
	if ids is Array or ids is PackedStringArray:
		for id in ids:
			if id is String and id in ORDER: result[id] = true
	elif ids is Dictionary:
		for id in ids:
			if id is String and id in ORDER and _is_true(ids[id]): result[id] = true
	return result

static func _catalog_entries(catalog: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var seen_ids: Dictionary = {}
	var levels = catalog.get("levels", [])
	if not levels is Array: return result
	for entry in levels:
		if not entry is Dictionary: continue
		var id = entry.get("id")
		if not id is String or id not in ORDER: continue
		if seen_ids.has(id):
			result.erase(id)
			continue
		seen_ids[id] = true
		var world = entry.get("world")
		if not (world is int or world is float) or not is_finite(float(world)) or float(world) != float(int(id[0])): continue
		result[id] = entry
	return result

static func _receipt_indices(value) -> Array:
	var result: Array = []
	if not value is Array: return result
	for index in value:
		if (index is int or index is float) and is_finite(float(index)) and index >= 0 and index <= 2 and float(int(index)) == float(index) and int(index) not in result: result.append(int(index))
	result.sort()
	return result
