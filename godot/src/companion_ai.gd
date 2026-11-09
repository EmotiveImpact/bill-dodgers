extends RefCounted
## Source updateCPU plus W2 lvCPU/checkout and W6 w6Aim. Feet use absolute native
## coordinates and all timers use seconds. Geometry comes from read-only queries.
## This emits ordinary actor controls; it never runs physics or the world clock.
var rng := RandomNumberGenerator.new()
var events: Array[Dictionary] = []

func _init() -> void:
	rng.seed = 1979

static func neutral() -> Dictionary:
	return {"left": false, "right": false, "jump": false, "down": false, "shoot": false, "aim": false, "special": false, "dash": false}

func controls(delta: float, actor, context: Dictionary) -> Dictionary:
	events.clear()
	var input := neutral()
	if not actor.is_alive(): return input
	var roster: Array = context.get("actors", [])
	if roster.is_empty(): return input
	var lead = roster[0]
	var world := int(context.get("world", 1))
	actor.ai.jump_cooldown -= delta
	if lead != actor and lead.is_alive():
		var far: bool = absf(lead.player.x - actor.player.x) > (320 if world == 6 else 460) or (lead.grounded and absf(lead.player.y - actor.player.y) > 50)
		actor.ai.far_time = actor.ai.far_time + delta if far else 0.0
		if actor.ai.far_time > 1.6 and lead.grounded and not _inside_wall(context, lead.player - Vector2(0, 10)):
			var before: Vector2 = actor.player
			actor.player = lead.player - Vector2(lead.face * 20, 0)
			actor.velocity.y = 0
			actor.grounded = true
			actor.on_platform = lead.on_platform
			actor.ai.far_time = 0.0
			events.append({"kind": "catch_up", "slot": actor.slot, "from": before, "to": actor.player})
	var down_mate = null
	for other in roster:
		if other != actor and (other.down or other.hearts <= 0) and not other.out:
			down_mate = other
			break
	var goal: Variant = down_mate.player.x if down_mate != null else null
	var camera := float(context.get("camera_x", 0))
	var width := float(context.get("view_width", 960.0 / 1.3))
	var enemies: Array = context.get("enemies", [])
	var boss: Dictionary = context.get("boss", {})
	var targets: Array = []
	for enemy in enemies:
		if _live(enemy) and float(enemy.p.x) > camera - 20 and float(enemy.p.x) < camera + width + 20: targets.append(float(enemy.p.x))
	if world in [4, 6]: targets.append_array(context.get("scene_targets", []))
	if _boss_on(boss): targets.append(float(boss.get("aim_x", boss.x)) if world == 4 else float(boss.x))
	if world == 2: targets.append_array(context.get("scene_targets", []))
	var target: Variant = null
	var distance := INF
	for x in targets:
		var candidate := absf(float(x) - actor.player.x)
		if candidate < distance:
			distance = candidate
			target = float(x)
	if down_mate == null and target != null:
		var direction := signf(float(target) - actor.player.x)
		if direction == 0: direction = 1
		var want := 300.0 if not boss.is_empty() and float(target) == float(boss.get("x", INF)) else 210.0
		if distance > want + 60: goal = float(target) - direction * want
		elif distance < want - 90: goal = actor.player.x - direction * 60
		actor.face = int(direction)
		input.shoot = rng.randf() < 0.9
		if world == 6: input.aim = _billing_aim(actor, float(target), context)
	elif down_mate == null: goal = lead.player.x - lead.face * 110
	if lead != actor and down_mate == null and lead.grounded and lead.player.y < actor.player.y - 40 and actor.grounded: goal = lead.player.x
	if goal != null and absf(float(goal) - actor.player.x) > 26:
		input.left = float(goal) < actor.player.x
		input.right = not input.left
		var direction := -1.0 if input.left else 1.0
		var look_x: float = actor.player.x + direction * 46
		var floor_y := _floor_below(context, look_x, actor.player.y - 2)
		var blocked: bool = _wall_clamp(context, actor.player.x, actor.player.x + direction * 40, actor.player.y) != actor.player.x + direction * 40
		var lead_above: bool = lead != actor and lead.player.y < actor.player.y - 40 and absf(lead.player.x - actor.player.x) < 200
		if actor.grounded and actor.ai.jump_cooldown <= 0 and (blocked or floor_y == INF or floor_y > actor.player.y + 30 or lead_above):
			input.jump = true
			actor.ai.jump_cooldown = 0.65
	if target != null and down_mate == null and absf(0 if goal == null else float(goal) - actor.player.x) <= 26:
		actor.face = -1 if float(target) < actor.player.x else 1
	for bill in context.get("bills", []):
		var dx: float = float(bill.p.x) - actor.player.x
		if absf(dx) < 140 and signf(-float(bill.v.x)) == signf(dx):
			if bill.get("flat", false): input.down = true
			elif actor.ai.jump_cooldown <= 0 and float(bill.p.y) > actor.player.y - 120:
				input.jump = true
				actor.ai.jump_cooldown = 0.7
	if world == 2: _supermarket(actor, lead, input, context)
	for wave in context.get("boss_waves", []):
		if absf(float(wave.x) - actor.player.x) < 110 and actor.ai.jump_cooldown <= 0:
			input.jump = true
			actor.ai.jump_cooldown = 0.6
	if _boss_on(boss) and absf(float(boss.x) - actor.player.x) < 140 and actor.ai.jump_cooldown <= 0 and rng.randf() < 0.02:
		input.jump = true
		actor.ai.jump_cooldown = 0.8
	_special(delta, actor, input, context)
	return input

func _special(delta: float, actor, input: Dictionary, context: Dictionary) -> void:
	var crowd := 0
	var camera := float(context.get("camera_x", 0))
	var width := float(context.get("view_width", 960.0 / 1.3))
	for enemy in context.get("enemies", []):
		if _live(enemy) and enemy.p.x > camera and enemy.p.x < camera + width: crowd += 1
	if actor.abilities.meter >= 1 and (crowd >= 2 or _boss_on(context.get("boss", {}))):
		actor.ai.special_wait += delta
		if actor.ai.special_wait > 0.7 and actor.abilities.active.is_empty():
			input.special = true
			actor.ai.special_wait = 0.0
	else: actor.ai.special_wait = 0.0

func _supermarket(actor, lead, input: Dictionary, context: Dictionary) -> void:
	var entities: Array = context.get("entities", [])
	for entity in entities:
		if entity.get("kind", "") == "trolley" and absf(float(entity.x) - actor.player.x) < 170 and signf(actor.player.x - float(entity.x)) == signf(float(entity.vx)) and actor.ai.jump_cooldown <= 0 and actor.grounded:
			input.jump = true
			actor.ai.jump_cooldown = 0.5
	for enemy in context.get("enemies", []):
		if enemy.get("state", "") == "cart" and absf(float(enemy.p.x) - actor.player.x) < 170 and signf(actor.player.x - float(enemy.p.x)) == float(enemy.get("cart_direction", 0)) and actor.ai.jump_cooldown <= 0 and actor.grounded:
			input.jump = true
			actor.ai.jump_cooldown = 0.5
	for hazard in context.get("hazards", []):
		var ahead: float = float(hazard.x) - actor.player.x
		var same_floor := absf(actor.player.y - float(hazard.y)) < 10
		match str(hazard.kind):
			"flame":
				var period := float(hazard.period)
				var phase := fposmod(float(context.get("elapsed", 0)) + float(hazard.get("offset", 0)), period) if period > 0 else 0.0
				if absf(ahead) < 110 and (phase < 1.15 or phase > period - 0.7) and same_floor and ((ahead > 0 and input.right) or (ahead < 0 and input.left)):
					input.right = false
					input.left = false
			"low":
				if absf(ahead) < 130 and same_floor:
					input.down = true
					input.jump = false
			"block":
				if ahead > 0 and ahead < 120 + (60 if context.get("auto", false) else 0) and actor.grounded and actor.ai.jump_cooldown <= 0 and same_floor:
					input.jump = true
					actor.ai.jump_cooldown = 0.45
	if lead != actor and lead.is_alive():
		for gate in context.get("gates", []):
			if float(gate.get("open", 0)) > 0.5 and not gate.get("held", false): continue
			var plate: Dictionary = {}
			for candidate in context.get("plates", []):
				if candidate.id == gate.id:
					plate = candidate
					break
			if plate.is_empty() or float(plate.x) > float(gate.x): continue
			if lead.player.x > float(plate.x) - 120 and lead.player.x < float(gate.x) + 10 and absf(lead.player.x - float(plate.x)) > 50:
				input.left = false
				input.right = false
				if absf(float(plate.x) - actor.player.x) > 18:
					input.left = float(plate.x) < actor.player.x
					input.right = not input.left
				actor.ai.far_time = 0.0
				if input.jump and not entities.any(func(entity): return entity.get("kind", "") == "trolley"):
					input.jump = absf(float(plate.y) - actor.player.y) > 8 and actor.grounded and float(plate.y) < actor.player.y - 8
	_checkout(actor, input, context)
	var extra: Callable = context.get("scene_cpu", Callable())
	if extra.is_valid(): extra.call(actor, input)

func _checkout(actor, input: Dictionary, context: Dictionary) -> void:
	var checkout: Dictionary = context.get("checkout", {})
	if checkout.is_empty() or not checkout.get("alive", false): return
	var ground := float(context.get("ground", 482))
	var beam: Dictionary = checkout.get("beam", {})
	if not beam.is_empty():
		var age := float(beam.age)
		if float(beam.y) < ground - 100 and age > 0.5 and age < 1.5:
			input.down = true
			input.jump = false
			input.left = false
			input.right = false
			return
		if float(beam.y) > ground - 100 and age > 0.78 and age < 1.0 and actor.grounded and actor.ai.jump_cooldown <= 0:
			input.jump = true
			actor.ai.jump_cooldown = 0.5
	if int(checkout.get("phase", 0)) == 2 and not checkout.get("frozen", false):
		var target: Variant = null
		if actor.scene_state.get("carrying_crate", checkout.get("carrying_crate", false)): target = float(checkout.till_left) - 260
		else:
			var distance := INF
			for crate in checkout.get("crates", []):
				if crate.get("state", "") == "ground" and absf(float(crate.x) - actor.player.x) < distance:
					distance = absf(float(crate.x) - actor.player.x)
					target = float(crate.x)
		if target != null:
			input.right = float(target) > actor.player.x + 10
			input.left = float(target) < actor.player.x - 10
	var steps: Array = checkout.get("steps", [])
	if int(checkout.get("phase", 0)) == 3 and not steps.is_empty():
		if actor.player.y > float(steps[-1].top) + 5:
			var index := mini(steps.size() - 1, maxi(0, roundi((ground - actor.player.y) / 65)))
			var step: Dictionary = steps[index]
			var wanted := (float(step.x0) + float(step.x1)) / 2
			input.right = actor.player.x < wanted - 20
			input.left = actor.player.x > wanted + 20
			if absf(actor.player.x - float(step.x0)) < 90 and actor.grounded and actor.ai.jump_cooldown <= 0:
				input.jump = true
				actor.ai.jump_cooldown = 0.45
		else:
			input.left = false
			input.right = false
			# Source assigns inp.face here (not p.face); retain this inert field.
			input.face = 1

func _billing_aim(actor, target: float, context: Dictionary) -> bool:
	for flier in context.get("fliers", []):
		if _live(flier) and absf(float(flier.p.x) - target) < 2:
			return actor.player.y - actor.character_height() * 0.6 - float(flier.p.y) > 60
	var boss: Dictionary = context.get("boss", {})
	if not boss.is_empty() and float(boss.get("offset_y", 0)) < -60 and absf(float(boss.x) - target) < 2: return true
	for enemy in context.get("enemies", []):
		if _live(enemy) and absf(float(enemy.p.x) - target) < 2:
			var shot_y: float = actor.player.y - actor.character_height() * 0.53
			if shot_y > float(enemy.p.y) - 10: return absf(float(enemy.p.x) - actor.player.x) > shot_y - float(enemy.p.y) + 60
	return false

func _inside_wall(context: Dictionary, point: Vector2) -> bool:
	var query: Callable = context.get("inside_wall", Callable())
	return bool(query.call(point)) if query.is_valid() else false

func _floor_below(context: Dictionary, x: float, y: float) -> float:
	var query: Callable = context.get("floor_below", Callable())
	return float(query.call(x, y)) if query.is_valid() else INF

func _wall_clamp(context: Dictionary, from_x: float, to_x: float, feet: float) -> float:
	var query: Callable = context.get("wall_clamp", Callable())
	return float(query.call(from_x, to_x, feet)) if query.is_valid() else to_x

static func _live(entity: Dictionary) -> bool:
	return bool(entity.get("alive", true)) and entity.get("state", "") not in ["pop", "down"] and float(entity.get("hp", 1)) > 0

static func _boss_on(boss: Dictionary) -> bool:
	return not boss.is_empty() and _live(boss)
