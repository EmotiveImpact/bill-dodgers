extends SceneTree
## Explicit synthetic objective fixtures test campaign UI/story/persistence only.
## The input-driven world suites separately prove actual gameplay clears.
const Campaign = preload("res://src/campaign_progression.gd")
const SaveStore = preload("res://src/save_store.gd")
class AudioLog extends RefCounted:
	var enabled := false
	var endings := 0
	func set_paused(_value: bool) -> void: pass
	func stop_music() -> void: pass
	func start_music(_boss: bool = false) -> void: pass
	func start_ending() -> void: endings += 1
	func play_effect(_effect: String) -> void: pass
	func shutdown() -> void: pass
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL: ", message)
func button(game, label: String) -> Button:
	return preload("res://tests/campaign_ui_support.gd").button(game, label)

func tap(control: Button) -> void:
	# Title options now scroll at fixed touch density. Settle containers and
	# reveal the requested control before dispatching the unchanged real tap.
	await process_frame
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control); await process_frame
		ancestor = ancestor.get_parent()
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 9; event.position = root.get_screen_transform() * control.get_global_rect().get_center(); event.pressed = pressed
		Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
func run() -> void:
	# Headless defaults to a100x100 placeholder window, which is not a supported
	# frontend fixture. Use the same real desktop/canvas dimensions as GUI suites.
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(960,540)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var game = load("res://main.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	game.audio.shutdown(); game.audio.queue_free(); game.audio = AudioLog.new()
	game.credits_roll.set_process(false)
	await process_frame
	game.save = {"schema":1,"receipts":{},"cleared":{},"seen":{},"skills":[],"kitty":0}
	game.character = "mei"
	game._show_campaign()
	check(not game._show_credits() and button(game,"The credits") == null, "Fresh campaign cannot open or advertise credits")
	game.save.cleared["6-6"] = true
	check(not game._show_credits(), "Orphan final-stage clear cannot bypass verified chain")
	game.save.cleared.clear()
	var seen: Array[String] = []
	var expected_kitty := 0
	for world in range(1,7):
		for stage in range(1,7):
			var id := "%d-%d" % [world,stage]
			check(game.start_campaign_level(id), "Campaign enters unlocked " + id)
			if Campaign.BEFORE_SCENES.has(id):
				var scene: String = Campaign.BEFORE_SCENES[id]
				check(game.mode == "story" and game.story.scene_id == scene and game.story.playing, "Original pre-stage scene " + scene)
				seen.append(scene); game.story.skip()
			check(game.mode == "play" and game.campaign_run and not game.save.cleared.has(id), "Entry itself grants no clear " + id)
			check(game.character == "mei" and not game.ui.has_node("TitleMenu") and not game.ui.has_node("CampaignMap"), "All36 stage entries retain chosen character and skip title/reselection " + id)
			game.score = 1 # Explicit accounting fixture, not a gameplay reward claim.
			expected_kitty += 1 + game.coins.size() # Source sweep banks untouched authored seeds too.
			game._complete_level()
			if Campaign.AFTER_SCENES.has(id):
				var scene: String = Campaign.AFTER_SCENES[id]
				check(game.mode == "story" and game.story.scene_id == scene and game._story_return_mode == "clear", "Original post-clear scene " + scene)
				game._campaign_next()
				check(game.mode == "story" and not game.credits_roll.playing, "Next cannot skip active story " + scene)
				seen.append(scene); game.story.skip()
			check(game.mode == "clear" and game.save.cleared.get(id,false), "Fixture clear restores settlement " + id)
			var kitty: int = game.save.kitty
			game._complete_level()
			check(game.save.kitty == kitty, "Duplicate settlement does not bank twice " + id)
			game._campaign_next()
			if id != "6-6":
				var next_id := "%d-%d" % [world,stage+1] if stage<6 else "%d-1" % (world+1)
				check(game.mode == "menu" and game.campaign_target == next_id, "Source next main route " + next_id)
				check(game.character == "mei" and is_instance_valid(game.campaign_map) and not game.campaign_map.friend_panel.visible and not game.ui.has_node("TitleMenu"), "Next map preserves hero and never forces character selection " + next_id)
	check(game.mode == "credits" and game.credits_roll.playing and not game.ui.visible and game.audio.endings == 1, "Final ending routes to native credits and ending audio hook")
	var saved := SaveStore.read_save()
	check(saved.cleared.size() == 36 and saved.kitty == expected_kitty, "All main synthetic clears and one-time accounting persist (clears=%d kitty=%d)" % [saved.cleared.size(),saved.kitty])
	for scene in seen: check(saved.seen.get(scene,false), "Source scene persistence " + scene)
	check(seen.size() == 19 and Campaign.snapshot(saved,game.catalog).credits_unlocked, "All19 main progression scenes and verified credits complete")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var elapsed: float = game.credits_roll.elapsed
	game.credits_roll.tick(1)
	check(game.credits_roll.elapsed == elapsed, "Focus loss pauses credit timeline")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game.credits_roll.tick(1)
	check(game.credits_roll.elapsed == elapsed+1, "Focus return resumes credit timeline")
	await tap(game.credits_roll.skip_button)
	check(game.mode == "menu" and game.ui.visible and is_instance_valid(game.title_menu) and not game.credits_roll.visible, "Actual Skip touch returns to source title menu")
	check(game.gameplay_contacts.is_empty() and game.touches.is_empty(), "Credits touch never leaks gameplay movement")
	check(button(game,"The credits") != null, "Completed menu offers source credits replay")
	var before := JSON.stringify(SaveStore.read_save())
	await tap(button(game,"The credits"))
	check(game.mode == "credits" and game.audio.endings == 2, "Actual credits button replays without award")
	game.credits_roll.tick(game.credits_roll.duration+0.601)
	check(game.mode == "menu" and JSON.stringify(SaveStore.read_save()) == before, "Timed replay returns without modifying save")
	game._show_credits(); game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(game.mode == "menu", "Android Back leaves credits rather than quitting")
	game.audio.shutdown(); game.queue_free(); await create_timer(0.2).timeout
	print("Full campaign completion: %d checks, %d failures (synthetic UI/story/accounting fixtures)" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
