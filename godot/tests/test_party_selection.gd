extends SceneTree
## Actual Input.parse_input_event dispatch through the production selector.
## The single synthetic clear below tests UI handoff, not gameplay completion.
## Run with isolated HOME/XDG; byte-for-byte save restoration also protects
## subsequent suites in the same test home from leaked party preferences.
const Save = preload("res://src/save_store.gd")
const Support = preload("res://tests/test_support.gd")
var checks := 0
var failures: Array[String] = []
var had_save := false
var original_save := PackedByteArray()

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--restart-check": call_deferred("restart_probe", args[1])
	else: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)
func button(parent: Node, prefix: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text.begins_with(prefix) and child.is_visible_in_tree(): return child
		var nested := button(child, prefix)
		if nested != null: return nested
	return null
func tap(control: Button) -> void:
	if control == null or not is_instance_valid(control): check(false, "Required visible GUI control exists"); return
	check(control.is_visible_in_tree(), "Tap visible control: " + control.text)
	await process_frame
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control); await process_frame
		ancestor = ancestor.get_parent()
	var position := root.get_screen_transform() * control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 19; event.position = position; event.pressed = pressed
		Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code; event.physical_keycode = code; event.pressed = pressed
	Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
func progress(save: Dictionary) -> Dictionary:
	var snapshot := {}
	for field in ["cleared","receipts","skills","kitty","seen"]: snapshot[field] = save.get(field)
	return snapshot.duplicate(true)
func roster(game, mode: String, first: String, second: String) -> bool:
	var party = game.party_session.runtime
	return party.mode == mode and party.p1 == first and game.character == first and party.p2 == second
func settle_map(map) -> void:
	map.set_process(false)
	for index in 1000: map.tick(0.02)
func new_game():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	Support.silence(game)
	await process_frame
	if is_instance_valid(game.title_menu): game.title_menu.set_process(false)
	return game
func enter_map(game) -> void:
	var title = game.title_menu
	if title.page == "press": await tap(title.buttons.start)
	title.tick(0.5)
	await tap(title.buttons.story)
	if game.mode == "story": await tap(game.story.skip_button)
	settle_map(game.campaign_map)
func back_to_map(game) -> void:
	await tap(button(game.ui,"Menu"))
	check(game.mode == "paused","Actual Menu pauses before returning to map")
	await tap(button(game.ui,"Level map"))
func select_mode(selector, mode: String) -> void:
	for index in 3:
		if selector.draft.mode == mode: return
		await tap(selector.mode_button)
	check(selector.draft.mode == mode,"Visible mode cycle reaches " + mode)
func choose_party(map, mode: String, first: String, second: String) -> void:
	await tap(map.friend_button)
	var selector = map.friend_panel
	await select_mode(selector,mode)
	while selector.step > 0: await tap(selector.back_button)
	await tap(selector.choices[first])
	if mode != "solo": await tap(selector.choices[second])
	await tap(selector.start_button)
func start_next(map) -> void:
	if map.card.visible: await tap(button(map.card,"Close"))
	await tap(map.next_button); settle_map(map); await tap(map.play_button)
func verify_bounds(map, viewport: Rect2) -> void:
	var selector = map.friend_panel
	var safe := viewport.grow_individual(-map.game.safe_padding.x,-map.game.safe_padding.y,-map.game.safe_padding.x,-map.game.safe_padding.y)
	check(selector.get_global_rect() == viewport,"Official selection fills the viewport, not a portrait modal")
	var controls: Array = [selector.mode_button,selector.start_button,selector.back_button,selector.cancel_button]
	controls.append_array(selector.choices.values())
	for control in controls:
		check(control.size.x >= 44 and control.size.y >= 44 and safe.encloses(control.get_global_rect()),"Official safe ≥44px target: " + control.text)
	for first in controls.size():
		for second in range(first+1,controls.size()):
			check(not controls[first].get_global_rect().intersects(controls[second].get_global_rect()),"Official selection targets never overlap")
	check(selector.background != null,"Official original street backdrop resolves")
	for index in selector.CAST.size():
		var character: String = selector.CAST[index]
		var rect: Rect2 = selector.cards[character]
		check(rect == Rect2(31+index*152,118,138,290),"Original single-row doorway geometry: " + character)
		var state: Dictionary = selector.painter.sprite_state(selector,character)
		var sheet: Dictionary = selector.info.sheets[character]
		check(state.source.size == Vector2(sheet.w,sheet.h) and selector.pictures.has("sprite-" + character),"Full original sprite frame, not cropped portrait: " + character)
	selector.elapsed = 0.21
	check(selector.painter.sprite_state(selector,selector.draft.p1).animation == "win" and selector.painter.sprite_state(selector,selector.draft.p1).frame == 1,"Selected actor uses source160ms win animation")
	var unselected: String = "ama" if selector.draft.p1 != "ama" and selector.draft.p2 != "ama" else "leo"
	check(selector.painter.sprite_state(selector,unselected).animation == "idle" and selector.painter.sprite_state(selector,unselected).frame == 1,"Unselected actor uses source200ms idle animation")
func panel_buttons(parent: Node) -> Array[Button]:
	var result: Array[Button] = []
	for child in parent.get_children():
		if child is Button: result.append(child)
		result.append_array(panel_buttons(child))
	return result
func clipped_rect(control: Control) -> Rect2:
	var result := control.get_global_rect()
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: result = result.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	return result
func verify_panel_targets(map, panel: Panel, label: String) -> void:
	var safe := Rect2(map.game.safe_padding,Vector2(960,540) - 2 * map.game.safe_padding)
	check(safe.encloses(panel.get_global_rect()), label + " panel stays inside safe viewport")
	var controls := panel_buttons(panel)
	for child in controls:
		var ancestor := child.get_parent()
		while ancestor != null:
			if ancestor is ScrollContainer:
				ancestor.ensure_control_visible(child); await process_frame
			ancestor = ancestor.get_parent()
		check(child.size.x >= 44 and child.size.y >= 44 and safe.encloses(child.get_global_rect()) and panel.get_global_rect().encloses(child.get_global_rect()), "Safe reachable contained ≥44 logical unit " + label + " target: " + child.text)
	for first in controls.size():
		for second in range(first+1, controls.size()):
			check(not clipped_rect(controls[first]).intersects(clipped_rect(controls[second])), label + " visible button hit regions never overlap")

func restore_save() -> void:
	if had_save:
		var file := FileAccess.open(Save.PATH,FileAccess.WRITE)
		file.store_buffer(original_save); file.close()
	else: DirAccess.remove_absolute(Save.PATH)
func restart_fixture(mode: String) -> String:
	return "user://party-selector-restart-%s.json" % mode
func restart_probe(mode: String) -> void:
	# Execute in a fresh Godot process AFTER the main suite, with the same
	# isolated HOME/XDG. These bytes came from actual GUI selections, not a
	# manually invented preference fixture. Preserve the pre-existing save.
	if mode not in ["p2","cpu","solo"] or not FileAccess.file_exists(restart_fixture(mode)):
		printerr("Run the full party selector suite before --restart-check p2|cpu|solo in the same isolated HOME/XDG."); quit(1); return
	had_save = FileAccess.file_exists(Save.PATH)
	if had_save: original_save = FileAccess.get_file_as_bytes(Save.PATH)
	check(DirAccess.copy_absolute(restart_fixture(mode),Save.PATH) == OK, "Install exact previous-process GUI save for restart")
	root.size = Vector2i(1280,720); root.content_scale_size = Vector2i(960,540); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var game = await new_game()
	check(roster(game,mode,"theo","mei"), "Separate process startup restores " + mode + " and both identities")
	await enter_map(game)
	var map = game.campaign_map
	check(not map.friend_panel.visible, "Separate process map never forces reselection")
	if map.card.visible: await tap(button(map.card,"Close"))
	await tap(map.next_button); settle_map(map); await tap(map.play_button)
	check(game.mode == "play" and game.party_session.active == (mode != "solo"), "Separate process stage honors saved " + mode)
	if mode != "solo":
		var actors: Array = game.party_session.runtime.actors
		check(actors.size() == 2 and actors[0].character == "theo" and actors[1].character == "mei" and actors[1].cpu == (mode == "cpu"), "Separate process creates exact chosen actors")
	game.queue_free(); await process_frame
	restore_save()
	print("Native party separate-process restart %s: %d checks, %d failures" % [mode,checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
func run() -> void:
	root.size = Vector2i(1280,720); root.content_scale_size = Vector2i(960,540); root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	had_save = FileAccess.file_exists(Save.PATH)
	if had_save: original_save = FileAccess.get_file_as_bytes(Save.PATH)
	Save.write_save({"schema":1,"receipts":{},"cleared":{},"seen":{"1-intro":true},"skills":[],"kitty":17,"friend":"jp"})
	var game = await new_game()
	check(game.character == "jp" and game.party_session.runtime.mode == "solo" and not game.save.get("party_confirmed",false),"Legacy save boots Solo without claiming an explicit selection")
	await enter_map(game)
	var map = game.campaign_map
	check(game.mode == "menu" and not map.friend_panel.visible,"Campaign opens map without forced title/reselection")
	var before := progress(game.save)
	await tap(button(map.header,"Worlds")); await verify_panel_targets(map,map.world_panel,"World")
	await tap(map.world_buttons[2]); check(map.world_panel.visible and not map.stage_panel.visible,"Disabled World target cannot bypass lock")
	await tap(map.world_buttons[1]); await verify_panel_targets(map,map.stage_panel,"Stage")
	await tap(map.stage_buttons["1-2"]); check(map.stage_panel.visible and game.mode == "menu","Disabled Stage target cannot bypass lock")
	await tap(map.stage_buttons["1-1"]); settle_map(map); await verify_panel_targets(map,map.card,"Card")
	var unchanged_disk := FileAccess.get_file_as_bytes(Save.PATH)
	await tap(map.play_button)
	var selector = map.friend_panel
	check(selector.visible and game.mode == "menu" and map.pending_party_level == "1-1","First genuine map Play opens official selection before the chosen stage")
	check(selector.draft.mode == "cpu" and selector.step == 0,"Fresh official selection uses source computer-mate default and P1 step")
	verify_bounds(map,Rect2(Vector2.ZERO,Vector2(960,540)))
	await tap(selector.choices.theo)
	check(selector.step == 1 and selector.draft.p1 == "theo" and game.character == "jp","First doorway advances to mate while host remains unchanged")
	await tap(selector.choices.mei)
	check(selector.step == 2 and selector.draft.p2 == "mei" and selector.can_start(),"Second doorway completes distinct draft and enables Start")
	check(FileAccess.get_file_as_bytes(Save.PATH) == unchanged_disk,"Unconfirmed official choices never write native save")
	await tap(selector.cancel_button)
	check(not selector.visible and map.card.visible and map.selected == "1-1" and not game.save.get("party_confirmed",false) and game.character == "jp","Cancel restores original stage card and discards pending start/choices")
	await tap(map.play_button); selector = map.friend_panel
	await key(KEY_RIGHT,true); await key(KEY_RIGHT,false)
	check(selector.cursor == 1,"Official Right key moves doorway cursor")
	await key(KEY_ENTER,true); await key(KEY_ENTER,false)
	check(selector.step == 1 and selector.draft.p1 == "maya","Official Enter picks P1")
	await key(KEY_BACKSPACE,true); await key(KEY_BACKSPACE,false)
	check(selector.step == 0 and selector.draft.p2.is_empty() and selector.start_button.disabled,"Backspace steps back and gates Start until pair is valid")
	await key(KEY_F,true); await key(KEY_F,false)
	check(selector.draft.mode == "p2" and selector.step == 1,"Official F cycles CPU to local P2 and requests missing mate")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	check(selector.visible and selector.step == 0,"Escape first steps back from missing mate")
	await key(KEY_ESCAPE,true); await key(KEY_ESCAPE,false)
	check(not selector.visible and game.character == "jp" and FileAccess.get_file_as_bytes(Save.PATH) == unchanged_disk,"Escape at P1 cancels transaction without save or stage start")
	await tap(map.play_button); selector = map.friend_panel
	await tap(selector.choices.theo); await tap(selector.choices.mei)
	selector._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var selection_time: float = selector.elapsed; selector._process(0.5)
	check(selector.elapsed == selection_time,"Backgrounding freezes official character animation")
	selector.confirm_selection(); check(game.mode == "menu","Backgrounded selector cannot confirm")
	selector._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await tap(selector.start_button)
	check(game.mode == "play" and game.level_id == "1-1" and game.party_session.active and roster(game,"cpu","theo","mei"),"Official Start commits selected party and starts the originally selected stage")
	check(game.party_session.runtime.actors[1].cpu and game.party_session.runtime.actors[1].character == "mei","First real stage creates selected computer actor")
	check(game.save.party_confirmed and progress(game.save) == before and button(game.ui,"Change character") == null,"Only explicit Start confirms; gameplay exposes no selection and grants no progress")
	await back_to_map(game); map = game.campaign_map; settle_map(map)
	await tap(map.friend_button); selector = map.friend_panel
	await tap(selector.choices.mei)
	check(selector.draft.p1 == "mei" and selector.draft.p2 == "theo" and roster(game,"cpu","theo","mei"),"P1 choosing current mate swaps draft only")
	await tap(selector.choices.theo); await tap(selector.start_button)
	check(roster(game,"cpu","mei","theo") and game.mode == "menu" and not selector.visible,"Explicit map change commits swap and returns to map, not gameplay")
	await choose_party(map,"cpu","theo","mei")
	await tap(map.friend_button); selector = map.friend_panel
	await tap(selector.choices.theo); await tap(selector.choices.theo)
	check(selector.draft.p1 == "mei" and selector.draft.p2 == "theo","Partner choosing P1 swaps identities rather than duplicating")
	await tap(selector.cancel_button)
	check(roster(game,"cpu","theo","mei"),"Cancelling swapped draft leaves selected party intact")
	await choose_party(map,"p2","theo","mei")
	check(roster(game,"p2","theo","mei") and progress(game.save) == before,"Mode/cast confirmation preserves progression and locks")
	var saved := Save.read_save()
	check(saved.friend == "theo" and saved.party_mode == "p2" and saved.party_mate == "mei" and saved.party_confirmed,"Confirmed mode/cast marker persists atomically")
	check(DirAccess.copy_absolute(Save.PATH,restart_fixture("p2")) == OK,"Save actual GUI bytes for independent P2 restart")
	game.queue_free(); await process_frame
	game = await new_game()
	check(roster(game,"p2","theo","mei") and game.save.party_confirmed and progress(game.save) == before,"Fresh host startup restores confirmed party and progress")
	await enter_map(game); map = game.campaign_map
	check(not map.friend_panel.visible and not game.ui.has_node("TitleMenu"),"Restart reaches map without forced selection")
	await start_next(map)
	check(game.mode == "play" and game.level_id == "1-1" and game.party_session.active,"Confirmed map Play skips selection on later entry")
	check(game.party_session.runtime.actors.size() == 2 and game.party_session.runtime.actors[0].character == "theo" and game.party_session.runtime.actors[1].character == "mei" and not game.party_session.runtime.actors[1].cpu and not game.party_session.runtime.actors[1].remote,"Stage creates chosen local humans, not online/CPU")
	game.party_session.input.read(0,"p2"); game.party_session.input.read(1,"p2")
	await key(KEY_D,true); check(game.party_session.input.read(1,"p2").right and not game.party_session.input.read(0,"p2").right,"Engine P2 keys do not move P1")
	await key(KEY_D,false); check(not game.party_session.input.read(1,"p2").right,"Engine P2 release clears movement")
	await back_to_map(game); map = game.campaign_map; settle_map(map)
	check(roster(game,"p2","theo","mei") and not map.friend_panel.visible,"Gameplay Map preserves party without reselection")
	await tap(map.play_button)
	game._complete_level(); await process_frame # Synthetic clear: settlement routing only.
	if game.mode == "story": await tap(game.story.skip_button)
	await tap(button(game.ui,"Settle up")); await tap(button(game.ui,"Next level"))
	map = game.campaign_map; settle_map(map)
	check(game.mode == "menu" and map.selected == "1-2" and roster(game,"p2","theo","mei") and not map.friend_panel.visible and not game.ui.has_node("TitleMenu"),"Next level goes directly to next map stop with confirmed party")
	await tap(map.play_button)
	check(game.mode == "play" and game.level_id == "1-2" and game.party_session.active and game.party_session.runtime.actors[1].character == "mei","Next real stage retains party without official screen repeating")
	await back_to_map(game); map = game.campaign_map; settle_map(map); before = progress(game.save)
	await choose_party(map,"cpu","theo","mei")
	check(DirAccess.copy_absolute(Save.PATH,restart_fixture("cpu")) == OK,"Save GUI bytes for independent CPU restart")
	await start_next(map)
	check(game.party_session.active and game.party_session.runtime.actors[1].cpu,"Official CPU mode creates real computer actor")
	await back_to_map(game); map = game.campaign_map; settle_map(map)
	await choose_party(map,"solo","theo","")
	await start_next(map)
	check(game.mode == "play" and not game.party_session.active and game.character == "theo","Official Solo starts no active partner")
	check(progress(game.save) == before and Save.read_save().party_mode == "solo","Solo keeps progress and saved explicit mode")
	check(DirAccess.copy_absolute(Save.PATH,restart_fixture("solo")) == OK,"Save GUI bytes for independent Solo restart")
	game.queue_free(); await process_frame
	game = await new_game(); check(game.party_session.runtime.mode == "solo" and game.character == "theo" and game.save.party_confirmed,"Restart honors explicitly confirmed Solo")
	await enter_map(game); map = game.campaign_map
	await choose_party(map,"cpu","theo","mei"); await tap(map.title_button)
	var title = game.title_menu; title.set_process(false); title.tick(0.5)
	await tap(title.buttons.new); title.tick(0.5); await tap(title.buttons.reset)
	check(roster(game,"cpu","theo","mei") and game.save.party_confirmed and game.save.cleared.is_empty() and game.save.kitty == 0,"New story resets progress but retains explicit official choice")
	if game.mode == "story": await tap(game.story.skip_button)
	map = game.campaign_map
	await tap(map.title_button); title = game.title_menu; title.set_process(false); title.tick(0.5)
	await tap(title.buttons.free); await tap(button(game.ui,"Mei"))
	check(roster(game,"cpu","mei","theo"),"Free-play current-mate selection retains distinct pair")
	saved = Save.read_save(); check(saved.friend == "mei" and saved.party_mode == "cpu" and saved.party_mate == "theo" and saved.party_confirmed,"Free-play swap retains explicit choice on disk")
	await tap(button(game.ui,"1-1")); check(game.mode == "play" and game.party_session.active and game.party_session.runtime.actors[0].character == "mei" and game.party_session.runtime.actors[1].character == "theo","Free-play starts actual swapped actors")
	var disk_before := FileAccess.get_file_as_bytes(Save.PATH)
	game._choose_preview_character("jp"); check(roster(game,"cpu","mei","theo") and FileAccess.get_file_as_bytes(Save.PATH) == disk_before,"Gameplay cannot alter selected party")
	await back_to_map(game); game._choose_preview_character("bot")
	check(roster(game,"cpu","mei","theo") and FileAccess.get_file_as_bytes(Save.PATH) == disk_before,"Invalid preview character does not write save")
	game.queue_free(); await process_frame
	game = await new_game(); check(roster(game,"cpu","mei","theo"),"Restart preserves preview swap")
	await enter_map(game)
	# Completed-save geometry fixture only, never gameplay-clear evidence.
	for world in range(1,7):
		for stage in range(1,7): game.save.cleared["%d-%d" % [world,stage]] = true
	game._show_campaign(); map = game.campaign_map; settle_map(map)
	for world in range(1,7):
		await tap(button(map.header,"Worlds")); await tap(map.world_buttons[world]); await verify_panel_targets(map,map.stage_panel,"World %d Stage" % world)
		await tap(map.stage_buttons["%d-S" % world]); settle_map(map)
		check(map.card.visible and map.selected == "%d-S" % world and not map.play_button.disabled,"Real bottom-row tap reaches World %d bonus card" % world)
		await verify_panel_targets(map,map.card,"World %d Card" % world); await tap(button(map.card,"Close"))
	game.queue_free(); await process_frame; restore_save()
	check(FileAccess.get_file_as_bytes(Save.PATH) == original_save if had_save else not FileAccess.file_exists(Save.PATH),"Suite restores original save byte-for-byte")
	print("Official native selection: %d checks, %d failures. Real GUI/input; synthetic clear, no physical-device/full-route claim." % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
