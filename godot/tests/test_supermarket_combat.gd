extends SceneTree
const Combat = preload("res://src/supermarket_combat.gd")
const Abilities = preload("res://src/abilities.gd")

class Runtime extends RefCounted:
	var additional: Array = []
	var intercept := false
	var intercept_calls := 0
	var intercepted_hearts: Array = []
	func surfaces(host) -> Array:
		var rows: Array = []
		for row in host.level.solids: rows.append({"row": row, "plat": false})
		for row in host.level.plats: rows.append({"row": row, "plat": true})
		return rows + additional
	func intercept_shot(host, _shot: Dictionary) -> bool:
		intercept_calls += 1
		intercepted_hearts.append(host.hearts)
		return intercept

class AbilityStub extends RefCounted:
	func enemy_is_bubbled(enemy: Dictionary) -> bool: return float(enemy.get("ab_bubble", 0)) > 0

class Host extends RefCounted:
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
	var world_two = Runtime.new()
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
		hearts = maxi(0, hearts - 1)
	func add_coins(position: Vector2, count: int) -> void: drops.append({"p": position, "count": count})
	func floor_at(x: float, y: float) -> float:
		var found := INF
		for surface in world_two.surfaces(self):
			var row: Array = surface.row
			if x >= row[0] and x <= row[1] and row[2] >= y - 2: found = minf(found, row[2])
		return found
	func _land(x: float, old_y: float, new_y: float) -> float:
		var found := INF
		for surface in world_two.surfaces(self):
			var row: Array = surface.row
			if x >= row[0] and x <= row[1] and row[2] >= old_y - 1 and row[2] <= new_y + 0.5: found = minf(found, row[2])
		return found
	func ability_inside_wall(point: Vector2) -> bool:
		for surface in world_two.surfaces(self):
			var row: Array = surface.row
			if not surface.plat and point.x > row[0] and point.x < row[1] and point.y > row[2] + 4: return true
		return false

class PairHost extends Host:
	var roster: Array = [{"p": Vector2(300, 300), "hearts": 3, "down": false, "height": 180.0, "crouching": false}, {"p": Vector2(500, 482), "hearts": 3, "down": false, "height": 170.0, "crouching": false}]
	func combat_participants() -> Array: return roster
	func hurt_combat_participant(record: Dictionary, from_x: float) -> void:
		record.hearts -= 1
		hits.append(from_x)

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

func spawn_one(combat, host, kind: String = "rush", side: Variant = 500) -> Dictionary:
	combat.spawn(host, side, kind)
	return host.enemies.back()

func _initialize() -> void:
	_test_waves()
	_test_spawns()
	_test_enemies()
	_test_projectiles()
	_test_canceled_bills()
	_test_pickups()
	_test_late_phases()
	print("Supermarket combat: ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

func _test_waves() -> void:
	var c = Combat.new()
	var h = Host.new()
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/2-1.json"))
	h.level = source.level.duplicate(true)
	var original: Dictionary = h.level.duplicate(true)
	c.reset(h)
	check(c.waves.size() == 11 and h.crates.size() == 5, "2-1 loads all eleven waves and five crates")
	check(c.waves[-1].at == 15262, "Authored last wave camera is not silently clamped or remapped")
	check(c.waves[5].group.size() == 4, "Solo wave excludes co-op extras")
	h.camera.x = 497.9
	c.waves_tick(0.016, h)
	check(not c.waves[0].started and h.enemies.is_empty(), "Camera must reach authored wave minus two")
	h.camera.x = 498
	c.waves_tick(0.016, h)
	check(c.waves[0].started and h.camera_lock == 538 and c.waves[0].index == 1, "First source wave starts at threshold and locks camera forty pixels ahead")
	c.waves_tick(1.784, h)
	check(c.waves[0].index == 3 and h.enemies.size() == 3, "Due entries dispatch sequentially in source order")
	for enemy in h.enemies: enemy.state = "pop"
	c.waves_tick(0, h)
	check(c.waves[0].done and h.camera_lock == null, "Last pop releases the wave on the next waves phase")
	c.reset(h, 2)
	check(c.waves[5].group.map(func(entry): return int(entry[0])) == [0, 2500, 4500, 6500, 3500], "Appended pair wave delays remain deliberately unsorted")
	h.enemies.clear()
	c.waves = [c.waves[5]]
	h.camera.x = 6880
	c.waves_tick(4, h)
	check(c.waves[0].index == 2 and h.enemies.size() == 2, "Appended3500ms entry waits behind base4500ms entry")
	c.waves_tick(2.5, h)
	check(c.waves[0].index == 5 and h.enemies.size() == 5, "6500ms tick consumes late base and then overdue extra")
	check(h.level == original, "Combat never mutates imported wave arrays or geometry")
	h = Host.new()
	h.level.waves = [{"at": 100, "g": [[0, "r", "rush"]], "x": []}]
	h.level.solids = []
	c.reset(h)
	h.camera.x = 100
	c.waves_tick(0.016, h)
	check(c.waves[0].index == 1 and c.waves[0].done and h.enemies.is_empty(), "Failed placement is consumed once and cannot stall a wave")
	h.level.solids = [[-400, 16400, 482]]
	h.level.auto = 0.2
	c.reset(h)
	c.waves_tick(0, h)
	check(h.camera_lock == null and not c.waves[0].done, "Auto stages do not set normal wave locks")
	var enemy: Dictionary = h.enemies[0]
	c.kill_enemy(h, enemy)
	check(not c.waves[0].done, "Death after waves does not finish the wave in the same phase")
	c.waves_tick(0, h)
	check(c.waves[0].done, "Wave completion sees prior phase death on next tick")

func _test_spawns() -> void:
	var c = Combat.new()
	var h = Host.new()
	c.reset(h, 1, 123)
	var rush := spawn_one(c, h)
	check(rush.hp == 3 and rush.type == "rush" and rush.speed >= 99 and rush.speed <= 126.5 and rush.stop == 0, "Rush source HP, speed and no stopping distance")
	check(rush.p == Vector2(500, 482) and rush.face == 1 and rush.entered and rush.spawn_side == 500, "Numeric spawn retains its position, face and provenance")
	check(rush.arrival == 0.3 and rush.t >= 0 and rush.t <= 0.4 and rush.cd >= 0.9 and rush.cd <= 1.8, "Numeric arrival and common timer ranges")
	var flat := spawn_one(c, h, "flat", "l")
	check(flat.p.x == -70 and flat.face == 1 and not flat.entered and flat.hp == 4 and flat.type == "flat", "Left flat spawns outside screen with four HP")
	var right := spawn_one(c, h, "throw", "r")
	check(right.p.x == 808 and right.face == -1 and right.stop >= 230 and right.stop <= 400, "Right thrower starts seventy pixels outside view")
	var big := spawn_one(c, h, "big")
	check(big.hp == 24 and big.max_hp == 24 and big.hw == 58 and big.hh == 186 and big.scale == 1.66, "Solo security bot uses its own health and hitbox")
	check(big.speed == 55 and big.stop == 250 and big.cd == 1.2 and not big.has("volley"), "Security uses normal arc throw policy, never Bailiff volleys")
	c.reset(h, 2)
	big = spawn_one(c, h, "big")
	check(big.hp == 34 and big.max_hp == 34, "Participant scaling uses source34HP security bot")
	var drone := spawn_one(c, h, "drone")
	check(drone.state == "drone" and drone.hp == 2 and drone.p.y == 282 and drone.base_y == 482, "Drone spawns200 pixels above its source floor")
	check(drone.hw == 40 and drone.hh == 70 and not drone.has("fly"), "Drone preserves source hitbox and absence of fly flag")
	check(drone.cd >= 1.5 and drone.cd <= 2.3 and drone.phase >= 0 and drone.phase <= 6, "Drone initial cooldown and phase ranges")
	var cart := spawn_one(c, h, "cart", 300)
	check(cart.hp == 2 and cart.state == "cart" and cart.cart_dir == 1 and cart.speed >= 300 and cart.speed <= 360, "Numeric cart direction follows midpoint and has source speed")
	cart = spawn_one(c, h, "cart", 500)
	check(cart.cart_dir == -1 and cart.face == 1, "Numeric cart direction and initial base face are distinct source fields")
	h = Host.new()
	h.level.solids = [[200, 600, 482]]
	var numeric := spawn_one(c, h, "rush", 200)
	check(numeric.p.x == 248, "Numeric gap search increments right by24 and respects strict30px inset")
	h = Host.new()
	h.level.solids = []
	h.level.plats = [[-400, 4000, 482]]
	c.spawn(h, 300, "drone")
	check(h.enemies.is_empty(), "Drone still requires a qualifying solid, never spawns on one-way platforms")
	h.world_two.additional = [{"row": [-400, 4000, 430], "plat": false}]
	numeric = spawn_one(c, h, "rush", 300)
	check(numeric.p.y == 430, "Spawn reads runtime surfaces, including dynamic geometry")
	h.world_two.additional[0].row[2] = 5482
	h.enemies.clear()
	c.spawn(h, 300, "rush")
	check(h.enemies.is_empty(), "Dynamically opened gate top outside view cannot host a bot")
	var pair = PairHost.new()
	pair.level.solids = [[-400, 4000, 310], [-400, 4000, 390], [-400, 4000, 482]]
	numeric = spawn_one(c, pair, "rush", 600)
	check(numeric.p.y == 390, "Spawn selects floor closest to average living feet")
	pair.roster[1].down = true
	numeric = spawn_one(c, pair, "rush", 600)
	check(numeric.p.y == 310, "Down participant excluded from spawn height average")
	var first = Host.new()
	var second = Host.new()
	c.reset(first, 1, 321)
	spawn_one(c, first, "drone", 500)
	c.reset(second, 1, 321)
	spawn_one(c, second, "drone", 500)
	check(first.enemies == second.enemies, "Reset with same seed reconstructs deterministic combat state")

func _test_enemies() -> void:
	var c = Combat.new()
	var h = Host.new()
	c.reset(h)
	var big := spawn_one(c, h, "big", 550)
	big.state = "throw"
	big.t = 0.219
	big.pending = true
	c.enemies_tick(0.001, h)
	check(h.bullets.size() == 1 and h.bullets[0].gravity == 1700 and h.bullets[0].v.y == -780, "Security releases one ordinary arc at220ms")
	check(h.bullets[0].p == Vector2(524, 382) and is_equal_approx(h.bullets[0].v.x, -250.0 / 0.9), "Arc source origin and900ms horizontal aim")
	c.enemies_tick(0.22, h)
	check(big.state == "walk" and big.cd >= 1.4 and big.cd <= 2.8 and h.bullets.size() == 1, "Throw resumes walk at440ms without duplicate projectile")
	h.enemies.clear()
	h.bullets.clear()
	var flat := spawn_one(c, h, "flat", 550)
	flat.state = "throw"
	flat.t = 0.21
	flat.pending = true
	c.enemies_tick(0.01, h)
	check(h.bullets.size() == 1 and h.bullets[0].p == Vector2(520, 354) and h.bullets[0].v == Vector2(-420, 0) and h.bullets[0].gravity == 0 and h.bullets[0].flat, "Flat bill uses fixed height128 and horizontal420 speed")
	h = Host.new()
	var held := spawn_one(c, h)
	held.p = Vector2(-401, 482)
	held.entered = false
	held.ab_bubble = 1.0
	held.wait = 5.99
	held.t = 0.2
	held.flash = 0.1
	c.enemies_tick(0.1, h)
	check(h.enemies.size() == 1 and held.t == 0.2 and held.wait == 5.99 and held.flash == 0.1 and held.p.x == -401, "Held bubbles excluded from AI, timers and out-of-view cleanup")
	held.ab_bubble = 0
	c.enemies_tick(0.1, h)
	check(h.enemies.is_empty(), "Unheld offscreen enemy resumes source cleanup")
	h = Host.new()
	var abandoned := spawn_one(c, h, "rush", "r")
	abandoned.wait = 6.0
	c.enemies_tick(0, h)
	check(h.enemies.size() == 1, "Unentered abandon threshold is strict greater-than six seconds")
	c.enemies_tick(0.001, h)
	check(h.enemies.is_empty(), "Unentered bot abandons once wait exceeds six seconds")
	var popped := spawn_one(c, h)
	c.kill_enemy(h, popped)
	c.enemies_tick(1.3, h)
	check(h.enemies.size() == 1 and h.drops.size() == 1 and h.drops[0].count >= 4 and h.drops[0].count <= 6, "Pop survives1300ms and drops4–6 coins once")
	c.kill_enemy(h, popped)
	check(h.drops.size() == 1 and h.pop_count == 1, "Repeated death callback never duplicates credits or loot")
	c.enemies_tick(0.001, h)
	check(h.enemies.is_empty(), "Pop removed after1300ms")
	h = Host.new()
	big = spawn_one(c, h, "big", 400)
	big.state = "throw"
	big.pending = false
	h.player = Vector2(467, 314)
	c.enemies_tick(0, h)
	check(h.hits.size() == 1, "Security extended contact reaches67px sideways and168px above feet")
	h.hits.clear()
	h.hearts = 3
	h.player.x = 468
	c.enemies_tick(0, h)
	check(h.hits.is_empty(), "Security contact excludes exact horizontal68px boundary")
	h = Host.new()
	h.level.solids = [[-400, 300, 482], [450, 900, 330]]
	h.player = Vector2(700, 330)
	var hopper := spawn_one(c, h, "rush", 250)
	hopper.p.x = 278
	hopper.entered = true
	c.enemies_tick(0, h)
	check(hopper.has("hop") and hopper.hop.end == Vector2(490, 330), "Ground bot hops to the next eligible solid forty pixels inside")
	var duration: float = hopper.hop.duration
	check(is_equal_approx(duration, 0.520 + 212 * 0.0012), "Hop duration uses source520ms plus1.2ms per horizontal pixel")
	c.enemies_tick(duration * 0.5, h)
	check(is_equal_approx(hopper.p.y, 406 - (70 + 152 * 0.6)), "Hop has source sine arc and uphill height boost")
	h.player = hopper.p
	c.enemies_tick(0, h)
	check(h.hits.is_empty(), "In-flight hop skips ordinary contact")
	c.enemies_tick(duration * 0.5, h)
	check(not hopper.has("hop") and hopper.p == Vector2(490, 330) and hopper.segment == h.level.solids[1], "Hop lands on new segment and ends on exact top")
	h = Host.new()
	var walker := spawn_one(c, h, "rush", 500)
	c.sync_visuals(h)
	walker.p.x -= 18
	c.sync_visuals(h)
	check(walker.stride == 18 and walker.visual_move == -1, "Renderer stride comes from displacement without draw-time mutation")
	walker.flash = 0.01
	c.sync_visuals(h)
	check(walker.visual_move == 0, "Hit flash suppresses visual walking")
	var unseen := spawn_one(c, h, "rush", 1000)
	c.sync_visuals(h)
	check(not unseen.has("last_visual_x"), "Bots outside source drawing margin do not accrue hidden stride")
	unseen.p.x = 800
	c.sync_visuals(h)
	check(unseen.stride == 0 and unseen.visual_move == 0, "First visible frame has no fabricated prior displacement")

func _test_projectiles() -> void:
	var c = Combat.new()
	var h = Host.new()
	c.reset(h)
	var enemy := spawn_one(c, h, "rush", 310)
	var bullet := shot(Vector2(360, 410), Vector2(780, 0))
	bullet.first_frame = true
	h.bullets = [bullet]
	c.projectiles_tick(0.016, h)
	check(enemy.hp == 2 and enemy.p.x == 316 and h.bullets.is_empty(), "First-frame sweep from owner crosses enemy between body and muzzle")
	check(h.world_two.intercept_calls == 0, "Bot hit consumes shot before level interceptor")
	h.enemies.clear()
	h.crates = [{"p": Vector2(400, 482), "hp": 3, "broken": false, "give": "split", "hit": 0.0}]
	h.world_two.intercept = true
	h.bullets = [shot(Vector2(400, 452), Vector2.ZERO, 9)]
	h.bullets[0].ghost = true
	c.projectiles_tick(0, h)
	check(h.crates[0].hp == 3 and h.world_two.intercept_calls == 1 and h.bullets.is_empty(), "Level interceptor precedes crate even for powerful ghost shot")
	h.world_two.intercept = false
	for i in range(3):
		h.bullets = [shot(Vector2(400, 452), Vector2.ZERO, 9)]
		c.projectiles_tick(0, h)
		check(h.crates[0].hp == 2 - i, "Crate loses exactly one HP per projectile regardless damage" + str(i))
	check(h.crates[0].broken and h.items.size() == 1 and h.items[0].p == Vector2(400, 442) and h.items[0].vy == -600, "Third crate shot releases source item origin and impulse")
	h = Host.new()
	var big := spawn_one(c, h, "big", 500)
	h.bullets = [shot(Vector2(443, 297))]
	c.projectiles_tick(0, h)
	check(big.hp == 23, "Security projectile hitbox uses58 by186, not scaled ordinary box")
	big.p.x = 500
	h.bullets = [shot(Vector2(442, 297))]
	c.projectiles_tick(0, h)
	check(big.hp == 23, "Security shot excludes exact58px horizontal boundary")
	h.bullets = [shot(Vector2(500, 296))]
	c.projectiles_tick(0, h)
	check(big.hp == 23, "Security shot excludes exact186px top boundary")
	h.enemies.clear()
	var drone := spawn_one(c, h, "drone", 500)
	h.bullets = [shot(Vector2(500, 211))]
	c.projectiles_tick(0, h)
	check(drone.hp == 2, "Drone shot passes above source70px body")
	h.bullets = [shot(Vector2(500, 213), Vector2.ZERO, 2)]
	c.projectiles_tick(0, h)
	check(drone.state == "pop" and h.drops.back().p.x == 506, "Drone kill drops coins at post-impact shove position")
	h = Host.new()
	h.bullets = [shot(Vector2(300, 354), Vector2.ZERO, 1, true), shot(Vector2(500, 410))]
	h.world_two.intercept = true
	c.projectiles_tick(0, h)
	check(h.world_two.intercepted_hearts == [3] and h.hearts == 2, "All player shot hooks happen before earlier-stored hostile bill damage")
	h = Host.new()
	h.crouching = true
	h.bullets = [shot(Vector2(300, 354), Vector2.ZERO, 1, true)]
	c.projectiles_tick(0, h)
	check(h.hearts == 3 and h.bullets.size() == 1, "Crouched body avoids high flat bills")
	h.crouching = false
	c.projectiles_tick(0, h)
	check(h.hearts == 2 and h.bullets.is_empty(), "Standing body takes the same flat bill")
	h = Host.new()
	h.bullets = [shot(Vector2(500, -200), Vector2(0, -100), 1, true)]
	h.bullets[0].gravity = 1700.0
	c.projectiles_tick(0.016, h)
	check(h.bullets.size() == 1 and h.bullets[0].p.y < -200, "Hostile arcs survive above camera and can descend later")
	h.bullets = [shot(Vector2(500, 475), Vector2(0, 100), 1, true)]
	c.projectiles_tick(0.02, h)
	check(h.bullets.is_empty(), "Descending hostile bill lands with source six-pixel offset")
	var upper := Vector2(0, h.view_top() - 60).y
	h.bullets = [shot(Vector2(-40, 400)), shot(Vector2(778, 400)), shot(Vector2(500, upper)), shot(Vector2(500, 580)), shot(Vector2(-60, 400), Vector2.ZERO, 1, true), shot(Vector2(798, 400), Vector2.ZERO, 1, true)]
	c.projectiles_tick(0, h)
	check(h.bullets.is_empty(), "Player and hostile culling exclude exact source screen boundaries")
	h.bullets = [shot(Vector2(500, 400))]
	h.bullets[0].life = 0.001
	c.projectiles_tick(0.1, h)
	check(h.bullets.size() == 1, "World2 source has no arbitrary projectile lifetime countdown")
	h = Host.new()
	h.level.solids.append([450, 650, 300])
	h.world_two.intercept = true
	h.bullets = [shot(Vector2(500, 400))]
	c.projectiles_tick(0, h)
	check(h.world_two.intercept_calls == 1, "Hook sees a projectile before solid-wall cleanup")
	var pair = PairHost.new()
	pair.roster[0].p = Vector2(300, 482)
	pair.roster[1].p = Vector2(300, 482)
	pair.bullets = [shot(Vector2(300, 400), Vector2.ZERO, 1, true)]
	c.projectiles_tick(0, pair)
	check(pair.roster[0].hearts == 2 and pair.roster[1].hearts == 2, "A source hostile bill can hit both overlapping living participants")

func _test_canceled_bills() -> void:
	var c = Combat.new()
	# Exercise the actual abilities pre-step, including Maya's final frame:
	# her shield erases the bill even though active expires before combat.
	for who in ["ama", "maya"]:
		var h = Host.new()
		var a = Abilities.new()
		h.abilities = a
		a.reset(who)
		if who == "ama": a.meter = 1.0
		else:
			a.active = "maya"
			a.remaining = 0.005
		var canceled := shot(h.player + Vector2(0, -80), Vector2(20, 0), 1, true)
		var before: Vector2 = canceled.p
		h.bullets = [canceled]
		a.tick(0.01, {"special": who == "ama"}, h, true)
		check(canceled.life == 0 and (a.active == "ama" if who == "ama" else a.active.is_empty()), who + " actual ability cancels bill before combat at special boundary")
		c.projectiles_tick(0.01, h)
		check(h.hearts == 3 and h.hits.is_empty() and h.bullets.is_empty(), who + " canceled overlapping bill cannot deal same-frame damage")
		check(canceled.p == before and not canceled.has("age"), who + " canceled bill does not move or age after removal")
	var h = Host.new()
	var marked_dead := shot(h.player + Vector2(0, -80), Vector2(100, 100), 1, true)
	marked_dead.dead = true
	h.bullets = [marked_dead]
	c.projectiles_tick(0.01, h)
	check(h.hearts == 3 and h.bullets.is_empty() and marked_dead.p == h.player + Vector2(0, -80), "Already-dead hostile bill is discarded even with positive life")
	h.hearts = 3
	var live := shot(h.player + Vector2(0, -80), Vector2.ZERO, 1, true)
	live.life = 0.001
	h.bullets = [live]
	c.projectiles_tick(0.01, h)
	check(h.hearts == 2 and h.bullets.is_empty(), "Positive-life hostile bill still collides before this tick's normal removal")
	h.hearts = 3
	h.bullets = [shot(Vector2(h.player.x, 475), Vector2(0, 100), 1, true)]
	c.projectiles_tick(0.02, h)
	check(h.hearts == 2 and h.bullets.is_empty(), "Live bill landing this tick still checks player contact before floor cleanup")

func _test_pickups() -> void:
	var c = Combat.new()
	var h = Host.new()
	h.coins = [coin(Vector2(300, 410), 0.25)]
	c.pickups_tick(0, h)
	check(h.score == 0 and h.coins.size() == 1, "Coin collection threshold is strict250ms")
	c.pickups_tick(0.001, h)
	check(h.score == 1 and h.coins.is_empty(), "Coin collection credits the shared kitty once")
	h.coins = [coin(Vector2(400, 410))]
	c.pickups_tick(0.016, h)
	check(h.coins[0].p.x == 392, "Coin attraction is500 pixels per second inside source range")
	h.coins = [coin(Vector2(300, 474))]
	c.pickups_tick(0, h)
	check(h.coins.is_empty(), "Floor coin inside collection reach still credits before filtering")
	h.coins = [coin(Vector2(600, 410), 11.0), coin(Vector2(-60, 410))]
	c.pickups_tick(0, h)
	check(h.coins.is_empty(), "Coin age11sec and behind-camera equality are excluded")
	h.coins = [coin(Vector2(600, 410), 10.99)]
	h.coins[0].keep = true
	c.pickups_tick(0.02, h)
	check(h.coins.is_empty(), "Generic filtering precedes runtime keep-age reset, matching source")
	h.items = [{"p": Vector2(300, 100), "vy": 0.0, "age": 0.3, "rest": true, "give": "split"}]
	c.pickups_tick(0, h)
	check(h.items.size() == 1 and h.power == "", "Item pickup threshold is strict300ms")
	c.pickups_tick(0.001, h)
	check(h.items.is_empty() and h.power == "split" and h.power_time == 12, "Item pickup has no vertical distance check and lasts12sec")
	h.hearts = 2
	h.items = [{"p": Vector2(300, 456), "vy": 0.0, "age": 0.31, "rest": true, "give": "heart"}]
	c.pickups_tick(0, h)
	check(h.hearts == 3, "Heart item restores one heart capped at three")
	h.hearts = 0
	h.coins = [coin(Vector2(300, 410))]
	h.items = [{"p": Vector2(300, 456), "vy": 0.0, "age": 0.31, "rest": true, "give": "heart"}]
	c.pickups_tick(0, h)
	check(h.hearts == 0 and h.coins.size() == 1 and h.items.size() == 1, "Down player cannot collect items or coins before late checkpoint revive")
	h.hearts = 3
	h.items = [{"p": Vector2(600, 454), "vy": 100.0, "age": 0.0, "rest": false, "give": "heart"}]
	c.pickups_tick(0.02, h)
	check(h.items[0].p.y == 456 and h.items[0].rest, "Falling item rests26 pixels above the runtime floor")
	h.items[0].age = 10000.0
	c.pickups_tick(0, h)
	check(h.items.size() == 1, "Source items have no imagined age expiry")
	h.coins = [{"p": Vector2(600, 472), "v": Vector2(100, 100), "age": 0.0, "rest": false}]
	c.pickups_tick(0.02, h)
	check(h.coins[0].p.y == 474 and is_equal_approx(h.coins[0].v.y, 0), "Low-energy coin settles at eight-pixel floor offset")
	h.coins = [{"p": Vector2(600, 472), "v": Vector2(100, 200), "age": 0.0, "rest": false}]
	c.pickups_tick(0.02, h)
	check(h.coins[0].p.y == 474 and is_equal_approx(h.coins[0].v.x, 70) and is_equal_approx(h.coins[0].v.y, -248 * 0.45), "Bouncing coin uses source restitution and friction")

func _test_late_phases() -> void:
	var c = Combat.new()
	var h = Host.new()
	c.reset(h)
	var cart := spawn_one(c, h, "cart", 500)
	cart.speed = 300.0
	c.enemies_tick(0.1, h)
	check(cart.p.x == 500, "Ordinary AI pass does not perform late cart movement")
	h.bullets = [shot(Vector2(500, 410))]
	c.projectiles_tick(0, h)
	check(cart.hp == 1 and cart.p.x == 506, "Shot hits cart at pre-late position, then shoves")
	c.late_carts(0.1, h)
	check(cart.p.x == 476, "Late cart motion occurs after its projectile hit")
	cart.ab_bubble = 1.0
	c.late_carts(0.1, h)
	check(cart.p.x == 446, "Held carts still have source late motion after bubbles are re-appended")
	cart.p.x = 44
	cart.cart_dir = -1
	c.late_carts(0.01, h)
	check(cart.p.x == 44 and cart.cart_dir == 1 and cart.face == -1, "Entered cart turns at44px clamp with source one-frame old face")
	cart.p.x = 694
	cart.cart_dir = 1
	c.late_carts(0.01, h)
	check(cart.p.x == 694 and cart.cart_dir == -1, "Entered cart turns at right screen inset44")
	cart.entered = false
	cart.segment = [-100, 800, 482]
	cart.p.x = 775
	cart.cart_dir = 1
	c.late_carts(0, h)
	check(cart.p.x == 774 and cart.cart_dir == -1, "Unentered cart uses segment26 inset, not screen clamp")
	h = Host.new()
	var drone := spawn_one(c, h, "drone", 500)
	drone.phase = 0.0
	drone.cd = 0.05
	c.enemies_tick(0.1, h)
	check(drone.p == Vector2(500, 282) and drone.cd == 0.05, "Base AI does not advance drone phase, motion or cooldown")
	c.projectiles_tick(0.1, h)
	c.late_drones(0.1, h)
	check(drone.p.x == 491 and is_equal_approx(drone.phase, 0.25) and is_equal_approx(drone.p.y, 282 + sin(0.25) * 14), "Late drone tracks at90px/sec and bobs with400ms phase")
	check(h.bullets.size() == 1 and h.bullets[0].sticker and h.bullets[0].p == drone.p + Vector2(0, 6), "Drone sticker emitted after projectiles stays at origin this frame")
	check(h.bullets[0].v == Vector2(0, 50) and h.bullets[0].gravity == 1200 and drone.cd >= 1.7 and drone.cd <= 2.6, "Sticker speed, gravity and subsequent drone cooldown match source")
	var before: Vector2 = h.bullets[0].p
	c.projectiles_tick(0.1, h)
	check(is_equal_approx(h.bullets[0].p.y - before.y, 17), "New sticker moves next frame with acceleration applied before displacement")
	drone.ab_bubble = 1.0
	var old_x: float = drone.p.x
	c.late_drones(0.1, h)
	check(drone.p.x < old_x and is_equal_approx(drone.phase, 0.5), "Held drone still runs source late movement after bubble phase")
	drone.p.x = 10
	c.late_drones(0, h)
	check(drone.p.x == 40 and drone.entered, "Drone late phase clamps screen and marks entry")
