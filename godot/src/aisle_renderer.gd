extends "res://src/supermarket_renderer.gd"
## Source 2-2 Aisle seven / Frozen foods painter. World pixels, seconds.
## The host supplies the bottom-anchored camera transform. Imported paintings
## stay at source resolution; only authored islands scale a cropped bay.
## Physics, hazard clocks, progress and scene switching belong to the runtime.

const PRODUCTS := ["e23b3b", "f4c542", "2d6a4f", "3f7fd8", "ff8fc7", "7a4fd0", "f08a24", "1fa39a", "ffffff", "9fd18d", "d64545", "5bc0eb", "c94f9b", "ffd27a"]
var _gate_art_cache: Dictionary = {}

func supports(id: String) -> bool:
	return id == "2-2"

func _in_view(c: Dictionary, x0: float, x1: float) -> bool:
	return x1 > float(c.camera.x) - 40 and x0 < float(c.camera.x) + float(c.width) + 40

func _scene_x(c: Dictionary) -> float:
	var scenes: Array = c.level.get("scenes", [])
	return float(scenes[0][0]) if not scenes.is_empty() else 10400.0

func build_sky(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	var key := "aisle" if int(_state(runtime, "scene_index", 0)) == 0 else "freezer"
	var size := _size(c, key)
	if size == Vector2.ZERO:
		_rect(out, Rect2(c.camera.x - 10, c.camera.y - 10, c.width + 20, HEIGHT + 20), Color("d7e6df"), "missing_painting_fill")
		return out
	var top := float(c.ground) - 0.82 * size.y - float(c.camera.y)
	_rect(out, Rect2(c.camera.x - 10, c.camera.y - 10, c.width + 20, top + 10).abs(), Color("cfd3e6" if key == "aisle" else "1b2a4a"), "aisle_ceiling_fill")
	# Exclude the painted number 7 from the ceiling crop, then hang a sign at
	# its independent parallax between the ceiling and wall layers.
	_tile_row(out, c, key, _crop(c, key, 0, 0, 0.45 if key == "aisle" else 1.0, 0.22), 0.6, top, "aisle_ceiling", 0.22 * size.y)
	var scroll := float(c.camera.x) * 0.8
	for i in range(int(floorf(scroll / 1500)) - 1, int(floorf((scroll + float(c.width)) / 1500)) + 2):
		var origin := Vector2(float(c.camera.x) + source_round(i * 1500 + 500 - scroll), float(c.camera.y) + source_round(top - 40))
		if Rect2(origin, Vector2(120, 150)).intersects(c.view): _aisle_sign(out, origin, 7 if key == "aisle" else 8)
	_tile_row(out, c, key, _crop(c, key, 0, 0.22, 1, 1), 1.0, top + 0.22 * size.y, "aisle_wall")
	return out

func _aisle_sign(out: Array, origin: Vector2, number: int) -> void:
	for row in [[Rect2(28, 0, 3, 60), "9aa5b8"], [Rect2(89, 0, 3, 60), "9aa5b8"], [Rect2(0, 56, 120, 94), "14243b"], [Rect2(4, 60, 112, 86), "2d6a4f"], [Rect2(4, 60, 112, 10), "3f8f63"], [Rect2(4, 136, 112, 6), "f4c542"]]:
		_rect(out, Rect2(origin + row[0].position, row[0].size), Color(row[1]), "aisle_sign")
	out.append({"type": "text", "position": origin + Vector2(60, 102), "text": str(number), "size": 64, "colour": Color.WHITE, "tag": "aisle_sign_number"})

func build_level(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	var aisle := int(_state(runtime, "scene_index", 0)) == 0
	var scene_x := _scene_x(c)
	var ys := float(c.y_snap)
	var ground := float(c.ground)
	if aisle and c.images.has("strip") and _in_view(c, scene_x - 160, scene_x + 160):
		var size := _size(c, "strip")
		var x := _x(c, scene_x - size.x / 2)
		_rect(out, Rect2(x, ground - 4 + ys, size.x, 8), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.3), "strip_door_shadow")
		_texture(out, c, "strip", Rect2(x, ground - size.y + 4 + ys, size.x, size.y), "strip_doors")
	elif aisle and _in_view(c, scene_x - 140, scene_x + 160):
		_strip_fallback(out, c, scene_x, float(_state(runtime, "elapsed", host.elapsed)))
	for island in c.level.get("islands", []):
		var a := float(island[0])
		var b := float(island[1])
		if (a < scene_x) != aisle or not _in_view(c, a - 6, b + 16): continue
		_rect(out, Rect2(_x(c, a - 6), ground - 4 + ys, b - a + 22, 12), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.28), "island_shadow")
		_island(out, c, Vector2(_x(c, a), source_round(ground - 236) + ys), b - a, "aisle" if a < scene_x else "freezer", int(a))
	return out

func _strip_fallback(out: Array, c: Dictionary, scene_x: float, elapsed: float) -> void:
	var x := _x(c, scene_x - 120)
	var y := float(c.ground) - 280 + float(c.y_snap)
	for row in [[Rect2(0, 0, 240, 280), Color("9aa5b8")], [Rect2(6, 6, 228, 12), Color("c7d0dc")], [Rect2(14, 22, 212, 258), Color("1b2a4a")], [Rect2(14, 22, 212, 258), Color(120 / 255.0, 190 / 255.0, 240 / 255.0, 0.5)]]:
		_rect(out, Rect2(Vector2(x, y) + row[0].position, row[0].size), row[1], "strip_door_fallback")
	for i in 9:
		var sway := sin(elapsed / 0.5 + i) * 2
		# x is already screen-snapped, but retain source's second round here.
		var strip_x := float(c.camera.x) + source_round(x - float(c.camera.x) + 16 + i * 23 + sway)
		_rect(out, Rect2(strip_x, y + 24, 20, 254), Color(220 / 255.0, 240 / 255.0, 1, 0.55) if i % 2 else Color(190 / 255.0, 225 / 255.0, 250 / 255.0, 0.45), "strip_door_fallback_strip")
	_rect(out, Rect2(x + 50, y - 46, 140, 40), Color("2b3850"), "strip_door_fallback_label")
	# During source play the canvas inherits the shared txt middle baseline.
	out.append({"type": "text", "position": Vector2(x + 120, y - 20), "text": "FROZEN", "size": 18, "colour": Color("bfe6f7"), "tag": "strip_door_fallback_text"})

func _island(out: Array, c: Dictionary, origin: Vector2, width: float, key: String, seed: int) -> void:
	var bay := _crop(c, key, 0.065, 0.46, 0.345, 0.775) if key == "aisle" else _crop(c, key, 0.045, 0.27, 0.37, 0.76)
	if not bay.has_area():
		# Missing shipped content is explicit; do not substitute invented art.
		_rect(out, Rect2(origin, Vector2(width, 236)), Color("d7e6df"), "missing_island_painting")
	else:
		var tile_width := source_round(bay.size.x * 226 / bay.size.y)
		var px := 0.0
		var index := seed % 2
		while px < width:
			var visible_width := minf(tile_width, width - px)
			var source := bay
			source.size.x *= visible_width / tile_width
			var flip := index % 2 != 0
			if flip: source.position.x += bay.size.x - source.size.x
			_texture(out, c, key, Rect2(origin + Vector2(px, 10), Vector2(visible_width, 226)), "island_bay", source, flip, {"island_width": width, "tile_width": tile_width, "index": index})
			px += tile_width
			index += 1
	var frame := Color("2f9a3c" if key == "aisle" else "9aa5b8")
	var highlight := Color("6fd36a" if key == "aisle" else "dfe7ee")
	var end_colour := Color("1f7a2e" if key == "aisle" else "6e778c")
	for row in [[Rect2(0, 0, width, 12), frame], [Rect2(0, 0, width, 3), highlight], [Rect2(0, 232, width, 4), Color("14243b")], [Rect2(0, 0, 12, 236), end_colour], [Rect2(width - 12, 0, 12, 236), end_colour], [Rect2(0, 0, 3, 236), Color("14243b")], [Rect2(width - 3, 0, 3, 236), Color("14243b")], [Rect2(0, 0, width, 2), Color("14243b")], [Rect2(12, 12, width - 24, 220), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.12)]]:
		_rect(out, Rect2(origin + row[0].position, row[0].size), row[1], "island_frame")

func _hazards(host, runtime) -> Array:
	return _state(runtime, "hazards", host.level.get("hz", []))

func _controls(host, runtime) -> Dictionary:
	var controller = _state(runtime, "hazard_controller", null)
	if controller != null:
		return {"gates": _state(controller, "gates", []), "plates": _state(controller, "plates", []), "buttons": _state(controller, "buttons", [])}
	# Allows the painter to be inspected before the optional controller is wired.
	# Closed defaults are visual only and never create colliders or active timers.
	var result := {"gates": [], "plates": [], "buttons": []}
	for h in _hazards(host, runtime):
		match h[0]:
			"gate": result.gates.append({"x": h[1], "floor": h[2], "h": h[3], "id": h[4], "open": 0.0, "timer": 0.0, "held": false})
			"plate": result.plates.append({"x": h[1], "y": h[2], "id": h[3], "on": false})
			"button": result.buttons.append({"x": h[1], "y": h[2], "id": h[3], "hit": 0.0})
	return result

func build_mid(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	var elapsed := float(_state(runtime, "elapsed", host.elapsed))
	var controls := _controls(host, runtime)
	var ys := float(c.y_snap)
	for plate in controls.plates:
		if not _in_view(c, float(plate.x) - 50, float(plate.x) + 50): continue
		var x := _x(c, float(plate.x))
		var y := float(plate.y) + ys
		var pressed := bool(plate.get("on", false))
		_border(out, Rect2(x - 48, y - (3 if pressed else 7), 96, 6 if pressed else 10), 4, Color("9fe0b8" if pressed else "f4c542"), Color("14243b"), 2, "pressure_plate")
		for i in range(-40, 40, 16):
			_rect(out, Rect2(x + i, y - (2 if pressed else 6), 7, 4 if pressed else 8), Color("14243b"), "pressure_plate_groove")
		if not pressed and int(floorf(elapsed / 0.4)) % 2:
			for gate in controls.gates:
				if gate.id != plate.id: continue
				if float(gate.get("open", 0)) < 0.5: _poly(out, [Vector2(x - 10, y - 40), Vector2(x + 10, y - 40), Vector2(x, y - 24)], GOLD, "pressure_plate_arrow")
				break
	for gate in controls.gates:
		if not _in_view(c, float(gate.x) - 60, float(gate.x) + 60): continue
		var x := _x(c, float(gate.x))
		var h := float(gate.h)
		var openness := float(gate.get("open", 0))
		var floor_y := float(gate.floor) + ys
		var top := floor_y - h - source_round(openness * (h + 40))
		var rail_y := float(c.view.position.y) - 10 + ys
		var rail_height := float(gate.floor) - h - float(c.view.position.y) + 20
		_rect(out, Rect2(x - 40, rail_y, 6, rail_height).abs(), Color("5b6578"), "gate_rail")
		_rect(out, Rect2(x + 34, rail_y, 6, rail_height).abs(), Color("5b6578"), "gate_rail")
		for command in _gate_art(h):
			var translated: Dictionary = command.duplicate()
			translated.rect = Rect2(command.rect.position + Vector2(x - 36, top), command.rect.size)
			out.append(translated)
		var remaining := float(gate.get("timer", 0))
		if openness > 0 and not bool(gate.get("held", false)) and remaining > 0:
			var center := Vector2(x, floor_y - h - 60)
			_arc(out, center, 16, 0, 6.3, Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.6), 5, "gate_timer_back")
			_arc(out, center, 16, -1.57, 6.283 * minf(1, remaining / 5.2), GOLD, 5, "gate_timer")
	for button in controls.buttons:
		if not _in_view(c, float(button.x) - 30, float(button.x) + 30): continue
		var x := _x(c, float(button.x))
		var y := float(button.y) + ys
		var open := false
		for gate in controls.gates:
			if gate.id == button.id and float(gate.get("open", 0)) > 0.5: open = true
		_border(out, Rect2(x - 22, y - 22, 44, 44), 10, Color("14243b"), Color("c7d0dc"), 3, "gate_button_back")
		var colour := Color("9fe0b8") if open else (Color.WHITE if float(button.get("hit", 0)) > 0 else Color("3fbf6e" if int(floorf(elapsed / 0.3)) % 2 else "2d8f52"))
		_ellipse(out, Vector2(x, y), Vector2(13, 13), colour, "gate_button")
		_rect(out, Rect2(x - 6, y - 9, 5, 4), Color(1, 1, 1, 0.6), "gate_button_glint")
	for h in _hazards(host, runtime):
		if h[0] == "ice" and _in_view(c, float(h[1]), float(h[2])): _ice(out, c, h)
		elif h[0] == "belt" and _in_view(c, float(h[1]), float(h[2])): _belt(out, c, h, elapsed)
	# The base painter supplies the common trolley. 2-2 has no authored spawner.
	out.append_array(super.build_mid(host, runtime))
	for entity in _state(runtime, "entities", []):
		if entity.get("k", "") == "drop" and not entity.get("dead", false): _drop(out, c, entity)
	return out

func _border(out: Array, rectangle: Rect2, radius: float, colour: Color, stroke: Color, width: float, tag: String) -> void:
	out.append({"type": "outlined_rounded", "rect": rectangle, "radius": radius, "colour": colour, "stroke": stroke, "width": width, "tag": tag})

func _arc(out: Array, center: Vector2, radius: float, start: float, sweep: float, colour: Color, width: float, tag: String) -> void:
	var points := PackedVector2Array()
	var segments := maxi(1, int(ceilf(absf(sweep) * 16)))
	for i in range(segments + 1):
		var angle := start + sweep * i / segments
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	out.append({"type": "line", "points": points, "colour": colour, "width": width, "center": center, "radius": radius, "start": start, "sweep": sweep, "tag": tag})

static func _random(state: Array) -> float:
	state[0] = (int(state[0]) * 1664525 + 1013904223) & 0xffffffff
	return float(state[0]) / 4294967296.0

static func _rng(seed: int) -> Array:
	var value := (seed * 2654435761) & 0xffffffff
	return [value if value else 1]

static func _shade(colour: Color, amount: float) -> Color:
	var result := colour.lerp(Color.WHITE, amount) if amount > 0 else colour * (1 + amount)
	return Color(source_round(result.r * 255) / 255.0, source_round(result.g * 255) / 255.0, source_round(result.b * 255) / 255.0, 1)

func _r0(out: Array, colour: Color, x: float, y: float, width: float, height: float, tag: String) -> void:
	_rect(out, Rect2(source_round(x), source_round(y), source_round(width), source_round(height)), colour, tag)

func _gate_art(height: float) -> Array:
	if _gate_art_cache.has(height): return _gate_art_cache[height]
	var out: Array = []
	var hh := height + 8
	for row in [[Rect2(0, 0, 72, hh), "1f4d39"], [Rect2(3, 3, 66, hh - 6), "2d6a4f"], [Rect2(8, 18, 56, hh - 26), "e9f0ec"], [Rect2(3, 3, 66, 8), "f4c542"]]:
		_rect(out, row[0], Color(row[1]), "gate_shelf_frame")
	var rng_state := _rng(int(height))
	var y := 76.0
	while y < hh - 6:
		_rect(out, Rect2(6, y, 60, 6), Color("2d6a4f"), "gate_shelf_rail")
		_rect(out, Rect2(10, y + 1, 10, 3), Color.WHITE, "gate_shelf_label")
		y += 58
	y = 18
	while y + 58 <= hh - 6:
		var px := 10.0
		while px < 60:
			var width := 8 + floorf(_random(rng_state) * 10)
			var product_height := 22 + floorf(_random(rng_state) * 26)
			var colour := Color(PRODUCTS[int(floorf(_random(rng_state) * PRODUCTS.size()))])
			if px + width > 62: break
			_r0(out, colour, px, y + 58 - product_height, width, product_height, "gate_product")
			_r0(out, _shade(colour, 0.35), px + 1, y + 58 - product_height + 1, 2, product_height - 2, "gate_product_highlight")
			_r0(out, Color.WHITE, px + 2, y + 58 - product_height * 0.6, width - 4, 3, "gate_product_label")
			px += width + 2
		y += 58
	_rect(out, Rect2(0, hh - 4, 72, 4), Color("9aa5b8"), "gate_shelf_base")
	_gate_art_cache[height] = out
	return out

func _ice(out: Array, c: Dictionary, hazard: Array) -> void:
	var y := float(hazard[3]) if hazard.size() > 3 and hazard[3] else float(c.ground)
	y += float(c.y_snap)
	_rect(out, Rect2(_x(c, float(hazard[1])), y - 2, float(hazard[2]) - float(hazard[1]), 6), Color(210 / 255.0, 240 / 255.0, 1, 0.55), "ice_reflection")
	var x := float(hazard[1]) + 20
	while x < float(hazard[2]):
		_rect(out, Rect2(_x(c, x + fmod(x * 7, 30)), y, 26, 2), Color(1, 1, 1, 0.7), "ice_glint")
		x += 90

func _belt(out: Array, c: Dictionary, hazard: Array, elapsed: float) -> void:
	var y := float(hazard[3]) + float(c.y_snap)
	var x0 := _x(c, float(hazard[1]))
	var width := float(hazard[2]) - float(hazard[1])
	# Hazard tuples remain source units (px/ms); elapsed is native seconds.
	var off := fposmod(source_round(fmod(elapsed * 1000 * float(hazard[4]), 24) + 24), 24)
	_rect(out, Rect2(x0, y, width, 20), Color("1d2433"), "belt_base")
	_rect(out, Rect2(x0, y, width, 6), Color("2f3a50"), "belt_top")
	var x := -24 + off
	while x < width:
		if x >= 0: _rect(out, Rect2(x0 + x, y + 1, 10, 3), Color("4a5670"), "belt_tread")
		x += 24
	_rect(out, Rect2(x0 - 6, y - 2, 6, 24), Color("9aa5b8"), "belt_end")
	_rect(out, Rect2(x0 + width, y - 2, 6, 24), Color("9aa5b8"), "belt_end")
	var direction := signf(float(hazard[4]))
	x = 60
	while x < width - 30:
		_poly(out, [Vector2(x0 + x + direction * 10, y + 12), Vector2(x0 + x - direction * 6, y + 7), Vector2(x0 + x - direction * 6, y + 17)], GOLD if direction > 0 else Color("9fe0b8"), "belt_arrow")
		x += 160

func _drop(out: Array, c: Dictionary, entity: Dictionary) -> void:
	var p: Vector2 = entity.get("p", Vector2(entity.get("x", 0), entity.get("y", 0)))
	var x := _x(c, p.x)
	var ys := float(c.y_snap)
	var age := float(entity.get("t", 0))
	var warn := float(entity.get("warn", 0.95))
	var k := minf(1, age / warn) if warn > 0 else 1.0
	_ellipse(out, Vector2(x, float(entity.get("top", c.ground)) - 2 + ys), Vector2(14 + 20 * k, 5), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.15 + 0.3 * k), "drop_shadow")
	if age >= warn:
		if entity.get("kind", "box") == "icicle":
			_poly(out, [Vector2(x - 14, p.y - 70 + ys), Vector2(x + 14, p.y - 70 + ys), Vector2(x, p.y + ys)], Color("dff3ff"), "falling_icicle")
			_rect(out, Rect2(x - 6, p.y - 66 + ys, 4, 40), Color.WHITE, "icicle_highlight")
		else:
			_box(out, Vector2(x - 32, source_round(p.y - 58) + ys), int(floorf(p.x)) % 5)
	elif int(floorf(age / 0.12)) % 2:
		out.append({"type": "outlined_text", "position": Vector2(x, c.view.position.y + 100 + ys), "text": "!", "size": 22, "colour": Color("ffb3b3"), "outline": Color("0e1726"), "outline_size": 5.5, "tag": "drop_warning"})

func _box(out: Array, origin: Vector2, seed: int) -> void:
	for row in [[Rect2(0, 0, 64, 58), "3f7fd8"], [Rect2(2, 2, 60, 26), "5b97e8"], [Rect2(2, 30, 60, 26), "2c5fae"], [Rect2(26, 0, 12, 58), "f5f1ea"], [Rect2(0, 56, 64, 2), "1f3a66"]]:
		_rect(out, Rect2(origin + row[0].position, row[0].size), Color(row[1]), "falling_box")
	var rng_state := _rng(seed)
	_rect(out, Rect2(origin + Vector2(8, 36 + floorf(_random(rng_state) * 8)), Vector2(12, 6)), Color.WHITE, "falling_box_label")

func build_front(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	var aisle := int(_state(runtime, "scene_index", 0)) == 0
	var scroll := float(c.camera.x) * 1.3
	for index in range(int(floorf(scroll / 2300)) - 1, int(floorf((scroll + float(c.width)) / 2300)) + 2):
		var sx := source_round(index * 2300 + 900 - scroll)
		if sx < -54 or sx > float(c.width) + 20: continue
		var x := float(c.camera.x) + sx
		var top := HEIGHT - 46 + float(c.y_snap)
		var colour := Color(236 / 255.0, 240 / 255.0, 238 / 255.0, 0.92) if aisle else Color(170 / 255.0, 200 / 255.0, 225 / 255.0, 0.9)
		_rect(out, Rect2(x, top + 8, 30, 46), colour, "foreground_bollard")
		_ellipse(out, Vector2(x + 15, top + 8), Vector2(15, 6), colour, "foreground_bollard_cap")
		_rect(out, Rect2(x + 4, top + 10, 3, 46), Color(1, 1, 1, 0.9) if aisle else Color(235 / 255.0, 248 / 255.0, 1, 0.9), "foreground_bollard_highlight")
		if aisle: _rect(out, Rect2(x, top + 18, 30, 8), Color("2d6a4f"), "foreground_bollard_band")
	return out

func clear_cache() -> void:
	super.clear_cache()
	_gate_art_cache.clear()

func draw_commands(host, commands: Array) -> void:
	# Reuse the parking painter's primitives, sprite variants and iris. These
	# two local commands retain source outlines on controls and drop warnings.
	for command in commands:
		match command.type:
			"outlined_rounded":
				var style := StyleBoxFlat.new()
				style.bg_color = command.colour
				style.border_color = command.stroke
				style.set_border_width_all(int(command.width))
				style.set_corner_radius_all(int(source_round(command.radius + command.width / 2)))
				style.corner_detail = 12
				host.draw_style_box(style, command.rect.grow(command.width / 2))
			"outlined_text":
				var text_width: float = host.font.get_string_size(command.text, HORIZONTAL_ALIGNMENT_LEFT, -1, command.size).x
				var baseline: Vector2 = command.position - Vector2(text_width / 2, 0)
				baseline.y += (host.font.get_ascent(command.size) - host.font.get_descent(command.size)) / 2
				host.draw_string_outline(host.font, baseline, command.text, HORIZONTAL_ALIGNMENT_LEFT, -1, command.size, int(source_round(command.outline_size / 2)), command.outline)
				host.draw_string(host.font, baseline, command.text, HORIZONTAL_ALIGNMENT_LEFT, -1, command.size, command.colour)
			_: super.draw_commands(host, [command])
