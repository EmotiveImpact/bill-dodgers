extends "res://src/festival_renderer.gd"
## Actual W4 fallback art: procedural flamingo, original thief rider and hat.
## There are no captain/jetbot sheets in the authored W4 metadata. Parent
## contributes drawing primitives and sprite crops only; no festival scenes.

func supports(id: String) -> bool:
	return id == "4-6"

func _captain_owner(host, runtime):
	return _state(runtime, "captain", _state(runtime, "boss", _state(host, "boss", null)))

func _boss(host, runtime) -> Dictionary:
	var owner = _captain_owner(host, runtime)
	if owner == null: return {}
	if owner is Dictionary:
		if owner.get("boss") is Dictionary: return owner.boss
		if owner.get("state") is Dictionary: return owner.state
		return owner
	return owner.boss

static func captain_pose(b: Dictionary) -> Dictionary:
	var time := float(b.get("t", 0))
	var down: bool = b.state == "down"
	var rear := minf(1, time / 0.4) * 0.18 if b.state == "rear" else 0.0
	return {"bob": 0.0 if down else sin(time / 0.3) * 6,
		"rotation": -rear if b.face < 0 else rear,
		"scale": 1 - float(b.get("sink", 0)) * 0.35,
		"alpha": maxf(0, 1 - maxf(0, time - 2.6) / 1.2) if down else 1.0,
		"mirror": 1 if b.face < 0 else -1,
		"animation": "throw" if b.state == "throw" else "run",
		"frame": mini(3, int(floorf(time / 0.16))) if b.state == "throw" else 0}

func _shape_rect(out: Array, rectangle: Rect2, colour: Color, tag: String, transform: Transform2D) -> void:
	_poly(out, [rectangle.position, Vector2(rectangle.end.x, rectangle.position.y), rectangle.end, Vector2(rectangle.position.x, rectangle.end.y)], colour, tag, transform)
	out[-1].local_rect = rectangle
	out[-1].transform = transform

func _shape_ellipse(out: Array, center: Vector2, radius: Vector2, colour: Color, tag: String, transform: Transform2D) -> void:
	var points: Array = []
	for i in 64: points.append(center + Vector2(cos(i * TAU / 64), sin(i * TAU / 64)) * radius)
	_poly(out, points, colour, tag, transform)
	out[-1].local_center = center
	out[-1].local_radius = radius
	out[-1].transform = transform

func build_boss(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var b := _boss(host, runtime)
	if b.is_empty(): return []
	var c := _context(host)
	var pose := captain_pose(b)
	var origin := Vector2(_x(c, float(b.x)), source_round(float(b.y) + pose.bob) + float(c.y_snap))
	var outer := Transform2D(pose.rotation, Vector2.ONE * pose.scale, 0, origin)
	var shape := outer * Transform2D(0, Vector2(pose.mirror, 1), 0, Vector2.ZERO)
	var out: Array = []
	var pink := Color(Color("ff7eb6"), pose.alpha)
	_shape_ellipse(out, Vector2(0, -60), Vector2(150, 60), pink, "captain_flamingo_body", shape)
	_shape_ellipse(out, Vector2(-10, -78), Vector2(110, 30), Color(Color("ff9fca"), pose.alpha), "captain_flamingo_highlight", shape)
	var neck := PackedVector2Array()
	for i in 33:
		var t := i / 32.0
		neck.append(shape * ((1 - t) * (1 - t) * Vector2(-110, -80) + 2 * (1 - t) * t * Vector2(-190, -170) + t * t * Vector2(-150, -250)))
	out.append({"type": "line", "points": neck, "colour": pink, "width": 28 * pose.scale, "tag": "captain_flamingo_neck"})
	_shape_ellipse(out, Vector2(-140, -262), Vector2.ONE * 30, pink, "captain_flamingo_head", shape)
	_shape_rect(out, Rect2(-150, -272, 8, 8), Color(Color("14243b"), pose.alpha), "captain_flamingo_eye", shape)
	_poly(out, [Vector2(-168, -258), Vector2(-206, -240), Vector2(-166, -244)], Color(Color("f5f1ea"), pose.alpha), "captain_flamingo_beak", shape)
	_poly(out, [Vector2(-200, -243), Vector2(-206, -240), Vector2(-196, -236)], Color(Color("14243b"), pose.alpha), "captain_flamingo_beak_tip", shape)
	_shape_rect(out, Rect2(64, -126, 16, 20), Color(Color("c9a227"), pose.alpha), "captain_valve_stem", shape)
	_shape_rect(out, Rect2(60, -132, 24, 8), Color(Color("f4c542"), pose.alpha), "captain_valve_cap", shape)
	# drawSprite sets globalAlpha=1 inside the source fallback, so the rider
	# intentionally stays opaque while the surrounding flamingo/hat fade.
	var local_context := c.duplicate()
	local_context.camera = Vector2.ZERO
	local_context.y_snap = 0.0
	for rider: Dictionary in _sprite_commands(host, local_context, "thief", pose.animation, pose.frame, Vector2(10 * pose.mirror, -96), -int(pose.mirror), 1, "", float(b.get("flash", 0)) > 0, "captain_rider"):
		var r: Rect2 = rider.rect
		rider.type = "captain_rider"
		rider.transform = outer
		rider.points = outer * PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		out.append(rider)
	for row in [[Rect2(-38 + 10 * pose.mirror, -350, 76, 18), "f5f1ea", "brim"], [Rect2(-26 + 10 * pose.mirror, -372, 52, 24), "f5f1ea", "crown"], [Rect2(-38 + 10 * pose.mirror, -338, 76, 6), "14243b", "band"], [Rect2(-6 + 10 * pose.mirror, -366, 12, 10), "f4c542", "badge"]]:
		_shape_rect(out, row[0], Color(Color(row[1]), pose.alpha), "captain_hat_" + row[2], outer)
	if int(b.phase) == 3 and b.state != "down":
		# The source highlight sits outside body rotation and pixel snapping.
		var center := Vector2(float(b.x) + 70 * pose.mirror * pose.scale, float(b.y) + pose.bob - 120 * pose.scale + float(c.y_snap))
		var time := float(_state(runtime, "elapsed", _state(runtime, "level_time", host.elapsed)))
		var radius := 22 + sin(time / 0.09) * 4
		var points := PackedVector2Array()
		for i in 65: points.append(center + Vector2(cos(i * TAU / 64), sin(i * TAU / 64)) * radius)
		out.append({"type": "line", "points": points, "colour": GOLD, "width": 3.0, "tag": "captain_valve_glow", "center": center, "radius": radius})
	for wave: Dictionary in b.get("wave", []):
		var x := _x(c, float(wave.x))
		for i in 4:
			_rect(out, Rect2(x - 8 - i * 9 * signf(float(wave.vx)), float(c.ground) - 12 - (3 - i) * 8 - sin(float(wave.t) / 0.05 + i) * 3 + float(c.y_snap), 14, 12 + (3 - i) * 4), Color(1, 1, 1, 0.9), "captain_splash_wave")
		_rect(out, Rect2(x - 16, float(c.ground) - 6 + float(c.y_snap), 32, 6), Color("7fd0f0"), "captain_splash_wave_base")
	return out

func build_jar(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var jar: Dictionary = _state(_captain_owner(host, runtime), "jar", _state(runtime, "jar", {}))
	if jar.is_empty(): return []
	var c := _context(host)
	var point: Vector2 = jar.get("p", Vector2(jar.get("x", 0), jar.get("y", 0)))
	var time := float(jar.get("t", 0))
	var got := bool(jar.get("got", false))
	point.y += (0.0 if got else sin(time / 0.14) * 2) + float(c.y_snap)
	var out: Array = []
	if not got: _ellipse(out, point + Vector2(0, -4), Vector2.ONE * (44 + sin(time / 0.1) * 4), Color(1, 241 / 255.0, 168 / 255.0, 0.35), "captain_jar_glow")
	_rect(out, Rect2(point + Vector2(-18, -44), Vector2(36, 12)), Color("b07a2a"), "captain_jar_lid")
	_border(out, Rect2(point + Vector2(-28, -32), Vector2(56, 60)), 16, Color(200 / 255.0, 230 / 255.0, 1, 0.3), Color("dce8f0"), 4, "captain_jar_glass")
	_rounded(out, Rect2(point + Vector2(-24, -28), Vector2(48, 52)), 14, GOLD, "captain_jar_coins")
	for i in 6: _rect(out, Rect2(point + Vector2(-10 + (i * 7) % 20, 10 - (i * 5) % 26) * 2, Vector2(8, 4)), Color("c99a1d"), "captain_jar_coin_detail")
	_rect(out, Rect2(point + Vector2(-20, -24), Vector2(6, 16)), Color.WHITE, "captain_jar_highlight")
	return out

func draw_jar(host, runtime = null) -> void:
	draw_commands(host, build_jar(host, runtime))

func draw_commands(host, commands: Array) -> void:
	for command: Dictionary in commands:
		if command.type != "captain_rider":
			super.draw_commands(host, [command])
			continue
		var texture: Texture2D = command.texture
		var source: Rect2 = command.source
		if command.flash:
			texture = _festival_variant(command, texture)
			source.position = Vector2.ZERO
		var uv := Rect2(source.position / texture.get_size(), source.size / texture.get_size())
		var u0 := uv.end.x if command.flip_h else uv.position.x
		var u1 := uv.position.x if command.flip_h else uv.end.x
		var uvs := PackedVector2Array([Vector2(u0, uv.position.y), Vector2(u1, uv.position.y), Vector2(u1, uv.end.y), Vector2(u0, uv.end.y)])
		host.draw_polygon(command.points, PackedColorArray([Color(1, 1, 1, command.alpha)]), uvs, _nearest(texture))
