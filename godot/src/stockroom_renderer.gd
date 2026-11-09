extends "res://src/aisle_renderer.gd"
## Source 2-3 stockroom / top floor painter. World pixels, seconds.
## Reuses common W2 controls, belts, drops, bots and HUD without changing state.
## Crops retain the original paintings, including offscreen-canvas clipping.

var _stockroom_glow: Texture2D

func supports(id: String) -> bool:
	return id == "2-3"

func _scene_x(c: Dictionary) -> float:
	var scenes: Array = c.level.get("scenes", [])
	return float(scenes[0][0]) if not scenes.is_empty() else 8910.0

func build_sky(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	var cam: Vector2 = c.camera
	_rect(out, Rect2(cam.x - 10, cam.y - 10, c.width + 20, HEIGHT + 20), Color("1e2738"), "stockroom_sky_fill")
	var size := _size(c, "stockroom")
	if size == Vector2.ZERO: return out
	if int(_state(runtime, "scene_index", 0)) == 0:
		var top := float(c.ground) + 10 - 0.8 * size.y - cam.y * 0.5
		_tile_row(out, c, "stockroom", _crop(c, "stockroom", 0, 0, 1, 0.17), 0.3, top, "stockroom_roof")
		_tile_row(out, c, "stockroom", _crop(c, "stockroom", 0, 0.17, 1, 1), 0.55, top + 0.17 * size.y, "stockroom_wall")
		_rect(out, Rect2(cam.x - 10, cam.y - 10, c.width + 20, HEIGHT + 20), Color(20 / 255.0, 28 / 255.0, 44 / 255.0, 0.3), "stockroom_shade")
	elif c.images.has("mezz"):
		var height := _size(c, "mezz").y
		var top := source_round(float(c.ground) - 0.9 * height - cam.y)
		_tile_row(out, c, "mezz", _crop(c, "mezz", 0, 0, 1, 0.3), 0.6, top, "mezz_roof")
		_tile_row(out, c, "mezz", _crop(c, "mezz", 0, 0.3, 1, 0.86), 0.85, top + source_round(0.3 * height), "mezz_racking")
		_tile_row(out, c, "mezz", _crop(c, "mezz", 0, 0.86, 1, 1), 1.0, top + source_round(0.86 * height), "mezz_floor")
	else:
		# Exact source fallback for missing mezz paint, not another stage's art.
		var height := size.y * 0.62
		var top := float(c.ground) - 40 - 0.8 * height - cam.y * 0.35
		_tile_row(out, c, "stockroom", _crop(c, "stockroom", 0, 0.17, 1, 1), 0.3, top + 0.17 * height, "mezz_fallback_wall", 0.83 * height)
		_rect(out, Rect2(cam.x - 10, cam.y - 10, c.width + 20, HEIGHT + 20), Color(14 / 255.0, 20 / 255.0, 34 / 255.0, 0.5), "mezz_fallback_shade")
		_trusses(out, c, 118 - cam.y * 0.6)
		var rail_y := float(c.ground) - 110
		_rect(out, Rect2(cam.x - 10, cam.y + rail_y, c.width + 20, 6), GOLD, "mezz_fallback_rail")
		_rect(out, Rect2(cam.x - 10, cam.y + rail_y + 50, c.width + 20, 5), GOLD, "mezz_fallback_rail")
		var x := -fmod(cam.x * 0.92, 160)
		while x < float(c.width) + 10:
			_rect(out, Rect2(cam.x + source_round(x), cam.y + rail_y, 6, 110), GOLD, "mezz_fallback_rail_post")
			x += 160
		_rect(out, Rect2(cam.x - 10, cam.y + float(c.ground) - 16, c.width + 20, 16), Color("3a4258"), "mezz_fallback_kickplate")
	return out

func _trusses(out: Array, c: Dictionary, ty: float) -> void:
	var cam: Vector2 = c.camera
	_rect(out, Rect2(cam.x - 10, cam.y + source_round(ty), c.width + 20, 14), Color("2b3850"), "mezz_fallback_truss")
	var x := -fmod(cam.x * 0.7, 300) - 300
	while x < float(c.width) + 300:
		out.append({"type": "line", "points": PackedVector2Array([cam + Vector2(source_round(x), ty + 14), cam + Vector2(source_round(x + 150), ty + 80), cam + Vector2(source_round(x + 300), ty + 14)]), "colour": Color("2b3850"), "width": 6.0, "tag": "mezz_fallback_truss_brace"})
		var origin := cam + Vector2(source_round(x + 105), source_round(ty + 10))
		_rect(out, Rect2(origin + Vector2(44, 0), Vector2(2, 100)), Color("3a4258"), "mezz_fallback_lamp_wire")
		_poly(out, [origin + Vector2(20, 128), origin + Vector2(70, 128), origin + Vector2(56, 100), origin + Vector2(34, 100)], Color("5b6578"), "mezz_fallback_lamp")
		_rect(out, Rect2(origin + Vector2(26, 126), Vector2(38, 6)), Color("fff3b0"), "mezz_fallback_lamp_light")
		out.append({"type": "stockroom_glow", "rect": Rect2(cam + Vector2(x, ty + 140), Vector2(300, 400)), "tag": "mezz_fallback_lamp_glow"})
		x += 300

func _clipped_texture(out: Array, c: Dictionary, source: Rect2, destination: Rect2, bounds: Rect2, flip: bool, tag: String, extra: Dictionary = {}) -> void:
	var visible := destination.intersection(bounds)
	if not visible.has_area(): return
	var scale := source.size / destination.size
	var offset := visible.position - destination.position
	var clipped := Rect2(source.position + offset * scale, visible.size * scale)
	if flip: clipped.position.x = source.end.x - (offset.x + visible.size.x) * scale.x
	var details := {"art_bounds": bounds, "tile_source": source, "tile_rect": destination}
	details.merge(extra)
	_texture(out, c, "stockroom", visible, tag, clipped, flip, details)

func _rack(out: Array, c: Dictionary, origin: Vector2, width: float, height: float) -> void:
	var row_a := _crop(c, "stockroom", 0.163, 0.326, 0.5, 0.485)
	var row_b := _crop(c, "stockroom", 0.163, 0.485, 0.5, 0.627)
	var beam := _crop(c, "stockroom", 0.163, 0.296, 0.5, 0.326)
	if not row_a.has_area(): return
	var tile_width := source_round(row_a.size.x * 120 / row_a.size.y)
	var bounds := Rect2(origin, Vector2(width, height + 6))
	var y := height
	var row := 0
	while y > 0:
		var px := 0.0
		var index := row
		while px < width:
			var crop := row_b if (index + row) % 2 else row_a
			_clipped_texture(out, c, crop, Rect2(origin + Vector2(px, y - 120), Vector2(tile_width, 120)), bounds, index % 2 != 0, "rack_row", {"row": row, "index": index})
			px += tile_width
			index += 1
		y -= 120
		row += 1
	var px := 0.0
	while px < width:
		_clipped_texture(out, c, beam, Rect2(origin + Vector2(px, 0), Vector2(tile_width, 16)), bounds, false, "rack_top_beam")
		px += tile_width
	for piece in [[Rect2(width - 10, 0, 10, height), "2f6fb8"], [Rect2(0, 0, 10, height), "2f6fb8"], [Rect2(2, 0, 3, height), "5b94d8"], [Rect2(0, height, width, 6), "14243b"]]:
		_rect(out, Rect2(origin + piece[0].position, piece[0].size), Color(piece[1]), "rack_frame")

func _stack(out: Array, c: Dictionary, origin: Vector2, width: float, height: float) -> void:
	var crop := _crop(c, "stockroom", 0.32, 0.635, 0.485, 0.76)
	if not crop.has_area():
		_pallet(out, origin, width - 8, height - 4, "stack_fallback")
		return
	var tile_width := source_round(crop.size.x * 110 / crop.size.y)
	var bounds := Rect2(origin, Vector2(width, height))
	var y := height
	var index := 0
	while y > 0:
		var px := 0.0
		while px < width:
			_clipped_texture(out, c, crop, Rect2(origin + Vector2(px, y - 110), Vector2(tile_width, 110)), bounds, index % 2 != 0, "stock_stack", {"index": index})
			px += tile_width
			index += 1
		y -= 110

func _pallet(out: Array, origin: Vector2, width: float, height: float, tag: String = "chained_pallet") -> void:
	# blockArt('pallet', width, height) has a width+8 by height+4 canvas.
	# Its topmost boxes and final column are cropped, never compressed.
	var local: Array = []
	_r0(local, Color("3a4a66"), 0, height - 16, width + 8, 16, tag + "_base")
	_r0(local, Color("55678a"), 4, height - 14, width, 4, tag + "_highlight")
	for i in 3: _r0(local, Color("2b3850"), 8 + i * (width / 2 - 6), height - 8, 14, 8, tag + "_foot")
	var y := height - 16
	while y > 0:
		var x := 4.0
		while x < width:
			_r0(local, Color("3f7fd8"), x, y - 34, 38, 34, tag + "_box")
			_r0(local, Color("5b97e8"), x + 2, y - 32, 34, 12, tag + "_box_highlight")
			_r0(local, Color("f5f1ea"), x + 15, y - 34, 6, 34, tag + "_tape")
			x += 40
		y -= 34
	_rect(local, Rect2(0, 0, width + 8, height - 16), Color(1, 1, 1, 0.18), tag + "_wrap")
	var bounds := Rect2(Vector2.ZERO, Vector2(ceilf(width + 8), ceilf(height + 4)))
	for command in local:
		var rectangle: Rect2 = command.rect.intersection(bounds)
		if rectangle.has_area(): _rect(out, Rect2(origin + rectangle.position, rectangle.size), command.colour, command.tag)

func _platform_rows(host, runtime) -> Array:
	var surfaces: Array = []
	if runtime is Object and runtime.has_method("surfaces"):
		surfaces = runtime.surfaces(host)
	elif runtime is Dictionary and runtime.has("surfaces"):
		surfaces = runtime.surfaces
	else:
		return host.level.get("plats", [])
	var result: Array = []
	for surface in surfaces:
		if surface.get("plat", false): result.append(surface.row)
	return result

func build_level(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	var cam: Vector2 = c.camera
	var ground := float(c.ground)
	var ys := float(c.y_snap)
	var view_bottom := cam.y + HEIGHT + 20
	var upper := int(_state(runtime, "scene_index", 0)) > 0
	for floor_row in c.level.get("grounds", []):
		var x0 := maxf(float(floor_row[0]), cam.x - 50)
		var x1 := minf(float(floor_row[1]), cam.x + float(c.width) + 50)
		if x1 <= x0: continue
		_rect(out, Rect2(_x(c, x0), ground + ys, x1 - x0, view_bottom - ground), Color("4a5266" if upper else "5b6578"), "stockroom_floor")
		_rect(out, Rect2(_x(c, x0), ground + ys, x1 - x0, 4), Color("6e778c" if upper else "6f7a8f"), "stockroom_floor_edge")
		if not upper:
			var x := floorf(x0 / 260) * 260
			while x < x1:
				_rect(out, Rect2(_x(c, x), ground + 22 + ys, 120, 5), GOLD, "concrete_floor_line")
				x += 260
		else:
			for row in 2:
				var x := floorf(x0 / 24) * 24 + row * 12
				while x < x1:
					_rect(out, Rect2(_x(c, x), ground + 8 + row * 12 + ys, 12, 4), Color("3a4258"), "mezz_floor_grate")
					x += 24
	var gap: Array = c.level.get("gap", [9000, 9440])
	var ga := float(gap[0])
	var gb := float(gap[1])
	if _in_view(c, ga - 40, gb + 40):
		_rect(out, Rect2(_x(c, ga), ground + ys, gb - ga, view_bottom - ground), Color("0e1420"), "hoist_opening")
		for edge in [ga, gb]:
			var y := ground
			while y < view_bottom:
				_rect(out, Rect2(_x(c, edge) - (10 if edge == ga else 0), y + ys, 10, 24), GOLD if int(floorf((y - ground) / 24)) % 2 else Color("14243b"), "hoist_edge_stripe")
				y += 24
	for stack in c.level.get("stacks", []):
		var a := float(stack[0])
		var b := float(stack[1])
		var h := float(stack[2])
		if not _in_view(c, a, b): continue
		_rect(out, Rect2(_x(c, a - 4), ground - 4 + ys, b - a + 12, 10), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.3), "stock_stack_shadow")
		_stack(out, c, Vector2(_x(c, a), source_round(ground - h) + ys), b - a, h)
	for tower in c.level.get("towers", []):
		var a := float(tower[0])
		var b := float(tower[1])
		var h := float(tower[2])
		if not _in_view(c, a - 160, b + 160): continue
		_rect(out, Rect2(_x(c, a - 6), ground - 4 + ys, b - a + 16, 10), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.3), "rack_shadow")
		_rack(out, c, Vector2(_x(c, a), source_round(ground - h) + ys), b - a, h)
	var hazards := _hazards(host, runtime)
	for platform in _platform_rows(host, runtime):
		var a := float(platform[0])
		var b := float(platform[1])
		var top := float(platform[2])
		if not _in_view(c, a, b) or hazards.any(func(h): return h[0] == "belt" and float(h[1]) == a): continue
		var x0 := _x(c, a)
		var width := b - a
		if top > ground - 70:
			for x in [x0 + 8, x0 + width - 11]:
				_rect(out, Rect2(x, float(c.view.position.y) - 10 + ys, 3, top - float(c.view.position.y) + 10), Color("9aa5b8"), "pallet_chain")
			_pallet(out, Vector2(x0, top + ys), width - 8, 40)
			continue
		var adjacent: Array = []
		for tower in c.level.get("towers", []):
			if absf(float(tower[0]) - b) < 12 or absf(float(tower[1]) - a) < 12:
				adjacent = tower
				break
		if adjacent.is_empty():
			if top > ground - 140: _stack(out, c, Vector2(x0, source_round(top) + ys), width, ground - top)
			continue
		var left := absf(float(adjacent[0]) - b) < 12
		var ux := _x(c, float(adjacent[0]) - 156 if left else float(adjacent[1]) + 146)
		var beam_x := ux if left else _x(c, float(adjacent[1]))
		_rect(out, Rect2(ux, ground - float(adjacent[2]) + ys, 10, float(adjacent[2])), Color("2f6fb8"), "ladder_upright")
		_rect(out, Rect2(ux + 2, ground - float(adjacent[2]) + ys, 3, float(adjacent[2])), Color("5b94d8"), "ladder_upright_highlight")
		var y := ground - float(adjacent[2]) + 10
		while y < ground:
			_rect(out, Rect2(ux + 4, y + ys, 3, 4), Color("14243b"), "ladder_upright_slot")
			y += 24
		for piece in [[0, 10, "e8692a"], [0, 3, "f59a52"], [8, 2, "a8461c"]]:
			_rect(out, Rect2(beam_x, top + float(piece[0]) + ys, 156, float(piece[1])), Color(piece[2]), "ladder_beam")
	for hazard in hazards:
		if hazard[0] != "belt" or not _in_view(c, float(hazard[1]), float(hazard[2])): continue
		for x in [float(hazard[1]) + 20, float(hazard[2]) - 30]:
			_rect(out, Rect2(_x(c, x), float(hazard[3]) + 20 + ys, 10, ground - float(hazard[3]) - 20), Color("2f5d9a"), "belt_support")
	var scene_x := _scene_x(c)
	if not upper and _in_view(c, scene_x - 200, scene_x + 160):
		var lift_size := _size(c, "glift")
		if lift_size != Vector2.ZERO:
			_texture(out, c, "glift", Rect2(_x(c, scene_x - 20 - lift_size.x / 2), ground - lift_size.y + 4 + ys, lift_size.x, lift_size.y), "goods_lift")
		else:
			_goods_lift(out, Vector2(_x(c, scene_x - 120), ground - 380 + ys))
	return out

func _goods_lift(out: Array, origin: Vector2) -> void:
	var local: Array = []
	for piece in [[Rect2(0, 0, 200, 380), "3a4258"], [Rect2(0, 0, 200, 14), "f4c542"]]:
		_rect(local, piece[0], Color(piece[1]), "goods_lift_fallback")
	for x in range(0, 200, 28): _rect(local, Rect2(x, 0, 14, 14), Color("14243b"), "goods_lift_fallback_stripe")
	_rect(local, Rect2(16, 30, 168, 350), Color("1b2333"), "goods_lift_fallback_opening")
	for x in range(22, 180, 14): _rect(local, Rect2(x, 34, 4, 346), Color("6e778c"), "goods_lift_fallback_bar")
	for y in range(60, 380, 60): _rect(local, Rect2(16, y, 168, 4), Color("6e778c"), "goods_lift_fallback_bar")
	for piece in [[Rect2(70, 40, 60, 6), "fff3b0"], [Rect2(186, 150, 12, 40), "2b3850"], [Rect2(189, 156, 6, 6), "9fe0b8"], [Rect2(189, 170, 6, 6), "ffd23f"]]:
		_rect(local, piece[0], Color(piece[1]), "goods_lift_fallback_detail")
	for command in local:
		var clipped: Rect2 = command.rect.intersection(Rect2(0, 0, 200, 380))
		_rect(out, Rect2(origin + clipped.position, clipped.size), command.colour, command.tag)

func build_front(host, _runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	var scroll := float(c.camera.x) * 1.3
	for index in range(int(floorf(scroll / 2300)) - 1, int(floorf((scroll + float(c.width)) / 2300)) + 2):
		var sx := source_round(index * 2300 + 900 - scroll)
		if sx < -50 or sx > float(c.width) + 20: continue
		var x := float(c.camera.x) + sx
		var top := HEIGHT - 46 + float(c.y_snap)
		var colour := Color(14 / 255.0, 20 / 255.0, 34 / 255.0, 0.9)
		_rect(out, Rect2(x, top + 8, 30, 46), colour, "foreground_bollard")
		_ellipse(out, Vector2(x + 15, top + 8), Vector2(15, 6), colour, "foreground_bollard_cap")
		_rect(out, Rect2(x + 4, top + 10, 3, 46), Color(47 / 255.0, 111 / 255.0, 184 / 255.0, 0.7), "foreground_bollard_highlight")
		_rect(out, Rect2(x, top + 18, 30, 8), GOLD, "foreground_bollard_band")
	return out

func _glow_texture() -> Texture2D:
	if _stockroom_glow != null: return _stockroom_glow
	# Source two-circle radial gradient, clipped to its 300x400 fill rectangle.
	# Both centres differ: (150,10,r4) -> (150,50,r220). A concentric
	# replacement would incorrectly brighten the lamp and narrow the cone.
	var image := Image.create(300, 400, false, Image.FORMAT_RGBA8)
	var a := 40.0 * 40 - 216.0 * 216
	for y in 400:
		for x in 300:
			var v := Vector2(x + 0.5 - 150, y + 0.5 - 10)
			var b := -2.0 * (v.y * 40 + 4 * 216)
			var cc := v.length_squared() - 16
			var t := (-b - sqrt(maxf(0, b * b - 4 * a * cc))) / (2 * a)
			image.set_pixel(x, y, Color(1, 243 / 255.0, 176 / 255.0, 0.18 * (1 - clampf(t, 0, 1))))
	_stockroom_glow = ImageTexture.create_from_image(image)
	return _stockroom_glow

func draw_commands(host, commands: Array) -> void:
	for command in commands:
		if command.type == "stockroom_glow":
			host.draw_texture_rect_region(_nearest(_glow_texture()), command.rect, Rect2(0, 0, 300, 400), Color.WHITE)
		else:
			super.draw_commands(host, [command])

func clear_cache() -> void:
	super.clear_cache()
	_stockroom_glow = null
