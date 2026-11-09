extends SceneTree
const Campaign = preload("res://src/campaign_progression.gd")
const NativeLevels = preload("res://src/native_levels.gd")
var checks := 0
var failures: Array[String] = []
var catalog: Dictionary
var source_map: Dictionary

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func fresh() -> Dictionary: return {"schema": 1, "receipts": {}}
func all_main_save() -> Dictionary:
	var save := fresh()
	save.cleared = {}
	for id in Campaign.ORDER:
		if not id.ends_with("-S"): save.cleared[id] = true
	return save

# Stream only MAP4's small data line; never emit or parse the giant IMG/base64 line.
func read_source_map() -> Dictionary:
	var file := FileAccess.open("res://../game/index.html", FileAccess.READ)
	if file == null: return {}
	while not file.eof_reached():
		var line := file.get_line()
		if line.begins_with("const MAP4 = "):
			file.close()
			return JSON.parse_string(line.trim_prefix("const MAP4 = ").trim_suffix(";"))
	file.close()
	return {}

func source_open(id: String, cleared: Dictionary) -> bool:
	for edge in source_map.edges:
		if (edge.a == id or edge.b == id) and (edge.need == null or cleared.has(edge.need)): return true
	return false

func source_next(cleared: Dictionary) -> String:
	for include_bonus in [false, true]:
		for id in source_map.order:
			if id == "HOME" or (not include_bonus and id.ends_with("-S")): continue
			if source_open(id, cleared) and not cleared.has(id): return id
	return ""

func verify_source_contract() -> void:
	check(not source_map.is_empty(), "Original MAP4 data readable without embedded image output")
	if source_map.is_empty(): return
	var order: Array = source_map.order.duplicate()
	order.erase("HOME")
	check(order == Campaign.ORDER, "Canonical order matches exact MAP4.order, including bonuses")
	for id in Campaign.ORDER:
		var incoming := "MISSING"
		for edge in source_map.edges:
			if edge.b == id: incoming = "" if edge.need == null else edge.need
		check(Campaign.REQUIRES[id] == incoming, "%s requirement matches authored incoming map edge" % id)
	var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/story.json"))
	for id in Campaign.ORDER:
		var file := FileAccess.open("res://../game/%s/index.html" % id, FileAccess.READ)
		var hook := ""
		var way := false
		while not file.eof_reached():
			var line := file.get_line()
			if line.begins_with("var B="): hook = line
			if line.contains("const WAY = LAST ? '../index.html#credits' : '../index.html#map&next'"): way = true
		file.close()
		var before: String = Campaign.BEFORE_SCENES.get(id, "")
		var after: String = Campaign.AFTER_SCENES.get(id, "")
		var expected := "var B=%s,A=%s;" % ['"%s"' % before if before else "null", '"%s"' % after if after else "null"]
		check(hook == expected if (before or after) else hook.is_empty(), "%s story hooks match original level" % id)
		check(way, "%s retains source Map/Next/credits hook" % id)
		if before: check(story.scenes.has(before), "%s before scene exists in imported story" % id)
		if after: check(story.scenes.has(after), "%s after scene exists in imported story" % id)

func verify_fresh_and_boundaries() -> void:
	var save := fresh()
	var state := Campaign.snapshot(save, catalog)
	check(state.playable == ["1-1"] and state.unlocked == ["1-1"], "Fresh campaign opens exactly first main level")
	check(state.native_cleared.is_empty() and state.verified_cleared.is_empty(), "Fresh save has no invented clears")
	check(state.next_route.kind == "level" and state.next_route.level_id == "1-1", "Fresh next route starts at first main")
	check(state.menu_label == "Start story" and not state.story_complete and not state.credits_unlocked, "Fresh labels and credits gating")
	check(state.worlds[0].unlocked and not state.worlds[1].unlocked and not state.worlds[0].completed, "Fresh world boundary")
	check(state.levels["1-S"].requires == "1-1" and state.levels["1-S"].receipts_required == 0, "Bonus requires actual source stage, zero receipts")
	check(Campaign.story_before_level(save, catalog, NativeLevels.SUPPORTED, "1-1") == ["1-intro"], "First entry requests intro")
	check(Campaign.story_library(save, catalog) == ["1-intro"], "Empty story library uses source first-intro fallback")
	check(Campaign.level_state(save, catalog, [], "bogus").is_empty(), "Unknown stage has no decision")
	check(Campaign.BEFORE_STORY_DELAY == 0.25 and Campaign.AFTER_CLEAR_STORY_DELAY == 2.6 and Campaign.CONTINUE_DELAY == 1.9, "Source before/after/continue timing constants")
	check(not Campaign.can_continue(1.899999, true, false), "Keyboard continuation blocked just before1900ms")
	check(Campaign.can_continue(1.9, true, false), "Keyboard continuation accepts inclusive1900ms")
	check(not Campaign.can_continue(100, false, false) and not Campaign.can_continue(100, true, true), "Settlement and active story independently gate continuation")
	check(not Campaign.can_continue(NAN, true, false) and not Campaign.can_continue(INF, true, false) and not Campaign.can_continue(-1, true, false), "Nonfinite and negative timing rejected")

func verify_full_campaign() -> void:
	var save := fresh()
	var expected_clears: Dictionary = {}
	for id in Campaign.ORDER:
		if id.ends_with("-S"): continue
		var before := JSON.stringify(save)
		var state := Campaign.snapshot(save, catalog, Campaign.ORDER)
		check(state.next_route.level_id == id and state.next_route.kind == "level", "%s is exact next normal destination" % id)
		check(state.next_route.level_id == source_next(expected_clears), "%s next selection equals original source algorithm" % id)
		for bonus_id in ["1-S", "2-S", "3-S", "4-S", "5-S", "6-S"]:
			check(state.levels[bonus_id].unlocked == source_open(bonus_id, expected_clears), "%s bonus boundary before%s matches source" % [bonus_id, id])
		var result := Campaign.record_clear(save, catalog, Campaign.ORDER, id, true, true)
		check(result.accepted and result.newly_cleared, "%s real campaign completion accepted" % id)
		check(JSON.stringify(save) == before, "%s completion is pure; original save unchanged" % id)
		check(not result.save.has("kitty") and not result.save.has("skills"), "%s progression grants no money or movement skill" % id)
		save = result.save
		expected_clears[id] = true
		state = Campaign.snapshot(save, catalog, Campaign.ORDER)
		check(state.verified_cleared == expected_clears, "%s verified prefix contains only completed main stages" % id)
		check(result.after_scenes == ([Campaign.AFTER_SCENES[id]] if Campaign.AFTER_SCENES.has(id) else []), "%s post-clear story decision" % id)
		if id.ends_with("-6"):
			var world := int(id[0])
			check(state.worlds[world - 1].completed and state.worlds[world - 1].main_cleared == 6, "%s completes exactly six main stages, bonus optional" % id)
			check(result.route.world_completed == world, "%s world-complete banner decision" % id)
			if world < 6:
				check(result.route.level_id == "%d-1" % (world + 1) and result.route.next_world == world + 1, "%s crosses bridge, skipping optional bonus" % id)
			else:
				check(result.route.kind == "credits" and result.route.label == "The end" and result.route.next_world == 0, "Final boss routes to credits, never6-S")
	check(Campaign.snapshot(save, catalog, Campaign.ORDER).menu_label == "Story complete", "Full main story label does not require bonuses")
	check(Campaign.next_route(save, catalog, Campaign.ORDER).level_id == "1-S", "Map nextUp falls back to earliest unfinished bonus after all main stages")
	check(Campaign.next_route(save, catalog, Campaign.ORDER, "1-1").level_id == "1-S", "Replaying old stage follows global unfinished order, not numeric successor")
	for id in ["1-S", "2-S", "3-S", "4-S", "5-S", "6-S"]:
		var result := Campaign.record_clear(save, catalog, Campaign.ORDER, id, true, true)
		check(result.accepted and result.after_scenes.is_empty(), "%s clears without invented bonus story" % id)
		save = result.save
	var complete := Campaign.snapshot(save, catalog, Campaign.ORDER)
	check(complete.verified_cleared.size() == 42 and complete.next_route.kind == "map" and complete.next_route.reason == "all_stages_cleared", "All42cleared returns map without loop or phantom next level")
	var replay := Campaign.record_clear(save, catalog, Campaign.ORDER, "6-6", true, true)
	check(replay.accepted and not replay.newly_cleared and replay.route.kind == "credits" and replay.after_scenes == ["6-ending"], "Final replay retains ending and credits without new progress")

func verify_native_boundary_and_forgery() -> void:
	var save := all_main_save()
	var before := JSON.stringify(save)
	var state := Campaign.snapshot(save, catalog, NativeLevels.WORLD_ONE + NativeLevels.WORLD_TWO)
	check(state.verified_cleared.size() == 12 and not state.story_complete and not state.credits_unlocked, "Forged preview clears do not finish native story")
	check(state.levels["3-1"].unlocked and not state.levels["3-1"].playable and state.levels["3-1"].status == "preview", "World3path can open but remains an explicit native preview boundary")
	var route := Campaign.next_route(save, catalog, NativeLevels.WORLD_ONE + NativeLevels.WORLD_TWO, "2-6")
	check(route.kind == "blocked" and route.level_id == "3-1" and route.reason == "not_native_supported" and route.world_completed == 2, "After checkout returns exact blocked3-1, not bonus or credits")
	check(Campaign.next_route(save, catalog, NativeLevels.WORLD_ONE + NativeLevels.WORLD_TWO, "6-6").reason == "unverified_origin", "Forged final origin cannot enter credits")
	check(JSON.stringify(save) == before, "Snapshot never deletes existing save contents")
	var no_second := Campaign.ORDER.duplicate()
	no_second.erase("1-2")
	state = Campaign.snapshot(save, catalog, no_second)
	check(state.verified_cleared.keys() == ["1-1"] and state.next_route.level_id == "1-2" and state.next_route.kind == "blocked", "Support hole invalidates dependent clear chain without skipping destination")
	var orphan := {"schema": 1, "cleared": {"1-6": true, "2-6": true, "6-6": true}, "preview": true, "freeplay": true, "shown4": {"all": true}, "last": "6-6"}
	state = Campaign.snapshot(orphan, catalog)
	check(state.playable == ["1-1"] and state.verified_cleared.is_empty(), "Preview/freeplay/last flags and orphan boss clears cannot bypass campaign")
	check(state.native_cleared.has("1-6") and state.levels["1-6"].native_cleared, "Legitimate out-of-order native clear remains visible as such")
	var result := Campaign.record_clear(orphan, catalog, NativeLevels.WORLD_ONE + NativeLevels.WORLD_TWO, "1-1", true, true)
	check(result.accepted and result.save.cleared["1-6"] and result.save.cleared["2-6"], "Recording campaign progress preserves existing development stage clears")
	for bad in [1, 1.0, "true", [], {}, null, false]:
		state = Campaign.snapshot({"cleared": {"1-1": bad}}, catalog)
		check(state.verified_cleared.is_empty(), "Only actual boolean true is a native clear: %s" % str(bad))
	for bad_schema in [true, false, "1", 0, 2, null, NAN, INF]:
		state = Campaign.snapshot({"schema": bad_schema, "cleared": {"1-1": true}}, catalog)
		check(not state.schema_valid and state.verified_cleared.is_empty(), "Bad schema cannot grant progress: %s" % str(bad_schema))
	check(Campaign.snapshot({"schema": 1.0, "cleared": {"1-1": true}}, catalog).verified_cleared.has("1-1"), "JSON numeric1schema accepted")
	for bad_clears in [[], 1, "all", null]:
		check(Campaign.snapshot({"cleared": bad_clears}, catalog).verified_cleared.is_empty(), "Malformed clears container handled safely")
	var odd := {"cleared": {"1-1": true, "HOME": true, "1-EXIT": true, "2-ENTRY": true, "7-1": true, "1-s": true, "1-7": true, "1-01": true, 1: true}}
	check(Campaign.snapshot(odd, catalog).native_cleared.keys() == ["1-1"], "Unknown ids, gates, wrong case and numeric keys ignored")
	state = Campaign.snapshot(fresh(), catalog, {"1-1": 1, "1-2": true, "garbage": true})
	check(not state.levels["1-1"].supported and state.next_route.kind == "blocked", "Support dictionary requires actualtrueand ignores unknowns")
	check(Campaign.snapshot(fresh(), catalog, PackedStringArray(["1-1"])).playable == ["1-1"], "PackedStringArray support set accepted")
	for bad_support in [null, true, "1-1"]:
		check(Campaign.snapshot(fresh(), catalog, bad_support).playable.is_empty(), "Malformed support set fails closed")
	var bad_catalog := catalog.duplicate(true)
	bad_catalog.levels.reverse()
	check(Campaign.snapshot(fresh(), bad_catalog).next_route.level_id == "1-1", "Catalog ordering cannot rewrite source order")
	bad_catalog.levels = bad_catalog.levels.filter(func(item): return item.id != "1-1")
	state = Campaign.snapshot(save, bad_catalog, Campaign.ORDER)
	check(state.verified_cleared.is_empty() and state.next_route.reason == "missing_catalog" and state.next_route.level_id == "1-1", "Absent catalog root blocks chain and preserves destination")
	bad_catalog = catalog.duplicate(true)
	bad_catalog.levels.append(bad_catalog.levels[0].duplicate(true))
	check(not Campaign.snapshot(fresh(), bad_catalog).levels["1-1"].available, "Duplicate catalog ids fail closed")
	bad_catalog.levels[0].world = 2
	check(not Campaign.snapshot(fresh(), bad_catalog).levels["1-1"].available, "Conflicting duplicate remains rejected even when first row is invalid")
	bad_catalog.levels.append(catalog.levels[0].duplicate(true))
	check(not Campaign.snapshot(fresh(), bad_catalog).levels["1-1"].available, "Third duplicate cannot resurrect a rejected id")
	for bad_world in [true, "1", 1.5, 2, NAN, INF]:
		bad_catalog = catalog.duplicate(true)
		bad_catalog.levels[0].world = bad_world
		check(not Campaign.snapshot(fresh(), bad_catalog).levels["1-1"].available, "Catalog world must match exact canonical id")
	for bad_levels in [null, {}, "all"]:
		check(Campaign.snapshot(fresh(), {"levels": bad_levels}).next_route.reason == "missing_catalog", "Malformed catalog fails closed")

func verify_recording_receipts_and_story() -> void:
	var save := fresh()
	for args in [["1-1", false, true, "objective_not_completed"], ["1-1", true, false, "not_campaign_run"], ["1-6", true, true, "locked"], ["4-1", true, true, "locked"], ["unknown", true, true, "unknown_level"]]:
		var result := Campaign.record_clear(save, catalog, NativeLevels.SUPPORTED, args[0], args[1], args[2])
		check(not result.accepted and result.reason == args[3] and result.save == save, "Rejected completion is pure: %s" % args[3])
	check(not Campaign.record_clear(save, catalog, NativeLevels.SUPPORTED, "1-1").accepted, "Completion API defaults to no authority")
	check(Campaign.record_clear({"schema": 2}, catalog, NativeLevels.SUPPORTED, "1-1", true, true).reason == "invalid_schema", "Malformed schema cannot receive a completion")
	check(Campaign.record_clear(save, {}, NativeLevels.SUPPORTED, "1-1", true, true).reason == "missing_catalog", "Missing catalog cannot receive a completion")
	var before_save := JSON.stringify(save)
	var before_catalog := JSON.stringify(catalog)
	var isolated := Campaign.record_clear(save, catalog, NativeLevels.SUPPORTED, "1-1", true, true)
	isolated.save.receipts["1-1"] = [2]
	isolated.save.cleared["1-2"] = true
	check(JSON.stringify(save) == before_save and JSON.stringify(catalog) == before_catalog, "Returned nested save mutation cannot alias caller state or catalog")
	var receipts := {"schema": 1, "receipts": {"1-1": [0, 1.0, 2, 2, -1, 3, 0.5, true, false, "0", NAN, INF], "1-S": [2], "2-1": "all", "4-1": [0, 1, 2], "7-1": [0]}}
	var state := Campaign.snapshot(receipts, catalog, NativeLevels.WORLD_ONE + NativeLevels.WORLD_TWO)
	check(state.receipts["1-1"] == [0, 1, 2] and state.receipt_count == 4 and not state.receipts.has("4-1"), "Receipt ids sanitized to native uniquezero-basedfinite indices on supported stages")
	check(state.playable == ["1-1"], "Collecting all receipts cannot unlock a path")
	var result := Campaign.record_clear(save, catalog, NativeLevels.SUPPORTED, "1-1", true, true)
	save = result.save
	state = Campaign.snapshot(save, catalog)
	check(state.levels["1-S"].playable and state.receipt_count == 0 and state.levels["1-1"].play_label == "Play again", "First bonus opens at exact clear boundary with zero receipts")
	check(state.next_route.level_id == "1-2", "Optional bonus never interrupts main progression")
	var all_save := all_main_save()
	all_save.seen = {}
	for world in range(1, 7):
		for kind in ["intro", "clue", "boss"]: all_save.seen["%d-%s" % [world, kind]] = true
	all_save.seen["6-ending"] = true
	all_save.seen["1-ending"] = true
	all_save.seen["title"] = true
	for id in Campaign.ORDER:
		var before_scene: String = Campaign.BEFORE_SCENES.get(id, "")
		var after_scene: String = Campaign.AFTER_SCENES.get(id, "")
		check(Campaign.story_before_level(all_save, catalog, Campaign.ORDER, id).is_empty(), "%s seen before-scenes do not auto-replay" % id)
		check(Campaign.story_after_clear(all_save, catalog, Campaign.ORDER, id) == ([after_scene] if after_scene else []), "%s seen post-clear scenes still replay" % id)
		var replay: Array = []
		if before_scene: replay.append(before_scene)
		if after_scene: replay.append(after_scene)
		check(Campaign.story_replay_for_level(all_save, catalog, Campaign.ORDER, id) == replay, "%s level Story button follows B then seenAorder" % id)
	var library := Campaign.story_library(all_save, catalog, Campaign.ORDER)
	check(library.size() == 19 and library.slice(0, 3) == ["1-intro", "1-clue", "1-boss"] and library.back() == "6-ending", "Story library matches imported world order, excluding title and fake endings")
	check(Campaign.story_library(all_save, catalog, NativeLevels.WORLD_ONE + NativeLevels.WORLD_TWO).size() == 6, "Forged preview seen flags cannot reveal later campaign library scenes")
	check(Campaign.story_before_level({"seen": {"1-intro": 1}}, catalog, NativeLevels.SUPPORTED, "1-1") == ["1-intro"], "Truthy forged seen flag does not suppress intro")
	check(Campaign.story_before_level(fresh(), catalog, NativeLevels.SUPPORTED, "1-6").is_empty(), "Locked boss cannot trigger automatic boss scene")
	check(Campaign.story_after_clear(fresh(), catalog, NativeLevels.SUPPORTED, "1-3").is_empty(), "Clue requires a verified clear")
	check(Campaign.story_replay_for_level(fresh(), catalog, NativeLevels.SUPPORTED, "1-1") == ["1-intro"], "Active level Story button offers before-scene even unseen")
	var started := Campaign.record_scene_started(fresh(), catalog, NativeLevels.SUPPORTED, "1-intro")
	check(started.accepted and started.save.schema == 1 and started.save.seen["1-intro"] and Campaign.story_before_level(started.save, catalog, NativeLevels.SUPPORTED, "1-1").is_empty(), "Scene marked seen on start, including subsequent skip")
	for id in ["1-boss", "1-clue", "6-ending", "title", "1-ending", "garbage"]:
		check(not Campaign.record_scene_started(fresh(), catalog, NativeLevels.SUPPORTED, id).accepted, "Ineligible or noncampaign scene cannot be marked:%s" % id)

func run() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://content/catalog.json"))
	source_map = read_source_map()
	verify_source_contract()
	verify_fresh_and_boundaries()
	verify_full_campaign()
	verify_native_boundary_and_forgery()
	verify_recording_receipts_and_story()
	if failures.is_empty(): print("Campaign progression: %d checks passed; source route/story parity, native support boundaries, strict save handling and pure completion." % checks)
	else: printerr("Campaign progression: %d/%d checks failed." % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
