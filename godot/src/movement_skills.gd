extends RefCounted
## Source stage variants are deliberate: own world mechanics override shared cards.
const ALL = ["slide", "double-jump", "ground-pound", "dash", "wall-jump", "super"]
const HEIGHTS = {"jp": 180.0, "maya": 162.0, "ama": 171.0, "leo": 187.0, "theo": 178.0, "mei": 160.0}
const CARDS = {
	"1-4": {"skill": "slide", "p": Vector2(8497, 442)},
	"2-5": {"skill": "double-jump", "p": Vector2(8850, 232)},
	"3-4": {"skill": "ground-pound", "p": Vector2(5700, -358)},
	"4-4": {"skill": "dash", "p": Vector2(11710, 342)},
	"5-4": {"skill": "wall-jump", "p": Vector2(3560, 482)},
	"6-4": {"skill": "super", "p": Vector2(369, -5632)},
}
var skills: Array = []
var stage := "1-1"
var world := 1
var slide_remaining := 0.0
var dash_remaining := 0.0
var dash_cooldown := 0.0
var ground_pounding := false
var double_jumped := false
var effects: Array = []
var events: Array[String] = []
var card_collected := false
var time := 0.0
var _run_time := 0.0
var _jump_held := false
var _down_held := false
var _left_held := false
var _right_held := false
var _dash_held := false
var _left_t := -1e9
var _right_t := -1e9
var _wall_time := 0.0
var _wall_direction := 0
var _pre_grounded := true
var _pre_vy := 0.0
var _fresh_jump := false
var _fresh_down := false
var _controls: Dictionary = {}
var _dt := 0.0

func reset(level_id: String, unlocked: Array = []) -> void:
	stage = level_id
	world = int(level_id.get_slice("-", 0))
	skills = []
	for skill in unlocked:
		if skill in ALL and skill not in skills: skills.append(skill)
	slide_remaining = 0
	dash_remaining = 0
	dash_cooldown = 0
	ground_pounding = false
	double_jumped = false
	effects.clear()
	events.clear()
	card_collected = false
	time = 0
	_run_time = 0
	_jump_held = false
	_down_held = false
	_left_held = false
	_right_held = false
	_dash_held = false
	_left_t = -1e9
	_right_t = -1e9
	_wall_time = 0
	_wall_direction = 0

func has_skill(skill: String) -> bool:
	return skill in skills

func collect_card(feet: Vector2, character: String, alive := true) -> String:
	# Host calls at its source pickup phase; returns skill for persistence/UI.
	if not alive or card_collected or not CARDS.has(stage): return ""
	var card: Dictionary = CARDS[stage]
	var h: float = HEIGHTS.get(character, 180.0)
	var dx: float = absf(feet.x - card.p.x)
	var near := false
	match world:
		1, 4: near = dx < 42 and feet.y > card.p.y - 120 and feet.y - h < card.p.y
		2: near = dx < 42 and feet.y > card.p.y - 30 and feet.y - h < card.p.y
		3: near = dx < 42 and card.p.y > feet.y - h - 10 and card.p.y < feet.y + 20
		5: near = dx < 44 and absf(feet.y - card.p.y) < 110
		6: near = dx < 44 and absf(feet.y - h * 0.5 - card.p.y) < h * 0.6
	if not near: return ""
	card_collected = true
	if card.skill not in skills: skills.append(card.skill)
	events.append("card:" + card.skill)
	return card.skill

func begin_step(dt: float, controls: Dictionary, host) -> void:
	# Before ordinary horizontal movement/jumping, after normal lock timer decrement.
	_dt = dt
	time += dt
	_controls = controls.duplicate()
	_pre_grounded = host.grounded
	_pre_vy = host.velocity.y
	_fresh_jump = controls.get("jump", false) and not _jump_held
	_fresh_down = controls.get("down", false) and not _down_held
	events.clear()
	for effect in effects: effect.age += dt
	effects = effects.filter(func(e): return e.age < e.life)

func jump_step(host, wall_hit: int = 0) -> void:
	# After normal ground jump/drop and horizontal collision, BEFORE gravity.
	# wall_hit must be real movement collision, excluding camera-edge clamps.
	var locked: bool = host.hurt_lock > 0
	if world == 5 and has_skill("wall-jump") and not _pre_grounded and not host.grounded and _fresh_jump and not locked and wall_hit != 0:
		host.velocity.y = -960.0
		host.velocity.x = -wall_hit * 220.0
		host.face = -wall_hit
		events.append("wall-jump")
	if world == 2 and has_skill("double-jump"):
		if host.grounded: double_jumped = false
		elif _fresh_jump and not _controls.get("down", false) and not locked and not double_jumped and host.velocity.y > -900.0:
			double_jumped = true
			host.velocity.y = -860.0
			events.append("double-jump")

func post_step(host, active_special: String = "", animation: String = "", cpu := false) -> void:
	# After normal player movement AND the housemate special/passive post hook.
	var locked: bool = host.hurt_lock > 0
	var mv := 0 if locked else int(_controls.get("right", false)) - int(_controls.get("left", false))
	if has_skill("slide") and world != 1: _slide(host, animation, false)
	var kicked := false
	if has_skill("wall-jump") and world != 5 and not host.grounded and not locked:
		var wall := 0
		if mv:
			var to_x: float = host.player.x + mv * 8
			if absf(host.skill_wall_clamp(host.player.x, to_x, host.player.y - 90) - to_x) > 0.5: wall = mv
		if wall:
			host.velocity.y = minf(host.velocity.y, 220)
			_wall_time = 0.14
			_wall_direction = wall
		else: _wall_time = maxf(0.0, _wall_time - _dt)
		if _wall_time > 0 and _fresh_jump and host.velocity.y >= _pre_vy - 300:
			host.velocity.y = -950
			host.velocity.x = -_wall_direction * 550
			host.face = -_wall_direction
			_wall_time = 0
			double_jumped = false
			kicked = true
			events.append("wall-jump")
	if has_skill("double-jump") and world != 2:
		if host.grounded: double_jumped = false
		elif not kicked and _fresh_jump and not locked and not double_jumped and not _pre_grounded and host.velocity.y >= _pre_vy - 300 and host.velocity.y > -900:
			double_jumped = true
			host.velocity.y = -860
			events.append("double-jump")
	if has_skill("ground-pound") and active_special != "leo":
		if not ground_pounding and not _pre_grounded and not host.grounded and _fresh_down and not _controls.get("jump", false) and not locked and host.velocity.y > -700:
			var floor_y: float = host.skill_floor_below(host.player.x, host.player.y + 2)
			if not is_finite(floor_y) or floor_y - host.player.y > 70:
				ground_pounding = true
				host.velocity.y = 1400
				host.velocity.x = 0
				events.append("ground-pound-start")
		if ground_pounding:
			if host.grounded:
				ground_pounding = false
				_pound(host)
			elif locked: ground_pounding = false
			else: host.velocity.y = maxf(host.velocity.y, 1400)
	if has_skill("dash") and world != 4 and not cpu: _dash(host, false)
	dash_remaining = maxf(0.0, dash_remaining - _dt)
	_jump_held = _controls.get("jump", false)
	_down_held = _controls.get("down", false)

func late_step(host, animation: String = "", cpu := false) -> void:
	# After normal combat/enemy updates and world pickup collection.
	if has_skill("slide") and world == 1: _slide(host, animation, true)
	if has_skill("dash") and world == 4 and not cpu: _dash(host, true)

func blocks_damage() -> bool:
	# World-owned variants use host.invincible instead, as in their source.
	return (world != 1 and slide_remaining > 0) or (world != 4 and dash_remaining > 0)

func cancel_on_death() -> void:
	ground_pounding = false

func _live(enemy: Dictionary) -> bool:
	return enemy.get("state", "") != "pop" and not enemy.get("lost", false)

func _slide(host, animation: String, own: bool) -> void:
	if slide_remaining <= 0 and _controls.get("down", false) and host.grounded and (_controls.get("left", false) or _controls.get("right", false)) and _run_time > 0.12 and host.hurt_lock <= 0:
		slide_remaining = 0.42
		host.face = 1 if _controls.get("right", false) else -1
		events.append("slide")
	_run_time = _run_time + _dt if animation in ["run", "rundiag"] else 0.0
	if slide_remaining > 0:
		slide_remaining = maxf(0.0, slide_remaining - _dt)
		host.velocity.x = host.face * 620.0 * (slide_remaining / 0.42 + 0.2)
		if own: host.invincible = maxf(host.invincible, 0.06)
		for enemy in host.enemies:
			if _live(enemy) and not enemy.get("fly", false) and absf(enemy.p.x - host.player.x) < 50 and absf(enemy.p.y - host.player.y) < 30:
				if own:
					# Own world subtracts directly, unlike the shared invisible shot.
					host.skill_slide_hit(enemy, 1 if enemy.get("big", false) else 3, host.face * 30.0)
				elif enemy.get("skill_slide_next", 0.0) <= time:
					enemy.skill_slide_next = time + 0.4
					host.damage_enemy(enemy, 1 if enemy.get("big", false) else 3)
		if slide_remaining <= 0: host.velocity.x = 0

func _dash(host, own: bool) -> void:
	dash_cooldown -= _dt
	var right: bool = _controls.get("right", false)
	var left: bool = _controls.get("left", false)
	var button: bool = _controls.get("dash", false)
	var go := 0
	if right and not _right_held:
		if time - _right_t < 0.26: go = 1
		_right_t = time
	if left and not _left_held:
		if time - _left_t < 0.26: go = -1
		_left_t = time
	if button and not _dash_held: go = host.face
	_right_held = right
	_left_held = left
	_dash_held = button
	if go and dash_cooldown <= 0 and (own or host.hurt_lock <= 0):
		dash_cooldown = 0.6 if own else 0.65
		host.face = go
		host.velocity.x = go * 1100.0
		if own: host.invincible = maxf(host.invincible, 0.26)
		else: dash_remaining = 0.26
		events.append("dash")

func _pound(host) -> void:
	var power := 1.5 if has_skill("super") else 1.0
	for enemy in host.enemies:
		if _live(enemy) and absf(enemy.p.x - host.player.x) < 170 * power and absf(enemy.p.y - host.player.y) < 80: host.damage_enemy(enemy, 3)
	if host.boss != null:
		var boss: Dictionary = host.boss.state
		if boss.get("state", "") not in ["down", "enter"] and boss.get("hp", 0) > 0 and absf(boss.x - host.player.x) < 210 and absf(boss.fy - host.player.y) < 140: host.damage_boss(3)
	for crate in host.crates:
		if not crate.get("broken", false) and absf(crate.p.x - host.player.x) < 140 and absf(crate.p.y - host.player.y) < 70: host.hit_crate(crate, 3)
	effects.append({"kind": "ring", "p": host.player, "age": 0.0, "life": 0.38})
	events.append("ground-pound-land")
