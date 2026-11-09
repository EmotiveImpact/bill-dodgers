extends RefCounted
## Native rendering of game/1-2/index.html drawSky/drawClimb/drawLevel.
## The host has already applied the world camera and bottom-anchored zoom.
## Regions are clipped mathematically, so roof tiles never paint over an alley.
## The imported textures and source level/decor coordinates stay unmodified.

const HEIGHT := 540.0
const SKY_COLOURS := [Color("5b4a8a"), Color("e98a6a"), Color("f6c27a")]
const GOLD := Color("f4c542")
var _filtered_textures: Dictionary = {}

func draw_scene(host, scene = null) -> void:
	draw_commands(host, build_scene(host, scene))

func draw_front(host, _scene = null) -> void:
	# Only the source tutorial hint. Sweeping foreground props were removed by
	# bd-fixes in the original game and must not be reintroduced here.
	draw_commands(host, build_front(host))

func build_scene(host, scene = null) -> Array:
	var context := _context(host)
	var commands: Array = []
	_sky(commands, context)
	_level(commands, context, [] if scene == null else scene.crumbles)
	return commands

func _context(host) -> Dictionary:
	return {
		"images": host.images, "dims": host.meta.get("dims", {}),
		"level": host.level, "camera": host.camera,
		"ground": float(host.meta.get("ground", 482)),
		"width": float(host.view_width()),
		"view": Rect2(host.camera.x, host.view_top(), host.view_width(), HEIGHT + host.camera.y - host.view_top()),
		# Canvas source translates by -Math.round(camY), whereas the host's
		# world transform uses -camera.y. Compensate once, for artwork only.
		"y_snap": host.camera.y - source_round(host.camera.y)
	}

static func source_round(value: float) -> float:
	# JavaScript Math.round(-0.5) is 0, unlike GDScript round(-0.5).
	return floorf(value + 0.5)

func _x(c: Dictionary, world_x: float) -> float:
	return c.camera.x + source_round(world_x - c.camera.x)

func _size(c: Dictionary, key: String) -> Vector2:
	if c.dims.has(key):
		var dimensions: Array = c.dims[key]
		return Vector2(dimensions[0], dimensions[1])
	if c.images.has(key): return c.images[key].get_size()
	return Vector2.ZERO

func _sky(out: Array, c: Dictionary) -> void:
	var cam: Vector2 = c.camera
	_gradient(out, c, Rect2(cam + Vector2(-10, -10), Vector2(c.width + 20, HEIGHT + 20)),
		[cam.y, cam.y + HEIGHT / 2, cam.y + HEIGHT], SKY_COLOURS, "sky_gradient")
	if not c.images.has("sky"): return
	var sky := _size(c, "sky")
	if sky.x <= 0 or sky.y <= 0: return
	var roofs: Array = c.level.get("roofs", [])
	var roof_camera := float(roofs[0][2]) - float(c.ground) + 30 if not roofs.is_empty() else 0.0
	var bottom := source_round(470 + (cam.y - roof_camera) * 0.08)
	var sx := fmod(-source_round(cam.x * 0.12), sky.x)
	var tile_index := int(floorf(cam.x * 0.12 / sky.x))
	while sx < c.width:
		_texture(out, c, "sky", Rect2(cam + Vector2(sx, bottom - sky.y), sky),
			"sky", tile_index % 2 != 0, 1, null, true)
		sx += sky.x
		tile_index += 1
	if not c.images.has("far"): return
	var far := _size(c, "far")
	if far.x <= 0 or far.y <= 0: return
	var fy := bottom - 34
	_gradient(out, c, Rect2(cam + Vector2(-10, fy + far.y - 30), Vector2(c.width + 20, HEIGHT + 60)),
		[cam.y + fy + far.y - 30, cam.y + HEIGHT + 40], [Color("5e4a72"), Color("2c2236")], "far_haze")
	var fx := fmod(-source_round(cam.x * 0.3), far.x) - far.x
	while fx < c.width + far.x:
		_texture(out, c, "far", Rect2(cam + Vector2(fx, fy), far), "far_back")
		fx += far.x
	fx = fmod(-source_round(cam.x * 0.42), far.x) - far.x * 1.5
	while fx < c.width + far.x:
		_texture(out, c, "far", Rect2(cam + Vector2(source_round(fx), fy + 40), far), "far_front", false, 0.85)
		fx += far.x
	_rect(out, c, Rect2(cam + Vector2(-10, fy + 40 + far.y - 24), Vector2(c.width + 20, HEIGHT)), Color(44 / 255.0, 34 / 255.0, 54 / 255.0, 0.55), "far_shade")

func _level(out: Array, c: Dictionary, crumbles: Array) -> void:
	var level: Dictionary = c.level
	var camera: Vector2 = c.camera
	var vb := camera.y + HEIGHT + 20
	var ys := float(c.y_snap)
	# Behind the paintings, not stand-in collision platforms.
	for roof in level.get("roofs", []):
		_rect(out, c, Rect2(_x(c, roof[0]) - 2, roof[2] + 30 + ys, roof[1] - roof[0] + 4, maxf(0, vb - roof[2])), Color("2a2230"), "alley_back")
	var climb: Array = level.get("climb", [])
	if climb.size() >= 2:
		var start := float(climb[0])
		var width := _size(c, "climb").x
		if start + width - camera.x > -10:
			_climb(out, c, start, float(climb[1]), true)
			_yard(out, c, start, width, vb)
	for decor in level.get("decor", []):
		if decor[0] == "climb2": _climb(out, c, decor[1], decor[2], false)
	var roof_size := _size(c, "roof")
	var front_size := _size(c, "front")
	for roof in level.get("roofs", []):
		var left := float(roof[0])
		var right := float(roof[1])
		if right - camera.x < -20 or left - camera.x > c.width + 20: continue
		var top := float(roof[2]) - float(level.get("ridge", 4))
		var clip := Rect2(_x(c, left), top - 2 + ys, right - left, vb - top + 4)
		# Every building restarts the pattern at its own left boundary.
		if front_size.x > 0 and front_size.y > 0:
			var y := top + roof_size.y - 4
			while y < vb:
				var x := left
				while x < right:
					_texture(out, c, "front", Rect2(_x(c, x), source_round(y) + ys, front_size.x, front_size.y), "roof_front", false, 1, clip)
					x += front_size.x
				y += front_size.y
		if roof_size.x > 0 and roof_size.y > 0:
			var x := left
			while x < right:
				_texture(out, c, "roof", Rect2(_x(c, x), top + ys, roof_size.x, roof_size.y), "roof", false, 1, clip)
				x += roof_size.x
		var shadow := Color(20 / 255.0, 14 / 255.0, 24 / 255.0, 0.45)
		_rect(out, c, Rect2(_x(c, left), roof[2] + 2 + ys, 4, vb - roof[2]), shadow, "roof_edge")
		_rect(out, c, Rect2(_x(c, right) - 4, roof[2] + 2 + ys, 4, vb - roof[2]), shadow, "roof_edge")
	for decor in level.get("decor", []):
		if decor[0] == "climb2" or not c.images.has(decor[0]): continue
		var key: String = decor[0]
		var dimensions := _size(c, key)
		var x := float(decor[1])
		var y := float(decor[2])
		if x - camera.x > c.width + 10 or x + dimensions.x - camera.x < -10: continue
		var alpha := 1.0
		var variant := int(decor[3]) if decor.size() > 3 else 0
		if variant == 2:
			for slate in crumbles:
				if absf(float(slate.row[0]) - 6 - x) >= 2: continue
				var fall := float(slate.fall)
				if fall > 0:
					# Runtime is seconds; the original uses fall milliseconds.
					if fall > 0.7:
						alpha = 0
					else:
						y += fall * fall * 1200
						alpha = maxf(0, 1 - fall / 0.7)
				elif float(slate.t) > 0:
					# Rendering must not advance the gameplay RNG. A deterministic
					# shake stays in the source ±2px range and freezes on pause.
					x += sin(float(slate.t) * 113 + x * 0.73) * 2
				break
		if alpha <= 0: continue
		_texture(out, c, key, Rect2(_x(c, x), source_round(y) + ys, dimensions.x, dimensions.y), "decor", variant == 1, alpha)

func _yard(out: Array, c: Dictionary, start: float, climb_width: float, vb: float) -> void:
	var ground := float(c.ground)
	var ys := float(c.y_snap)
	_rect(out, c, Rect2(_x(c, 0) - 400, ground - 120 + ys, start + 400, 120), Color("7d4a36"), "yard_wall")
	var y := ground - 120
	while y < ground:
		var x := -400 + fmod(y / 10, 2) * 14
		while x < start:
			var colour := Color("9a5a40") if not is_zero_approx(fmod(x + y, 3)) else Color("8a4f39")
			_rect(out, c, Rect2(_x(c, x), y + ys, 26, 8), colour, "yard_brick")
			x += 28
		y += 10
	_rect(out, c, Rect2(_x(c, 0) - 400, ground - 126 + ys, start + 400, 8), Color("c9b79a"), "yard_cap")
	_rect(out, c, Rect2(_x(c, 50), ground - 104 + ys, 54, 104), Color("2f5d3a"), "yard_gate")
	_rect(out, c, Rect2(_x(c, 54), ground - 100 + ys, 46, 96), Color("3f7d4c"), "yard_gate_inner")
	var x := -400.0
	while x < start + climb_width:
		y = ground
		while y < vb:
			var colour := Color("8e8476") if not is_zero_approx(fmod(x / 64 + y / 32, 2)) else Color("978d7f")
			_rect(out, c, Rect2(_x(c, x), y + ys, 62, 30), colour, "yard_paving")
			y += 32
		x += 64

func _climb(out: Array, c: Dictionary, start: float, top: float, mirrored_back: bool) -> void:
	var size := _size(c, "climb")
	if not c.images.has("climb") or size.x <= 0 or size.y <= 0: return
	if start + size.x - c.camera.x < -10 or start - c.camera.x > c.width + 10: return
	var ys := float(c.y_snap)
	if mirrored_back:
		# Source paints a reflected duplicate left of X0 AND the regular house
		# to its right. This is not just a flipped replacement for the house.
		_texture(out, c, "climb", Rect2(_x(c, start) - size.x, top + ys, size.x, size.y), "climb_mirror", true)
		_rect(out, c, Rect2(_x(c, start - size.x), top + 30 + ys, size.x, size.y), Color(20 / 255.0, 14 / 255.0, 24 / 255.0, 0.35), "climb_mirror_shade")
	_texture(out, c, "climb", Rect2(_x(c, start), top + ys, size.x, size.y), "climb")
	var front := _size(c, "front")
	if not c.images.has("front") or front.x <= 0 or front.y <= 0: return
	var clip := Rect2(_x(c, start), top + size.y - 2 + ys, size.x, 2000)
	var y := top + size.y - 2
	while y < c.camera.y + HEIGHT + 20:
		var x := start
		while x < start + size.x:
			_texture(out, c, "front", Rect2(_x(c, x), y + ys, front.x, front.y), "climb_front", false, 1, clip)
			x += front.x
		y += front.y
	_rect(out, c, clip, Color(20 / 255.0, 14 / 255.0, 24 / 255.0, 0.25), "climb_front_shade")

func build_front(host) -> Array:
	var out: Array = []
	if host.mode != "play" or host.elapsed <= 3.4 or host.hearts <= 0: return out
	var ground := float(host.meta.get("ground", 482))
	if host.player.y <= ground - 40: return out
	var plats: Array = host.level.get("plats", [])
	if plats.is_empty(): return out
	var c := _context(host)
	var platform: Array = plats[0]
	var x := _x(c, (float(platform[0]) + float(platform[1])) / 2)
	# level time rather than wall time makes the native hint pause correctly.
	var y := float(platform[2]) - 70 + sin(float(host.elapsed) / 0.18) * 5 + float(c.y_snap)
	var points := PackedVector2Array([Vector2(x, y - 12), Vector2(x + 14, y + 4), Vector2(x + 5, y + 4), Vector2(x + 5, y + 18), Vector2(x - 5, y + 18), Vector2(x - 5, y + 4), Vector2(x - 14, y + 4)])
	out.append({"type": "text", "position": Vector2(x, y - 30), "text": "Up the fire escape!", "size": 13, "colour": GOLD, "outline": Color("0e1726"), "stroke_width": 3.25, "tag": "climb_hint"})
	out.append({"type": "outlined_polygon", "points": points, "colour": GOLD, "outline": Color("0e1726"), "width": 3.0, "tag": "climb_hint"})
	return out

static func clipped_region(destination: Rect2, source: Rect2, clip: Rect2, flip_h: bool = false) -> Dictionary:
	# Clip destination and corresponding original pixels. Cropping a tile must
	# never stretch its remaining art to fit a partial roof or facade.
	if destination.size.x <= 0 or destination.size.y <= 0 or not clip.has_area(): return {}
	var visible := destination.intersection(clip)
	if not visible.has_area(): return {}
	var ratio := source.size / destination.size
	var offset := visible.position - destination.position
	if flip_h: offset.x = destination.end.x - visible.end.x
	return {"rect": visible, "source": Rect2(source.position + offset * ratio, visible.size * ratio)}

func _texture(out: Array, c: Dictionary, key: String, destination: Rect2, tag: String, flip_h: bool = false, alpha: float = 1, clip = null, smooth: bool = false) -> void:
	if not c.images.has(key) or not destination.has_area(): return
	var source := Rect2(Vector2.ZERO, c.images[key].get_size())
	if clip != null:
		var cropped := clipped_region(destination, source, clip, flip_h)
		if cropped.is_empty(): return
		destination = cropped.rect
		source = cropped.source
	if not destination.intersects(c.view): return
	out.append({"type": "texture", "key": key, "rect": destination, "source": source,
		"flip_h": flip_h, "alpha": alpha, "smooth": smooth, "tag": tag})

func _rect(out: Array, c: Dictionary, rectangle: Rect2, colour: Color, tag: String) -> void:
	if rectangle.has_area() and rectangle.intersects(c.view):
		out.append({"type": "rect", "rect": rectangle, "colour": colour, "tag": tag})

func _gradient(out: Array, c: Dictionary, rectangle: Rect2, stops: Array, colours: Array, tag: String) -> void:
	if not rectangle.has_area() or not rectangle.intersects(c.view): return
	# Vertex colours reproduce the source continuous gradient without baking a
	# downsampled replacement image. Clamp at both colour stops, as canvas does.
	var boundaries: Array[float] = [rectangle.position.y, rectangle.end.y]
	for stop in stops:
		if stop > rectangle.position.y and stop < rectangle.end.y: boundaries.append(stop)
	boundaries.sort()
	for index in range(boundaries.size() - 1):
		var top := boundaries[index]
		var bottom := boundaries[index + 1]
		var band := Rect2(rectangle.position.x, top, rectangle.size.x, bottom - top)
		if not band.intersects(c.view): continue
		var top_colour := _gradient_colour(top, stops, colours)
		var bottom_colour := _gradient_colour(bottom, stops, colours)
		out.append({"type": "gradient", "rect": band,
			"colours": PackedColorArray([top_colour, top_colour, bottom_colour, bottom_colour]), "tag": tag})

func _gradient_colour(y: float, stops: Array, colours: Array) -> Color:
	# The source's two-stop haze can reverse if a debug camera is below ground.
	if stops.size() == 2:
		var span := float(stops[1]) - float(stops[0])
		return colours[0].lerp(colours[1], clampf((y - float(stops[0])) / span, 0, 1)) if not is_zero_approx(span) else colours[1]
	if y <= float(stops[0]): return colours[0]
	for index in range(stops.size() - 1):
		if y <= float(stops[index + 1]):
			return colours[index].lerp(colours[index + 1], (y - float(stops[index])) / (float(stops[index + 1]) - float(stops[index])))
	return colours.back()

func _filtered(texture: Texture2D, smooth: bool) -> CanvasTexture:
	var key := "%s:%s" % [texture.get_instance_id(), smooth]
	if not _filtered_textures.has(key):
		var canvas := CanvasTexture.new()
		canvas.diffuse_texture = texture
		canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if smooth else CanvasItem.TEXTURE_FILTER_NEAREST
		_filtered_textures[key] = canvas
	return _filtered_textures[key]

func clear_cache() -> void:
	_filtered_textures.clear()

func draw_commands(host, commands: Array) -> void:
	for command in commands:
		match command.type:
			"texture":
				var destination: Rect2 = command.rect
				if command.flip_h:
					# Godot mirrors inside the original left/top bounds.
					destination.size.x = -destination.size.x
				host.draw_texture_rect_region(_filtered(host.images[command.key], command.smooth), destination, command.source, Color(1, 1, 1, command.alpha))
			"rect": host.draw_rect(command.rect, command.colour)
			"gradient":
				var r: Rect2 = command.rect
				host.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), command.colours)
			"outlined_polygon":
				var outline: PackedVector2Array = command.points.duplicate()
				outline.append(outline[0])
				host.draw_polyline(outline, command.outline, command.width)
				host.draw_colored_polygon(command.points, command.colour)
			"text":
				var text_size: Vector2 = host.font.get_string_size(command.text, HORIZONTAL_ALIGNMENT_LEFT, -1, command.size)
				var baseline: Vector2 = command.position + Vector2(-text_size.x / 2, (host.font.get_ascent(command.size) - host.font.get_descent(command.size)) / 2)
				host.draw_string_outline(host.font, baseline, command.text, HORIZONTAL_ALIGNMENT_LEFT, -1, command.size, int(ceilf(command.stroke_width / 2)), command.outline)
				host.draw_string(host.font, baseline, command.text, HORIZONTAL_ALIGNMENT_LEFT, -1, command.size, command.colour)
