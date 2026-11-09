extends SceneTree
## Actual main.tscn fixtures. Receipt routes below use only ordinary input.
## Teleported fixtures are explicitly isolated from the full-route evidence.
const SaveStore = preload("res://src/save_store.gd")
const DT := 1.0 / 60
var checks := 0
var failures: Array[String] = []
var game
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)
func _initialize() -> void: call_deferred("run")
func fresh(id: String, who: String = "jp") -> void:
	game.character = who; game.save = {"schema": 1, "receipts": {}, "skills": [], "kitty": 0}
	check(game.load_level(id), id + " loads")
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	for id in ["5-1", "5-2", "5-3", "5-4", "5-5", "5-6", "5-S"]:
		fresh(id)
		check(game._native_world_five() and game.scene_runtime == game.world_five and game.combat == game.moving_day_combat, id + " family adapters")
		check(game.player.y == (420 if id == "5-5" else 482), id + " initial exact source feet")
		check(game.combat.waves.size() == game.level.waves.size(), id + " complete wave schedule")
		check(game.coins.size() == (484 if id == "5-S" else 0), id + " authored coin seeding after reset")
		var original := JSON.stringify(game.meta)
		for i in 10: game.step(DT, {})
		game.queue_redraw(); await process_frame
		check(JSON.stringify(game.meta) == original, id + " actual main keeps immutable META")
	for id in ["5-1", "5-2", "5-4", "5-6"]:
		for who in game.CHARACTERS:
			fresh(id, who)
			check(game.receipts[0].position == Vector2(60, 482) and game.level.receipts[0] == [-250.0, 482.0], who + " " + id + " repaired secret keeps source")
			for i in 360:
				var jump: bool = id == "5-1" and game.grounded and game.player.x > 130 and not game.jump_held
				game.step(DT, {"left": true, "jump": jump})
				if game.receipts[0].taken: break
			check(game.receipts[0].taken and game.camera.x == 0 and game.player.x >= 30, who + " " + id + " reachable receipt using only left/jump input")
			check(game.save.receipts.get(id, []) == [0] and game.score == 0, who + " " + id + " secret zero reward and exact save identity")
			for i in 20: game.step(DT, {"left": true})
			check(game.save.receipts[id] == [0] and game.score == 0, who + " " + id + " receipt once per run")
			game.load_level(id)
			check(not game.receipts[0].taken and game.receipts[0].previously_collected and game.receipts[1].position == Vector2(game.level.receipts[1][0], game.level.receipts[1][1]), who + " " + id + " replay identity and later receipt preserved")
	# Explicitly positioned collision/lifecycle fixtures, not full-route claims.
	fresh("5-S"); game.player = Vector2(2760, 410); game.velocity.y = 300; game.grounded = false; game.camera.x = 2400
	game.step(DT, {}); game.step(DT, {})
	check(game.velocity.y < -1300 and not game.grounded, "actual main landing calls mattress bounce")
	fresh("5-4"); game.player = Vector2(6100, 242); game.camera.x = 5800; game.grounded = true; game.on_platform = true
	game.step(0.01, {}); check(absf(game.player.x - 6101.4) < 0.01, "actual main raised conveyor carry")
	fresh("5-2"); game.player = Vector2(2940, 482); game.camera.x = 2600; game.world_five.sofa.x = 2940
	for i in 30: game.step(DT, {"down": true})
	check(game.world_five.sofa.tip, "actual main duck input tips sofa")
	game.world_five.checkpoint = {"x": 15150.0, "y": 482.0}; game.player = Vector2(15000, 482); game.camera.x = 14900; game.hearts = 0; game.mode = "over"
	game._continue_level(); check(game.player.x == 15150 and game.hearts == 3 and game.invincible == 2.5, "Continue preserves run and checkpoint respawn")
	fresh("5-6", "ama"); game.player = Vector2(4000, 482); game.camera.x = 3662
	game.combat.start_boss(game); game.boss.state.state = "walk"; game.boss.state.x = 4100
	game.abilities.meter = 1.0; game.step(DT, {"special": true})
	check(is_finite(game.boss.state.fy) and game.boss.state.fy == 482 and game.boss.state.dizzy > 3 and game.boss.state.hp < 26, "King native finite feet repair enables Ama dizzy/ghost through actual shot pass")
	# Final objective fixture checks source late base phases still run.
	fresh("5-S"); game.world_five.clock_left = 0
	for wave in game.combat.waves: wave.started = true; wave.done = true
	game.world_five.end_time = 2.599; game.coins = [{"p": game.player - Vector2(0, 60), "v": Vector2.ZERO, "age": 0.4, "rest": true}]
	game.step(0.01, {})
	check(game.mode == "clear" and game.world_five.clear_reported, "final W5 objective completes via actual main")
	game.queue_free(); await process_frame
	print("World 5 actual-main integration: %d checks, %d failures; 24 input-only repaired-secret routes" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
