extends RefCounted
## Source shared World 2 shelves, floors and falling stock (2-2:738–819,860–863).
## Coordinates are absolute pixels; timers are seconds; velocities are px/s.
## The owning runtime chooses supported levels and the order of these phases.
const KINDS := ["gate", "plate", "button", "ice", "slow", "belt", "drops"]
const TIME_EPSILON := 0.000000001

var gates: Array = []
var plates: Array = []
var buttons: Array = []
var drop_counters: Dictionary = {} # Authored hazard index -> occupied seconds.
var ice_velocity: Dictionary = {} # Stable participant identity -> px/s.
var hazards: Array = [] # Lossless copy, including schemas owned by later modules.
var hinted: Dictionary = {}
var _host_id := 0
var _level_id := ""
var _generation := -1
var _runtime: WeakRef

func reset(host, runtime) -> void:
	_host_id = host.get_instance_id()
	_level_id = host.level_id
	_generation = runtime.run_generation
	_runtime = weakref(runtime)
	gates.clear()
	plates.clear()
	buttons.clear()
	drop_counters.clear()
	ice_velocity.clear()
	hinted.clear()
	hazards = runtime.hazards.duplicate(true)
	# Idempotent component reset also works without rebuilding the runtime.
	# Preserve other hazard entities and all non-gate surface identities.
	var surfaces: Array = runtime.surfaces(host)
	for index in range(surfaces.size() - 1, -1, -1):
		if surfaces[index].has("gate"): surfaces.remove_at(index)
	for index in range(runtime.entities.size() - 1, -1, -1):
		if runtime.entities[index].get("k", "") == "drop": runtime.entities.remove_at(index)
	for hazard in hazards:
		if not hazard is Array or hazard.is_empty(): continue
		match hazard[0]:
			"gate":
				var surface := {"row": [float(hazard[1]) - 34, float(hazard[1]) + 34, float(hazard[2]) - float(hazard[3])], "plat": false, "gate": hazard[4]}
				surfaces.append(surface)
				gates.append({"x": float(hazard[1]), "floor": float(hazard[2]), "h": float(hazard[3]), "id": hazard[4], "q": surface, "open": 0.0, "timer": 0.0, "held": false})
			"plate":
				plates.append({"x": float(hazard[1]), "y": float(hazard[2]), "id": hazard[3], "on": false})
			"button":
				buttons.append({"x": float(hazard[1]), "y": float(hazard[2]), "id": hazard[3], "hit": 0.0})

func _can_step(host, runtime = null) -> bool:
	if _runtime == null: return false
	var owner = _runtime.get_ref()
	return owner != null and (runtime == null or runtime == owner) and owner.run_generation == _generation and host.get_instance_id() == _host_id and host.level_id == _level_id and host.mode == "play"

func base_displacement(dt: float, host, move: float) -> float:
	# Movement runs against the active scalar facade, before the shared roster
	# is published. Only its identity comes from the party, never its stale p.
	var slot: int = host.combat_owner_slot() if host.has_method("combat_owner_slot") else -1
	var identity: Variant = slot if slot >= 0 else host.get_instance_id()
	return participant_displacement(dt, host, move, _solo(host), identity)

func participant_displacement(dt: float, host, move: float, participant: Dictionary, participant_id: Variant) -> float:
	# Explicit identity prevents mutable record hashes, party order or a new
	# snapshot each frame from transferring one participant's ice momentum.
	if not _can_step(host): return 0.0
	var position: Vector2 = participant.p
	var grounded: bool = participant.get("grounded", false)
	var velocity := move * 270.0
	var ice := false
	var slow := false
	for hazard in hazards:
		if not hazard is Array or hazard.is_empty() or hazard[0] not in ["ice", "slow"]: continue
		var top := float(hazard[3]) if hazard.size() > 3 and hazard[3] else float(host.meta.ground)
		if position.x > float(hazard[1]) and position.x < float(hazard[2]) and absf(position.y - top) < 4:
			if hazard[0] == "ice" and grounded: ice = true
			if hazard[0] == "slow": slow = true
	if slow: velocity *= 0.55
	var previous := float(ice_velocity.get(participant_id, velocity))
	if ice:
		previous += (move * 310.0 - previous) * minf(1, dt / 0.9)
	elif not grounded and ice_velocity.has(participant_id) and absf(previous) > absf(velocity):
		previous += (velocity - previous) * minf(1, dt / 0.5)
	else:
		previous = velocity
	ice_velocity[participant_id] = previous
	var displacement := previous * dt
	for hazard in hazards:
		if not hazard is Array or hazard.is_empty() or hazard[0] != "belt": continue
		if grounded and position.x > float(hazard[1]) and position.x < float(hazard[2]) and absf(position.y - float(hazard[3])) < 4:
			displacement += float(hazard[4]) * 1000.0 * dt
	return displacement

func gates_tick(dt: float, host, runtime) -> void:
	if not _can_step(host, runtime): return
	var participants := _participants(host)
	var living := _living(participants)
	for plate in plates:
		var was: bool = plate.on
		plate.on = living.any(func(player): return player.get("grounded", false) and absf(player.p.x - plate.x) < 46 and absf(player.p.y - plate.y) < 6)
		if plate.on and not was: host.sfx("select")
	for gate in gates:
		gate.held = plates.any(func(plate): return plate.id == gate.id and plate.on)
		if gate.held:
			gate.timer = 2.6 if participants.size() > 1 and not participants.any(func(player): return player.get("cpu", false)) else 5.2
		else:
			gate.timer = maxf(0, gate.timer - dt)
		var inside := living.any(func(player): return player.p.x > gate.x - 60 and player.p.x < gate.x + 60)
		var want: bool = gate.held or gate.timer > 0 or (gate.open > 0.5 and inside)
		if want and gate.open == 0: host.sfx("power")
		gate.open = clampf(gate.open + (1 if want else -1) * dt / 0.38, 0, 1)
		gate.q.row[2] = float(host.meta.ground) + 5000 if gate.open > 0.55 else gate.floor - gate.h
		var near := living.any(func(player): return player.p.x > gate.x - 300 and player.p.x < gate.x - 40 and gate.open < 0.5)
		if near and not hinted.has(gate.id):
			hinted[gate.id] = true
			var matching := buttons.filter(func(button): return button.id == gate.id)
			host.status = "Stand on the yellow pad!" if matching.is_empty() else ("Climb the shelf, shoot the button!" if matching[0].y < gate.floor - 200 else "Shoot the green button!")
	for button in buttons: button.hit = maxf(0, button.hit - dt)

func intercept_shot(host, bullet: Dictionary) -> bool:
	# Called after ordinary bots, before checkout/crates and wall cleanup.
	# Point overlap, not a swept test; ghost shots use exactly the same hook.
	if not _can_step(host): return false
	var position: Vector2 = bullet.p
	for button in buttons:
		if absf(position.x - button.x) < 30 and absf(position.y - button.y) < 30:
			button.hit = 0.3
			for gate in gates:
				if gate.id == button.id: gate.timer = maxf(gate.timer, 6.5)
			host.sfx("power")
			return true
	return false

func drops_tick(dt: float, host, runtime) -> void:
	if not _can_step(host, runtime): return
	for index in range(hazards.size()):
		var hazard = hazards[index]
		if not hazard is Array or hazard.is_empty() or hazard[0] != "drops": continue
		var occupants := _living(_participants(host)).filter(func(player): return player.p.x > float(hazard[1]) and player.p.x < float(hazard[2]))
		if occupants.is_empty(): continue
		drop_counters[index] = float(drop_counters.get(index, 0)) + dt
		if drop_counters[index] + TIME_EPSILON < float(hazard[3]) / 1000.0: continue
		# At most one attempt per zone/frame. No catch-up; failed support still
		# consumes the interval and both gameplay RNG draws, as in JavaScript.
		drop_counters[index] = 0.0
		var target: Dictionary = occupants[mini(occupants.size() - 1, int(floor(runtime.rng.randf() * occupants.size())))]
		var x: float = target.p.x + (runtime.rng.randf() - 0.4) * 160 + float(target.get("face", 1)) * 60
		var landing: Dictionary = runtime.below(host, x, target.p.y - 300)
		if not landing.is_empty():
			runtime.entities.append({"k": "drop", "p": Vector2(x, host.view_top() - 80), "top": float(landing.row[2]), "vy": 0.0, "warn": 0.95, "t": 0.0, "kind": String(hazard[4]) if hazard.size() > 4 and hazard[4] else "box", "dead": false})
	# New drops receive this frame's full dt, including warning expiry.
	# Dead removal belongs after carts/drones/picks in the owner's late phase.
	for entity in runtime.entities:
		if entity.get("k", "") != "drop": continue
		entity.t += dt
		if entity.t + TIME_EPSILON < entity.warn: continue
		entity.vy += 3200.0 * dt
		entity.p.y += entity.vy * dt
		for player in _living(_participants(host)):
			var top: float = player.p.y - float(player.get("height", host.character_height())) * (0.56 if player.get("crouching", false) else 0.86)
			if absf(player.p.x - entity.p.x) < 34 and entity.p.y > top and entity.p.y - 60 < player.p.y:
				_hurt(host, player, entity.p.x)
				entity.dead = true
		if entity.p.y >= entity.top:
			entity.dead = true
			host.sfx("stomp")

func _solo(host) -> Dictionary:
	return {"host_player": true, "p": host.player, "hearts": host.hearts, "height": host.character_height(), "crouching": host.crouching, "grounded": host.grounded, "face": host.face, "cpu": false}

func _participants(host) -> Array:
	# Reuse the combat adapter; no second, incompatible co-op roster contract.
	return host.combat_participants() if host.has_method("combat_participants") else [_solo(host)]

func _living(participants: Array) -> Array:
	return participants.filter(func(player): return not player.get("down", false) and int(player.hearts) > 0)

func _hurt(host, player: Dictionary, from_x: float) -> void:
	if player.get("host_player", false): host.hurt_player(from_x)
	else: host.hurt_combat_participant(player, from_x)
