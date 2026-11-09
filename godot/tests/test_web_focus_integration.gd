extends SceneTree
## Real-main regression for Web's exact WINDOW focus notifications.
## Synthetic input plus explicit story/credits fixtures, not browser/device QA.
const Keys = preload("res://tests/local_two_player_input.gd")
const Support = preload("res://tests/test_support.gd")
var checks := 0
var failures: Array[String] = []
var keys = Keys.new()
var game
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)
func touch(position: Vector2, pressed: bool, index: int) -> void:
	var event := InputEventScreenTouch.new()
	event.position = root.get_screen_transform() * position
	event.index = index; event.pressed = pressed
	Input.parse_input_event(event); Input.flush_buffered_events()
	await process_frame
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	Support.silence(game)
	game._show_menu(); game.character = "jp"
	game.save = {"schema": 1, "receipts": {}, "skills": [], "seen": {}}
	check(game.configure_party("p2", "maya") and game.load_level("1-1", false), "actual local party loads")
	var actors: Array = game.party_session.runtime.actors
	keys.frame(game, {}, {}, 0)
	var p1 := {"right": true, "shoot": true}
	var p2 := {"left": true, "shoot": true}
	await touch(game.buttons.right.get_center(), true, 11)
	await touch(game.buttons.shoot.get_center(), true, 12)
	var initial: Array = actors.map(func(a): return a.player)
	keys.frame(game, p1, p2)
	print("FOCUS_PRECONDITION before=", initial, " after=", actors.map(func(a): return a.player))
	check(not game.touches.is_empty() and not game.joystick_contacts.is_empty(), "actual held multitouch registered")
	check(actors[0].player.x > initial[0].x and actors[1].player.x < initial[1].x, "independent held human keys move both actors")
	var positions: Array = actors.map(func(a): return a.player)
	var elapsed: float = game.elapsed
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(game.mode == "paused" and game.audio.paused and game.mobile_game_menu.opened, "Web window focus loss pauses gameplay and audio")
	check(game.touches.is_empty() and game.gameplay_contacts.is_empty() and game.joystick_contacts.is_empty(), "Web focus loss clears all contact ownership")
	keys.frame(game, p1, p2)
	check(game.elapsed == elapsed and actors.map(func(a): return a.player) == positions, "paused production physics does not advance")
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	check(game.mode == "paused" and game.audio.paused, "Web focus regain never auto-resumes gameplay")
	game._resume()
	check(game.mode == "play" and not game.audio.paused, "explicit Resume restores gameplay")
	keys.frame(game, p1, p2)
	check(actors.map(func(a): return a.player) == positions, "keys held across focus remain suppressed after Resume")
	check(game.touches.is_empty() and game.joystick_contacts.is_empty(), "old fingers are not reconstructed on Resume")
	# Releasing the original touch IDs must not revive their old actions.
	await touch(game.buttons.right.get_center(), false, 11)
	await touch(game.buttons.shoot.get_center(), false, 12)
	keys.frame(game)
	check(actors.map(func(a): return a.player) == positions, "neutral key/touch release rearms without movement")
	keys.frame(game, p1, p2)
	check(actors[0].player.x > positions[0].x and actors[1].player.x < positions[1].x, "fresh keys move independent actors after focus recovery")
	keys.release()
	game._show_menu(); game._open_story("1-intro")
	check(game.mode == "story" and game.story.playing, "real story starts")
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(game.mode == "paused" and game._paused_mode == "story" and game.story.paused and game.audio.paused, "Web focus loss pauses story instead of entering gameplay")
	var story_time: float = game.story.elapsed
	game.story._process(1)
	check(game.story.elapsed == story_time, "paused story clock frozen")
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	check(game.mode == "paused" and game.story.paused, "Web focus regain does not auto-resume story")
	game._resume()
	check(game.mode == "story" and not game.story.paused and game.audio.paused, "explicit Resume returns to story with gameplay music paused")
	game.story.skip()
	check(game.mode == "menu", "story exits to original menu")
	# Isolated credits fixture tests interruption, not campaign unlock authority.
	game.mode = "credits"
	game.credits_roll.play(false, true)
	game.audio.set_paused(false)
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(game.credits_roll.paused and game.audio.paused, "Web credits focus loss pauses roll and music")
	var credits_time: float = game.credits_roll.elapsed
	game.credits_roll.tick(1)
	check(game.credits_roll.elapsed == credits_time, "unfocused credits do not advance")
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	check(not game.credits_roll.paused and not game.audio.paused and game.mode == "credits", "Web credits focus regain restores credits only")
	game.credits_roll.stop()
	keys.release(); game.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	print("Web focus real-main integration: %d checks, %d failures. Synthetic WINDOW notifications, not an actual browser/device run." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
