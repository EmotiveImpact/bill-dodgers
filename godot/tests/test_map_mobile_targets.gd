extends SceneTree
## Real native touch dispatch, including interruption and short-window scrolling.
## Rendered desktop pixels are a fixture, not device dp/pt certification.
const Support = preload("res://tests/test_support.gd")
var checks := 0
var failures: Array[String] = []
var game
var map
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)
func touch(point: Vector2, pressed: bool, canceled: bool = false, id: int = 21) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id; event.position = root.get_screen_transform() * point; event.pressed = pressed; event.canceled = canceled
	Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
func drag(point: Vector2, id: int = 21) -> void:
	var event := InputEventScreenDrag.new(); event.index = id; event.position = root.get_screen_transform() * point
	Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
func tap(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	await touch(point, true); await touch(point, false)
func frames() -> void:
	await process_frame; await process_frame
func run() -> void:
	root.content_scale_size = Vector2i(960,540); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS; root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	game = load("res://main.tscn").instantiate(); root.add_child(game); await frames()
	Support.silence(game); game.set_physics_process(false)
	game.save = {"schema":1,"receipts":{},"cleared":{},"seen":{"1-intro":true},"skills":[],"kitty":0,"friend":"jp","party_mode":"solo","party_mate":"maya","party_confirmed":true}
	game._show_campaign(); await frames(); map = game.campaign_map
	for fixture in [Vector2i(568,320),Vector2i(844,390),Vector2i(1280,720)]:
		root.size = fixture; await frames()
		var scale := root.get_screen_transform().get_scale()
		game.safe_padding = Vector2(maxf(18,44 / scale.x),maxf(14,16 / scale.y)); await frames()
		var safe := Rect2(game.safe_padding,Vector2(960,540) - 2 * game.safe_padding)
		for button in [map.friend_button,map.zoom_button,map.header.get_node("Worlds"),map.title_button,map.next_button]:
			var rect: Rect2 = root.get_screen_transform() * button.get_global_rect()
			check(rect.size.x >= 43.99 and rect.size.y >= 43.99, "%s target at %s" % [button.text,fixture])
			check(safe.grow(0.01).encloses(button.get_global_rect()),"Header/footer fits safe bounds")
		var point: Vector2 = map.zoom_button.get_global_rect().get_center()
		map.set_wide(false)
		await touch(point,true); await touch(point,false,true)
		check(not map.wide,"Canceled UI touch never zooms")
		await tap(map.zoom_button); check(map.wide,"Normal native touch zooms exactly once")
		map.set_wide(false)
		await touch(point,true); map._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT); map._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN); await touch(point,false)
		check(not map.wide,"Focus interruption invalidates UI owner")
		await touch(point,true); map.show_card("1-1"); await touch(point,false)
		check(not map.wide,"Overlay change invalidates UI owner")
		for button in [map.play_button,map.card.get_node("CloseCard")]:
			var rect: Rect2 = root.get_screen_transform() * button.get_global_rect()
			check(rect.size.y >= 43.99 and safe.grow(0.01).encloses(button.get_global_rect()),"Card action target and safe bounds")
		await tap(map.friend_button)
		check(map.friend_panel.visible and map.selection_return_stage == "1-1", "Header Character opens over card and retains return stage")
		await tap(map.friend_panel.cancel_button)
		check(not map.friend_panel.visible and map.card.visible and map.selected == "1-1", "Character Cancel restores stage card")
		await tap(map.card.get_node("CloseCard")); check(not map.card.visible,"Card closes via touch")
		await tap(map.header.get_node("Worlds")); check(map.world_panel.visible,"Worlds opens via touch")
		await tap(map.world_buttons[1]); check(map.stage_panel.visible,"World opens stages via touch")
		check(map.stage_scroll.size.y > 0,"Short-window list has positive scroll viewport")
		for button in map.stage_buttons.values():
			var rect: Rect2 = root.get_screen_transform() * button.get_global_rect()
			check(rect.size.y >= 43.99,"All seven scroll rows meet rendered target")
		var start: Vector2 = map.stage_scroll.get_global_rect().get_center()
		await touch(start,true); await drag(start - Vector2(0,150)); await touch(start - Vector2(0,150),false)
		check(map.stage_list.size.y <= map.stage_scroll.size.y or map.stage_scroll.scroll_vertical > 0,"Native touch drag scrolls overflowing stage list")
		var close: Button = map.stage_panel.get_node("CloseList")
		check(safe.grow(0.01).encloses(close.get_global_rect()),"List Close remains safely reachable")
		await tap(close); check(not map.stage_panel.visible,"List Close works after scroll")
		point = map.zoom_button.get_global_rect().get_center()
		await touch(point,true); root.size = fixture + Vector2i(1,1); await frames(); await touch(point,false)
		check(not map.wide,"Window transform change cancels touch even with unchanged canvas")
	await tap(map.title_button)
	check(is_instance_valid(game.title_menu) and game.title_menu.page == "menu", "Native Menu release safely removes map without stale viewport access")
	game.queue_free(); await frames()
	print("Map mobile targets: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
