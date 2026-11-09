extends SceneTree
const Notices = preload("res://src/legal_notices.gd")
var checks := 0
var failures: Array[String] = []
var closes := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)

func touch(point: Vector2, pressed: bool, canceled := false, index := 3) -> void:
	var event := InputEventScreenTouch.new()
	event.position = root.get_screen_transform() * point
	event.index = index
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func drag(point: Vector2, index := 3) -> void:
	var event := InputEventScreenDrag.new()
	event.position = root.get_screen_transform() * point
	event.index = index
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func run() -> void:
	var fixture := [{"name": "A [url]component[/url]", "parts": [{"copyright": ["2026, Original Author"], "files": ["source/file.c"], "license": "License-A or License-B"}]}]
	var fixture_licenses := {"License-B": "Second complete text", "License-A": "First complete text"}
	var fixture_fonts := {}
	for path in Notices.FONT_FILES: fixture_fonts[path] = "Complete unchanged font text: " + path
	var snapshot := var_to_str([fixture, fixture_licenses, fixture_fonts])
	var pure: String = Notices.build_text("Full engine text", fixture, fixture_licenses, fixture_fonts)
	check(pure == Notices.build_text("Full engine text", fixture, fixture_licenses, fixture_fonts), "formatter is deterministic without a scene")
	check(snapshot == var_to_str([fixture, fixture_licenses, fixture_fonts]), "formatter does not mutate input dictionaries")
	for value in ["Full engine text", "A [url]component[/url]", "2026, Original Author", "source/file.c", "License-A or License-B", "First complete text", "Second complete text"]:
		check(pure.contains(value), "formatter preserves original content: " + value)
	check(pure.find("First complete text") < pure.find("Second complete text"), "license texts are sorted independently of map insertion order")
	check(Notices.build_text("", [], {}, {}).contains("Required notice unavailable: " + Notices.FONT_FILES[0]), "missing notice is explicit, not silently omitted")
	for path in Notices.FONT_FILES:
		check(pure.contains(fixture_fonts[path]), "formatter includes complete font text: " + path)
		check(FileAccess.file_exists(path), "bundled font notice exists: " + path)
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var view := Notices.new()
	view.configure(ThemeDB.fallback_font, Vector2(18, 14))
	root.add_child(view)
	view.close_requested.connect(func(): closes += 1)
	await process_frame
	check(not view.visible and not view.opened, "standalone view starts hidden")
	view.open()
	await process_frame
	await process_frame
	check(view.opened and view.visible, "open shows read-only view")
	check(view.missing_notice_paths.is_empty(), "all required font notices are readable")
	check(view.body.text.contains(Engine.get_license_text()), "complete engine license comes from running binary")
	for component in Engine.get_copyright_info():
		check(view.body.text.contains(component.name), "engine component retained: " + component.name)
		for part in component.parts:
			check(view.body.text.contains(part.license), "license expression retained: " + part.license)
			for owner in part.copyright: check(view.body.text.contains(owner), "component attribution retained")
			for file in part.files: check(view.body.text.contains(file), "component source paths retained")
	for license in Engine.get_license_info().values(): check(view.body.text.contains(license), "complete runtime license-map text retained")
	for path in Notices.FONT_FILES: check(view.body.text.contains(FileAccess.get_file_as_string(path)), "full bundled notice retained: " + path)
	check(not view.body.bbcode_enabled and view.body.selection_enabled and view.body.scroll_active, "body is selectable, scrolling plain text")
	check(view.body.get_theme_font("normal_font") == ThemeDB.fallback_font, "configured font reaches the reader")
	var official_text: String = view.body.text
	view.body.text = "[url=https://example.invalid]Not a link[/url] [b]Not bold[/b]"
	check(view.body.get_parsed_text() == view.body.text, "BBCode-like external attribution stays literal text")
	view.body.text = official_text
	await process_frame
	var count: int = view.get_child_count()
	view.open()
	check(view.get_child_count() == count, "repeated open does not duplicate nodes")
	var scroll: VScrollBar = view.body.get_v_scroll_bar()
	check(scroll.max_value > scroll.page, "full notices overflow and can be scrolled")
	var point: Vector2 = view.body.get_global_rect().get_center()
	await touch(point, true)
	await drag(point - Vector2(0, 90))
	await touch(point - Vector2(0, 90), false)
	check(scroll.value > 0 and closes == 0, "native touch drag scrolls without closing")
	var bar_rect := scroll.get_global_rect()
	point = Vector2(bar_rect.get_center().x, bar_rect.end.y - 1)
	await touch(point, true)
	check(scroll.value > (scroll.max_value - scroll.page) * 0.9, "touch scrollbar jumps near the end of long notices")
	await drag(Vector2(point.x, bar_rect.position.y))
	await touch(Vector2(point.x, bar_rect.position.y), false)
	check(is_zero_approx(scroll.value) and closes == 0, "touch scrollbar scrubs back to the start")
	point = view.close_button.get_global_rect().get_center()
	await touch(point, true)
	await touch(point, false, true)
	check(closes == 0 and view.opened and view._touch_index == -1, "canceled Close contact cannot activate")
	await touch(point, true)
	await drag(Vector2(2, 2))
	await touch(Vector2(2, 2), false)
	check(closes == 0 and view.opened, "dragging outside Close cancels activation")
	await touch(point, true)
	view.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await touch(point, false)
	check(closes == 0 and view.opened and not view.close_button.button_pressed, "focus loss clears pending activation")
	await touch(point, true)
	root.size = Vector2i(844, 390)
	await process_frame
	await touch(point, false)
	check(closes == 0 and view.opened and view._touch_index == -1, "viewport resize clears pending activation")
	for dimensions in [Vector2i(844,390), Vector2i(568,320), Vector2i(390,844), Vector2i(1280,720)]:
		root.size = dimensions
		await process_frame
		await process_frame
		var scale := root.get_screen_transform().get_scale().abs()
		check(view.size.is_equal_approx(root.get_visible_rect().size), "view follows its viewport without host relayout: " + str(dimensions))
		check(view.close_button.size.x * scale.x >= 44 and view.close_button.size.y * scale.y >= 44, "Close remains >=44 screen pixels: " + str(dimensions))
		check(scroll.size.x * scale.x >= 44, "scrollbar remains >=44 screen pixels: " + str(dimensions))
		check(view.get_global_rect().encloses(view.close_button.get_global_rect()) and view.get_global_rect().encloses(view.body.get_global_rect()), "reader and Close stay inside viewport: " + str(dimensions))
		check(not view.close_button.get_global_rect().intersects(view.body.get_global_rect()), "Close and reader do not overlap: " + str(dimensions))
	point = view.close_button.get_global_rect().get_center()
	await touch(point, true)
	await touch(point, false)
	check(closes == 1 and not view.opened and not view.visible, "real touch Close emits once and hides")
	view.request_close()
	view.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(closes == 1, "late/hidden requests cannot emit again")
	view.open()
	check(scroll.value == 0, "reopening starts at the top")
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key); Input.flush_buffered_events()
	await process_frame
	check(closes == 2 and not view.opened, "Escape requests one close")
	view.open()
	view.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(closes == 3 and not view.opened, "Android Back requests one close")
	view.open()
	paused = true
	await process_frame
	check(view.can_process(), "licenses remain usable while host tree is paused")
	view.close()
	paused = false
	check(closes == 3 and not view.visible, "silent host removal does not request navigation")
	view.configure(null, Vector2(44,24))
	view.open()
	await process_frame
	check(view.body.get_theme_font("normal_font") == ThemeDB.fallback_font, "font fallback can be configured after ready")
	view.close()
	view.queue_free()
	await process_frame
	print("Legal notices: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
