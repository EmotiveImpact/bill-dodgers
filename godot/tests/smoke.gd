extends SceneTree

var failures: Array[String] = []

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		printerr("FAIL: " + description)

func _initialize() -> void:
	call_deferred("run")

func dispatch_touch(position: Vector2, pressed: bool, index: int = 0) -> void:
	# Input.parse_input_event exercises touch-to-mouse emulation and GUI dispatch.
	# It accepts window coordinates, unlike Viewport.push_input(..., true).
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = root.get_screen_transform() * position
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func tap_gui(button: Button) -> void:
	check(button != null, "Requested GUI control exists before real touch")
	if button == null: return
	# Density-aware title controls may be in a scrollable native menu. Reveal
	# the actual button before the unchanged engine-dispatched touch.
	await process_frame
	var ancestor := button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
			await process_frame
		ancestor = ancestor.get_parent()
	# The callback may free its button, so retain only its position across awaits.
	var position := button.get_global_rect().get_center()
	await dispatch_touch(position, true)
	await dispatch_touch(position, false)

func find_button(game: Node, prefix: String) -> Button:
	for child in game.ui.find_children("*", "Button", true, false):
		if child is Button and child.text.begins_with(prefix):
			return child
	return null

func run() -> void:
	# The headless100x100 placeholder is not a phone or desktop UI viewport.
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(960,540)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	check(Input.is_emulating_mouse_from_touch(), "Touch-to-mouse GUI emulation enabled")
	await tap_gui(find_button(game, "Press start"))
	await create_timer(0.5).timeout
	await tap_gui(find_button(game, "Free play"))
	await tap_gui(find_button(game, "1-1"))
	if game.story != null and game.story.playing: game.story.skip()
	check(game.mode == "play" and game.level_id == "1-1", "Dispatched touchscreen tap opens a level")
	await dispatch_touch(game.buttons.left.get_center(), true, 2)
	await dispatch_touch(game.buttons.shoot.get_center(), true, 3)
	check(game._held("left") and game._held("shoot"), "Dispatched multitouch supports move and shoot")
	check(not game.touches.has(-1), "Emulated mouse does not duplicate gameplay touches")
	await dispatch_touch(game.buttons.left.get_center(), false, 2)
	await dispatch_touch(game.buttons.shoot.get_center(), false, 3)
	check(game.touches.is_empty(), "Dispatched touch releases clear gameplay input")
	await tap_gui(find_button(game, "Menu"))
	check(game.mode == "paused", "Dispatched touchscreen tap pauses")
	await tap_gui(find_button(game, "Resume"))
	check(game.mode == "play", "Dispatched touchscreen tap resumes")
	await tap_gui(find_button(game, "Menu"))
	await tap_gui(find_button(game, "Level map"))
	check(game.mode == "menu", "Dispatched touchscreen tap returns to worlds")
	check(game.catalog.get("levels", []).size() == 42, "Catalog retains all 42 levels")
	check(game.sheets.size() == 8, "All six housemates and two robot sheets load")
	check(game.font.get_font_name() == "Silkscreen" and game.ui_font.get_font_name() == "Pixelify Sans", "Original bundled WOFF2 fonts load natively")
	check(game.font.has_char(0x00A3), "Original HUD font includes the pound sign")
	check(not game.load_level("99-1"), "Unknown level fails closed")
	for entry in game.catalog.get("levels", []):
		check(game.load_level(entry.id), "Loads %s" % entry.id)
		check(is_finite(game.player.y), "Finite spawn for %s" % entry.id)
		check(game.images.size() == game.meta.imgs.size(), "Every META image loads for %s" % entry.id)
	game.load_level("1-1")
	game.save.receipts["1-1"] = [0]
	game.load_level("1-1")
	check(not game.receipts[0].taken and game.receipts[0].previously_collected and not game.receipts[1].taken and not game.receipts[1].previously_collected and game.save.receipts["1-1"] == [0], "Replay receipts remain collectable while saved collection history is retained")
	game.step(1.0 / 60, {})
	var x: float = game.player.x
	game.step(1.0 / 60, {"right": true})
	check(is_equal_approx(game.player.x - x, 4.5), "Source movement speed preserved at 270 px/s")
	var ground: float = game.player.y
	game.step(1.0 / 60, {"jump": true})
	check(game.player.y < ground and not game.grounded, "Jump takes off")
	for i in range(90): game.step(1.0 / 60, {})
	check(game.grounded and is_equal_approx(game.player.y, ground), "Jump lands on original floor")
	game.step(1.0 / 60, {"shoot": true})
	check(game.bullets.size() == 1, "Shoots a projectile")
	for i in range(120): game.step(1.0 / 60, {})
	check(game.bullets.is_empty(), "Expired projectile removed")
	await create_timer(0.1).timeout
	game._touch(2, game.buttons.left.get_center())
	game._touch(3, game.buttons.shoot.get_center())
	check(game._held("left") and game._held("shoot"), "Simultaneous multitouch move and shoot")
	game._pause()
	check(game.touches.is_empty() and game.mode == "paused", "Pause releases all active touches")
	var paused_position: Vector2 = game.player
	game._physics_process(1)
	check(game.player == paused_position, "Pause freezes simulation")
	game._resume()
	check(game.mode == "play" and not game._held("left"), "Resume has no stuck touch")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.mode == "paused", "Background/focus loss pauses")
	game._show_menu()
	check(game.mode == "menu", "Can leave pause for world picker")
	game.load_level("6-6")
	check(game.is_native_supported() and game._native_world_six() and not game.status.contains("LAYOUT PREVIEW") and game.boss == null, "Final native stage starts fresh without fabricated boss or completion")
	check(not game.load_level("7-1") and game.level_id == "6-6", "Unknown stage cannot replace a valid runtime")
	var store = load("res://src/save_store.gd")
	var test_path := "user://test-save.json"
	check(store.write_save({"schema": 1, "receipts": {"1-1": [0]}}, test_path) == OK, "Save writes atomically")
	var restored: Array = store.read_save(test_path).receipts["1-1"]
	check(restored.size() == 1 and int(restored[0]) == 0, "Save round trip")
	var corrupt := FileAccess.open(test_path, FileAccess.WRITE)
	corrupt.store_string("broken")
	corrupt.close()
	check(store.read_save(test_path) == {"schema": 1, "receipts": {}}, "Corrupt save recovers safely")
	store.write_save({"schema": 1, "receipts": {"1-1": "broken", "1-2": [0, 0, 2, 3, -1, 0.5, "x"], "99-1": [0]}}, test_path)
	var sanitized: Dictionary = store.read_save(test_path)
	check(not sanitized.receipts.has("1-1") and not sanitized.receipts.has("99-1"), "Malformed receipt records rejected")
	check(sanitized.receipts["1-2"] == [0, 2], "Receipt indices validated and deduplicated")
	DirAccess.remove_absolute(test_path)
	await create_timer(0.1).timeout
	game.queue_free()
	await create_timer(0.1).timeout
	print("Native smoke tests: ", "PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)
