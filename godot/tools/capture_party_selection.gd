extends SceneTree
## Actual native-renderer capture. The companion/level behavior is verified by
## test_party_selection.gd; these screenshots document visual layout only.
const Support = preload("res://tests/test_support.gd")
var output := ""
func _initialize() -> void: call_deferred("run")
func tap(control: Button) -> void:
	for pressed in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 19; event.position = root.get_screen_transform() * control.get_global_rect().get_center(); event.pressed = pressed
		Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
func capture(filename: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(output.path_join(filename + ".png")) != OK:
		printerr("Capture failed: ", filename); quit(1)
func button(parent: Node, prefix: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text.begins_with(prefix): return child
	return null
func run() -> void:
	if DisplayServer.get_name() == "headless": printerr("Actual renderer required"); quit(1); return
	root.size = Vector2i(1280,720); root.content_scale_size = Vector2i(960,540); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var args := OS.get_cmdline_user_args()
	output = args[0] if not args.is_empty() else "/tmp/bd-party-captures"
	DirAccess.make_dir_recursive_absolute(output)
	var game = load("res://main.tscn").instantiate(); root.add_child(game); game.set_physics_process(false)
	Support.silence(game); await process_frame
	game.save = {"schema":1,"receipts":{},"cleared":{},"seen":{},"skills":[],"kitty":0}
	game._show_campaign(); var map = game.campaign_map; map.set_process(false); map.tick(2)
	await tap(map.friend_button); await capture("native-official-character-p1")
	await tap(map.friend_panel.choices.theo); await capture("native-official-character-mate")
	await tap(map.friend_panel.choices.mei); await capture("native-official-character-cpu-ready")
	await tap(map.friend_panel.mode_button); await capture("native-official-character-local-p2")
	await tap(map.friend_panel.start_button); await capture("native-official-map-return")
	game.queue_free(); await process_frame
	print("Native party/map rendered captures: ",output); quit(0)
