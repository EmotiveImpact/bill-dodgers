extends RefCounted
## Shared abilities port. All times are seconds and velocities pixels/second.
const SPEC = {
	"jp": {"name": "Coin rain", "duration": 1.8, "color": "#f4c542"},
	"maya": {"name": "Flower shield", "duration": 6.0, "color": "#ff8fc7"},
	"ama": {"name": "Bubble trap", "duration": 4.2, "color": "#8fd3ff"},
	"leo": {"name": "Paper glider", "duration": 5.0, "color": "#ffffff"},
	"theo": {"name": "Ricochet ball", "duration": 3.6, "color": "#7fe08f"},
	"mei": {"name": "Sugar rush", "duration": 6.0, "color": "#d7a8ff"},
}
const HEIGHTS = {"jp": 180.0, "maya": 162.0, "ama": 171.0, "leo": 187.0, "theo": 178.0, "mei": 160.0}
var character := "jp"
var skills: Array = []
var meter := 0.5
var active := ""
var remaining := 0.0
var duration := 0.0
var effects: Array = []
var rng := RandomNumberGenerator.new()
var _requested := false
var _held := false
var _pops := 0
var _time := 0.0
var _next := 0.0
var _count := 0
var _hits := 0
var _boss_next := 0.0
var _start_y := 0.0

func reset(who: String, unlocked: Array = []) -> void:
	character = who if SPEC.has(who) else "jp"
	skills = unlocked.duplicate()
	meter = 0.5
	active = ""
	remaining = 0.0
	duration = 0.0
	effects.clear()
	_requested = false
	_held = false
	_pops = 0
	_time = 0.0
	_next = 0.0
	_count = 0
	_hits = 0
	_boss_next = 0.0
	rng.seed = 1979

func power() -> float:
	return 1.5 if skills.has("super") else 1.0

func request_special() -> void:
	_requested = true

func speed_multiplier() -> float:
	var extra := 0.12 if character == "mei" else 0.0
	if active == "mei": extra += 0.7 if power() > 1.0 else 0.6
	return 1.0 + extra

func airborne_speed_multiplier() -> float:
	return speed_multiplier() + (0.35 if active == "leo" else 0.0)

func jump_multiplier() -> float:
	return (1.09 if character == "ama" else 1.0) * (1.06 if active == "mei" else 1.0)

func max_fall_speed(jump_held: bool) -> float:
	return 340.0 if character == "leo" and active != "leo" and jump_held else INF

func blocks_damage(host) -> bool:
	# Invoke only for eligible damage attempts, after existing invulnerability checks.
	if active == "maya": return true
	if character != "maya": return false
	_hits += 1
	if _hits % 2 == 0:
		host.invincible = 0.9
		return true
	return false

func enemy_is_bubbled(enemy: Dictionary) -> bool:
	return float(enemy.get("ab_bubble", 0.0)) > 0.0

func _live(enemy: Dictionary) -> bool:
	return enemy.get("state", "") != "pop" and not enemy.get("lost", false) and enemy.get("hp", 1) > 0

func _in_view(x: float, host) -> bool:
	return x > host.camera.x - 20.0 and x < host.camera.x + host.view_width() + 20.0

func _boss_on(host) -> bool:
	return host.boss != null and host.boss.state.get("state", "") not in ["down", "enter"] and host.boss.state.get("hp", 0) > 0

func _shot(host, p: Vector2, v: Vector2, damage: int, kind: String, homing := false) -> void:
	host.bullets.append({"p": p, "v": v, "life": 5.0, "enemy": false, "damage": damage, "homing": homing, "gravity": 0.0, "kind": kind, "ab_rain": kind == "rain", "owner_slot": host.combat_owner_slot() if host.has_method("combat_owner_slot") else -1, "owner_x": host.player.x})

func _start(host) -> void:
	meter = 0.0
	active = character
	duration = float(SPEC[character].duration) * power()
	remaining = duration
	_next = 0.0
	_count = 0
	_start_y = host.player.y
	if host.has_method("fx_float"): host.fx_float(SPEC[character].name + "!", host.player - Vector2(0, HEIGHTS[character] + 44), Color(SPEC[character].color))
	if host.has_method("fx_shake"): host.fx_shake(5)
	if host.has_method("fx_burst"): host.fx_burst(host.player - Vector2(0, HEIGHTS[character] * .5), Color(SPEC[character].color), 16)
	if active == "ama":
		for enemy in host.enemies:
			if _live(enemy) and _in_view(enemy.p.x, host) and not enemy_is_bubbled(enemy):
				enemy.ab_bubble = duration
				enemy.ab_bubble_total = duration
				enemy.ab_floor = enemy.p.y
		for bullet in host.bullets:
			if bullet.get("enemy", false) and _in_view(bullet.p.x, host): bullet.life = 0.0
		if _boss_on(host):
			host.boss.state.dizzy = maxf(float(host.boss.state.get("dizzy", 0.0)), 3.5 * power())
			host.damage_boss(3)
	elif active == "leo" and host.grounded:
		host.grounded = false
		host.velocity.y = -800.0
	elif active == "theo":
		effects.append({"kind": "ball", "p": host.player + Vector2(host.face * 40, -HEIGHTS[character] * 0.55), "v": Vector2(host.face * 620, -420), "age": 0.0, "life": duration, "spin": 0.0, "free": 0.0, "boss_next": 0.0, "floor": host.player.y, "trail": []})

func tick(dt: float, controls: Dictionary, host, defer_effects: bool = false) -> void:
	# Source abPost runs before combat with the previous AB.t. In deferred mode,
	# the host calls effects_tick AFTER boss/bin collisions to advance that clock.
	# Other stages retain the existing combined ordering by default.
	if not defer_effects: _time += dt
	var held: bool = controls.get("special", false)
	var want := _requested or (held and not _held)
	_requested = false
	_held = held
	if active.is_empty():
		var rate := 2.0 if skills.has("super") else 1.0
		meter = minf(1.0, meter + (dt / 30.0 + maxi(0, host.pop_count - _pops) * 0.07) * rate)
	_pops = host.pop_count
	if want and active.is_empty() and meter >= 1.0: _start(host)
	if not active.is_empty():
		remaining -= dt
		_special_tick(dt, controls, host)
		if remaining <= 0.0:
			if active == "jp": host.add_coins(host.player + Vector2(0, -HEIGHTS[character] - 10), roundi(5 * power()))
			if active == "maya" and host.has_method("fx_burst"): host.fx_burst(host.player - Vector2(0, HEIGHTS[character] * .5), Color("ff8fc7"), 12)
			active = ""
			remaining = 0.0
	if host.has_method("ability_post_motion"): host.ability_post_motion(dt, controls)
	_passives(dt, controls, host)
	if not defer_effects:
		_tick_bubbles(dt, host, false)
		_tick_effects(dt, host)

func bubbles_tick(dt: float, host) -> void:
	# Pair with deferred tick. Combat must skip live held bubbles in both its
	# bot-AI and cleanup loops, then call this before its projectile pass.
	_tick_bubbles(dt, host, true)

func _tick_bubbles(dt: float, host, source_order: bool) -> void:
	var held: Array = host.enemies.filter(func(enemy): return enemy_is_bubbled(enemy) and _live(enemy))
	if source_order:
		# Source updateBots removes held bubbles then appends them after all
		# normal bots, which matters when overlapping shots pick their target.
		host.enemies = host.enemies.filter(func(enemy): return not (enemy_is_bubbled(enemy) and _live(enemy)))
	for enemy in held:
		enemy.ab_bubble = maxf(0.0, enemy.ab_bubble - dt)
		if source_order: enemy.flash = maxf(0.0, float(enemy.get("flash", 0.0)) - dt)
		var k: float = 1.0 - enemy.ab_bubble / enemy.ab_bubble_total
		enemy.p.y = enemy.ab_floor - minf(1.0, k * 8.0) * 44.0 + sin(_time / 0.260 + enemy.p.x) * 5.0
		if enemy.ab_bubble <= 0.0:
			enemy.p.y = enemy.ab_floor
			host.damage_enemy(enemy, 1)
	if source_order: host.enemies.append_array(held)

func effects_tick(dt: float, host) -> void:
	# Pair once with tick(..., true); source abTick runs after the whole scene.
	_time += dt
	_tick_effects(dt, host)

func _tick_effects(dt: float, host) -> void:
	for effect in effects:
		effect.age += dt
		_ball_tick(effect, dt, host)
	effects = effects.filter(func(f): return f.age < f.life and not f.get("dead", false))

func _special_tick(dt: float, controls: Dictionary, host) -> void:
	var h: float = HEIGHTS[character]
	if active == "jp":
		_next -= dt
		if _next <= 0.0:
			_next = duration / (26.0 * power())
			_count += 1
			var targets: Array = host.enemies.filter(func(e): return _live(e) and _in_view(e.p.x, host))
			var r := rng.randf()
			var x: float
			if _boss_on(host) and r < 0.35: x = host.boss.state.x + rng.randf_range(-45, 45)
			elif not targets.is_empty() and r < 0.75: x = targets[rng.randi_range(0, targets.size() - 1)].p.x + rng.randf_range(-15, 15)
			else: x = host.camera.x + 40 + rng.randf() * (host.view_width() - 80)
			_shot(host, Vector2(x, host.view_top() - 20), Vector2(rng.randf_range(-20, 20), rng.randf_range(720, 920)), 2, "rain")
	elif active == "maya":
		var cy: float = host.player.y - h * 0.5
		for bullet in host.bullets:
			if bullet.get("enemy", false) and absf(bullet.p.x - host.player.x) < 100 and absf(bullet.p.y - cy) < 110: bullet.life = 0.0
		for enemy in host.enemies:
			if _live(enemy) and not enemy_is_bubbled(enemy) and absf(enemy.p.x - host.player.x) < 92 and absf(enemy.p.y - 56 - cy) < 110 and enemy.get("ab_shield_next", 0.0) <= _time:
				enemy.ab_shield_next = _time + 0.35
				host.damage_enemy(enemy, 1)
		if _boss_on(host) and absf(host.boss.state.x - host.player.x) < 140 and absf(host.boss.state.fy - host.player.y) < 260 and _boss_next <= _time:
			_boss_next = _time + 0.35
			host.damage_boss(1)
	elif active == "leo":
		if not host.grounded:
			if controls.get("jump", false): host.velocity.y = maxf(-320, host.velocity.y - 4000 * dt)
			elif controls.get("down", false): host.velocity.y = minf(550, host.velocity.y + 3000 * dt)
			else: host.velocity.y = minf(host.velocity.y, 70)
			if (host.player.y < host.view_top() + h + 90 or host.player.y < _start_y - 260) and host.velocity.y < 0: host.velocity.y = maxf(host.velocity.y, 20)
		_next -= dt
		if _next <= 0:
			_next = 0.3
			_count += 1
			_shot(host, host.player + Vector2(host.face * h * 0.3, -h * 0.62), Vector2(host.face * 850, 250 if _count % 3 == 0 else 0), 1, "plane", true)
	elif active == "mei": host.cooldown = minf(host.cooldown, 0.105)

func _passives(dt: float, controls: Dictionary, host) -> void:
	if character == "jp":
		var center: Vector2 = host.player + Vector2(0, -HEIGHTS[character] * 0.4)
		for coin in host.coins:
			if coin.get("age", 0.0) < 0.25: continue
			var delta: Vector2 = center - coin.p
			var distance := delta.length()
			if distance < 300 and distance > 1:
				coin.p += delta * minf(distance, 550 * dt) / distance
				coin.v = Vector2.ZERO
				coin.rest = true
				coin.ab_magnet = true
			elif coin.get("ab_magnet", false):
				coin.ab_magnet = false
				coin.rest = false
	var movement_locked: bool = host.ability_movement_locked() if host.has_method("ability_movement_locked") else false
	if character == "theo" and host.grounded and not movement_locked and (controls.get("left", false) != controls.get("right", false)):
		for crate in host.crates:
			if not crate.get("broken", false) and absf(host.player.x + host.face * 24 - crate.p.x) < 50 and absf(crate.p.y - host.player.y) < 50 and crate.get("ab_kick_next", 0.0) <= _time:
				crate.ab_kick_next = _time + 0.2
				host.hit_crate(crate, 1)

func _ball_tick(ball: Dictionary, dt: float, host) -> void:
	var old_y: float = ball.p.y
	ball.v.y = minf(1200, ball.v.y + 1800 * dt)
	ball.p += ball.v * dt
	ball.spin += ball.v.x * dt / 22.0
	if ball.v.y > 0:
		var floor_y: float = INF
		if host.has_method("ability_land_on"): floor_y = host.ability_land_on(ball.p.x, old_y + 22, ball.p.y + 22)
		elif old_y + 22 <= ball.floor and ball.p.y + 22 >= ball.floor: floor_y = ball.floor
		if is_finite(floor_y):
			ball.p.y = floor_y - 22
			ball.v.y = -maxf(620, ball.v.y * 0.8)
	if host.has_method("ability_inside_wall") and host.ability_inside_wall(ball.p + Vector2(0, 6.6)):
		ball.v.x = -ball.v.x
		ball.p.x += ball.v.x * dt * 2
	if (ball.p.x < host.camera.x + 24 and ball.v.x < 0) or (ball.p.x > host.camera.x + host.view_width() - 24 and ball.v.x > 0): ball.v.x = -ball.v.x
	if ball.p.y < host.view_top() + 30 and ball.v.y < 0: ball.v.y = 0.0
	if ball.p.y > 1000000: ball.dead = true
	var near := false
	for enemy in host.enemies:
		if _live(enemy) and absf(enemy.p.x - ball.p.x) < 46 and ball.p.y > enemy.p.y - 130 and ball.p.y < enemy.p.y + 10:
			near = true
			if enemy.get("ab_ball_next", 0.0) <= _time:
				enemy.ab_ball_next = _time + 0.24
				host.damage_enemy(enemy, 2)
	if _boss_on(host) and absf(host.boss.state.x - ball.p.x) < 90 and ball.p.y > host.boss.state.fy - 260 and ball.p.y < host.boss.state.fy + 10:
		near = true
		if ball.boss_next <= _time:
			ball.boss_next = _time + 0.3
			host.damage_boss(2)
			ball.v.x = -ball.v.x
	if not near:
		ball.free -= dt
		if ball.free <= 0:
			ball.free = 0.18
			# The source emits one untargeted invisible shot at the ball, even
			# without a nearby crate. A ghost-aware host applies all object rules.
			var handled: bool = host.has_method("ability_free_zap") and host.ability_free_zap(ball.p, signf(ball.v.x))
			if not handled:
				for crate in host.crates:
					if not crate.get("broken", false) and absf(crate.p.x - ball.p.x) < 36 and absf(crate.p.y - 30 - ball.p.y) < 40: host.hit_crate(crate, 1)
	ball.trail.append(ball.p)
	if ball.trail.size() > 6: ball.trail.pop_front()
