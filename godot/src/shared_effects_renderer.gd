extends RefCounted
## Original shared drawShot/drawBill and ability drawFx/drawAura. Pure command
## builders use existing clocks; they never advance simulation, RNG or effects.
const SPEC = preload("res://src/abilities.gd").SPEC
const SHOTS := {"jp": "coin", "maya": "flower", "ama": "bubble", "leo": "plane", "theo": "ball", "mei": "sweet"}
const RAINBOW := ["ff7eb6", "ffd23f", "7fd6ff", "9be37a", "c79be8", "ff9f5a"]
const INK := Color("14243b")
var submitted := 0

static func source_round(value: float) -> float: return floorf(value + 0.5)
static func _snap(host, p: Vector2) -> Vector2:
	return Vector2(source_round(p.x - host.camera.x), source_round(p.y))
static func shot_age(shot: Dictionary) -> float:
	if shot.has("age"): return maxf(0, shot.age)
	# W1 consumes life rather than storing a separate animation clock.
	var initial := 5.0 if str(shot.get("kind", "")) in ["rain", "plane"] and not shot.get("enemy", false) else 20.0
	return maxf(0, initial - float(shot.get("life", initial)))

func draw_shot(host, shot: Dictionary) -> void: draw_commands(host, build_shot(host, shot))
func draw_bill(host, bill: Dictionary) -> void: draw_commands(host, build_bill(host, bill))
func draw_fx(host, include_global := true) -> void: draw_commands(host, build_fx(host, include_global))
func draw_aura(host, behind: bool, feet: Vector2) -> void: draw_commands(host, build_aura(host, behind, feet))

func build_shot(host, shot: Dictionary) -> Array:
	if shot.get("ghost", false) or shot.get("ab_rain", false) or shot.get("dead", false): return []
	var out: Array = []
	var p := _snap(host, shot.p)
	var t := shot_age(shot)
	var velocity: Vector2 = shot.get("v", Vector2.ZERO)
	var kind := str(shot.get("kind", host.character))
	kind = str(SHOTS.get(kind, kind))
	match kind:
		"coin": _coin(out, p, 1.4, t / 0.05, "shot_coin")
		"flower":
			for j in 5:
				var angle := t / 0.09 + j * 1.2566
				var petal := Vector2(source_round(p.x + cos(angle) * 5), source_round(p.y + sin(angle) * 5))
				_rect(out, Rect2(petal - Vector2(3, 3), Vector2(6, 6)), Color("e07b1c"), "shot_flower_petal")
				_rect(out, Rect2(petal - Vector2(1, 2), Vector2(2, 2)), Color("ffb35c"), "shot_flower_light")
			_rect(out, Rect2(p - Vector2(2, 2), Vector2(5, 5)), Color("f4d266"), "shot_flower_center")
		"bubble":
			var radius := 7 + source_round(sin(t / 0.09))
			p.y = source_round(p.y + sin(t / 0.07) * 3)
			_circle(out, p, radius, Color(200 / 255.0, 230 / 255.0, 1, 0.35), "shot_bubble")
			_arc(out, p, Vector2.ONE * radius, 0, TAU, Color("a9d0f5"), 2, "shot_bubble_edge")
			_rect(out, Rect2(p + Vector2(-radius + 3, -radius + 3), Vector2(3, 3)), Color.WHITE, "shot_bubble_light")
			_rect(out, Rect2(p + Vector2(radius - 4, 1), Vector2(2, 3)), Color("e7a6e0"), "shot_bubble_pink")
		"plane":
			p.y = source_round(p.y + sin(t / 0.11) * 2)
			var rotation := atan2(velocity.y, 0.1 if absf(velocity.x) < 10 else absf(velocity.x)) * (-1 if velocity.x < 0 else 1)
			_plane(out, Transform2D(rotation, Vector2(-1 if velocity.x < 0 else 1, 1), 0, p), 1, "shot_plane")
		"ball":
			p.y = source_round(p.y - absf(sin(t / 0.08)) * 6)
			var transform := Transform2D(t / 0.06 * (-1 if velocity.x < 0 else 1), p)
			_circle(out, p, 7, Color.WHITE, "shot_ball")
			_arc(out, p, Vector2(7, 7), 0, TAU, INK, 1.5, "shot_ball_edge")
			_pentagon(out, transform, 3, 0, "shot_ball_patch")
			for j in 5:
				var angle := j * 1.2566 + 0.63
				_rect(out, Rect2(Vector2(source_round(cos(angle) * 6) - 1, source_round(sin(angle) * 6) - 1), Vector2(2, 2)), INK, "shot_ball_spot", transform)
		"sweet":
			# Preserve the source's signed remainder and &3 palette quirk.
			var index := int(fmod(floorf((float(shot.p.x) - host.camera.x) / 37 + float(shot.p.y) / 23), 5) + 5) & 3
			var colour := Color(RAINBOW[index])
			var transform := Transform2D(t / 0.07, p)
			_ellipse(out, Vector2.ZERO, Vector2(6, 4), colour, "shot_sweet", transform)
			_poly(out, [Vector2(-5, 0), Vector2(-10, -4), Vector2(-10, 4)], colour, "shot_sweet_wrap", transform)
			_poly(out, [Vector2(5, 0), Vector2(10, -4), Vector2(10, 4)], colour, "shot_sweet_wrap", transform)
			_rect(out, Rect2(-2, -2, 3, 2), Color(1, 1, 1, 0.7), "shot_sweet_light", transform)
			if (int(t * 1000) >> 5) % 2:
				_rect(out, Rect2(p + Vector2(-source_round(velocity.x * 0.014) + fmod(t * 7000, 5) - 2, fmod(t * 3000, 7) - 3), Vector2(2, 2)), Color.WHITE, "shot_sweet_sparkle")
	return _to_world(out, host)

func build_bill(host, bill: Dictionary) -> Array:
	if bill.get("dead", false): return []
	var out: Array = []
	var transform := Transform2D(shot_age(bill) / 0.09, _snap(host, bill.p))
	var rows: Array = [[Rect2(-14, -9, 28, 18), "3f7d4c"], [Rect2(-12, -7, 24, 14), "9fd18d"], [Rect2(-4, -4, 8, 8), "3f7d4c"], [Rect2(-14, -1, 28, 3), "e8d9a8"]] if bill.get("big", false) else [[Rect2(-9, -7, 18, 14), "4f8f5a"], [Rect2(-7, -5, 6, 4), "a8d79a"], [Rect2(1, 0, 6, 5), "a8d79a"], [Rect2(-3, -2, 6, 4), "2f5d3a"]]
	for row in rows: _rect(out, row[0], Color(row[1]), "enemy_bill", transform)
	return _to_world(out, host)

func build_fx(host, include_global := true) -> Array:
	var out: Array = []
	var time: float = host.abilities._time
	for shot in (host.bullets if include_global else []):
		if not shot.get("ab_rain", false) or shot.get("dead", false) or float(shot.get("life", 1)) <= 0: continue
		var p := _snap(host, shot.p)
		_gradient(out, Rect2(p - Vector2(3, 70), Vector2(6, 60)), Color(1, 230 / 255.0, 140 / 255.0, 0), Color(1, 230 / 255.0, 140 / 255.0, 0.85), true, "coin_rain_trail")
		_coin(out, p, 2.3, shot_age(shot) / 0.045, "coin_rain")
	for enemy in (host.enemies if include_global else []):
		var remaining: float = enemy.get("ab_bubble", 0)
		if remaining <= 0 or enemy.get("state", "") == "pop" or float(enemy.get("hp", 1)) <= 0: continue
		if remaining < 0.8 and int(remaining / 0.1) % 2: continue
		var p := _snap(host, enemy.p - Vector2(0, 62))
		var radius := 66 + sin(time / 0.2 + float(enemy.p.x)) * 3
		_circle(out, p, radius, Color(190 / 255.0, 230 / 255.0, 1, 0.22), "trapped_bubble")
		_arc(out, p, Vector2.ONE * radius, 0, TAU, Color(169 / 255.0, 208 / 255.0, 245 / 255.0, 0.95), 3, "trapped_bubble_edge")
		_arc(out, p, Vector2.ONE * (radius - 10), 3.6, 4.4, Color(1, 1, 1, 0.8), 4, "trapped_bubble_light")
		_rect(out, Rect2(p + Vector2(radius - 18, 10), Vector2(4, 6)), Color("e7a6e0"), "trapped_bubble_pink")
	for fx in host.abilities.effects:
		if fx.kind != "ball" or fx.get("dead", false): continue
		var trail: Array = fx.get("trail", [])
		for i in trail.size(): _circle(out, _snap(host, trail[i]), 20, Color(Color("7fe08f"), float(i + 1) / (trail.size() + 2) * 0.35), "ricochet_trail")
		var p := _snap(host, fx.p)
		var floor_y := _below(host, fx.p)
		if is_finite(floor_y) and floor_y - float(fx.p.y) < 300:
			_ellipse(out, Vector2(p.x, floor_y - 2), Vector2(20, 5), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.25), "ricochet_shadow")
		if float(fx.life) - float(fx.age) > 0.6 or int(float(fx.age) / 0.09) % 2:
			_football(out, p, 22, fx.spin)
	return _to_world(out, host)

func build_aura(host, behind: bool, feet: Vector2) -> Array:
	var out: Array = []
	if host.hearts <= 0 or host.mode not in ["play", "paused", "clear"]: return out
	var p := _snap(host, feet)
	var height: float = host.character_height()
	var center := p - Vector2(0, height * 0.5)
	var time: float = host.abilities._time
	var active := str(host.abilities.active) if host.abilities.remaining > 0 else ""
	var colour := Color(SPEC.get(host.character, SPEC.jp).color)
	if behind:
		if host.abilities.meter >= 1 and active.is_empty():
			_arc(out, p - Vector2(0, 2), Vector2(36, 9), 0, TAU, Color(colour, 0.45 + 0.3 * sin(time / 0.16)), 3, "special_ready_aura")
		if active == "maya": _circle(out, center, 84, Color(1, 143 / 255.0, 199 / 255.0, 0.16), "shield_back")
		if active == "mei":
			var running: bool = host.player_animation in ["run", "rundiag", "jump"]
			for i in 5:
				var y := source_round(p.y - height * (0.16 + i * 0.16))
				var length := (160 if running else 50) + sin(time / 0.07 + i * 1.7) * (40 if running else 12)
				var x0: float = p.x - host.face * 26
				var x1: float = x0 - host.face * length
				var solid_end: float = x0 + (x1 - x0) * 0.55
				var bright := Color(RAINBOW[i])
				_rect(out, Rect2(minf(x0, solid_end), y - 3, absf(x0 - solid_end), 7), bright, "sugar_rush_solid")
				_gradient(out, Rect2(minf(solid_end, x1), y - 3, absf(solid_end - x1), 7), Color(1, 1, 1, 0) if host.face > 0 else bright, bright if host.face > 0 else Color(1, 1, 1, 0), false, "sugar_rush_fade")
		return _to_world(out, host)
	if active == "maya" and not (host.abilities.remaining < 1 and int(host.abilities.remaining / 0.1) % 2):
		for j in 8:
			var angle := time / 0.38 + j * 0.785
			_flower(out, center + Vector2(cos(angle) * 76, sin(angle) * 70), Color("ff8fc7") if j % 2 else Color.WHITE)
		_arc(out, center, Vector2(84, 84), 0, TAU, Color(1, 190 / 255.0, 225 / 255.0, 0.7), 2, "shield_edge")
	if active == "leo":
		var top := p - Vector2(0, height + 4)
		var tilt: float = clampf(host.velocity.y * 0.0006, -0.3, 0.4) * host.face
		_line(out, PackedVector2Array([top + Vector2(-12, 6), top + Vector2(-8, height * 0.2)]), Color(20 / 255.0, 36 / 255.0, 59 / 255.0, 0.7), 2, "glider_string")
		_line(out, PackedVector2Array([top + Vector2(12, 6), top + Vector2(8, height * 0.2)]), Color(20 / 255.0, 36 / 255.0, 59 / 255.0, 0.7), 2, "glider_string")
		_plane(out, Transform2D(tilt, Vector2(host.face * 5.6, 2.8), 0, top), 1.4, "glider")
	if host.movement_skills.ground_pounding:
		for i in range(-1, 2): _rect(out, Rect2(p.x + i * 16 - 2, p.y - height - 50 - fmod(time * 1000 / 3 + i * 20, 30), 4, 26), Color(1, 1, 1, 0.75), "ground_pound_streak")
	return _to_world(out, host)

func _to_world(commands: Array, host) -> Array:
	# Source snaps after horizontal camera subtraction, and translates by rounded
	# camera Y. Main uses an exact world transform, so compensate only at the end.
	var offset := Vector2(host.camera.x, host.camera.y - source_round(host.camera.y))
	for command in commands:
		if command.has("rect"): command.rect.position += offset
		if command.has("position"): command.position += offset
		if command.has("points"): command.points = Transform2D(0, offset) * command.points
	return commands

func _below(host, p: Vector2) -> float:
	if host.is_native_supported():
		var surface: Dictionary = host.scene_runtime.below(host, p.x, p.y)
		return float(surface.row[2]) if not surface.is_empty() else INF
	var floor_y := INF
	for row in host.level.get("solids", []) + host.level.get("plats", []):
		if p.x >= row[0] and p.x <= row[1] and row[2] >= p.y - 2: floor_y = minf(floor_y, row[2])
	return floor_y

func _football(out: Array, p: Vector2, radius: float, spin: float) -> void:
	var transform := Transform2D(spin, p)
	_circle(out, p, radius, Color.WHITE, "ricochet_ball")
	_arc(out, p, Vector2.ONE * radius, 0, TAU, INK, 3, "ricochet_edge")
	_pentagon(out, transform, radius * 0.42, -1.57, "ricochet_patch")
	for j in 5:
		var angle := j * 1.2566 + 0.63 - 1.57
		_circle(out, transform * Vector2(cos(angle) * radius * 0.86, sin(angle) * radius * 0.86), radius * 0.22, INK, "ricochet_spot")
	_circle(out, transform * Vector2(-radius * 0.35, -radius * 0.45), radius * 0.18, Color(1, 1, 1, 0.55), "ricochet_light")

func _flower(out: Array, p: Vector2, colour: Color) -> void:
	for j in 5:
		var angle := j * 1.2566
		_rect(out, Rect2(Vector2(source_round(p.x + cos(angle) * 5) - 3, source_round(p.y + sin(angle) * 5) - 3), Vector2(6, 6)), colour, "shield_flower_petal")
	_rect(out, Rect2(Vector2(source_round(p.x) - 2, source_round(p.y) - 2), Vector2(5, 5)), Color("ffd23f"), "shield_flower_center")

func _plane(out: Array, transform: Transform2D, width: float, tag: String) -> void:
	var points := PackedVector2Array([Vector2(11, 0), Vector2(-9, -7), Vector2(-4, 0), Vector2(-9, 7)])
	_poly(out, points, Color.WHITE, tag, transform)
	_poly(out, [Vector2(11, 0), Vector2(-4, 0), Vector2(-9, 7)], Color("c7d0dc"), tag + "_fold", transform)
	var line := transform * points; line.append(line[0]); _line(out, line, INK, width, tag + "_edge")

func _pentagon(out: Array, transform: Transform2D, radius: float, angle: float, tag: String) -> void:
	var points := PackedVector2Array()
	for j in 5: points.append(Vector2(cos(j * 1.2566 + angle), sin(j * 1.2566 + angle)) * radius)
	_poly(out, points, INK, tag, transform)

func _coin(out: Array, p: Vector2, scale: float, phase: float, tag: String) -> void:
	var width: float = [12, 9, 4, 9][int(phase) % 4] * scale
	var height := 12 * scale
	_rect(out, Rect2(source_round(p.x - width / 2 - scale), source_round(p.y - height / 2 - scale), source_round(width + 2 * scale), source_round(height + 2 * scale)), Color("7a5410"), tag + "_edge")
	_rect(out, Rect2(source_round(p.x - width / 2), source_round(p.y - height / 2), source_round(width), source_round(height)), Color("f4c542"), tag)
	if width > 5 * scale:
		_rect(out, Rect2(source_round(p.x - width / 2 + scale), source_round(p.y - height / 2 + scale), source_round(2 * scale), source_round(5 * scale)), Color("fff1a8"), tag + "_light")
		_rect(out, Rect2(source_round(p.x - scale), source_round(p.y - 3 * scale), source_round(2 * scale), source_round(6 * scale)), Color("c99a1d"), tag + "_mark")

func _rect(out: Array, rect: Rect2, colour: Color, tag: String, transform := Transform2D.IDENTITY) -> void:
	if not rect.has_area(): return
	if transform == Transform2D.IDENTITY: out.append({"type": "rect", "rect": rect, "colour": colour, "tag": tag})
	else: _poly(out, [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)], colour, tag, transform)
func _poly(out: Array, points, colour: Color, tag: String, transform := Transform2D.IDENTITY) -> void:
	out.append({"type": "polygon", "points": transform * PackedVector2Array(points), "colour": colour, "tag": tag})
func _circle(out: Array, center: Vector2, radius: float, colour: Color, tag: String) -> void:
	out.append({"type": "circle", "position": center, "radius": radius, "colour": colour, "tag": tag})
func _ellipse(out: Array, center: Vector2, radii: Vector2, colour: Color, tag: String, transform := Transform2D.IDENTITY) -> void:
	var points := PackedVector2Array()
	for i in 48: points.append(center + Vector2(cos(TAU * i / 48), sin(TAU * i / 48)) * radii)
	_poly(out, points, colour, tag, transform)
func _line(out: Array, points: PackedVector2Array, colour: Color, width: float, tag: String) -> void:
	out.append({"type": "line", "points": points, "colour": colour, "width": width, "tag": tag})
func _arc(out: Array, center: Vector2, radii: Vector2, start: float, finish: float, colour: Color, width: float, tag: String) -> void:
	var points := PackedVector2Array()
	for i in 49:
		var angle := start + (finish - start) * i / 48
		points.append(center + Vector2(cos(angle), sin(angle)) * radii)
	_line(out, points, colour, width, tag)
func _gradient(out: Array, rect: Rect2, start: Color, finish: Color, vertical: bool, tag: String) -> void:
	out.append({"type": "gradient", "points": PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]), "colours": PackedColorArray([start, start if vertical else finish, finish, finish if vertical else start]), "tag": tag})
func draw_commands(canvas: CanvasItem, commands: Array) -> void:
	for c in commands:
		match c.type:
			"rect": canvas.draw_rect(c.rect, c.colour)
			"polygon": canvas.draw_colored_polygon(c.points, c.colour)
			"gradient": canvas.draw_polygon(c.points, c.colours)
			"circle": canvas.draw_circle(c.position, c.radius, c.colour, true, -1, true)
			"line": canvas.draw_polyline(c.points, c.colour, c.width, true)
		submitted += 1
