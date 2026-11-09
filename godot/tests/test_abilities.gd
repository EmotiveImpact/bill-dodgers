extends SceneTree
const Abilities = preload("res://src/abilities.gd")
class BossStub:
	extends RefCounted
	var state := {"state": "idle", "hp": 40, "max": 40, "x": 500.0, "fy": 482.0, "dizzy": 0.0}
class Host:
	extends RefCounted
	var player := Vector2(400, 482)
	var velocity := Vector2.ZERO
	var grounded := true
	var face := 1
	var cooldown := 0.3
	var elapsed := 0.0
	var camera := Vector2.ZERO
	var enemies: Array = []
	var bullets: Array = []
	var coins: Array = []
	var crates: Array = []
	var boss = null
	var pop_count := 0
	var invincible := 0.0
	var coins_added := 0
	func damage_enemy(enemy, damage): enemy.hp -= damage
	func damage_boss(damage): boss.state.hp -= damage
	func hit_crate(crate, damage): crate.hp -= damage
	func add_coins(_position, count): coins_added += count
	func nudge_player(dx): player.x += dx
	func view_width(): return 960.0
	func view_top(): return 0.0

var failures: Array[String] = []
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: " + label)
func enemy_at(p: Vector2) -> Dictionary:
	return {"p": p, "hp": 20, "state": "walk", "kind": "bot"}
func ready(who: String, host, unlocked: Array = []):
	var a = Abilities.new()
	a.reset(who, unlocked)
	a.meter = 1.0
	a.request_special()
	a.tick(0.0, {}, host)
	return a
func _initialize() -> void:
	var h = Host.new()
	var a = Abilities.new()
	a.reset("jp")
	check(a.meter == 0.5 and a.skills.is_empty(), "initial half meter, skills never auto unlocked")
	a.request_special()
	a.tick(0.0, {}, h)
	check(a.active.is_empty(), "unready special rejected")
	a.tick(3.0, {}, h)
	check(is_equal_approx(a.meter, 0.6), "30 second charge rate")
	h.pop_count = 2
	a.tick(0.0, {}, h)
	check(is_equal_approx(a.meter, 0.74), "each new pop adds 7 percent")
	a.tick(0.0, {}, h)
	check(is_equal_approx(a.meter, 0.74), "pops only counted once")
	a.reset("jp", ["super"])
	h.pop_count = 0
	a.tick(3.0, {}, h)
	check(is_equal_approx(a.meter, 0.7), "super doubles charging")
	for who in Abilities.SPEC:
		h = Host.new()
		a = ready(who, h)
		check(a.active == who and a.meter == 0.0, who + " activates")
		check(is_equal_approx(a.remaining, Abilities.SPEC[who].duration), who + " source duration")
		h.pop_count = 1
		a.tick(0.1, {}, h)
		check(a.meter == 0.0, who + " no charge during active")
		a.tick(10.0, {}, h)
		check(a.active.is_empty() and a.remaining == 0.0, who + " expires")
		a.tick(0.0, {}, h)
		check(a.meter == 0.0, who + " active-time pops not banked")
	h = Host.new()
	a = ready("jp", h)
	check(h.bullets.size() == 1 and h.bullets[0].damage == 2 and h.bullets[0].p.y == -20, "coin rain initial shot")
	check(h.bullets[0].v.y >= 720 and h.bullets[0].v.y <= 920, "rain speed range")
	for i in range(109): a.tick(1.0 / 60.0, {}, h)
	check(h.coins_added == 5, "rain ends with five collectible coins")
	h = Host.new()
	h.coins = [{"p": Vector2(600, 410), "v": Vector2.ONE, "age": 1.0, "rest": false}]
	a.reset("jp")
	a.tick(0.1, {}, h)
	check(h.coins[0].p.x < 600 and h.coins[0].rest and h.coins[0].v == Vector2.ZERO, "JP magnet pulls settled coins")
	h = Host.new()
	h.enemies = [enemy_at(Vector2(450, 482)), enemy_at(Vector2(1200, 482))]
	h.boss = BossStub.new()
	h.bullets = [{"p": Vector2(300, 300), "enemy": true, "life": 3.0}, {"p": Vector2(1200, 300), "enemy": true, "life": 3.0}]
	a = ready("ama", h)
	check(a.enemy_is_bubbled(h.enemies[0]) and not a.enemy_is_bubbled(h.enemies[1]), "Ama captures visible enemies only")
	check(h.bullets[0].life == 0.0 and h.bullets[1].life == 3.0, "Ama clears visible hostile shots")
	check(h.boss.state.hp == 37 and h.boss.state.dizzy == 3.5, "Ama boss sting and dizzy")
	a.tick(0.6, {}, h)
	check(h.enemies[0].p.y < 450, "bubble lift")
	a.tick(3.6, {}, h)
	check(h.enemies[0].hp == 19 and h.enemies[0].p.y == 482, "bubble release sting restores feet")
	check(is_equal_approx(a.jump_multiplier(), 1.09), "Ama jump passive")
	h = Host.new()
	a.reset("maya")
	check(not a.blocks_damage(h) and a.blocks_damage(h) and h.invincible == 0.9, "Maya blocks alternating eligible hits")
	h.enemies = [enemy_at(Vector2(430, 482))]
	h.boss = BossStub.new()
	h.bullets = [{"p": Vector2(400, 400), "enemy": true, "life": 3.0}]
	a = ready("maya", h)
	check(a.blocks_damage(h) and h.bullets[0].life == 0.0, "Maya shield damage/projectile block")
	check(h.enemies[0].hp == 19 and h.boss.state.hp == 39, "Maya shield enemy and boss damage")
	a.tick(0.1, {}, h)
	check(h.enemies[0].hp == 19, "shield respects 350ms repeat timer")
	a.tick(0.25, {}, h)
	check(h.enemies[0].hp == 18, "shield repeats after cooldown")
	h = Host.new()
	a = ready("leo", h)
	check(not h.grounded and h.velocity.y == -800, "Leo grounded launch")
	check(h.bullets[0].homing and h.bullets[0].v.x == 850, "Leo launches homing planes")
	a.tick(0.3, {}, h)
	a.tick(0.3, {}, h)
	check(h.bullets.size() == 3 and h.bullets[2].v.y == 250, "every third glider plane descends")
	h.velocity.y = 500
	a.tick(0.01, {}, h)
	check(h.velocity.y == 70, "glider fall cap")
	check(is_equal_approx(a.airborne_speed_multiplier(), 1.35), "glider speed bonus")
	a.reset("leo")
	check(a.max_fall_speed(true) == 340 and is_inf(a.max_fall_speed(false)), "Leo held-jump passive")
	h = Host.new()
	a = ready("mei", h)
	check(is_equal_approx(a.speed_multiplier(), 1.72) and is_equal_approx(a.jump_multiplier(), 1.06) and h.cooldown == 0.105, "Mei sugar rush movement and rapid fire")
	a.reset("mei")
	check(is_equal_approx(a.speed_multiplier(), 1.12), "Mei passive 12 percent speed")
	h = Host.new()
	h.crates = [{"p": Vector2(440, 482), "hp": 5, "broken": false}]
	a.reset("theo")
	a.tick(0.01, {"right": true}, h)
	a.tick(0.05, {"right": true}, h)
	check(h.crates[0].hp == 4, "Theo running kick cooldown")
	a.tick(0.2, {"right": true}, h)
	check(h.crates[0].hp == 3, "Theo running kick repeats")
	h.enemies = [enemy_at(Vector2(440, 482))]
	a = ready("theo", h)
	check(a.effects.size() == 1 and h.enemies[0].hp == 18, "Theo ball two damage")
	a.tick(0.001, {}, h)
	check(h.enemies[0].hp == 18, "ball repeat cooldown")
	a.effects[0].p = Vector2(950, 300)
	a.effects[0].v = Vector2(620, 0)
	a.tick(0.01, {}, h)
	check(a.effects[0].v.x < 0, "ball rebounds at camera edge")
	h = Host.new()
	a = ready("jp", h, ["super"])
	check(is_equal_approx(a.duration, 2.7), "super extends duration 50 percent")
	a.tick(3.0, {"special": true}, h)
	a.meter = 1.0
	a.tick(0.1, {"special": true}, h)
	check(a.active.is_empty(), "held special does not retrigger")
	a.tick(0.0, {"special": false}, h)
	a.tick(0.0, {"special": true}, h)
	check(a.active == "jp", "new special edge triggers")
	print("Abilities: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
