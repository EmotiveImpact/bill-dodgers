extends RefCounted
## Native-only progress. Deliberately does not overwrite the web game's bd-save.
const NativeLevels = preload("res://src/native_levels.gd")
const PATH := "user://native-preview-save.json"

static func read_save(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"schema": 1, "receipts": {}}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"schema": 1, "receipts": {}}
	var value = parser.data
	if not value is Dictionary or value.get("schema") != 1 or not value.get("receipts") is Dictionary:
		return {"schema": 1, "receipts": {}}
	var cleaned: Dictionary = {}
	var level_pattern := RegEx.new()
	level_pattern.compile("^[1-6]-[1-6S]$")
	for level_id in value.receipts:
		if not level_id is String or level_pattern.search(level_id) == null:
			continue
		var indices = value.receipts[level_id]
		if not indices is Array:
			continue
		var valid: Array = []
		for index in indices:
			if (index is int or index is float) and is_finite(float(index)) and index >= 0 and index <= 2 and float(int(index)) == float(index) and not int(index) in valid:
				valid.append(int(index))
		cleaned[level_id] = valid
	var result := {"schema": 1, "receipts": cleaned}
	if value.get("cleared") is Dictionary:
		result.cleared = {}
		for key in value.cleared:
			# Only stages with actual native progression can retain completion.
			if key is String and NativeLevels.supports(key) and value.cleared[key] == true: result.cleared[key] = true
	if value.get("skills") is Array:
		result.skills = []
		for skill in value.skills:
			if skill in ["slide", "double-jump", "ground-pound", "dash", "wall-jump", "super"] and skill not in result.skills:
				result.skills.append(skill)
	if value.get("seen") is Dictionary:
		result.seen = {}
		var scene_pattern := RegEx.new()
		scene_pattern.compile("^[1-6]-(intro|clue|boss|ending)$")
		for key in value.seen:
			if key is String and scene_pattern.search(key) != null and value.seen[key] == true: result.seen[key] = true
	if (value.get("kitty") is int or value.get("kitty") is float) and is_finite(float(value.kitty)):
		result.kitty = clampi(int(value.kitty), 0, 100000000)
	# Presentation preferences cannot grant gameplay progress or unlock a path.
	if value.get("friend") in ["jp", "maya", "ama", "leo", "theo", "mei"]:
		result.friend = value.friend
	var mode = value.get("party_mode")
	var mate = value.get("party_mate")
	var mate_valid: bool = mate in ["jp", "maya", "ama", "leo", "theo", "mei"] and mate != result.get("friend", "jp")
	if mode is String:
		if mode == "solo": result.party_mode = "solo"
		elif mode in ["cpu", "p2"] and mate_valid: result.party_mode = mode
	if mate_valid: result.party_mate = mate
	result.party_confirmed = value.get("party_confirmed") is bool and value.party_confirmed
	var map_at = value.get("map_at")
	if map_at is String and (map_at == "HOME" or level_pattern.search(map_at) != null):
		result.map_at = map_at
	if value.get("map_shown") is Array:
		result.map_shown = []
		for edge in value.map_shown:
			if (edge is int or edge is float) and is_finite(float(edge)) and float(int(edge)) == float(edge) and edge >= 0 and edge < 128 and int(edge) not in result.map_shown:
				result.map_shown.append(int(edge))
	return result

static func write_save(value: Dictionary, path: String = PATH) -> Error:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value))
	file.flush()
	file.close()
	return DirAccess.rename_absolute(temp, path)
