extends SceneTree
## Integration soak: regular control inputs traverse every wave and the boss.
## Invulnerability is an explicit test assist, so this is NOT difficulty QA.
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

func run_character(game, character: String) -> bool:
	game.character = character
	game.save = {"schema": 1, "receipts": {}}
	game.load_level("1-1")
	var ticks := 0
	var specials_used := 0
	for frame in range(36000):
		ticks = frame
		game.invincible = 999
		var controls := {"right": true, "shoot": true}
		var target: Dictionary = {}
		for enemy in game.enemies:
			if enemy.state == "pop": continue
			if target.is_empty() or absf(enemy.p.x - game.player.x) < absf(target.p.x - game.player.x): target = enemy
		if not target.is_empty():
			var dx: float = target.p.x - game.player.x
			controls.right = dx > 220
			controls.left = dx < -220
			if target.kind == "tiny": controls.down = true
			if target.kind == "fly":
				controls.aim = true
				controls.right = dx > 30
				controls.left = dx < -30
		if game.boss != null:
			var boss: Dictionary = game.boss.state
			if boss.state == "down" and not boss.jar.is_empty():
				controls.right = boss.jar.x > game.player.x + 10
				controls.left = boss.jar.x < game.player.x - 10
			elif target.is_empty():
				var dx: float = boss.x - game.player.x
				controls.right = dx > 220
				controls.left = dx < -220
		# Turn through movement input, rather than directly assigning player facing.
		var facing_x: float = game.player.x + 1
		if not target.is_empty(): facing_x = target.p.x
		elif game.boss != null:
			facing_x = game.boss.state.jar.x if game.boss.state.state == "down" and not game.boss.state.jar.is_empty() else game.boss.state.x
		if game.face != (1 if facing_x >= game.player.x else -1):
			controls.right = facing_x >= game.player.x
			controls.left = facing_x < game.player.x
		if game.abilities.meter >= 1: controls.special = true
		var was_active: String = game.abilities.active
		game.step(1.0 / 60, controls)
		if was_active.is_empty() and not game.abilities.active.is_empty(): specials_used += 1
		if game.mode == "clear": break
	var passed: bool = game.mode == "clear" and game.combat.waves.all(func(wave): return wave.done) and game.boss != null and game.boss.state.jar.get("got", false) and game.combat.waves.size() == 12 and specials_used > 0 and game.save.get("cleared", {}).get("1-1", false)
	print("Full street input soak [", character, "]: ", "PASS" if passed else "FAIL", " ticks=", ticks + 1, " specials=", specials_used, " clear=", game.mode == "clear", " jar=", game.boss != null and game.boss.state.jar.get("got", false), " x=", game.player.x, " camera=", game.camera.x, " popped=", game.pop_count, " waves=", game.combat.waves.filter(func(w): return w.done).size(), "/", game.combat.waves.size())
	if not passed:
		printerr("Remaining enemies [", character, "]: ", game.enemies.filter(func(e): return e.state != "pop"))
		printerr("Boss [", character, "]: ", game.boss.state if game.boss != null else {}, " player=", game.player, " face=", game.face)
	return passed
