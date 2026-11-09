extends SceneTree
## Independent interruption/input fixtures. Not device or difficulty certification.
const Support = preload("res://tests/test_support.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)

func button(game, prefix: String) -> Button:
	return find_button(game.ui, prefix)

func find_button(node: Node, prefix: String) -> Button:
	for child in node.get_children():
		if child is Button and child.is_visible_in_tree() and child.text.begins_with(prefix): return child
		var found := find_button(child, prefix)
		if found != null: return found
	return null

func touch(point: Vector2, pressed: bool, index: int = 1, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = root.get_screen_transform() * point
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func drag(point: Vector2, index: int = 1) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = root.get_screen_transform() * point
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_screen_transform() * point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func mouse_drag(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_screen_transform() * point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func tap(control: Button) -> void:
	var point := control.get_global_rect().get_center()
	await touch(point, true, 7)
	await touch(point, false, 7)

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	Support.silence(game)
	await process_frame
	check(not quit_on_go_back, "Engine automatic Back exit disabled before game starts")
	game.save = {"schema": 1, "receipts": {}, "cleared": {}, "seen": {}, "skills": [], "kitty": 0}
	game.load_level("1-1")
	await touch(game.buttons.left.get_center(), true)
	check(game._held("left"), "Dispatched touch starts movement")
	await drag(game.mobile_game_menu.launcher.get_global_rect().get_center())
	check(not game._held("left"), "Dragging a gameplay touch onto GUI releases its former action")
	await touch(game.mobile_game_menu.launcher.get_global_rect().get_center(), false)
	check(game.touches.is_empty(), "Releasing a gameplay touch over GUI leaves no held action")
	await touch(game.buttons.shoot.get_center(), true, 2)
	check(game._held("shoot"), "Second touch starts firing")
	await touch(game.mobile_game_menu.launcher.get_global_rect().get_center(), false, 2)
	check(game.touches.is_empty(), "Release without intermediate drag over GUI leaves no held action")
	await touch(game.buttons.right.get_center(), true, 3)
	await touch(game.mobile_game_menu.launcher.get_global_rect().get_center(), false, 3, true)
	check(game.touches.is_empty(), "Canceled gameplay touch over GUI leaves no held action")
	# Crossing native GUI must not steal another finger or trigger that button.
	var sound_before: bool = game.audio.enabled
	await touch(game.buttons.left.get_center(), true, 4)
	await touch(game.buttons.shoot.get_center(), true, 5)
	await drag(game.mobile_game_menu.launcher.get_global_rect().get_center(), 4)
	check(not game._held("left") and game._held("shoot"), "GUI-crossing drag releases only its own finger")
	await touch(game.mobile_game_menu.launcher.get_global_rect().get_center(), false, 4)
	await touch(game.buttons.shoot.get_center(), false, 5)
	check(game.touches.is_empty() and game.audio.enabled == sound_before, "Crossing GUI cannot activate an unpressed HUD button")
	await tap(game.mobile_game_menu.launcher)
	check(game.mode == "paused" and game.touches.is_empty(), "Ordinary HUD touch opens the consolidated menu exactly once")
	await tap(button(game, "Sound"))
	check(game.audio.enabled != sound_before and game.mode == "paused", "Menu Sound touch toggles once without resuming")
	await tap(button(game, "Resume"))
	check(game.mode == "play" and game.touches.is_empty(), "Menu Resume returns with neutral gameplay input")
	await mouse(game.buttons.right.get_center(), true)
	check(game._held("right"), "Real mouse starts a gameplay pad")
	await mouse_drag(game.mobile_game_menu.launcher.get_global_rect().get_center())
	check(not game._held("right"), "Mouse drag onto GUI also releases its gameplay action")
	await mouse(game.mobile_game_menu.launcher.get_global_rect().get_center(), false)
	check(game.touches.is_empty(), "Mouse release over GUI leaves no held action")

	# Godot keeps the 960x540 playfield letterboxed, rather than changing source
	# camera geometry. Dispatch window-coordinate input through each transform.
	var original_size: Vector2i = root.size
	for window_size in [Vector2i(2340,1080), Vector2i(1440,1080), Vector2i(1080,1920), Vector2i(1280,720)]:
		root.size = window_size
		await process_frame
		game._resize()
		check(root.get_visible_rect().size.is_equal_approx(Vector2(960,540)), "Fixed logical playfield at %s" % window_size)
		check(game.view_width() == roundf(960.0/game.ZOOM), "Source camera width retained at %s" % window_size)
		for action in game.buttons:
			var rect: Rect2 = game.buttons[action]
			check(root.get_visible_rect().encloses(rect), "%s touch rect remains in logical viewport at %s" % [action, window_size])
			await touch(rect.get_center(), true, 6)
			check(game.touches.get(6, "") == action, "%s transformed touch maps to its visible pad at %s" % [action, window_size])
			await touch(rect.get_center(), false, 6)
		check(game.touches.is_empty(), "Aspect-change sequence releases all input at %s" % window_size)
	root.size = original_size
	await process_frame
	game._resize()

	# Back notifications can now reach the game without engine automatic quit.
	await touch(game.buttons.right.get_center(), true, 8)
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(game.mode == "paused" and game.touches.is_empty(), "Android Back notification pauses and clears contacts")
	var before_pause: Vector2 = game.player
	game._physics_process(1.0)
	check(game.player == before_pause, "Back-paused simulation cannot advance")
	await touch(game.buttons.right.get_center(), false, 8)
	await tap(button(game, "Resume"))
	check(game.mode == "play" and game.touches.is_empty(), "Real touch resumes after Back without stale movement")
	game._open_story("1-intro")
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(game.mode == "paused" and game.story.paused and not game.story.visible, "Back also pauses and hides a live story")
	await tap(button(game, "Resume"))
	check(game.mode == "story" and game.story.playing and not game.story.paused, "Real touch resumes the paused story")
	game.story.skip()
	check(game.mode == "play" and game.ui.visible, "Resumed story skip returns to gameplay")

	# A repeated carried-surface reload must not retain an old camera/player.
	for id in ["3-5", "3-3", "1-2", "2-3", "3-4", "1-3", "3-5"]:
		check(game.load_level(id), "Repeated mixed-stage load succeeds for %s" % id)
		var spawn: Vector2 = game.player
		var spawn_camera: Vector2 = game.camera
		game.step(1.0/60.0, {"right": true})
		game._pause()
		check(game.load_level(id), "Fresh load can replace paused %s" % id)
		check(game.mode == "play" and game.player == spawn and game.camera == spawn_camera and game.velocity == Vector2.ZERO and game.grounded, "Fresh load restores exact initial surface/camera for %s" % id)
		game.hearts = 0
		game._game_over()
		var over_position: Vector2 = game.player
		await tap(button(game, "Continue"))
		check(game.mode == "play" and game.hearts == 3 and game.player == over_position and game.camera == spawn_camera, "Continue retains encounter position/camera for %s" % id)

	# Explicit clear fixture checks accounting, not genuine stage completion.
	for world in range(1, 3):
		for stage in range(1, 7): game.save.cleared["%d-%d" % [world, stage]] = true
	game.save.cleared["3-1"] = true
	game.save.cleared["3-2"] = true
	game.load_level("3-3")
	game.campaign_run = true
	game.coins.clear()
	game.score = 17
	game._complete_level()
	var banked: int = game.save.kitty
	check(game.mode == "story" and game._story_return_mode == "clear" and banked == 17, "Clue begins only after one-time clear banking")
	game._complete_level()
	game._settle_up()
	game._campaign_next()
	check(game.mode == "story" and game.save.kitty == banked, "Repeated stale clear callbacks cannot skip clue or bank twice")
	game.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await tap(button(game, "Resume"))
	game.story.skip()
	game._complete_level()
	check(game.mode == "clear" and game.save.kitty == banked, "Clue Back/resume/skip retains clear mode and the original bank")
	game._settle_up()
	await tap(button(game, "Back to worlds"))
	check(game.mode == "menu" and game.campaign_view and game.save.kitty == banked, "Real settlement navigation preserves campaign context/accounting")
	game.audio.shutdown()
	game.queue_free()
	await create_timer(0.1).timeout
	print("Native independent audit: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
