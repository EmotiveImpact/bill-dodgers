extends SceneTree
## Diagnostic only. Linux headless CPU/resource retention is not device GPU/FPS.
## Run through scripts/profile-native-resources.py for an isolated writable HOME.
var game
var failures := 0
var rows: Array = []

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for frame in range(4): await process_frame

func process_memory() -> Dictionary:
	var result: Dictionary = {}
	var file := FileAccess.open("/proc/self/status", FileAccess.READ)
	if file == null: return result
	# procfs reports length zero, so get_as_text() would silently read nothing.
	while not file.eof_reached():
		var line := file.get_line()
		for key in ["VmRSS", "VmHWM", "RssAnon", "RssFile"]:
			if line.begins_with(key + ":"):
				result[key + "_kib"] = int(line.substr(key.length() + 1).strip_edges().get_slice(" ", 0))
	return result

func texture_bytes(textures: Dictionary) -> int:
	# Deliberately labelled estimate: no GPU allocation is queried by headless.
	var seen: Dictionary = {}
	var total := 0
	for texture in textures.values():
		if texture is Texture2D and not seen.has(texture.get_instance_id()):
			seen[texture.get_instance_id()] = true
			total += texture.get_width() * texture.get_height() * 4
	return total

func snapshot(label: String, milliseconds: float = 0, detail: Dictionary = {}) -> void:
	var row := {"label": label, "operation_ms": milliseconds,
		"static_bytes": OS.get_static_memory_usage(), "static_peak_bytes": OS.get_static_memory_peak_usage(),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT), "nodes": get_node_count(),
		"linux_memory": process_memory()}
	if is_instance_valid(game):
		row.merge({"stage_image_count": game.images.size(), "stage_rgba8_estimate_bytes": texture_bytes(game.images),
			"sheet_count": game.sheets.size(), "sheet_rgba8_estimate_bytes": texture_bytes(game.sheets),
			"story_texture_count": game.story.textures.size(), "story_rgba8_estimate_bytes": texture_bytes(game.story.textures),
			"score_cache_count": game.audio.score_cache.size(), "effect_cache_count": game.audio.cache.size()})
	row.merge(detail)
	rows.append(row)
	print("RESOURCE_PROFILE ", JSON.stringify(row))

func references(textures: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for texture in textures.values():
		if texture is Texture2D: result[texture.resource_path] = weakref(texture)
	return result

func old_unique_retained(previous: Dictionary, current: Dictionary) -> Array:
	var current_paths: Dictionary = {}
	for texture in current.values():
		if texture is Texture2D: current_paths[texture.resource_path] = true
	var retained: Array = []
	for path in previous:
		if not current_paths.has(path) and previous[path].get_ref() != null: retained.append(path)
	return retained

func warm_story_shot(story, shot: Dictionary) -> void:
	# Dummy rendering does not certify draw execution. Explicitly request only
	# the same referenced art that StoryPlayer._draw would use for this shot.
	if shot.has("bg"): story._texture("bg-" + str(shot.bg) + ".webp")
	for actor in shot.get("actors", []) + shot.get("props", []):
		if actor.has("shape"): continue
		if actor.has("p"): story._texture("prop-" + str(actor.p) + ".png")
		elif story.data.meta.spr.has(actor.get("s", "")): story._texture("spr-" + str(actor.s) + ".webp")
		var carries = actor.get("carry", [])
		if carries is Dictionary: carries = [carries]
		for carry in carries: story._texture("prop-" + str(carry.p) + ".png")

func run() -> void:
	snapshot("engine_before_main")
	var start := Time.get_ticks_usec()
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.save = {"schema": 1, "receipts": {}, "cleared": {}, "skills": [], "friend": "jp", "party_mode": "solo"}
	game.configure_party("solo", "maya")
	var startup_ms := (Time.get_ticks_usec() - start) / 1000.0
	await settle()
	snapshot("title_ready", startup_ms)
	start = Time.get_ticks_usec()
	game._show_campaign()
	var map_ms := (Time.get_ticks_usec() - start) / 1000.0
	await settle()
	var map_refs := references(game.campaign_map.pictures)
	snapshot("map_ready", map_ms, {"map_image_count": game.campaign_map.pictures.size(), "map_rgba8_estimate_bytes": texture_bytes(game.campaign_map.pictures)})
	var previous: Dictionary = {}
	for cycle in range(2):
		for entry in game.catalog.levels:
			start = Time.get_ticks_usec()
			var loaded: bool = game.load_level(entry.id, false)
			var load_ms := (Time.get_ticks_usec() - start) / 1000.0
			await settle()
			var retained := old_unique_retained(previous, game.images)
			if not loaded or game.images.size() != game.meta.imgs.size() or not retained.is_empty(): failures += 1
			snapshot("stage_%s_cycle_%d" % [entry.id, cycle + 1], load_ms,
				{"loaded": loaded, "previous_unique_retained": retained,
				"map_unique_retained_count": old_unique_retained(map_refs, game.images).size()})
			previous = references(game.images)
	game._show_menu()
	await settle()
	snapshot("menu_after_stages", 0, {"last_stage_retained_count": old_unique_retained(previous, {}).size()})
	# This is an asset-demand sweep, not a story timing or visual acceptance test.
	for id in game.story.data.scenes:
		start = Time.get_ticks_usec()
		game.story.play(id)
		for shot in game.story.shots: warm_story_shot(game.story, shot)
		var demand_ms := (Time.get_ticks_usec() - start) / 1000.0
		game.story.stop()
		await settle()
		snapshot("story_stopped_" + id, demand_ms)
	for cue in game.audio.CUES: game.audio.score_stream(cue)
	for effect in game.audio.EFFECT_NAMES: game.audio.effect_stream(effect)
	await settle()
	snapshot("all_cues_and_effects_requested")
	game.audio.shutdown()
	game.queue_free()
	await settle()
	game = null
	snapshot("game_freed", 0, {"failures": failures})
	quit(0 if failures == 0 else 1)
