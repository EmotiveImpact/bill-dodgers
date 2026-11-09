extends SceneTree
## Focused real-main lifecycle fixtures. Full normal-input bus traversal lives
## in its own suite; placing a fixture or marking waves done here is not one.
var checks := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	game.save = {"schema": 1, "receipts": {}, "skills": []}
	game.character = "jp"
	game.load_level("1-3")
	check(game._native_world_one() and game.bus_ride.enabled and game.combat.waves.size() == 12, "Native bus loads its independent timeline after twelve combat waves")
	check(game.player == Vector2(319, 150) and game.grounded and game.camera == Vector2(0, -332), "Initial bus player and camera use source roof coordinates")
	check(game.combat.waves.all(func(w): return w.at == 1.0e9 and not w.started), "Bus reset gates all otherwise-simultaneous zero-position waves")
	game.step(2.59, {"down": true})
	check(game.camera == Vector2(0, -235) and game.enemies.is_empty() and game.bus_ride.phase == "obst", "Initial native bus frame pins camera but does not spawn before initial wait")
	game.step(0.011, {"down": true})
	check(game.bus_ride.phase == "wave" and not game.combat.waves[0].started and game.enemies.is_empty(), "Late bus hook arms first wave without spawning it prematurely")
	game.step(0.016, {"down": true})
	check(game.combat.waves[0].started and game.combat.waves[0].index == 1 and game.enemies.size() == 1, "Following native combat frame releases only first scheduled scooter robot")
	var enemy: Dictionary = game.enemies[0]
	check(enemy.has("hop") and absf(enemy.hop.t - 0.016) < 0.00001 and enemy.source_kind == "rush", "Combat spawn hook supplies source arrival hop before ordinary AI")
	check(game.bus_ride.scooters.size() == 1 and absf(game.bus_ride.scooters[0].t - 0.016) < 0.00001, "New scooter advances only in final source scene hook")
	check(game.combat.waves.slice(1).all(func(w): return not w.started and w.at == 1.0e9), "Initial fight cannot release other eleven waves")
	# Every bus label passes through the local hook before shared specials.
	game.combat.spawn(game, "l", "tiny")
	game.combat.spawn(game, "r", "mini")
	check(game.enemies[-2].hp == 4 and game.enemies[-1].hp == 4 and game.enemies[-2].scale == 1 and not game.enemies[-1].has("volley"), "Native bus tiny/mini retain source four-HP ordinary arrivals")
	var scooter_count: int = game.bus_ride.scooters.size()
	game.combat.spawn(game, "r", "fly")
	check(game.enemies.back().kind == "fly" and game.enemies.back().hp == 2 and not game.enemies.back().has("hop") and game.bus_ride.scooters.size() == scooter_count, "Flyer still uses shared airborne spawn without scooter")
	# Isolate the first between-wave obstacle with native controller transition.
	game.enemies.clear()
	game.combat.waves[0].index = game.combat.waves[0].group.size()
	game.combat.waves[0].done = true
	game.bus_ride.tick(0.016, game)
	game.bus_ride.tick(1.401, game)
	check(game.bus_ride.slot == 1 and game.bus_ride.phase == "obst" and game.bus_ride.obstacles.size() == 1 and not game.combat.waves[1].started, "Native post-fight transition produces source bridge and keeps next wave gated")
	# Source Continue revives in place. Snapshot actual gameplay objects before
	# a forced last-heart hit, then verify no reset/reload or implicit completion.
	game.combat.spawn(game, "r", "rush")
	game.coins = [{"p": Vector2(600, 142), "v": Vector2.ZERO, "age": 0.26, "rest": true}]
	game.score = 17
	game.receipts[0].taken = true
	game.hearts = 1
	game.invincible = 0
	game.hurt_player(game.player.x + 40)
	check(game.mode == "over" and game.hearts == 0 and game.audio.paused, "Last-heart hit pauses bus encounter in native game-over state")
	var player_at_death: Vector2 = game.player
	var camera_at_death: Vector2 = game.camera
	var drive_at_death: float = game.bus_ride.drive
	var obstacle_snapshot := JSON.stringify(game.bus_ride.obstacles)
	var scooter_snapshot := JSON.stringify(game.bus_ride.scooters)
	var wave_snapshot := JSON.stringify(game.combat.waves)
	var enemy_snapshot := JSON.stringify(game.enemies)
	var coin_snapshot := JSON.stringify(game.coins)
	var rest_at_death: float = game.bus_ride.rest_time
	var warn_at_death: float = game.bus_ride.warn_time
	game.step(10, {"right": true, "shoot": true})
	check(game.bus_ride.drive == drive_at_death and JSON.stringify(game.combat.waves) == wave_snapshot and JSON.stringify(game.bus_ride.obstacles) == obstacle_snapshot, "Game over freezes existing bus and wave timelines")
	game._continue_level()
	check(game.mode == "play" and game.hearts == 3 and game.invincible == 2.5 and not game.audio.paused, "Continue revives in place with source three hearts and2.5secondprotection")
	check(game.player == player_at_death and game.camera == camera_at_death and game.bus_ride.drive == drive_at_death, "Continue cannot rewind player, camera or moving scenery")
	check(JSON.stringify(game.bus_ride.obstacles) == obstacle_snapshot and JSON.stringify(game.bus_ride.scooters) == scooter_snapshot and game.bus_ride.rest_time == rest_at_death and game.bus_ride.warn_time == warn_at_death, "Continue retains obstacle positions, scooters, rest and warning countdowns")
	check(JSON.stringify(game.combat.waves) == wave_snapshot and JSON.stringify(game.enemies) == enemy_snapshot, "Continue preserves fight progress and partially arriving enemies")
	check(JSON.stringify(game.coins) == coin_snapshot and game.score == 17 and game.receipts[0].taken, "Continue retains loose coins, kitty score and collected receipts")
	check(not game.save.get("cleared", {}).get("1-3", false), "Continue never grants bus completion")
	game._continue_level()
	check(game.bus_ride.drive == drive_at_death and game.hearts == 3 and game.invincible == 2.5, "Repeated Continue outside game over has no side effects")
	game.step(0.016, {"down": true})
	check(game.bus_ride.drive > drive_at_death and game.bus_ride.obstacles[0].x < JSON.parse_string(obstacle_snapshot)[0].x, "Resumed bus continues existing motion rather than restarting")
	game._pause()
	var paused_drive: float = game.bus_ride.drive
	var paused_time: float = game.elapsed
	game.step(10, {})
	check(game.mode == "paused" and game.bus_ride.drive == paused_drive and game.elapsed == paused_time, "Normal pause freezes bus and shared simulation together")
	game._resume()
	game.step(0.016, {"down": true})
	check(game.mode == "play" and game.bus_ride.drive > paused_drive, "Explicit resume continues bus timeline")
	# Actual obstacle update hits after earlier player/combat work, then stops
	# subsequent frames. Continue must not create a second hit from same object.
	game.load_level("1-3")
	game.bus_ride.obstacles = [{"k": "bridge", "x": 300.0, "w": 330.0, "hit": false}]
	game.hearts = 1
	game.step(0, {})
	check(game.mode == "over" and game.bus_ride.obstacles[0].hit, "Actual bus bridge can knock out standing player and consumes its hit")
	game._continue_level()
	game.invincible = 0
	game.step(0, {})
	check(game.mode == "play" and game.hearts == 3, "Continuing under same bridge cannot repeat its consumed hit")
	# Arrival enemies remain protected from overhead collisions until landed.
	game.load_level("1-3")
	game.combat.spawn(game, "r", "rush")
	enemy = game.enemies[0]
	enemy.p = Vector2(400, 150)
	game.bus_ride.obstacles = [{"k": "branch", "x": 350.0, "w": 150.0, "hit": false}]
	game.bus_ride.tick(0, game)
	check(enemy.state == "walk", "Arrival hop is exempt from passing branch robot kill")
	enemy.erase("hop")
	game.bus_ride.tick(0, game)
	check(enemy.state == "pop" and game.pop_count == 0 and game.coins.size() >= 4, "Landed robot is popped by branch without player kill credit")
	# Objective fixture requires all waves, then source end delay; it never
	# substitutes a Jar Thief or grants completion merely for riding distance.
	game.load_level("1-3")
	game.bus_ride.drive = 1000000
	game.scene_objective(10)
	check(game.mode == "play" and game.bus_ride.end_time == 0 and game.boss == null, "Distance alone cannot finish bus or create a boss")
	for wave in game.combat.waves: wave.started = true; wave.done = true
	game.scene_objective(0.016)
	check(game.mode == "play" and game.bus_ride.end_time > 0 and game.status == "Next stop: the park!", "Final completed fight starts source bus exit announcement")
	game.scene_objective(2.582)
	check(game.mode == "play" and not game.save.get("cleared", {}).get("1-3", false), "Bus cannot save clear before source end delay")
	game.scene_objective(0.002)
	check(game.mode == "clear" and game.save.cleared["1-3"] and game.boss == null, "Native bus objective saves clear after2.6seconds without jar boss")
	check(game.ui.get_children().any(func(c): return c is Label and c.text == "Bus ride survived!"), "Native completion UI uses original bus clear text")
	var banked: int = game.save.kitty
	game._continue_level()
	game.scene_objective(10)
	check(game.mode == "clear" and game.save.kitty == banked, "Clear cannot be resumed via Continue or banked twice")
	game.load_level("1-3")
	check(game.bus_ride.drive == 0 and game.bus_ride.slot == 0 and game.bus_ride.phase == "obst" and game.bus_ride.obstacles.is_empty() and game.bus_ride.scooters.is_empty() and game.bus_ride.end_time == 0, "Explicit replay rebuilds a fresh bus timeline")
	game.load_level("1-2")
	check(not game.bus_ride.enabled and game.combat.waves[0].at == 651, "Leaving bus disables its spawn/timeline override and restores rooftop triggers")
	game.load_level("4-1"); game.level_id = "7-1"
	game._complete_level()
	check(not game._native_world_one() and not game.save.cleared.get("7-1", false), "Unknown run ID still cannot receive false completion")
	game.queue_free()
	await process_frame
	print("Bus main integration: ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
