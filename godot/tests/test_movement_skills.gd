extends SceneTree
const Skills = preload("res://src/movement_skills.gd")
class BossStub:
	extends RefCounted
	var state := {"state": "idle", "hp": 40, "x": 500.0, "fy": 482.0}
class Host:
	extends RefCounted
	var player := Vector2(400, 482)
	var velocity := Vector2.ZERO
	var grounded := true
	var face := 1
	var hurt_lock := 0.0
	var invincible := 0.0
	var enemies: Array = []
	var crates: Array = []
	var boss = null
	var wall := false
	var floor_y := 482.0
	func skill_wall_clamp(_from_x, to_x, _feet): return to_x - 8 if wall else to_x
	func skill_floor_below(_x, _y): return floor_y
	func damage_enemy(e, d): e.hp -= d
	func damage_boss(d): boss.state.hp -= d
	func hit_crate(c, d): c.hp -= d
	func skill_slide_hit(e, d, shove):
		e.hp -= d
		e.p.x += shove
		e.flash = 0.09
var failures: Array[String] = []
var count := 0
func check(ok: bool, label: String) -> void:
	count += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: " + label)
func enemy(p: Vector2, big := false, fly := false) -> Dictionary:
	return {"p": p, "hp": 30, "state": "walk", "big": big, "fly": fly}
func step(s, h, dt: float, controls: Dictionary, animation := "", active := "", cpu := false):
	s.begin_step(dt, controls, h)
	s.jump_step(h)
	s.post_step(h, active, animation, cpu)
	s.late_step(h, animation, cpu)
func _initialize() -> void:
	var s = Skills.new()
	var h = Host.new()
	s.reset("6-6")
	check(s.skills.is_empty(), "entering late world grants nothing")
	step(s, h, 0.1, {"dash": true, "jump": true, "down": true, "right": true}, "run")
	check(h.velocity == Vector2.ZERO and not s.blocks_damage(), "locked cards never act")
	check(s.collect_card(Vector2(369, -5632), "jp").is_empty(), "no card on wrong stage")
	for stage in Skills.CARDS:
		s.reset(stage)
		var card: Dictionary = Skills.CARDS[stage]
		check(s.collect_card(card.p + Vector2(100, 0), "jp").is_empty(), stage + " horizontal pickup boundary")
		check(s.collect_card(card.p, "jp", false).is_empty(), stage + " dead player cannot collect")
		check(s.collect_card(card.p, "jp") == card.skill, stage + " source pickup unlock")
		check(s.has_skill(card.skill), stage + " unlocked on actual pickup")
		check(s.collect_card(card.p, "jp").is_empty(), stage + " collected only once per run")
	s.reset("1-4")
	check(s.collect_card(Vector2(8497 + 42, 442), "jp").is_empty(), "pickup comparisons strict")
	s.reset("2-5")
	check(s.collect_card(Vector2(8850, 202), "jp").is_empty(), "World 2 narrow vertical threshold strict")
	s.reset("5-4")
	check(s.collect_card(Vector2(3560, 592), "jp").is_empty(), "World 5 pickup feet tolerance strict")
	s.reset("6-4")
	check(s.collect_card(Vector2(369, -5632 + 90 + 108), "jp").is_empty(), "World 6 pickup centered on body")
	# Shared slide: run-up, duration, repeat timer, no direct knockback.
	h = Host.new()
	h.enemies = [enemy(Vector2(410, 482)), enemy(Vector2(410, 482), true), enemy(Vector2(410, 482), false, true)]
	s.reset("3-1", ["slide"])
	step(s, h, 0.12, {"right": true}, "run")
	step(s, h, 0.001, {"right": true, "down": true}, "run")
	check(s.slide_remaining == 0, "slide requires strictly over 120ms run")
	step(s, h, 0.01, {"right": true, "down": true}, "crouch")
	check(is_equal_approx(s.slide_remaining, 0.41), "slide 420ms minus current frame")
	check(is_equal_approx(h.velocity.x, 620 * (0.41 / 0.42 + 0.2)), "source slide speed envelope")
	check(h.enemies[0].hp == 27 and h.enemies[1].hp == 29 and h.enemies[2].hp == 30, "slide 3 normal 1 big no flying")
	check(s.blocks_damage() and h.invincible == 0, "shared slide protects via damage hook")
	step(s, h, 0.01, {}, "idle")
	check(h.enemies[0].hp == 27, "shared slide hit cooldown")
	step(s, h, 0.41, {}, "idle")
	check(s.slide_remaining == 0 and h.velocity.x == 0, "slide expires and clears horizontal impulse")
	# World 1 local variant direct per-frame damage and shove.
	h = Host.new()
	h.enemies = [enemy(Vector2(400, 482))]
	s.reset("1-1", ["slide"])
	step(s, h, 0.13, {"right": true}, "run")
	step(s, h, 0.01, {"right": true, "down": true}, "crouch")
	check(h.enemies[0].hp == 27 and h.enemies[0].p.x == 430 and h.invincible == 0.06, "World 1 slide shove and invulnerability")
	step(s, h, 0.01, {}, "idle")
	check(h.enemies[0].hp == 24 and h.enemies[0].p.x == 460, "World 1 no per-target hit cooldown")
	check(not s.blocks_damage(), "World 1 uses normal invulnerability only")
	# Air jump gates, once per airtime and ground reset.
	h = Host.new()
	h.grounded = false
	s.reset("3-1", ["double-jump"])
	step(s, h, 0.01, {"jump": true})
	check(h.velocity.y == -860 and s.double_jumped, "shared double jump impulse")
	step(s, h, 0.01, {})
	h.velocity.y = 100
	step(s, h, 0.01, {"jump": true})
	check(h.velocity.y == 100, "double jump only once airborne")
	h.grounded = true
	step(s, h, 0.01, {})
	check(not s.double_jumped, "landing resets double jump")
	s.begin_step(0.01, {"jump": true}, h)
	h.grounded = false
	h.velocity.y = -980
	s.jump_step(h)
	s.post_step(h)
	check(not s.double_jumped and h.velocity.y == -980, "normal launch not mistaken for double jump")
	for world in ["2-1", "3-1"]:
		h = Host.new()
		h.grounded = false
		s.reset(world, ["double-jump"])
		step(s, h, 0.01, {"jump": true, "down": true})
		check(s.double_jumped == (world == "3-1"), world + " down+jump source variant")
	# Shared wall slide/coyote and distinct World 5 collision kick.
	h = Host.new()
	h.grounded = false
	h.wall = true
	h.velocity.y = 500
	s.reset("3-1", ["wall-jump", "double-jump"])
	step(s, h, 0.01, {"right": true})
	check(h.velocity.y == 220, "shared wall slide caps fall")
	h.wall = false
	step(s, h, 0.1, {"jump": true})
	check(h.velocity == Vector2(-550, -950) and not s.double_jumped, "shared 140ms wall coyote beats double jump")
	h = Host.new()
	h.grounded = false
	s.reset("5-1", ["wall-jump"])
	s.begin_step(0.01, {"jump": true, "right": true}, h)
	s.jump_step(h, 1)
	check(h.velocity == Vector2(-220, -960) and h.face == -1, "World 5 real-wall impulse before gravity")
	s.post_step(h)
	check(h.velocity == Vector2(-220, -960), "World 5 shared wall behavior suppressed")
	h = Host.new()
	h.grounded = false
	h.wall = true
	h.velocity.y = 700
	s.reset("5-1", ["wall-jump"])
	step(s, h, 0.01, {"right": true})
	check(h.velocity.y == 700, "World 5 has no shared wall slide")
	# Ground pound selection and shockwave geometry.
	h = Host.new()
	h.grounded = false
	h.player.y = 200
	h.enemies = [enemy(Vector2(569, 482)), enemy(Vector2(570, 482)), enemy(Vector2(400, 562))]
	h.crates = [{"p": Vector2(539, 482), "hp": 5, "broken": false}, {"p": Vector2(540, 482), "hp": 5, "broken": false}]
	h.boss = BossStub.new()
	s.reset("3-1", ["ground-pound"])
	step(s, h, 0.01, {"down": true})
	check(s.ground_pounding and h.velocity == Vector2(0, 1400), "ground pound starts above floor")
	h.velocity.y = 500
	step(s, h, 0.01, {})
	check(h.velocity.y == 1400, "ground pound maintains minimum descent")
	h.grounded = true
	h.player.y = 482
	step(s, h, 0.01, {})
	check(not s.ground_pounding and h.enemies[0].hp == 27 and h.enemies[1].hp == 30 and h.enemies[2].hp == 30, "pound strict enemy radius/height")
	check(h.crates[0].hp == 2 and h.crates[1].hp == 5 and h.boss.state.hp == 37, "pound crate and boss damage")
	check(s.effects.size() == 1 and s.effects[0].life == 0.38, "pound ring effect")
	for mode in ["floor", "ascent", "glider", "locked"]:
		h = Host.new()
		h.grounded = false
		h.player.y = 200
		if mode == "floor": h.floor_y = 270
		if mode == "ascent": h.velocity.y = -700
		if mode == "locked": h.hurt_lock = 0.1
		s.reset("3-1", ["ground-pound"])
		step(s, h, 0.01, {"down": true}, "", "leo" if mode == "glider" else "")
		check(not s.ground_pounding, "pound blocked: " + mode)
	h = Host.new()
	h.grounded = false
	h.player.y = 200
	h.floor_y = INF
	s.reset("3-1", ["ground-pound", "super"])
	step(s, h, 0.01, {"down": true})
	check(s.ground_pounding, "pound allowed over gap")
	h.grounded = true
	h.player.y = 482
	h.enemies = [enemy(Vector2(654, 482)), enemy(Vector2(655, 482))]
	step(s, h, 0.01, {})
	check(h.enemies[0].hp == 27 and h.enemies[1].hp == 30, "super scales enemy shockwave radius only")
	# Dash edge/double tap/cooldowns and World 4 lock exception.
	for stage in ["3-1", "4-1"]:
		h = Host.new()
		s.reset(stage, ["dash"])
		step(s, h, 0.01, {"right": true})
		check(h.velocity.x == 0, stage + " first tap no dash")
		step(s, h, 0.1, {})
		step(s, h, 0.1, {"right": true})
		check(h.velocity.x == 1100, stage + " second tap dash")
		check(is_equal_approx(s.dash_cooldown, 0.6 if stage == "4-1" else 0.65), stage + " cooldown variant")
		check(h.invincible == 0.26 if stage == "4-1" else s.blocks_damage(), stage + " invulnerability variant")
		h.velocity.x = 0
		step(s, h, 0.01, {"dash": true})
		check(h.velocity.x == 0, stage + " cooldown refuses retrigger")
		s.reset(stage, ["dash"])
		h.hurt_lock = 1
		step(s, h, 0.01, {"dash": true})
		check((h.velocity.x == 1100) == (stage == "4-1"), stage + " hurt lock source variant")
	h = Host.new()
	s.reset("3-1", ["dash"])
	step(s, h, 0.01, {"dash": true}, "", "", true)
	check(h.velocity.x == 0, "CPU cannot use dash")
	s.reset("3-1", ["dash"])
	step(s, h, 0.01, {"right": true})
	step(s, h, 0.3, {})
	step(s, h, 0.01, {"right": true})
	check(h.velocity.x == 0, "slow double tap rejected")
	print("Movement skills: %d checks, %d failures" % [count, failures.size()])
	quit(0 if failures.is_empty() else 1)
