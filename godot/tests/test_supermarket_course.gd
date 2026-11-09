extends SceneTree
## Isolated source-boundary fixtures, not input-driven completion/device proof.
const Course = preload("res://src/supermarket_course.gd")
const World = preload("res://src/world_two.gd")
const Abilities = preload("res://src/abilities.gd")
const Skills = preload("res://src/movement_skills.gd")

class Host extends RefCounted:
	var level_id := "2-4"
	var level := {"auto": 0.2, "ride": 30, "hz": [], "solids": [[-400, 40000, 482]], "plats": []}
	var meta := {"ground": 482, "heights": Skills.HEIGHTS}
	var mode := "play"
	var player := Vector2(369, 482)
	var velocity := Vector2.ZERO
	var camera := Vector2.ZERO
	var elapsed := 0.0
	var hearts := 3
	var invincible := 0.0
	var grounded := true
	var on_platform := false
	var player_animation := "idle"
	var crouching := false
	var face := 1
	var character := "jp"
	var hits: Array = []
	var combat := {"waves": []}
	var world = World.new()
	var course = Course.new()
	var abilities = Abilities.new()
	var movement_skills = Skills.new()
	func character_height() -> float: return float(meta.heights[character])
	func view_width() -> float: return 738.0
	func hurt_player(from_x: float) -> void:
		hits.append(from_x)
		if hearts <= 0 or invincible > 0 or mode != "play": return
		if movement_skills.blocks_damage() or abilities.blocks_damage(self): return
		hearts -= 1
		invincible = 1.5
		player_animation = "hit"
		velocity.x = -350 if player.x < from_x else 350
	func reset(rows: Array = []) -> void:
		level.hz = rows.duplicate(true)
		world.reset(self)
		course.reset(self, world)
		abilities.reset(character)
		movement_skills.reset(level_id)
	func fixture(id: String) -> void:
		level_id = id
		meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/%s.json" % id))
		level = meta.level.duplicate(true)
		reset(level.hz)
	func actor(point: Vector2, pose: String = "idle") -> void:
		player = point
		player_animation = pose
		crouching = pose == "crouch"
		grounded = pose != "jump"
		hearts = 3
		invincible = 0
		velocity = Vector2.ZERO
		hits.clear()
		abilities.reset(character)
		movement_skills.reset(level_id)
	func tick(dt: float = 0.0) -> void: course.hazards_tick(dt, self, world)

class PairHost extends Host:
	var roster: Array = []
	func combat_participants() -> Array: return roster
	func hurt_combat_participant(participant: Dictionary, from_x: float) -> void:
		hits.append(from_x)
		if float(participant.get("invincible", 0)) > 0: return
		participant.hearts -= 1
		participant.invincible = 1.5

var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func near(a: float, b: float) -> bool:
	# Godot Vector2 stores32-bit coordinates, unlike JavaScript Number. Allow
	# sub-millipixel speed noise, never loosen production collision comparisons.
	return absf(a - b) < 0.0001

func _initialize() -> void: call_deferred("run")

func run() -> void:
	_schema()
	_auto_speed()
	_authored_collisions()
	_low_exact_head_edges()
	_flame_clock()
	_hurt_order_and_bounce()
	_participants()
	_lifecycle()
	_real_host_defenses()
	print("Supermarket course: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _schema() -> void:
	var h := Host.new()
	h.fixture("2-4")
	var original := JSON.stringify(h.meta)
	check(h.course.hazards.size() == 102, "2-4 retains all102 tuples, including hazards owned elsewhere")
	for row in [["block", 36], ["low", 14], ["boost", 7], ["trolleys", 2], ["coins", 43]]:
		check(h.course.hazards.filter(func(hz): return hz[0] == row[0]).size() == row[1], "2-4 authored %s count%d" % [row[0], row[1]])
	check(h.course.hazards.filter(func(hz): return hz[0] == "boost").map(func(hz): return hz[1]) == [4884.0, 10048.0, 15435.0, 20576.0, 25619.0, 30934.0, 36237.0], "All seven authored boost starts retained in order")
	check(near(h.course.speed, 200) and not h.course.boost, "Authored trolley initial speed is200px/s")
	h.course.hazards[0][1] = -999
	check(JSON.stringify(h.meta) == original and h.world.hazards[0][1] != -999, "Course owns a deep copy, never mutates source/runtime schemas")
	h.fixture("2-5")
	check(h.course.hazards.size() == 28, "Bakery retains all28 authored tuples")
	check(h.course.hazards.filter(func(hz): return hz[0] == "flame").size() == 13, "Bakery has thirteen actual flame jets")
	check(h.course.hazards.filter(func(hz): return hz[0] == "block").size() == 2 and h.course.speed == 0, "Bakery has two wet signs and no automatic scroll")
	var flames: Array = h.course.hazards.filter(func(hz): return hz[0] == "flame")
	check(flames.map(func(hz): return hz[1]) == [1920.0, 2440.0, 2960.0, 3480.0, 4000.0, 4520.0, 6320.0, 6780.0, 7240.0, 7700.0, 8160.0, 8620.0, 9080.0], "All thirteen oven positions match source")
	check(flames.map(func(hz): return hz[3]) == [2600.0, 2600.0, 2600.0, 2600.0, 2600.0, 2600.0, 2200.0, 2200.0, 2200.0, 2200.0, 2200.0, 2200.0, 2200.0], "Six2600ms and seven2200ms flame cycles retained")
	check(flames.map(func(hz): return hz[4]) == [2200.0, 640.0, 1680.0, 120.0, 1160.0, 2200.0, 1000.0, 180.0, 1560.0, 740.0, 2120.0, 1300.0, 480.0], "Every authored flame offset retained")
	var geometry := JSON.stringify(h.world.surfaces(h))
	var entities := JSON.stringify(h.world.entities)
	h.course.reset(h, h.world)
	h.tick()
	check(JSON.stringify(h.world.surfaces(h)) == geometry and JSON.stringify(h.world.entities) == entities, "Course does not create solid blocks, trolley decks, drops, belts or other module state")

func _auto_speed() -> void:
	var h := Host.new()
	h.reset([["boost", 1000, 1800]])
	check(near(h.course.auto_displacement(0.1, h), 20) and near(h.course.speed, 200), "Base automatic scroll moves20px in100ms")
	for endpoint in [1, 2]:
		h.camera.x = 1000
		h.player.x = 1369
		var probe: float = h.camera.x + h.view_width() * 0.4
		h.course.hazards = [["boost", probe, probe + 800]] if endpoint == 1 else [["boost", probe - 800, probe]]
		h.course.auto_displacement(0, h)
		check(not h.course.boost, "Boost excludes exact boundary endpoint%s" % endpoint)
	h.course.hazards = [["boost", 1000, 1800]]
	h.camera.x = 800
	h.player.x = h.camera.x + h.view_width() * 0.5
	var before_player := h.player
	var before_camera := h.camera
	check(near(h.course.auto_displacement(0.35, h), 89.25) and h.course.boost and near(h.course.speed, 255), "Boost enters smoothly at half700ms interpolation toward310")
	check(h.player == before_player and h.camera == before_camera and h.velocity == Vector2.ZERO and h.grounded, "Auto returns camera displacement without moving or locking the trolley/player")
	h.combat.waves = [{"started": true, "done": false}]
	h.course.auto_displacement(0.35, h)
	check(near(h.course.speed, 220.5), "Active-wave multiplier applies to boosted target186 before interpolation")
	h.combat.waves[0].done = true
	h.course.auto_displacement(0.35, h)
	check(near(h.course.speed, 265.25), "Completed wave releases slowdown on the next camera evaluation")
	h.camera.x = 1600
	h.player.x = h.camera.x + h.view_width() * 0.5
	h.course.auto_displacement(0.35, h)
	check(not h.course.boost and near(h.course.speed, 232.625), "Leaving boost eases back to200 rather than snapping")
	h.combat.waves = [{"started": false, "done": false}, {"started": true, "done": true}]
	h.course.auto_displacement(0.7, h)
	check(near(h.course.speed, 200), "Unstarted and finished waves do not slow camera")
	for spec in [[0.0, 0.0], [0.5, 0.0], [0.65, 60.0], [0.8, 120.0], [1.3, 120.0]]:
		h.player.x = h.camera.x + h.view_width() * spec[0]
		h.course.auto_displacement(0.7, h)
		check(near(h.course.speed, 200 + spec[1]), "Front fraction%s clamps push to%s px/s" % [spec[0], spec[1]])
	h.combat.waves[0].started = true
	h.course.auto_displacement(2.0, h)
	check(near(h.course.speed, 240), "Large-dt interpolation caps at1; wave slowdown does not multiply120px/s front push")
	h.hearts = 0
	h.course.auto_displacement(0.7, h)
	check(near(h.course.speed, 120), "Empty living roster uses camera as front, adding no push")
	h.fixture("2-5")
	h.player.x = 9999
	check(h.course.auto_displacement(1, h) == 0 and h.course.speed == 0, "Non-auto bakery cannot gain accidental push-only scrolling")

func _collision(h, row: Array, point: Vector2, pose: String, expected: bool, label: String) -> void:
	h.actor(point, pose)
	h.tick()
	check((h.hits.size() == 1) == expected, label)
	if expected:
		var from_x: float = float(row[1]) + (200 if row[0] == "low" else 300 if row[0] == "block" else -h.face)
		check(near(h.hits[0], from_x), label + " source knockback side")

func _authored_collisions() -> void:
	var h := Host.new()
	for stage in ["2-4", "2-5"]:
		h.fixture(stage)
		var rows: Array = h.course.hazards.duplicate(true)
		for who in Skills.HEIGHTS:
			h.character = who
			for row in rows:
				if row[0] not in ["block", "low", "flame"]: continue
				h.world.hazards = [row]
				h.course.reset(h, h.world)
				var x := float(row[1])
				var floor_y := float(row[2])
				var label := "%s %s %s at%s" % [stage, who, row[0], x]
				if row[0] == "flame":
					h.elapsed = (float(row[3]) - float(row[4])) / 1000.0
					for pose in ["idle", "crouch", "jump"]:
						_collision(h, row, Vector2(x, floor_y), pose, true, label + " full logical height at zero visual ramp " + pose)
					for dx in [-36.0, 36.0]: _collision(h, row, Vector2(x + dx, floor_y), "idle", false, label + " strict x edge%s" % dx)
					_collision(h, row, Vector2(x + 35.99, floor_y - 174.99), "jump", true, label + " inside both boundaries")
					_collision(h, row, Vector2(x, floor_y - 175), "jump", false, label + " feet lower edge excluded")
					_collision(h, row, Vector2(x, floor_y + 4), "jump", true, label + " feet upper edge included")
					_collision(h, row, Vector2(x, floor_y + 4.01), "jump", false, label + " beyond feet upper edge")
					h.elapsed = (float(row[3]) - float(row[4]) + 1000.0) / 1000.0
					_collision(h, row, Vector2(x, floor_y), "idle", false, label + " one-second active edge excluded")
				elif row[0] == "low":
					_collision(h, row, Vector2(x, floor_y), "idle", true, label + " standing hits")
					_collision(h, row, Vector2(x, floor_y), "crouch", false, label + " crouch clears")
					_collision(h, row, Vector2(x, floor_y - 70), "jump", true, label + " jumping intersects sign")
					for pose in ["shoot", "up", "diag", "rundiag"]: _collision(h, row, Vector2(x, floor_y), pose, true, label + " non-crouch pose " + pose)
					for dx in [-52.0, 52.0]: _collision(h, row, Vector2(x + dx, floor_y), "idle", false, label + " strict x edge%s" % dx)
					_collision(h, row, Vector2(x + 51.99, floor_y), "idle", true, label + " inside horizontal edge")
					_collision(h, row, Vector2(x, floor_y - float(row[3]) - 40), "jump", false, label + " feet underside-minus40 excluded")
					_collision(h, row, Vector2(x, floor_y - float(row[3]) - 39.99), "jump", true, label + " feet just inside underside-minus40")
				else:
					var radius := float(row[3]) / 2 + 12
					var low := floor_y - float(row[4]) + 8
					for pose in ["idle", "crouch", "jump"]:
						_collision(h, row, Vector2(x, floor_y), pose, true, label + " body-independent contact " + pose)
						check(h.velocity.y == -700 and not h.grounded, label + " normal hit bounces")
					for dx in [-radius, radius]: _collision(h, row, Vector2(x + dx, floor_y), "idle", false, label + " strict x edge%s" % dx)
					_collision(h, row, Vector2(x + radius - 0.01, low + 0.01), "jump", true, label + " inside both edges")
					_collision(h, row, Vector2(x, low), "jump", false, label + " feet lower edge excluded")
					_collision(h, row, Vector2(x, floor_y + 4), "jump", true, label + " feet upper edge included")
					_collision(h, row, Vector2(x, floor_y + 4.01), "jump", false, label + " beyond upper feet edge")

func _low_exact_head_edges() -> void:
	var h := Host.new()
	for who in Skills.HEIGHTS:
		h.character = who
		for pose in ["idle", "crouch"]:
			var top := -h.character_height() * (0.56 if pose == "crouch" else 0.86) - 12
			var row := ["low", 300, 0, -top, 0, 0]
			h.reset([row])
			_collision(h, row, Vector2(300, 0), pose, false, "%s %s exact head underside excluded" % [who, pose])
			_collision(h, row, Vector2(300, -0.01), pose, true, "%s %s just above head underside hits" % [who, pose])
			_collision(h, row, Vector2(300, 0.01), pose, false, "%s %s just below head underside clears" % [who, pose])
			# Twelve pixels above the unmounted head, but six below the ride head.
			row[3] = -top - 6
			h.reset([row])
			_collision(h, row, Vector2(300, 0), pose, true, "%s %s ride adds exactly12px logical head offset" % [who, pose])
			h.level.ride = 0
			h.course.reset(h, h.world)
			_collision(h, row, Vector2(300, 0), pose, false, "%s %s no-ride head clears the same sign" % [who, pose])
			h.level.ride = 30
	# Source uses rendered/current act, not a stale held-down flag.
	h.reset([["low", 300, 482, 128]])
	h.actor(Vector2(300, 482), "jump")
	h.crouching = true
	h.tick()
	check(h.hits.size() == 1, "Held down does not grant crouch geometry during jump/hit/aim poses")

func _flame_clock() -> void:
	var h := Host.new()
	var row := ["flame", 300, 482, 2600, 0]
	h.reset([row])
	for stamp in [0.0, 0.00001, 0.149999, 0.15, 0.85, 0.850001, 0.999999, 1.0, 1.000001, 1.9, 1.900001, 2.599999, 2.6]:
		h.elapsed = stamp
		h.actor(Vector2(300, 308), "jump")
		h.world.elapsed = 999.0
		h.tick(10.0)
		var phase := fposmod(stamp * 1000, 2600) / 1000
		check(near(h.course.elapsed, stamp) and near(h.course.flame_phase(row), phase), "Source clock snapshot at%s ignores late runtime clock and supplied dt" % stamp)
		check((h.hits.size() == 1) == (phase < 1), "Logical175px flame remains active throughout ramp/shrink, inactive in warning interval at%s" % stamp)
		var old: float = h.course.elapsed
		for i in range(10): h.course.flame_phase(row)
		check(h.course.elapsed == old, "Repeated renderer phase reads are pure at%s" % stamp)
	h.world.hazards = [["flame", 300, 482, 2200, 1000]]
	h.course.reset(h, h.world)
	h.elapsed = 0
	h.actor(Vector2(300, 482))
	h.tick()
	check(h.hits.is_empty() and near(h.course.flame_phase(h.course.hazards[0]), 1), "Authored1000ms initial offset is already inactive at fresh start")
	h.elapsed = 1.2
	h.tick()
	check(h.hits.size() == 1 and near(h.course.flame_phase(h.course.hazards[0]), 0), "Offset flame wraps exactly at period")
	h.world.hazards = [["flame", 300, 482, 2600]]
	h.course.reset(h, h.world)
	h.elapsed = 0
	h.actor(Vector2(300, 482))
	h.face = -1
	h.tick()
	check(h.hits == [301.0], "Missing offset defaults0 and left-facing flame uses x-minus-face")

func _hurt_order_and_bounce() -> void:
	var h := Host.new()
	h.reset([["block", 300, 482, 62, 84]])
	for inv in [0.0, 0.9, 1.399999, 1.4, 1.400001, 1.5, 2.5]:
		h.actor(Vector2(300, 482))
		h.invincible = inv
		h.velocity = Vector2(17, 22)
		h.on_platform = true
		h.tick()
		var bounced: bool = inv == 0 or inv > 1.4
		check((h.velocity.y == -700) == bounced and h.grounded != bounced, "Block bounce uses strict post-call inv>1.4 at%s" % inv)
		check(h.hearts == (2 if inv == 0 else 3), "Inv%s routes damage eligibility through host" % inv)
		check(h.velocity.x == (-350 if inv == 0 else 17) and h.on_platform, "Bounce preserves horizontal damage/past velocity and on-platform marker at%s" % inv)
	# Hazards recompute alive per tuple; source stops later attempts after death.
	h.reset([["flame", 300, 482, 2600, 0], ["block", 300, 482, 62, 84]])
	h.actor(Vector2(300, 482))
	h.tick()
	check(h.hits == [299.0, 600.0] and h.hearts == 2 and h.velocity.y == -700, "Flame damage grants inv before same-frame block still bounces")
	h.actor(Vector2(300, 482))
	h.hearts = 1
	h.tick()
	check(h.hits.size() == 1 and h.hearts == 0 and h.velocity.y == 0, "Lethal first hazard removes participant from next tuple")
	h.reset([["block", 300, 482, 62, 84], ["low", 300, 482, 128]])
	h.actor(Vector2(300, 482), "crouch")
	h.tick()
	check(h.hits == [600.0], "Block hurt changes native display but source crouch remains for following low sign")
	h.actor(Vector2(300, 482), "crouch")
	h.hurt_player(600)
	h.hits.clear()
	h.world.hazards = [["low", 300, 482, 128]]
	h.course.reset(h, h.world)
	h.tick()
	check(h.hits.is_empty(), "Earlier combat damage cannot expand crouched source body until next player update")
	h.crouching = false
	h.tick()
	check(h.hits == [500.0], "Next-frame hurt-lock pose uses standing-height sign geometry")

func _participants() -> void:
	var h := PairHost.new()
	h.roster = [
		{"p": Vector2(300, 482), "hearts": 3, "height": 160, "face": -1, "crouching": false, "grounded": true, "invincible": 0.0, "velocity": Vector2(17, 22)},
		{"p": Vector2(300, 482), "hearts": 3, "height": 187, "face": 1, "crouching": true, "grounded": true, "invincible": 0.0, "velocity": Vector2.ZERO},
		{"p": Vector2(10000, 482), "hearts": 3, "down": true},
		{"p": Vector2(10000, 482), "hearts": 0}]
	h.reset([["low", 300, 482, 128]])
	h.tick()
	check(h.roster[0].hearts == 2 and h.roster[1].hearts == 3 and h.hits.size() == 1, "Shared roster uses each participant's own height/posture and excludes down/dead")
	h.world.hazards = [["block", 300, 482, 62, 84]]
	h.course.reset(h, h.world)
	h.tick()
	check(h.roster[0].velocity == Vector2(17, -700) and h.roster[1].velocity.y == -700 and not h.roster[1].grounded, "Mutable shared participant adapter receives post-hurt bounce without moving solo host")
	h.roster[0].p.x = 738 * 0.5
	h.roster[1].p.x = 738 * 0.65
	h.roster[1].cpu = true
	h.course.auto_displacement(0.7, h)
	check(near(h.course.speed, 260), "Auto push includes front-most living CPU but ignores down/dead records")
	h.roster[0].hearts = 0
	h.roster[1].hearts = 0
	h.course.auto_displacement(0.7, h)
	check(near(h.course.speed, 200), "Empty pair roster does not fall back to unrelated solo host")

func _lifecycle() -> void:
	var h := Host.new()
	h.reset([["boost", 100, 1000], ["block", 369, 482, 62, 84]])
	h.elapsed = 5
	h.course.auto_displacement(0.7, h)
	check(near(h.course.speed, 310) and h.course.boost and h.course.elapsed == 5, "Lifecycle fixture starts with live boost state and source clock")
	for mode in ["pause", "over", "menu", "clear"]:
		h.mode = mode
		h.elapsed = 999
		h.tick(10)
		check(h.course.auto_displacement(10, h) == 0 and h.course.speed == 310 and h.course.boost and h.course.elapsed == 5 and h.hits.is_empty(), "Mode%s freezes collision/speed/render clock even when called" % mode)
	h.mode = "play"
	h.elapsed = 5.034
	h.invincible = 2.5
	h.tick(0.034)
	check(h.hearts == 3 and h.velocity.y == -700 and near(h.course.elapsed, 5.034) and h.course.speed == 310, "Continue preserves course speed/boost/clock and permits source invulnerability bounce")
	var impostor := Host.new()
	impostor.reset(h.level.hz)
	h.course.hazards_tick(0.1, impostor, h.world)
	check(h.course.auto_displacement(0.1, impostor) == 0 and impostor.hits.is_empty(), "Another host cannot use a stale course")
	var old_elapsed: float = h.course.elapsed
	h.world.run_generation += 1
	h.elapsed += 1
	h.hits.clear()
	h.tick(1)
	check(h.course.auto_displacement(1, h) == 0 and h.course.elapsed == old_elapsed and h.hits.is_empty(), "Invalidated run generation prevents late callbacks changing state")
	h.elapsed = 0
	h.course.reset(h, h.world)
	check(h.course.speed == 200 and not h.course.boost and h.course.elapsed == 0, "Fresh run restores source initial speed, resets boost and renderer clock")
	h.level_id = "2-5"
	check(h.course.auto_displacement(1, h) == 0, "Changing level id invalidates old component")
	h.level_id = "2-4"
	h.course.hazards_tick(1, h, impostor.world)
	check(h.hits.is_empty(), "Wrong runtime instance cannot drive component")
	var orphan = Course.new()
	var ephemeral = World.new()
	ephemeral.reset(h)
	orphan.reset(h, ephemeral)
	ephemeral = null
	check(orphan.auto_displacement(1, h) == 0, "Freed runtime weak reference safely invalidates component")

func _real_host_defenses() -> void:
	# Actual main hurt_player/abilities/skills path, with isolated placement.
	# No stage promotion, real traversal, saved clear, or device claim is made.
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	game.load_level("2-4", false)
	game.world_two.reset(game)
	var course = Course.new()
	for kind in ["flame", "low", "block"]:
		game.world_two.hazards = [["flame", 300, 482, 2600, 0]] if kind == "flame" else [["low", 300, 482, 128]] if kind == "low" else [["block", 300, 482, 62, 84]]
		course.reset(game, game.world_two)
		for defense in ["none", "maya_active", "maya_passive", "slide", "dash", "invincible"]:
			game.character = "maya" if defense.begins_with("maya") else "jp"
			game.abilities.reset(game.character)
			game.movement_skills.reset("2-4", ["slide", "dash"])
			game.mode = "play"
			game.hearts = 3
			game.invincible = 0
			game.hurt_lock = 0
			game.elapsed = 0
			game.player = Vector2(300, 482)
			game.player_animation = "idle"
			game.velocity = Vector2.ZERO
			game.grounded = true
			match defense:
				"maya_active": game.abilities.active = "maya"
				"maya_passive": game.abilities._hits = 1
				"slide": game.movement_skills.slide_remaining = 0.3
				"dash": game.movement_skills.dash_remaining = 0.2
				"invincible": game.invincible = 2.5
			course.hazards_tick(0, game, game.world_two)
			check(game.hearts == (2 if defense == "none" else 3), "Actual main %s respects%s damage defense" % [kind, defense])
			var bounce: bool = kind == "block" and defense in ["none", "invincible"]
			check((game.velocity.y == -700) == bounce, "Actual main %s %s post-defense bounce is source-faithful" % [kind, defense])
			if defense == "maya_passive": check(near(game.invincible, 0.9), "Actual Maya passive supplies900ms without triggering block bounce")
	game.mode = "over"
	game.hearts = 0
	game.elapsed = 12.4
	course.speed = 275
	course.boost = true
	game._continue_level()
	check(game.mode == "play" and game.hearts == 3 and near(game.invincible, 2.5) and game.elapsed == 12.4 and course.speed == 275 and course.boost, "Real Continue does not reload course state or rewind level clock")
	course.hazards_tick(0, game, game.world_two)
	check(game.hearts == 3 and game.velocity.y == -700 and near(course.elapsed, 12.4), "Real Continue invulnerability bounces from block while preserving position")
	game.free()
