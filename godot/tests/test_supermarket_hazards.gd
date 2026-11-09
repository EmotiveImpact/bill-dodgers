extends SceneTree
const Hazards = preload("res://src/supermarket_hazards.gd")
const World = preload("res://src/world_two.gd")
const Combat = preload("res://src/supermarket_combat.gd")

class TestWorld extends World:
	var tested_hazards
	func intercept_shot(host, bullet: Dictionary) -> bool:
		return tested_hazards.intercept_shot(host, bullet)

class Host extends RefCounted:
	var level_id := "2-2"
	var meta := {"ground": 482}
	var level := {"solids": [[-400, 16400, 482]], "plats": [], "hz": [], "fall": 742}
	var mode := "play"
	var elapsed := 0.0
	var player_animation := "idle"
	var player := Vector2(300, 482)
	var camera := Vector2.ZERO
	var hearts := 3
	var invincible := 0.0
	var grounded := true
	var crouching := false
	var height := 180.0
	var face := 1
	var status := ""
	var sounds: Array = []
	var hits: Array = []
	var enemies: Array = []
	var bullets: Array = []
	var crates: Array = []
	var items: Array = []
	var boss = null
	var world_two = TestWorld.new()
	var hazards = Hazards.new()
	func _init() -> void: world_two.tested_hazards = hazards
	func view_top() -> float: return camera.y + 540.0 - 540.0 / 1.3
	func view_width() -> float: return 738.0
	func character_height() -> float: return height
	func sfx(effect: String) -> void: sounds.append(effect)
	func hurt_player(from_x: float) -> void:
		hits.append(from_x)
		if hearts > 0 and invincible <= 0:
			hearts -= 1
			invincible = 1.5
	func ability_inside_wall(point: Vector2) -> bool: return world_two.inside_wall(self, point)
	func reset(rows: Array = []) -> void:
		level.hz = rows
		world_two.reset(self)
		hazards.reset(self, world_two)
	func fixture(id: String = "2-2") -> void:
		level_id = id
		meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/%s.json" % id))
		level = meta.level.duplicate(true)
		world_two.reset(self)
		hazards.reset(self, world_two)
	func gates(dt: float) -> void: hazards.gates_tick(dt, self, world_two)
	func drops(dt: float) -> void: hazards.drops_tick(dt, self, world_two)

class PairHost extends Host:
	var roster: Array = [
		{"p": Vector2(1900, 482), "hearts": 3, "down": false, "grounded": true, "face": 1, "cpu": false, "height": 180.0, "crouching": false},
		{"p": Vector2(300, 482), "hearts": 3, "down": false, "grounded": true, "face": -1, "cpu": false, "height": 170.0, "crouching": false}]
	func combat_participants() -> Array: return roster
	func hurt_combat_participant(participant: Dictionary, from_x: float) -> void:
		participant.hearts -= 1
		hits.append(from_x)

var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func near(a: float, b: float, epsilon: float = 0.00001) -> bool: return absf(a - b) < epsilon

func drop(point: Vector2, top: float = 1000, age: float = 0.95, kind: String = "box") -> Dictionary:
	return {"k": "drop", "p": point, "top": top, "vy": 0.0, "warn": 0.95, "t": age, "kind": kind, "dead": false}

func shot(point: Vector2, speed: Vector2 = Vector2.ZERO) -> Dictionary:
	return {"p": point, "v": speed, "damage": 1, "enemy": false, "life": 20.0}

func _initialize() -> void:
	_test_schema_reset()
	_test_plates_gates()
	_test_buttons_order()
	_test_floor_motion()
	_test_drop_spawn()
	_test_drop_contact()
	_test_pause_continue()
	print("Supermarket hazards: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_schema_reset() -> void:
	var h := Host.new()
	h.fixture()
	var original := JSON.stringify(h.meta)
	check(h.hazards.gates.size() == 7 and h.hazards.plates.size() == 5 and h.hazards.buttons.size() == 2, "2-2 retains seven gates, five pads and two button definitions")
	check(h.hazards.gates.map(func(g): return g.x) == [2500.0, 4500.0, 6500.0, 9200.0, 9700.0, 12000.0, 14000.0], "All source gate positions retained in authored order")
	check(h.hazards.gates.all(func(g): return g.q.row == [g.x - 34, g.x + 34, -78.0] and not g.q.plat and g.q.gate == g.id), "Gates are 68px-wide non-platform solids with closed top minus78")
	check(h.world_two.surfaces(h).size() == 22 and h.world_two.surfaces(h, true).size() == 8, "All seven gate surfaces append to one ground and fourteen shelf platforms")
	check(h.hazards.buttons[0].y == 152 and h.hazards.buttons[1].y == 372, "High and low button heights are the actual authored y coordinates")
	var ground: Dictionary = h.world_two.surfaces(h)[0]
	var sentinel := {"k": "tspawn", "on": true}
	h.world_two.entities.append(sentinel)
	h.world_two.entities.append(drop(Vector2(200, 100)))
	h.hazards.drop_counters[18] = 1.1
	h.hazards.ice_velocity[1] = 310.0
	h.hazards.hinted[0] = true
	h.hazards.reset(h, h.world_two)
	check(h.world_two.surfaces(h).size() == 22 and is_same(h.world_two.surfaces(h)[0], ground), "Repeated reset replaces gate surfaces without duplicating or replacing ordinary geometry")
	check(h.world_two.entities.size() == 1 and is_same(h.world_two.entities[0], sentinel), "Component reset clears drops but preserves unrelated runtime entities by reference")
	check(h.hazards.drop_counters.is_empty() and h.hazards.ice_velocity.is_empty() and h.hazards.hinted.is_empty(), "Fresh reset clears leaked source counters, per-player momentum and one-shot hints")
	check(h.hazards.gates.all(func(g): return g.open == 0 and g.timer == 0 and not g.held), "Fresh reset restores all closed gate states")
	h.hazards.hazards[0][1] = -999
	check(JSON.stringify(h.meta) == original and h.world_two.hazards[0][1] != -999, "Component owns deeply copied authored schema and leaves source/runtime metadata untouched")
	for stage in ["2-3", "2-4", "2-5", "2-6", "2-S"]:
		h.fixture(stage)
		check(h.hazards.hazards == h.level.hz, "%s later schemas retained without a component completion API" % stage)

func _test_plates_gates() -> void:
	var h := Host.new()
	h.reset([["gate", 2500, 482, 560, 0], ["plate", 1900, 482, 0]])
	var gate: Dictionary = h.hazards.gates[0]
	h.player = Vector2(1946, 482)
	h.gates(0.01)
	check(not gate.held, "Plate excludes exact46px horizontal edge")
	h.player = Vector2(1854, 482)
	h.gates(0)
	check(not gate.held, "Plate excludes both horizontal edges")
	h.player = Vector2(1900, 488)
	h.gates(0)
	check(not gate.held, "Plate excludes exact6px feet tolerance")
	h.player = Vector2(1900, 476)
	h.gates(0)
	check(not gate.held, "Plate excludes negative6px feet tolerance")
	h.player.y = 482
	h.grounded = false
	h.gates(0)
	check(not gate.held, "Airborne feet over pad do not hold shelf")
	h.grounded = true
	h.hearts = 0
	h.gates(0)
	check(not gate.held, "Down solo player cannot hold shelf")
	h.hearts = 3
	h.gates(0.209)
	check(gate.held and near(gate.timer, 5.2) and near(gate.open, 0.55), "Solo pad refreshes5200ms without decrement and opens209/380")
	check(gate.q.row[2] == -78, "Exactly55percent open keeps solid collider")
	check(h.world_two.wall_clamp(h, 2400, 2500, 482) == 2452, "Closed shared gate participates in side-wall clamp")
	check(h.world_two.inside_wall(h, Vector2(2500, 100)) and h.world_two.below(h, 2500, -100).row[2] == -78, "Closed gate participates in inside-wall and highest-support queries")
	check(h.world_two.land_on(h, 2500, -80, -77).row[2] == -78, "Closed gate participates in dynamic landing queries")
	h.gates(0.0001)
	check(gate.q.row[2] == 5482 and h.world_two.wall_clamp(h, 2400, 2500, 482) == 2500, "Strictly beyond55percent moves shared collider below world and releases side-wall")
	check(not h.world_two.inside_wall(h, Vector2(2500, 100)) and h.world_two.below(h, 2500, -100).row[2] == 482, "Opening immediately changes all runtime geometry queries")
	check(h.sounds.count("select") == 1 and h.sounds.count("power") == 1, "Held pad does not retrigger transition sounds every frame")
	h.gates(1)
	check(gate.open == 1 and near(gate.timer, 5.2), "Held gate fully opens and refreshes hold timer")
	h.player = Vector2(2800, 482)
	h.gates(5.2)
	check(gate.timer == 0 and gate.open == 0, "Released gate decrements before want calculation and can close on expiry frame")
	gate.open = 0.5
	h.player = Vector2(2500, -900)
	h.gates(0.01)
	check(gate.open < 0.5, "Occupancy does not rescue a gate at exactlyhalf-open")
	gate.open = 0.5001
	h.gates(0.01)
	check(gate.open > 0.5001, "Strictly-more-than-half-open shelf stays open for occupied x regardless of height")
	gate.open = 0
	h.gates(0.01)
	check(gate.open == 0, "A closed gate does not open just because a player overlaps it")
	for x in [2440.0, 2560.0]:
		gate.open = 0.8
		h.player.x = x
		h.gates(0.01)
		check(gate.open < 0.8, "Occupancy excludes exact60px gate boundary %s" % x)
	h.player.x = 2559.9
	gate.open = 0.56
	h.gates(0.01)
	check(gate.open > 0.56, "Interior occupied shelf stays open while timer remains zero")
	var pair := PairHost.new()
	pair.reset([["gate", 2500, 482, 560, 0], ["plate", 1900, 482, 0]])
	pair.gates(0.02)
	check(near(pair.hazards.gates[0].timer, 2.6), "Two human participants use2600ms pad grace")
	pair.roster[1].cpu = true
	pair.gates(0)
	check(near(pair.hazards.gates[0].timer, 5.2), "CPU mate changes grace to5200ms")
	pair.roster[0].down = true
	pair.gates(0.02)
	check(not pair.hazards.gates[0].held, "Down participant cannot press pad")

func _test_buttons_order() -> void:
	var h := Host.new()
	h.fixture()
	var gate: Dictionary = h.hazards.gates[1]
	for point in [Vector2(4400, 152), Vector2(4340, 152), Vector2(4370, 122), Vector2(4370, 182)]:
		check(not h.hazards.intercept_shot(h, shot(point)), "Button excludes exact30px boundary %s" % point)
	check(not h.hazards.intercept_shot(h, shot(Vector2(4370, 372))), "Ground-height shot cannot activate high button")
	check(h.hazards.intercept_shot(h, shot(Vector2(4399.9, 181.9))), "High button accepts shot strictly inside both axes")
	check(near(gate.timer, 6.5) and gate.open == 0 and gate.q.row[2] == -78 and near(h.hazards.buttons[0].hit, 0.3), "Shot sets6500ms timer and300ms flash but leaves collider closed until late gate phase")
	h.gates(0.034)
	check(near(gate.timer, 6.466) and near(h.hazards.buttons[0].hit, 0.266) and gate.open > 0, "Late gate phase decrements shot timer and flash in same frame")
	gate.timer = 9
	h.hazards.intercept_shot(h, shot(Vector2(4370, 152)))
	check(gate.timer == 9, "Repeated button shot never shortens an existing longer timer")
	check(h.hazards.intercept_shot(h, {"p": Vector2(11650, 372), "ghost": true}) and near(h.hazards.gates[5].timer, 6.5), "Low button and source-shaped ghost shot use the same point interception")
	check(h.hazards.gates[0].timer == 0 and h.hazards.gates[6].timer == 0, "Buttons raise only gates sharing their id")
	h.player = Vector2(4300, 482)
	h.gates(0)
	check(h.status == "Climb the shelf, shoot the button!", "High shelf hint uses button height below floor minus200")
	h.player = Vector2(11750, 482)
	h.gates(0)
	check(h.status == "Shoot the green button!", "Low button uses ground-accessible hint")
	# Actual shared combat path establishes enemy -> button -> crate -> wall.
	h.reset([["gate", 500, 482, 560, 1], ["button", 500, 372, 1]])
	h.player = Vector2(300, 482)
	h.enemies = [{"p": Vector2(500, 482), "state": "walk", "hp": 3, "flash": 0.0, "hh": 180}]
	h.crates = [{"p": Vector2(500, 400), "hp": 3, "broken": false, "hit": 0.0, "give": "heart"}]
	h.bullets = [shot(Vector2(500, 372))]
	var combat := Combat.new()
	combat.projectiles_tick(0, h)
	check(h.enemies[0].hp == 2 and h.hazards.gates[0].timer == 0 and h.crates[0].hp == 3, "Actual projectile phase consumes bot hit before overlapping shelf button and crate")
	h.enemies.clear()
	h.bullets = [shot(Vector2(500, 372))]
	combat.projectiles_tick(0, h)
	check(near(h.hazards.gates[0].timer, 6.5) and h.crates[0].hp == 3 and h.bullets.is_empty(), "Button intercepts before crate and closed-gate wall cleanup")
	h.bullets = [shot(Vector2(500, 300))]
	combat.projectiles_tick(0, h)
	check(h.bullets.is_empty(), "Closed gate solid removes a non-button projectile")
	h.gates(0.21)
	h.bullets = [shot(Vector2(500, 300))]
	combat.projectiles_tick(0, h)
	check(h.bullets.size() == 1, "Open gate shared surface also releases projectile wall cleanup")
	h.bullets = [shot(Vector2(450, 372), Vector2(1000, 0))]
	h.hazards.gates[0].timer = 0
	combat.projectiles_tick(0.1, h)
	check(h.hazards.gates[0].timer == 0, "Button interception is final-point overlap, not a newly invented swept ray")

func _test_floor_motion() -> void:
	var h := Host.new()
	h.reset([["ice", 100, 500, 482]])
	h.player = Vector2(300, 482)
	var key := h.get_instance_id()
	check(near(h.hazards.base_displacement(0.09, h, 1), 24.66) and near(h.hazards.ice_velocity[key], 274), "First ice frame starts from normal270 and blends toward310 with dt/900ms")
	check(near(h.hazards.base_displacement(0.9, h, 1), 279) and near(h.hazards.ice_velocity[key], 310), "Ice blend saturates at target speed for dt at least900ms")
	check(near(h.hazards.base_displacement(0.09, h, 0), 25.11), "Releasing move on grounded ice retains momentum and eases to zero")
	h.hazards.ice_velocity[key] = 310.0
	h.grounded = false
	h.player.x = 700
	check(near(h.hazards.base_displacement(0.1, h, 1), 30.2), "Leaving ice airborne eases faster310 momentum toward270 over500ms")
	h.hazards.ice_velocity[key] = 310.0
	check(near(h.hazards.base_displacement(0.1, h, -1), 19.4), "Airborne opposite input retains signed momentum while easing toward minus270")
	h.hazards.ice_velocity[key] = 270.0
	check(near(h.hazards.base_displacement(0.1, h, -1), -27), "Equal absolute airborne speed does not take retained-momentum branch")
	h.hazards.ice_velocity[key] = 100.0
	check(near(h.hazards.base_displacement(0.1, h, 1), 27), "Slower airborne momentum is replaced by normal speed")
	h.grounded = true
	for point in [Vector2(100, 482), Vector2(500, 482), Vector2(300, 486), Vector2(300, 478)]:
		h.player = point
		h.hazards.ice_velocity[key] = 310.0
		check(near(h.hazards.base_displacement(0.1, h, 1), 27), "Ice excludes strict zone/tolerance boundary %s" % point)
	h.reset([["slow", 100, 500, 482]])
	h.player = Vector2(300, 482)
	h.grounded = false
	check(near(h.hazards.base_displacement(0.1, h, 1), 14.85), "Flour slows base velocity even while airborne within feet tolerance")
	h.reset([["ice", 100, 500, 0]])
	h.grounded = true
	check(near(h.hazards.base_displacement(0.9, h, 1), 279), "Falsy authored ice top uses ground482 source fallback")
	h.reset([["ice", 100, 500, 482], ["slow", 100, 500, 482], ["belt", 100, 500, 482, 0.08], ["belt", 100, 500, 482, -0.03]])
	check(near(h.hazards.base_displacement(0.9, h, 1), 324), "Overlapping ice target remains310 despite flour; additive belts apply after ice")
	check(near(h.hazards.ice_velocity[key], 310), "Belt displacement never becomes retained ice velocity")
	h.reset([["belt", 100, 500, 482, 0.08]])
	check(near(h.hazards.base_displacement(0.1, h, 1), 35), "Grounded belt adds authored80px/s to base walking displacement")
	check(near(h.hazards.base_displacement(0.1, h, 0), 8), "Belt carries grounded idle player")
	h.grounded = false
	check(h.hazards.base_displacement(0.1, h, 0) == 0, "Airborne player is not carried by belt even at matching height")
	h.grounded = true
	for point in [Vector2(100, 482), Vector2(500, 482), Vector2(300, 486)]:
		h.player = point
		check(h.hazards.base_displacement(0.1, h, 0) == 0, "Belt uses strict x and feet bounds %s" % point)
	var pair := PairHost.new()
	pair.reset([["ice", 100, 500, 482]])
	pair.roster[0].p.x = 300
	pair.roster[1].p.x = 300
	pair.hazards.participant_displacement(0.9, pair, 1, pair.roster[0], "leader")
	pair.hazards.participant_displacement(0.9, pair, -1, pair.roster[1], "mate")
	check(pair.hazards.ice_velocity.leader == 310 and pair.hazards.ice_velocity.mate == -310, "Each stable participant identity retains independent ice direction and velocity")
	pair.roster[0].grounded = false
	pair.hazards.participant_displacement(0.1, pair, 0, pair.roster[0], "leader")
	check(near(pair.hazards.ice_velocity.leader, 248) and pair.hazards.ice_velocity.mate == -310, "One participant airborne update cannot alter another participant momentum")

func _test_drop_spawn() -> void:
	var h := Host.new()
	h.reset([["drops", 100, 500, 1700, "box"]])
	h.player.x = 100
	h.drops(9)
	check(h.hazards.drop_counters.is_empty() and h.world_two.entities.is_empty(), "Drop zone ignores exactleft boundary without accruing time")
	h.player.x = 500
	h.drops(9)
	check(h.hazards.drop_counters.is_empty(), "Drop zone ignores exactright boundary")
	h.player.x = 300
	h.hearts = 0
	h.drops(9)
	check(h.hazards.drop_counters.is_empty(), "Empty living roster never accrues drop interval")
	h.hearts = 3
	h.drops(1.2)
	check(near(h.hazards.drop_counters[0], 1.2) and h.world_two.entities.is_empty(), "Occupied zone accrues without early spawn")
	h.player.x = 600
	h.drops(30)
	check(near(h.hazards.drop_counters[0], 1.2), "Leaving zone pauses rather than resets accumulator")
	h.player.x = 300
	h.drops(0.499)
	check(h.world_two.entities.is_empty(), "Spawn remains pending at1699ms occupied time")
	var predictor := RandomNumberGenerator.new()
	predictor.state = h.world_two.rng.state
	predictor.randf() # Target choice consumes a draw even for solo.
	var expected_x := 300 + (predictor.randf() - 0.4) * 160 + 60
	h.drops(0.001)
	var entity: Dictionary = h.world_two.entities[0]
	check(h.hazards.drop_counters[0] == 0 and entity.k == "drop" and entity.kind == "box", "Exact1700ms emits one box and resets interval")
	check(near(entity.p.x, expected_x, 0.0001) and near(entity.p.y, h.view_top() - 80) and entity.top == 482 and near(entity.t, 0.001), "Spawn consumes choice+x draws, faces ahead, starts viewTop minus80 and ages in spawn frame")
	check(h.world_two.rng.state == predictor.state, "Drop spawn consumes exactlytwo gameplay RNG draws and no visual RNG")
	h.drops(0.948)
	check(near(entity.t, 0.949) and entity.vy == 0, "Drop remains motionless during949ms warning")
	h.drops(0.001)
	check(near(entity.t, 0.95) and near(entity.vy, 3.2) and near(entity.p.y, h.view_top() - 80 + 0.0032, 0.00002), "At950ms warning expiry gravity consumes the full current timestep")
	h.drops(0.1)
	check(near(entity.vy, 323.2), "Falling stock uses3200px/s² gravity")
	h.reset([["drops", 100, 500, 1700, "icicle"]])
	h.drops(10)
	check(h.world_two.entities.size() == 1 and h.world_two.entities[0].kind == "icicle" and h.world_two.entities[0].dead, "Huge step makes one icicle attempt, then updates and impacts it without catch-up")
	check(h.hazards.drop_counters[0] == 0 and h.sounds.back() == "stomp", "Impact sound occurs at landing; dead removal remains owner's later phase")
	h.world_two.entities.clear()
	h.level.solids = []
	h.reset([["drops", 100, 500, 1700, "box"]])
	var before_state: int = h.world_two.rng.state
	h.drops(1.7)
	check(h.world_two.entities.is_empty() and h.hazards.drop_counters[0] == 0 and h.world_two.rng.state != before_state, "Unsupported drop still consumes attempt, interval and RNG")
	h.level.solids = [[-400, 16400, 482]]
	h.level.plats = [[100, 600, 180], [100, 600, 100]]
	h.reset([["drops", 100, 500, 1, "box"]])
	h.drops(0.001)
	check(h.world_two.entities[0].top == 180, "Drop landing query begins at targetfeet minus300 with inclusive2px tolerance")
	h.world_two.surfaces(h)[1].row[2] = 900
	check(h.world_two.entities[0].top == 180, "Drop stores landing top once; later surface changes do not retarget it")
	h.level.plats.clear()
	h.reset([["drops", 100, 500, 1]])
	h.face = -1
	h.drops(0.001)
	check(h.world_two.entities[0].kind == "box" and h.world_two.entities[0].p.x >= 176 and h.world_two.entities[0].p.x <= 336, "Missing dropkind defaults to box and left-facing spawn bias is minus60")
	var pair := PairHost.new()
	pair.reset([["drops", 100, 500, 1, "box"]])
	pair.roster[0].p.x = 300
	pair.roster[0].down = true
	pair.roster[1].p.x = 400
	pair.drops(0.001)
	check(pair.world_two.entities[0].p.x >= 276 and pair.world_two.entities[0].p.x <= 436, "Drop target choice includes only living in-zone participants and uses their facing")

func _test_drop_contact() -> void:
	var h := Host.new()
	# Exact representable thresholds isolate strict comparisons from Vector2's
	# float32 storage (180*.86 produces a non-representable327.2 body top).
	h.height = 200
	h.reset()
	h.player = Vector2(300, 482)
	var entity := drop(Vector2(334, 400))
	h.world_two.entities = [entity]
	h.drops(0)
	check(h.hits.is_empty() and not entity.dead, "Drop hit excludes exact34horizontal edge")
	entity.p.x = 333.9
	entity.p.y = h.player.y - h.character_height() * 0.86
	h.drops(0)
	check(h.hits.is_empty(), "Drop hit excludes exact standing bodytop boundary")
	entity.p.y = 542
	h.drops(0)
	check(h.hits.is_empty(), "Drop hit excludes exactbottom minus60 equalsfeet boundary")
	entity.p.y = 541.9
	h.drops(0)
	check(h.hearts == 2 and entity.dead and h.hits.size() == 1, "Drop hits inside strict60px vertical extent and marks itself dead")
	h.hits.clear()
	h.invincible = 9
	entity = drop(Vector2(300, 400))
	h.world_two.entities = [entity]
	h.drops(0)
	check(entity.dead and h.hearts == 2 and h.hits.size() == 1, "Invulnerability suppresses heartloss but still consumes contacting drop")
	h.invincible = 0
	h.hits.clear()
	h.crouching = true
	entity = drop(Vector2(300, 350))
	h.world_two.entities = [entity]
	h.drops(0)
	check(not entity.dead and h.hits.is_empty(), "Crouching narrows damage body to56percent source characterheight")
	entity.p.y = 382
	h.drops(0)
	check(entity.dead and h.hearts == 1, "Crouched drop collision starts just below reduced bodytop")
	h.hits.clear()
	entity = drop(Vector2(300, 400), 1000, 0.949)
	h.world_two.entities = [entity]
	h.drops(0)
	check(not entity.dead and h.hits.is_empty(), "Warning phase cannot harm even when positioned inside player")
	h.player.x = 0
	entity = drop(Vector2(700, 481.9), 482)
	h.world_two.entities = [entity]
	h.drops(0)
	check(not entity.dead, "Drop survives just before stored landingtop")
	entity.p.y = 482
	h.drops(0)
	check(entity.dead and h.sounds.back() == "stomp", "Impact occurs at inclusive stored landingtop")
	var pair := PairHost.new()
	pair.reset()
	pair.roster[0].p = Vector2(300, 482)
	pair.roster[1].p = Vector2(300, 482)
	pair.world_two.entities = [drop(Vector2(300, 400))]
	pair.drops(0)
	check(pair.roster[0].hearts == 2 and pair.roster[1].hearts == 2, "Source contact loop can hit multiple overlapping living participants before late removal")

func _test_pause_continue() -> void:
	var h := Host.new()
	h.reset([["gate", 500, 482, 560, 0], ["button", 400, 372, 0], ["ice", 100, 500, 482], ["drops", 100, 500, 1700, "box"]])
	h.hazards.intercept_shot(h, shot(Vector2(400, 372)))
	h.gates(0.2)
	h.drops(0.5)
	h.hazards.base_displacement(0.4, h, 1)
	h.world_two.entities.append(drop(Vector2(700, 100), 482, 0.3))
	var gate_before: Dictionary = h.hazards.gates[0].duplicate(true)
	var counters: Dictionary = h.hazards.drop_counters.duplicate()
	var velocities: Dictionary = h.hazards.ice_velocity.duplicate()
	var entities: Array = h.world_two.entities.duplicate(true)
	h.mode = "paused"
	h.gates(30)
	h.drops(30)
	check(h.hazards.base_displacement(30, h, 1) == 0 and not h.hazards.intercept_shot(h, shot(Vector2(400, 372))), "Paused component rejects movement and shot activation")
	check(h.hazards.gates[0] == gate_before and h.hazards.drop_counters == counters and h.hazards.ice_velocity == velocities and h.world_two.entities == entities, "Pause freezes timers, drops, gate collider and retained momentum")
	h.mode = "over"
	h.hearts = 0
	h.gates(30)
	h.drops(30)
	h.hearts = 3
	h.invincible = 2.5
	h.mode = "play"
	check(h.hazards.gates[0] == gate_before and h.hazards.drop_counters == counters and h.hazards.ice_velocity == velocities and h.world_two.entities == entities, "Continue preserves entire shared hazard state and counters without reset")
	h.gates(0.01)
	h.drops(0.01)
	check(near(h.hazards.gates[0].timer, gate_before.timer - 0.01) and near(h.hazards.drop_counters[3], 0.51), "After Continue simulation resumes from retained exact timers")
	h.world_two.invalidate_run()
	gate_before = h.hazards.gates[0].duplicate(true)
	h.gates(1)
	h.drops(1)
	check(h.hazards.gates[0] == gate_before and h.hazards.base_displacement(1, h, 1) == 0, "Invalidated runtime generation cannot advance a stale component")
	h.reset([["gate", 500, 482, 560, 0]])
	check(h.hazards.drop_counters.is_empty() and h.hazards.ice_velocity.is_empty() and h.world_two.entities.is_empty() and h.hazards.gates[0].timer == 0, "Fresh run differs from Continue by resetting hazards and transient state")
	h.hazards.gates[0].timer = 1
	h.level_id = "1-1"
	h.gates(1)
	check(h.hazards.gates[0].timer == 1, "Stage mismatch rejects stale hazard tick even before runtime invalidation")
