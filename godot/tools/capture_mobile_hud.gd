extends SceneTree
## Genuine native-renderer fixtures. Input is dispatched through Godot GUI.
## No physical phone, human playthrough or unassisted route is implied.
const Support = preload("res://tests/test_support.gd")
var output := ""
func _initialize() -> void: call_deferred("run")
func tap(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 7; event.position = root.get_screen_transform() * point; event.pressed = pressed
		Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
func capture(game, name: String) -> bool:
	game.queue_redraw(); game.player_hud.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(output.path_join(name + ".png"))
	if error != OK: printerr("PNG save failed: ", name, " ", error); return false
	print("CAPTURE ", name, " ", image.get_width(), "x", image.get_height())
	return true
func run() -> void:
	if DisplayServer.get_name() == "headless": printerr("Actual native renderer required"); quit(1); return
	var args := OS.get_cmdline_user_args()
	output = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://../docs/validation/mobile-hud-captures")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(960,540)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var game = load("res://src/main.gd").new()
	root.add_child(game); await process_frame
	Support.silence(game); game.set_physics_process(false)
	var fixtures := [
		{"name":"mobile-hud-solo-charge", "mode":"solo", "window":Vector2i(1280,720), "viewport":Vector2i(960,540), "power":"charge"},
		{"name":"mobile-hud-p2-ready", "mode":"p2", "window":Vector2i(1280,720), "viewport":Vector2i(960,540), "power":"ready"},
		{"name":"mobile-hud-cpu-active-wide", "mode":"cpu", "window":Vector2i(1170,540), "viewport":Vector2i(1170,540), "power":"active"},
		{"name":"mobile-hud-p2-phone", "mode":"p2", "window":Vector2i(844,390), "viewport":Vector2i(960,540), "power":"charge"}
	]
	for fixture in fixtures:
		root.size = fixture.window; root.content_scale_size = fixture.viewport
		await process_frame
		game._show_menu(); game.character = "jp"; game.configure_party(fixture.mode,"maya")
		game.load_level("1-1",false)
		game.safe_padding = Vector2(44,24)
		var layout = game.TouchControls.layout(game.get_viewport_rect().size,game.safe_padding,false)
		game.buttons = layout.buttons; game.dpad_rect = layout.pad
		game._layout_game_hud()
		game.elapsed = 1.2; game.score = 24; game.receipt_score = 5
		if game.party_session.active:
			var first = game.party_session.runtime.actors[0]
			var second = game.party_session.runtime.actors[1]
			first.player = Vector2(260,482); first.hearts = 3; first.coins = 7; first.abilities.meter = .5
			second.player = Vector2(450,482); second.hearts = 2; second.coins = 12
			second.power = "debit"; second.power_time = 6.1; second.abilities.meter = .75
			if fixture.power == "ready": first.abilities.meter = 1
			elif fixture.power == "active":
				first.abilities.active = "jp"; first.abilities.duration = 1.8; first.abilities.remaining = .9; first.abilities.meter = 0
			first.apply_native(game)
		else:
			game.player = Vector2(260,482); game.abilities.meter = .5
		game.player_hud.notifications.reset()
		if not await capture(game,fixture.name): game.queue_free(); quit(1); return
		# The actual touch-to-menu transition is part of native visual validation.
		await tap(game.mobile_game_menu.launcher)
		if game.mode != "paused" or not game.mobile_game_menu.opened:
			printerr("Native GUI Menu tap did not pause: ", fixture.name); game.queue_free(); quit(1); return
		if not await capture(game,fixture.name + "-menu"): game.queue_free(); quit(1); return
		await tap(game.mobile_game_menu.resume_button)
		if game.mode != "play": printerr("Native GUI Resume did not restore play"); game.queue_free(); quit(1); return
	print("PASS: 8 native captures and 8 actual menu/resume GUI taps; isolated authored fixtures, not device acceptance.")
	game.queue_free(); await process_frame; quit(0)
