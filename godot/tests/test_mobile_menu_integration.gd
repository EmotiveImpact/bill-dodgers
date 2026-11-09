extends SceneTree
## Real main, GUI-dispatched touchscreen events and lifecycle interruptions.
## These fixtures are not human playthroughs or physical-device certification.
const Support = preload("res://tests/test_support.gd")
const Menu = preload("res://src/mobile_game_menu.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)
func touch(point: Vector2, pressed: bool, index := 8) -> void:
	var event := InputEventScreenTouch.new()
	event.position = root.get_screen_transform() * point
	event.pressed = pressed
	event.index = index
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
func tap(control: Control) -> void:
	var center := control.get_global_rect().get_center()
	await touch(center, true)
	await touch(center, false)
func escape() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_ESCAPE
		event.keycode = KEY_ESCAPE
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
func run() -> void:
	var game = load("res://src/main.gd").new()
	root.add_child(game)
	await process_frame
	Support.silence(game)
	game.set_physics_process(false)
	for viewport in [Vector2(960,540),Vector2(1170,540),Vector2(844,390)]:
		root.size = Vector2i(viewport)
		root.content_scale_size = Vector2i(viewport)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		await process_frame
		for party_mode in ["solo","p2","cpu"]:
			game._show_menu()
			game.character = "jp"
			check(game.configure_party(party_mode,"maya"), "fixture party configured %s" % party_mode)
			check(game.load_level("1-1",false), "real gameplay loaded")
			game.safe_padding = Vector2(44,24)
			game._resize(false)
			game.safe_padding = Vector2(44,24)
			game._layout_game_hud()
			var menu = game.mobile_game_menu
			await process_frame
			check(game.hud_controls.size() == 1 and game.hud_controls[0] == menu.launcher, "only one in-game menu control")
			check(menu.launcher.get_global_rect().position.y > 69, "menu stays below both player health/power blocks")
			check(not menu.get_children().any(func(c): return c is OptionButton), "no gameplay character selection")
			for action in ["jump","shoot","special"]:
				var edge: Vector2 = game.buttons[action].end - Vector2(0.5,0.5)
				await touch(edge,true,4)
				check(game._held(action), "graphical %s retains rectangular edge hitbox" % action)
				await touch(edge,false,4)
				check(not game._held(action), "graphical action edge lift releases")
			await touch(game.buttons.left.get_center(),true,1)
			await touch(game.buttons.shoot.get_center(),true,2)
			check(game._held("left") and game._held("shoot"), "real multitouch gameplay before menu")
			var position: Vector2 = game.player
			var elapsed: float = game.elapsed
			await tap(menu.launcher)
			check(game.mode == "paused" and menu.opened and game.audio.paused, "menu tap pauses simulation and audio")
			check(game.touches.is_empty() and game.gameplay_contacts.is_empty() and game.joystick_contacts.is_empty(), "opening clears every held contact")
			game._physics_process(1)
			check(game.player == position and game.elapsed == elapsed, "pause prevents a real physics step")
			await touch(game.buttons.left.get_center(),false,1)
			await touch(game.buttons.shoot.get_center(),false,2)
			var enabled: bool = game.audio.enabled
			await tap(menu.sound_button)
			check(game.audio.enabled != enabled and game.mode == "paused" and game.audio.paused, "sound toggles without resuming")
			game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
			check(game.mode == "paused" and menu.opened, "focus return never resumes an open menu")
			await tap(menu.resume_button)
			check(game.mode == "play" and not menu.opened and not game.audio.paused, "Resume explicitly restores play")
			check(game.touches.is_empty() and game.character == "jp" and game.party_session.runtime.mode == party_mode, "resume preserves roster with neutral input")
			await escape()
			check(game.mode == "paused" and menu.opened, "Escape opens same pause panel")
			await escape()
			check(game.mode == "play" and not menu.opened, "Escape closes same panel once")
			await tap(menu.launcher)
			await tap(menu.story_button)
			check(game.mode == "story" and game.story.playing and game._story_return_mode == "play" and game.audio.paused, "story enters atomically from menu with correct return mode")
			game._game_menu_action("resume")
			check(game.mode == "story", "stale menu resume cannot bypass story")
			game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			check(game.mode == "paused" and game._paused_mode == "story" and menu.story_button.disabled, "focus loss during story uses safe paused-story context")
			game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
			check(game.mode == "paused", "focus gain requires explicit story resume")
			await tap(menu.resume_button)
			check(game.mode == "story" and game.story.playing and game.audio.paused, "resume returns to story, not gameplay")
			game.story.skip()
			check(game.mode == "play" and not menu.opened and not game.audio.paused, "finished replay restores gameplay without stale pause shade")
			await tap(menu.launcher)
			await tap(menu.map_button)
			check(game.mode == "menu" and not is_instance_valid(game.mobile_game_menu) and not game.party_session.active, "Level map tears down menu and active run")
			game._game_menu_action("resume")
			check(game.mode == "menu", "stale resume cannot reopen exited run")
	# Story launched outside gameplay still pauses safely and creates no stray launcher.
	game._show_menu()
	game._open_story("1-intro")
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(game.mode == "paused" and game.mobile_game_menu.opened, "menu-origin story supports pause")
	await tap(game.mobile_game_menu.resume_button)
	check(game.mode == "story" and not game.mobile_game_menu.launcher.visible, "menu-origin story creates no gameplay launcher")
	game.story.skip()
	check(game.mode == "menu" and not game.mobile_game_menu.launcher.visible, "menu-origin story returns without gameplay controls")
	game.queue_free()
	await process_frame
	if failures.is_empty(): print("Mobile menu real-main integration: %d checks passed." % checks); quit(0)
	else: printerr("Mobile menu integration failed: %d/%d" % [failures.size(),checks]); quit(1)
