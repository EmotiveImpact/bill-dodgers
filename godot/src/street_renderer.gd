extends RefCounted
## Source World 1 scene art: Park, Back Alley Chase, Late Shop Bonus and Bin Day.
## The host already applies the world camera / bottom-anchored 1.3x zoom.
## Owns scene paintings, solid/one-way surface artwork and checkpoint flags.
## Actors, pickups, destructible crates and Binman effects stay with their owners.

const Painter = preload("res://src/rooftop_renderer.gd")
const LEVELS := ["1-4", "1-5", "1-S", "1-6"]
const HEIGHT := 540.0
const GOLD := Color("f4c542")
var _painter = Painter.new()

func supports(id: String) -> bool:
	return id in LEVELS

func draw_scene(host, world_one = null, pickups: Callable = Callable()) -> void:
	if not supports(host.level_id): return
	if not pickups.is_valid():
		draw_commands(host, build_scene(host, world_one))
		return
	var c := _context(host)
	draw_commands(host, _scene_back(host, c))
	# Source drawChecks draws receipts/skill cards before flags/levelDraw.
	# The host owns these pickups; keep this split independent of command tags.
	pickups.call()
	var out: Array = []
	_scene_after_pickups(out, c, host, world_one)
	draw_commands(host, out)

func draw_front(host, world_one = null) -> void:
	draw_commands(host, build_front(host, world_one))

func build_scene(host, world_one = null) -> Array:
	if not supports(host.level_id): return []
	var c := _context(host)
	var out := _scene_back(host, c)
	_scene_after_pickups(out, c, host, world_one)
	return out

func _scene_back(host, c: Dictionary) -> Array:
	var out := build_background(host)
	if host.level_id != "1-6":
		_join_trees(out, c)
		_decor(out, c)
	return out

func _scene_after_pickups(out: Array, c: Dictionary, host, world_one) -> void:
	_checkpoints(out, c, host, world_one)
	match host.level_id:
		"1-5": _alley(out, c)
		"1-S": _awnings(out, c)

func build_background(host, dim: float = 0) -> Array:
	if not supports(host.level_id): return []
	var c := _context(host)
	var out: Array = []
	var cam: Vector2 = c.camera
	_rect(out, c, Rect2(cam - Vector2(10, 10), Vector2(c.width + 20, HEIGHT + 20)),
		Color(c.level.get("skyCol", "#2a3348")), "sky_fill")
	if host.level_id == "1-6":
		var chunk := float(host.meta.get("chunk", 2048))
		if chunk > 0:
			var first := int(floorf(cam.x / chunk))
			for index in range(first, first + 2):
				# The final chunk is only 59px wide, never stretch it to CHUNK.
				_texture(out, c, "st%d" % index, Vector2(_x(c, index * chunk), cam.y), "street_chunk", false, {"index": index})
	else:
		var tiles: Array = c.level.get("tiles", [])
		if not tiles.is_empty():
			var x := 0.0
			var index := 0
			while true:
				var stride := _dimensions(c, str(tiles[index % tiles.size()])).x
				if stride <= 0: break
				if x + stride > cam.x: break
				x += stride
				index += 1
			while x < cam.x + float(c.width):
				var key := str(tiles[index % tiles.size()])
				var stride := _dimensions(c, key).x
				if stride <= 0: break
				# Source drawSky runs before the vertical camera translation.
				_texture(out, c, key, Vector2(_x(c, x), cam.y), "scene_tile", false, {"index": index})
				x += stride
				index += 1
	if dim > 0:
		# drawBG's source dim rectangle is VW (960), not the zoomed WV.
		_rect(out, c, Rect2(cam, Vector2(960, HEIGHT)), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, clampf(dim, 0, 1)), "background_dim")
	return out

func _join_trees(out: Array, c: Dictionary) -> void:
	if not c.images.has("tree"): return
	var tiles: Array = c.level.get("tiles", [])
	if tiles.is_empty(): return
	var size := _size(c, "tree")
	var x := 0.0
	var index := 0
	while x < float(c.camera.x) + float(c.width) + 400:
		var stride := _dimensions(c, str(tiles[index % tiles.size()])).x
		if stride <= 0: break
		x += stride
		index += 1
		var relative_x := source_round(x - float(c.camera.x) - size.x * 0.44)
		if relative_x > -size.x and relative_x < float(c.width):
			_texture(out, c, "tree", Vector2(float(c.camera.x) + relative_x, float(c.ground) - size.y + 8 + float(c.y_snap)), "join_tree", index % 2 != 0, {"index": index})

func _decor(out: Array, c: Dictionary) -> void:
	for row in c.level.get("decor", []):
		var key := str(row[0])
		var size := _size(c, key)
		var x := float(row[1]) - float(c.camera.x)
		if x > float(c.width) + 10 or x + size.x < -10: continue
		# Mirrored source decor rounds its right edge before reflecting. At
		# native integer image widths this equals rounding the left edge.
		_texture(out, c, key, Vector2(_x(c, float(row[1])), float(row[2]) + float(c.y_snap)), "decor", row.size() > 3 and bool(row[3]))

func _checkpoints(out: Array, c: Dictionary, host, world_one) -> void:
	var checks: Array = []
	var combat = host.get("combat")
	if combat != null:
		checks = combat.get("checks")
	else:
		for x in c.level.get("checks", []): checks.append({"x": float(x), "hit": false})
	for checkpoint in checks:
		var relative_x := source_round(float(checkpoint.x) - float(c.camera.x))
		if relative_x < -60 or relative_x > float(c.width) + 60: continue
		var top := INF
		if world_one != null:
			var surface: Dictionary = world_one.below(host, float(checkpoint.x), -9999)
			if not surface.is_empty(): top = float(surface.row[2])
		else:
			for row in c.level.get("solids", []) + c.level.get("plats", []):
				if float(checkpoint.x) >= float(row[0]) and float(checkpoint.x) <= float(row[1]) and float(row[2]) >= -10001:
					top = minf(top, float(row[2]))
		if is_inf(top): continue
		var x := float(c.camera.x) + relative_x
		var y := top + float(c.y_snap)
		var wave := sin(float(host.elapsed) / 0.16) * 3
		_rect(out, c, Rect2(x - 3, y - 150, 6, 150), Color("2a2f3d"), "checkpoint_pole")
		_rect(out, c, Rect2(x - 6, y - 156, 12, 8), GOLD, "checkpoint_cap")
		out.append({"type": "polygon", "points": PackedVector2Array([Vector2(x + 3, y - 146), Vector2(x + 58, y - 132 + wave), Vector2(x + 3, y - 112)]),
			"colour": Color("2d6a4f") if checkpoint.hit else Color("7a8aa8"), "tag": "checkpoint_flag"})
		_rect(out, c, Rect2(x + 14, y - 132, 12, 4), Color("f5f1ea"), "checkpoint_mark")

func _alley(out: Array, c: Dictionary) -> void:
	for obstacle in c.level.get("obs", []):
		var key := str(obstacle[0])
		var relative_x := source_round(float(obstacle[1]) - float(c.camera.x))
		if relative_x < -200 or relative_x > float(c.width) + 200: continue
		var size := _size(c, key)
		_texture(out, c, key, Vector2(float(c.camera.x) + relative_x - size.x / 2, float(c.ground) - size.y + 4 + float(c.y_snap)), "alley_obstacle")
	# Source levelDraw runs after checks, but before actors, crates and pickups.
	_rect(out, c, Rect2(float(c.camera.x), float(c.y_snap), float(c.width), float(c.ground) - 160), Color(20 / 255.0, 24 / 255.0, 48 / 255.0, 0.18), "alley_gloom")

func _awnings(out: Array, c: Dictionary) -> void:
	for row in c.level.get("plats", []):
		var x := _x(c, float(row[0]))
		var width := float(row[1]) - float(row[0])
		if x - float(c.camera.x) > float(c.width) or x + width - float(c.camera.x) < 0: continue
		var y := float(row[2]) + float(c.y_snap)
		var stripe := 0
		# Deliberately no trim of the last 26px stripe: that's what source paints.
		while stripe * 26 < width:
			_rect(out, c, Rect2(x + stripe * 26, y - 2, 26, 18), Color("f5f1ea") if stripe % 2 else Color("2d6a4f"), "awning_stripe")
			stripe += 1
		_rect(out, c, Rect2(x, y + 16, width, 4), Color("1b3d2e"), "awning_edge")
		_rect(out, c, Rect2(x + 6, y + 20, 4, float(c.ground) - float(row[2]) - 20), Color("333a48"), "awning_post")
		_rect(out, c, Rect2(x + width - 10, y + 20, 4, float(c.ground) - float(row[2]) - 20), Color("333a48"), "awning_post")

func build_front(host, _world_one = null) -> Array:
	var out: Array = []
	# bd-fixes clears LV.front in every source World 1 page. Never restore the
	# sweeping foreground lamps/leaves still present in imported metadata.
	if host.level_id != "1-S" or float(host.elapsed) >= 6: return out
	var c := _context(host)
	var alpha := minf(1, (6 - float(host.elapsed)) / 0.6)
	var center := float(c.camera.x) + float(c.width) / 2
	# Keep source y=80, even though bottom-anchored zoom can clip this strip.
	out.append({"type": "rounded_rect", "rect": Rect2(center - 170, 80 + float(c.y_snap), 340, 34), "radius": 17,
		"colour": Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.85 * alpha), "outline": Color(GOLD, alpha), "width": 2, "tag": "partner_strip"})
	out.append({"type": "plain_text", "position": Vector2(center, 98 + float(c.y_snap)), "text": "Bonus level with thanks to our partner", "size": 11,
		"colour": Color(GOLD, alpha), "tag": "partner_text"})
	return out

func _context(host) -> Dictionary:
	return {"images": host.images, "dims": host.meta.get("dims", {}), "level": host.level, "camera": host.camera,
		"width": float(host.view_width()), "ground": float(host.meta.get("ground", 482)),
		"view": Rect2(host.camera.x, host.view_top(), host.view_width(), host.camera.y + HEIGHT - host.view_top()),
		"y_snap": host.camera.y - source_round(host.camera.y)}

static func source_round(value: float) -> float:
	return floorf(value + 0.5)

func _x(c: Dictionary, x: float) -> float:
	return float(c.camera.x) + source_round(x - float(c.camera.x))

func _size(c: Dictionary, key: String) -> Vector2:
	return c.images[key].get_size() if c.images.has(key) else Vector2.ZERO

func _dimensions(c: Dictionary, key: String) -> Vector2:
	return Vector2(c.dims[key][0], c.dims[key][1]) if c.dims.has(key) else _size(c, key)

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
	if rectangle.has_area() and rectangle.intersects(c.view): out.append({"type": "rect", "rect": rectangle, "colour": colour, "tag": tag})

func draw_commands(host, commands: Array) -> void:
	var batch: Array = []
	for command in commands:
		if command.type not in ["polygon", "rounded_rect", "plain_text"]:
			batch.append(command)
			continue
		_painter.draw_commands(host, batch)
		batch.clear()
		match command.type:
			"polygon": host.draw_colored_polygon(command.points, command.colour)
			"rounded_rect":
				var style := StyleBoxFlat.new()
				style.bg_color = command.colour
				style.border_color = command.outline
				style.set_border_width_all(command.width)
				style.set_corner_radius_all(command.radius + command.width / 2)
				style.corner_detail = 16
				# Canvas strokes straddle their path; StyleBox borders are inset.
				host.draw_style_box(style, command.rect.grow(command.width / 2.0))
			"plain_text":
				var size: Vector2 = host.font.get_string_size(command.text, HORIZONTAL_ALIGNMENT_LEFT, -1, command.size)
				var baseline: Vector2 = command.position + Vector2(-size.x / 2, (host.font.get_ascent(command.size) - host.font.get_descent(command.size)) / 2)
				host.draw_string(host.font, baseline, command.text, HORIZONTAL_ALIGNMENT_LEFT, -1, command.size, command.colour)
	_painter.draw_commands(host, batch)

func clear_cache() -> void:
	_painter.clear_cache()
