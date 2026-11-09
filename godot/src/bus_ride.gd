extends RefCounted
## 1-3 source levelStart/levelUpdate/levelSpawn. Absolute feet coordinates,
## seconds, pixels/second. This module does not itself enable a native level.
var enabled := false
var drive := 0.0
var slot := 0
var phase := "obst"
var obstacle_queue: Array = []
var obstacles: Array = []
var rest_time := 2.6
var scooters: Array = []
var warn_time := 0.0
var roof_y := 150.0
var end_time := 0.0
var clear_reported := false

func reset(host) -> void:
	enabled = host.level_id == "1-3"
	drive = 0.0
	slot = 0
	phase = "obst"
	obstacle_queue.clear()
	obstacles.clear()
	rest_time = 2.6
	scooters.clear()
	warn_time = 0.0
	end_time = 0.0
	clear_reported = false
	if not enabled: return
	roof_y = float(host.level.solids[0][2])
	# Must run AFTER combat.reset: all source at=0 waves are sequential here.
	for wave in host.combat.waves: wave.at = 1.0e9

func tick(dt: float, host) -> void:
	# Source levelUpdate is the last scene hook, after receipts/skill/slide.
	if not enabled or host.mode != "play": return
	host.camera.y = float(host.level.camY)
	var speed := float(host.level.drive) * 1000
	drive += speed * dt
	if phase == "obst":
		rest_time -= dt
		# Inspect obstacles before this frame's movement/removal. The next
		# obstacle or fight waits until the frame after the preceding one exits.
		if rest_time <= 0 and obstacles.is_empty():
			if not obstacle_queue.is_empty():
				var kind: String = obstacle_queue.pop_front()
				obstacles.append({"k": kind, "x": host.view_width() + 40 + speed * 1.9, "w": 330.0 if kind == "bridge" else 150.0, "hit": false})
				warn_time = 1.9
				rest_time = 0.9
			elif slot < host.combat.waves.size():
				host.combat.waves[slot].at = -1.0e9
				phase = "wave"
	elif phase == "wave":
		if slot < host.combat.waves.size() and host.combat.waves[slot].done:
			var between: Array = host.level.get("between", [])
			obstacle_queue = between[slot].duplicate() if slot < between.size() else []
			slot += 1
			phase = "obst"
			rest_time = 1.4
	warn_time = maxf(0, warn_time - dt)
	for obstacle in obstacles:
		obstacle.x -= speed * dt
		var bottom := roof_y - (132 if obstacle.k == "bridge" else 128)
		for player in _living(host):
			var solo: bool = player.get("host_player", false)
			var identity: int = int(player.get("slot", -1))
			if not obstacle.has("hit_slots"): obstacle.hit_slots = {}
			var hit: bool = obstacle.hit if solo else obstacle.hit_slots.has(identity)
			if hit or player.p.x < obstacle.x - 10 or player.p.x > obstacle.x + obstacle.w + 10: continue
			var crouched: bool = player.get("player_animation", "") == "crouch"
			var top_y: float = player.p.y - float(player.height) * (0.56 if crouched else 0.86)
			if top_y < bottom:
				# Source records each actor even if invulnerability blocks damage.
				if solo:
					obstacle.hit = true
					host.hurt_player(player.p.x + 40)
				else:
					obstacle.hit_slots[identity] = true
					host.hurt_combat_participant(player, player.p.x + 40)
				host.status = "Duck!"
		for enemy in host.enemies:
			if enemy.get("fly", enemy.get("kind", "") == "fly") or enemy.state == "pop" or enemy.get("segment", []) != host.level.solids[0] or not enemy.get("hop", {}).is_empty(): continue
			if enemy.p.x > obstacle.x and enemy.p.x < obstacle.x + obstacle.w: _kill_robot(host, enemy)
	obstacles = obstacles.filter(func(obstacle): return obstacle.x + obstacle.w > -60)
	for scooter in scooters:
		scooter.t += dt
		scooter.x += scooter.vx * dt
		scooter.vy += 1600 * dt
		scooter.y += scooter.vy * dt
	scooters = scooters.filter(func(scooter): return scooter.t < 1.5)

func spawn(host, side: String, kind: String) -> bool:
	# This hook comes BEFORE the shared tiny/mini/fly dispatcher. In the source,
	# all non-fly arrivals, including labels tiny/mini, use the ordinary 4-HP
	# scooter body. They do not receive shared Small Print or Bailiff upgrades.
	if not enabled or kind == "fly": return false
	var bus: Array = host.level.bus
	var right := side == "r"
	var x0 := float(bus[0]) + float(bus[2]) + 90 if right else float(bus[0]) - 90
	var x1: float = float(bus[0]) + float(bus[2]) - 110 - host.combat.rng.randf() * 120 if right else float(bus[0]) + 110 + host.combat.rng.randf() * 120
	var y0 := roof_y + 230
	var rush := kind == "rush"
	var enemy := {
		"p": Vector2(x0, y0), "kind": kind if kind in ["rush", "flat", "throw"] else "throw", "source_kind": kind, "type": kind,
		"hp": 3 if rush else 4, "max_hp": 3 if rush else 4, "state": "walk", "t": host.combat.rng.randf() * 0.4,
		"cd": 1.4 + host.combat.rng.randf() * 0.9, "entered": true, "stop": 0.0 if rush else 200 + host.combat.rng.randf() * 150,
		"speed": (100 if rush else 70) * (0.9 + host.combat.rng.randf() * 0.25), "face": -1 if right else 1,
		"flash": 0.0, "pending": false, "gone": 0.0, "wait": 0.0, "scale": 1.0, "fly": false, "big": false,
		"segment": host.level.solids[0], "fly_time": 0.0,
		"hop": {"start": Vector2(x0, y0), "finish": Vector2(x1, roof_y), "t": 0.0, "duration": 0.76, "segment": host.level.solids[0]}
	}
	host.enemies.append(enemy)
	scooters.append({"x": x0, "y": y0 - 10, "vx": 250.0 if right else -350.0, "vy": -200.0, "t": 0.0, "face": -1 if right else 1})
	host.sfx("jump")
	return true

func objective_tick(dt: float, host) -> String:
	# Same shared end condition, but callable only for an explicitly reset bus
	# module. WorldOne continues to reject bus preview completion by default.
	if not enabled or host.mode != "play" or _living(host).is_empty() or clear_reported: return ""
	var event := ""
	if end_time == 0 and host.boss == null and host.camera.x >= float(host.level.w) - host.view_width() - 2 and host.combat.waves.all(func(wave): return wave.done):
		end_time = 0.001
		event = "ending"
	if end_time > 0:
		end_time += dt
		if end_time > 2.6:
			clear_reported = true
			return "clear"
	return event

func _kill_robot(host, enemy: Dictionary) -> void:
	enemy.state = "pop"
	enemy.t = 0
	enemy.gone = 0
	host.add_coins(enemy.p - Vector2(0, 70), 4 + host.combat.rng.randi_range(0, 2))
	host.sfx("pop")

func _living(host) -> Array:
	if host.has_method("combat_participants"):
		return host.combat_participants().filter(func(player): return not player.get("down", false) and int(player.hearts) > 0)
	return [{"host_player": true, "p": host.player, "hearts": host.hearts, "height": host.character_height(), "player_animation": host.player_animation}] if host.hearts > 0 else []
