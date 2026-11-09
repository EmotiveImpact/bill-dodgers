extends SceneTree
const Map = preload("res://src/campaign_map.gd")
const Title = preload("res://src/title_menu.gd")
const Support = preload("res://tests/test_support.gd")
var output := ""
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output.path_join(name + ".png"))
	if error != OK: printerr("Capture failed: ", name); quit(1)
func run() -> void:
	if DisplayServer.get_name() == "headless": printerr("Actual renderer required"); quit(1); return
	root.size = Vector2i(1280, 720); root.content_scale_size = Vector2i(960,540); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var args := OS.get_cmdline_user_args(); output = args[0] if not args.is_empty() else "/tmp/bd-map-captures"
	DirAccess.make_dir_recursive_absolute(output)
	var game = load("res://main.tscn").instantiate(); root.add_child(game); await process_frame; Support.silence(game); game.set_physics_process(false)
	game.save = {"schema":1,"receipts":{},"cleared":{},"seen":{},"skills":[],"kitty":0}; game.level_id = ""
	game._show_menu(); game._clear_ui()
	var title = Title.new(); title.configure(game); game.ui.add_child(title); title.set_process(false)
	await capture("native-title-press"); title.show_page("menu"); await capture("native-title-menu")
	title.show_page("press"); title.start_attract(); title.attract._process(1.2); await capture("native-title-attract"); title.end_attract(); title.show_page("help"); await capture("native-title-help")
	title.queue_free(); await process_frame
	var map = Map.new(); map.configure(game); game.ui.add_child(map); map.set_process(false)
	map.tick(2); await capture("native-map-home"); map.go_to("1-1"); map.tick(2); await capture("native-map-first-card")
	map.close_card(); map.set_wide(true); map.tick(2); await capture("native-map-locked-overview")
	map._show_friends(); await capture("native-map-housemates")
	map.queue_free(); await process_frame
	for world in 6:
		for stage in 6: game.save.cleared["%d-%d" % [world + 1,stage + 1]] = true
	game.level_id = "1-6"
	map = Map.new(); map.configure(game,"2-1"); game.ui.add_child(map); map.set_process(false)
	for index in 150: map.tick(0.02)
	await capture("native-map-bridge-opening")
	for index in 600: map.tick(0.02)
	await capture("native-map-world-two-card")
	map.close_card(); map.set_wide(true); map.tick(2); await capture("native-map-unlocked-overview")
	map.queue_free(); await process_frame
	title = Title.new(); title.configure(game,true); game.ui.add_child(title); title.set_process(false)
	await capture("native-title-complete-menu"); title.show_page("reset"); await capture("native-title-reset")
	game.queue_free(); await process_frame
	print("Native title/map rendered captures: ", output); quit(0)
