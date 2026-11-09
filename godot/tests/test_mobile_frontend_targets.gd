extends SceneTree
## Production frontend Controls at actual Godot window/canvas transforms.
## A 44 rendered desktop-pixel fixture is NOT a phone dp/pt acceptance claim.
## Run in isolated HOME/XDG. Existing saved bytes are restored on completion.
## Optional: --report=/absolute/report.json. This suite intentionally fails until
## all frontend controls, not just gameplay controls, meet its target contract.
const Support = preload("res://tests/test_support.gd")
const Save = preload("res://src/save_store.gd")
const MIN_TARGET := 44.0
var checks := 0
var failures: Array[String] = []
var measurements: Array[Dictionary] = []
var context := ""
var had_save := false
var original_save := PackedByteArray()
var game
var capture_dir := ""
var only_fixture := ""
var events: Array[String] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		var message := context + ": " + label
		failures.append(message); printerr("FAIL: ", message)
func frames(count: int = 2) -> void:
	for frame in count: await process_frame
func capture(label: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await process_frame; await RenderingServer.frame_post_draw
	var filename := context.replace(" ","_").replace("=","").replace("(","").replace(")","").replace(",","") + "-" + label + ".png"
	check(root.get_texture().get_image().save_png(capture_dir.path_join(filename)) == OK,"Actual renderer screenshot saved")
func rendered_rect(control: Control) -> Rect2:
	return root.get_screen_transform() * control.get_global_rect()
func touch(point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 28; event.position = root.get_screen_transform() * point
	event.pressed = pressed; event.canceled = canceled
	Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
func ensure_visible(control: Control) -> void:
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await frames()
		ancestor = ancestor.get_parent()
func tap(control: Button) -> void:
	check(is_instance_valid(control) and control.is_visible_in_tree(), "Real touch target is visible")
	if not is_instance_valid(control) or not control.is_visible_in_tree(): return
	await ensure_visible(control)
	var point := control.get_global_rect().get_center()
	await touch(point,true); await touch(point,false)
func key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = pressed
		Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
func visible_buttons(parent: Node) -> Array[Button]:
	var result: Array[Button] = []
	for child in parent.get_children():
		if child is Button and child.is_visible_in_tree(): result.append(child)
		result.append_array(visible_buttons(child))
	return result
func safe_rect() -> Rect2:
	return Rect2(game.safe_padding,root.get_visible_rect().size - 2 * game.safe_padding)
func audit_buttons(controls: Array, label: String, bounds: Rect2 = Rect2()) -> void:
	if bounds.size == Vector2.ZERO: bounds = safe_rect()
	for index in controls.size():
		var control: Button = controls[index]
		await ensure_visible(control)
		var actual := rendered_rect(control)
		measurements.append({"fixture":context,"group":label,"label":control.text,"logical_position":str(control.get_global_rect().position),"logical_size":str(control.size),"rendered_position":str(actual.position),"rendered_size":str(actual.size),"disabled":control.disabled})
		check(actual.size.x + 0.01 >= MIN_TARGET and actual.size.y + 0.01 >= MIN_TARGET, "%s %s is at least44 rendered px, got %s" % [label,control.text,actual.size])
		check(bounds.grow(0.01).encloses(control.get_global_rect()), "%s %s fits safe/container bounds" % [label,control.text])
		for previous in range(index):
			check(not control.get_global_rect().intersects(controls[previous].get_global_rect()), "%s %s does not overlap %s" % [label,control.text,controls[previous].text])
func audit_label(control: Label, label: String, bounds: Rect2) -> void:
	check(bounds.grow(0.01).encloses(control.get_global_rect()),label + " text box fits")
	check(control.size.y + 0.01 >= control.get_minimum_size().y,label + " text height fits")
func painter_text_rect(selector, value: String, center: Vector2, font_size: int) -> Rect2:
	var width: float = selector.font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var height: float = selector.font.get_height(font_size)
	return Rect2(center - Vector2(width,height) / 2,Vector2(width,height))
func audit_selector_text(selector) -> void:
	for pair in [[selector.mode_button,roundi(13 * selector.ui_scale)],[selector.start_button,roundi(15 * selector.ui_scale)],[selector.back_button,roundi(13 * selector.ui_scale)],[selector.cancel_button,roundi(13 * selector.ui_scale)]]:
		var control: Button = pair[0]
		check(control.get_global_rect().encloses(painter_text_rect(selector,control.text,control.get_global_rect().get_center(),pair[1])),"Painter action text fits " + control.text)
	for mode in selector.MODES:
		var mode_text := painter_text_rect(selector,selector.MODE_LABELS[mode],selector.mode_button.get_global_rect().get_center(),roundi(13 * selector.ui_scale))
		check(selector.mode_button.get_global_rect().encloses(mode_text),"Every mode label fits " + mode)
	var heading := painter_text_rect(selector,"Player 1: pick your friend",selector.heading_center,selector.heading_size)
	check(safe_rect().encloses(heading),"Selector heading fits safe bounds")
	check(not heading.intersects(selector.back_button.get_global_rect()) and not heading.intersects(selector.cancel_button.get_global_rect()),"Selector heading avoids navigation buttons")
	for who in selector.CAST:
		var card: Rect2 = selector.cards[who]
		var name_rect := painter_text_rect(selector,str(selector.info.cast[who]),card.position + Vector2(card.size.x / 2,card.size.y - 18 * card.size.y / 290),14)
		check(card.encloses(name_rect),"Full source name fits doorway " + who)
func fresh_save() -> Dictionary:
	return {"schema":1,"receipts":{},"cleared":{},"seen":{"1-intro":true},"skills":[],"kitty":0,"friend":"jp","party_mode":"cpu","party_mate":"maya","party_confirmed":true}
func fixture(window_size: Vector2i, inset: Vector2) -> void:
	root.size = window_size; root.content_scale_size = Vector2i(960,540)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	await frames()
	var scale := root.get_screen_transform().get_scale()
	game.safe_padding = Vector2(maxf(18,inset.x / scale.x),maxf(14,inset.y / scale.y))
	context = "%dx%d inset=%s" % [window_size.x,window_size.y,inset]
	print("TRANSFORM ",context," viewport=",root.get_visible_rect()," screen=",root.get_screen_transform()," logical_safe=",game.safe_padding)
	check(root.size == window_size,"Engine window is exact requested fixture")
	check(root.get_visible_rect().size == Vector2(960,540),"Production logical canvas remains960x540")
	var expected_scale := minf(float(window_size.x)/960,float(window_size.y)/540)
	check(absf(scale.x - expected_scale) * 960 <= 1.01 and absf(scale.y - expected_scale) * 540 <= 1.01,"Engine transform matches integer-rounded window-to-canvas extent")
	if window_size == Vector2i(844,390): check(root.get_screen_transform().origin.x > 70,"Wide window uses letterboxing, not844/960 horizontal scaling")

	game.save = fresh_save(); game.character = "jp"; game.configure_party("cpu","maya")
	game._show_title(); await frames()
	var title = game.title_menu; title.set_process(false)
	await audit_buttons(title.buttons.values(),"title press")
	await tap(title.buttons.start); title.tick(0.5); await frames()
	check(title.page == "menu","Actual title touch opens options once")
	await audit_buttons(title.buttons.values(),"title fresh")
	title.content_scroll.scroll_vertical = 0; await frames()
	await capture("title-fresh")
	await ensure_visible(title.buttons.help)
	var help_point: Vector2 = title.buttons.help.get_global_rect().get_center()
	await touch(help_point,true); await touch(help_point,false,true)
	check(title.page == "menu","OS-canceled title contact never opens Help")
	title.show_page("menu"); title.tick(0.5); await frames()
	await tap(title.buttons.help); title.tick(0.5); await frames()
	check(title.page == "help","Help is reachable by touch")
	await audit_buttons(title.buttons.values(),"title help")
	check(safe_rect().encloses(title.content_scroll.get_global_rect()),"Help scroll fits safe bounds")
	check(not title.content_scroll.get_global_rect().intersects(title.buttons.back.get_global_rect()),"Help copy avoids Back")
	await capture("title-help")
	await tap(title.buttons.back); title.tick(0.5)
	await tap(title.buttons.scenes); title.tick(0.5); await frames()
	await audit_buttons(title.buttons.values(),"title scenes")
	await tap(title.buttons.back); title.tick(0.5)
	for world in range(1,7):
		for stage in range(1,7): game.save.cleared["%d-%d" % [world,stage]] = true
	game._show_title(true); await frames(); title = game.title_menu; title.set_process(false); title.tick(0.5)
	await audit_buttons(title.buttons.values(),"title completed")
	title.content_scroll.scroll_vertical = 0; await frames()
	await capture("title-completed")
	# Layout capacity only: a forthcoming authorized Licenses entry is not yet
	# integrated into production and this fixture never opens legal content.
	check(title.buttons.has("licenses"),"Integrated Licenses remains reachable without shrinking menu targets")
	await tap(title.buttons.licenses); await frames()
	check(title.legal.opened,"Licenses opens from actual scrolling menu tap")
	await capture("licenses")
	await tap(title.legal.close_button); title.tick(0.5)
	check(not title.legal.opened and title.buttons.licenses.has_focus(),"Licenses closes to originating menu focus")
	await tap(title.buttons.new); title.tick(0.5); await frames()
	await audit_buttons(title.buttons.values(),"title reset")
	check(safe_rect().encloses(title.content_scroll.get_global_rect()),"Reset scroll fits safe bounds")
	await tap(title.buttons.back); title.tick(0.5)
	check(game.save.cleared.size() == 36,"Cancel reset preserves completed-save fixture")

	game.save = fresh_save(); game._show_campaign(); await frames()
	var map = game.campaign_map; map.set_process(false); map._layout()
	check(not map.friend_panel.visible,"Map does not force existing party reselection")
	await audit_buttons(visible_buttons(map.header),"map header")
	await audit_buttons([map.next_button],"map next")
	await capture("map-actions")
	var zoom_point: Vector2 = map.zoom_button.get_global_rect().get_center()
	var prior_wide: bool = map.wide
	await touch(zoom_point,true); await touch(zoom_point,false,true)
	check(map.wide == prior_wide,"OS-canceled map action never changes zoom")
	map.set_wide(prior_wide)
	check(not map.next_button.get_global_rect().intersects(map.get_node("MapHint").get_global_rect()),"Next action avoids map hint")
	await tap(map.header.get_node("Worlds")); await frames()
	check(map.world_panel.visible,"Worlds touch opens world list")
	await audit_buttons(visible_buttons(map.world_panel),"map world list",map.world_panel.get_global_rect())
	check(safe_rect().encloses(map.world_panel.get_global_rect()),"World list stays in safe bounds")
	await tap(map.world_buttons[1]); await frames()
	await audit_buttons(visible_buttons(map.stage_panel),"map stage list",map.stage_panel.get_global_rect())
	check(safe_rect().encloses(map.stage_panel.get_global_rect()),"Stage list stays in safe bounds")
	map.close_overlays(); map.show_card("1-1"); await frames()
	await audit_buttons(visible_buttons(map.card),"map stage card",map.card.get_global_rect())
	check(map.card.get_global_rect().encloses(map.card_copy.get_parent().get_global_rect()),"Stage description scroll fits card")
	check(not map.card_copy.get_parent().get_global_rect().intersects(map.play_button.get_global_rect()),"Stage description avoids Play")
	await capture("map-stage-card")
	var before: Dictionary = game.save.duplicate(true)
	await tap(map.friend_button); await frames()
	var selector = map.friend_panel; selector.set_process(false)
	check(selector.visible and map.selection_return_stage == "1-1","Deliberate map Change character preserves stage return")
	await audit_buttons(visible_buttons(selector),"selector")
	audit_selector_text(selector)
	await capture("official-selector")
	check(selector.cards.size() == 6,"Six original doorways remain in one row")
	var previous_x := -INF
	for who in selector.CAST:
		var rect: Rect2 = selector.cards[who]
		check(rect.position.x > previous_x and rect.position.y == selector.cards.jp.position.y,"Source doorway ordering " + who)
		previous_x = rect.position.x
	await tap(selector.choices.theo)
	check(selector.draft.p1 == "theo" and selector.step == 1,"Door touch selects P1 and advances to mate")
	await tap(selector.choices.mei)
	check(selector.draft.p2 == "mei" and selector.step == 2,"Door touch selects distinct mate")
	await tap(selector.cancel_button)
	check(not selector.visible and map.card.visible and map.selected == "1-1","Cancel restores exact selected stage card")
	check(game.save == before,"Cancel does not persist draft choices")
	await tap(map.friend_button); await tap(selector.choices.theo); await tap(selector.back_button)
	check(selector.step == 0 and selector.visible,"Back reverses selection without committing")
	await key(KEY_ESCAPE)
	check(not selector.visible and game.save == before,"Escape at first step cancels without changing saved choices")
	await tap(map.friend_button)
	var point: Vector2 = selector.mode_button.get_global_rect().get_center()
	var old_mode: String = selector.draft.mode
	await touch(point,true); await touch(point,false,true)
	check(selector.draft.mode == old_mode,"OS-canceled selector contact never activates")
	# A real root resize with unchanged logical viewport catches cached-layout
	# bugs that watching only get_viewport_rect().size cannot detect.
	old_mode = selector.draft.mode
	selector.set_process(true)
	await touch(point,true)
	root.size = window_size + Vector2i(8,0); await frames()
	await touch(point,false)
	check(selector.draft.mode == old_mode,"Window resize cancels pending selector activation")
	selector.set_process(false)
	root.size = window_size; await frames()
	await tap(selector.cancel_button)
	await tap(map.friend_button); await tap(selector.choices.theo); await tap(selector.choices.mei); await tap(selector.start_button)
	check(not selector.visible and game.character == "theo" and game.party_session.runtime.p2 == "mei","Confirmed GUI choice persists to host")
	var persisted: Dictionary = Save.read_save()
	check(persisted.friend == "theo" and persisted.party_mate == "mei" and persisted.party_confirmed,"Confirmed choices persist to native disk save")
	game._show_campaign(); await frames()
	check(not game.campaign_map.friend_panel.visible and game.character == "theo","Reopening map keeps choice without automatic selector")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="): only_fixture = arg.trim_prefix("--fixture=")
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(capture_dir)
	had_save = FileAccess.file_exists(Save.PATH)
	if had_save: original_save = FileAccess.get_file_as_bytes(Save.PATH)
	root.size = Vector2i(1280,720); root.content_scale_size = Vector2i(960,540); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game = load("res://main.tscn").instantiate(); root.add_child(game); game.set_physics_process(false); Support.silence(game); await frames()
	for window_size in [Vector2i(568,320),Vector2i(844,390),Vector2i(1280,720)]:
		if only_fixture.is_empty() or only_fixture == "%dx%d" % [window_size.x,window_size.y]:
			for inset in [Vector2.ZERO,Vector2(44,16)]: await fixture(window_size,inset)
	game.queue_free(); await frames()
	if had_save:
		var saved := FileAccess.open(Save.PATH,FileAccess.WRITE); saved.store_buffer(original_save); saved.close()
	else: DirAccess.remove_absolute(Save.PATH)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var report := FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
			if report != null:
				report.store_string(JSON.stringify({"checks":checks,"failures":failures,"targets":measurements,"scope":"Actual Godot desktop-window transforms and input dispatch; not physical phone points, rendering review, device performance, or phone acceptance."},"\t")); report.close()
	print("Mobile frontend window targets: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
