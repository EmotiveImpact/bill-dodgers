extends SceneTree
const Combat = preload("res://src/festival_combat.gd")
const Abilities = preload("res://src/abilities.gd")

class Runtime extends RefCounted:
	var additional: Array = []
	var tents: Array = []
	var trailer: Dictionary = {}
	var cam_dx := 0.0
	var level_time := 0.0
	var tied := 0.0
	var events: Array = []
	func surfaces(host) -> Array:
		var rows: Array = []
		for row in host.level.solids: rows.append({"row": row, "plat": false})
		for row in host.level.plats: rows.append({"row": row, "plat": true})
		return rows + additional
	func below(host, x: float, y: float) -> Dictionary:
		var best: Dictionary = {}
		for surface in surfaces(host):
			var row: Array = surface.row
			if x < row[0] or x > row[1] or row[2] < y - 2: continue
			if best.is_empty() or row[2] < best.row[2]: best = surface
		return best
	func set_tied(_host, participant: Dictionary, value: float) -> void:
		if participant.get("host_player", false): tied = value
		else: participant.tied = value
	func boss_event(_host, event: Dictionary) -> void: events.append(event)

class AbilityStub extends RefCounted:
	func enemy_is_bubbled(enemy: Dictionary) -> bool: return float(enemy.get("ab_bubble", 0)) > 0

class Host extends RefCounted:
	var meta := {"l3": {"waves": []}, "ground": 482}
	var grounded := true
	var velocity := Vector2.ZERO
	var invincible := false
	var level := {"w": 16000, "fall": 742, "solids": [[-400, 16400, 482]], "plats": [], "waves": [], "crates": []}
	var player := Vector2(300, 482)
	var camera := Vector2.ZERO
	var camera_lock: Variant = null
	var status := ""
	var enemies: Array = []
	var bullets: Array = []
	var coins: Array = []
	var items: Array = []
	var crates: Array = []
	var boss = null
	var abilities = AbilityStub.new()
	var world_three = Runtime.new()
	var hearts := 3
	var crouching := false
	var score := 0
	var pop_count := 0
	var power := ""
	var power_time := 0.0
	var hits: Array = []
	var drops: Array = []
	var sounds: Array = []
	func view_width() -> float: return 738.0
	func view_top() -> float: return camera.y + 540.0 - 540.0 / 1.3
	func character_height() -> float: return 180.0
	func sfx(key: String) -> void: sounds.append(key)
	func hurt_player(from_x: float) -> void:
		hits.append(from_x)
		if not invincible: hearts = maxi(0, hearts - 1)
	func add_coins(position: Vector2, count: int) -> void: drops.append({"p": position, "count": count})
	func floor_at(x: float, y: float) -> float:
		var found := INF
		for surface in world_three.surfaces(self):
			var row: Array = surface.row
			if x >= row[0] and x <= row[1] and row[2] >= y - 2: found = minf(found, row[2])
		return found
	func _land(x: float, old_y: float, new_y: float) -> float:
		var found := INF
		for surface in world_three.surfaces(self):
			var row: Array = surface.row
			if x >= row[0] and x <= row[1] and row[2] >= old_y - 1 and row[2] <= new_y + 0.5: found = minf(found, row[2])
		return found
	func ability_inside_wall(point: Vector2) -> bool:
		for surface in world_three.surfaces(self):
			var row: Array = surface.row
			if not surface.plat and point.x > row[0] and point.x < row[1] and point.y > row[2] + 4: return true
		return false

class PairHost extends Host:
	var roster: Array = [{"p": Vector2(300, 300), "hearts": 3, "down": false, "height": 180.0, "crouching": false}, {"p": Vector2(500, 482), "hearts": 3, "down": false, "height": 170.0, "crouching": false}]
	func combat_participants() -> Array: return roster
	func hurt_combat_participant(record: Dictionary, from_x: float) -> void:
		record.hearts -= 1
		hits.append(from_x)

class AbilityHost extends Host:
	var face := 1
	var cooldown := 0.3
	func _zap(point: Vector2, damage: int, direction: float = 1) -> void:
		bullets.append({"p": point, "v": Vector2(direction * 0.1, 0), "life": 20.0, "ghost": true, "ghost_age": 0.0, "enemy": false, "damage": damage})
	func damage_enemy(enemy: Dictionary, damage: int) -> void: _zap(enemy.p - Vector2(0, 56), damage)
	func damage_boss(damage: int) -> void: _zap(Vector2(boss.state.x, boss.state.fy - 120), damage)
	func hit_crate(crate: Dictionary, damage: int) -> void: _zap(crate.p - Vector2(0, 30), damage)
	func ability_free_zap(point: Vector2, direction: float) -> bool:
		_zap(point, 1, direction if direction != 0 else 1)
		return true

var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func shot(point: Vector2, velocity: Vector2 = Vector2.ZERO, damage: int = 1, hostile: bool = false) -> Dictionary:
	return {"p": point, "v": velocity, "damage": damage, "enemy": hostile, "life": 20.0}

func coin(point: Vector2, age: float = 0.3) -> Dictionary:
	return {"p": point, "v": Vector2.ZERO, "age": age, "rest": true}

func spawn_one(combat, host, kind: String = "rush", x: float = 500) -> Dictionary:
	return combat.new_bot(host, x, {"row": [-400, 16400, 482], "plat": false}, kind, {"entered": true})

func _initialize() -> void:
	_test_waves()
	_test_spawns()
	_test_tents()
	_test_hook_order()
	_test_carriers()
	_test_projectiles()
	_test_pickups()
	_test_boss_adapter()
	_test_actual_abilities()
	_test_hop_contact_order()
	_test_boss_participant_snapshot()
	print("Festival combat: ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

func _test_waves() -> void:
	var c = Combat.new()
	var h = Host.new()
	var counts := [[10, 47, 58], [15, 51, 66], [10, 48, 65], [9, 31, 40], [16, 39, 62], [3, 10, 13], [0, 0, 0]]
	var ids := ["3-1", "3-2", "3-3", "3-4", "3-5", "3-6", "3-S"]
	for i in ids.size():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/" + ids[i] + ".json"))
		h.level = data.level.duplicate(true)
		h.meta = data.duplicate(true)
		var original: Dictionary = h.meta.duplicate(true)
		for participants in [1, 2]:
			c.reset(h, participants)
			var entries := 0
			for wave in c.waves: entries += wave.group.size()
			check(c.waves.size() == counts[i][0], ids[i] + " authored wave count")
			check(entries == counts[i][participants], ids[i] + " participant-filtered group count " + str(participants))
		check(h.meta == original, ids[i] + " source META remains immutable")
	h = Host.new()
	h.meta.l3.waves = [[500, [[0, "r", "rush"], [100, "r", "throw", 1], [200, "l", "flat"]]]]
	c.reset(h)
	h.camera.x = 497.999
	c.waves_tick(0, h)
	check(not c.waves[0].started, "Wave starts only at at-minus-two")
	h.camera.x = 498
	c.waves_tick(0, h)
	check(c.waves[0].started and c.waves[0].index == 1 and h.camera_lock == 538, "Start spawns zero entry and locks forty pixels ahead")
	c.waves_tick(0.2, h)
	check(c.waves[0].index == 2 and not c.waves[0].done, "Solo filters fourth flag and waits for all live bots")
	for enemy in h.enemies: enemy.state = "pop"
	c.waves_tick(0, h)
	check(c.waves[0].done and h.camera_lock == null, "Popped bots unblock next waves phase")
	h.enemies.clear()
	h.level.auto = 0.2
	c.reset(h)
	c.waves_tick(0.2, h)
	check(c.waves[0].done and h.enemies.size() == 2 and h.camera_lock == null, "Auto wave completes with live bots after last dispatch")
	h.level.erase("auto")
	c.reset(h)
	h.boss = RefCounted.new()
	h.camera_lock = 99
	c.waves_tick(0.2, h)
	check(h.camera_lock == 99, "Waves never replace active boss camera lock")
	for enemy in h.enemies: enemy.state = "pop"
	c.waves_tick(0, h)
	check(h.camera_lock == 99, "Wave completion retains boss lock")
	h.boss = null
	h.enemies.clear()
	h.level.solids = []
	c.reset(h)
	c.waves_tick(0.2, h)
	check(c.waves[0].done and h.enemies.is_empty(), "Failed spawn consumes entry without invented bots")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/3-2.json"))
	h.meta = data
	h.level = data.level
	c.reset(h, 2)
	c.waves = [c.waves[8]]
	h.camera.x = 16100
	c.waves_tick(1.7, h)
	check(c.waves[0].index == 3, "Unsorted late400ms entry waits behind2300ms co-op entry")
	c.waves_tick(0.6, h)
	check(c.waves[0].index == 7 and c.waves[0].done, "Co-op2300ms consumes authored unsorted tail without sorting")

func _test_spawns() -> void:
	var c = Combat.new()
	var h = Host.new()
	c.reset(h, 1, 123)
	c.spawn(h, "r", "rush")
	var enemy: Dictionary = h.enemies.back()
	check(enemy.p == Vector2(808, 482) and enemy.face == -1 and enemy.hp == 3, "Ordinary right rush defaults")
	check(enemy.speed >= 99 and enemy.speed <= 126.5 and enemy.stop == 0, "Rush speed and pursuit")
	c.spawn(h, "l", "flat")
	enemy = h.enemies.back()
	check(enemy.p.x == -70 and enemy.face == 1 and enemy.hp == 4, "Left flat defaults")
	check(enemy.cd >= 0.9 and enemy.cd <= 1.8 and enemy.stop >= 230 and enemy.stop <= 400, "Flat timer and spacing ranges")
	h.enemies.clear()
	h.level.solids = []
	h.level.plats = [[0, 1000, 482, {"nospawn": true}]]
	c.spawn(h, "r", "rush")
	check(h.enemies.is_empty(), "nospawn platform is rejected")
	h.level.plats = [[700, 960, 482]]
	c.spawn(h, "r", "rush")
	check(h.enemies.is_empty(), "Exactly260px platform rejected")
	h.level.plats = [[700, 961, 482]]
	c.spawn(h, "r", "rush")
	check(h.enemies.size() == 1 and enemy.hp == 4, "261px platform allowed, unlike W2")
	h.enemies.clear()
	h.level.plats = []
	h.level.solids = [[0, 1000, 600]]
	c.spawn(h, "r", "rush")
	check(h.enemies.is_empty(), "Bottom view boundary600 is excluded")
	h.level.solids = [[0, 1000, h.view_top() + 120]]
	c.spawn(h, "r", "rush")
	check(h.enemies.is_empty(), "Top view boundary is excluded")
	h.level.solids = [[0, 750, 482]]
	c.spawn(h, "r", "rush")
	check(h.enemies.back().p.x == 712, "Placement scans inward24px until strict edge margin passes")
	var pair = PairHost.new()
	pair.level.solids = [[-400, 1000, 300], [-400, 1000, 482]]
	pair.roster[0].p.y = 300
	pair.roster[1].p.y = 400
	c.spawn(pair, "r", "rush")
	check(pair.enemies.back().p.y == 300, "Spawn floor nearest mean living feet, stable ties")

func _test_tents() -> void:
	var c = Combat.new()
	var h = Host.new()
	c.reset(h)
	h.world_three.tents = [{"x": 490.0, "y": 482.0, "shake": 0.0}, {"x": 560.0, "y": 482.0, "shake": 0.0}, {"x": 680.0, "y": 482.0, "shake": 0.0}]
	c.spawn(h, "t", "throw")
	var enemy: Dictionary = h.enemies.back()
	check(enemy.p.x == 560 and enemy.rise == 0.5 and enemy.entered and enemy.face == -1, "Tent nearest front+260 selected, rise500ms")
	check(h.world_three.tents[1].shake == 0.5, "Emergence shakes selected tent")
	enemy.state = "pop"
	c.spawn(h, "t", "rush")
	check(h.enemies.back().p.x == 490, "Popped bot still excludes its tent")
	h.world_three.tents = [{"x": 450.0, "y": 482.0, "shake": 0.0}]
	c.spawn(h, "t", "rush")
	check(h.enemies.back().p.x == 808, "Tent exactly150px from front falls back to ordinary right")
	h.enemies.clear()
	h.world_three.tents = [{"x": 560.0, "y": 482.0, "shake": 0.0}]
	h.level.solids = []
	h.level.plats = [[511, 609, 482]]
	c.spawn(h, "t", "rush")
	check(h.enemies.is_empty(), "Narrow tent platform falls back then fails regular spawn")
	h.level.plats = [[510, 610, 482]]
	c.spawn(h, "t", "rush")
	check(h.enemies.size() == 1 and h.enemies[0].p.x == 560, "Exactly100px tent platform accepted")

func _test_hook_order() -> void:
	var c = Combat.new()
	var h = Host.new()
	c.reset(h)
	var enemy := spawn_one(c, h)
	enemy.age = 12.0
	enemy.speed = 0.0
	c.enemies_tick(0, h)
	check(h.enemies.has(enemy), "Untouched bot retained at exact12s")
	c.enemies_tick(0.001, h)
	check(h.enemies.is_empty() and h.pop_count == 0 and h.drops.is_empty(), "Retirement strictly after12s gives no pop or coins")
	enemy = spawn_one(c, h)
	enemy.age = 12.0
	enemy.flash = 0.09
	c.enemies_tick(0.01, h)
	check(h.enemies.has(enemy) and enemy.hit_age == enemy.age, "Unexpired flash refreshes last-hit age after flash decay")
	enemy.age = 25.0
	enemy.flash = 0.01
	c.enemies_tick(0.01, h)
	check(not h.enemies.has(enemy), "Flash expiring exactly this tick does not refresh retirement")
	enemy = spawn_one(c, h)
	enemy.ab_bubble = 1.0
	enemy.rise = 0.5
	enemy.age = 12.0
	enemy.p.x = -500
	c.enemies_tick(1, h)
	check(enemy.age == 12 and enemy.rise == 0.5 and h.enemies.has(enemy), "Bubble hides age/rise and cleanup, including offscreen")
	enemy.ab_bubble = 0.0
	c.enemies_tick(0.01, h)
	check(not h.enemies.has(enemy), "Released untouched bubble bot retires on next AI hook")
	enemy = spawn_one(c, h, "rush", 300)
	h.power = "wellies"
	h.grounded = false
	h.velocity.y = 101
	h.player.y = enemy.p.y - 100
	enemy.dz = 0.001
	c.enemies_tick(0.01, h)
	check(enemy.state == "walk" and h.pop_count == 0 and enemy.dz < 0, "Dazzle skips wellies and AI for entire expiry tick")
	enemy.rise = 0.001
	c.enemies_tick(0.01, h)
	check(enemy.state == "walk" and enemy.rise < 0, "Emergence also skips wellies on expiry tick")
	c.enemies_tick(0, h)
	check(enemy.state == "pop" and h.velocity.y == -800 and h.pop_count == 1, "Wellies stomp after blockers expire, rebound800px/s")
	for boundary in [100.0, 101.0]:
		h.enemies.clear()
		enemy = spawn_one(c, h, "rush", 300)
		h.velocity.y = boundary
		c.enemies_tick(0, h)
		check((enemy.state == "pop") == (boundary > 100), "Wellies strict downward speed threshold " + str(boundary))
	h = Host.new()
	enemy = spawn_one(c, h, "flat", 500)
	enemy.state = "throw"
	enemy.pending = true
	enemy.t = 0.219
	c.enemies_tick(0, h)
	check(h.bullets.is_empty(), "Throw not before220ms")
	c.enemies_tick(0.001, h)
	check(h.bullets.size() == 1 and h.bullets[0].v == Vector2(-420, 0) and h.bullets[0].p.y == 354, "Flat throw frame2 and source height")
	c.enemies_tick(0.22, h)
	check(enemy.state == "walk" and enemy.cd >= 1.4 and enemy.cd <= 2.8, "Frame4 exits throw, resets timer range")

func _test_carriers() -> void:
	var c = Combat.new()
	var h = Host.new()
	c.reset(h)
	h.world_three.trailer = {"row": [100, 700, 402], "plat": true}
	c.spawn(h, "k", "throw")
	var enemy: Dictionary = h.enemies.back()
	check(enemy.ride and enemy.carry and enemy.hp == 3 and enemy.p.y == 327 and enemy.entered, "Carrier hangs75px over trailer with3HP")
	check(enemy.tx >= 180 and enemy.tx <= 590.4 and enemy.hop_t >= 1.6 and enemy.hop_t <= 3.8, "Carrier target and drop timers")
	enemy.p.x = enemy.tx
	enemy.cd = 10.0
	enemy.hop_t = 0.0
	h.world_three.cam_dx = 5
	c.enemies_tick(0, h)
	check(not enemy.ride and not enemy.carry and enemy.has("hop") and enemy.type == "rush" and enemy.stop == 0, "Carrier becomes rushing bot and starts drop hop")
	check(c.ex_drones.size() == 1 and enemy.hop.end.x == enemy.p.x + 150 and enemy.hop.duration == 0.42, "Drop anticipates30frame camera displacement, detaches drone once")
	c.enemies_tick(0.42, h)
	check(not enemy.has("hop") and enemy.p.y == 402 and enemy.surface == h.world_three.trailer, "Drop lands on live trailer surface")
	c.spawn(h, "d", "rush")
	enemy = h.enemies.back()
	check(enemy.fly and enemy.type == "flat" and enemy.hp == 2 and enemy.p.y == 372 and enemy.cd == 1.5, "Side d overrides kind with2HP flyer")
	enemy.age = 99.0
	enemy.cd = 0.0
	h.world_three.level_time = 0.4
	c.enemies_tick(0.01, h)
	check(h.enemies.has(enemy) and h.bullets.back().v == Vector2(-60, 50) and h.bullets.back().gravity == 900, "Flyer never retires and drops source low-gravity bill")
	check(is_equal_approx(enemy.p.y, 372 + sin(1 + enemy.ph) * 14), "Flyer bob follows absolute level clock")
	h.enemies.clear()
	c.spawn(h, "k", "throw")
	enemy = h.enemies.back()
	var before: int = c.ex_drones.size()
	c.kill_enemy(h, enemy)
	c.kill_enemy(h, enemy)
	check(c.ex_drones.size() == before + 1 and not enemy.carry and not enemy.ride, "Popping carried bot detaches drone once")
	h.world_three.level_time += 2.6
	c.visuals_tick(2.6, h)
	check(c.ex_drones.is_empty(), "Exiting drones expire exactly2600ms")

func _test_projectiles() -> void:
	var c = Combat.new()
	var h = Host.new()
	c.reset(h)
	var enemy := spawn_one(c, h, "throw", 400)
	enemy.dz = 0.25
	h.bullets = [shot(Vector2(400, 400), Vector2.ZERO, 2)]
	c.projectiles_tick(0, h)
	check(enemy.state == "pop" and enemy.p.x == 406 and h.drops[0].p.x == 406, "Dazzled bullet double damage, shove before coin drop")
	h.enemies.clear()
	for point in [Vector2(434, 400), Vector2(400, 370), Vector2(400, 482)]:
		enemy = spawn_one(c, h, "throw", 400)
		h.bullets = [shot(point)]
		c.projectiles_tick(0, h)
		check(enemy.hp == 4, "Strict ordinary shot edge " + str(point))
		h.enemies.clear()
	enemy = spawn_one(c, h, "throw", 400)
	h.bullets = [shot(Vector2(500, 400))]
	h.bullets[0].first_frame = true
	h.bullets[0].owner_x = 300
	c.projectiles_tick(0, h)
	check(enemy.hp == 3, "First frame sweeps from owner even behind muzzle")
	h.enemies.clear()
	h.bullets = [shot(Vector2(100, 400)), shot(Vector2(200, 400))]
	h.bullets[0].life = 0
	h.bullets[1].dead = true
	c.projectiles_tick(0, h)
	check(h.bullets.is_empty(), "Dead and canceled shots removed before late world interception")
	h.invincible = true
	var bill := shot(h.player - Vector2(0, 40), Vector2.ZERO, 1, true)
	bill.tie = true
	h.bullets = [bill]
	c.projectiles_tick(0, h)
	check(h.hearts == 3 and h.world_three.tied == 2.2 and h.bullets.is_empty(), "Invulnerability still consumes wristband and ties player2200ms")
	h.world_three.tied = 0
	bill = shot(h.player - Vector2(0, 40), Vector2(40, 10), 1, true)
	bill.tie = true
	bill.life = 0
	h.bullets = [bill]
	c.projectiles_tick(0.1, h)
	check(h.world_three.tied == 0 and h.bullets.is_empty(), "Ama/shield canceled wristband cannot move hit or tie")
	h.invincible = false
	h.hearts = 3
	h.bullets = [shot(Vector2(h.player.x + 26, h.player.y - 50), Vector2.ZERO, 1, true)]
	c.projectiles_tick(0, h)
	check(h.hearts == 3, "Hostile horizontal edge26 excluded")
	h.bullets = [shot(Vector2(h.player.x, h.player.y - 100), Vector2.ZERO, 1, true)]
	h.crouching = true
	c.projectiles_tick(0, h)
	check(h.hearts == 2, "Crouch source height100.8 includes100px high bill")
	h.bullets = [shot(Vector2(h.player.x, h.player.y - 101), Vector2.ZERO, 1, true)]
	c.projectiles_tick(0, h)
	check(h.hearts == 2, "Crouch avoids101px high bill")
	h = Host.new()
	h.level.solids.append([350, 450, 350])
	h.bullets = [shot(Vector2(400, 400))]
	h.crates = [{"p": Vector2(400, 482), "hp": 3, "give": "wellies", "broken": false}]
	c.projectiles_tick(0, h)
	check(h.crates[0].hp == 3 and h.bullets.is_empty(), "Out of crate y range wall-culls shot")
	h.bullets = [shot(Vector2(400, 430), Vector2.ZERO, 99)]
	c.projectiles_tick(0, h)
	check(h.crates[0].hp == 2, "Crate precedes wall filter and bullet damage is fixed1")
	h.level.solids = [[-400, 16400, 482]]
	h.bullets = [shot(Vector2(-40, 200)), shot(Vector2(778, 200)), shot(Vector2(500, h.view_top() - 60)), shot(Vector2(500, 580))]
	c.projectiles_tick(0, h)
	check(h.bullets.is_empty(), "All exact player-shot cull boundaries excluded")

func _test_pickups() -> void:
	var c = Combat.new()
	var h = Host.new()
	c.reset(h)
	h.coins = [coin(Vector2(600, 410), 11), coin(Vector2(650, 410), 100)]
	h.coins[1].stay = true
	c.pickups_tick(0, h)
	check(h.coins.size() == 1 and h.coins[0].stay, "Authored stay coins do not expire at11s")
	h.coins[0].p.x = -60
	c.pickups_tick(0, h)
	check(h.coins.is_empty(), "Stay coins still culled at camera-minus60")
	h.coins = [coin(h.player - Vector2(0, 72), 0.25)]
	c.pickups_tick(0, h)
	check(h.score == 0, "Coin age250ms exact cannot collect")
	c.pickups_tick(0.001, h)
	check(h.score == 1 and h.coins.is_empty(), "Coin collection after250ms")
	h.items = [{"p": Vector2(h.player.x, -5000), "vy": 0.0, "age": 0.3, "rest": true, "give": "wellies"}]
	c.pickups_tick(0, h)
	check(h.power == "", "Item age300ms exact cannot collect")
	c.pickups_tick(0.001, h)
	check(h.power == "wellies" and h.power_time == 12 and h.items.is_empty(), "Source item pickup ignores vertical distance and gives12s wellies")
	h.crates = [{"p": Vector2(400, 482), "hp": 1, "give": "wellies", "broken": false}]
	c.hit_crate(h, h.crates[0], 1)
	check(h.crates[0].broken and h.items[0].p == Vector2(400, 442) and h.items[0].vy == -600, "Crate spawns item40px above feet with600upward velocity")

func _test_boss_adapter() -> void:
	var c = Combat.new()
	var h = Host.new()
	c.reset(h)
	var cfg := {"cam": 0, "hp": 60, "hp2": 80, "kind": "seller", "name": "Wristband seller", "sub": "Seller blocks the path", "mini": "Sorted!"}
	c.start_boss(h, cfg)
	check(h.boss.state.hp == 60 and h.camera_lock == 0 and h.sounds.has("warn"), "Actual seller config starts warning and lock")
	h.boss.state.state = "walk"
	h.boss.state.x = 400
	var enemy := spawn_one(c, h, "throw", 400)
	h.crates = [{"p": Vector2(400, 482), "hp": 3, "give": "heart", "broken": false}]
	h.bullets = [shot(Vector2(400, 430), Vector2.ZERO, 1)]
	c.projectiles_tick(0, h)
	check(enemy.hp == 3 and h.boss.state.hp == 60 and h.crates[0].hp == 3, "Bot intercepts boss and crate, source hit order")
	h.enemies.clear()
	h.bullets = [shot(Vector2(400, 430), Vector2.ZERO, 99)]
	c.projectiles_tick(0, h)
	check(h.boss.state.hp == 59 and h.crates[0].hp == 3, "Boss precedes crate and ignores damage99")
	h.boss.state.dizzy = 1.0
	h.bullets = [shot(Vector2(400, 430), Vector2.ZERO, 99)]
	h.bullets[0].ghost = true
	c.projectiles_tick(0, h)
	check(h.boss.state.hp == 57, "Special ghost uses same fixed2dizzy path")
	h.boss.state.hp = 1
	h.bullets = [shot(Vector2(400, 430))]
	c.projectiles_tick(0, h)
	check(h.boss.state.state == "down" and h.drops.back().count == 16, "Boss bullet death drains rewards immediately in shots phase")
	check(c.boss_tick(1.8, h) == "" and h.boss != null, "Seller retained exactly1.8seconds after defeat")
	check(c.boss_tick(0.001, h) == "mini_done" and h.boss == null and h.camera_lock == null, "Seller clears encounter not level after strict1.8seconds")
	h.enemies.clear()
	h.bullets.clear()
	c.start_boss(h, cfg)
	h.boss.state.state = "throw"
	h.boss.state.x = 500
	h.boss.state.t = 0.32
	h.boss.state.pending_throw = true
	c.boss_tick(0, h)
	check(h.bullets.size() == 3 and h.bullets.all(func(b): return b.tie and not b.big), "Late boss throw preserves wristband attributes")

func _test_actual_abilities() -> void:
	var c = Combat.new()
	var h = AbilityHost.new()
	var a = Abilities.new()
	h.abilities = a
	c.reset(h)
	var cfg := {"cam": 0, "hp": 60, "hp2": 80, "kind": "seller", "name": "Seller", "mini": true}
	c.start_boss(h, cfg)
	h.boss.state.state = "walk"
	h.boss.state.x = 400
	var enemy := spawn_one(c, h, "throw", 400)
	enemy.p.y = 470
	var wristband := shot(h.player - Vector2(0, 80), Vector2.ZERO, 1, true)
	wristband.tie = true
	h.bullets = [wristband]
	a.reset("ama")
	a.meter = 1
	a.tick(0, {"special": true}, h, true)
	check(enemy.ab_bubble == 4.2 and h.boss.state.dizzy == 3.5 and wristband.life == 0, "Real Ama bubbles bots, dizzies boss and cancels wristbands in pre-step")
	check(h.boss.state.hp == 60 and enemy.hp == 4 and h.bullets.size() == 2, "Ama damage queues ghost rather than directly subtracting3HP")
	c.enemies_tick(0.016, h)
	a.bubbles_tick(0.016, h)
	check(not enemy.has("age") and enemy.ab_bubble < 4.2, "Shared bubble freezes World3 retirement while floating in reinsertion phase")
	c.projectiles_tick(0, h)
	check(enemy.hp == 1 and h.boss.state.hp == 60 and h.world_three.tied == 0, "Ama boss ghost intercepted by raised helper, canceled wristband cannot tie")
	h.enemies.clear()
	h.damage_boss(3)
	c.projectiles_tick(0, h)
	check(h.boss.state.hp == 58, "Ama3damage ghost with no helper gives exactly2dizzy damage")
	# Maya can cancel a band in pre-step even when shield duration expires in
	# that same call. life=0 must not revive it during hostile collision pass.
	a.reset("maya")
	a.active = "maya"
	a.duration = 6
	a.remaining = 0.01
	wristband = shot(h.player - Vector2(0, 81), Vector2.ZERO, 1, true)
	wristband.tie = true
	h.bullets = [wristband]
	a.tick(0.01, {}, h, true)
	check(a.active == "" and wristband.life == 0, "Real Maya shield marks wristband dead before exact expiry")
	c.projectiles_tick(0.01, h)
	check(h.world_three.tied == 0, "Expired shield cancellation still blocks later tie collision")
	# Football emits after boss and pickup phases, so its ghost gets its first
	# collision next frame. Boss health ignores football's requested damage2.
	a.reset("theo")
	var boss_hp: int = h.boss.state.hp
	h.bullets.clear()
	h.boss.state.dizzy = 0
	a.effects = [{"kind": "ball", "p": Vector2(400, 400), "v": Vector2.ZERO, "age": 0.0, "life": 3.6, "spin": 0.0, "free": 0.0, "boss_next": 0.0, "floor": 482.0, "trail": []}]
	a.tick(0.01, {}, h, true)
	c.projectiles_tick(0.01, h)
	check(h.bullets.is_empty() and h.boss.state.hp == boss_hp, "Football has no early projectile before late effects")
	a.effects_tick(0.01, h)
	check(h.bullets.size() == 1 and h.bullets[0].ghost and h.boss.state.hp == boss_hp, "Late football ghost waits for next collision pass")
	c.projectiles_tick(0, h)
	check(h.boss.state.hp == boss_hp - 1, "Football requested2 damage becomes source fixed1 on undizzy boss")
	# Real bubble release queues a ghost and can be intercepted by the first
	# overlapping ordinary bot, because held bots reinsert at array end.
	h.boss = null
	h.enemies.clear()
	var held := spawn_one(c, h, "throw", 500)
	held.ab_bubble = 0.001
	held.ab_bubble_total = 4.2
	held.ab_floor = 482
	var regular := spawn_one(c, h, "throw", 500)
	c.enemies_tick(0, h)
	a.bubbles_tick(0.001, h)
	check(h.enemies[0] == regular and h.enemies[1] == held and held.hp == 4, "Bubble release appends held bot after ordinary bot and queues damage")
	c.projectiles_tick(0, h)
	check(regular.hp == 3 and held.hp == 4, "Ordinary overlapping bot intercepts released-bubble ghost")

func _test_hop_contact_order() -> void:
	var c = Combat.new()
	var h = Host.new()
	c.reset(h)
	h.level.solids = [[0, 500, 482], [500, 1000, 482]]
	h.player = Vector2(519, 482)
	var enemy: Dictionary = c.new_bot(h, 478, {"row": h.level.solids[0], "plat": false}, "rush", {"entered": true})
	enemy.speed = 0.0
	c.enemies_tick(0, h)
	check(enemy.has("hop") and h.hearts == 2, "Newly created adjacent-solid hop still contacts player this frame")
	var before: int = h.hits.size()
	c.enemies_tick(0, h)
	check(h.hits.size() == before, "Already-hopping bot skips contact even at zero timestep")
	check(enemy.hop.duration == 0.5944 and enemy.hop.end == Vector2(540, 482), "Adjacent hop destination40px inward and520ms-plus-distance1.2")

func _test_boss_participant_snapshot() -> void:
	var c = Combat.new()
	var h = PairHost.new()
	c.reset(h, 2)
	var cfg := {"cam": 0, "hp": 60, "hp2": 80, "kind": "seller", "name": "Seller", "mini": true}
	c.start_boss(h, cfg)
	h.boss.state.state = "walk"
	h.boss.state.x = 600
	h.boss.state.dizzy = 10
	h.boss.state.waves = [{"x": 300.0, "vx": 0.0, "t": 0.0}]
	h.roster[0].p = Vector2(300, 482)
	h.roster[0].hearts = 1
	h.roster[1].p = Vector2(300, 482)
	c.boss_tick(0, h)
	check(h.roster[0].hearts == 0 and h.roster[1].hearts == 2, "Boss event roster stays stable when prior contact downs first participant")
	h.enemies.clear()
	var enemy := spawn_one(c, h)
	h.bullets = [shot(Vector2(600, 400)), shot(Vector2(100, 300), Vector2.ZERO, 1, true)]
	h.boss.state.hp = 1
	c.projectiles_tick(0, h)
	check(enemy.state == "pop" and h.pop_count == 0 and h.drops.size() == 2, "Boss down pops all helpers with normal drops but no player credit")
	check(h.bullets.size() == 1 and h.bullets[0].enemy, "Boss down intentionally retains existing hostile bills")
	check(c.boss_tick(1.801, h) == "mini_done" and c.go_time == 2.2, "Mini departure sets sourceGo2200ms")
	c.visuals_tick(0.016, h)
	check(is_equal_approx(c.go_time, 2.184), "Late sourceGo countdown consumes current frame")
