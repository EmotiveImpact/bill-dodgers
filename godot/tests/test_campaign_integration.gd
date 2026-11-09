extends SceneTree
## Explicit GUI/save fixtures, not a replacement for objective progression tests.
const Campaign = preload("res://src/campaign_progression.gd")
const SaveStore = preload("res://src/save_store.gd")
class AudioLog extends RefCounted:
	var enabled := false
	var paused := false
	var music_requested := false
	func set_enabled(value: bool) -> void: enabled = value
	func set_paused(value: bool) -> void: paused = value
	func play_effect(_effect: String) -> void: pass
	func start_music(_boss: bool = false) -> void: music_requested = true
	func stop_music() -> void: music_requested = false
	func shutdown() -> void: pass
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)
func button(game, prefix: String) -> Button:
	return preload("res://tests/campaign_ui_support.gd").button(game, prefix)

func touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 5; event.position = root.get_screen_transform() * point; event.pressed = pressed
	Input.parse_input_event(event); Input.flush_buffered_events()
	await process_frame
func tap(control: Button) -> void:
	var point := control.get_global_rect().get_center()
	await touch(point, true); await touch(point, false)
func fresh(game) -> void:
	game.save = {"schema": 1, "receipts": {}, "cleared": {}, "seen": {}, "skills": [], "kitty": 0}
	game.world_selected = 1
	game._show_menu()
func clear_fixture(game) -> void:
	# Only UI regression setup. Full input-driven suites prove real objectives.
	game._complete_level()
func seed_main_clears(game, worlds: int) -> void:
	for world in range(1, worlds + 1):
		for stage in range(1, 7): game.save.cleared["%d-%d" % [world, stage]] = true
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	game.audio.shutdown(); game.audio.queue_free()
	game.audio = AudioLog.new()
	await process_frame
	fresh(game)
	check(button(game, "Play campaign") != null and button(game, "1-1") != null, "Development picker remains available alongside explicit campaign entry")
	await tap(button(game, "Play campaign"))
	check(game.mode == "menu" and game.campaign_view and not game.campaign_run, "Dispatched touch opens campaign without starting gameplay")
	check(not button(game, "1-1").disabled and button(game, "1-2").disabled and button(game, "1-S").disabled, "Fresh campaign exposes only source first stage")
	check(button(game, "WORLD 2").disabled, "Fresh World 2 path remains locked")
	var old_level: String = game.level_id
	check(not game.start_campaign_level("2-1") and game.level_id == old_level, "Programmatic locked entry also fails closed")
	check(not game.start_campaign_level("4-1"), "Later native world cannot bypass campaign prerequisites")
	await tap(button(game, "1-1"))
	check(game.campaign_map.friend_panel.visible and game.mode == "menu", "First map Play requests explicit official party confirmation")
	var selector = game.campaign_map.friend_panel
	while selector.draft.mode != "solo": await tap(selector.mode_button)
	await tap(selector.start_button)
	check(game.campaign_run and game.campaign_view and game.level_id == "1-1" and game.mode == "story", "Real campaign entry starts unseen intro before gameplay")
	check(game.save.seen.get("1-intro", false), "Campaign intro marks native seen state")
	check(not game.start_campaign_level("1-1") and game.mode == "story" and game.story.playing and not game.ui.visible, "Duplicate campaign start cannot reload behind active story")
	game._pause()
	check(game.mode == "paused" and game.story.playing, "Campaign introduction supports pause")
	await tap(button(game, "Resume"))
	check(game.mode == "story" and game.story.visible and not game.story.paused, "Dispatched touch resumes paused story and restores overlay")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await tap(button(game, "Level map"))
	check(game.mode == "menu" and game.campaign_view and not game.story.playing and not game.campaign_run, "Leaving paused intro returns to campaign without stale playback")
	check(game.start_campaign_level("1-1") and game.mode == "play", "Seen campaign intro does not replay on normal entry")
	check(not game.start_campaign_level("1-1") and game.mode == "play", "Duplicate start cannot reset an active run after intro was seen")
	game.score = 5
	clear_fixture(game)
	check(game.mode == "clear" and game.save.cleared.get("1-1", false) and game.save.kitty == 5, "Explicit completion fixture uses existing one-time accounting")
	game._settle_up()
	check(button(game, "Next level") != null, "Campaign settlement offers source next-map handoff")
	await tap(button(game, "Next level"))
	check(game.mode == "menu" and game.campaign_view and game.campaign_target == "1-2", "Next level focuses first open main, not earlier bonus")
	check(not button(game, "1-S").disabled and not button(game, "→ 1-2").disabled, "1-1 opens both correct source routes without receipt gate")
	check(game.save.receipts.is_empty() and game.save.kitty == 5, "Navigation never awards receipts or coins")
	check(game.start_campaign_level("1-2"), "Unlocked native sequel can start")
	game._campaign_next(); game._settle_up()
	check(game.mode == "play" and game.level_id == "1-2", "Stale clear/next callbacks cannot replace active gameplay")
	game.hearts = 0; game._game_over()
	await tap(button(game, "Back to worlds"))
	check(game.mode == "menu" and game.campaign_view, "Knockout-to-map preserves campaign context")
	check(game.start_campaign_level("1-2"), "Campaign can restart after leaving knockout")
	clear_fixture(game); game._campaign_next()
	check(game.campaign_target == "1-3", "Source main ordering continues after actual accounting")
	check(game.start_campaign_level("1-3"), "Campaign bus starts through unlocked path")
	clear_fixture(game)
	check(game.mode == "story" and game.story.playing and game._story_return_mode == "clear", "Bus clear plays clue before returning to settlement")
	game.story.skip()
	check(game.mode == "clear" and game.save.seen.get("1-clue", false), "Skipping clue returns to clear, not active gameplay")
	game._settle_up(); game._return_to_map()
	check(game.start_campaign_level("1-3") and game.mode == "play", "Replaying a clue stage does not play post-clear story before entry")
	clear_fixture(game)
	check(game.mode == "story", "Source clue repeats after replay clear despite seen flag")
	game.story.skip()
	seed_main_clears(game, 1)
	check(game.start_campaign_level("1-6") and game.mode == "story", "Unseen boss story opens before native Binman entry")
	game.story.skip(); clear_fixture(game); game._campaign_next()
	check(game.campaign_target == "2-1" and game.campaign_map.auto_target == "2-1", "World boss clear targets next island while source walker travels, not remaining bonus")
	check(game.start_campaign_level("2-1") and game.mode == "story", "World 2 first entry opens its source introduction")
	game.story.skip(); game._pause()
	await tap(button(game, "Level map"))
	check(game.mode == "menu" and game.campaign_view and game.world_selected == 2, "Pause-to-map keeps campaign world context")
	seed_main_clears(game, 2)
	game.save.skills = ["slide", "double-jump"]
	check(game.start_campaign_level("2-6") and game.mode == "story", "Checkout source boss story precedes its puzzle")
	game.story.skip(); clear_fixture(game)
	var saved: Dictionary = SaveStore.read_save()
	check(saved.cleared.get("2-6", false) and saved.skills == ["slide", "double-jump"], "Campaign uses existing native disk save and retained earned skills")
	game._settle_up(); game._campaign_next()
	check(game.mode == "menu" and game.campaign_target == "3-1" and game.campaign_map.auto_target == "3-1", "Checkout targets actual World3 bridge destination, never skips to a bonus")
	check(not button(game, "→ 3-1").disabled and game.start_campaign_level("3-1") and game.mode == "story", "Unlocked native World 3 starts its own intro")
	game.story.skip(); clear_fixture(game); game._campaign_next()
	check(game.campaign_target == "3-2" and not button(game, "→ 3-2").disabled and game.start_campaign_level("3-2") and game.mode == "play", "Native queue continues campaign without replaying intro")
	clear_fixture(game); game._campaign_next()
	check(game.campaign_target == "3-3" and not button(game, "→ 3-3").disabled and game.start_campaign_level("3-3") and game.mode == "play", "Native night continues campaign without a duplicate intro")
	clear_fixture(game)
	check(game.mode == "story" and game._story_return_mode == "clear", "Night clue follows native clear before settlement")
	game.story.skip(); game._campaign_next()
	check(game.campaign_target == "3-4" and not button(game, "→ 3-4").disabled and game.start_campaign_level("3-4") and game.mode == "play", "Native Big top starts after night clue settlement")
	clear_fixture(game); game._campaign_next()
	check(game.campaign_target == "3-5" and not button(game, "→ 3-5").disabled and game.start_campaign_level("3-5") and game.mode == "play", "Native Hay ride follows Big top without granting a new card")
	clear_fixture(game); game._campaign_next()
	check(game.campaign_target == "3-6" and not button(game, "→ 3-6").disabled and game.start_campaign_level("3-6") and game.mode == "story", "Native Ticket Tout opens the original boss story")
	game.story.skip(); clear_fixture(game); game._campaign_next()
	check(game.campaign_target == "4-1" and not button(game, "→ 4-1").disabled, "Native holiday destination unlocks after festival")
	check(not game.save.cleared.has("4-1"), "Boundary navigation grants no automatic clear")
	await tap(button(game, "Stage previews"))
	check(not game.campaign_view and not game.campaign_run and game.mode == "menu", "Development picker is an explicit separate exit")
	check(game.load_level("4-1") and not game.campaign_run and not game.status.contains("LAYOUT PREVIEW"), "Direct development level remains separate from campaign entry")
	game.level_id = "7-1" # Explicit invalid-ID guard fixture, never an authored stage.
	game._complete_level()
	check(game.mode == "play" and not game.save.cleared.has("4-1"), "Unknown-level completion remains blocked")
	fresh(game); game.save.cleared["2-6"] = true
	game._show_campaign()
	check(game.save.cleared.has("2-6") and button(game, "WORLD 2").disabled, "Orphan development history is retained without forging campaign prerequisites")
	game.load_level("1-1"); clear_fixture(game); game._settle_up()
	check(button(game, "Next level") == null and button(game, "Back to worlds") != null, "Direct development runs retain their separate settlement flow")
	game._open_story("1-intro")
	check(game.mode == "story" and game.story.playing, "Intentional replacement fixture opens story")
	check(game.load_level("2-1") and game.mode == "play" and not game.story.playing and game.ui.visible, "Intentional direct replacement stops old story and restores the live HUD")
	game.audio.shutdown(); game.queue_free()
	await create_timer(0.1).timeout
	print("Campaign host integration: %d checks, %d failures (explicit GUI fixtures)" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
