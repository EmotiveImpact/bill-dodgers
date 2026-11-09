extends SceneTree
const Checkout = preload("res://src/checkout_boss.gd")
const World = preload("res://src/world_two.gd")
const Combat = preload("res://src/supermarket_combat.gd")
const Abilities = preload("res://src/abilities.gd")
const Skills = preload("res://src/movement_skills.gd")

class TestWorld extends World:
	func intercept_shot(host, bullet: Dictionary) -> bool:
		return hazard_controller.intercept_shot(host, bullet) or checkout.intercept_shot(host, bullet)

class Host extends RefCounted:
	var level_id := "2-6"
	var meta := {"ground": 482}
	var level := {"w": 4900, "solids": [[-300, 4900, 482]], "plats": [], "hz": [], "waves": [], "crates": [], "fall": 742}
	var mode := "play"
	var player := Vector2(4300, 482)
	var velocity := Vector2.ZERO
	var camera := Vector2(4162, 0)
	var camera_lock = null
	var hearts := 3
	var invincible := 0.0
	var hurt_lock := 0.0
	var player_animation := "idle"
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
	var coins: Array = []
	var coin_drops: Array = []
	var pop_count := 0
	var cooldown := 0.0
	var elapsed := 0.0
	var generic_boss_calls := 0
	var boss = null
	var world_two = TestWorld.new()
	var checkout = Checkout.new()
	var combat = Combat.new()
	var abilities = Abilities.new()
	var movement_skills = Skills.new()
	func _init() -> void:
		abilities.reset("jp")
		movement_skills.reset("2-6", [])
		reset()
	func view_top() -> float: return camera.y + 540.0 - 540.0 / 1.3
	func view_width() -> float: return 738.0
	func character_height() -> float: return height
	func floor_at(x: float, y: float) -> float:
		var surface: Dictionary = world_two.below(self, x, y - 2)
		return float(surface.row[2]) if not surface.is_empty() else 482.0
	func sfx(effect: String) -> void: sounds.append(effect)
	func hurt_player(from_x: float) -> void:
		hits.append(from_x)
		if invincible > 0 or hearts <= 0 or mode != "play": return
		if movement_skills.blocks_damage() or abilities.blocks_damage(self): return
		hearts -= 1
		invincible = 1.5
		hurt_lock = 0.42
		velocity.x = -350 if player.x < from_x else 350
		player_animation = "hit"
	func add_coins(point: Vector2, count: int) -> void:
		coin_drops.append({"p": point, "count": count})
		for i in range(count): coins.append({"p": point, "v": Vector2.ZERO, "age": 0.0, "rest": false})
	func ability_inside_wall(point: Vector2) -> bool: return world_two.inside_wall(self, point)
	func ability_land_on(x: float, before: float, after: float) -> float:
		var surface: Dictionary = world_two.land_on(self, x, before, after)
		return float(surface.row[2]) if not surface.is_empty() else INF
	func ability_free_zap(point: Vector2, direction: float) -> bool:
		bullets.append({"p": point, "v": Vector2(direction * 0.1, 0), "damage": 1, "life": 20.0, "ghost": true, "enemy": false})
		return true
	func damage_boss(_amount: int) -> void: generic_boss_calls += 1
	func damage_enemy(enemy: Dictionary, amount: int) -> void: combat.damage_enemy(self, enemy, amount)
	func hit_crate(box: Dictionary, amount: int) -> void: combat.hit_crate(self, box, amount)
	func reset() -> void:
		world_two.reset(self, 106)
		checkout = world_two.checkout
		combat.reset(self, 1, 306)
	func start() -> void: checkout.ready_end(self)
	func fight(phase: int = 1) -> void:
		start()
		checkout.boss.state = "fight"
		checkout.boss.phase = phase
		checkout.boss.next = 100.0
	func tick(dt: float = 0.016) -> String: return checkout.late_tick(dt, self, world_two)
	func player_state() -> Dictionary: return checkout.players[get_instance_id()]

class PairHost extends Host:
	var roster: Array = [
		{"id": "human", "p": Vector2(4300, 482), "hearts": 3, "invincible": 0.0, "height": 180.0, "cpu": false, "grounded": true, "velocity": Vector2.ZERO},
		{"id": "friend", "p": Vector2(4350, 482), "hearts": 3, "invincible": 0.0, "height": 171.0, "cpu": true, "grounded": true, "velocity": Vector2.ZERO}]
	func combat_participants() -> Array: return roster
	func hurt_combat_participant(participant: Dictionary, from_x: float) -> void:
		hits.append(from_x)
		if participant.invincible <= 0 and participant.hearts > 0:
			participant.hearts -= 1
			participant.invincible = 1.5

var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)
func near(a: float, b: float, tolerance: float = 0.00001) -> bool: return absf(a - b) < tolerance
func shot(point: Vector2, damage: int = 99, ghost: bool = false) -> Dictionary:
	return {"p": point, "v": Vector2.ZERO, "damage": damage, "enemy": false, "life": 20.0, "ghost": ghost, "owner": {}}
func crate(point: Vector2, state: String = "ground", kind: int = 0) -> Dictionary:
	return {"p": point, "vy": 0.0, "st": state, "k": kind, "by": null}

func _initialize() -> void:
	_test_entry_and_reset()
	_test_beam_timing()
	_test_beam_body_geometry()
	_test_bags_and_protection()
	_test_crate_spawn_pickup()
	_test_crate_throw_freeze()
	_test_hit_geometry_and_floor()
	_test_phase_three_helpers_stairs()
	_test_barrier_returns()
	_test_defeat_jar()
	_test_shot_order()
	_test_shared_specials()
	_test_pair_and_cpu()
	print("Checkout puzzle: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_entry_and_reset() -> void:
	var h := Host.new()
	check(h.checkout.boss.is_empty() and h.checkout.jar.is_empty() and is_inf(h.checkout.camera_cap()), "Fresh component owns no encounter and no camera cap")
	check(not h.checkout.ready_end(h), "Checkout always rejects timed ordinary exit")
	var b: Dictionary = h.checkout.boss
	check(b.hp == 70 and b.max == 70 and b.x == 4760 and b.state == "enter", "Solo TB boots at4760 with70HP")
	check(h.boss == null and h.camera_lock == 4162, "Checkout never occupies generic boss slot and locks camera4162")
	check(b.beam == null and b.codes.is_empty() and b.dizzy == 0 and b.crates.is_empty(), "No dormant barcode/dizzy/stock-rain attacks imported")
	h.checkout.ready_end(h)
	check(is_same(b, h.checkout.boss) and h.sounds.count("warn") == 1, "Repeated end predicate cannot replace TB or replay music/warning")
	check(h.checkout.targets().is_empty(), "Entering boss adds no CPU target")
	h.player.x = 4750
	h.tick(1.4)
	check(b.state == "enter" and h.player.x == 4750 and near(b.next, 1.8), "Boot remains enter at exactly1400ms; timer and barrier skipped")
	h.tick(0.001)
	check(b.state == "fight" and b.t == 0 and near(b.next, 1.8) and h.player.x == 4750, "Boot transitions strictly after1400 and returns before fight logic")
	check(h.checkout.targets() == [4700.0], "Fighting target is source4700")
	h.tick(0.016)
	check(near(b.next, 1.784) and h.player.x == 4595, "First combat frame advances attack clock and final barrier")
	h.checkout.input_event(h)
	h.player_state().bag = 1.0
	h.player_state().crate = crate(Vector2(4200, 482))
	h.checkout.jar = {"p": Vector2(4600, 452), "v": Vector2.ZERO, "t": 0.8, "got": false}
	h.world_two.surfaces(h).append(h.checkout.receipt_step(0))
	var ordinary: Dictionary = h.world_two.surfaces(h)[0]
	h.checkout.reset(h, h.world_two)
	check(h.checkout.boss.is_empty() and h.checkout.jar.is_empty() and h.checkout.mash == 0 and not h.checkout.clear_reported, "Fresh checkout reset clears TB/jar/mash/completion latch")
	check(h.player_state().bag == 0 and h.player_state().crate == null and h.player_state().boss_hits == 0, "Fresh reset clears bag/carry/hit counters")
	check(h.world_two.surfaces(h).size() == 1 and is_same(ordinary, h.world_two.surfaces(h)[0]), "Component reset removes receipt surfaces without replacing normal geometry")
	h.world_two.hazard_controller.drop_counters[5] = 2.0
	h.reset()
	check(h.world_two.hazard_controller.drop_counters.is_empty(), "Whole-runtime fresh reset clears source leaked drop-zone counters")
	h.fight(2)
	h.player_state().bag = 1.3
	b = h.checkout.boss
	b.crates.append(crate(Vector2(4300, 482)))
	b.frozen = 3.0
	h.mode = "over"
	h.tick(4.0)
	h.checkout.input_event(h)
	check(b.frozen == 3.0 and h.player_state().bag == 1.3 and h.checkout.mash == 0, "All-down stops encounter clocks and input; state retained")
	h.hearts = 3
	h.invincible = 2.5
	h.mode = "play"
	h.tick(0.01)
	check(is_same(b, h.checkout.boss) and near(b.frozen, 2.99) and near(h.player_state().bag, 1.29), "Continue resumes same puzzle without reset")
	h.mode = "paused"
	h.tick(120)
	check(near(b.frozen, 2.99), "Pause does not fast-forward freeze")
	h.mode = "play"
	h.world_two.invalidate_run()
	h.tick(1)
	check(near(b.frozen, 2.99), "Generation invalidation rejects old checkout work")
	h.reset()
	h.fight()
	h.level_id = "2-1"
	h.tick(1)
	check(h.checkout.boss.t == 0, "Leaving stage blocks stale checkout step")

func _test_beam_timing() -> void:
	var h := Host.new()
	h.fight()
	h.invincible = 100
	var b: Dictionary = h.checkout.boss
	b.next = 0.034
	h.tick(0.034)
	check(b.beam != null and near(b.beam.t, 0.034) and b.beam.y in [448.0, 332.0], "New randomly high/low beam receives full current frame dt")
	b.beam = {"y": 448.0, "t": 0.9}
	h.invincible = 0
	h.tick(0)
	check(h.hits.is_empty(), "Beam exactly900ms is harmless")
	h.tick(0.001)
	check(h.hits.size() == 1 and h.player_state().bag == 1.5 and h.sounds.count("honk") == 1, "Beam first active frame bags and honks after900ms")
	h.player_state().bag = 0
	h.invincible = 0
	b.beam.t = 1.45
	h.tick(0)
	check(h.hits.size() == 1, "Beam exactly1450ms is harmless")
	b.beam.t = 1.6
	h.tick(0)
	check(b.beam != null and b.beams == 0, "Beam exactly1600ms is not complete")
	h.tick(0.001)
	check(b.beam == null and b.beams == 1 and near(b.next, 1.2), "Beam ends strictly after1600 and uses phase1 delay1200")
	b.beams = 2
	b.beam = {"y": 448.0, "t": 1.6}
	h.tick(0.001)
	check(b.phase == 1 and b.beams == 3 and b.crates.is_empty(), "Third beam completion cannot transition phase until following frame")
	h.tick(0.016)
	check(b.phase == 2 and b.crates.size() == 3 and near(b.next, 1.584), "Next frame starts phase2/crates and immediately deducts dt from1600 delay")
	check(b.hp == b.max, "Phase1 transition is three completed beams, not HP damage")
	for phase in [2, 3]:
		b.phase = phase
		b.beam = {"y": 448.0, "t": 1.6}
		h.tick(0.001)
		check(near(b.next, 2.6 if phase == 2 else 2.0), "Phase%d completed beam delay matches source" % phase)

func _test_beam_body_geometry() -> void:
	for height in [180.0, 162.0, 171.0, 187.0, 178.0, 160.0]:
		var h := Host.new()
		h.height = height
		h.fight()
		h.checkout.boss.beam = {"y": 332.0, "t": 0.95}
		h.tick(0)
		check((h.hits.size() == 1) == (332 > 482 - height * 0.86), "Standing high scanner uses .86 height for%s" % height)
		h.checkout.players.clear()
		h.invincible = 0
		h.hearts = 3
		h.hits.clear()
		h.crouching = true
		h.tick(0)
		check(h.hits.is_empty(), "Crouching .56 body ducks high scanner for%s" % height)
		h.checkout.boss.beam.y = 448.0
		h.tick(0)
		check(h.hits.size() == 1, "Low scanner hits even crouched%s" % height)
	var h := Host.new()
	h.fight()
	h.checkout.boss.beam = {"y": 448.0, "t": 0.95}
	h.player.y = 452
	h.tick(0)
	check(h.hits.is_empty(), "Beam equal to feet minus4 does not hit")
	h.player.y = 453
	h.player.x = 4635
	h.tick(0)
	check(h.hits.is_empty(), "Scanner excludes exact till-left x4635")
	h.player.x = 4634.999
	h.tick(0)
	check(h.hits.size() == 1, "Scanner includes x just before till-left")
	h.checkout.players.clear()
	h.hits.clear()
	h.invincible = 0
	h.hearts = 3
	h.player = Vector2(4300, 448 + h.height * 0.86)
	h.checkout.boss.beam.y = h.player.y - h.height * 0.86
	h.tick(0)
	check(h.hits.is_empty(), "Scanner excludes exact body-top y boundary")

func _test_bags_and_protection() -> void:
	var h := Host.new()
	h.fight()
	var state := h.player_state()
	h.checkout.boss.beam = {"y": 448.0, "t": 0.95}
	h.abilities.active = "maya"
	h.velocity = Vector2(400, -120)
	h.tick(0)
	check(h.hearts == 3 and state.bag == 1.5 and h.velocity == Vector2(0, -120), "Maya shield rejects health loss but scanner still bags and only zeros vx")
	h.checkout.boss.beam = null
	h.checkout.input_event(h)
	h.checkout.input_event(h)
	h.tick(0.02)
	check(near(state.bag, 1.16) and h.checkout.mash == 0, "Every global key/touch start tears160ms plus elapsed dt")
	check(near(h.hurt_lock, 0.06) and h.player_animation == "hit", "Bag loop refreshes60ms lock and hit animation")
	h.tick(0.01)
	check(near(state.bag, 1.15), "Mash counter consumes once, not every held-input frame")
	for i in range(8): h.checkout.input_event(h)
	h.tick(0)
	check(state.bag == 0 and h.hurt_lock == 0.06, "Mash release clamps bag zero but preserves final frame lock")
	h.abilities.active = ""
	h.movement_skills.slide_remaining = 0.5
	h.checkout.boss.beam = {"y": 448.0, "t": 0.95}
	h.tick(0)
	check(h.hearts == 3 and state.bag == 1.5, "Slide immunity also still permits bag application")
	state.bag = 0
	h.movement_skills.slide_remaining = 0
	h.movement_skills.dash_remaining = 0.2
	h.tick(0)
	check(h.hearts == 3 and state.bag == 1.5, "Dash immunity also still permits bag application")
	state.bag = 0
	h.invincible = 0.001
	h.tick(0)
	check(state.bag == 0, "Existing positive invulnerability blocks both hurt and bag")
	h.invincible = 0
	h.hearts = 0
	h.tick(0)
	check(state.bag == 0, "Down participant cannot be newly bagged")
	h.hearts = 1
	h.movement_skills.dash_remaining = 0
	h.player.x = 4630
	h.tick(0)
	check(h.hearts == 0 and state.bag == 1.5 and h.player.x == 4630, "Lethal scanner still assigns bag but newly down solo skips final living-player barrier")

func _test_crate_spawn_pickup() -> void:
	var h := Host.new()
	h.fight()
	var b: Dictionary = h.checkout.boss
	b.beams = 3
	h.player.x = 4300
	h.tick(0)
	check(b.crates.map(func(c): return c.p.x) == [4222.0, 4300.0, 4420.0], "Three crates use living player offset and camera+60 lower clamp")
	check(near(b.crates[0].p.y, h.view_top() - 60) and near(b.crates[1].p.y, h.view_top() - 150) and near(b.crates[2].p.y, h.view_top() - 240), "Crates begin60/150/240px above view top")
	check(b.crates.map(func(c): return c.k) == [0, 1, 2] and h.crates.is_empty(), "Boss crate kinds remain separate from breakable power-up crates")
	var c: Dictionary = b.crates[0]
	var old_y: float = c.p.y
	h.tick(0.034)
	check(near(c.vy, 85) and near(c.p.y, old_y + 85 * 0.034), "Falling crate uses source Euler gravity2500px/s²")
	c.p = Vector2(4300, 481)
	c.vy = 100
	h.tick(0.02)
	check(c.st == "ground" and c.p.y == 482 and h.player_state().crate == null, "Landing snaps ground but cannot pickup in same else-if pass")
	h.player.x = 4346
	h.tick(0)
	check(c.st == "ground", "Pickup excludes exact46px range")
	h.player = Vector2(4300, 422)
	h.tick(0)
	check(c.st == "ground", "Pickup excludes exact feet422 boundary")
	h.player.y = 422.001
	h.player_state().bag = 0.01
	h.tick(0)
	check(c.st == "ground", "Bagged player cannot pick up boss crate")
	h.player_state().bag = 0
	h.tick(0)
	check(c.st == "carry" and is_same(h.player_state().crate, c), "Walking into grounded crate picks it up without input key")
	h.tick(0)
	check(c.p == h.player - Vector2(0, h.height + 10), "Carry follows feet minus full character height minus10")
	h.hearts = 0
	h.tick(0)
	check(c.st == "ground" and c.p.y == 482 and h.player_state().crate == null, "Down carrier drops crate at ground and clears carry reference")
	check(h.hits.is_empty(), "Falling and carried boss crates have no player damage collision")
	b.phase = 3
	h.hearts = 3
	h.tick(0)
	check(c.st == "ground", "Ground boss crates pickup only in phase2")

func _test_crate_throw_freeze() -> void:
	var h := Host.new()
	h.fight(2)
	var b: Dictionary = h.checkout.boss
	for slot in range(3):
		h.player = Vector2(4335, 482)
		var c := crate(h.player)
		b.crates.append(c)
		h.tick(0)
		h.tick(0)
		check(c.st == "carry" and b.placed == slot, "Auto-throw excludes exact4335 threshold for crate%d" % slot)
		h.player.x = 4335.001
		h.tick(0)
		check(c.st == "fly" and c.t == 0 and b.placed == slot + 1 and h.player_state().crate == null, "Launch increments placed and releases ownership immediately for crate%d" % slot)
		check(c.target == [Vector2(4846, 354), Vector2(4906, 354), Vector2(4876, 292)][slot], "Crate%d uses exact authored tray position, including beyond-world4906" % slot)
		h.tick(0.325)
		check(c.st == "fly" and c.p.is_equal_approx(c.start.lerp(c.target, 0.5) - Vector2(0, 160)), "Crate%d halfway650ms flight rises160px" % slot)
		check(b.frozen == 0, "No freeze while crate%d still flying" % slot)
		h.tick(0.325)
		check(c.st == "on" and c.p.is_equal_approx(c.target), "Crate%d lands at650ms" % slot)
	check(b.placed == 3 and b.frozen == 5.0 and b.beam == null, "Third landed crate triggers five-second error and cancels beam")
	var next: float = b.next
	var spawn: float = b.spawnT
	h.player.x = 4800
	h.tick(1.0)
	check(b.frozen == 4.0 and b.next == next and b.spawnT == spawn and h.player.x == 4800, "Frozen branch skips attacks/helper timers/barrier")
	h.tick(4.0)
	check(b.frozen == 0 and b.crates.is_empty() and b.placed == 0 and b.crateT == 1.5, "Freeze expiry clears on-tray crates and schedules fresh batch1500ms")
	h.player.x = 4300
	h.tick(1.499)
	check(b.crates.is_empty(), "Replacement crates wait entire1500ms delay")
	h.tick(0.001)
	check(b.crates.size() == 3 and b.crates.all(func(c): return c.st == "fall"), "Expiry frame spawns three fresh unadvanced falling crates")
	h.tick(0.016)
	check(b.crates.size() == 3 and b.crateT == 0, "Floating-point timer residue cannot spawn a duplicate replacement batch")

func _test_hit_geometry_and_floor() -> void:
	var h := Host.new()
	h.start()
	check(not h.checkout.intercept_shot(h, shot(Vector2(4700, 200))), "Entering boss does not consume intersecting shot")
	h.fight()
	for point in [Vector2(4635, 200), Vector2(4885, 200), Vector2(4700, 122), Vector2(4700, 482)]:
		check(not h.checkout.intercept_shot(h, shot(point)), "Boss rectangle excludes strict edge%s" % point)
	for point in [Vector2(4635.01, 200), Vector2(4884.99, 200), Vector2(4700, 122.01), Vector2(4700, 481.99)]:
		check(h.checkout.intercept_shot(h, shot(point)), "Boss rectangle consumes just-inside%s" % point)
	var b: Dictionary = h.checkout.boss
	check(b.hp == 70 and near(b.bounce, 0.9) and h.sounds.count("hitBot") == 1, "Phase1 shots deal zero and throttle bounce hint900ms")
	h.tick(0.899)
	h.checkout.intercept_shot(h, shot(Vector2(4700, 200)))
	check(h.sounds.count("hitBot") == 1, "Bounce sound suppressed before900ms")
	h.tick(0.001)
	h.checkout.intercept_shot(h, shot(Vector2(4700, 200)))
	check(h.sounds.count("hitBot") == 2, "Bounce hint renews at elapsed900ms")
	b.phase = 2
	h.checkout.intercept_shot(h, shot(Vector2(4700, 200), 99999))
	check(b.hp == 70, "Unfrozen phase2 immune to arbitrary shot damage")
	b.frozen = 5.0
	var body := shot(Vector2(4700, 272), 99999)
	h.checkout.intercept_shot(h, body)
	check(b.hp == 68 and body.owner.bossHits == 1, "Frozen y272 body hit deals fixed2 and credits owner")
	var screen := shot(Vector2(4700, 271.999), 99999, true)
	h.checkout.intercept_shot(h, screen)
	check(b.hp == 65 and screen.owner.bossHits == 1, "Frozen screen ghost ignores damage multiplier and deals fixed3")
	for i in range(40): h.checkout.intercept_shot(h, shot(Vector2(4700, 200)))
	check(b.hp == 21 and near(b.frozen, 0.001) and b.state == "fight", "Phase2 floor21 prevents kill and shortens freeze to1ms")
	h.tick(0.016)
	check(b.phase == 2 and b.frozen == 0 and b.crateT == 1.5, "Phase3 threshold is checked before frozen expiry")
	h.tick(0.016)
	check(b.phase == 3 and h.enemies.size() == 2 and near(b.next, 2.484), "Following frame enters phase3 with two immediate helpers")
	b.hp = 10
	var count_before := 0
	for i in range(12):
		var body_chip := shot(Vector2(4700, 350), 99999)
		var hp_before: int = b.hp
		h.checkout.intercept_shot(h, body_chip)
		check(b.hp in [hp_before, hp_before - 1] and not body_chip.owner.has("bossHits"), "Phase3 random body hit%d deals only0or1 and earns no bossHits" % i)
		if hp_before != b.hp: count_before += 1
	check(count_before > 0 and count_before < 12, "Deterministic seeded phase3 fixture exercises both chip and bounce")
	var hp_before: int = b.hp
	h.checkout.intercept_shot(h, shot(Vector2(4700, 200), 0))
	check(b.hp == hp_before - 3, "Phase3 screen damage3 is unconditional even projectile damage0")
	b.hp = 3
	b.steps = 0
	for i in range(100):
		if b.state == "down": break
		h.checkout.intercept_shot(h, shot(Vector2(4700, 350), 9999))
	check(b.state == "down" and b.steps == 0, "Repeated random body chips can legitimately finish phase3 without receipt climb")

func _test_phase_three_helpers_stairs() -> void:
	var h := Host.new()
	h.fight(2)
	var b: Dictionary = h.checkout.boss
	b.spawnT = 11.0
	h.tick(0)
	check(h.enemies.is_empty(), "Helper timer exactly11000ms does not spawn")
	h.tick(0.001)
	check(h.enemies.size() == 1 and b.spawnT == 0 and h.enemies[0].kind == "rush", "Strictly overdue helper spawns random side rush and resets clock")
	b.spawnT = 20.0
	h.tick(0.02)
	check(h.enemies.size() == 1 and near(b.spawnT, 20.02), "Solo helper cap1 retains accumulated overdue timer")
	h.enemies[0].state = "pop"
	h.tick(0)
	check(h.enemies.size() == 2 and b.spawnT == 0, "Pop enemies do not count against helper cap")
	b.hp = 21
	b.spawnT = 7.0
	var extra := crate(Vector2(4400, 482))
	b.crates.append(extra)
	b.crates.append(crate(Vector2(4846, 354), "on"))
	h.player_state().crate = extra
	h.tick(0)
	check(b.phase == 3 and h.enemies.filter(func(e): return e.state != "pop").size() == 3, "Phase3 immediate pair ignores existing helper cap")
	check(b.spawnT == 7 and b.crates.size() == 1 and b.crates[0].st == "on" and h.player_state().crate == null, "Phase3 discards non-on crates/carry refs but does not reset helper clock")
	h.tick(0.6)
	check(b.steps == 0, "Receipt accumulator exactly600ms emits no step")
	h.tick(0.001)
	check(b.steps == 1 and b.stepT == 0 and b.mouth == 0.3, "Receipt step emits strictly after600ms and resets accumulator")
	h.tick(2.0)
	check(b.steps == 2 and b.stepT == 0, "Long isolated dt produces only one step, no catch-up loop")
	h.tick(0.601)
	check(b.steps == 3, "Exactly three receipt steps emitted")
	var steps: Array = h.world_two.surfaces(h).filter(func(s): return s.get("receipt", false))
	check(steps.map(func(s): return s.row) == [[4385.0,4475.0,412.0],[4465.0,4555.0,347.0],[4545.0,4635.0,282.0]], "All receipt surface coordinates match source")
	check(steps.all(func(s): return s.plat), "Receipt surfaces are one-way, not body walls")
	check(h.world_two.land_on(h, 4420, 400, 415).row == steps[0].row, "New step participates in shared player landing")
	check(h.world_two.below(h, 4580, 200).row == steps[2].row, "New top step participates in shared below/item/skill probe")
	check(h.world_two.wall_clamp(h, 4380, 4420, 482) == 4420 and not h.world_two.inside_wall(h, Vector2(4420, 450)), "Receipt platform never becomes solid side wall")
	var snapshot: Dictionary = h.checkout.snapshot()
	snapshot.boss.hp = -100
	snapshot.boss.crates.clear()
	check(b.hp == 21 and b.crates.size() == 1, "Painter snapshot deep-copies mutable encounter state")

func _test_barrier_returns() -> void:
	var h := Host.new()
	h.fight()
	h.player.x = 4625
	h.tick(0)
	check(h.player.x == 4625, "Final barrier excludes exact4625 threshold")
	h.player.x = 4625.001
	h.tick(0)
	check(h.player.x == 4595, "Final barrier snaps strictly beyond4625 back4595")
	h.checkout.boss.phase = 2
	h.checkout.boss.placed = 3
	h.player.x = 4800
	h.tick(0)
	check(h.player.x == 4800 and h.checkout.boss.frozen == 5, "Freeze-trigger return skips barrier in triggering frame")
	h.checkout.boss.frozen = 0.001
	h.tick(0.016)
	check(h.player.x == 4800, "Freeze-expiry return still skips barrier")
	h.checkout.boss.state = "down"
	h.tick(0)
	check(h.player.x == 4800, "Defeated return skips barrier")

func _test_defeat_jar() -> void:
	var h := Host.new()
	h.fight(3)
	var b: Dictionary = h.checkout.boss
	b.hp = 3
	b.beam = {"y": 448.0, "t": 0.1}
	b.frozen = 2.0
	b.crates.append(crate(Vector2(4400, 482)))
	h.player_state().bag = 1.0
	h.player_state().crate = b.crates[0]
	h.world_two.surfaces(h).append(h.checkout.receipt_step(0))
	h.combat.spawn(h, "l", "rush")
	h.combat.spawn(h, "r", "rush")
	h.checkout.intercept_shot(h, shot(Vector2(4700, 200)))
	check(b.state == "down" and b.t == 0 and b.beam == null and b.codes.is_empty() and b.frozen == 0, "Lethal screen hit clears active attacks/freeze and entersdown")
	check(b.crates.is_empty() and h.player_state().bag == 0 and h.player_state().crate == null, "Defeat clears all bags/carry refs/boss crates")
	check(h.coin_drops[0] == {"p": Vector2(4700, 282), "count": 20}, "Defeat drops exactly20 base coins at source location")
	check(h.enemies.all(func(e): return e.state == "pop") and h.pop_count == 0 and h.coin_drops.size() == 3, "Helpers ordinary-pop with their coin drops and no player kill credit")
	check(h.coins.size() >= 28 and h.coins.size() <= 32 and h.world_two.surfaces(h).size() == 2, "Loose helper coins remain unbanked and receipt stairs survive defeat")
	check(h.checkout.jar.is_empty() and not h.checkout.intercept_shot(h, shot(Vector2(4700, 200))), "Defeated hit does not immediately spawn jar or consume later shots")
	h.tick(1.5)
	check(h.checkout.jar.is_empty(), "Jar not spawned at exactly1500ms defeated time")
	h.tick(0.001)
	var jar: Dictionary = h.checkout.jar
	check(near(jar.t, 0.001) and jar.p.is_equal_approx(Vector2(4609.85, 261.1024)) and jar.v.is_equal_approx(Vector2(-150, -897.6)), "Jar spawns4610,262 and immediately advances using current frame delta")
	h.player = Vector2(jar.p.x, -2000)
	jar.p = Vector2(4610, 452)
	jar.v = Vector2(0, 0)
	jar.t = 0.6
	h.player.x = 4610
	check(h.tick(0) == "" and not jar.got, "Jar exactly600ms is not collectable")
	jar.t = 0.601
	h.player.x = 4660
	check(h.tick(0) == "" and not jar.got, "Jar excludes exact50px horizontal distance")
	h.player.x = 4659.999
	check(h.tick(0) == "jar_collected" and jar.got and h.checkout.clear_reported, "Jar collection ignores vertical distance and reports clear once")
	var coins_before := h.coins.size()
	check(h.tick(2) == "" and h.coins.size() == coins_before and h.mode == "play", "Component cannot double-clear/bank coins/change mode; host owns legitimate completion")
	var bounce := Host.new()
	bounce.fight(3)
	bounce.checkout.boss.state = "down"
	bounce.checkout.jar = {"p": Vector2(4700, 451), "v": Vector2(-150, 300), "t": 0.0, "got": false}
	bounce.tick(0.01)
	check(bounce.checkout.jar.p.y == 452 and near(bounce.checkout.jar.v.y, -129.6) and bounce.checkout.jar.v.x == -75, "Jar floor452 bounce uses post-gravity .4 restitution and halves vx")
	bounce.checkout.jar.p = Vector2(4700, 451.9)
	bounce.checkout.jar.v = Vector2(-75, 100)
	bounce.tick(0.001)
	check(bounce.checkout.jar.v.y == 0, "Jar settles when impact speed does not exceed200px/s")
	var stationary: Vector2 = bounce.checkout.jar.p
	bounce.tick(1)
	check(bounce.checkout.jar.p == stationary, "Settled jar stops horizontal movement despite residual vx")

func _test_shot_order() -> void:
	var h := Host.new()
	h.fight(3)
	var b: Dictionary = h.checkout.boss
	b.hp = 70
	h.enemies.append({"p": Vector2(4700, 250), "state": "walk", "hp": 10, "flash": 0.0})
	var intercepted := shot(Vector2(4700, 200), 1, true)
	h.bullets.append(intercepted)
	h.combat.projectiles_tick(0, h)
	check(b.hp == 70 and h.enemies[0].hp == 9 and intercepted.dead, "Ordinary helper intercepts ghost before TB")
	h.enemies.clear()
	h.world_two.hazard_controller.buttons.append({"x": 4700.0, "y": 200.0, "id": 5, "hit": 0.0})
	h.bullets.append(shot(Vector2(4700, 200)))
	h.combat.projectiles_tick(0, h)
	check(b.hp == 70 and h.world_two.hazard_controller.buttons[0].hit == 0.3, "Shared gate button intercepts before checkout")
	h.world_two.hazard_controller.buttons.clear()
	h.crates.append({"p": Vector2(4700, 250), "hp": 3, "broken": false, "hit": 0.0, "give": "heart"})
	var physical := shot(Vector2(4700, 200), 100)
	h.bullets.append(physical)
	h.combat.projectiles_tick(0, h)
	check(b.hp == 67 and h.crates[0].hp == 3 and physical.dead, "Physical shot hits TB before ordinary power-up crate and ignores damage100")
	var ghost := shot(Vector2(4700, 200), 100, true)
	h.bullets.append(ghost)
	h.combat.projectiles_tick(0, h)
	check(b.hp == 64 and ghost.dead and h.boss == null, "Incidental ability ghost uses same fixed3 path, no generic boss interface")
	b.state = "enter"
	h.bullets.append(shot(Vector2(4700, 200), 100, true))
	h.combat.projectiles_tick(0, h)
	check(h.crates[0].hp == 2, "Enter rejection lets ghost proceed to ordinary crate with fixed1 crate damage")

func _test_pair_and_cpu() -> void:
	var h := PairHost.new()
	h.reset()
	h.fight()
	var b: Dictionary = h.checkout.boss
	check(b.hp == 90 and b.max == 90, "Optional pair schema uses90HP even if one member CPU")
	b.beam = {"y": 448.0, "t": 0.95}
	h.tick(0)
	check(h.roster.all(func(p): return p.bag == 1.5), "Scanner bags all eligible living participants")
	h.checkout.input_event(h)
	h.tick(0.01)
	check(near(h.roster[0].bag, 1.33) and near(h.roster[1].bag, 1.49), "Global mash tears every human bag but CPU bag loses only dt")
	b.beam = null
	b.phase = 2
	b.frozen = 5.0
	for i in range(40): h.checkout.intercept_shot(h, shot(Vector2(4700, 200)))
	check(b.hp == 27, "Pair phase2 health floor is ceil90*.3=27")
	b.frozen = 0
	b.hp = 90
	b.spawnT = 12.0
	h.combat.spawn(h, "l", "rush")
	h.tick(0)
	check(h.enemies.size() == 2, "Pair helper cap allows second active helper")
	b.spawnT = 12.0
	h.tick(0)
	check(h.enemies.size() == 2 and b.spawnT == 12, "Pair helper cap2 keeps overdue timer")
	var cpu: Dictionary = h.roster[1]
	var inputs := {"left": true, "right": true, "jump": true}
	b.beam = {"y": 332.0, "t": 0.501}
	h.checkout.cpu_input(h, cpu, inputs)
	check(inputs.down and not inputs.jump and not inputs.left and not inputs.right, "CPU high tell ducks and stops movement500–1500ms")
	b.beam = {"y": 448.0, "t": 0.781}
	inputs = {}
	cpu.jump_cd = 0
	h.checkout.cpu_input(h, cpu, inputs)
	check(inputs.jump and cpu.jump_cd == 0.5, "CPU low tell jumps780–1000ms with500ms cooldown")
	b.beam = null
	b.crates = [crate(Vector2(4400, 482)), crate(Vector2(4200, 482))]
	inputs = {}
	h.checkout.cpu_input(h, cpu, inputs)
	check(inputs.right and not inputs.left, "CPU seeks nearest grounded crate")
	h.checkout.players.friend.crate = b.crates[0]
	cpu.p.x = 4350
	inputs = {}
	h.checkout.cpu_input(h, cpu, inputs)
	check(inputs.right, "Carrying CPU moves toward4375 throw destination")
	b.phase = 3
	b.steps = 3
	cpu.p = Vector2(4385, 482)
	cpu.jump_cd = 0
	inputs = {}
	h.checkout.cpu_input(h, cpu, inputs)
	check(inputs.right and inputs.jump and cpu.jump_cd == 0.45, "CPU climbs next receipt step with450ms jump cooldown")
	cpu.p = Vector2(4600, 282)
	inputs = {}
	h.checkout.cpu_input(h, cpu, inputs)
	check(not inputs.left and not inputs.right and inputs.face == 1, "CPU stops on upper receipt and faces screen")
	# An absent owner must release carry even when the owner dictionary vanished.
	b.phase = 2
	b.crates = [crate(Vector2(4300, 300), "carry")]
	b.crates[0].by = "missing"
	h.tick(0)
	check(b.crates[0].st == "ground" and b.crates[0].p.y == 482, "Missing carrier safely drops crate instead of retaining stale reference")
	b.crates = [crate(Vector2(4300, 300), "carry")]
	b.crates[0].by = "friend"
	h.checkout.players.friend.crate = b.crates[0]
	cpu.out = true
	h.tick(0)
	check(b.crates[0].st == "ground" and cpu.crate == null, "Out carrier drops even when still present in the optional roster")
	cpu.out = false
	cpu.cpu = false
	for participant in h.roster:
		h.checkout.players[participant.checkout_id].bag = 1.0
	h.checkout.input_event(h)
	h.tick(0)
	check(h.roster.all(func(p): return near(p.bag, 0.84)), "One global input tears both human bags, not just the input owner's")

func _test_shared_specials() -> void:
	for character in ["jp", "maya", "ama", "leo", "theo", "mei"]:
		var h := Host.new()
		h.fight(2)
		h.checkout.boss.frozen = 5.0
		h.player = Vector2(4700, 482)
		h.abilities.reset(character, ["super"])
		h.abilities.meter = 1.0
		h.abilities.tick(0, {"special": true}, h, true)
		check(h.abilities.active == character and h.boss == null and not h.abilities._boss_on(h), "%s special starts while checkout remains invisible to generic boss targeting" % character)
		check(h.checkout.boss.hp == 70 and h.checkout.boss.dizzy == 0 and h.generic_boss_calls == 0, "%s special does not directly damage/stun checkout" % character)
		if character == "theo":
			h.abilities.effects_tick(0, h)
			check(h.bullets.size() == 1 and h.bullets[0].ghost and h.checkout.boss.hp == 70, "Theo untargeted ball ghost queues late without direct checkout hit")
			h.combat.projectiles_tick(0, h)
			check(h.checkout.boss.hp == 68 and h.player_state().boss_hits == 1, "Following projectile pass applies fixed2 body damage to incidental ball ghost")
		elif character == "ama":
			check(h.bullets.is_empty(), "Ama cannot fabricate checkout-targeted ghost or stun")
		elif character == "maya":
			check(h.bullets.is_empty(), "Maya aura does not create checkout-targeted ghost")
		elif character == "jp":
			check(h.bullets.size() == 1 and h.bullets[0].get("ab_rain", false), "JP still generates ordinary unbiased rain projectile")
		elif character == "leo":
			check(h.bullets.size() == 1 and h.bullets[0].kind == "plane", "Leo still generates ordinary physical plane projectile")
