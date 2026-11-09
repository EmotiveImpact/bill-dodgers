extends RefCounted
## Native scene art from game/1-3/index.html, without altering simulation state.
## The host has already applied its world camera / bottom-anchored zoom.
## Call draw_scene before actors and draw_front after actors/projectiles.

const Painter = preload("res://src/rooftop_renderer.gd")
const HEIGHT := 540.0
const GOLD := Color("f4c542")
var _painter = Painter.new()

func draw_scene(host, scene = null) -> void:
	draw_commands(host, build_scene(host, scene))

func draw_front(host, scene = null) -> void:
	draw_commands(host, build_front(host, scene))

func build_scene(host, scene = null) -> Array:
	var c := _context(host)
	var out := build_background(host, scene)
	_level(out, c, scene)
	return out

func build_background(host, scene = null, dim: float = 0) -> Array:
	# Same drawSky + optional drawBG dimming, expressed under the host transform.
	var c := _context(host)
	var out: Array = []
	var cam: Vector2 = c.camera
	var bands := [-10.0, 0.0, HEIGHT * 0.55, HEIGHT, HEIGHT + 10]
	var colours := [Color("5b4a8a"), Color("5b4a8a"), Color("e98a6a"), Color("f6c27a"), Color("f6c27a")]
	for i in range(bands.size() - 1):
		var rectangle := Rect2(cam + Vector2(-10, bands[i]), Vector2(c.width + 20, bands[i + 1] - bands[i]))
		if rectangle.intersects(c.view):
			out.append({"type": "gradient", "rect": rectangle, "colours": PackedColorArray([colours[i], colours[i], colours[i + 1], colours[i + 1]]), "tag": "sky_gradient"})
	if c.images.has("sky"):
		var offset := minf(_dimensions(c, "sky").x - float(c.width), float(_state(scene, "drive", 0.0)) * 0.006)
		# Unlike drawLevel, the source paints its sky BEFORE camera.y translation.
		_texture(out, c, "sky", cam + Vector2(-source_round(offset), c.roof_y - 390), "sky")
	if dim > 0:
		_rect(out, c, Rect2(cam, Vector2(c.width, HEIGHT)), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, clampf(dim, 0, 1)), "background_dim")
	return out

func build_front(host, scene = null) -> Array:
	var c := _context(host)
	var out: Array = []
	var obstacles: Array = _state(scene, "obstacles", [])
	for obstacle in obstacles:
		var x := float(c.camera.x) + source_round(float(obstacle.x))
		if obstacle.k == "bridge":
			var bottom := float(c.roof_y) - 132 + float(c.y_snap)
			if c.images.has("bridge"):
				_texture(out, c, "bridge", Vector2(x - 14, bottom - _size(c, "bridge").y + 4), "bridge_front")
			else:
				_rect(out, c, Rect2(x, bottom - 30, obstacle.w, 30), Color("4b5162"), "bridge_fallback")
		else:
			var bottom := float(c.roof_y) - 128 + float(c.y_snap)
			if c.images.has("branch"):
				_texture(out, c, "branch", Vector2(x - 20, bottom - _size(c, "branch").y + 10), "branch_front")
			else:
				_rect(out, c, Rect2(x - 40, bottom - 80, float(obstacle.w) + 80, 16), Color("4a3a2a"), "branch_fallback")
				for i in range(9):
					_circle(out, c, Vector2(x - 30 + i * (float(obstacle.w) + 60) / 8, bottom - 50 + (i % 3) * 12), 26, Color("3f7d4c") if i % 2 else Color("5c9a4a"), "branch_leaves_fallback")
	var warn_time := float(_state(scene, "warn_time", 0.0))
	if warn_time > 0 and int(floorf(warn_time * 1000 / 200)) % 2 == 0:
		var x := float(c.camera.x) + float(c.width) - 90
		var y := float(c.roof_y) + float(c.y_snap)
		out.append({"type": "text", "position": Vector2(x, y - 170), "text": "Duck!", "size": 26, "colour": GOLD, "outline": Color("0e1726"), "stroke_width": 6.5, "tag": "duck_warning"})
		out.append({"type": "polygon", "points": PackedVector2Array([Vector2(x, y - 116), Vector2(x - 18, y - 142), Vector2(x + 18, y - 142)]), "colour": GOLD, "tag": "duck_arrow"})
	# Source bd-fixes empties LV.front. Do not restore sweeping lamps/leaves.
	# The host owns shared pickups/checkpoints; this source level has no checks.
	return out

func _level(out: Array, c: Dictionary, scene) -> void:
	var drive := float(_state(scene, "drive", 0.0))
	var towns: Array = c.towns
	var ys := float(c.y_snap)
	var cx := float(c.camera.x)
	if not towns.is_empty():
		var dimensions := _dimensions(c, towns[0])
		var width := dimensions.x
		if width > 0:
			var y := float(c.roof_y) - 330 + ys
			var offset := drive * 0.7
			var index := int(floorf(offset / width))
			# JavaScript % is remainder, not positive modulo: retain the minus.
			var start := fmod(-source_round(offset), width)
			var x := start
			while x < float(c.width) + width:
				var key := _town_at(c.level, towns, index)
				_texture(out, c, key, Vector2(cx + x, y), "town", towns.size() == 1 and index % 2 != 0, {"town_index": index})
				x += width
				index += 1
			if c.images.has("jtree") and towns.size() > 1:
				var tree := _size(c, "jtree")
				var tx := source_round(tree.x * 470 / 1075)
				x = start + width
				while x < float(c.width) + tree.x:
					_texture(out, c, "jtree", Vector2(cx + x - tx, y + 545 - tree.y), "town_join_tree")
					x += width
			_rect(out, c, Rect2(cx - 10, y + dimensions.y - 2, float(c.width) + 20, 600), Color("3b2f3a"), "town_base")
	var obstacles: Array = _state(scene, "obstacles", [])
	for obstacle in obstacles:
		if obstacle.k == "bridge":
			_texture(out, c, "bridgeback", Vector2(cx + source_round(obstacle.x), float(c.roof_y) - 132 + ys), "bridge_back")
	var bus: Array = c.level.get("bus", [])
	if bus.size() >= 2:
		var bob := source_round(sin(drive / 40) * 1.2)
		_texture(out, c, "bus", Vector2(cx + float(bus[0]), float(bus[1]) + bob + ys), "bus")
	for scooter in _state(scene, "scooters", []):
		var x := cx + source_round(scooter.x)
		var y := source_round(scooter.y) + ys
		if c.images.has("scooter"):
			var size := _size(c, "scooter")
			_texture(out, c, "scooter", Vector2(x - size.x / 2, y - size.y), "scooter", scooter.face > 0)
		else:
			_rect(out, c, Rect2(x - 30, y - 6, 60, 6), Color("2a2f3d"), "scooter_deck_fallback")
			_rect(out, c, Rect2(x + 22 * float(scooter.face), y - 60, 5, 56), Color("2a2f3d"), "scooter_handle_fallback")
			_circle(out, c, Vector2(x - 24, y), 8, Color("e45b5b"), "scooter_wheel_fallback")
			_circle(out, c, Vector2(x + 24, y), 8, Color("e45b5b"), "scooter_wheel_fallback")
	for obstacle in obstacles:
		_rect(out, c, Rect2(cx + source_round(obstacle.x), float(c.roof_y) - 6 + ys, obstacle.w, 10), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.35), "obstacle_shadow")

func _context(host) -> Dictionary:
	var roofs: Array = host.level.get("solids", [])
	return {"images": host.images, "dims": host.meta.get("dims", {}), "level": host.level, "camera": host.camera,
		"width": float(host.view_width()), "roof_y": float(roofs[0][2]) if not roofs.is_empty() else 150.0,
		"view": Rect2(host.camera.x, host.view_top(), host.view_width(), host.camera.y + HEIGHT - host.view_top()),
		"y_snap": host.camera.y - source_round(host.camera.y), "towns": _towns(host)}

static func source_round(value: float) -> float:
	return floorf(value + 0.5)

static func _state(scene, key: String, default):
	if scene == null: return default
	var value = scene.get(key)
	return default if value == null else value

func _towns(host) -> Array:
	if host.level.has("towns"): return host.level.towns
	var towns: Array = []
	for key in host.meta.get("imgs", {}):
		if key.begins_with("town") and key.substr(4).is_valid_int(): towns.append(key)
	return towns

func town_at(host, index: int) -> String:
	return _town_at(host.level, _towns(host), index)

func _town_at(level: Dictionary, towns: Array, index: int) -> String:
	if towns.is_empty(): return ""
	var embankment_index := int(level.get("embankAt", -1)) if level.has("embank") else -1
	if level.has("embank") and index == embankment_index: return str(level.embank)
	var adjusted := index - 1 if embankment_index >= 0 and index > embankment_index else index
	return str(towns[posmod(adjusted, towns.size())])

func _size(c: Dictionary, key: String) -> Vector2:
	return c.images[key].get_size() if c.images.has(key) else Vector2.ZERO

func _dimensions(c: Dictionary, key: String) -> Vector2:
	if c.dims.has(key): return Vector2(c.dims[key][0], c.dims[key][1])
	return _size(c, key)

func _texture(out: Array, c: Dictionary, key: String, position: Vector2, tag: String, flip_h: bool = false, extra: Dictionary = {}) -> void:
	if not c.images.has(key): return
	var size := _size(c, key)
	var destination := Rect2(position, size)
	if not destination.has_area() or not destination.intersects(c.view): return
	var command := {"type": "texture", "key": key, "rect": destination, "source": Rect2(Vector2.ZERO, size),
		"flip_h": flip_h, "alpha": 1.0, "smooth": false, "tag": tag}
	command.merge(extra)
	out.append(command)

func _rect(out: Array, c: Dictionary, rectangle: Rect2, colour: Color, tag: String) -> void:
	if rectangle.has_area() and rectangle.intersects(c.view):
		out.append({"type": "rect", "rect": rectangle, "colour": colour, "tag": tag})

func _circle(out: Array, c: Dictionary, position: Vector2, radius: float, colour: Color, tag: String) -> void:
	if Rect2(position - Vector2.ONE * radius, Vector2.ONE * radius * 2).intersects(c.view):
		out.append({"type": "circle", "position": position, "radius": radius, "colour": colour, "tag": tag})

func draw_commands(host, commands: Array) -> void:
	# Share texture filtering, gradients and outlined text with the roof renderer.
	# The two extra primitives are source fallback art and the warning triangle.
	var batch: Array = []
	for command in commands:
		if command.type not in ["circle", "polygon"]:
			batch.append(command)
			continue
		_painter.draw_commands(host, batch)
		batch.clear()
		if command.type == "circle": host.draw_circle(command.position, command.radius, command.colour)
		else: host.draw_colored_polygon(command.points, command.colour)
	_painter.draw_commands(host, batch)

func clear_cache() -> void:
	_painter.clear_cache()
