extends SceneTree
const Captain = preload("res://src/holiday_captain.gd")
var assertions := 0
var failures := 0

class Host extends RefCounted:
	var level: Dictionary = {}
	var meta: Dictionary = {}
	var player := Vector2(5200, 482)
	var camera := Vector2(4974, 0)
	var camera_lock := 0.0
	var status := ""
	var hearts := 3
	var invincible := 0.0
	var roster: Array = []
	var sounds: Array = []
	var rewards: Array = []
	var clears := 0
	func view_width() -> float: return 738
	func combat_participants() -> Array:
		return roster if not roster.is_empty() else [{"host_player": true, "p": player, "hearts": hearts}]
	func sfx(effect: String) -> void: sounds.append(effect)
	func add_coins(point: Vector2, count: int) -> void: rewards.append({"p": point, "count": count})
	func hurt_player(_from_x: float) -> void:
		if hearts <= 0 or invincible > 0: return
		hearts -= 1
		invincible = 1.4
	func _complete_level() -> void: clears += 1

class RandomFixture extends RefCounted:
	var value := 0.5
	var calls := 0
	func randf() -> float:
		calls += 1
		return value

class World extends RefCounted:
	var rng := RandomFixture.new()
	var spawned: Array = []
	var bills: Array = []
	var hurt_attempts: Array = []
	var cleanups := 0
	func living(host) -> Array:
		return host.combat_participants().filter(func(p): return not p.get("down", false) and int(p.hearts) > 0)
	func hurt(host, participant: Dictionary, from_x: float) -> void:
		hurt_attempts.append({"p": participant.p, "from_x": from_x})
		if participant.get("host_player", false): host.hurt_player(from_x)
		elif float(participant.get("invincible", 0)) <= 0:
			participant.hearts -= 1
			participant.invincible = 1.4
	func spawn_foe(side: String, kind: String, _host) -> void: spawned.append([side, kind])
	func bill(_host, point: Vector2, target_x: float, big: bool = false) -> void:
		bills.append({"p": point, "target_x": target_x, "big": big})
	func clear_threats(_host) -> void: cleanups += 1

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func close(value: float, expected: float, message: String) -> void:
	check(absf(value - expected) < 0.00001, message + " (" + str(value) + ", expected " + str(expected) + ")")

func setup(pair: bool = false) -> Dictionary:
	var host := Host.new()
	host.meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/4-6.json"))
	host.level = host.meta.level
	if pair: host.roster = [{"p": Vector2(5200, 482), "hearts": 3}, {"p": Vector2(5400, 482), "hearts": 0, "down": true}]
	var captain = Captain.new()
	var world := World.new()
	captain.reset(host)
	captain.start(host)
	return {"captain": captain, "host": host, "world": world}

func fight(pair: bool = false) -> Dictionary:
	var fixture := setup(pair)
	fixture.captain.boss.state = "drift"
	fixture.captain.boss.x = 5450.0
	fixture.captain.boss.next = 1000.0
	fixture.captain.drain_events()
	fixture.host.sounds.clear()
	return fixture

func shot(point: Vector2, damage: float = 1) -> Dictionary:
	return {"p": point, "damage": damage, "enemy": false, "dead": false, "life": 20.0}

func _initialize() -> void:
	_test_reset_entry()
	_test_drift_throw()
	_test_phases_crew()
	_test_charge()
	_test_waves()
	_test_shots()
	_test_generic_adapter()
	_test_down_jar()
	print("Holiday Captain: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)

func _test_reset_entry() -> void:
	var f := setup()
	var b: Dictionary = f.captain.boss
	check(b.hp == 90 and b.max == 90 and b.state == "enter", "Solo source 90 HP entry")
	check(b.x == 5972 and b.y == 522 and b.t == 0 and b.next == 1.8, "4-6 source initial position and 1800ms delay")
	check(b.face == -1 and b.phase == 1 and b.flash == 0 and b.dizzy == 0 and b.sink == 0 and b.aimX == 0, "Source initial counters")
	check(b.w4 and b.wave.is_empty() and b.called.is_empty(), "Distinct W4 source boss arrays")
	check(b.fy == b.y, "Named native repair supplies fy=y instead of original missing feet")
	check(f.host.camera_lock == 4974 and f.host.sounds == ["warn"], "Source finale camera lock and warning")
	check(f.captain.drain_events().size() == 1 and f.captain.drain_events().is_empty(), "Warning event drains exactly once")
	f.captain.start(f.host)
	check(f.host.sounds == ["warn"], "Repeated start is harmless")
	check(not f.captain.intercept_shot(shot(Vector2(5972, 400)), 5900, f.host, f.world), "Entry immunity belongs to W4 interception")
	f.captain.tick(0.016, f.host, f.world)
	check(b.x == 5902 and b.aimX == 5952 and b.state == "enter", "First entry frame clamps to R+300, aim uses pre-clamp x")
	b.x = 5482.25
	f.captain.tick(0.001, f.host, f.world)
	check(b.x == 5482 and b.state == "drift" and b.t == 0 and b.next == 1.8, "250px/s entry finishes at inclusive R-120")
	b.dizzy = 3.5
	f.captain.tick(0.1, f.host, f.world)
	check(b.dizzy == 3.5, "Source Captain never decays or honors dizzy")
	f.host.hearts = 0
	b.state = "enter"
	b.x = 5972.0
	b.flash = 0.08
	f.captain.tick(0.1, f.host, f.world)
	check(b.x == 5972 and b.flash == 0 and b.aimX == 5952, "No living target skips entry and clamp but still ages flash/aim")
	var duo := setup(true)
	check(duo.captain.boss.hp == 120 and duo.captain.boss.max == 120, "Pair scaling includes down participant, not living count")
	f.captain.jar = {"got": true}
	f.captain.reset(f.host)
	check(f.captain.boss.is_empty() and f.captain.jar.is_empty() and f.captain.drain_events().is_empty(), "Replay reset removes all boss/jar/presentation state")
	f.captain.start(f.host)
	check(f.captain.boss.hp == 90 and f.captain.boss.x == 5972, "Reset then start restores source state")
	f.captain.reset(f.host)
	f.host.level.cfg = {"water": 500, "bossY": 0}
	f.captain.start(f.host)
	check(f.captain.boss.y == 530, "Falsy bossY uses source water+30 fallback")

func _test_drift_throw() -> void:
	var f := fight()
	var b: Dictionary = f.captain.boss
	b.t = 0.4
	b.x = 5450.0
	f.captain.tick(0.1, f.host, f.world)
	var want := 5602.0 - 150 + sin(0.5 / 1.5) * 140
	close(b.x, 5450 + clampf((want - 5450) / 0.5, -80, 80) * 0.1, "Drift source sine target and 500ms approach")
	check(b.face == -1 and b.aimX == 5430, "Drift faces nearest but aim precedes drift")
	f.host.player.x = b.x
	f.captain.tick(0, f.host, f.world)
	check(b.face == -1, "Equal-position face falls back to left")
	f.host.player.x = 5600
	b.t = b.next
	f.captain.tick(0, f.host, f.world)
	check(b.state == "drift" and b.face == 1 and f.world.rng.calls == 0, "Drift waits at exact next threshold")
	f.world.rng.value = 0.0
	f.captain.tick(0.001, f.host, f.world)
	check(b.state == "throw" and b.t == 0 and not b.fired and f.world.rng.calls == 1, "Phase1 always throws but still samples source choice")
	b.t = 0.38
	f.captain.tick(0, f.host, f.world)
	check(f.world.bills.is_empty(), "No throw at exact380ms")
	f.captain.tick(0.001, f.host, f.world)
	check(f.world.bills.size() == 3 and b.fired, "Phase1 emits three bills strictly after380ms")
	for i in 3:
		check(f.world.bills[i].p == Vector2(b.x - 60, 222) and f.world.bills[i].big, "Big bill origin independent of facing")
		close(f.world.bills[i].target_x, 5600 + (i - 1) * 120, "Phase1 centered120px spread")
	b.t = 0.9
	f.captain.tick(0, f.host, f.world)
	check(b.state == "throw" and f.world.bills.size() == 3, "Throw is once and persists at exact900ms")
	f.world.rng.value = 0.25
	f.captain.tick(0.001, f.host, f.world)
	check(b.state == "drift" and b.t == 0 and b.next == 1.75, "Phase1 recovery1500ms plus random1000ms")
	for hp in [50, 20]:
		b.hp = hp
		b.state = "throw"
		b.t = 0.381
		b.fired = false
		f.world.bills.clear()
		f.captain.tick(0, f.host, f.world)
		check(f.world.bills.size() == 4, "Later phase emits four bills")
		for i in 4: close(f.world.bills[i].target_x, 5600 + (i - 1.5) * 120, "Four-bill half-step centered spread")
		b.t = 0.901
		f.captain.tick(0, f.host, f.world)
		close(b.next, 1.25 if hp == 20 else 1.75, "Phase-dependent recovery delay")
	for choice in [0.399999, 0.4]:
		b.hp = 50
		b.state = "drift"
		b.t = b.next + 0.001
		f.world.rng.value = choice
		f.captain.tick(0, f.host, f.world)
		check(b.state == ("rear" if choice < 0.4 else "throw"), "Rear selection strict0.4 boundary")
	# Source nearest scans roster in order and includes only living players.
	f.host.roster = [{"p": Vector2(5400, 482), "hearts": 3}, {"p": Vector2(5500, 482), "hearts": 3}]
	b.x = 5450.0
	b.state = "throw"
	b.t = 0.381
	b.fired = false
	f.world.bills.clear()
	f.captain.tick(0, f.host, f.world)
	close(f.world.bills[0].target_x, 5220, "Equidistant targets preserve roster order")

func _test_phases_crew() -> void:
	var f := fight()
	var b: Dictionary = f.captain.boss
	for pair in [[72.0, 1, 0], [71.999, 1, 1], [59.4, 2, 1], [45.0, 2, 1], [44.999, 2, 3], [29.7, 3, 3], [22.5, 3, 3], [22.499, 3, 4]]:
		b.hp = pair[0]
		f.captain.tick(0, f.host, f.world)
		check(b.phase == pair[1] and f.world.spawned.size() == pair[2], "Exact phase/crew thresholds at hp=" + str(pair[0]))
	check(f.world.spawned == [["r", "jet"], ["l", "jet"], ["r", "ring"], ["r", "jet"]], "Solo crew source order and sides")
	f.captain.tick(5, f.host, f.world)
	check(f.world.spawned.size() == 4, "Every threshold calls crew once")
	check(f.host.sounds == ["warn", "power"], "Only phase transitions emit warning/power")
	var duo := fight(true)
	duo.captain.boss.hp = 1
	duo.captain.tick(0, duo.host, duo.world)
	check(duo.world.spawned == [["r", "jet"], ["l", "jet"], ["r", "ring"], ["r", "jet"], ["l", "jet"]], "Crossed pair thresholds fire together in a/b/c order")
	check(duo.captain.boss.phase == 3 and duo.host.sounds == ["power"], "Direct phase1-to3 transition emits only final phase cue")
	f = fight()
	f.captain.boss.hp = 30
	f.captain.boss.phase = 2
	var hit := shot(Vector2(5520, 402), 999)
	check(f.captain.intercept_shot(hit, 5520, f.host, f.world), "Pre-threshold projectile accepted")
	check(f.captain.boss.hp == 29 and f.captain.boss.phase == 2, "Projectile pass does not prematurely change phase")
	f.captain.intercept_shot(shot(Vector2(5520, 402), 999), 5520, f.host, f.world)
	check(f.captain.boss.hp == 28, "Second same-pass valve shot still fixed1")
	f.captain.tick(0, f.host, f.world)
	f.captain.intercept_shot(shot(Vector2(5520, 402), 999), 5520, f.host, f.world)
	check(f.captain.boss.hp == 25 and f.captain.boss.phase == 3, "Next boss tick opens valve for subsequent projectile pass")

func _test_charge() -> void:
	for point in [Vector2(5350, 482), Vector2(5348, 482), Vector2(5200, 482)]:
		var f := fight()
		var b: Dictionary = f.captain.boss
		b.state = "rear"
		b.x = point.x
		b.t = 0.7
		f.host.player = Vector2(5500, 482)
		f.captain.tick(0, f.host, f.world)
		check(b.state == "rear", "Rear waits at exact700ms")
		f.captain.tick(0.001, f.host, f.world)
		check(b.state == "charge" and b.t == 0 and b.x == point.x, "Rear switches to charge without same-frame charge motion")
		check(b.dir == (-1 if point.x > 5348 else 1), "Charge direction follows arena midpoint, not player")
		check(f.host.sounds == ["stomp"], "Charge transition stomps")
	var f := fight()
	var b: Dictionary = f.captain.boss
	b.state = "charge"
	b.dir = -1
	b.x = 5300.0
	f.host.player = Vector2(5229, 482)
	f.captain.tick(0.02, f.host, f.world)
	check(b.x == 5289 and f.world.hurt_attempts.size() == 1 and f.host.hearts == 2, "Charge550px/s updates before real neck damage")
	check(f.world.hurt_attempts[0].from_x == 5289, "Neck knockback source is boss x")
	for state in ["enter", "drift", "throw", "rear"]:
		b.state = state
		b.t = 0.0
		b.x = 5300.0
		f.host.player = Vector2(5240, 482)
		f.world.hurt_attempts.clear()
		f.captain.tick(0, f.host, f.world)
		check(f.world.hurt_attempts.is_empty(), "No stationary body damage in " + state)
	for point in [Vector2(5180, 482), Vector2(5300, 482), Vector2(5240, 362), Vector2(5240, 362.001)]:
		b.state = "charge"
		b.x = 5300.0
		f.host.player = point
		f.world.hurt_attempts.clear()
		f.captain.tick(0, f.host, f.world)
		check(not f.world.hurt_attempts.is_empty() == (absf(point.x - 5240) < 60 and point.y > 362), "Strict neck60px/ground-120 boundary " + str(point))
	for direction in [-1, 1]:
		b.state = "charge"
		b.dir = direction
		b.x = 5154.0 if direction < 0 else 5542.0
		b.wave = []
		f.host.player = Vector2(b.x + direction * 60, 482)
		f.captain.tick(0, f.host, f.world)
		check(b.state == "charge" and b.wave.is_empty(), "Charge persists at exact arena turnaround edge")
		f.world.hurt_attempts.clear()
		f.captain.tick(0.001, f.host, f.world)
		check(b.state == "drift" and b.t == 0 and b.next == 1.4 and b.wave.size() == 1, "Charge crosses boundary into1400ms drift with one wave")
		check(b.wave[0].vx == -direction * 400 and b.wave[0].t == 0 and b.wave[0].x == b.x - direction * 30, "Wave origin and reverse400px/s, no newborn motion")
		check(f.world.hurt_attempts.is_empty(), "Turnaround frame cannot also cause neck damage")

func _test_waves() -> void:
	var f := fight()
	var b: Dictionary = f.captain.boss
	b.wave = [{"x": 5200.0, "vx": 400.0, "t": 0.0}]
	f.host.player = Vector2(5240, 452)
	f.captain.tick(0.1, f.host, f.world)
	check(b.wave[0].x == 5240 and b.wave[0].t == 0.1 and f.world.hurt_attempts.is_empty(), "Waves move before strict ground-minus30 contact")
	f.host.player.y = 452.001
	f.captain.tick(0, f.host, f.world)
	check(f.world.hurt_attempts.size() == 1 and f.world.hurt_attempts[0].from_x == 5220, "Wave uses50ms source offset and no grounded requirement")
	check(f.host.hearts == 2 and f.host.invincible > 0, "Normal damage is delegated to host")
	f.captain.tick(0, f.host, f.world)
	check(f.world.hurt_attempts.size() == 2 and f.host.hearts == 2, "Invulnerability remains host-owned")
	f.world.hurt_attempts.clear()
	f.host.player = Vector2(5266, 482)
	f.captain.tick(0, f.host, f.world)
	check(f.world.hurt_attempts.is_empty(), "Wave exact26px horizontal edge excluded")
	b.wave = [{"x": 4894.0, "vx": 0.0, "t": 0.0}, {"x": 5802.0, "vx": 0.0, "t": 0.0}, {"x": 4894.001, "vx": 0.0, "t": 0.0}, {"x": 5801.999, "vx": 0.0, "t": 0.0}]
	f.captain.tick(0, f.host, f.world)
	check(b.wave.size() == 2 and b.wave[0].x == 4894.001 and b.wave[1].x == 5801.999, "Waves culled at exact L-200 and R+200")
	f.host.hearts = 0
	b.wave = [{"x": 5300.0, "vx": -400.0, "t": 0.0}]
	f.captain.tick(0.1, f.host, f.world)
	check(b.wave[0].x == 5260 and b.wave[0].t == 0.1, "Waves keep advancing without a living target")

func _test_shots() -> void:
	var f := fight()
	var b: Dictionary = f.captain.boss
	check(f.captain.body_box() == {"x0": 5300.0, "x1": 5570.0, "top": 192.0, "bot": 502.0}, "Exact asymmetric Captain body rectangle")
	for point in [Vector2(5300, 400), Vector2(5570, 400), Vector2(5450, 192), Vector2(5450, 502)]:
		check(not f.captain.intercept_shot(shot(point), point.x, f.host, f.world), "Strict body edge rejected " + str(point))
	var hit := shot(Vector2(5300.001, 192.001), 999)
	hit.owner = {}
	check(f.captain.intercept_shot(hit, hit.p.x, f.host, f.world), "Just-inside body accepts high-damage shot")
	check(b.hp == 89 and b.flash == 0.08 and hit.dead and hit.life == 0 and hit.owner.bossHits == 1, "Fixed1 damage,80ms flash, consumption and source owner credit")
	check(not f.captain.intercept_shot(hit, hit.p.x, f.host, f.world) and b.hp == 89, "Consumed shot cannot repeat")
	check(f.captain.intercept_shot(shot(Vector2(5600, 400)), 5200, f.host, f.world), "Swept body accepts both endpoints outside")
	check(f.captain.intercept_shot(shot(Vector2(5200, 400)), 5600, f.host, f.world), "Swept body accepts reverse direction")
	check(not f.captain.intercept_shot(shot(Vector2(5600, 192)), 5200, f.host, f.world), "Sweep uses moved y, not interpolated old y")
	for point in [Vector2(NAN, 400), Vector2(5450, NAN), Vector2(INF, 400), Vector2(5450, INF)]:
		check(not f.captain.intercept_shot(shot(point), 5450, f.host, f.world), "Non-finite direct-special coordinates rejected safely")
	check(not f.captain.intercept_shot(shot(Vector2(5450, 400)), NAN, f.host, f.world), "Non-finite old x rejected safely")
	hit = shot(Vector2(5450, 400))
	hit.enemy = true
	check(not f.captain.intercept_shot(hit, 5450, f.host, f.world), "Hostile bills do not damage boss")
	hit.enemy = false
	hit.life = 0.0
	check(not f.captain.intercept_shot(hit, 5450, f.host, f.world), "Expired native shot ignored")
	b.phase = 3
	b.hp = 90
	b.dizzy = 3.5
	for face in [-1, 1]:
		b.face = face
		var valve := Vector2(5450 + (70 if face < 0 else -70), 402)
		var previous: float = b.hp
		check(f.captain.intercept_shot(shot(valve, 0), valve.x, f.host, f.world) and b.hp == previous - 3, "Face-dependent endpoint valve triple ignores zero shot damage/dizzy")
		for offset in [Vector2(-60, 0), Vector2(0, -60), Vector2(0, 60)]:
			previous = b.hp
			var point: Vector2 = valve + offset
			check(f.captain.intercept_shot(shot(point, 99), point.x, f.host, f.world) and b.hp == previous - 1, "Valve exact60px edge remains ordinary body damage")
	b.face = -1
	var previous: float = b.hp
	check(f.captain.intercept_shot(shot(Vector2(5600, 402), 900), 5200, f.host, f.world) and b.hp == previous - 1, "Sweep through valve with endpoint outside deals only1")
	b.sink = 1.0
	var box: Dictionary = f.captain.body_box()
	close(box.x0, 5352.5, "Sink scales left body edge")
	close(box.x1, 5528, "Sink scales right body edge")
	close(box.top, 307.5, "Sink scales top body edge")
	check(box.bot == 502, "Sink does not scale fixed20px bottom offset")

func _test_generic_adapter() -> void:
	var f := fight()
	check(is_same(f.captain.state, f.captain.boss) and f.captain.state.fy == 522, "Generic state aliases boss and repaired current feet")
	check(not f.captain.hit(Vector2(5450, 400)), "Generic hit without runtime binding is harmless")
	f.captain.configure_context(f.host, f.world)
	check(f.captain.hit(Vector2(5450, 400), 100) and f.captain.state.hp == 89, "Bound generic hit routes through same fixed1 shot policy")
	# Original startW4Boss stores y only. This explicit source-shaped fixture
	# demonstrates its invalid direct-special coordinate separately from repair.
	var original_source_shape := {"x": 5450.0, "y": 522.0}
	var original_point := Vector2(original_source_shape.x, float(original_source_shape.get("fy", NAN)) - 120)
	check(not original_point.is_finite() and not f.captain.hit(original_point), "Original missing-fy direct-special is invalid and safely rejected")
	var repaired_point := Vector2(f.captain.state.x, f.captain.state.fy - 120)
	check(repaired_point == Vector2(5450, 402) and f.captain.hit(repaired_point, 999) and f.captain.state.hp == 88, "Native mapped direct-special now hits for fixed1")
	f.captain.reset(f.host)
	f.captain.start(f.host)
	f.captain.boss.state = "drift"
	check(not f.captain.hit(Vector2(5972, 400)), "Reset invalidates old runtime binding")
	f.captain.boss.x = 5450.0
	f.captain.tick(0, f.host, f.world)
	check(f.captain.hit(Vector2(5450, 400)), "Boss tick binds context for generic integration")

func _test_down_jar() -> void:
	var f := fight()
	var b: Dictionary = f.captain.boss
	b.hp = 1
	b.wave = [{"x": 5300.0, "vx": 400.0, "t": 0.0}]
	check(f.captain.intercept_shot(shot(Vector2(5450, 300)), 5450, f.host, f.world), "Final ordinary hit accepted")
	check(b.state == "down" and b.hp == 0 and b.t == 0 and b.wave.is_empty(), "Lethal hit immediately downs and clears own waves")
	check(f.host.sounds == ["hitBot", "pop", "stomp"] and f.world.cleanups == 1, "Down hit/pop/stomp and one threat-cleanup callback")
	check(f.host.rewards == [{"p": Vector2(5390, 282), "count": 18}], "Down source18coins at x-60/ground-200")
	check(f.host.clears == 0 and f.captain.jar.is_empty(), "Boss death is not level clear or instant jar")
	check(not f.captain.intercept_shot(shot(Vector2(5450, 300)), 5450, f.host, f.world), "Down immunity avoids duplicate rewards")
	f.host.hearts = 0
	f.captain.tick(1.8, f.host, f.world)
	check(f.captain.jar.is_empty() and f.host.clears == 0, "Exact1800ms does not spawn jar, even while down")
	close(b.sink, 0.75, "2400ms sink progression")
	close(b.y, 576, "Sinking y moves30px/s")
	check(b.fy == b.y, "Native repair feet remain synchronized during sinking")
	f.host.camera.x = 4900
	f.captain.tick(0.001, f.host, f.world)
	check(f.captain.jar == {"p": Vector2(5269, 262), "v": Vector2(-100, -900), "t": 0.0, "got": false}, "Jar spawns strict1800ms at current camera center with exact source launch")
	check(f.host.sounds[-1] == "power" and f.host.clears == 0, "Jar power cue, collection remains host responsibility")
	var original_jar: Dictionary = f.captain.jar
	f.captain.tick(5, f.host, f.world)
	check(b.sink == 1 and is_same(original_jar, f.captain.jar) and f.captain.jar.t == 0, "Sink caps1; no jar motion/replacement in boss tick")
	close(b.y, 726.03, "Y continues sinking after scale reaches cap")
	check(b.fy == b.y and f.captain.state.fy == b.y, "Shared ability feet follow continued sink after cap")
	f.captain.jar.got = true
	f.captain.tick(5, f.host, f.world)
	check(f.captain.jar.got and f.host.rewards.size() == 1 and f.world.cleanups == 1 and f.host.clears == 0, "Collected jar never respawns and controller never directly clears")
