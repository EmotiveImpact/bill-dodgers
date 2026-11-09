extends SceneTree
const BusRide = preload("res://src/bus_ride.gd")
const WorldOne = preload("res://src/world_one.gd")
const Combat = preload("res://src/combat.gd")
var checks := 0
var failures: Array[String] = []

class Host extends RefCounted:
	var level_id := "1-3"
	var meta: Dictionary = {}
	var level: Dictionary = {}
	var player := Vector2(319, 150)
	var velocity := Vector2.ZERO
	var camera := Vector2.ZERO
	var camera_speed := 0.0
	var camera_lock = null
	var grounded := true
	var on_platform := false
	var hearts := 3
	var invincible := 0.0
	var face := 1
	var mode := "play"
	var status := ""
	var pop_count := 0
	var player_animation := "idle"
	var boss = null
	var enemies: Array = []
	var coins: Array = []
	var crates: Array = []
	var sounds: Array = []
	var hurt_attempts := 0
	var hurt_source := 0.0
	var combat = Combat.new()
	var world_one = WorldOne.new()
	var bus_ride = BusRide.new()
	func view_width() -> float: return 738
	func view_top() -> float: return camera.y + 540 - 540 / 1.3
	func character_height() -> float: return 180
	func sfx(effect: String) -> void: sounds.append(effect)
	func hurt_player(from_x: float) -> void:
		hurt_attempts += 1
		hurt_source = from_x
		if invincible == 0 and hearts > 0: hearts -= 1
	func add_coins(p: Vector2, count: int) -> void:
		for i in range(count): coins.append({"p": p})
	func floor_at(x: float, y: float) -> float:
		var surface: Dictionary = world_one.below(self, x, y)
		return float(surface.row[2]) if not surface.is_empty() else float(meta.ground)
	func reset_source() -> void:
		level_id = "1-3"
		meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/1-3.json"))
		level = meta.level
		player = Vector2(319, 150)
		camera = Vector2(0, -332)
		velocity = Vector2.ZERO
		grounded = true
		hearts = 3
		invincible = 0
		mode = "play"
		player_animation = "idle"
		enemies.clear()
		coins.clear()
		crates.clear()
		sounds.clear()
		hurt_attempts = 0
		world_one.reset(self)
		combat.reset(self, 31)
		bus_ride.reset(self)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)

func near(a: float, b: float) -> bool: return absf(a - b) < 0.00001
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var h = Host.new()
	h.reset_source()
	var bus = h.bus_ride
	check(h.combat.waves.size() == 12 and h.level.between.size() == 12, "Bus retains twelve source fights and twelve between-wave entries")
	var source_obstacles: Array = []
	for group in h.level.between: source_obstacles.append_array(group)
	check(source_obstacles.size() == 25 and h.level.between.back().is_empty(), "Source route contains25obstacles and none after last fight")
	check(h.level.w == 738 and h.level.solids[0][0] == 45 and h.level.solids[0][1] == 689 and bus.roof_y == 150, "Fixed738pixelbusarena preserves45-to689roof at150")
	check(h.level.bus[0] == 19 and h.level.bus[1] == 146 and h.level.bus[2] == 700 and h.level.bus[3] == 385, "Original bus artwork rectangle remains unchanged")
	check(bus.enabled and bus.phase == "obst" and bus.slot == 0 and bus.rest_time == 2.6 and bus.drive == 0, "Level start resets source2.6secondwait")
	check(h.combat.waves.all(func(w): return w.at == 1.0e9 and not w.started), "All originally-zero wave triggers are gated before first fight")
	var source_json := JSON.stringify(h.level)
	bus.tick(2.59, h)
	check(bus.phase == "obst" and h.combat.waves[0].at == 1.0e9, "First fight waits full initial pause")
	check(near(bus.drive, 1087.8) and h.camera.y == -235 and h.camera.x == 0, "Level update advances scenery at420px/s and pins camera vertical offset")
	bus.tick(0.011, h)
	check(bus.phase == "wave" and h.combat.waves[0].at == -1.0e9 and not h.combat.waves[0].started, "Late scene hook arms first fight for next combat frame")
	check(h.combat.waves[1].at == 1.0e9, "Arming one fight does not start remaining eleven")
	h.combat.waves[0].done = true
	bus.tick(0.016, h)
	check(bus.phase == "obst" and bus.slot == 1 and bus.obstacle_queue == ["bridge"] and bus.rest_time == 1.4, "Won fight copies its bridge queue and starts1.4secondrest")
	bus.tick(1.399, h)
	check(bus.obstacles.is_empty(), "Post-fight rest cannot release obstacle early")
	bus.tick(0.002, h)
	check(bus.obstacles.size() == 1 and bus.obstacles[0].k == "bridge" and bus.obstacles[0].w == 330, "First bridge uses source330pixelwidth")
	check(near(bus.obstacles[0].x, 1576 - 0.84) and near(bus.warn_time, 1.898) and bus.rest_time == 0.9, "Spawn includes source1.9secondlead and same-frame motion/warning decrement")
	bus.tick(0.9, h)
	check(bus.phase == "obst" and h.combat.waves[1].at == 1.0e9, "Elapsed rest cannot arm a fight while obstacle remains onscreen")
	bus.obstacles[0].x = -390
	bus.tick(0, h)
	check(bus.obstacles.is_empty() and bus.phase == "obst", "Obstacle retires at rightedge=-60 and does not arm fight in same pass")
	bus.tick(0, h)
	check(bus.phase == "wave" and h.combat.waves[1].at == -1.0e9, "Next frame releases next fight after final obstacle exits")
	check(JSON.stringify(h.level) == source_json, "Timeline never mutates imported metadata or between lists")
	# Arrival path intercepts shared special dispatch in the original game.
	h.reset_source()
	check(not bus.spawn(h, "r", "fly") and h.enemies.is_empty(), "Flying junk mailers deliberately fall through to shared spawn")
	check(bus.spawn(h, "r", "rush"), "Nonflying robot arrives through bus scooter hook")
	var enemy: Dictionary = h.enemies.back()
	check(enemy.p == Vector2(809, 380) and enemy.entered and enemy.hp == 3 and enemy.type == "rush", "Right rush starts on scooter230pixelsbelowroof")
	check(enemy.hop.finish.x >= 489 and enemy.hop.finish.x <= 609 and enemy.hop.finish.y == 150 and enemy.hop.duration == 0.76, "Right arrival targets source120pixelrange with760mshop")
	check(enemy.cd >= 1.4 and enemy.cd <= 2.3 and enemy.stop == 0 and enemy.speed >= 90 and enemy.speed <= 115, "Rush arrival keeps source cooldown and speed range")
	check(bus.scooters[0].x == 809 and bus.scooters[0].y == 370 and bus.scooters[0].vx == 250 and bus.scooters[0].vy == -200, "Right scooter starts with source outward velocity")
	var finish: Vector2 = enemy.hop.finish
	h.world_one.tick_enemy_hop(0.38, enemy)
	check(enemy.p.distance_to(Vector2((809 + finish.x) / 2, 57)) < 0.0001, "Arrival hop follows208pixel-sourcearc at halfway")
	h.world_one.tick_enemy_hop(0.38, enemy)
	check(enemy.p == finish and not enemy.has("hop") and enemy.segment == h.level.solids[0], "Arrival lands on actual bus surface")
	bus.spawn(h, "l", "flat")
	enemy = h.enemies.back()
	check(enemy.p == Vector2(-71, 380) and enemy.hp == 4 and enemy.type == "flat" and enemy.face == 1, "Left flat arrival keeps type, body and facing")
	check(enemy.hop.finish.x >= 129 and enemy.hop.finish.x <= 249 and enemy.stop >= 200 and enemy.stop <= 350 and enemy.speed >= 63 and enemy.speed <= 80.5, "Left ordinary arrival uses source landing/stop/speed ranges")
	check(bus.scooters.back().vx == -350 and bus.scooters.back().face == 1, "Left scooter falls away in source opposite direction")
	for kind in ["tiny", "mini"]:
		bus.spawn(h, "r", kind)
		enemy = h.enemies.back()
		check(enemy.source_kind == kind and enemy.kind == "throw" and enemy.type == kind and enemy.hp == 4 and enemy.scale == 1 and not enemy.big and not enemy.has("volley"), "Bus " + kind + " preserves source ordinary body rather than shared upgrade")
	bus.tick(0.1, h)
	check(near(bus.scooters[0].x, 834) and near(bus.scooters[0].y, 366) and near(bus.scooters[0].vy, -40), "Scooter uses semi-implicit1600px/s2gravity and outward movement")
	bus.tick(1.399, h)
	check(bus.scooters.size() == 4, "Scooter remains before1.5seconds")
	bus.tick(0.002, h)
	check(bus.scooters.is_empty(), "Scooters retire at source1.5secondlifetime")
	# Obstacle collision uses animation pose and strict vertical threshold.
	h.reset_source()
	bus.obstacles = [{"k": "bridge", "x": 300.0, "w": 330.0, "hit": false}]
	bus.tick(0, h)
	check(h.hearts == 2 and h.hurt_attempts == 1 and h.hurt_source == h.player.x + 40 and bus.obstacles[0].hit, "Standing player hit once with source leftward knockback origin")
	bus.tick(0, h)
	check(h.hearts == 2 and h.hurt_attempts == 1, "Obstacle cannot hit same player repeatedly")
	h.reset_source()
	h.player_animation = "crouch"
	bus.obstacles = [{"k": "bridge", "x": 300.0, "w": 330.0, "hit": false}]
	bus.tick(0, h)
	check(h.hearts == 3 and not bus.obstacles[0].hit, "Crouched source body fits beneath bridge")
	h.player_animation = "idle"
	bus.tick(0, h)
	check(h.hearts == 2, "Standing up while under bridge incurs hit")
	h.reset_source()
	h.player.y = 174
	bus.obstacles = [{"k": "bridge", "x": 300.0, "w": 330.0, "hit": false}]
	bus.tick(0, h)
	check(h.hearts == 3, "Bridge uses source roof-132 underside")
	bus.obstacles = [{"k": "branch", "x": 300.0, "w": 150.0, "hit": false}]
	bus.tick(0, h)
	check(h.hearts == 2, "Branch uses lower source roof-128 underside")
	h.reset_source()
	h.player.x = 290
	h.invincible = 1
	bus.obstacles = [{"k": "bridge", "x": 300.0, "w": 330.0, "hit": false}]
	bus.tick(0, h)
	check(h.hearts == 3 and bus.obstacles[0].hit and h.hurt_attempts == 1, "Inclusive left10pixelmargin marks hit even while invulnerable")
	h.invincible = 0
	bus.tick(0, h)
	check(h.hearts == 3 and h.hurt_attempts == 1, "Expired invulnerability cannot cause second hit from same obstacle")
	h.reset_source()
	h.player.x = 640.01
	bus.obstacles = [{"k": "bridge", "x": 300.0, "w": 330.0, "hit": false}]
	bus.tick(0, h)
	check(h.hearts == 3 and not bus.obstacles[0].hit, "Collision excludes point beyond right10pixelmargin")
	h.player.x = 640
	bus.tick(0, h)
	check(h.hearts == 2, "Collision includes exact right10pixelmargin")
	# Bridges/branches pop roof robots, never flying or still-arriving robots.
	h.reset_source()
	h.player_animation = "crouch"
	bus.spawn(h, "r", "rush")
	enemy = h.enemies.back()
	enemy.p = Vector2(350, 150)
	enemy.erase("hop")
	bus.spawn(h, "l", "throw")
	var arriving: Dictionary = h.enemies.back()
	arriving.p = Vector2(360, 150)
	var flyer := enemy.duplicate(true)
	flyer.kind = "fly"
	flyer.fly = true
	flyer.p.x = 370
	h.enemies.append(flyer)
	var edge := enemy.duplicate(true)
	edge.p.x = 300
	h.enemies.append(edge)
	bus.obstacles = [{"k": "branch", "x": 300.0, "w": 150.0, "hit": false}]
	bus.tick(0, h)
	check(enemy.state == "pop" and enemy.t == 0 and h.pop_count == 0, "Obstacle pops grounded robot without granting player kill credit")
	check(arriving.state == "walk" and flyer.state == "walk" and edge.state == "walk", "Obstacle spares arrival hops/flyers/exact horizontal edge")
	check(h.coins.size() >= 4 and h.coins.size() <= 6, "Obstacle robot kill drops source four-to-sixcoins")
	# Full timeline: a controller fixture resolves each fight only after its last
	# actual source spawn delay. This validates sequencing, not combat difficulty.
	h.reset_source()
	h.player_animation = "crouch"
	var seen_obstacles: Array = []
	var started: Array = []
	var simultaneous := false
	var dt := 1.0 / 60
	var ending_count := 0
	var clear_count := 0
	for frame in range(30000):
		var live_waves := 0
		for i in range(h.combat.waves.size()):
			var wave: Dictionary = h.combat.waves[i]
			if not wave.started and h.camera.x >= wave.at - 2:
				wave.started = true
				started.append(i)
			if wave.started and not wave.done:
				live_waves += 1
				wave.t += dt
				if wave.t >= float(wave.group.back()[0]) / 1000: wave.done = true
		if live_waves > 1 or (live_waves > 0 and not bus.obstacles.is_empty()): simultaneous = true
		var objective: String = bus.objective_tick(dt, h)
		if objective == "ending": ending_count += 1
		if objective == "clear": clear_count += 1; break
		var before: int = bus.obstacles.size()
		bus.tick(dt, h)
		if before == 0 and bus.obstacles.size() == 1: seen_obstacles.append(bus.obstacles[0].k)
	check(started == range(12), "Full controller sequence starts all twelve source fights in order")
	check(seen_obstacles == source_obstacles, "Full controller sequence passes all25sourceobstacles in exact order")
	check(not simultaneous, "No fight overlaps another fight or its between-wave obstacles")
	check(ending_count == 1 and clear_count == 1 and h.combat.waves.all(func(w): return w.done), "Final completed fight emits one delayedclear with no invented bus boss")
	check(h.hearts == 3, "Holding source crouch safely survives every generated obstacle in controller fixture")
	check(h.world_one.objective_tick(10, h) == "", "Generic WorldOne module still cannot clear unintegrated bus preview")
	# Independent objective guards, reset and pause.
	h.reset_source()
	check(bus.objective_tick(10, h) == "" and bus.end_time == 0, "Unfinished bus waves cannot be bypassed by waiting")
	for wave in h.combat.waves: wave.done = true
	check(bus.objective_tick(0.016, h) == "ending" and near(bus.end_time, 0.017), "Bus ending uses shared one-millisecondinitialtimer")
	check(bus.objective_tick(2.582, h) == "", "Bus finish banner remains for full source2.6seconds")
	h.mode = "paused"
	var drive_before: float = bus.drive
	bus.tick(10, h)
	check(bus.drive == drive_before and bus.objective_tick(10, h) == "", "Pause freezes scenery timeline and ending timer")
	h.mode = "play"
	check(bus.objective_tick(0.002, h) == "clear" and bus.objective_tick(10, h) == "", "Bus clear is one-shot after required timer")
	h.reset_source()
	check(bus.phase == "obst" and bus.slot == 0 and bus.obstacles.is_empty() and bus.scooters.is_empty() and bus.end_time == 0, "Restart resets all timeline and ending state")
	h.level_id = "1-2"
	bus.reset(h)
	check(not bus.enabled and not bus.spawn(h, "r", "rush") and bus.objective_tick(10, h) == "", "Bus module cannot take over another level")
	print("Bus ride scene state: ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
