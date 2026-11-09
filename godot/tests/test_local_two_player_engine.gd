extends SceneTree
## Bounded actual-main synthetic-key fixtures for all six world families.
## Explicit lifecycle/camera fixture state is NOT full-route or survival evidence.
const Keys = preload("res://tests/local_two_player_input.gd")
const DT := 1.0 / 60.0
var keys = Keys.new()
var game
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)

func fresh(id: String) -> void:
	keys.release()
	game._show_menu()
	game.character = "jp"
	game.save = {"schema": 1, "receipts": {}, "skills": [], "seen": {}}
	check(game.configure_party("p2", "maya") and game.load_level(id), id + " explicit local two-player selection loads")
	keys.frame(game) # Rearm mode-change suppression via actual neutral poll.

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	print("ASSISTS bounded fixtures: explicit down/all-down/clear states, camera positions; no difficulty or physical-device claim.")
	for world in range(1, 7):
		var id := "%d-1" % world
		fresh(id)
		_test_inputs(id)
		fresh(id)
		_test_lifecycle(id)
		fresh(id)
		_test_camera(id)
	keys.release()
	game.queue_free()
	await process_frame
	print("Local P2 actual engine: %d checks, %d failures across six worlds; synthetic input only." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_inputs(id: String) -> void:
	var s = game.party_session
	var p1 = s.runtime.actors[0]
	var p2 = s.runtime.actors[1]
	check(not p1.cpu and not p2.cpu and s.runtime.mode == "p2", id + " both slots are humans, not hidden CPU")
	var a: Vector2 = p1.player
	var b: Vector2 = p2.player
	var time: float = game.elapsed
	keys.frame(game, {"left": true, "shoot": true}, {"right": true, "shoot": true, "aim": true})
	check(p1.player.x < a.x and p2.player.x > b.x, id + " opposing real key sets move independent actors")
	check(is_equal_approx(game.elapsed - time, DT), id + " one native poll advances shared clock once")
	check(game.bullets.any(func(shot): return not shot.enemy and shot.get("owner_slot", -1) == 0) and game.bullets.any(func(shot): return not shot.enemy and shot.get("owner_slot", -1) == 1), id + " real keys emit separately owned shots")
	check(p2.shoot_diagonal and not p1.shoot_diagonal, id + " P2 W moving aim never leaks to P1")
	keys.frame(game)
	a = p1.player
	keys.frame(game, {}, {"jump": true})
	check(p2.velocity.y < 0 and not p2.grounded and p1.player == a, id + " G jumps only P2")
	keys.frame(game)
	keys.frame(game, {"jump": true}, {})
	check(p1.velocity.y < 0 and not p1.grounded, id + " Z independently jumps P1")
	keys.controls({"right": true, "shoot": true}, {"left": true, "shoot": true})
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	time = game.elapsed
	a = p1.player; b = p2.player
	keys.frame(game, {"right": true, "shoot": true}, {"left": true, "shoot": true})
	check(game.mode == "paused" and game.elapsed == time and p1.player == a and p2.player == b, id + " focus loss freezes both actors and shared world")
	game._resume()
	check(not s.input.read(0, "p2").right and not s.input.read(1, "p2").left and not s.input.read(0, "p2").shoot and not s.input.read(1, "p2").shoot, id + " resume suppresses held movement/fire for both")
	keys.frame(game)
	a = p1.player; b = p2.player
	keys.frame(game, {"right": true}, {"left": true})
	check(p1.player.x > a.x and p2.player.x < b.x, id + " release and repress independently rearms both slots")
	game._resize()
	check(not s.input.read(0, "p2").right and not s.input.read(1, "p2").left, id + " viewport resize suppresses both held controls")
	keys.release()
	check(game.player == p1.player and game.character == "jp" and not s.bridge.shared_phase, id + " engine frame restores P1 facade and closes shared pass")
	var old1 = p1
	var old2 = p2
	game._show_menu()
	game.load_level(id)
	check(s.runtime.actors[0] != old1 and s.runtime.actors[1] != old2 and s.runtime.actors.all(func(actor): return actor.hearts == 3 and not actor.down and not actor.cpu), id + " replay creates fresh local actors without previous transient state")

func _test_lifecycle(id: String) -> void:
	var s = game.party_session
	var p1 = s.runtime.actors[0]
	var p2 = s.runtime.actors[1]
	# Source spawn gap is exactly80; a real D tap brings the helper within80.
	keys.frame(game, {}, {"right": true})
	keys.frame(game)
	p1.mark_down(); s.bind(game, 0) # Deliberate lifecycle fixture, printed above.
	var time: float = game.elapsed
	for frame in 84: keys.frame(game)
	check(p1.down and game.mode == "play", id + " one downed human waits through strict1.4-second threshold")
	keys.frame(game)
	check(not p1.down and p1.hearts == 2 and p2.hearts == 3 and game.mode == "play", id + " ordinary idle frames let P2 rescue P1 after threshold")
	check(p1.invincible > 2.1 and p1.hurt_lock > 0.5, id + " rescued actor alone receives source protection and celebration")
	check(is_equal_approx(game.elapsed - time, 85 * DT), id + " rescue never doubles shared time")
	p1.mark_down(); p2.mark_down(); s.bind(game, 0)
	keys.frame(game)
	check(game.mode == "over", id + " both down opens real Continue")
	time = game.elapsed
	var camera: Vector2 = game.camera
	var waves := JSON.stringify(game.combat.waves)
	game._continue_level()
	check(game.mode == "play" and p1.hearts == 3 and p2.hearts == 3 and not p1.down and not p2.down, id + " real Continue revives both humans")
	check(game.elapsed == time and game.camera == camera and JSON.stringify(game.combat.waves) == waves, id + " Continue preserves shared encounter and camera")
	p2.mark_down(); s.bind(game, 0)
	game._complete_level() # Explicit clear settlement fixture, not route success.
	check(game.mode == "clear" and not p2.down and p2.hearts == 1 and p1.player_animation == "win" and p2.player_animation == "win", id + " clear settlement rescues downed P2 exactly once")
	time = game.elapsed
	keys.frame(game, {"right": true}, {"right": true})
	check(game.elapsed == time, id + " clear UI freezes native world input")

func _test_camera(id: String) -> void:
	var s = game.party_session
	var p1 = s.runtime.actors[0]
	var p2 = s.runtime.actors[1]
	# Explicit flat opening camera fixture, no claim of input traversal here.
	p1.player = Vector2(700, 482); p2.player = Vector2(900, 482)
	p1.mark_down(); s.bind(game, 0)
	game.camera = Vector2.ZERO; game.camera_speed = 0
	check(s.runtime.camera_actors().size() == 2 and s.runtime.camera_actors().has(p1), id + " downed human remains in camera roster")
	var wanted: float = minf(900 - game.view_width() * 0.45, 700 - 60)
	check(is_equal_approx(s.runtime.camera_follow_x(0, game.view_width(), game.level.w), wanted), id + " human camera uses both front and back source bounds")
	keys.frame(game)
	check(game.camera.x > 0 and game.camera.x <= wanted and game.mode == "play", id + " living P2 drives actual camera while P1 is down")
