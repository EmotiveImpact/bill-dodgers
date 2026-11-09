extends "res://src/aisle_renderer.gd"
## Source 2-4 Trolley dash painter. World pixels, seconds; no simulation writes.
## The host applies the camera transform and raises only the player sprite by30.
## Full source paintings stay unmirrored and unscaled. No stage is enabled here.

const AISLE_LENGTH := 3200.0
const AISLE_COLOURS := ["2d6a4f", "3f7fd8", "c94f9b", "1fa39a", "e23b3b", "7a4fd0"]
const PLAYER_RIDE := 30.0

func supports(id: String) -> bool:
	return id == "2-4"

static func aisle_at(world_x: float) -> int:
	return maxi(0, int(floorf(world_x / AISLE_LENGTH)))

func build_sky(host, _runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	var cam: Vector2 = c.camera
	var size := _size(c, "aisle0")
	if size == Vector2.ZERO:
		_rect(out, Rect2(cam.x - 10, cam.y - 10, c.width + 20, HEIGHT + 20), Color("d7e6df"), "missing_painting_fill")
		return out
	var top := source_round(float(c.ground) - 0.777 * size.y - cam.y)
	var index := int(floorf(cam.x / size.x))
	while index * size.x - cam.x < float(c.width):
		var world_x := index * size.x
		var aisle := aisle_at(world_x)
		var key := "aisle%d" % (aisle % 6)
		if not c.images.has(key): key = "aisle0"
		_texture(out, c, key, Rect2(_x(c, world_x), cam.y + top, size.x, size.y), "dash_painting", Rect2(Vector2.ZERO, _size(c, key)), false, {"index": index, "aisle": aisle, "world_x": world_x, "floor_factor": 0.777})
		index += 1
	if top > -20:
		_rect(out, Rect2(cam.x - 10, cam.y - 10, c.width + 20, top + 11), Color("1e2738"), "painting_top_fill")
	_ceiling(out, c)
	for n in range(aisle_at(cam.x) - 2, aisle_at(cam.x + float(c.width)) + 3):
		if n < 0: continue
		var sx := n * AISLE_LENGTH * 0.8 + 400 - cam.x * 0.8
		if sx > -130 and sx < float(c.width) + 10:
			_dash_sign(out, Vector2(cam.x + source_round(sx), cam.y + 60), n + 1, Color(AISLE_COLOURS[n % 6]))
	return out

func _ceiling(out: Array, c: Dictionary) -> void:
	var cam: Vector2 = c.camera
	_rect(out, Rect2(cam.x - 10, cam.y - 10, c.width + 20, 210), Color("f2f5f4"), "dash_ceiling")
	_rect(out, Rect2(cam.x - 10, cam.y + 194, c.width + 20, 6), _shade(Color("f2f5f4"), -0.12), "dash_ceiling_edge")
	var x := -fmod(cam.x * 0.6, 260) - 260
	while x < float(c.width) + 260:
		var sx := cam.x + source_round(x)
		_rect(out, Rect2(sx, cam.y + 174, 170, 14), Color("c7d0dc"), "ceiling_light_frame")
		_rect(out, Rect2(sx + 4, cam.y + 176, 162, 8), Color.WHITE, "ceiling_light")
		_rect(out, Rect2(sx - 20, cam.y + 188, 210, 30), Color(1, 1, 240 / 255.0, 0.18), "ceiling_light_glow")
		x += 260

func _dash_sign(out: Array, origin: Vector2, number: int, colour: Color) -> void:
	for row in [[Rect2(28, 0, 3, 60), Color("9aa5b8")], [Rect2(89, 0, 3, 60), Color("9aa5b8")], [Rect2(0, 56, 120, 94), Color("14243b")], [Rect2(4, 60, 112, 86), colour], [Rect2(4, 60, 112, 10), _shade(colour, 0.25)]]:
		_rect(out, Rect2(origin + row[0].position, row[0].size), row[1], "dash_sign")
	out.append({"type": "text", "position": origin + Vector2(60, 102), "text": str(number), "size": 60, "colour": Color.WHITE, "tag": "dash_sign_number"})

func build_level(host, _runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	var cam: Vector2 = c.camera
	var ground := float(c.ground) + float(c.y_snap)
	var size := _size(c, "aisle0")
	if size != Vector2.ZERO:
		for n in range(aisle_at(cam.x), aisle_at(cam.x + float(c.width)) + 2):
			var sx := source_round(ceilf(n * AISLE_LENGTH / size.x) * size.x - cam.x)
			if sx < -40 or sx > float(c.width) + 40: continue
			var x := cam.x + sx
			var top := float(c.view.position.y) - 10 + float(c.y_snap)
			var height := float(c.ground) - float(c.view.position.y) + 10
			_rect(out, Rect2(x - 16, top, 32, height), Color("9aa5b8"), "aisle_boundary_post")
			_rect(out, Rect2(x - 12, top, 10, height), Color("e9f0ec"), "aisle_boundary_highlight")
			_rect(out, Rect2(x - 16, ground - 120, 32, 60), Color(AISLE_COLOURS[n % 6]), "aisle_boundary_band")
			_rect(out, Rect2(x - 18, ground - 8, 36, 8), Color("5b6578"), "aisle_boundary_base")
	var x := -fmod(cam.x, 180)
	while x < float(c.width):
		_rect(out, Rect2(cam.x + source_round(x), ground + 30, 60, 3), Color(1, 1, 1, 0.55), "floor_speed_line")
		x += 180
	return out

func build_mid(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	for hazard in _hazards(host, runtime):
		match hazard[0]:
			"low":
				if _in_view(c, float(hazard[1]) - 70, float(hazard[1]) + 70): _low_sign(out, c, hazard)
			"block":
				if _in_view(c, float(hazard[1]) - 80, float(hazard[1]) + 80): _block(out, c, hazard)
			"boost":
				if _in_view(c, float(hazard[1]), float(hazard[2])): _boost(out, c, hazard, float(host.elapsed))
	# Source hazards precede autonomous trolleys, then draw_mid's pickups callback.
	out.append_array(super.build_mid(host, {"hazards": [], "hazard_controller": {"gates": [], "plates": [], "buttons": []}, "entities": _state(runtime, "entities", []), "elapsed": host.elapsed}))
	return out

func _low_sign(out: Array, c: Dictionary, hazard: Array) -> void:
	var x := _x(c, float(hazard[1]))
	var bottom := float(hazard[2]) - float(hazard[3])
	var ys := float(c.y_snap)
	var rail_top := float(c.view.position.y) - 10
	# Canvas fillRect accepts negative height when the camera is below a sign.
	for dx in [-40, 37]:
		_rect(out, Rect2(x + dx, rail_top + ys, 3, bottom - 60 - rail_top).abs(), Color("5b6578"), "low_sign_rail")
	var origin := Vector2(x - 60, bottom - 64 + ys)
	var colour := Color(["2d6a4f", "e23b3b", "3f7fd8"][int(hazard[5]) % 3 if hazard.size() > 5 else 0])
	var start := out.size()
	for row in [[Rect2(0, 0, 120, 64), Color("14243b")], [Rect2(3, 3, 114, 58), colour], [Rect2(3, 3, 114, 8), _shade(colour, 0.25)]]:
		_rect(out, Rect2(origin + row[0].position, row[0].size), row[1], "low_sign")
	_poly(out, [origin + Vector2(60, 12), origin + Vector2(80, 48), origin + Vector2(40, 48)], GOLD, "low_sign_warning")
	_rect(out, Rect2(origin + Vector2(58, 22), Vector2(4, 14)), Color("14243b"), "low_sign_mark")
	_rect(out, Rect2(origin + Vector2(58, 40), Vector2(4, 4)), Color("14243b"), "low_sign_mark")
	for i in range(start, out.size()): out[i].merge({"hazard_x": float(hazard[1]), "art_rect": Rect2(origin, Vector2(120, 64)), "underside": bottom + ys})

func _block(out: Array, c: Dictionary, hazard: Array) -> void:
	var width := float(hazard[3])
	var height := float(hazard[4])
	var kind := str(hazard[5]) if hazard.size() > 5 else "wet"
	var size := _size(c, "wet") if kind == "wet" and c.images.has("wet") else Vector2(ceilf(width + 8), ceilf(height + 4))
	var origin := Vector2(_x(c, float(hazard[1]) - size.x / 2), float(hazard[2]) - size.y + float(c.y_snap))
	if kind == "wet" and c.images.has("wet"):
		_texture(out, c, "wet", Rect2(origin, size), "block_painting", Rect2(), false, {"kind": kind, "hazard_x": float(hazard[1]), "art_rect": Rect2(origin, size)})
		return
	var art := _block_art(kind, width, height)
	for command in _clip_commands(art, Rect2(Vector2.ZERO, size)):
		var translated := _translated(command, origin)
		translated.merge({"kind": kind, "hazard_x": float(hazard[1]), "art_rect": Rect2(origin, size), "source_region": Rect2(Vector2.ZERO, size)})
		out.append(translated)

func _block_art(kind: String, w: float, h: float) -> Array:
	var out: Array = []
	match kind:
		"wet":
			_poly(out, [Vector2(w / 2 + 4, 0), Vector2(w, h), Vector2(8, h)], GOLD, "wet_sign")
			_poly(out, [Vector2(w / 2 + 4, 0), Vector2(w, h), Vector2(w / 2 + 14, h)], Color("d8a520"), "wet_sign_shade")
			_ellipse(out, Vector2(w / 2 + 4, h * 0.45), Vector2(7, 7), Color("14243b"), "wet_sign_head")
			_rect(out, Rect2(w / 2 - 6, h * 0.55, 22, 5), Color("14243b"), "wet_sign_body")
			_r0(out, Color("14243b"), 4, h, w, 4, "wet_sign_base")
		"pallet":
			_r0(out, Color("3a4a66"), 0, h - 16, w + 8, 16, "pallet_base")
			_r0(out, Color("55678a"), 4, h - 14, w, 4, "pallet_highlight")
			for i in 3: _r0(out, Color("2b3850"), 8 + i * (w / 2 - 6), h - 8, 14, 8, "pallet_foot")
			var y := h - 16
			while y > 0:
				var x := 4.0
				while x < w:
					_r0(out, Color("3f7fd8"), x, y - 34, 38, 34, "pallet_box")
					_r0(out, Color("5b97e8"), x + 2, y - 32, 34, 12, "pallet_box_highlight")
					_r0(out, Color("f5f1ea"), x + 15, y - 34, 6, 34, "pallet_box_tape")
					x += 40
				y -= 34
			_rect(out, Rect2(0, 0, w + 8, h - 16), Color(1, 1, 1, 0.18), "pallet_glaze")
		"spill":
			_ellipse(out, Vector2(w / 2 + 4, h - 6), Vector2(w / 2, 8), Color(1, 1, 1, 0.95), "spill_puddle")
			_r0(out, Color.WHITE, w / 2 - 10, 0, 24, h - 10, "spill_bottle")
			_r0(out, Color("3f7fd8"), w / 2 - 10, 10, 24, 12, "spill_label")
			_r0(out, Color("dfe7ee"), w / 2 - 6, 0, 16, 6, "spill_cap")
		"cones":
			for i in 2:
				var x := 12 + i * (w - 16)
				_poly(out, [Vector2(x, 0), Vector2(x + 14, h - 6), Vector2(x - 14, h - 6)], Color("f08a24"), "cone")
				_r0(out, Color.WHITE, x - 8, h * 0.45, 16, 6, "cone_stripe")
				_r0(out, Color("14243b"), x - 18, h - 6, 36, 6, "cone_base")
			_r0(out, Color("e23b3b"), 12, h * 0.3, w - 16, 6, "cone_barrier")
			_r0(out, Color.WHITE, 12 + (w - 16) / 3, h * 0.3, (w - 16) / 3, 6, "cone_barrier_stripe")
	return out

func _boost(out: Array, c: Dictionary, hazard: Array, elapsed: float) -> void:
	var x := float(hazard[1])
	var y := float(c.ground) + float(c.y_snap)
	while x < float(hazard[2]):
		var sx := _x(c, x)
		_poly(out, [Vector2(sx, y + 8), Vector2(sx + 26, y + 18), Vector2(sx, y + 28), Vector2(sx + 10, y + 18)], Color("f4c542" if int(floorf(elapsed * 1000 / 120 + x / 70)) % 2 else "ffe08a"), "boost_arrow")
		out[-1].merge({"hazard_x": float(hazard[1]), "world_x": x})
		x += 70

func _player_state(host, player) -> Dictionary:
	if player is Dictionary:
		return {"p": player.get("p", host.player), "face": player.get("face", 1), "grounded": player.get("on_ground", player.get("grounded", player.get("onG", false))), "animation": player.get("act", player.get("animation", "idle")), "down": player.get("down", false)}
	return {"p": player if player is Vector2 else host.player, "face": _state(host, "face", 1), "grounded": _state(host, "grounded", false), "animation": "win" if _state(host, "mode", "play") == "clear" else _state(host, "player_animation", "idle"), "down": bool(_state(host, "down", false)) or int(_state(host, "hearts", 3)) <= 0}

func _player_art(host, player, front: bool) -> Array:
	if not supports(host.level_id): return []
	var actor := _player_state(host, player)
	if actor.down: return []
	var c := _context(host)
	var p: Vector2 = actor.p
	var bob := sin(float(host.elapsed) * 1000 / 60) if actor.grounded and actor.animation == "run" else 0.0
	var origin := Vector2(_x(c, p.x - 60), source_round(p.y - 104 + bob) + float(c.y_snap))
	var commands := build_trolley(origin + Vector2(60, 52), int(actor.face) < 0)
	var clip := Rect2(origin + Vector2(0, 12), Vector2(120, 30))
	if front: commands = _clip_commands(commands, clip)
	for command in commands:
		command.merge({"layer": "player_front" if front else "player_back", "art_rect": Rect2(origin, Vector2(120, 106)), "source_region": Rect2(0, 12, 120, 30) if front else Rect2(0, 0, 120, 106), "bob": bob, "flip_h": int(actor.face) < 0})
		if front: command.clip_rect = clip
		else: command.colour.a *= 0.95
	# The source's random draw-time dust is omitted rather than consuming RNG or
	# modifying particles. The trolley and front clip are pure repeated draws.
	return commands

func build_player_back(host, player = null) -> Array:
	return _player_art(host, player, false)

func build_player_front(host, player = null) -> Array:
	return _player_art(host, player, true)

func draw_player_back(host, player = null) -> void:
	draw_commands(host, build_player_back(host, player))

func draw_player_front(host, player = null) -> void:
	draw_commands(host, build_player_front(host, player))

func build_front(host, _runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	var scroll := float(c.camera.x) * 1.25
	for index in range(int(floorf(scroll / 3100)) - 1, int(floorf((scroll + float(c.width)) / 3100)) + 2):
		var sx := source_round(index * 3100 + 900 - scroll)
		if sx < -54 or sx > float(c.width) + 20: continue
		var x := float(c.camera.x) + sx
		var top := HEIGHT - 46 + float(c.y_snap)
		var colour := Color(236 / 255.0, 240 / 255.0, 238 / 255.0, 0.94)
		_rect(out, Rect2(x, top + 8, 30, 46), colour, "foreground_bollard")
		_ellipse(out, Vector2(x + 15, top + 8), Vector2(15, 6), colour, "foreground_bollard_cap")
		_rect(out, Rect2(x + 4, top + 10, 3, 46), Color(1, 1, 1, 0.9), "foreground_bollard_highlight")
		_rect(out, Rect2(x, top + 18, 30, 8), Color("2d6a4f"), "foreground_bollard_band")
	return out

func build_hud(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	if _state(host, "mode", "play") in ["play", "clear"]:
		var elapsed := float(host.elapsed)
		var course = _state(runtime, "course_controller", null)
		var boosted := bool(_state(course, "boost", false))
		var back := Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.8)
		if boosted: _border(out, Rect2(390, 74, 180, 34), 10, back, GOLD, 2, "dash_timer_back")
		else: _rounded(out, Rect2(390, 74, 180, 34), 10, back, "dash_timer_back")
		var seconds := int(floorf(elapsed))
		out.append({"type": "text", "position": Vector2(440, 92), "text": "%d:%02d" % [seconds / 60, seconds % 60], "size": 18, "colour": Color("f5f1ea"), "tag": "dash_elapsed"})
		out.append({"type": "text", "position": Vector2(516, 92), "text": "par 3:30", "size": 11, "colour": Color("9fb0c8"), "tag": "dash_par"})
		if boosted and int(floorf(elapsed * 1000 / 250)) % 2:
			out.append({"type": "outlined_text", "position": Vector2(480, 126), "text": "Reduced aisle! Faster!", "size": 14, "colour": GOLD, "outline": Color("0e1726"), "outline_size": 3.5, "tag": "dash_boost_label"})
		var progress := minf(1, float(host.camera.x) / maxf(1, float(host.level.get("w", 40000)) - float(host.view_width())))
		_rounded(out, Rect2(280, 514, 400, 10), 5, Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.7), "dash_progress_back")
		_rounded(out, Rect2(280, 514, 400 * progress, 10), 5, Color("9fe0b8"), "dash_progress")
		var origin := Vector2(source_round(266 + 400 * progress), 494)
		# Flatten source strokes before the source30x26 HUD image scaling.
		for command in _clip_commands(build_trolley(Vector2(60, 52)), Rect2(0, 0, 120, 106)):
			var transformed := PackedVector2Array()
			for point in command.points: transformed.append(origin + point * Vector2(0.25, 26.0 / 106))
			out.append({"type": "polygon", "points": transformed, "colour": command.colour, "tag": "dash_progress_trolley", "art_rect": Rect2(origin, Vector2(30, 26)), "source_region": Rect2(0, 0, 120, 106), "progress": progress})
	# No2-4 scene transition is authored, but retain the shared iris contract.
	out.append_array(super.build_hud(host, runtime))
	return out

func _translated(command: Dictionary, origin: Vector2) -> Dictionary:
	var result: Dictionary = command.duplicate()
	if result.has("rect"): result.rect = Rect2(result.rect.position + origin, result.rect.size)
	if result.has("center"): result.center += origin
	if result.has("points"):
		var points := PackedVector2Array()
		for point in result.points: points.append(point + origin)
		result.points = points
	return result

func _polygons(command: Dictionary) -> Array:
	match command.type:
		"polygon": return [command.points]
		"rect":
			var r: Rect2 = command.rect
			return [PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])]
		"ellipse":
			var points := PackedVector2Array()
			for i in 64: points.append(command.center + Vector2(cos(i * TAU / 64), sin(i * TAU / 64)) * command.radius)
			return [points]
		"line":
			# Source canvas uses butt ends and miter joins. Outline the complete
			# frame before clipping/scaling so its corners have no separate-cap gap.
			var points: PackedVector2Array = command.points
			if points.size() < 2: return []
			var half_width := float(command.width) / 2
			var left := PackedVector2Array()
			var right := PackedVector2Array()
			for i in points.size():
				var incoming := (points[i] - points[i - 1]).normalized().orthogonal() if i > 0 else (points[1] - points[0]).normalized().orthogonal()
				var outgoing := (points[i + 1] - points[i]).normalized().orthogonal() if i + 1 < points.size() else incoming
				var bisector := (incoming + outgoing).normalized()
				var normal := bisector * half_width / maxf(0.1, bisector.dot(outgoing))
				left.append(points[i] + normal)
				right.append(points[i] - normal)
			right.reverse()
			left.append_array(right)
			return [left]
	return []

func _clip_commands(commands: Array, clip: Rect2) -> Array:
	var out: Array = []
	for command in commands:
		for polygon in _polygons(command):
			var points: PackedVector2Array = polygon
			# Sutherland-Hodgman clipping retains fractional source vertices, unlike
			# CanvasItem-wide clipping, which would leak into the host sprite pass.
			for edge in [[0, clip.position.x, true], [0, clip.end.x, false], [1, clip.position.y, true], [1, clip.end.y, false]]:
				if points.is_empty(): break
				var clipped := PackedVector2Array()
				var previous := points[-1]
				var previous_inside: bool = previous[edge[0]] >= edge[1] if edge[2] else previous[edge[0]] <= edge[1]
				for current in points:
					var inside: bool = current[edge[0]] >= edge[1] if edge[2] else current[edge[0]] <= edge[1]
					if inside != previous_inside:
						var fraction: float = (edge[1] - previous[edge[0]]) / (current[edge[0]] - previous[edge[0]])
						var crossing := previous.lerp(current, fraction)
						crossing[edge[0]] = edge[1]
						clipped.append(crossing)
					if inside: clipped.append(current)
					previous = current
					previous_inside = inside
				points = clipped
			points = _clean_polygon(points)
			if points.size() >= 3:
				var result: Dictionary = command.duplicate()
				result.type = "polygon"
				result.points = points
				for key in ["rect", "center", "radius", "width"]: result.erase(key)
				out.append(result)
	return out

func _clean_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		if result.is_empty() or point.distance_squared_to(result[-1]) > 0.00000001: result.append(point)
	if result.size() > 1 and result[0].distance_squared_to(result[-1]) <= 0.00000001: result.remove_at(result.size() - 1)
	var twice_area := 0.0
	for i in result.size(): twice_area += (result[i] - result[0]).cross(result[(i + 1) % result.size()] - result[0])
	return result if absf(twice_area) > 0.0001 else PackedVector2Array()
