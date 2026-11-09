extends SceneTree
## Actual-main phase-order fixtures. Positions/health below are setup, not route assists.
var game
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)
func setup() -> Array:
	game._show_menu()
	game.character = "jp"
	game.save = {"schema":1, "receipts":{}, "skills":[]}
	game.configure_party("p2", "maya")
	game.load_level("1-1")
	return game.party_session.runtime.actors
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	var actors := setup()
	var first = actors[0]
	var second = actors[1]
	first.player = Vector2(500, 482)
	first.mark_down()
	first.revive = 0.5
	first.invincible = 1
	first.power_time = 1
	first.power = "debit"
	first.hurt_lock = 0.7
	first.cooldown = 0.8
	second.player = Vector2(580, 482)
	game.party_session.bind(game, 0)
	game.party_session.step(game, 1.0/60, {}, {"left":true})
	check(is_equal_approx(first.revive, 0.5 - 1.0/120), "Down P1 sees later P2 old position at strict boundary")
	check(is_equal_approx(second.player.x, 575.5), "Later P2 then moves normally")
	check(is_equal_approx(first.invincible, 1 - 1.0/60) and is_equal_approx(first.power_time, 1 - 1.0/60), "Downed timer prelude advances invulnerability and power once")
	check(is_equal_approx(first.hurt_lock, 0.7) and is_equal_approx(first.cooldown, 0.8), "Downed early return freezes ordinary movement timers")
	game.party_session.step(game, 1.0/60, {}, {})
	check(is_equal_approx(first.revive, 0.5 + 1.0/120), "Next P1 phase observes P2 new nearby position")
	actors = setup()
	first = actors[0]; second = actors[1]
	first.player = Vector2(580, 482)
	second.player = Vector2(500, 482)
	second.mark_down(); second.revive = 0.5
	game.party_session.bind(game, 0)
	game.party_session.step(game, 1.0/60, {"left":true}, {})
	check(is_equal_approx(second.revive, 0.5 + 1.0/60), "Down P2 sees earlier P1 already moved inside revive boundary")
	actors = setup()
	first = actors[0]; second = actors[1]
	first.player = Vector2(500, 900)
	first.hearts = 1
	first.grounded = false
	first.scene_state.safe_position = Vector2(500, 482)
	second.player = Vector2(530, 482)
	game.party_session.bind(game, 0)
	game.party_session.step(game, 1.0/60, {}, {})
	check(first.down and first.hearts == 0, "Real fall damage knocks P1 down during its actor phase")
	check(is_zero_approx(first.revive), "A newly downed actor receives no retroactive same-frame revive tick")
	game.queue_free()
	await process_frame
	print("Party revive order: %d checks, %d failures. Boundary fixtures, not route/device acceptance." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
