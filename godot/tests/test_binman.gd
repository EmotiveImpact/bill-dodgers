extends SceneTree
const Binman = preload("res://src/binman.gd")
var assertions := 0
var failures := 0
var players: Array[Dictionary] = [{"position": Vector2(9100, 482), "alive": true, "height": 180.0, "crouching": false}]

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		push_error(message)
		failures += 1

func count(events: Array[Dictionary], kind: String) -> int:
	return events.filter(func(e): return e.type == kind).size()

func first(events: Array[Dictionary], kind: String) -> Dictionary:
	for event in events:
		if event.type == kind: return event
	return {}

func ready(b, hp: float = 260.0, duo: bool = false) -> void:
	b.reset(10000, 1000, 482, 2 if duo else 1, 31)
	b.state.state = "walk"
	b.state.x = 9700.0
	b.state.next = 999.0
	b.state.hp = hp
	b.drain_events()
	players[0] = {"position": Vector2(9100, 482), "alive": true, "height": 180.0, "crouching": false}

func projectile(at: Vector2, damage: int = 1) -> Dictionary:
	return {"p": at, "v": Vector2.ZERO, "life": 1.0, "enemy": false, "damage": damage}

func bin_at(at: Vector2, rolling: bool = true, velocity: Vector2 = Vector2.ZERO) -> Dictionary:
	return {"x": at.x, "y": at.y, "vx": velocity.x, "vy": velocity.y, "roll": rolling, "rot": 0.0, "hp": 2, "t": 0.0}

func rain_at(at: Vector2) -> Dictionary:
	return {"x": at.x, "y": at.y, "vy": 0.0, "t": 0.0, "k": 0}

func _initialize() -> void:
	var b = Binman.new()
	b.reset(10000, 1000, 482)
	check(b.state.hp == 260 and b.state.max == 260, "Solo 260 HP")
	check(b.state.x == 10200 and b.state.fy == 482 and b.state.phase == 1, "Initial position and phase")
	check(not b.state.has("jar"), "No Jar Thief pickup compatibility")
	check(count(b.drain_events(), "warning") == 1 and b.drain_events().is_empty(), "Warning drains once")
	check(not b.hit(Vector2(10200, 400)), "Entry ignores shots")
	b.tick(0.016, players)
	check(b.state.x == 9910 and b.state.state == "enter", "Source first-frame entry clamp")
	b.tick(0.639, players)
	check(b.state.state == "enter", "Entry reaches 160px inward at 250px/s")
	var events = b.tick(0.0011, players)
	check(b.state.state == "walk" and is_equal_approx(b.state.next, 1.4), "Entry completes and waits 1.4s")
	check(b.state.lid_t == 1.4 and b.state.lid == 0 and count(events, "roar") == 1, "Roar opens lid timer after current-frame easing")
	b.tick(0.045, players)
	check(is_equal_approx(b.state.lid, 0.5), "Lid smoothing uses 90ms")
	b.tick(0.045, players)
	check(is_equal_approx(b.state.lid, 0.75), "Lid easing is exponential Euler, not linear")
	b.open_lid(0.01)
	b.tick(0.09, players)
	check(b.state.lid == 0.0, "Expiry closes before easing target")

	# Body hitTest is inclusive, unlike most ordinary robot hitboxes.
	ready(b)
	b.state.lid = 0.59999
	var shot = projectile(Vector2(9700, 400), 999)
	check(b.hit_shot(shot) and shot.dead and shot.life == 0, "Closed lid consumes native bullet")
	check(b.state.hp == 260 and count(b.drain_events(), "clang") == 1, "Closed lid does not damage boss")
	b.state.lid = 0.6
	check(b.hit(Vector2(9805, 182), 999), "Inclusive right/top hit boundaries")
	check(b.hit(Vector2(9595, 482), 999), "Inclusive left/bottom hit boundaries")
	check(b.state.hp == 258 and b.state.flash == 0.08, "Open boss ignores damage amount and flashes 80ms")
	for at in [Vector2(9805.01, 400), Vector2(9594.99, 400), Vector2(9700, 181.99), Vector2(9700, 482.01)]:
		check(not b.hit(at), "Outside exact Binman body does not consume")
	b.state.dizzy = 3.5
	check(b.hit(Vector2(9700, 362), 3) and b.state.hp == 256, "Ama zap can deal transient two damage")
	b.tick(0, players)
	check(b.state.dizzy == 0, "Every boss update clears Ama dizzy, even zero delta")
	check(b.hit(Vector2(9700, 362), 99) and b.state.hp == 255, "Special zap follows ordinary lid and damage rule")
	shot = projectile(Vector2(9700, 362))
	shot.enemy = true
	check(not b.hit_shot(shot) and shot.life == 1, "Hostile bullets cannot damage boss")
	shot.enemy = false
	shot.dead = true
	check(not b.hit_shot(shot), "Already consumed shot cannot hit boss twice")

	# Strict phase thresholds differ from helper thresholds at exact .66/.33.
	ready(b, 171.6)
	events = b.tick(0, players)
	check(b.state.phase == 2 and count(events, "spawn_bot") == 0, "Exactly .66 enters phase 2 without helpers")
	b.state.hp = 171.59
	events = b.tick(0, players)
	check(count(events, "spawn_bot") == 2 and events[0].side == "l" and events[0].kind == "rush" and events[1].side == "r" and events[1].kind == "throw", "Strictly below .66 summons rush and throw")
	check(count(events, "backup") == 1 and b.state.lid_t == 2.4, "Backup opens lid for 2.4s")
	check(count(b.tick(0, players), "spawn_bot") == 0, "First helper call is once only")
	b.state.hp = 85.8
	events = b.tick(0, players)
	check(b.state.phase == 3 and count(events, "spawn_bot") == 0, "Exactly .33 enters phase 3 without second helpers")
	b.state.hp = 85.79
	events = b.tick(0, players)
	check(count(events, "spawn_bot") == 2 and events[0].kind == "flat" and events[1].kind == "rush", "Second solo helpers are flat and rush")
	check(count(events, "furious") == 1 and b.state.lid_t == 2.4, "Furious opening lasts 2.4s")
	ready(b, 100, true)
	events = b.tick(0, players)
	check(b.state.max == 340 and count(events, "spawn_bot") == 5, "Duo 340 HP and both helper thresholds")
	check(events[5].type == "spawn_bot" and events[5].side == "l" and events[5].kind == "fly", "Duo bonus is specifically left fly bot")

	# Walking, random selection, exact fire/recovery boundaries.
	ready(b)
	b.tick(0.1, players)
	check(is_equal_approx(b.state.x, 9692), "Phase 1 walk is 80px/s")
	b.state.x = 9300.0
	b.tick(0.1, players)
	check(b.state.x == 9300, "No walk at exactly 200px from target")
	ready(b, 80)
	b.state.called = [true, true, false]
	b.tick(0.1, players)
	check(is_equal_approx(b.state.x, 9688), "Phase 3 walk is 120px/s")
	for phase in [1, 2, 3]:
		for seed_value in range(1, 9):
			ready(b, 260 if phase == 1 else 130 if phase == 2 else 60)
			b.state.called = [true, true, false]
			b.state.next = 0.0
			b.rng.seed = seed_value
			var probe := RandomNumberGenerator.new()
			probe.seed = seed_value
			var r := probe.randf()
			var expected: String = "throw" if phase == 1 else ("roll" if r < 0.5 else "throw") if phase == 2 else ("slam" if r < 0.4 else "roll" if r < 0.7 else "throw")
			b.tick(0, players)
			check(b.state.state == "walk", "Attack waits strictly beyond next")
			b.tick(0.001, players)
			check(b.state.state == expected and b.state.pending_throw and b.state.t == 0, "Phase %d source attack probabilities with deterministic seed %d" % [phase, seed_value])
	ready(b)
	b.state.state = "throw"
	b.state.pending_throw = true
	check(count(b.tick(0.42, players), "throw") == 0, "Windup is strictly beyond 420ms")
	events = b.tick(0.0001, players)
	check(count(events, "throw") == 1 and b.state.bins.size() == 1, "Throw once after windup")
	var n: Dictionary = b.state.bins[0]
	check(n.x == b.state.x - 60 and n.y == 212 and n.vy == -850 and not n.roll and n.hp == 2, "Arc launch geometry, velocity, health")
	check(n.vx >= -550 and n.vx <= 550, "Arc horizontal speed clamps 550px/s")
	check(count(b.tick(0.1, players), "throw") == 0, "Attack does not refire while pending is false")
	b.state.t = 0.82
	b.tick(0, players)
	check(b.state.state == "throw", "Recovery strictly beyond 820ms")
	b.tick(0.0001, players)
	check(b.state.state == "walk" and b.state.next >= 1.7 and b.state.next <= 2.3 and b.state.lid_t == 1.2, "Phase 1 recovery and gap")
	for phase in [2, 3]:
		ready(b, 130 if phase == 2 else 60)
		b.state.called = [true, true, false]
		b.state.state = "roll"
		b.state.t = 0.821
		b.tick(0, players)
		var gap := 1.3 if phase == 2 else 0.9
		check(b.state.next >= gap and b.state.next <= gap + 0.6 and b.state.lid_t == (1.0 if phase == 2 else 1.2), "Phase-specific recovery lid and gap")

	# Phase 3 double throw re-targets exactly 260ms later and cancels on down/reset.
	ready(b, 60)
	b.state.called = [true, true, false]
	b.state.state = "throw"
	b.state.pending_throw = true
	b.tick(0.421, players)
	check(count(b.tick(0.259, players), "throw") == 0, "Second throw waits 260ms")
	players[0].position.x = 9800
	events = b.tick(0.001, players)
	check(count(events, "throw") == 1 and b.state.bins.size() == 2, "Second throw fires at 260ms")
	check(b.state.bins[1].vx > 0, "Delayed throw re-targets current nearest player")
	check(count(b.tick(0, players), "throw") == 0, "Delayed throw only once")
	ready(b, 60)
	b.state.called = [true, true, false]
	b.state.state = "throw"
	b.state.pending_throw = true
	b.tick(0.421, players)
	b.down()
	check(count(b.tick(0.26, players), "throw") == 0, "Down cancels delayed throw")

	# Bin rotation, gravity, landing, rolling speeds and boundary culling.
	ready(b)
	b.throw_bin(Vector2(0, 482), true)
	n = b.state.bins[0]
	check(n.y == 442 and n.roll and n.vx >= -420 and n.vx <= -320 and n.vy == 0, "Ground roll launch")
	b.state.bins = [bin_at(Vector2(9500, 400), false, Vector2(100, 0))]
	b.tick(0.1, players)
	n = b.state.bins[0]
	check(is_equal_approx(n.x, 9510) and is_equal_approx(n.y, 417) and is_equal_approx(n.vy, 170), "Bin semi-implicit Euler gravity 1700")
	check(is_equal_approx(n.rot, 0.2), "Rotation uses horizontal displacement times .02")
	events = b.tick(0.1, players)
	n = b.state.bins[0]
	check(n.roll and n.y == 442 and n.vx == 300 and count(events, "bin_land") == 1, "Bin landing snaps and converts to 300px/s roll")
	check(b.state.waves.size() == 1 and b.state.waves[0].bin and b.state.waves[0].vx == 0, "Rolling bins expose stationary CPU wave markers")
	b.state.bins = [bin_at(Vector2(9500, 442), false)]
	b.tick(0, players)
	check(b.state.bins[0].vx == -300, "Zero velocity landing uses boss facing")
	b.state.bins = [bin_at(Vector2(8950, 442)), bin_at(Vector2(10050, 442))]
	b.state.waves = []
	b.tick(0, players)
	check(b.state.bins.size() == 2, "Bins retained at exact arena plus 140px boundary")
	b.state.bins[0].x -= 0.01
	b.state.bins[1].x += 0.01
	b.tick(0, players)
	check(b.state.bins.is_empty(), "Bins culled outside arena plus 140px")

	# Bins are two-hit objects and ignore damage, including ghost ability zaps.
	ready(b)
	b.state.bins = [bin_at(Vector2(9500, 400))]
	shot = projectile(Vector2(9540, 400), 999)
	b.tick(0, players, [shot])
	check(shot.life == 1 and b.state.bins[0].hp == 2, "Bin x hit boundary strictly 40px")
	shot.p = Vector2(9500, 446)
	b.tick(0, players, [shot])
	check(shot.life == 1, "Bin y hit boundary strictly 46px")
	shot.p = Vector2(9500, 445.99)
	shot.ghost = true
	events = b.tick(0, players, [shot])
	check(shot.dead and shot.life == 0 and b.state.bins[0].hp == 1 and count(events, "drop_coins") == 0, "Ability ghost shot consumes and deals one bin damage")
	events = b.tick(0, players, [projectile(Vector2(9500, 400), 10)])
	check(b.state.bins.is_empty() and first(events, "drop_coins").count == 2, "Second shot destroys bin for two coins")
	b.state.bins = [bin_at(Vector2(9500, 400))]
	events = b.tick(0, players, [projectile(Vector2(9500, 400)), projectile(Vector2(9500, 400)), projectile(Vector2(9500, 400))])
	check(count(events, "bin_hit") == 3 and count(events, "drop_coins") == 2, "Source consumes all same-frame overkill shots and repeats rewards")
	b.state.bins = [bin_at(Vector2(9500, 400)), bin_at(Vector2(9500, 400))]
	b.tick(0, players, [projectile(Vector2(9500, 400))])
	check(b.state.bins[0].hp == 1 and b.state.bins[1].hp == 2, "Shot consumed by first overlapping bin only")

	# Player collisions precede bin-shot hits, and invulnerability is host-owned.
	ready(b)
	players[0].position = Vector2(9500, 482)
	players[0].invincible = 10.0
	b.state.bins = [bin_at(Vector2(9500, 442))]
	events = b.tick(0, players, [projectile(Vector2(9500, 442))])
	check(first(events, "hurt_player").hazard == "bin" and b.state.bins.is_empty(), "Even invulnerable player's contact removes bin")
	check(count(events, "drop_coins") == 1, "Player contact precedes shot and source still drops coins")
	b.state.bins = [bin_at(Vector2(9540, 442))]
	events = b.tick(0, players)
	check(count(events, "hurt_player") == 0 and b.state.bins.size() == 1, "Bin contact x boundary strictly 40px")
	b.state.waves = []
	b.state.bins = [bin_at(Vector2(9500, 440), false)]
	players[0].position.y = 400
	check(count(b.tick(0, players), "hurt_player") == 0, "Bin contact feet boundary is strict")
	b.state.bins = [bin_at(Vector2(9500, 330), false)]
	players[0].position.y = 482
	players[0].crouching = true
	check(count(b.tick(0, players), "hurt_player") == 0, "Crouch top uses .56 height for bin avoidance")
	players[0].crouching = false
	check(count(b.tick(0, players), "hurt_player") == 1, "Standing top uses .86 height for bin impact")

	# Slam geometry, rain spacing, wave source offset, jump tests and update order.
	ready(b, 60)
	b.state.called = [true, true, false]
	b.state.state = "slam"
	b.state.pending_throw = true
	events = b.tick(0.421, players, [], -100)
	check(first(events, "stomp").shake == 14 and b.state.waves.size() == 2, "Slam creates two waves and 14 shake")
	check(b.state.waves[0].x == 9620 and b.state.waves[0].vx == -450 and b.state.waves[1].x == 9780 and b.state.waves[1].vx == 450, "Slam source wave position and speed")
	check(b.state.rain.size() == 5, "Slam creates five recycling pieces")
	for i in 5:
		var r: Dictionary = b.state.rain[i]
		check(r.x >= 9090 and r.x <= 9910 and r.y == -140 - i * 120 and r.k == i % 3 and r.vy == 0, "Rain source distribution, spacing and colors")
	b.state.rain = []
	players[0].position = Vector2(9575, 452)
	check(count(b.tick(0.1, players), "hurt_player") == 0, "Wave clears player at exactly 30px jump height")
	players[0].position.y = 452.01
	events = b.tick(0, players)
	check(first(events, "hurt_player").source_x == 9597.5, "Wave damages below jump threshold with source vx*50ms offset")
	players[0].position.x = 9599
	check(count(b.tick(0, players), "hurt_player") == 0, "Wave horizontal contact strictly 24px")
	ready(b)
	b.state.waves = [{"x": 8970.0, "vx": 0.0, "t": 0.0}, {"x": 10030.0, "vx": 0.0, "t": 0.0}]
	b.tick(0, players)
	check(b.state.waves.is_empty(), "Wave boundary culls at equality, arena plus 120")
	ready(b)
	players[0].position = Vector2(9500, 482)
	b.state.waves = [{"x": 9500.0, "vx": 0.0, "t": 0.0, "bin": true}]
	b.state.bins = [bin_at(Vector2(9600, 442))]
	events = b.tick(0, players)
	check(first(events, "hurt_player").hazard == "bin_marker" and b.state.waves[0].x == 9600, "Previous-frame rolling marker hurts before replacement")
	ready(b)
	b.state.rain = [rain_at(Vector2(9500, 200))]
	b.tick(0.1, players)
	check(b.state.rain[0].vy == 180 and b.state.rain[0].y == 218, "Rain gravity is 1800 semi-implicit Euler")
	b.state.rain = [rain_at(Vector2(9500, 468))]
	check(count(b.tick(0, players), "rain_land") == 0, "Rain ground expiry strictly beyond ground minus14")
	b.state.rain[0].y += 0.01
	check(count(b.tick(0, players), "rain_land") == 1 and b.state.rain.is_empty(), "Rain ground expiry removes recycling")
	players[0].position = Vector2(9500, 482)
	players[0].crouching = true
	b.state.rain = [rain_at(Vector2(9500, 350))]
	events = b.tick(0, players)
	check(first(events, "hurt_player").hazard == "rain", "Rain deliberately uses standing .86 body even when crouched")
	b.state.rain = [rain_at(Vector2(9528, 350))]
	check(count(b.tick(0, players), "hurt_player") == 0, "Rain horizontal boundary strictly 28px")
	b.state.rain = [rain_at(Vector2(9500, 482))]
	events = b.tick(0, players)
	check(count(events, "hurt_player") == 0 and count(events, "rain_land") == 1, "Rain feet boundary strictly excludes equality")

	# Body contact, down effects, post-down hazards, direct and once-only clear.
	ready(b)
	players[0].position = Vector2(9700 + 210 * 0.42, 482)
	check(count(b.tick(0, players), "hurt_player") == 0, "Boss body x boundary strict .42 width")
	players[0].position = Vector2(9700, 222)
	check(count(b.tick(0, players), "hurt_player") == 0, "Boss body feet boundary strict ground minus260")
	players[0].position.y += 0.01
	check(first(b.tick(0, players), "hurt_player").hazard == "body", "Boss body contact above height boundary")
	players[0].alive = false
	check(count(b.tick(0.1, players), "hurt_player") == 0, "Downed players never receive damage")
	ready(b)
	b.state.lid = 1.0
	b.state.hp = 1
	b.state.waves = [{"x": 9500.0, "vx": 450.0, "t": 0.0}]
	b.state.bins = [bin_at(Vector2(9500, 442))]
	b.state.rain = [rain_at(Vector2(9400, 0))]
	check(b.hit(Vector2(9700, 400)) and b.state.state == "down", "Final open hit defeats boss")
	check(b.state.waves.is_empty() and b.state.bins.size() == 1 and b.state.rain.size() == 1, "Down clears waves but retains bin and rain hazards")
	events = b.drain_events()
	check(count(events, "down") == 1 and count(events, "kill_bots") == 1 and first(events, "drop_coins").count == 16 and count(events, "bits") == 2, "Source down effects and 16 coin reward")
	check(not b.hit(Vector2(9700, 400)), "Down boss does not consume shots")
	players[0].position = Vector2(9500, 482)
	events = b.tick(0, players)
	check(count(events, "hurt_player") == 1 and first(events, "hurt_player").hazard == "bin", "Retained bins still collide during defeat")
	events = b.tick(2.6, players)
	check(count(events, "clear") == 0, "Clear strictly beyond 2.6s, no jar")
	check(count(b.tick(0.001, players, [], 0, false), "clear") == 0, "Clear waits for host play state")
	check(count(b.tick(0, players), "clear") == 1, "Direct clear after down delay")
	check(count(b.tick(10, players), "clear") == 0, "Clear exactly once")
	b.down()
	check(b.drain_events().is_empty(), "Down is idempotent")
	b.reset(10000, 1000, 482, 2)
	check(b.state.hp == 340 and b.state.bins.is_empty() and b.state.rain.is_empty() and b.state.waves.is_empty(), "Reset removes all encounter state")

	# Reproducibility at identical cadence and negative dt guard.
	var other = Binman.new()
	ready(b, 60)
	ready(other, 60)
	for i in 1000:
		b.tick(0.016, players)
		other.tick(0.016, players)
	check(b.state == other.state and b.rng.state == other.rng.state, "Seeded deterministic multi-attack encounter")
	var before: float = b.state.t
	b.tick(-1, players)
	check(b.state.t == before, "Negative delta is clamped")
	print("Binman parity: %d/%d checks passed" % [assertions - failures, assertions])
	quit(1 if failures else 0)
