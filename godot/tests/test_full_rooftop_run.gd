extends SceneTree
## Real-input progression soak, not difficulty QA: invincibility is the only assist.
## Waypoints come from imported collision geometry. Never teleport or edit health.
## No enemy, wave, power-meter, position, timer, geometry or completion edits.
## Run with isolated HOME/XDG paths, as in scripts/verify-native.sh.
const MAX_TICKS := 36000
const DT := 1.0 / 60.0
const SaveStore = preload("res://src/save_store.gd")
const EXPECTED_WAVES := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
var failures: Array[String] = []
var route: Array[Vector3] = []
var route_index := 0

func _initialize() -> void: call_deferred("run")

func make_route(level: Dictionary) -> void:
	route.clear()
	route_index = 0
	# The first six escape landings share x=320; ordinary repeated jumps climb them.
	route.append(Vector3(305, 335, -152))
	for roof in level.roofs:
		var cuts: Array[float] = [float(roof[0]), float(roof[1])]
		for solid in level.solids:
			if solid[0] > roof[0] and solid[1] < roof[1] and solid[2] < roof[2]:
				cuts.append(float(solid[0])); cuts.append(float(solid[1]))
		cuts.sort()
		for i in range(cuts.size() - 1):
			var middle := (cuts[i] + cuts[i + 1]) * 0.5
			var top := float(roof[2])
			for solid in level.solids:
				if middle >= solid[0] and middle <= solid[1]: top = minf(top, solid[2])
			route.append(Vector3(cuts[i], cuts[i + 1], top))
	for slate in level.crumble: route.append(Vector3(slate[0], slate[1], slate[2]))
	# Intermediate escape lands between the two real roofs (330 pixels apart).
	for row in [[7870, 8081, -305], [7925, 8081, -432], [7870, 8321, -562]]:
		route.append(Vector3(row[0], row[1], row[2]))
	route.sort_custom(func(a, b):
		if a.x >= 7870 and a.x < 8321 and b.x >= 7870 and b.x < 8321: return a.z > b.z
		return a.x < b.x)

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	var passed := true
	var characters: Array = ["jp"] if "--jp-only" in OS.get_cmdline_user_args() else game.CHARACTERS
	for character in characters:
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
	# Setup only: each housemate earns a new persisted clear and no skills.
	check(SaveStore.write_save(game.save) == OK, "fresh isolated save failed")
	check(not SaveStore.read_save().get("cleared", {}).get("1-2", false), "stale saved clear")
	check(game.load_level("1-2"), "level did not load")
	check(game._native_world_one(), "1-2 is not native gameplay")
	check(game.level.w == 19922 and game.level.roofs.size() == 14 and game.level.crumble.size() == 12, "original rooftop geometry changed")
	check(game.combat.waves.size() == 11, "expected all eleven source waves")
	if not failures.is_empty():
		printerr("Rooftop input soak [", character, "]: FAIL ", failures)
		return false
	make_route(game.level)
	check(route.size() == 56, "original 56 waypoints changed")
	var geometry_before := JSON.stringify(game.level)
	var started: Array[int] = []
	var completed: Array[int] = []
	var roofs_reached: Array[int] = []
	var slates_reached: Array[int] = []
	var ticks := 0
	var specials := 0
	var jumps := 0
	var falls := 0
	var completed_at := -1
	var boss_seen := false
	var high_roof_reached := false
	var first_climb_reached := false
	var combat_jump := false
	var combat_bounds := Vector2.ZERO
	for frame in range(MAX_TICKS):
		ticks = frame + 1
		game.invincible = 999 # Explicit progression-only assist, never enemy damage.
		if game.grounded:
			combat_jump = false
			combat_bounds = Vector2(game.player.x, game.player.x)
			for roof in game.level.roofs:
				if game.player.x >= roof[0] and game.player.x <= roof[1]:
					combat_bounds = Vector2(maxf(roof[0] + 35, game.camera.x + 35), minf(roof[1] - 35, game.camera.x + game.view_width() - 40))
		elif game.abilities.active == "leo" and game.camera_lock != null:
			combat_jump = true
		if game.grounded and route_index < route.size():
			var goal: Vector3 = route[route_index]
			if game.player.x >= goal.x + minf(20, (goal.y - goal.x) * 0.25) and game.player.x <= goal.y and game.player.y <= goal.z + 2:
				route_index += 1
		var controls := navigation(game)
		controls.shoot = true
		var target: Dictionary = {}
		for enemy in game.enemies:
			if enemy.state == "pop": continue
			if target.is_empty() or absf(enemy.p.x - game.player.x) < absf(target.p.x - game.player.x): target = enemy
		if not target.is_empty() and (game.grounded or combat_jump) and not on_crumble(game) and game.player.y >= target.p.y - 40:
			# Fight from a stable roof rather than walking into a camera-lock edge.
			controls.left = false
			controls.right = false
			controls.jump = false
			var dx: float = target.p.x - game.player.x
			if game.face != (1 if dx >= 0 else -1):
				controls.right = dx >= 0
				controls.left = dx < 0
			if target.kind == "tiny": controls.down = true
			var obstructed := false
			for row in game.level.solids:
				if row[2] < game.player.y - 40 and row[0] < maxf(game.player.x, target.p.x) and row[1] > minf(game.player.x, target.p.x): obstructed = true
			if target.p.y < game.player.y - 130 or obstructed:
				# Use ordinary jumps to get past a chimney between us and a flyer.
				# Merely walking toward its x can pin the old JP-only driver.
				var fight_x: float = clampf(target.p.x, combat_bounds.x, combat_bounds.y)
				# Lure an off-roof flyer back over safe footing before aiming up.
				if target.kind == "fly" and target.p.x > combat_bounds.y: fight_x = maxf(combat_bounds.x, combat_bounds.y - 250)
				if target.kind == "fly" and target.p.x < combat_bounds.x: fight_x = minf(combat_bounds.y, combat_bounds.x + 250)
				controls = navigate_to(game, fight_x, game.player.y)
				controls.shoot = true
				controls.aim = target.p.y < game.player.y - 130
				if controls.jump: combat_jump = true
				if absf(dx) <= 24:
					controls.right = false
					controls.left = false
		# Combat jumps and the glider keep the same safe roof beneath them.
		if combat_jump:
			if game.player.x >= combat_bounds.y - 5: controls.right = false
			if game.player.x <= combat_bounds.x + 5: controls.left = false
		if game.abilities.meter >= 1: controls.special = true
		var was_active: String = game.abilities.active
		var was_grounded: bool = game.grounded
		var previous_y: float = game.player.y
		game.step(DT, controls)
		boss_seen = boss_seen or game.boss != null
		if game.grounded and game.player.x > 8321 and game.player.y <= -562: high_roof_reached = true
		if game.grounded and game.player.x >= 305 and game.player.x <= 335 and game.player.y <= -152: first_climb_reached = true
		if was_active.is_empty() and not game.abilities.active.is_empty():
			specials += 1
			check(game.abilities.active == character, "activated another housemate's special")
		if was_grounded and not game.grounded and game.velocity.y < 0: jumps += 1
		if previous_y > 800 and game.player.y < previous_y - 100:
			falls += 1
		for i in range(game.combat.waves.size()):
			var wave: Dictionary = game.combat.waves[i]
			if wave.started and i not in started: started.append(i)
			if wave.done and i not in completed:
				check(wave.index == wave.group.size(), "wave completed before all source spawns")
				completed.append(i)
		if game.grounded:
			for i in range(game.level.roofs.size()):
				var row: Array = game.level.roofs[i]
				if game.player.x >= row[0] and game.player.x <= row[1] and game.player.y <= row[2] + 2 and i not in roofs_reached: roofs_reached.append(i)
			for i in range(game.level.crumble.size()):
				var row: Array = game.level.crumble[i]
				if game.player.x >= row[0] and game.player.x <= row[1] and absf(game.player.y - row[2]) < 2 and i not in slates_reached: slates_reached.append(i)
		if game.world_one.end_time > 0 and completed_at < 0:
			completed_at = frame
			check(completed == EXPECTED_WAVES, "timed exit started before all waves finished")
			check(game.camera.x >= game.level.w - game.view_width() - 2, "timed exit started before source end of level")
		if game.mode == "clear" or game.mode == "over": break
	var exit_ticks := ticks - 1 - completed_at if completed_at >= 0 else -1
	check(game.mode == "clear", "bounded input route did not clear")
	check(not boss_seen, "unexpected boss in rooftop timed-exit stage")
	check(first_climb_reached and high_roof_reached, "did not complete both actual roof climbs")
	check(falls == 0, "route relied on fall-safe recovery")
	check(route_index == route.size(), "missed original route waypoints")
	check(roofs_reached.size() == 14 and slates_reached.size() == 12, "did not land on every roof and crumbling slate")
	check(started == EXPECTED_WAVES and completed == EXPECTED_WAVES, "all eleven waves did not start and finish in source order")
	check(game.combat.waves.size() == 11 and game.combat.waves.all(func(w): return w.done), "all source waves must remain completed at clear")
	check(game.camera.x >= game.level.w - game.view_width() - 2, "source camera endpoint was not reached")
	check(specials > 0 and jumps >= 6, "missing ordinary jumping or actual housemate special activation")
	check(exit_ticks == 155, "source 2.6-second timed exit changed")
	check(JSON.stringify(game.level) == geometry_before, "test/runtime mutated source geometry")
	check(game.movement_skills.skills.is_empty(), "unearned movement skill appeared")
	check(game.save.get("cleared", {}).get("1-2", false), "native clear missing in memory")
	check(SaveStore.read_save().get("cleared", {}).get("1-2", false), "native clear missing after disk reload")
	var passed := failures.is_empty()
	print("Rooftop input soak [", character, "]: ", "PASS" if passed else "FAIL", " ticks=", ticks, " waves=", game.combat.waves.filter(func(w): return w.done).size(), "/", game.combat.waves.size(), " jumps=", jumps, " specials=", specials, " falls=", falls, " exit_ticks=", exit_ticks, " boss_seen=", boss_seen, " player=", game.player, " route=", route_index, "/", route.size(), " roofs=", roofs_reached.size(), "/14 slates=", slates_reached.size(), "/12 camera=", game.camera.x, " mode=", game.mode)
	if not passed:
		printerr("Rooftop failures [", character, "]: ", failures)
		printerr("Next support: ", route[route_index] if route_index < route.size() else Vector3.ZERO, " enemies=", game.enemies.filter(func(e): return e.state != "pop"))
	return passed

func on_crumble(game) -> bool:
	for row in game.level.crumble:
		if game.player.x >= row[0] and game.player.x <= row[1] and absf(game.player.y - row[2]) < 2: return true
	return false

func navigation(game) -> Dictionary:
	var target_x: float = game.level.w - 70
	var target_y: float = game.player.y
	if route_index < route.size():
		var goal := route[route_index]
		target_x = goal.x + minf(30, (goal.y - goal.x) * 0.5)
		target_y = goal.z
	# A fight may pull us back onto an already visited chimney. Step down
	# onto this roof again before approaching a distant slate or next roof.
	for roof in game.level.roofs:
		if game.grounded and game.player.x >= roof[0] and game.player.x <= roof[1] and game.player.y < roof[2] - 6 and target_x > roof[1]:
			target_x = roof[1] - 40
			target_y = roof[2]
	# Do not jump into a roof gap while the current fight still locks the
	# next landing outside the viewport. Offscreen arrivals expire naturally.
	if game.camera_lock != null and target_x > game.camera.x + game.view_width() - 40 and game.grounded and not on_crumble(game):
		return {"right": false, "left": false, "jump": false}
	if game.camera_lock != null and game.grounded and not on_crumble(game):
		for slate in game.level.crumble:
			if target_x >= slate[0] and target_x <= slate[1]: return {"right": false, "left": false, "jump": false}
	return navigate_to(game, target_x, target_y)

func navigate_to(game, target_x: float, target_y: float) -> Dictionary:
	var controls := {"right": true, "left": false, "jump": false}
	var dx := target_x - float(game.player.x)
	controls.right = dx > 3
	controls.left = dx < -3
	if game.grounded and not game.jump_held:
		if target_y < game.player.y - 6 and absf(dx) < 110: controls.jump = true
		var forward := 1 if dx >= 0 else -1
		# Leave a crumbling slate before its 0.65-second lifetime, while still
		# close enough to reach the following slate with a normal jump.
		for row in game.level.crumble:
			if game.player.x >= row[0] and game.player.x <= row[1] and absf(game.player.y - row[2]) < 2 and dx > 0 and game.player.x >= row[1] - 60: controls.jump = true
		# Step off a chimney onto its lower roof rather than launching across
		# the roof and undershooting the next gap's landing.
		if game._land(game.player.x + forward * 12, game.player.y - 2, game.player.y + 150) == INF and absf(dx) > 12: controls.jump = true
		for row in game.level.solids:
			if row[2] >= game.player.y - 6: continue
			var edge: float = row[0] if forward > 0 else row[1]
			var distance: float = (edge - game.player.x) * forward
			if distance >= 0 and distance < 70 and absf(dx) > distance: controls.jump = true
	return controls
