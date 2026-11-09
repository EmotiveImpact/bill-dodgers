extends RefCounted
## Read-only adapters from the existing world runtimes to CompanionAI. Creating a
## context must never tick a scene or synthesize a second player's world state.
static func build(host, party, actor = null) -> Dictionary:
	var world := int(str(host.level_id).get_slice("-", 0))
	var context := {"world": world, "actors": party.actors, "camera_x": float(host.camera.x),
		"view_width": float(host.view_width()), "elapsed": float(host.elapsed),
		"ground": float(host.meta.get("ground", 482)), "auto": float(host.level.get("auto", 0)) != 0,
		"enemies": [], "bills": [], "boss": {}, "scene_targets": [], "boss_waves": [],
		"floor_below": Callable(host, "skill_floor_below"),
		"wall_clamp": Callable(host, "skill_wall_clamp"),
		"inside_wall": Callable(host, "ability_inside_wall")}
	for enemy in host.enemies:
		var snapshot: Dictionary = enemy.duplicate()
		if enemy.has("cart_dir"): snapshot.cart_direction = enemy.cart_dir
		context.enemies.append(snapshot)
	for bullet in host.bullets:
		if bullet.get("enemy", false) and float(bullet.get("life", 1)) > 0 and not bullet.get("dead", false):
			context.bills.append({"p": bullet.p, "v": bullet.v, "flat": bool(bullet.get("flat", false))})
	if host.boss != null:
		var state: Dictionary = host.boss.state
		if not state.is_empty():
			context.boss = state.duplicate()
			if state.has("aimX"): context.boss.aim_x = state.aimX
			if state.has("yo"): context.boss.offset_y = state.yo
			context.boss_waves = state.get("waves", state.get("wave", [])).duplicate()
	match world:
		2: _supermarket(host, actor, context)
		4:
			var foes = host.world_four.foes
			for foe in foes.entries:
				if not foe.get("dead", false) and foes.hittable(foe) and foe.kind != "case" and float(foe.x) > context.camera_x - 20 and float(foe.x) < context.camera_x + context.view_width + 20:
					context.scene_targets.append(float(foe.x))
		6:
			context.fliers = []
			for flier in host.world_six.fliers:
				context.fliers.append(flier.duplicate())
				if flier.get("state", "") != "pop" and flier.get("entered", false): context.scene_targets.append(float(flier.p.x))
			var mini: Dictionary = host.world_six.mini_boss
			if not mini.is_empty() and mini.get("state", "") == "fight": context.scene_targets.append(float(mini.x))
	return context

static func _supermarket(host, actor, context: Dictionary) -> void:
	var world = host.world_two
	context.entities = []
	for entity in world.entities:
		if entity.get("k", "") == "trolley":
			context.entities.append({"kind": "trolley", "x": float(entity.p.x), "vx": float(entity.v.x)})
	context.hazards = []
	for row in world.hazards:
		if not row is Array or row.size() < 3 or row[0] not in ["flame", "low", "block"]: continue
		var hazard := {"kind": row[0], "x": float(row[1]), "y": float(row[2])}
		if row[0] == "flame":
			hazard.period = float(row[3]) / 1000.0
			hazard.offset = float(row[4]) / 1000.0 if row.size() > 4 and row[4] != null else 0.0
		context.hazards.append(hazard)
	context.gates = world.hazard_controller.gates.duplicate(true)
	context.plates = world.hazard_controller.plates.duplicate(true)
	var checkout = world.checkout
	if checkout == null or checkout.boss.is_empty(): return
	context.scene_targets = checkout.targets()
	var boss: Dictionary = checkout.boss
	var puzzle := {"alive": boss.state != "down", "phase": int(boss.phase), "frozen": float(boss.frozen) > 0,
		"till_left": checkout.till_left(), "crates": [], "steps": [], "beam": {}, "carrying_crate": false}
	if boss.beam != null: puzzle.beam = {"y": float(boss.beam.y), "age": float(boss.beam.t)}
	for crate in boss.crates: puzzle.crates.append({"x": float(crate.p.x), "state": str(crate.st)})
	for index in int(boss.steps):
		var step: Dictionary = checkout.receipt_step(index)
		puzzle.steps.append({"x0": float(step.row[0]), "x1": float(step.row[1]), "top": float(step.row[2])})
	if actor != null:
		var state: Dictionary = checkout.players.get(actor.slot, {})
		puzzle.carrying_crate = state.get("crate") != null
	context.checkout = puzzle
