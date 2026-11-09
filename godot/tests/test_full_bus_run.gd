extends SceneTree
## Bounded real-input progression soak, NOT a difficulty or device playtest.
## The only gameplay assist is invulnerability. Never move actors, edit damage,
## spawn enemies, advance waves, or invoke completion from the test.
## Run with isolated HOME/XDG paths, like scripts/verify-native.sh.
const MAX_TICKS := 60000
const DT := 1.0 / 60.0
const SaveStore = preload("res://src/save_store.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	var passed := true
	for character in game.CHARACTERS:
		if not run_character(game, character): passed = false
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)

func check(condition: bool, message: String) -> void:
	if not condition and message not in failures: failures.append(message)

func run_character(game, character: String) -> bool:
	failures.clear()
	game.character = character
	game.save = {"schema": 1, "receipts": {}}
	# A fresh disk save prevents an earlier character's clear masking a failed
	# write. This is setup only; the game must earn and persist its own result.
	check(SaveStore.write_save(game.save) == OK, "fresh isolated save failed")
	check(not SaveStore.read_save().get("cleared", {}).get("1-3", false), "stale saved clear")
	check(game.load_level("1-3"), "level did not load")
	check(game._native_world_one(), "1-3 is not wired as native gameplay")
	check(game.combat.waves.size() == 12, "expected twelve source fights")
	if not failures.is_empty():
		printerr("Bus input soak [", character, "]: FAIL ", failures)
		return false
	var ride = game.bus_ride
	check(ride.enabled, "bus timeline is disabled")
	var expected: Array[String] = []
	var expected_obstacles := 0
	for i in range(game.level.waves.size()):
		expected.append("fight:%d" % (i + 1))
		expected.append("done:%d" % (i + 1))
		for kind in game.level.between[i]:
			expected.append("obstacle:" + kind)
			expected_obstacles += 1
	check(expected_obstacles == 25, "expected twenty-five source overhead obstacles")
	var timeline: Array[String] = []
	var seen_starts: Array[int] = []
	var seen_done: Array[int] = []
	var obstacle: Dictionary = {}
	var obstacle_crossed := false
	var obstacles_seen := 0
	var obstacles_passed := 0
	var duck_crossings := 0
	var duck_frames := 0
	var aim_frames := 0
	var movement_frames := 0
	var shot_frames := 0
	var specials := 0
	var boss_seen := false
	var completed_at := -1
	var ticks := 0
	var min_x: float = game.player.x
	var max_x := min_x
	for frame in range(MAX_TICKS):
		ticks = frame + 1
		game.invincible = 999 # Explicit progression assist, not proof of ducking.
		var controls := controls_for(game)
		var was_active: String = game.abilities.active
		game.step(DT, controls)
		if was_active.is_empty() and not game.abilities.active.is_empty(): specials += 1
		if game.player_animation == "crouch": duck_frames += 1
		if controls.get("aim", false): aim_frames += 1
		if controls.get("left", false) or controls.get("right", false): movement_frames += 1
		if controls.get("shoot", false): shot_frames += 1
		min_x = minf(min_x, game.player.x)
		max_x = maxf(max_x, game.player.x)
		boss_seen = boss_seen or game.boss != null
		check(game.player.y <= float(game.level.solids[0][2]) + 2, "player fell off the bus roof")
		check(absf(game.camera.x) < 0.01, "fixed-width bus camera moved horizontally")
		if game.mode == "play": check(absf(game.camera.y - float(game.level.camY)) < 0.01, "bus camera lost its source height")
		check(ride.obstacles.size() <= 1, "overlapping obstacle timeline")
		for i in range(game.combat.waves.size()):
			var wave: Dictionary = game.combat.waves[i]
			if wave.started and i not in seen_starts:
				seen_starts.append(i)
				timeline.append("fight:%d" % (i + 1))
			if wave.done and i not in seen_done:
				seen_done.append(i)
				timeline.append("done:%d" % (i + 1))
		if obstacle.is_empty() and not ride.obstacles.is_empty():
			obstacle = ride.obstacles[0] # Keep the actual dictionary through removal.
			obstacle_crossed = false
			obstacles_seen += 1
			timeline.append("obstacle:" + str(obstacle.k))
		if not obstacle.is_empty():
			# The source sets hit BEFORE hurt_player checks invulnerability. This
			# assertion catches collisions even though the soak cannot lose hearts.
			check(not obstacle.hit, "overhead collision recorded for obstacle %d" % obstacles_seen)
			if game.player.x >= obstacle.x - 10 and game.player.x <= obstacle.x + obstacle.w + 10:
				var bottom: float = ride.roof_y - (132 if obstacle.k == "bridge" else 128)
				var height: float = game.character_height()
				check(controls.get("down", false) and game.player_animation == "crouch", "crossed overhead obstacle without ducking")
				check(game.player.y - height * 0.86 < bottom, "obstacle passage did not exercise standing collision height")
				check(game.player.y - height * 0.56 >= bottom, "crouched player did not fit below obstacle")
				obstacle_crossed = true
			if ride.obstacles.is_empty():
				obstacles_passed += 1
				if obstacle_crossed and not obstacle.hit: duck_crossings += 1
				check(obstacle_crossed, "obstacle exited without crossing the player")
				obstacle = {}
		if seen_done.size() == 12 and completed_at < 0: completed_at = frame
		if game.mode in ["clear", "over"]: break
	var exit_ticks := ticks - 1 - completed_at if completed_at >= 0 else -1
	check(game.mode == "clear", "normal gameplay did not clear before the tick bound")
	check(not boss_seen, "unexpected Jar Thief on the bus")
	check(seen_starts.size() == 12 and seen_done.size() == 12, "not every fight started and completed")
	check(timeline == expected, "source fight/obstacle ordering differs")
	check(obstacles_seen == 25 and obstacles_passed == 25 and duck_crossings == 25, "not every overhead obstacle was safely ducked")
	check(ride.slot == 12 and ride.obstacle_queue.is_empty() and ride.obstacles.is_empty(), "bus timeline did not finish")
	check(specials > 0 and aim_frames > 0 and shot_frames > 0 and duck_frames > 0, "missing normal attack/aim/special/duck coverage")
	check(movement_frames > 0 and max_x - min_x > 40, "movement controls did not move the player")
	check(exit_ticks >= 155 and exit_ticks <= 157, "source 2.6-second exit timing differs")
	check(game.save.get("cleared", {}).get("1-3", false), "in-memory native clear missing")
	check(SaveStore.read_save().get("cleared", {}).get("1-3", false), "native clear did not persist through save reload")
	var passed := failures.is_empty()
	print("Bus input soak [", character, "]: ", "PASS" if passed else "FAIL", " ticks=", ticks, " fights=", seen_done.size(), "/12 obstacles=", obstacles_passed, "/25 ducked=", duck_crossings, " specials=", specials, " aim_frames=", aim_frames, " exit_ticks=", exit_ticks, " boss_seen=", boss_seen, " mode=", game.mode)
	if not passed:
		printerr("Bus failures [", character, "]: ", failures)
		printerr("Timeline: ", timeline, " slot=", ride.slot, " phase=", ride.phase, " player=", game.player, " enemies=", game.enemies.filter(func(enemy): return enemy.state != "pop"))
	return passed

func controls_for(game) -> Dictionary:
	var controls := {"left": false, "right": false, "shoot": true}
	var ride = game.bus_ride
	# Every hazard is crossed at roof height using the ordinary duck control.
	# Down also lets Leo land his glider during the warning approach.
	if ride.phase == "obst":
		controls.down = true
		return controls
	var target: Dictionary = {}
	for enemy in game.enemies:
		if enemy.state == "pop": continue
		if target.is_empty() or absf(enemy.p.x - game.player.x) < absf(target.p.x - game.player.x): target = enemy
	if not target.is_empty():
		var dx: float = target.p.x - game.player.x
		controls.right = dx > 220
		controls.left = dx < -220
		if target.kind == "fly":
			controls.aim = true
			controls.right = dx > 30
			controls.left = dx < -30
		# Turn by input, never directly assign facing or position.
		if game.face != (1 if dx >= 0 else -1):
			controls.right = dx >= 0
			controls.left = dx < 0
	# Stay on the roof using controls, including while chasing airborne robots.
	if game.player.x < float(game.level.solids[0][0]) + 20:
		controls.left = false
	if game.player.x > float(game.level.solids[0][1]) - 20:
		controls.right = false
	# Start charged specials near the beginning of a fight, leaving time to land
	# before overhead obstacles. Charge and damage remain wholly game-owned.
	if ride.slot < game.combat.waves.size() and game.combat.waves[ride.slot].t < 0.3 and game.abilities.meter >= 1:
		controls.special = true
	return controls
