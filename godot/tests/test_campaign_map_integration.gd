extends SceneTree
## Real Input.parse_input_event dispatch through the production title/map/GUI.
## Save and timing setup are explicit fixtures, not campaign objective evidence.
const Support = preload("res://tests/test_support.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)
func button(parent: Node, prefix: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text.begins_with(prefix) and child.is_visible_in_tree(): return child
		var nested := button(child, prefix)
		if nested != null: return nested
	return null
func touch(position: Vector2, pressed: bool, id: int = 9, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new(); event.index = id; event.position = root.get_screen_transform() * position; event.pressed = pressed; event.canceled = canceled
	Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
func tap(control: Button) -> void:
	if control == null: check(false, "Required visible GUI control exists"); return
	await process_frame
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control); await process_frame
		ancestor = ancestor.get_parent()
	var position := control.get_global_rect().get_center()
	await touch(position, true); await touch(position, false)
func drag(position: Vector2, id: int) -> void:
	var event := InputEventScreenDrag.new(); event.index = id; event.position = root.get_screen_transform() * position
	Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
func key(code: int) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = true
	Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
	event = InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = false
	Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
func run() -> void:
	root.size = Vector2i(1280,720); root.content_scale_size = Vector2i(960,540); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var game = load("res://main.tscn").instantiate(); root.add_child(game); await process_frame
	Support.silence(game); game.set_physics_process(false)
	game.save = {"schema":1,"receipts":{},"cleared":{},"seen":{},"skills":[],"kitty":0,"friend":"jp","party_mode":"solo","party_mate":"maya","party_confirmed":true}; game.level_id = ""
	game._show_title(); await process_frame
	check(game.title_menu.page == "press" and game.mode == "menu", "Production startup has original title, not development grid")
	var title = game.title_menu; title.set_process(false); title.idle = 0; title.elapsed = 0
	title.tick(6.99); check(not title.attracting, "Attract does not start before source seven seconds")
	title.tick(0.02); check(title.attracting and title.attract.scene_id == "title", "Original native title cast roll starts at seven seconds")
	check(game.save.seen.is_empty() and not game.story.playing, "Attract uses separate player without marking story seen")
	title._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT); var clock: float = title.elapsed; title.tick(1)
	check(title.elapsed == clock and title.attract.paused, "Background title/attract pause")
	title._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await tap(title.buttons.start)
	check(title.page == "menu" and not title.attracting, "Real touch cancels attract and opens menu")
	await tap(title.buttons.story)
	check(game.ui.has_node("TitleMenu"), "Opening touch cannot click through the 450ms guard")
	title.tick(0.5); await tap(title.buttons.help)
	check(title.page == "help", "Actual How to play opens controls")
	check(title.controls.get_node("CopyScroll/Copy").get_global_rect().end.x <= game.get_viewport_rect().size.x - 24, "Help copy stays inside the native viewport after text wrapping")
	title.tick(0.5); await tap(title.buttons.back)
	title.tick(0.5); await tap(title.buttons.scenes)
	check(title.page == "scenes" and title.buttons.has("1-intro") and not title.buttons.has("6-ending"), "Story library exposes only eligible seen material")
	title.tick(0.5); await tap(title.buttons.back)
	title.tick(0.5); await tap(title.buttons.story)
	check(game.campaign_view and is_instance_valid(game.campaign_map) and game.mode == "story" and game.story.scene_id == "1-intro", "Fresh Story mode presents source introduction before the map")
	check(game.save.seen.get("1-intro",false), "Title introduction uses normal story-seen accounting")
	await tap(game.story.skip_button)
	check(game.mode == "menu" and game.ui.visible, "Real introduction Skip reveals the preserved painted map")
	var map = game.campaign_map; map.set_process(false)
	await tap(button(map.header,"Worlds"))
	check(map.world_panel.visible and map.world_buttons[2].disabled, "Real Worlds panel retains locked second island")
	await tap(map.world_buttons[2]); check(map.world_panel.visible and not map.stage_panel.visible, "Disabled world cannot navigate")
	await tap(map.world_buttons[1])
	check(map.stage_panel.visible and not map.stage_buttons["1-1"].disabled and map.stage_buttons["1-2"].disabled, "Actual stage picker exposes source locks")
	await tap(map.stage_buttons["1-1"])
	check(not map.stage_panel.visible and not map.route.is_empty(), "Real stage selection walks the painted path")
	for index in 100: map.tick(0.02)
	check(map.card.visible and map.selected == "1-1" and not map.next_button.visible, "Arrival card is reachable and not covered by footer")
	await tap(map.play_button)
	check(game.mode == "play" and game.campaign_run and game.level_id == "1-1", "Actual card Play uses guarded host without repeating the seen title introduction")
	check(not game.story.playing and game.ui.visible, "Native stage runs with no stale title story overlay")
	await tap(button(game.ui,"Menu")); await tap(button(game.ui,"Level map"))
	check(game.mode == "menu" and game.campaign_view and game.campaign_map != map, "Gameplay Map creates clean new map scene")
	map = game.campaign_map; map.set_process(false)
	for index in 100: map.tick(0.02)
	await tap(button(map.card,"Close"))
	check(not map.card.visible and map.next_button.visible, "Card Close returns unobstructed map")
	await tap(map.zoom_button); check(map.wide, "Real Whole map button changes camera target")
	check(map.friend_button.text == "Change character" and map.friend_button.size.y >= 44, "Explicit mobile-sized character control is only on map")
	var progress_before := JSON.stringify(game.save.cleared) + JSON.stringify(game.save.receipts) + str(game.save.kitty)
	await tap(map.friend_button); check(map.friend_panel.visible, "Real housemate selection opens")
	await tap(button(map.friend_panel,"Maya")); await tap(map.friend_panel.start_button); check(game.character == "maya" and not map.friend_panel.visible and map.friend_button.text == "Change character" and map.friend_button.tooltip_text.ends_with("Maya"), "Housemate choice updates native host and walker")
	check(JSON.stringify(game.save.cleared) + JSON.stringify(game.save.receipts) + str(game.save.kitty) == progress_before, "Explicit character change preserves clears, receipts and Kitty")
	check(preload("res://src/save_store.gd").read_save().friend == "maya", "Character choice persists to disk")
	check(game.configure_party("cpu", "ama"), "Bounded hidden pair selection fixture")
	await tap(map.friend_button); await tap(map.friend_panel.choices.ama); await tap(map.friend_panel.start_button)
	check(game.character == "ama" and game.party_session.runtime.p2 == "maya" and game.party_session.runtime.mode == "cpu", "Selecting existing mate swaps identities without duplicate or mode loss")
	await tap(map.friend_button); await tap(map.friend_panel.choices.maya); await tap(map.friend_panel.start_button); game.configure_party("solo")
	await touch(Vector2(200,150),true,31); await drag(Vector2(300,200),31)
	check(map.drag_moved and not map.contacts.is_empty(), "Real map drag is tracked")
	await touch(map.title_button.get_global_rect().get_center(),false,31)
	check(map.contacts.is_empty(), "Dragging onto header and lifting cannot leave stale contact")
	await touch(Vector2(200,150),true,32); await touch(Vector2(200,150),false,32,true)
	check(map.contacts.is_empty() and map.selected.is_empty(), "OS touch cancellation never selects a stage")
	await tap(map.title_button)
	check(is_instance_valid(game.title_menu) and game.title_menu.page == "menu", "Map Menu opens original title options")
	title = game.title_menu; title.set_process(false); title.tick(0.5)
	await tap(title.buttons.free)
	check(not game.campaign_view and button(game.ui,"Play campaign") != null and button(game.ui,"1-1") != null, "Explicit development/free picker remains reachable")
	# Completed-save presentation fixture, not a gameplay completion claim.
	for world in 6:
		for stage in 6: game.save.cleared["%d-%d"%[world+1,stage+1]] = true
	game._show_title(true); title = game.title_menu; title.set_process(false); title.tick(0.5)
	check(title.buttons.has("credits") and title.buttons.has("new"), "Completed story offers credits replay and explicit reset")
	await process_frame
	var within := true
	for control in title.buttons.values():
		title.content_scroll.ensure_control_visible(control); await process_frame
		within = within and title.content_scroll.get_global_rect().grow(1).encloses(control.get_global_rect())
	check(within, "Completed-story options remain reachable in source-art scroll menu")
	await tap(title.buttons.new); check(title.page == "reset", "New story does not immediately discard progress")
	title.tick(0.5); await tap(title.buttons.back); check(game.save.cleared.size() == 36, "Keep my story cancels reset")
	title.tick(0.5); await tap(title.buttons.credits)
	check(game.mode == "credits" and game.credits_roll.playing, "Actual credits control reaches native credits roll")
	game.credits_roll.skip(); await process_frame
	check(game.mode == "menu" and is_instance_valid(game.title_menu) and game.title_menu.page == "menu", "Credits returns to original title menu without stale input")
	title = game.title_menu; title.set_process(false); title.tick(0.5)
	await tap(title.buttons.new); title.tick(0.5); await tap(title.buttons.reset)
	check(game.campaign_view and game.save.cleared.is_empty() and game.save.skills.is_empty() and game.save.friend == "maya", "Explicit reset clears native progress and retains chosen housemate")
	var persisted: Dictionary = preload("res://src/save_store.gd").read_save()
	check(persisted.friend == "maya" and persisted.map_at == "HOME" and persisted.cleared.is_empty(), "Confirmed new story is atomic and survives disk read")
	check(game.mode == "story" and game.story.scene_id == "1-intro", "Confirmed new story restores source intro-before-map sequence")
	await tap(game.story.skip_button)
	map = game.campaign_map; map.set_process(false)
	await key(KEY_RIGHT); check(not map.route.is_empty(), "Actual directional key follows authored graph from Home")
	for index in 100: map.tick(0.02)
	await key(KEY_ESCAPE); check(not map.card.visible, "Escape closes stage card without leaving campaign")
	game._show_title(); title = game.title_menu; title.set_process(false)
	await key(KEY_ENTER); check(title.page == "menu", "Actual Enter opens title menu")
	game.queue_free(); await process_frame
	print("Native map/title real GUI: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
