extends RefCounted
## Active TB/L puzzle from game/2-6/index.html:1200–1286, plus updateJar.
## Absolute world pixels, seconds, px/s. This is deliberately NOT host.boss.
## Caller: ordinary enemies -> buttons -> intercept_shot -> ordinary crates;
## late_tick follows shared world pickups/hazards and precedes late abilities.
const GROUND := 482.0
const WIDTH := 250.0
const HEIGHT := 340.0
const TIME_EPSILON := 0.000000001

var boss: Dictionary = {}
var jar: Dictionary = {}
var players: Dictionary = {} # Stable participant identity -> bag/carry/hit state.
var mash := 0
var events: Array = []
var clear_reported := false
var _host_id := 0
var _generation := -1
var _runtime: WeakRef

func reset(host, runtime) -> void:
	# Deliberate source replay repair. Continue must NOT call this method.
	_host_id = host.get_instance_id()
	_generation = runtime.run_generation
	_runtime = weakref(runtime)
	boss.clear()
	jar.clear()
	players.clear()
	mash = 0
	events.clear()
	clear_reported = false
	var surfaces: Array = runtime.surfaces(host)
	for index in range(surfaces.size() - 1, -1, -1):
		if surfaces[index].get("receipt", false): surfaces.remove_at(index)
	# Shared runtime.reset owns drop-zone counter reset, gates and scene state.
	for participant in _participants(host):
		var state := _player_state(participant)
		_publish_state(participant, state)

func _can_step(host, runtime = null) -> bool:
	if _runtime == null: return false
	var owner = _runtime.get_ref()
	return owner != null and (runtime == null or runtime == owner) and owner.run_generation == _generation and host.get_instance_id() == _host_id and host.level_id == "2-6" and host.mode == "play"

func ready_end(host) -> bool:
	# Source L.readyEnd: caller first requires camera >=4160 and all waves done.
	# Always false, so the normal timed exit cannot bypass the jar objective.
	if not _can_step(host) or not boss.is_empty(): return false
	var maximum := 90 if _participants(host).size() > 1 else 70
	boss = {"x": 4760.0, "hp": maximum, "max": maximum, "state": "enter", "t": 0.0,
		"flash": 0.0, "beam": null, "codes": [], "phase": 1, "dizzy": 0.0,
		"frozen": 0.0, "mouth": 0.0, "next": 1.8, "beams": 0, "crates": [],
		"placed": 0, "crateT": 0.0, "steps": 0, "stepT": 0.0, "spawnT": 0.0, "bounce": 0.0}
	host.camera_lock = camera_cap()
	host.status = "Unexpected item! Watch its scanner: low glow, jump. High glow, duck."
	host.sfx("warn")
	events.append({"type": "boss_music", "enabled": true})
	return false

func camera_cap() -> float:
	return 4162.0 if not boss.is_empty() else INF

func input_event(host) -> void:
	# Call once per native key-down/touch-start, including key-repeat. Do not
	# derive mash from held actions or count emulated mouse events a second time.
	if _can_step(host): mash += 1

func late_tick(dt: float, host, runtime) -> String:
	if not _can_step(host, runtime) or boss.is_empty() or clear_reported: return ""
	_update(dt, host, runtime)
	# Shared updateJar runs even when L.update takes an early return. Newly
	# spawned jars receive the current frame's full dt before collision checks.
	return _jar_tick(dt, host)

func _update(dt: float, host, runtime) -> void:
	boss.t += dt
	for timer in ["flash", "mouth", "bounce"]:
		boss[timer] = maxf(0, boss[timer] - dt)
		if boss[timer] <= TIME_EPSILON: boss[timer] = 0.0
	var pressed := mash
	mash = 0
	var roster := _participants(host)
	for participant in roster:
		var state := _player_state(participant)
		if state.bag > 0:
			state.bag = maxf(0, state.bag - dt - (0 if participant.get("cpu", false) else pressed * 0.16))
			if state.bag <= TIME_EPSILON: state.bag = 0.0
			_set_vx(host, participant, 0)
			_lock_bag(host, participant)
			if state.bag <= 0: events.append({"type": "bag_released", "p": participant.p - Vector2(0, 80)})
		_publish_state(participant, state)
	_update_crates(dt, host, roster)
	# codes/dizzy remain empty/inactive: executable source never starts either.
	if boss.state == "down":
		if boss.t > 1.5 + TIME_EPSILON and jar.is_empty():
			jar = {"p": Vector2(boss.x - 150, GROUND - 220), "v": Vector2(-150, -900), "t": 0.0, "got": false}
			host.sfx("power")
			events.append({"type": "jar_spawn", "p": jar.p})
		return
	if boss.state == "enter":
		if boss.t > 1.4 + TIME_EPSILON:
			boss.state = "fight"
			boss.t = 0.0
		return
	if boss.phase == 1 and boss.beams >= 3 and boss.beam == null:
		boss.phase = 2
		boss.next = 1.6
		host.status = "Bagging area: stack three crates on it to jam it."
		host.sfx("warn")
		_drop_crates(host, roster)
	if boss.phase == 2 and float(boss.hp) / float(boss.max) <= 0.3 and boss.frozen <= 0:
		boss.phase = 3
		boss.crates = boss.crates.filter(func(crate): return crate.st == "on")
		for state in players.values(): state.crate = null
		for participant in roster: _publish_state(participant, _player_state(participant))
		boss.stepT = 0.0
		boss.steps = 0
		boss.beam = null
		boss.next = 2.5
		host.status = "Please wait for assistance. Climb the receipt and hit its screen."
		host.sfx("warn")
		host.combat.spawn(host, "l", "rush")
		host.combat.spawn(host, "r", "rush")
	if boss.phase == 3 and boss.steps < 3:
		boss.stepT += dt
		if boss.stepT > 0.6 + TIME_EPSILON:
			boss.stepT = 0.0
			var step := receipt_step(boss.steps)
			runtime.surfaces(host).append(step)
			boss.steps += 1
			boss.mouth = 0.3
			host.sfx("throw")
	if boss.frozen > 0:
		boss.frozen -= dt
		if boss.frozen <= TIME_EPSILON:
			boss.frozen = 0.0
			boss.crates = boss.crates.filter(func(crate): return crate.st != "on")
			boss.placed = 0
			if boss.phase == 2: boss.crateT = 1.5
		return
	if boss.crateT > 0:
		boss.crateT -= dt
		if boss.crateT <= TIME_EPSILON:
			boss.crateT = 0.0
			if boss.phase == 2: _drop_crates(host, roster)
	if boss.phase == 2 and boss.placed >= 3 and boss.crates.all(func(crate): return crate.st != "fly"):
		boss.frozen = 5.0
		boss.beam = null
		boss.flash = 0.2
		host.sfx("stomp")
		host.status = "Unexpected item in the bagging area! Shoot it now."
		events.append({"type": "freeze", "shake": 10})
		return
	if boss.phase == 2 and not boss.crates.is_empty() and boss.crates.all(func(crate): return crate.st == "ground") and boss.t > 0: boss.crateT = 0.0
	if boss.phase >= 2:
		boss.spawnT += dt
		var cap := 2 if roster.size() > 1 else 1
		if boss.spawnT > 11.0 + TIME_EPSILON and host.enemies.filter(func(enemy): return enemy.state != "pop").size() < cap:
			boss.spawnT = 0.0
			host.combat.spawn(host, "l" if runtime.rng.randf() < 0.5 else "r", "rush")
	boss.next -= dt
	if boss.beam == null and boss.next <= TIME_EPSILON:
		boss.beam = {"y": GROUND - (34 if runtime.rng.randf() < 0.5 else 150), "t": 0.0}
	if boss.beam != null:
		var beam: Dictionary = boss.beam
		beam.t += dt
		if beam.t > 0.9 + TIME_EPSILON and beam.t < 1.45 - TIME_EPSILON:
			boss.mouth = 0.1
			for participant in _living(roster):
				var feet: float = participant.p.y
				var top := feet - float(participant.get("height", host.character_height())) * (0.56 if participant.get("crouching", false) else 0.86)
				if beam.y > top and beam.y < feet - 4 and participant.p.x < till_left(): _bag(host, participant)
			if beam.t - dt <= 0.9 + TIME_EPSILON: host.sfx("honk")
		if beam.t > 1.6 + TIME_EPSILON:
			boss.beam = null
			boss.beams += 1
			boss.next = 1.2 if boss.phase == 1 else (2.6 if boss.phase == 2 else 2.0)
	# Source barrier is deliberately skipped by enter/down/frozen/freeze-trigger.
	for participant in _living(roster):
		if participant.p.x > till_left() - 10:
			participant.p.x = till_left() - 40
			_player_state(participant).p = participant.p
			if participant.get("host_player", false): host.player.x = participant.p.x
			else: participant.px = participant.p.x

func _bag(host, participant: Dictionary) -> void:
	var state := _player_state(participant)
	var inv: float = host.invincible if participant.get("host_player", false) else participant.get("invincible", 0.0)
	if inv > 0 or not _alive(participant) or state.bag > 0: return
	if participant.get("host_player", false):
		host.hurt_player(participant.p.x + 100)
		participant.hearts = host.hearts
	else: host.hurt_combat_participant(participant, participant.p.x + 100)
	# Wrapped hurt may reject damage (shield/slide/dash); bag still applies.
	state.bag = 1.5
	_set_vx(host, participant, 0)
	_publish_state(participant, state)
	events.append({"type": "bagged", "p": participant.p - Vector2(0, 190), "cpu": participant.get("cpu", false)})

func _drop_crates(host, roster: Array) -> void:
	var living := _living(roster)
	for i in range(3):
		var x: float = host.camera.x + 300 if living.is_empty() else living[i % living.size()].p.x
		x = maxf(host.camera.x + 60, minf(till_left() - 160, x - 120 + i * 120))
		boss.crates.append({"p": Vector2(x, host.view_top() - 60 - i * 90), "vy": 0.0, "st": "fall", "k": i % 3, "by": null})
	host.sfx("warn")
	events.append({"type": "crates_dropped"})

func _update_crates(dt: float, host, roster: Array) -> void:
	for crate in boss.crates:
		if crate.st == "fall":
			crate.vy += 2500.0 * dt
			crate.p.y += crate.vy * dt
			if crate.p.y >= GROUND:
				crate.p.y = GROUND
				crate.st = "ground"
		elif crate.st == "ground" and boss.phase == 2:
			for participant in _living(roster):
				var state := _player_state(participant)
				if state.crate == null and state.bag <= 0 and absf(participant.p.x - crate.p.x) < 46 and participant.p.y > GROUND - 60:
					crate.st = "carry"
					crate.by = participant.checkout_id
					state.crate = crate
					_publish_state(participant, state)
					host.sfx("coin")
					break
		elif crate.st == "carry":
			var matches := roster.filter(func(participant): return participant.checkout_id == crate.by)
			if matches.is_empty() or not _alive(matches[0]) or matches[0].get("out", false):
				crate.st = "ground"
				crate.p.y = GROUND
				if players.has(crate.by): players[crate.by].crate = null
				if not matches.is_empty(): _publish_state(matches[0], _player_state(matches[0]))
				continue
			var participant: Dictionary = matches[0]
			crate.p = participant.p - Vector2(0, float(participant.get("height", host.character_height())) + 10)
			if participant.p.x > till_left() - 300:
				var slot: int = boss.placed % 3
				crate.st = "fly"
				crate.t = 0.0
				crate.start = crate.p
				crate.target = Vector2(4816 + [30, 90, 60][slot], 354 - (62 if slot == 2 else 0))
				_player_state(participant).crate = null
				_publish_state(participant, _player_state(participant))
				crate.by = null
				host.sfx("throw")
				boss.placed += 1
		elif crate.st == "fly":
			crate.t += dt
			var fraction := minf(1, crate.t / 0.65)
			crate.p = crate.start.lerp(crate.target, fraction) - Vector2(0, sin(fraction * PI) * 160)
			if fraction >= 1: crate.st = "on"

func intercept_shot(host, bullet: Dictionary) -> bool:
	if not _can_step(host) or boss.is_empty() or boss.state in ["enter", "down"]: return false
	var point: Vector2 = bullet.p
	if not (point.x > till_left() and point.x < till_left() + WIDTH and point.y > GROUND - HEIGHT - 20 and point.y < GROUND): return false
	var screen := point.y < GROUND - HEIGHT + 130
	if boss.frozen > 0:
		_hit(host, 3 if screen else 2, point, screen)
		_credit_hit(host, bullet)
		return true
	if boss.phase == 3 and screen:
		_hit(host, 3, point, true)
		_credit_hit(host, bullet)
		events.append({"type": "screen_hit", "p": point})
		return true
	var runtime = _runtime.get_ref()
	if boss.phase == 3 and runtime.rng.randf() < 0.34:
		_hit(host, 1, point, false)
		return true
	if boss.bounce <= 0:
		boss.bounce = 0.9
		host.sfx("hitBot")
		events.append({"type": "bounce_hint", "p": point, "phase": boss.phase})
	return true

func _credit_hit(host, bullet: Dictionary) -> void:
	if bullet.has("owner_slot") and int(bullet.owner_slot) >= 0:
		# Native projectiles keep a stable slot, not a reference to whichever
		# actor happens to occupy the scalar facade in this shared shot pass.
		for participant in _participants(host):
			if not participant.get("host_player", false) and int(participant.get("slot", -1)) == int(bullet.owner_slot):
				var state := _player_state(participant)
				state.boss_hits += 1
				_publish_state(participant, state)
				return
		return # Missing/stale owner is uncredited; never fall back to P1.
	if bullet.get("owner") is Dictionary:
		var owner: Dictionary = bullet.owner
		owner.bossHits = int(owner.get("bossHits", 0)) + 1
		if owner.has("checkout_id"):
			var state := _player_state(owner)
			state.boss_hits += 1
			_publish_state(owner, state)
	else:
		if _participants(host).any(func(participant): return not participant.get("host_player", false)): return
		# Existing native shots belong to the host and do not carry owner objects.
		var solo := _solo(host)
		_player_state(solo).boss_hits += 1

func _hit(host, amount: int, point: Vector2, screen: bool) -> void:
	if boss.phase < 3:
		var floor_hp := int(ceil(float(boss.max) * 0.3))
		boss.hp = maxi(floor_hp, boss.hp - amount)
		if boss.hp <= floor_hp and boss.frozen > 0: boss.frozen = 0.001
	else: boss.hp -= amount
	boss.flash = 0.08
	host.sfx("hitBot")
	events.append({"type": "hit", "p": point, "screen": screen, "amount": amount})
	if boss.hp <= 0 and boss.state != "down":
		boss.state = "down"
		boss.t = 0.0
		boss.beam = null
		boss.codes.clear()
		boss.frozen = 0.0
		host.sfx("pop")
		host.sfx("stomp")
		host.add_coins(Vector2(boss.x - 60, GROUND - 200), 20)
		for enemy in host.enemies:
			if enemy.state != "pop": host.combat.kill_enemy(host, enemy, false)
		for state in players.values():
			state.bag = 0.0
			state.crate = null
		for participant in _participants(host): _publish_state(participant, _player_state(participant))
		boss.crates.clear()
		host.status = "Thank you for shopping! Grab the jar!"
		events.append({"type": "down", "shake": 18})
		events.append({"type": "boss_music", "enabled": false})

func _jar_tick(dt: float, host) -> String:
	if jar.is_empty() or jar.got: return ""
	jar.t += dt
	if jar.p.y < GROUND - 30 or jar.v.y < 0:
		jar.v.y += 2400.0 * dt
		jar.p += jar.v * dt
		if jar.p.y >= GROUND - 30:
			jar.p.y = GROUND - 30
			jar.v.y = -jar.v.y * 0.4 if absf(jar.v.y) > 200 else 0.0
			jar.v.x *= 0.5
	for participant in _living(_participants(host)):
		if absf(participant.p.x - jar.p.x) < 50 and jar.t > 0.6 + TIME_EPSILON:
			jar.got = true
			jar.by = participant.checkout_id
			clear_reported = true
			return "jar_collected"
	return ""

func till_left() -> float: return float(boss.get("x", 4760)) - WIDTH * 0.5

func receipt_step(index: int) -> Dictionary:
	return {"row": [4385.0 + index * 80, 4475.0 + index * 80, GROUND - 70 - index * 65], "plat": true, "receipt": true}

func targets() -> Array:
	return [4700.0] if not boss.is_empty() and boss.state not in ["enter", "down"] else []

func cpu_input(host, participant: Dictionary, inputs: Dictionary) -> void:
	# Extension to shared CPU logic, not a CPU controller or automatic solver.
	if not _can_step(host) or boss.is_empty() or boss.state == "down": return
	var beam = boss.beam
	if beam != null:
		if beam.y < GROUND - 100 and beam.t > 0.5 + TIME_EPSILON and beam.t < 1.5 - TIME_EPSILON:
			inputs.down = true
			inputs.jump = false
			inputs.left = false
			inputs.right = false
			return
		if beam.y > GROUND - 100 and beam.t > 0.78 + TIME_EPSILON and beam.t < 1.0 - TIME_EPSILON and participant.get("grounded", false) and float(participant.get("jump_cd", 0)) <= 0:
			inputs.jump = true
			participant.jump_cd = 0.5
	var state := _player_state(participant)
	if boss.phase == 2 and boss.frozen <= 0:
		var crates: Array = boss.crates.filter(func(crate): return crate.st == "ground")
		crates.sort_custom(func(first, second): return absf(first.p.x - participant.p.x) < absf(second.p.x - participant.p.x))
		var target: Variant = 4375.0 if state.crate != null else (null if crates.is_empty() else crates[0].p.x)
		if target != null:
			inputs.right = target > participant.p.x + 10
			inputs.left = target < participant.p.x - 10
	if boss.phase == 3 and boss.steps > 0:
		var top := receipt_step(boss.steps - 1)
		if participant.p.y > float(top.row[2]) + 5:
			var index := mini(boss.steps - 1, maxi(0, int(floor((GROUND - participant.p.y) / 65.0 + 0.5))))
			var step := receipt_step(index)
			var want: float = (step.row[0] + step.row[1]) * 0.5
			inputs.right = participant.p.x < want - 20
			inputs.left = participant.p.x > want + 20
			if absf(participant.p.x - step.row[0]) < 90 and participant.get("grounded", false) and float(participant.get("jump_cd", 0)) <= 0:
				inputs.jump = true
				participant.jump_cd = 0.45
		else:
			inputs.left = false
			inputs.right = false
			inputs.face = 1

func _solo(host) -> Dictionary:
	return {"checkout_id": _host_id, "host_player": true, "p": host.player, "hearts": host.hearts, "height": host.character_height(), "crouching": host.crouching, "grounded": host.grounded, "cpu": false}

func _participants(host) -> Array:
	if not host.has_method("combat_participants"): return [_solo(host)]
	var roster: Array = host.combat_participants()
	for index in range(roster.size()):
		# The scalar host gained a combat snapshot API during party integration.
		# Its compatibility identity is still the host, not the sentinel slot -1.
		if roster[index].get("host_player", false): roster[index].checkout_id = _host_id
		# Persistent roster dictionaries receive an identity once. Hosts returning
		# fresh snapshots must supply a stable checkout_id (or id/slot).
		if not roster[index].has("checkout_id"): roster[index].checkout_id = roster[index].get("id", roster[index].get("slot", index))
	return roster

func _player_state(participant: Dictionary) -> Dictionary:
	var key: Variant = participant.get("checkout_id", participant.get("id", participant.get("slot", _host_id)))
	if not players.has(key): players[key] = {"bag": 0.0, "crate": null, "boss_hits": 0}
	players[key].p = participant.get("p", Vector2.ZERO)
	players[key].height = participant.get("height", 180.0)
	players[key].cpu = participant.get("cpu", false)
	return players[key]

func _publish_state(participant: Dictionary, state: Dictionary) -> void:
	# Solo state is exclusively component-owned; persistent co-op records expose
	# source-style bag/crate fields for the caller's future CPU/visual adapter.
	if not participant.get("host_player", false):
		participant.bag = state.bag
		participant.crate = state.crate
		participant.boss_hits = state.boss_hits

func _alive(participant: Dictionary) -> bool:
	return not participant.get("down", false) and int(participant.get("hearts", 0)) > 0

func _living(roster: Array) -> Array:
	return roster.filter(_alive)

func _set_vx(host, participant: Dictionary, value: float) -> void:
	if participant.get("host_player", false): host.velocity.x = value
	else:
		var speed: Vector2 = participant.get("velocity", Vector2.ZERO)
		speed.x = value
		participant.velocity = speed

func _lock_bag(host, participant: Dictionary) -> void:
	if participant.get("host_player", false):
		host.hurt_lock = maxf(host.hurt_lock, 0.06)
		host.player_animation = "hit"
	else:
		participant.hurt_lock = maxf(float(participant.get("hurt_lock", 0)), 0.06)
		participant.lock_animation = "hit"
		participant.player_animation = "hit"

func drain_events() -> Array:
	var result := events
	events = []
	return result

func snapshot() -> Dictionary:
	return {"active": not boss.is_empty(), "boss": boss.duplicate(true), "jar": jar.duplicate(true), "players": players.duplicate(true), "mash": mash, "clear_reported": clear_reported}
