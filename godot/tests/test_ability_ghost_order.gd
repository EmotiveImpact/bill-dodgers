extends SceneTree
const Abilities = preload("res://src/abilities.gd")
class BossStub extends RefCounted:
	var state := {"state": "walk", "hp": 260, "max": 260, "x": 500.0, "fy": 482.0, "dizzy": 0.0}
class Host extends RefCounted:
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
	var ghost_mode := true
	var calls: Array = []
	func _zap(point: Vector2, damage: int, direction: float, kind: String) -> void:
		calls.append({"kind": kind, "point": point, "direction": direction, "damage": damage})
		bullets.append({"p": point, "v": Vector2((direction if direction != 0 else face) * 0.1, 0), "life": 20.0, "ghost": true, "ghost_age": 0.0, "enemy": false, "damage": damage})
	func damage_enemy(enemy: Dictionary, damage: int) -> void:
		_zap(enemy.p - Vector2(0, 56), damage, signf(enemy.p.x - player.x), "enemy")
	func damage_boss(damage: int) -> void:
		_zap(Vector2(boss.state.x, boss.state.fy - 120), damage, signf(boss.state.x - player.x), "boss")
	func hit_crate(crate: Dictionary, damage: int) -> void:
		if ghost_mode: _zap(crate.p - Vector2(0, 30), damage, face, "crate")
		else:
			calls.append({"kind": "legacy_crate"})
			crate.hp -= damage
	func ability_free_zap(point: Vector2, direction: float) -> bool:
		if not ghost_mode: return false
		_zap(point, 1, direction, "free")
		return true
	func add_coins(_point: Vector2, _count: int) -> void: pass
	func view_width() -> float: return 960.0
	func view_top() -> float: return 0.0

var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func enemy(x: float, tag: String) -> Dictionary:
	return {"p": Vector2(x, 482), "hp": 20, "state": "walk", "tag": tag, "t": 5.0, "flash": 0.2, "wait": 5.99}

func ball(point: Vector2, velocity: Vector2 = Vector2.ZERO) -> Dictionary:
	return {"kind": "ball", "p": point, "v": velocity, "age": 0.0, "life": 3.6, "spin": 0.0, "free": 0.0, "boss_next": 0.0, "floor": 482.0, "trail": []}

func _initialize() -> void:
	var h = Host.new()
	var a = Abilities.new()
	a.reset("theo")
	a.meter = 1.0
	a.request_special()
	a.tick(0.016, {}, h, true)
	check(a.active == "theo" and a.effects.size() == 1, "Deferred pre-step starts special immediately")
	check(a._time == 0 and a.effects[0].age == 0, "Pre-step retains old source ability clock and ball age")
	check(a.effects[0].p == Vector2(440, 482 - 178 * 0.55), "New ball stays at launch point until late effects")
	check(h.bullets.is_empty() and h.calls.is_empty(), "No early Theo ghost before bot/boss/bin collision pass")
	a.effects_tick(0.016, h)
	check(is_equal_approx(a._time, 0.016) and is_equal_approx(a.effects[0].age, 0.016), "Late effects advances clock and ball once")
	check(h.calls.size() == 1 and h.calls[0].kind == "free", "Free ball emits a ghost with no crate present")
	check(h.calls[0].point == a.effects[0].p and h.calls[0].direction == 1, "Free ghost uses exact moved ball point and direction")
	check(h.bullets[0].ghost and h.bullets[0].ghost_age == 0 and h.bullets[0].damage == 1, "Late ghost is newly queued for next frame collision")
	check(is_equal_approx(a.effects[0].free, 0.18), "Free ghost cadence resets to180ms")
	a.tick(0.09, {}, h, true)
	check(h.calls.size() == 1 and is_equal_approx(a.effects[0].age, 0.016), "Next pre-step does not emit or move late ball")
	a.effects_tick(0.09, h)
	check(h.calls.size() == 1, "Free ghost cooldown still active after90ms")
	a.tick(0.091, {}, h, true)
	a.effects_tick(0.091, h)
	check(h.calls.size() == 2, "Free ghost emits again after180ms")

	# One generic shot, no crate centering or per-crate duplication.
	h = Host.new()
	h.crates = [{"p": Vector2(440, 482), "hp": 3, "broken": false}, {"p": Vector2(440, 482), "hp": 3, "broken": false}]
	a.reset("theo")
	a.effects = [ball(Vector2(430, 452), Vector2(-620, 0))]
	a.effects_tick(0, h)
	check(h.calls.size() == 1 and h.calls[0].kind == "free", "Two overlapping crates still get exactly one generic free ghost")
	check(h.calls[0].point == Vector2(430, 452) and h.calls[0].direction == -1, "Ghost is not relocated to crate or current player-facing direction")
	check(h.crates[0].hp == 3 and h.crates[1].hp == 3, "Free ball cannot apply immediate crate damage")
	h.ghost_mode = false
	h.calls.clear()
	a.effects[0].free = 0
	a.effects_tick(0, h)
	check(h.calls.size() == 2 and h.calls[0].kind == "legacy_crate", "Host false return preserves legacy per-crate fallback")
	check(h.crates[0].hp == 2 and h.crates[1].hp == 2, "Other levels retain old direct crate damage")

	# Near-target ghosts are late too, and cooldowns do not create free zaps.
	h = Host.new()
	h.enemies = [enemy(440, "first"), enemy(440, "second")]
	a.reset("theo")
	a.effects = [ball(Vector2(440, 400), Vector2(620, 0))]
	a.tick(0.016, {}, h, true)
	check(h.calls.is_empty(), "Targeted ball ghosts are not emitted during pre-step")
	a.effects_tick(0, h)
	check(h.calls.size() == 2 and h.calls[0].kind == "enemy" and h.calls[1].kind == "enemy", "Source emits one targeted ghost per overlapping eligible enemy")
	check(h.enemies[0].hp == 20 and h.enemies[1].hp == 20, "Targeted ability callbacks only queue, no immediate HP loss")
	check(h.calls[0].point == Vector2(440, 426) and h.calls[0].damage == 2, "Enemy ghost targets feet minus56 with ball damage2")
	h.calls.clear()
	a.effects[0].v.x = 0.0
	a.effects_tick(0.1, h)
	check(h.calls.is_empty(), "Near enemy suppresses free ghost even during target cooldown")
	h = Host.new()
	h.boss = BossStub.new()
	a.reset("theo")
	a.effects = [ball(Vector2(500, 400), Vector2(620, 0))]
	a.tick(0.016, {}, h, true)
	check(h.calls.is_empty(), "Boss ball ghost waits for late effects")
	a.effects_tick(0, h)
	check(h.calls.size() == 1 and h.calls[0].kind == "boss" and h.calls[0].damage == 2, "Late ball targets boss once")
	check(a.effects[0].v.x == -620 and a.effects[0].boss_next == 0.3, "Boss target reverses ball and starts300ms timer before collision result")

	# Pre-specials see previous AB.t, late effects see advanced AB.t.
	h = Host.new()
	h.enemies = [enemy(430, "shield_target")]
	a.reset("maya")
	a.meter = 1.0
	a.request_special()
	a.tick(0.1, {}, h, true)
	check(h.calls.size() == 1 and h.calls[0].kind == "enemy", "Maya shield ghost is early, unlike ball")
	check(is_equal_approx(h.enemies[0].ab_shield_next, 0.35) and a._time == 0, "Shield cooldown based on old source clock")
	a.effects_tick(0.1, h)
	a.tick(0.25, {}, h, true)
	check(h.calls.size() == 1 and is_equal_approx(a._time, 0.1), "Current step delta does not prematurely satisfy pre-step shield cooldown")
	a.effects_tick(0.25, h)
	a.tick(0, {}, h, true)
	check(h.calls.size() == 2 and is_equal_approx(a._time, 0.35), "Shield emits at next pre-step after late clock reaches350ms")

	# Bubbles stay held through AI, then float/release and move to array end.
	h = Host.new()
	var first = enemy(430, "bubble_a")
	var normal = enemy(440, "normal")
	var second = enemy(450, "bubble_b")
	var popped = enemy(460, "popped")
	popped.state = "pop"
	first.merge({"ab_bubble": 0.05, "ab_bubble_total": 4.2, "ab_floor": 482.0})
	second.merge({"ab_bubble": 3.0, "ab_bubble_total": 4.2, "ab_floor": 482.0})
	popped.ab_bubble = 3.0
	h.enemies = [first, normal, second, popped]
	a.reset("ama")
	a.tick(0.1, {}, h, true)
	check(first.ab_bubble == 0.05 and first.p.y == 482 and h.calls.is_empty(), "Deferred pre-step does not release or move bubble before AI")
	a.bubbles_tick(0.1, h)
	check(first.ab_bubble == 0 and first.p.y == 482, "Bubble release restores original feet after AI")
	check(h.calls.size() == 1 and h.calls[0].point == Vector2(430, 426) and h.calls[0].damage == 1, "Bubble release sting queued before current projectile pass")
	check(first.hp == 20, "Bubble release does not directly damage held bot")
	check(is_equal_approx(first.flash, 0.1) and first.t == 5 and first.wait == 5.99, "Bubble hook decrements flash once without advancing AI/wait clocks")
	check(h.enemies.map(func(e): return e.tag) == ["normal", "popped", "bubble_a", "bubble_b"], "Held live bubbles append after unheld and popped bots in source order")
	check(popped.ab_bubble == 3.0, "Popped former bubbles are not held/released again")
	var expected_y: float = 482 - 44 + sin(450) * 5
	check(is_equal_approx(second.p.y, expected_y), "Bubble bob uses old ability clock before late increment")
	a.effects_tick(0.1, h)
	check(is_equal_approx(a._time, 0.1), "Bubble hook does not advance shared ability clock")
	h.calls.clear()
	a.bubbles_tick(0, h)
	check(h.calls.is_empty(), "Released bubble sting is not repeated")

	# Ama creation stays early and bubble countdown begins in the later hook.
	h = Host.new()
	h.enemies = [enemy(430, "new_bubble")]
	h.boss = BossStub.new()
	a.reset("ama")
	a.meter = 1.0
	a.request_special()
	a.tick(0.1, {}, h, true)
	check(h.enemies[0].ab_bubble == 4.2 and a.enemy_is_bubbled(h.enemies[0]), "Ama capture is available to upcoming AI but not yet decremented")
	check(h.calls.size() == 1 and h.calls[0].kind == "boss" and h.boss.state.dizzy == 3.5, "Ama boss zap/dizzy queued in pre-step")
	a.bubbles_tick(0.1, h)
	check(is_equal_approx(h.enemies[0].ab_bubble, 4.1), "Bubble timer starts at post-AI hook in activation frame")
	check(h.boss.state.hp == 260, "Queued Ama zap leaves HP to physical collision rules")

	# Non-deferred callers retain previous clock and combined effect behavior.
	h = Host.new()
	a.reset("theo")
	a.effects = [ball(Vector2(600, 200), Vector2(-620, 0))]
	a.tick(0.1, {}, h)
	check(is_equal_approx(a._time, 0.1) and is_equal_approx(a.effects[0].age, 0.1) and h.calls.size() == 1, "Default tick remains backward-compatible combined effects")
	a.reset("jp")
	a.meter = 1.0
	a.request_special()
	h = Host.new()
	a.tick(0.016, {}, h, true)
	check(h.bullets.size() == 1 and h.bullets[0].get("ab_rain", false) and not h.bullets[0].get("ghost", false), "Coin rain is a real early physical shot, not a deferred ghost")
	print("Ability ghost order: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)
