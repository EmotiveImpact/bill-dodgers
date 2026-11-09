extends SceneTree
const Boss = preload("res://src/festival_boss.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func config(id: String = "3-1") -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/" + id + ".json"))
	var result: Dictionary = data.l3.get("mini", data.l3.get("boss", {})).duplicate(true)
	if not result.has("cam"): result.cam = float(data.level.w) - 738
	return result

func players(x: float = 9200, y: float = 482) -> Array[Dictionary]:
	return [{"position": Vector2(x, y), "alive": true}]

func events_of(events: Array, kind: String) -> Array:
	return events.filter(func(event): return event.type == kind)

func fight(id: String = "3-1", count: int = 1, seed_value: int = 31, stage: Dictionary = {}, tents: bool = false):
	var boss = Boss.new()
	boss.reset(config(id), 738, 482, count, seed_value, stage, tents)
	boss.drain_events()
	boss.state.state = "walk"
	boss.state.x = boss.state.cam + 430
	boss.state.next = 99.0
	return boss

func _initialize() -> void:
	_test_source_configs()
	_test_enter()
	_test_hitbox()
	_test_attacks()
	_test_thresholds()
	_test_hops()
	_test_bailiff()
	_test_waves_and_contact()
	_test_death_and_jar()
	print("Festival boss: ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

func _test_source_configs() -> void:
	for pair in [["3-1", 60, 80, "seller"], ["3-3", 70, 95, "bailiff"], ["3-4", 60, 80, "tout"], ["3-6", 160, 220, "tout"]]:
		for count in [1, 2]:
			var b = Boss.new()
			var cfg := config(pair[0])
			b.reset(cfg, 738, 482, count)
			check(b.state.hp == pair[count] and b.state.max == pair[count], str(pair[0]) + " actual scaled health " + str(count))
			check(b.state.kind == pair[3] and b.state.state == "enter" and b.state.x == cfg.cam + 898, str(pair[0]) + " source kind and arrival")
			check(events_of(b.drain_events(), "warning").size() == 1, str(pair[0]) + " one warning event")
			check(b.drain_events().is_empty(), "Event drain consumes warning")
	var cfg := config()
	var b = Boss.new()
	b.reset(cfg)
	cfg.hp = 1
	check(b.state.cfg.hp == 60, "Boss config copied rather than mutating imported META")

func _test_enter() -> void:
	var b = Boss.new()
	b.reset(config())
	b.boss_tick(0.016, players())
	check(b.state.x == 9548 and b.state.state == "enter", "First16ms source clamp teleports9798 to arenaR9548 but stays enter")
	check(not b.hit(Vector2(b.state.x, 400), 99), "Arrival invulnerable even inside hitbox")
	b.boss_tick(0.599, players())
	check(b.state.state == "enter", "Entry requires reaching arenaR-minus180")
	b.boss_tick(0.001, players())
	check(b.state.state == "walk" and b.state.t == 0 and b.state.next == 1.6, "Entry transitions exactly at threshold")
	var x: float = b.state.x
	b.boss_tick(1.6, players(x - 40))
	check(b.state.state == "walk", "Attack wait is strictly greater than next")
	b.boss_tick(0.0001, players(x - 40))
	check(b.state.state in ["throw", "stomp"] and b.state.t == 0, "Attack starts after strict next time")
	b = fight()
	b.state.x = 10000
	b.boss_tick(1, [])
	check(b.state.x == 10000 and b.state.t == 1, "No living target early returns before clamp but timers advance")

func _test_hitbox() -> void:
	var b = fight()
	var x: float = b.state.x
	for point in [Vector2(x - 70, 400), Vector2(x + 70, 400), Vector2(x, 232), Vector2(x, 482)]:
		check(not b.hit(point, 1) and b.state.hp == 60, "Strict boss rectangle excludes " + str(point))
	check(b.hit(Vector2(x + 69.999, 232.001), 50) and b.state.hp == 59, "Ordinary inside hit ignores50damage and takes1")
	check(b.hit(Vector2(x, 400), 0) and b.state.hp == 58, "Zero-damage field still source fixed1")
	b.state.dizzy = 0.001
	check(b.hit(Vector2(x, 400), 1) and b.state.hp == 56, "Positive dizzy doubles fixed hit to2")
	b.boss_tick(0.001, players(x - 200))
	check(b.state.dizzy == 0, "Dizzy expires exactly at zero")
	check(b.hit(Vector2(b.state.x, 400), 99) and b.state.hp == 55, "After expiry high-damage shot returns to1")
	b.state.fy = 354
	check(not b.hit(Vector2(b.state.x, 400)), "Raised stage protects shots below feet")
	check(b.hit(Vector2(b.state.x, 200)), "Raised stage shifts complete hit rectangle")
	b.state.state = "down"
	check(not b.hit(Vector2(b.state.x, 200)), "Down boss cannot intercept shots")

func _test_attacks() -> void:
	var b = fight()
	b.state.state = "throw"
	b.state.t = 0.319
	b.state.pending_throw = true
	var events: Array = b.boss_tick(0, players())
	check(events_of(events, "bill").is_empty(), "Boss throw waits until320ms")
	events = b.boss_tick(0.001, players())
	var bills := events_of(events, "bill")
	check(bills.size() == 3, "Seller first phase throws three wristbands")
	check(bills.all(func(bill): return bill.tie and not bill.big and bill.gravity == 1600), "Wristband attributes survive event representation")
	check(bills.map(func(bill): return int(bill.velocity.y)) == [-700, -760, -820], "Wristband vertical fan60px/s spacing")
	check(bills.map(func(bill): return int(bill.velocity.x)) == [-240, -130, -20], "Fan aims at player offsets110px over1s")
	check(bills[0].position == Vector2(b.state.x - 40, 252), "Throw muzzle uses current boss facing and fy-minus230")
	events = b.boss_tick(0, players())
	check(events_of(events, "bill").is_empty(), "Pending flag prevents duplicate volley")
	b.boss_tick(0.32, players())
	check(b.state.state == "walk" and b.state.next >= 1.3 and b.state.next <= 2.4, "Throw ends640ms with high-health delay1.3to2.4")
	b.state.state = "throw"
	b.state.hp = 19
	b.state.t = 0.32
	b.state.pending_throw = true
	b.state.called = [true, true]
	b.state.dz = true
	events = b.boss_tick(0, players())
	check(events_of(events, "bill").size() == 4, "Below one third seller throws four")
	b.state.fy = 354
	b.state.state = "throw"
	b.state.pending_throw = true
	b.state.t = 0.32
	events = b.boss_tick(0, players())
	check(events_of(events, "bill").size() == 5, "On stage any non-bailiff throws five")
	b.state.state = "stomp"
	b.state.t = 0.32
	b.state.pending_throw = true
	events = b.boss_tick(0, players())
	check(b.state.waves.is_empty() and events_of(events, "stomp").size() == 1, "Stage stomp has sound but no ground shockwaves")
	b.state.fy = 482
	b.state.state = "stomp"
	b.state.t = 0.32
	b.state.pending_throw = true
	b.boss_tick(0, players())
	check(b.state.waves.size() == 2 and b.state.waves[0].vx == -420 and b.state.waves[1].vx == 420, "Ground stomp creates symmetric420px/s waves")
	check(b.state.waves[0].t == 0, "New waves do not move in creation frame")
	b.state.dizzy = 1
	b.state.state = "throw"
	b.state.t = 0.32
	b.state.pending_throw = true
	events = b.boss_tick(0, players())
	check(events_of(events, "bill").is_empty() and b.state.pending_throw, "Dizzy suppresses pending attack while timer continues")

func _test_thresholds() -> void:
	var b = fight("3-1", 1, 31, {}, true)
	b.state.max = 100
	b.state.hp = 66
	var events: Array = b.boss_tick(0, players())
	check(events_of(events, "spawn_bot").is_empty(), "No helper at exact0.66")
	b.state.hp = 65
	events = b.boss_tick(0, players())
	var helpers := events_of(events, "spawn_bot")
	check(helpers.size() == 2 and helpers[0].side == "t" and helpers[0].kind == "rush" and helpers[1].side == "r", "First helpers prefer tent plus right thrower")
	check(events_of(b.boss_tick(0, players()), "spawn_bot").is_empty(), "Threshold helper only once")
	b.state.hp = 50
	b.boss_tick(0, players())
	check(b.state.dizzy == 0, "No dizzy at exact0.5")
	b.state.hp = 49
	events = b.boss_tick(0, players())
	check(b.state.dizzy == 2.6 and b.state.dz and b.state.state == "walk" and events_of(events, "dizzy").size() == 1, "First below-half tick applies2600ms dizzy")
	b.state.hp = 33
	events = b.boss_tick(0, players())
	check(events_of(events, "spawn_bot").is_empty(), "Second helpers not at exact0.33")
	b.state.hp = 32
	events = b.boss_tick(0, players())
	helpers = events_of(events, "spawn_bot")
	check(helpers.size() == 2 and helpers[0].side == "l" and helpers[0].kind == "flat" and helpers[1].kind == "rush", "Below third solo gets left flat and right rush")
	b = fight("3-6", 2)
	b.state.hp = 1
	events = b.boss_tick(0, players(4000))
	helpers = events_of(events, "spawn_bot")
	check(helpers.size() == 5 and helpers[0].side == "l" and helpers[-1].kind == "throw", "Co-op crosses both thresholds with third last-phase helper")
	check(b.state.dizzy == 2.6, "Dizzy applies in same tick as both helper groups")

func _test_hops() -> void:
	var stage := {"row": [4040, 4290, 354], "plat": true}
	var b = fight("3-6", 1, 1, stage)
	b.state.hp = 100
	b.state.next = 0
	b.state.t = 0.001
	var events: Array = b.boss_tick(0, players(4000))
	check(b.state.has("hop") and b.state.hop.end == Vector2(4165, 354), "Mid-health Tout targets actual numeric stage0 platform")
	check(b.state.hop.duration == 0.8 and b.state.hop.height == 160 and b.state.stage_t == 9, "Stage hop800ms160px and nine-second dwell timer")
	check(events_of(events, "spawn_bot").is_empty(), "New hop early return defers helpers and stage timer decrement")
	var x: float = b.state.x
	b.boss_tick(0.4, players(4000))
	check(is_equal_approx(b.state.x, (x + 4165) / 2) and is_equal_approx(b.state.fy, (482 + 354) / 2.0 - 160), "Hop interpolation and sine arc at midpoint")
	check(b.state.stage_t == 9 and not b.state.called[0], "In-flight hop freezes stage timer and threshold callbacks")
	b.boss_tick(0.4, players(4000))
	check(not b.state.has("hop") and b.state.fy == 354 and b.state.next == 0.9 and b.state.t == 0, "Hop landing returns walk without same-frame helpers")
	events = b.boss_tick(0, players(4000))
	check(events_of(events, "spawn_bot").size() == 2, "Helpers dispatch next ordinary boss tick")
	b.state.stage_t = 0
	b.state.next = 0
	b.state.t = 0.001
	b.boss_tick(0, players(3800))
	check(b.state.hop.end == Vector2(3800, 482) and b.state.hop.slam and b.state.stage_t == 6, "Stage exit targets player, slams and sets six-second cooldown")
	check(b.state.hop.duration == 0.9 and b.state.hop.height == 140, "Stage exit900ms140px")
	b.boss_tick(0.9, players(3800))
	check(b.state.waves.size() == 2 and b.state.waves[0].vx == -460 and b.state.land_t == 0.32, "Slam landing460px/s waves and320ms landing pose")
	b = fight("3-6", 1, 1, stage)
	b.state.hp = 40
	b.state.dz = true
	b.state.called = [true, true]
	# Search deterministic seeds only to select the documented random branch.
	for seed_value in range(100):
		b.rng.seed = seed_value
		if b.rng.randf() < 0.4:
			b.rng.seed = seed_value
			break
	b.state.t = 0.001
	b.state.next = 0
	b.boss_tick(0, players(-1000))
	check(b.state.has("hop") and b.state.hop.end.x == b.state.cam + 90 and b.state.hop.height == 230 and b.state.hop.duration == 0.85, "Low-health Tout850ms230px slam clamps target to arena")
	b = fight("3-4")
	b.state.hp = 35
	b.state.t = 0.001
	b.state.next = 0
	b.boss_tick(0, players(8500))
	check(not b.state.has("hop"), "Ringmaster mini has no stage0 because config omits numeric stage")

func _test_bailiff() -> void:
	var b = fight("3-3")
	for seed_value in range(100):
		b.rng.seed = seed_value
		if b.rng.randf() < 0.45:
			b.rng.seed = seed_value
			break
	b.state.t = 0.001
	b.state.next = 0
	b.boss_tick(0, players(8000))
	check(b.state.state == "charge" and b.state.face == -1, "Bailiff has seeded45percent charge branch")
	var x: float = b.state.x
	b.boss_tick(0.1, players(8600))
	check(b.state.x == x - 50 and b.state.face == -1, "Charge500px/s keeps initial facing despite target crossing")
	b.state.x = b.state.cam + 95
	b.boss_tick(0.01, players(8600))
	check(b.state.state == "walk" and b.state.x == b.state.cam + 90 and b.state.next == 0.9, "Charge ends at arena edge with900ms delay")
	b.state.state = "throw"
	b.state.t = 0.32
	b.state.pending_throw = true
	b.state.hp = 20
	b.state.called = [true, true]
	b.state.dz = true
	var events: Array = b.boss_tick(0, players(8600))
	var bills := events_of(events, "bill")
	check(bills.size() == 3 and bills.all(func(bill): return bill.big and not bill.tie), "Bailiff always three big non-tie bills")

func _test_waves_and_contact() -> void:
	var b = fight()
	b.state.dizzy = 10
	var x: float = b.state.x
	for point in [Vector2(x + 62, 482), Vector2(x, 602), Vector2(x, 362), Vector2(x + 61.999, 482)]:
		var events: Array = b.boss_tick(0, players(point.x, point.y))
		check((not events_of(events, "hurt_player").is_empty()) == (absf(point.x - x) < 62 and absf(point.y - 482) < 120), "Boss contact strict62/120 " + str(point))
	b.state.waves = [{"x": 9100.0, "vx": 420.0, "t": 0.0}]
	var events: Array = b.boss_tick(0.1, players(9142, 452))
	check(events_of(events, "hurt_player").is_empty(), "Shockwave excludes exactground-minus30 feet")
	b.state.waves = [{"x": 9100.0, "vx": 420.0, "t": 0.0}]
	events = b.boss_tick(0.1, players(9142, 452.001))
	check(events_of(events, "hurt_player").size() == 1 and events_of(events, "hurt_player")[0].source_x == 9121, "Shockwave moves before contact and uses50ms knockback source")
	b.state.waves = [{"x": 9100.0, "vx": 0.0, "t": 0.0}]
	events = b.boss_tick(0, players(9124))
	check(events_of(events, "hurt_player").is_empty(), "Shockwave excludes exact24px edge")
	b.state.waves = [{"x": 8890.0, "vx": 0.0, "t": 0.0}, {"x": 9648.0, "vx": 0.0, "t": 0.0}]
	b.boss_tick(0, players())
	check(b.state.waves.is_empty(), "Shockwaves culled at exactarenaL-minus100 and arenaR-plus100")

func _test_death_and_jar() -> void:
	var b = fight()
	b.state.hp = 1
	b.state.waves = [{"x": 9000, "vx": -420, "t": 0.0}]
	b.state.hop = {"anything": true}
	check(b.hit(Vector2(b.state.x, 400)), "Last hit accepted")
	var events: Array = b.drain_events()
	check(b.state.state == "down" and b.state.t == 0 and b.state.waves.is_empty() and not b.state.has("hop"), "Down cancels hop and ground waves immediately")
	check(events.map(func(event): return event.type) == ["hit", "drop_coins", "kill_bots", "down"], "Down hit/reward/helper cleanup/source order")
	check(events[1].count == 16 and events[3].mini, "Mini still drops16coins but no jar")
	check(events_of(b.boss_tick(1.8, players()), "mini_done").is_empty() and b.state.jar.is_empty(), "No mini departure at exact1800ms")
	check(events_of(b.boss_tick(0.001, players()), "mini_done").size() == 1, "Mini departure strictly after1800ms")
	check(events_of(b.boss_tick(1, players()), "mini_done").is_empty() and b.state.jar.is_empty(), "Mini completion one-shot and never jar clear")
	b = fight("3-6")
	b.state.hp = 1
	b.hit(Vector2(b.state.x, 400))
	b.drain_events()
	check(events_of(b.boss_tick(1.5, []), "jar_spawn").is_empty(), "No jar at exact1500ms")
	events = b.boss_tick(0.001, [])
	check(events_of(events, "jar_spawn").size() == 1 and b.state.jar.t == 0, "Jar spawns strict1500ms even without living targets")
	var initial_x: float = b.state.jar.x
	b.jar_tick(0.1, [])
	check(is_equal_approx(b.state.jar.x, initial_x - 12) and is_equal_approx(b.state.jar.y, 216) and b.state.jar.vy == -660, "New jar receives full current timestep with source semi-implicit gravity")
	b.state.jar = {"x": 4000.0, "y": 452.0, "vx": 0.0, "vy": 0.0, "t": 0.6, "got": false}
	check(events_of(b.jar_tick(0, players(4000, -10000)), "clear").is_empty(), "Exact600ms jar cannot collect")
	check(events_of(b.jar_tick(0.001, players(4050, -10000)), "clear").is_empty(), "Jar excludes exact50px edge, independent of player height")
	events = b.jar_tick(0, players(4049.999, -10000))
	check(events_of(events, "clear").size() == 1 and b.state.jar.got, "Jar collection is horizontal only after600ms")
	check(b.jar_tick(10, players(4000)).is_empty(), "Collected jar never clears twice")
	b.state.jar = {"x": 4000.0, "y": 451.0, "vx": -120.0, "vy": 190.0, "t": 0.0, "got": false}
	b.jar_tick(0.01, [])
	check(b.state.jar.y == 452 and is_equal_approx(b.state.jar.vy, -85.6) and b.state.jar.vx == -60, "Jar >200px/s bounce40percent and horizontal half")
	b.state.jar = {"x": 4000.0, "y": 451.9, "vx": -120.0, "vy": 176.0, "t": 0.0, "got": false}
	b.jar_tick(0.01, [])
	check(b.state.jar.vy == 0 and b.state.jar.vx == -60, "Jar speed200px/s exact settles instead of bouncing")
	var cfg := config("3-6")
	b.reset(cfg)
	check(b.state.jar.is_empty() and b.state.state == "enter" and b.state.hp == 160, "Replay reset removes jar/death state and restores source HP")
