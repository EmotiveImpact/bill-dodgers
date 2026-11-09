extends RefCounted
## Canvas translation of game/index.html MAP4 draw order and authored animation data.
const GOLD = Color("f4c542")
const INK = Color("14102a")
var map
var t = 0.0
var view = Rect2()
var origin = Vector2.ZERO
var scale = 1.0

func _transform(position: Vector2 = Vector2.ZERO, rotation: float = 0.0, local_scale: Vector2 = Vector2.ONE) -> void:
	map.draw_set_transform(origin + position * scale, rotation, local_scale * scale)

func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var polygon = PackedVector2Array()
	for index in 24:
		var angle = index * TAU / 24
		polygon.append(center + Vector2(cos(angle), sin(angle)) * radius)
	map.draw_colored_polygon(polygon, color)

func _star(center: Vector2, radius: float, color: Color) -> void:
	var polygon = PackedVector2Array()
	for index in 10:
		var angle = -PI / 2 + index * PI / 5
		polygon.append(center + Vector2(cos(angle), sin(angle)) * radius * (0.45 if index % 2 else 1.0))
	map.draw_colored_polygon(polygon, color)

func _panel(rect: Rect2, color: Color, radius: int = 10, border: Color = Color.TRANSPARENT, border_width: int = 0) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color; style.set_corner_radius_all(radius)
	style.border_color = border; style.set_border_width_all(border_width)
	map.draw_style_box(style, rect)

func _hash(a: float, b: float, c: float) -> float:
	return fposmod(sin(a * 127.1 + b * 311.7 + c * 74.7) * 43758.5453, 1.0)

func _part(sheet: String, index: int, center: Vector2, width: float, color: Color = Color.WHITE, flip: bool = false) -> void:
	var parts: Array = map.map.cuts.get(sheet, [])
	var texture: Texture2D = map.pictures.get(sheet)
	if texture == null or index < 0 or index >= parts.size(): return
	var source: Array = parts[index]
	var dimensions = Vector2(width, width * float(source[3]) / source[2])
	_transform(center, 0, Vector2(-1 if flip else 1, 1))
	map.draw_texture_rect_region(texture, Rect2(-dimensions / 2, dimensions), Rect2(source[0], source[1], source[2], source[3]), color)
	_transform()

func _animation(name: String, index: int, position: Vector2, amount: float, flip: bool = false) -> void:
	var definition: Dictionary = map.map.anim.get(name, {})
	var texture: Texture2D = map.pictures.get(name)
	if texture == null or definition.is_empty(): return
	var columns = int(definition.cols)
	var source = Rect2((index % columns) * definition.w, (index / columns % int(definition.rows)) * definition.h, definition.w, definition.h)
	_transform(position, 0, Vector2(-1 if flip else 1, 1))
	var destination = Rect2(-Vector2(definition.ax, definition.ay) * amount, Vector2(definition.w, definition.h) * amount)
	map.draw_texture_rect_region(texture, destination, source)
	_transform()

func _cloud(index: int, center: Vector2, amount: float, alpha: float) -> void:
	var parts: Array = map.map.cuts.clouds
	_part("clouds", index, center, float(parts[index][2]) * amount, Color(1, 1, 1, alpha))

func _visible(position: Vector2, margin: float = 200) -> bool:
	return view.grow(margin).has_point(position)

func draw(context) -> void:
	map = context; t = map.time * 1000; view = map.view_rect(); scale = map.zoom; origin = -view.position * scale
	map.draw_rect(Rect2(Vector2.ZERO, map.size), Color("1d5fb8"))
	_transform()
	_draw_sea()
	_draw_sea_life()
	_draw_islands()
	_draw_water_smoke()
	for edge in map.edges:
		if edge.kind == "bridge" and map.shown.has(edge.index): _draw_bridge(edge, map.shown[edge.index] / edge.length)
	for edge in map.edges:
		if edge.kind != "bridge" and map.shown.has(edge.index): _draw_trail(edge, map.shown[edge.index])
	var things: Array = []
	for id in map.nodes:
		if map.nodes[id].kind != "gate": things.append({"id": id, "y": map.nodes[id].y})
	things.append({"id": "walker", "y": map.walker.y + 1})
	things.sort_custom(func(a, b): return a.y < b.y)
	for thing in things:
		if thing.id == "walker": _draw_walker()
		else: _draw_stop(thing.id)
	_draw_reveal()
	_draw_clouds_birds()
	map.draw_set_transform(Vector2.ZERO)
	if map.banner_time > 0:
		var alpha = minf(1, map.banner_time / 0.45)
		var rect = Rect2(map.size.x / 2 - 250, 100, 500, 100)
		_panel(rect, Color(0.078, 0.063, 0.165, 0.92 * alpha), 18, Color(map.COLORS[map.banner_world - 1], alpha), 2)
		var lines: PackedStringArray = map.banner_text.split("\n")
		for index in lines.size():
			var font_size = 22 if index == 0 else 30
			var width: float = map.ui_font.get_string_size(lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			map.draw_string(map.ui_font, Vector2((map.size.x - width) / 2, 137 + index * 36), lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(map.COLORS[map.banner_world - 1] if index == 0 else Color.WHITE, alpha))
	map = null # Never retain the host across scene teardown.

func _draw_sea() -> void:
	var sea: Texture2D = map.pictures.get("sea")
	if sea != null:
		# Mirror the source tile in both axes to conceal its seams, as prepSea does.
		var tile = sea.get_size() * 0.62
		for pass_index in 2:
			var drift = Vector2.ZERO if pass_index == 0 else Vector2(sin(t / 7000) * 60 + t * 0.004, cos(t / 9000) * 40) * 0.62
			var start = Vector2(floor((view.position.x - drift.x) / tile.x), floor((view.position.y - drift.y) / tile.y))
			for yy in range(int(start.y), int(ceil((view.end.y - drift.y) / tile.y)) + 1):
				for xx in range(int(start.x), int(ceil((view.end.x - drift.x) / tile.x)) + 1):
					var position = Vector2(xx, yy) * tile + drift
					var flip = Vector2(-1 if posmod(xx, 2) else 1, -1 if posmod(yy, 2) else 1)
					if flip.x < 0: position.x += tile.x
					if flip.y < 0: position.y += tile.y
					_transform(position, 0, flip)
					map.draw_texture_rect(sea, Rect2(Vector2.ZERO, tile), false, Color(1, 1, 1, 1 if pass_index == 0 else 0.22))
		_transform()
	for glint in map.map.glints:
		var point = Vector2(glint[0], glint[1])
		if not _visible(point, 10): continue
		var value = (sin(t / 600 + glint[2]) + 1) / 2
		if value > 0.82:
			var color = Color(1, 1, 1, (value - 0.82) * 5)
			map.draw_rect(Rect2(point + Vector2(-4, 0), Vector2(9, 2)), color)
			map.draw_rect(Rect2(point + Vector2(0, -3), Vector2(2, 8)), color)

func _draw_sea_life() -> void:
	var animation: Dictionary = map.map.anim.boatturn
	for boat in map.map.boats:
		var phase = _hash(boat.x, boat.y, 1) * 1000
		var u = fposmod(t * float(boat.v) + phase, 1000) / 1000
		var cosine = cos(u * TAU)
		var position = Vector2(boat.x + sin(u * TAU) * boat.rx, boat.y + sin(t / 400 + phase) * 1.5)
		if not _visible(position): continue
		var column = 1 if absf(cosine) < 0.14 else (0 if cosine > 0 else 2)
		_animation("boatturn", (int(boat.k) % int(animation.rows)) * int(animation.cols) + column, position, (float(boat.w) / 90) * (150.0 / float(animation.w)))
	for decoration in map.map.deco:
		var position = Vector2(decoration.x, decoration.y)
		if not _visible(position): continue
		_part("seaprops", int(decoration.k), position, decoration.w)
		if int(decoration.k) == 13:
			var source: Array = map.map.cuts.seaprops[13]
			var light = position + Vector2(-decoration.w * 0.03, -float(decoration.w) * source[3] / source[2] * 0.33)
			for ring in range(8, 0, -1): map.draw_circle(light, ring * 7.5, Color(1, 0.94, 0.67, (0.25 + (sin(t / 500) + 1) * 0.25) / 16))
	var u = fposmod(t, 9000) / 3600
	if u < 1 and not map.map.whales.is_empty():
		var whale: Array = map.map.whales[int(t / 9000) % map.map.whales.size()]
		var up = sin(u * PI)
		var source: Array = map.map.cuts.seaprops[int(map.map.whale)]
		var height = 90.0 * source[3] / source[2]
		_part("seaprops", int(map.map.whale), Vector2(whale[0], whale[1] - height / 2 + (1 - up) * height * 0.6), 90, Color(1, 1, 1, minf(1, up * 1.6)))
		for index in 2:
			var phase = fposmod(u * 2 + float(index) / 2, 1)
			_ellipse(Vector2(whale[0], whale[1] - 6), Vector2(20 + phase * 50, 7 + phase * 16), Color(1, 1, 1, 0.12 * (1 - phase)))

func _draw_islands() -> void:
	for island in map.map.islands:
		var texture: Texture2D = map.pictures.get("island-%d" % int(island.n))
		if texture == null: continue
		var rect = Rect2(Vector2(island.x, island.y), texture.get_size())
		if not view.grow(100).intersects(rect): continue
		var shadow = Rect2(rect.position + Vector2(26, 34), rect.size)
		for offset in [Vector2(-8, 0), Vector2(8, 0), Vector2(0, -8), Vector2(0, 8)]:
			map.draw_texture_rect(texture, Rect2(shadow.position + offset, shadow.size), false, Color(0.03, 0.09, 0.23, 0.12))
		# Original paintings already include the coast; this small breathing halo
		# retains that coastline rather than replacing it with an ellipse/island mesh.
		var foam_alpha = 0.06 + 0.025 * sin(t / 900 + island.n)
		for offset in [Vector2(-12, 0), Vector2(12, 0), Vector2(0, -10), Vector2(0, 10)]:
			map.draw_texture_rect(texture, Rect2(rect.position + offset, rect.size), false, Color(0.84, 1, 1, foam_alpha))
		var reveal: float = map.island_reveal[int(island.n)]
		map.draw_texture_rect(texture, rect, false, Color("6976a4").lerp(Color.WHITE, reveal))

func _draw_water_smoke() -> void:
	for fall in map.map.falls:
		var position = Vector2(fall.x, fall.y)
		if not _visible(position): continue
		for index in 7:
			var y = float(fall.y) + fposmod(t * 0.12 + index * float(fall.h) / 7, float(fall.h))
			var x = float(fall.x) - float(fall.w) / 2 + _hash(index, fall.x, 1) * float(fall.w)
			map.draw_rect(Rect2(x, y, 2.5, minf(16, float(fall.y) + fall.h - y)), Color(1, 1, 1, 0.55))
		for index in 4:
			var phase = fposmod(t / 1400 + float(index) / 4, 1)
			map.draw_circle(Vector2(float(fall.x) + (_hash(index, fall.y, 2) - 0.5) * float(fall.w) * 1.4, float(fall.y) + fall.h - phase * 10), 4 + phase * 9, Color(1, 1, 1, 0.55 * (1 - phase)))
	for index in map.map.smoke.size():
		var point: Array = map.map.smoke[index]
		if not _visible(Vector2(point[0], point[1])): continue
		for puff in 4:
			var phase = fposmod(t / 2200 + float(puff) / 4 + index * 0.37, 1)
			map.draw_circle(Vector2(point[0] + sin(phase * 5 + index) * 4, point[1] - phase * 34), 3 + phase * 6, Color(1, 1, 1, 0.55 * (1 - phase)))

func _draw_bridge(edge: Dictionary, fraction: float) -> void:
	if fraction <= 0: return
	var a: Vector2 = edge.points[0]
	var b: Vector2 = edge.points[-1]
	var displacement = b - a
	var vertical = absf(displacement.y) > absf(displacement.x)
	var index = 1 if vertical else 0
	var source: Array = map.map.cuts.bridges[index]
	var texture: Texture2D = map.pictures.bridges
	var length: float = displacement.length()
	# Artwork is mapped to the exact two authored endpoints, including diagonal
	# lean. A clipped prefix draws itself in as the boss opens the bridge.
	var across = Vector2(28, 0) if vertical else Vector2(0, 28)
	var end = a + displacement * fraction
	var polygon = PackedVector2Array([a - across, a + across, end + across, end - across])
	var width: float = source[2]
	var height: float = source[3]
	var uv: PackedVector2Array
	if vertical:
		var used = minf(height, length * width / 56) * fraction
		uv = PackedVector2Array([Vector2(source[0], source[1]), Vector2(source[0] + width, source[1]), Vector2(source[0] + width, source[1] + used), Vector2(source[0], source[1] + used)])
	else:
		var used = minf(width, length * height / 56) * fraction
		uv = PackedVector2Array([Vector2(source[0], source[1]), Vector2(source[0], source[1] + height), Vector2(source[0] + used, source[1] + height), Vector2(source[0] + used, source[1])])
	for i in uv.size(): uv[i] /= texture.get_size()
	map.draw_polygon(polygon, PackedColorArray([Color.WHITE]), uv, texture)

func _draw_trail(edge: Dictionary, upto: float) -> void:
	if edge.kind == "boat":
		var distance = fposmod(t / 40, 22)
		while distance < upto:
			var a: Vector2 = map.path_point(edge, distance)
			var b: Vector2 = map.path_point(edge, minf(upto, distance + 10))
			map.draw_line(a, b, Color(1, 1, 1, 0.75), 4, true); distance += 22
		return
	var distance = 30.0
	while distance < minf(upto, edge.length - 24):
		var point: Vector2 = map.path_point(edge, distance)
		if _visible(point, 10):
			var twinkle = (sin(t / 300 - distance / 40) + 1) / 2
			_ellipse(point + Vector2(0, 2.5), Vector2(7, 4.2), Color(0.12, 0.055, 0.04, 0.5))
			_ellipse(point, Vector2(6.4, 4.6), Color("3a1d0e"))
			_ellipse(point + Vector2(0, -0.4), Vector2(5, 3.4), Color(1, (178 + twinkle * 50) / 255, (40 + twinkle * 60) / 255))
			_ellipse(point + Vector2(-1.6, -1.5), Vector2(1.8, 1), Color(1, 1, 0.9, 0.85))
		distance += 24

func _draw_stop(id: String) -> void:
	var point: Vector2 = map.point(id)
	if not _visible(point, 90): return
	var node: Dictionary = map.nodes[id]
	var open: bool = map.is_open(id)
	var cleared: bool = map.state.verified_cleared.has(id)
	var here: bool = id == map.at
	var radius = 17.0 if node.kind == "boss" else 14.0
	if open:
		var pulse = (sin(t / 260) + 1) / 2 if id == map.state.next_route.get("level_id", "") else 0.3
		for ring in range(7, 0, -1): _ellipse(point, Vector2(radius * 2.6, radius * 1.9) * ring / 7, Color(1, 0.93, 0.59, (0.35 + 0.35 * pulse) / 15))
	_ellipse(point + Vector2(0, 3), Vector2(radius + 3, (radius + 3) * 0.62), Color(0.04, 0.03, 0.12, 0.45))
	var top = Color("8e8aa6")
	var mid = Color("6d6986")
	if open:
		top = Color("c58cff") if node.kind == "bonus" else (Color("ffd45e") if node.kind == "home" else Color("ff5d6c"))
		mid = Color("8a4fd6") if node.kind == "bonus" else (Color("d9a320") if node.kind == "home" else Color("c72f45"))
	if cleared: top = Color("5fe3a1"); mid = Color("23a76a")
	_ellipse(point, Vector2(radius + 2, (radius + 2) * 0.62), INK)
	_ellipse(point + Vector2(0, 1.5), Vector2(radius, radius * 0.62), mid)
	_ellipse(point + Vector2(0, -1), Vector2(radius, radius * 0.56), top)
	_ellipse(point + Vector2(-radius * 0.35, -radius * 0.25), Vector2(radius * 0.32, radius * 0.14), Color(1, 1, 1, 0.55))
	if not open:
		map.draw_rect(Rect2(point + Vector2(-4, -5), Vector2(8, 6)), INK)
		map.draw_arc(point + Vector2(0, -5), 3, PI, TAU, 12, INK, 2, true)
	elif cleared:
		map.draw_polyline(PackedVector2Array([point + Vector2(-5, -1), point + Vector2(-1, 3), point + Vector2(6, -5)]), Color("0f3d27"), 3, true)
	elif node.kind == "bonus": _star(point + Vector2(0, -1), 7, Color("fff6c8"))
	elif node.kind == "boss":
		var crown = PackedVector2Array()
		for p in [Vector2(-8, 3), Vector2(-8, -6), Vector2(-4, -2), Vector2(0, -8), Vector2(4, -2), Vector2(8, -6), Vector2(8, 3)]: crown.append(point + p)
		map.draw_colored_polygon(crown, Color("fff6c8"))
	elif node.kind == "home":
		map.draw_colored_polygon(PackedVector2Array([point + Vector2(-7, -1), point + Vector2(0, -8), point + Vector2(7, -1)]), INK)
		map.draw_rect(Rect2(point + Vector2(-5, -1), Vector2(10, 6)), INK)
	if cleared and node.kind == "boss":
		map.draw_rect(Rect2(point + Vector2(-1, -34), Vector2(2, 32)), INK)
		map.draw_colored_polygon(PackedVector2Array([point + Vector2(1, -34), point + Vector2(16, -30 + sin(t / 160) * 2), point + Vector2(1, -25)]), map.COLORS[int(node.world) - 1])
	if open and (here or map.zoom > map.near_zoom * 0.7):
		var text = "Home" if node.kind == "home" else id.replace("-S", " bonus")
		var factor = maxf(1, minf(2, 0.75 / scale))
		var font_size = int(13 * factor)
		var width: float = map.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 14 * factor
		var y = point.y + radius + 6 if here else point.y - radius - 10 - 20 * factor
		_panel(Rect2(point.x - width / 2, y, width, 20 * factor), GOLD if here else Color(0.078, 0.063, 0.165, 0.82), int(10 * factor))
		map.draw_string(map.font, Vector2(point.x - width / 2 + 7 * factor, y + 15 * factor), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK if here else Color("f5f1ea"))

func _draw_walker() -> void:
	var position: Vector2 = map.walker
	if map.boat:
		var animation: Dictionary = map.map.anim.boatturn
		_animation("boatturn", 2 * int(animation.cols) + (0 if map.face > 0 else 2), position + Vector2(0, 26 + sin(t / 300) * 2), 150.0 / float(animation.w))
	_ellipse(position + Vector2(0, 2), Vector2(13, 5), Color(0.04, 0.03, 0.12, 0.4))
	var key: String = map.game.character
	var metadata: Dictionary = map.info.sheets[key]
	var texture: Texture2D = map.pictures["sprite-" + key]
	var moving: bool = not map.route.is_empty() and not map.boat
	var animation: Dictionary = metadata.anims.run if moving else metadata.anims.idle
	var frame = int(t / (80 if moving else 220)) % int(animation.frames)
	var height = 78.0 * float(map.info.heights[key]) / 180
	var width = float(metadata.w) * height / float(metadata.h)
	_transform(position, 0, Vector2(map.face, 1))
	var destination = Rect2(Vector2(-width / 2, 3 - height - (8 if map.boat else 0)), Vector2(width, height))
	map.draw_texture_rect_region(texture, destination, Rect2(frame * metadata.w, animation.row * metadata.h, metadata.w, metadata.h))
	_transform()

func _draw_reveal() -> void:
	if not map.reveal_queue.is_empty():
		var edge: Dictionary = map.edges[map.reveal_queue[0]]
		var position: Vector2 = map.path_point(edge, map.shown[edge.index])
		for index in 8:
			var phase = fposmod(map.time * 1.5 + index * 0.17, 1)
			_star(position + Vector2(sin(index * 3.4) * phase * 30, -phase * 35), 4 + 3 * (1 - phase), Color(1, 0.94, 0.67, 1 - phase))
	for island in map.map.islands:
		var reveal: float = map.island_reveal[int(island.n)]
		if reveal >= 1: continue
		var texture: Texture2D = map.pictures["island-%d" % int(island.n)]
		var dimensions = texture.get_size()
		var center = Vector2(island.x, island.y) + dimensions * Vector2(0.5, 0.45)
		for index in 5:
			var angle = float(index) / 5 * TAU + island.n * 1.3
			var radii = dimensions * Vector2(0.27, 0.22) * (1 + reveal * 1.8)
			var position = center + Vector2(cos(angle), sin(angle)) * radii + Vector2(sin(t / 3000 + index) * 14, 0)
			_cloud(map.map.bigClouds[(index + int(island.n)) % map.map.bigClouds.size()], position, 1.25, 0.9 * (1 - reveal))
		if reveal == 0: _world_sign(island, center - Vector2(0, 10))

func _world_sign(island: Dictionary, center: Vector2) -> void:
	var name: String = map.Campaign.WORLD_NAMES[int(island.n) - 1]
	var width: float = maxf(150, map.font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x) + 92
	var color: Color = map.COLORS[int(island.n) - 1]
	_panel(Rect2(center - Vector2(width / 2, 39), Vector2(width, 78)), Color(0.06, 0.045, 0.13, 0.82), 22, color, 4)
	var lock = center + Vector2(-width / 2 + 40, 4)
	map.draw_arc(lock - Vector2(0, 10), 9, PI, TAU, 14, Color("f5f1ea"), 5, true)
	_panel(Rect2(lock - Vector2(14, 10), Vector2(28, 22)), Color("f5f1ea"), 5)
	map.draw_rect(Rect2(lock - Vector2(2, 3), Vector2(4, 8)), INK)
	map.draw_string(map.font, center + Vector2(-width / 2 + 72, -8), "WORLD %d" % int(island.n), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
	map.draw_string(map.font, center + Vector2(-width / 2 + 72, 24), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("f5f1ea"))

func _draw_clouds_birds() -> void:
	for index in 7:
		var speed = (-1.0 if index % 2 else 1.0) * (0.05 + _hash(index, 7, 3) * 0.04)
		var phase = _hash(index, 6, 4) * 6
		var position = Vector2(fposmod(_hash(index, 9, 1) * float(map.map.W) + speed * t + 50, float(map.map.W) + 100) - 50, _hash(index, 8, 2) * float(map.map.H) + sin(t / 900 + phase) * 30)
		if not _visible(position): continue
		var glide = sin(t / 2300 + phase * 2) > 0.55
		var frame = 2 if glide else int(t / 80 + phase * 3) % int(map.map.anim.gullfly.n)
		_ellipse(position + Vector2(50, 110), Vector2(20, 6), Color(0.03, 0.09, 0.23, 0.14))
		_animation("gullfly", frame, position, (58 + fposmod(phase, 1) * 16) / float(map.map.anim.gullfly.w), speed < 0)
	var balloon = Vector2(fposmod(t * 0.012, float(map.map.W) + 600) - 300, float(map.map.H) * 0.62 + sin(t / 5000) * 140)
	if _visible(balloon):
		_ellipse(balloon + Vector2(90, 190), Vector2(26, 9), Color(0.03, 0.09, 0.23, 0.18))
		_part("seaprops", int(map.map.balloon), balloon + Vector2(0, sin(t / 700) * 4), 76)
	for index in 8:
		var amount = 0.7 + _hash(index, 5, 6) * 0.5
		var speed = 0.006 + _hash(index, 7, 8) * 0.006
		var position = Vector2(fposmod(_hash(index, 1, 2) * float(map.map.W) + speed * t + 300, float(map.map.W) + 600) - 300, 200 + _hash(index, 3, 4) * (float(map.map.H) - 400))
		if not _visible(position, 700): continue
		_ellipse(position + Vector2(70, 120), Vector2(120, 50) * amount, Color(0.04, 0.08, 0.2, 0.18))
		var near: bool = position.distance_to(map.walker) < 260 * amount
		var zoom_factor: float = clampf((scale / map.fit_zoom - 1.5) / 2, 0, 1)
		_cloud(map.map.bigClouds[index % map.map.bigClouds.size()], position, amount, 0.3 if near else 0.9 - 0.45 * zoom_factor)
