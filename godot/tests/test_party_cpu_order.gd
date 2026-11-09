extends SceneTree
## Boundary fixtures for source CPU-before-all-players intent order.
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	game.character = "jp"
	game.save = {"schema":1, "receipts":{}, "skills":[]}
	game.configure_party("cpu", "maya")
	game.load_level("1-1")
	var session = game.party_session
	var leader = session.runtime.actors[0]
	var mate = session.runtime.actors[1]
	# Exactly at the source >26px follow threshold before human movement.
	leader.player = Vector2(636, 482)
	mate.player = Vector2(500, 482)
	session.bind(game, 0)
	game.step(1.0 / 60, {"right":true})
	check(is_equal_approx(mate.player.x, 500), "CPU intent samples old human position at strict follow threshold")
	check(is_equal_approx(leader.player.x, 640.5), "Human moves normally after CPU intent is gathered")
	check(is_equal_approx(game.elapsed, 1.0 / 60), "World time still advances once")
	# Catch-up must see the human grounded at frame start, even if this frame
	# makes the human jump. No manual relocation happens after this setup.
	leader.player = Vector2(650, 482)
	leader.grounded = true
	leader.velocity = Vector2.ZERO
	leader.jump_held = false
	mate.player = Vector2(100, 482)
	mate.ai.far_time = 1.61
	mate.velocity = Vector2.ZERO
	mate.grounded = true
	session.bind(game, 0)
	game.step(1.0 / 60, {"jump":true})
	check(session.ai.events.size() == 1 and session.ai.events[0].kind == "catch_up", "CPU catch-up reads frame-start grounded human")
	check(session.ai.events[0].to == Vector2(630, 482), "Catch-up destination uses old human feet before jump")
	check(not leader.grounded and leader.player.y < 482 and mate.player.x > 600, "Both actors move once after catch-up")
	game.queue_free()
	await process_frame
	print("Party CPU intent order: %d checks, %d failures. Boundary fixtures, not route/device acceptance." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
