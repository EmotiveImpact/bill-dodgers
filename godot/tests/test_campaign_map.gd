extends SceneTree
const Map = preload("res://src/campaign_map.gd")
const Support = preload("res://tests/test_support.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("FAIL: ", label)
func run() -> void:
	var game = load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	Support.silence(game); game.set_physics_process(false)
	game.save = {"schema":1,"receipts":{},"cleared":{},"seen":{},"skills":[],"kitty":0}
	game._show_menu(); game._clear_ui()
	var map = Map.new(); check(map.configure(game), "Original portable MAP4 data exists"); game.ui.add_child(map); map.set_process(false)
	check(map.map.islands.size() == 6 and map.state.levels.size() == 42, "Six original paintings and 42 stage states")
	check(map.pictures.size() == 18, "All eighteen original map/sprite textures resolve")
	check(map.is_open("1-1") and not map.is_open("1-2") and not map.world_open(2), "Fresh map preserves campaign locks")
	check(not map.route_to("1-1").is_empty() and map.route_to("2-1").is_empty(), "Graph routes respect locked bridges")
	var before: Dictionary = game.save.duplicate(true)
	map.go_to("1-1"); check(not map.route.is_empty(), "Selecting first stage starts source walker path")
	for index in 200: map.tick(0.02)
	check(map.at == "1-1" and map.route.is_empty() and map.selected == "1-1" and map.card.visible, "Walker arrives and stage card opens")
	check(map.card_title.text.contains("Doorstep dash") and not map.play_button.disabled, "Source stage name and guarded Play")
	map.show_card("1-2"); check(map.play_button.disabled and map.card_copy.text.contains("1-1"), "Locked stage explains actual prerequisite")
	map._play_selected(); check(game.mode == "menu", "Locked card never starts a level")
	map.close_card(); map.set_wide(true); map.tick(1)
	check(is_equal_approx(map.zoom_target, map.fit_zoom), "Whole-map zoom uses source map dimensions")
	map._pointer_down(1,Vector2(100,100)); map._pointer_move(1,Vector2(170,130)); check(map.drag_moved and map.look.length() > 0, "One-finger drag pans")
	map._pointer_down(2,Vector2(240,130)); map._pointer_move(2,Vector2(320,130)); check(map.zoom > map.fit_zoom, "Two-finger pinch zooms")
	map._pointer_up(1,Vector2(170,130)); map._pointer_up(2,Vector2(320,130)); check(map.contacts.is_empty() and map.selected.is_empty(), "Pinch release cannot activate a stop")
	map._pointer_down(3,Vector2(100,100)); map._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT); check(map.contacts.is_empty() and map.suspended, "Focus loss cancels contacts and animation")
	var old_time: float = map.time; map.tick(1); check(map.time == old_time, "Suspended map does not advance")
	map._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(before.cleared == game.save.cleared and before.receipts == game.save.receipts and before.skills == game.save.skills and before.kitty == game.save.kitty and before.seen == game.save.seen, "Navigation never grants campaign progress, skills or rewards")
	check(game.save.map_at == "1-1" and game.save.friend == game.character and not game.save.map_shown.is_empty(), "Only presentation location, cast and shown paths persist")
	map.queue_free(); await process_frame
	for world in 6:
		for stage in 6: game.save.cleared["%d-%d" % [world + 1,stage + 1]] = true
	game.level_id = "1-6"
	map = Map.new(); map.configure(game,"2-1"); game.ui.add_child(map); map.set_process(false)
	check(map.world_open(6) and not map.route_to("6-6").is_empty(), "Full verified chain opens all original island routes")
	check(not map.reveal_queue.is_empty() and map.auto_target == "2-1", "Boss handoff reveals authored edges before automatic walk")
	for index in 800: map.tick(0.02)
	check(map.at == "2-1" and map.selected == "2-1", "Boss bridge handoff arrives at next main stage")
	map.go_to("6-6",true); check(map.at == "6-6" and map.route.is_empty(), "Source long-distance return uses bounded hop")
	map._show_stages(6); check(map.stage_buttons.size() == 7 and not map.stage_buttons["6-6"].disabled, "Accessible native world/stage picker follows same locks")
	map.queue_redraw(); await process_frame
	map.queue_free(); await process_frame
	game.save = preload("res://src/save_store.gd").read_save()
	map = Map.new(); map.configure(game); game.ui.add_child(map); map.set_process(false)
	check(map.at == "6-6" and map.reveal_queue.is_empty(), "Disk reload restores valid walker position without replaying shown paths")
	map.queue_free(); await process_frame
	game.save = {"schema":1,"receipts":{},"cleared":{},"skills":[],"seen":{},"kitty":0,"map_at":"6-6","map_shown":[0,1,127,-1,2.5,"2"]}
	game.level_id = ""
	map = Map.new(); map.configure(game); game.ui.add_child(map); map.set_process(false)
	check(map.at == "HOME" and not map.world_open(6) and map.route_to("6-6").is_empty(), "Forged presentation location cannot open a campaign path")
	check(map.stored_shown.keys() == [0] and map.shown.keys() == [0], "Malformed, out-of-range and locked reveal IDs are ignored")
	game.queue_free(); await process_frame
	print("Native painted map: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
