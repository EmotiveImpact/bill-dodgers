extends RefCounted
## Solo Captain input driver adapted for the party's late elevated bot.
## Writes only ordinary controls and its own read-only route observations.
const ROUTE := [Vector2(60, 482), Vector2(1100, 362), Vector2(1480, 362), Vector2(2400, 482), Vector2(3060, 412), Vector2(3300, 342), Vector2(3700, 342), Vector2(5100, 482)]
var trace := false
var route_step := 0
var saw_throw := false
var saw_charge := false
var raised_approach_frames := 0
var _raised_target: Dictionary = {}

func walk(game, controls: Dictionary, x: float, tolerance := 3.0) -> void:
	controls.left = x < game.player.x - tolerance
	controls.right = x > game.player.x + tolerance

func face_target(game, controls: Dictionary, x: float) -> void:
	if game.face != (1 if x >= game.player.x else -1):
		controls.right = x >= game.player.x
		controls.left = x < game.player.x

func navigate(game, controls: Dictionary, point: Vector2) -> void:
	walk(game, controls, point.x)
	if not game.grounded or game.jump_held: return
	var direction := 1 if point.x >= game.player.x else -1
	for row in game.level.solids:
		if row[2] >= game.player.y - 6: continue
		var distance: float = ((row[0] if direction > 0 else row[1]) - game.player.x) * direction
		if distance >= 0 and distance < 65 and absf(point.x - game.player.x) > distance: controls.jump = true

func controls_for(game) -> Dictionary:
	var c := {"left": false, "right": false, "jump": false, "down": false, "aim": false, "shoot": true, "special": false}
	if game.boss != null:
		var b: Dictionary = game.boss.state
		if b.state == "down":
			var jar: Dictionary = game.world_four.captain.jar
			walk(game, c, float(jar.p.x) if not jar.is_empty() else game.camera.x + game.view_width() / 2)
			c.shoot = false
			return c
		# Stand at normal shot range; turn by input only. Wait for one real
		# phase2 charge before finishing so the route observes its attack cycle.
		var destination: float = b.x - 220 if b.x > game.camera.x + game.view_width() / 2 else b.x + 220
		walk(game, c, clampf(destination, game.camera.x + 50, game.camera.x + game.view_width() - 50), 10)
		if absf(destination - game.player.x) < 16:
			c.left = false
			c.right = false
			face_target(game, c, b.x)
		c.shoot = (int(b.phase) == 1 and (saw_throw or int(b.hp) > 72)) or (int(b.phase) >= 2 and (saw_charge or int(b.hp) > 35))
		if b.state == "enter": c.shoot = false
		if game.grounded and not game.jump_held:
			for wave in b.wave:
				if absf(wave.x - game.player.x) < 90: c.jump = true
		return c
	if route_step < ROUTE.size():
		var goal: Vector2 = ROUTE[route_step]
		if game.grounded and absf(game.player.x - goal.x) < 12 and absf(game.player.y - goal.y) < 2:
			route_step += 1
			if trace: print("Captain waypoint=", route_step, " p=", game.player)
		if route_step < ROUTE.size(): navigate(game, c, ROUTE[route_step])
	else: navigate(game, c, Vector2(5520, 482))
	# Reach the starting receipt before fighting or moving the camera.
	if route_step == 0: return c
	var targets: Array = []
	for enemy in game.enemies:
		if enemy.state != "pop": targets.append({"x": enemy.p.x, "y": enemy.p.y, "kind": "bot"})
	for foe in game.world_four.foes.entries:
		if not foe.dead and game.world_four.foes.hittable(foe): targets.append({"x": foe.x, "y": foe.y, "kind": foe.kind})
	var target: Dictionary = {}
	for candidate in targets:
		if absf(candidate.y - game.player.y) > 70: continue
		if absf(candidate.x - game.player.x) > 450: continue
		if target.is_empty() or absf(candidate.x - game.player.x) < absf(target.x - game.player.x): target = candidate
	if _approach_raised_bot(game, c, target): return c
	if not target.is_empty() and game.grounded:
		c.left = false
		c.right = false
		c.jump = false
		face_target(game, c, target.x)
		c.down = target.kind in ["jet", "ring"] and not c.left and not c.right
	if game.abilities.meter >= 1: c.special = true
	return c


func _approach_raised_bot(game, controls: Dictionary, ordinary_target: Dictionary) -> bool:
	# Pair timing can leave the second wave's left flat bot on the 362px roof
	# after the human descended to 482. The solo driver's 70px/450px filter
	# ignores it and walks into the camera cap forever. Walk/jump back onto
	# that actual roof, using only ordinary human inputs. Never move the CPU,
	# actor, enemy, surface, camera or wave directly.
	if not _raised_target.is_empty() and _raised_target.state == "pop": _raised_target = {}
	if _raised_target.is_empty() and ordinary_target.is_empty() and game.combat.waves.any(func(w): return w.started and not w.done):
		for enemy in game.enemies:
			if enemy.state == "pop" or enemy.p.y >= game.player.y - 70: continue
			if enemy.p.x < game.camera.x - 30 or enemy.p.x > game.camera.x + game.view_width() + 30: continue
			if _raised_target.is_empty() or absf(enemy.p.x - game.player.x) < absf(_raised_target.p.x - game.player.x): _raised_target = enemy
	if _raised_target.is_empty(): return false
	if game.grounded and absf(game.player.y - _raised_target.p.y) < 10 and absf(game.player.x - _raised_target.p.x) < 450:
		_raised_target = {}
		return false
	var direction := 1 if _raised_target.p.x >= game.player.x else -1
	navigate(game, controls, Vector2(_raised_target.p.x - direction * 90, _raised_target.p.y))
	controls.aim = true
	controls.shoot = true
	controls.down = false
	if game.abilities.meter >= 1: controls.special = true
	raised_approach_frames += 1
	return true
