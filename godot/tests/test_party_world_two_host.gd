extends SceneTree
## Actual main/session scene boundaries. Deliberate placement and phase setup,
## not ordinary-input complete routes or physical-device acceptance.
var checks := 0
var failures := 0
var game
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func fresh(id: String, mode := "p2") -> void:
	game._show_menu()
	game.character = "jp"
	game.save = {"schema": 1, "receipts": {}, "skills": [], "seen": {}}
	check(game.configure_party(mode, "maya") and game.load_level(id) and game.party_session.active, id + " actual party loaded")
func place(first: Vector2, second: Vector2, camera: Vector2) -> void:
	var actors: Array = game.party_session.runtime.actors
	for index in range(actors.size()):
		actors[index].player = first if index == 0 else second
		actors[index].velocity = Vector2.ZERO
		actors[index].grounded = true
		actors[index].on_platform = false
		actors[index].invincible = 0.0
		actors[index].hurt_lock = 0.0
		actors[index].down = false
		actors[index].hearts = 3
		actors[index].scene_state.safe_position = actors[index].player
	game.camera = camera
	game.camera_speed = 0
	game.camera_lock = null
	game.party_session.bind(game, 0)
func complete_waves() -> void:
	for wave in game.combat.waves:
		wave.started = true; wave.done = true; wave.index = wave.group.size()
func step(dt: float, first: Dictionary = {}, second: Dictionary = {}) -> void:
	game.party_session.step(game, dt, first, second)
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	_test_scene()
	_test_checkpoint()
	_test_ice()
	_test_checkout()
	game.queue_free()
	await process_frame
	print("W2 actual party host: %d checks, %d failures. Boundary fixtures, not full routes." % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_scene() -> void:
	for id in ["2-1", "2-3"]:
		fresh(id)
		complete_waves()
		var scene_x: float = game.level.scenes[0][0]
		place(Vector2(scene_x - 230, 482), Vector2(scene_x - 40, 482), Vector2(game.world_two.camera_cap(game), 0))
		var session = game.party_session
		var p1 = session.runtime.actors[0]
		var p2 = session.runtime.actors[1]
		p1.mark_down()
		p2.hearts = 1
		session.bind(game, 0)
		step(0)
		check(game.world_two.wiping and game.mode == "play" and p1.down, id + " living P2 starts scene while P1 remains rescueable")
		var start: Vector2 = p2.player
		var time: float = game.elapsed
		game.mode = "pause"
		step(2)
		check(game.elapsed == time and game.world_two.wipe_elapsed == 0 and p2.player == start, id + " pause freezes actual session and pending wipe")
		game.mode = "play"
		step(1.43)
		var destination: float = scene_x + (0 if id == "2-3" else 420)
		check(game.world_two.scene_index == 1 and p1.player.x == destination and p2.player.x == destination + (-70 if id == "2-3" else 70), id + " actual late shared midpoint moves both once")
		check(not p1.down and p1.hearts == 3 and p2.hearts == 1 and game.mode == "play", id + " actual midpoint raises P1 without healing living P2")
		check(game.player == p1.player and game.character == "jp" and not session.bridge.shared_phase, id + " final facade is restored after midpoint")
		check(p1.scene_state.safe_position.x == scene_x - 230, id + " midpoint preserves downed actor safe floor")
		step(0)
		check(game.world_two.scene_index == 1, id + " following frame cannot replay midpoint")

func _test_checkpoint() -> void:
	fresh("2-2")
	complete_waves()
	var x: float = game.level.check
	place(Vector2(x - 250, 482), Vector2(x - 50, 482), Vector2(x - game.view_width() * 0.5, 0))
	var session = game.party_session
	var p1 = session.runtime.actors[0]
	var p2 = session.runtime.actors[1]
	p1.mark_down(); p2.hearts = 1
	session.bind(game, 0)
	step(0)
	check(game.world_two.checkpoint_hit and p1.hearts == 3 and p2.hearts == 3 and not p1.down, "actual checkpoint heals roster before all-down decision")
	check(p1.invincible == 2 and p2.invincible == 0, "actual checkpoint protection applies only to revived actor")
	p1.mark_down(); p2.mark_down(); session.bind(game, 0)
	step(0)
	check(game.mode == "over", "actual all-down after spent checkpoint opens Continue")
	var elapsed: float = game.elapsed
	var generation: int = game.world_two.run_generation
	game._continue_level()
	check(game.mode == "play" and p1.hearts == 3 and p2.hearts == 3 and game.world_two.checkpoint_hit, "actual Continue revives both without resetting checkpoint")
	check(game.elapsed == elapsed and game.world_two.run_generation == generation, "actual Continue retains world clock and generation")

func _test_ice() -> void:
	fresh("2-2")
	var ice: Array = game.level.hz.filter(func(row): return row[0] == "ice")[0]
	var x := (float(ice[1]) + float(ice[2])) * 0.5
	var y := float(ice[3]) if ice.size() > 3 and ice[3] else 482.0
	place(Vector2(x - 35, y), Vector2(x + 35, y), Vector2(x - 300, 0))
	var session = game.party_session
	step(0.01, {"right": true}, {"left": true})
	var values: Dictionary = game.world_two.hazard_controller.ice_velocity
	check(values.has(0) and values.has(1) and values[0] > 0 and values[1] < 0, "actual actor movement stores independent ice velocity by slot")
	check(not values.has(game.get_instance_id()), "actual party motion never uses scalar host ice identity")

func _test_checkout() -> void:
	fresh("2-6")
	check(game.world_two.checkout.players.size() == 2 and game.world_two.checkout.players.has(0) and game.world_two.checkout.players.has(1), "actual fresh checkout owns only stable pair identities")
	complete_waves()
	place(Vector2(4300, 482), Vector2(4400, 482), Vector2(4162, 0))
	step(0)
	var checkout = game.world_two.checkout
	var boss: Dictionary = checkout.boss
	check(not boss.is_empty() and boss.hp == 90, "actual end predicate creates one 90HP pair checkout")
	boss.state = "fight"; boss.phase = 2; boss.next = 100.0
	boss.crates = [
		{"p": Vector2(4300, 482), "st": "ground", "vy": 0.0, "k": 0, "by": null},
		{"p": Vector2(4400, 482), "st": "ground", "vy": 0.0, "k": 1, "by": null}]
	step(0)
	var p1 = game.party_session.runtime.actors[0]
	var p2 = game.party_session.runtime.actors[1]
	check(boss.crates[0].by == 0 and boss.crates[1].by == 1 and is_same(p1.scene_state.crate, boss.crates[0]) and is_same(p2.scene_state.crate, boss.crates[1]), "actual late checkout assigns and persists both independent carriers")
	boss.frozen = 4.0
	step(0.3, {}, {"shoot": true})
	check(checkout.players[1].boss_hits == 1 and checkout.players[0].boss_hits == 0 and p2.scene_state.boss_hits == 1, "P2 ordinary input shot credits its checkout hit through actual projectile pass")
	check(boss.hp == 88 and boss.crates[1].st == "fly" and p2.scene_state.crate == null and p1.scene_state.crate != null, "actual shot damage and P2-only crate throw remain independent")
	var old_checkout = checkout
	fresh("2-6")
	check(game.world_two.checkout != old_checkout and game.world_two.checkout.boss.is_empty() and game.world_two.checkout.players.size() == 2, "actual replay discards old encounter and temporary scalar identity")
	check(game.world_two.checkout.players.values().all(func(state): return state.bag == 0 and state.crate == null and state.boss_hits == 0), "actual replay clears both carry/bag/credit states")
