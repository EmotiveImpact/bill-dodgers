extends SceneTree
## Actual canvas stretch and native cancellation; no device-dp claim.
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if not value: failures.append(label); printerr("FAIL: ", label)
func contact(menu, point: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = root.get_screen_transform() * point
	event.index = 9
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
func run() -> void:
	var game = load("res://src/main.gd").new()
	root.add_child(game)
	await process_frame
	preload("res://tests/test_support.gd").silence(game)
	game.set_physics_process(false)
	for fixture in [Vector2i(568,320), Vector2i(844,390), Vector2i(1280,720)]:
		root.content_scale_size = Vector2i(960,540)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		root.size = fixture
		await process_frame
		game._show_title(true)
		var menu = game.title_menu
		var scale: Vector2 = root.get_screen_transform().get_scale().abs()
		game.safe_padding = Vector2(44,16) / scale
		menu._layout()
		await process_frame
		for button in menu.buttons.values():
			menu.content_scroll.ensure_control_visible(button)
			await process_frame
			await process_frame
			var bounds := Rect2(game.safe_padding, root.get_visible_rect().size - game.safe_padding * 2)
			check(bounds.grow(0.01).encloses(button.get_global_rect()), "scrolled target within safe bounds")
			check(button.size.y * scale.y >= 44, "menu screen target")
		menu.tick(0.6)
		var button: Button = menu.buttons.story
		menu.content_scroll.ensure_control_visible(button)
		await process_frame
		await process_frame
		await contact(menu, button.get_global_rect().get_center(), true)
		await contact(menu, button.get_global_rect().get_center(), false, true)
		await process_frame
		check(game.title_menu == menu and menu.page == "menu", "canceled story contact")
		await contact(menu, button.get_global_rect().get_center(), true)
		var drag := InputEventScreenDrag.new()
		drag.index = 9
		drag.position = root.get_screen_transform() * (button.get_global_rect().get_center() + Vector2(0,30))
		Input.parse_input_event(drag)
		Input.flush_buffered_events()
		await process_frame
		await contact(menu, button.get_global_rect().get_center(), false)
		await process_frame
		check(menu.page == "menu", "drag does not activate")
		await contact(menu, button.get_global_rect().get_center(), true)
		menu._layout()
		await contact(menu, button.get_global_rect().get_center(), false)
		await process_frame
		check(menu.page == "menu", "resize releases contact")
		for page in ["help","scenes","reset"]:
			menu.show_page(page)
			await process_frame
			check(menu.buttons.back.size.y * scale.y >= 44, "back screen target")
			var scroll = menu.controls.get_node("Scenes") if page == "scenes" else menu.content_scroll
			check(scroll.position.y + scroll.size.y <= menu.buttons.back.position.y, "scroll excludes footer")
		menu.show_page("menu")
		menu.tick(0.6)
		await process_frame
		await process_frame
		menu.content_scroll.ensure_control_visible(menu.buttons.licenses)
		await process_frame
		await process_frame
		await contact(menu, menu.buttons.licenses.get_global_rect().get_center(), true)
		await contact(menu, menu.buttons.licenses.get_global_rect().get_center(), false)
		await process_frame
		check(menu.legal.opened, "licenses opens")
		menu._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		check(menu.page == "menu", "title does not navigate behind licenses")
		root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		check(menu.page == "menu" and not menu.legal.opened, "OS Back only closes overlay")
		check(menu.buttons.licenses.has_focus(), "licenses focus restored")
		game.safe_padding = Vector2(18,14)
	print("Title mobile layout failures: ", failures.size())
	quit(0 if failures.is_empty() else 1)
