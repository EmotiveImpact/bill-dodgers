extends "res://src/aisle_renderer.gd"
## Source 2-5 bakehouse / shop floor painter. World pixels, seconds.
## Extends shared controls, belt/drop art, enemies and HUD without enabling2-5.
## All animation reads host.elapsed (source levelT), never advances a clock.

func supports(id: String) -> bool:
	return id == "2-5"

func _scene_x(c: Dictionary) -> float:
	var scenes: Array = c.level.get("scenes", [])
	return float(scenes[0][0]) if not scenes.is_empty() else 9400.0

func build_sky(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	var cam: Vector2 = c.camera
	_rect(out, Rect2(cam.x - 10, cam.y - 10, c.width + 20, HEIGHT + 20), Color("eaf2ee"), "bakery_sky_fill")
	var size := _size(c, "bakery")
	if size == Vector2.ZERO: return out
	var top := float(c.ground) - 0.82 * size.y - cam.y
	_rect(out, Rect2(cam.x - 10, cam.y - 10, c.width + 20, top + 12).abs(), Color("1f4d39"), "bakery_ceiling_fill")
	_tile_row(out, c, "bakery", _crop(c, "bakery", 0, 0, 1, 0.07), 0.4, top, "bakery_roof")
	_tile_row(out, c, "bakery", _crop(c, "bakery", 0, 0.07, 1, 0.13), 0.7, top + source_round(0.07 * size.y), "bakery_pipes")
	var crop := _crop(c, "bakery", 0.035, 0.13, 0.6, 1) if int(_state(runtime, "scene_index", 0)) == 0 else _crop(c, "bakery", 0.45, 0.13, 1, 1)
	_tile_row(out, c, "bakery", crop, 1, top + 0.13 * size.y, "bakery_wall")
	return out

func build_level(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	var back := int(_state(runtime, "scene_index", 0)) == 0
	var scene_x := _scene_x(c)
	var ground := float(c.ground)
	var ys := float(c.y_snap)
	if back:
		var oven := _crop(c, "bakery", 0.13, 0.30, 0.46, 0.715)
		if oven.has_area():
			var width := source_round(oven.size.x * 250 / oven.size.y)
			for pos in c.level.get("ovens", []):
				var x := float(pos)
				if not _in_view(c, x - 60, x + 300): continue
				var left := _x(c, x + 120 - width / 2)
				_texture(out, c, "bakery", Rect2(left, ground - 254 + ys, width, 250), "bakery_oven", oven)
				_rect(out, Rect2(left, ground - 6 + ys, width, 8), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.25), "bakery_oven_shadow")
	for hazard in _hazards(host, runtime):
		if hazard[0] == "slow" and _in_view(c, float(hazard[1]), float(hazard[2])): _flour(out, c, hazard)
	for counter in c.level.get("counters", []):
		var a := float(counter[0])
		var b := float(counter[1])
		if not _in_view(c, a, b) or (a < scene_x) != back: continue
		if back and c.images.has("table"):
			var size := _size(c, "table")
			var x := a
			var index := 0
			# Source intentionally allows the last painted table past counter b.
			while x < b - 20:
				_texture(out, c, "table", Rect2(_x(c, x), ground - size.y + 4 + ys, size.x, size.y), "bakery_table", Rect2(), index % 2 != 0, {"index": index})
				x += size.x - 6
				index += 1
		elif back:
			_table_fallback(out, Vector2(_x(c, a), source_round(ground - 112) + ys), b - a)
		else:
			_deli(out, c, a, b)
	if back:
		var rack := _crop(c, "bakery", 0.455, 0.33, 0.59, 0.715)
		if rack.has_area():
			var width := source_round(rack.size.x * 194 / rack.size.y)
			for span in c.level.get("racks", []):
				var a := float(span[0])
				var b := float(span[1])
				if not _in_view(c, a, b): continue
				var x := a
				var index := 0
				while x < b - 10:
					_texture(out, c, "bakery", Rect2(_x(c, x), ground - 190 + ys, width, 194), "bakery_rack", rack, index % 2 != 0, {"index": index})
					x += width
					index += 1
	for belt in c.level.get("belts", []):
		if not _in_view(c, float(belt[0]), float(belt[1])): continue
		for hazard in _hazards(host, runtime):
			if hazard[0] == "belt" and float(hazard[1]) == float(belt[0]):
				_conveyor(out, c, belt, float(hazard[4]), float(host.elapsed))
				break
	if back and _in_view(c, scene_x - 160, scene_x + 160):
		if c.images.has("swing"):
			var size := _size(c, "swing")
			_texture(out, c, "swing", Rect2(_x(c, scene_x - size.x / 2), source_round(ground - size.y + 4) + ys, size.x, size.y), "bakery_swing_doors")
		else:
			_swing_fallback(out, Vector2(_x(c, scene_x - 130), source_round(ground - 320) + ys))
	return out

func _deli(out: Array, c: Dictionary, a: float, b: float) -> void:
	var crop := _crop(c, "bakery", 0.59, 0.40, 1, 0.70)
	if not crop.has_area(): return
	var width := source_round(crop.size.x * 116 / crop.size.y)
	var y := float(c.ground) - 116 + float(c.y_snap)
	var x := a
	var index := 0
	while x < b:
		var visible := minf(width, b - x)
		var clipped := crop
		clipped.size.x *= visible / width
		if index % 2: clipped.position.x += crop.size.x - clipped.size.x
		_texture(out, c, "bakery", Rect2(_x(c, x), y, visible, 116), "bakery_deli", clipped, index % 2 != 0, {"index": index, "tile_width": width, "tile_source": crop})
		x += width
		index += 1
	_rect(out, Rect2(_x(c, a), y - 4, b - a, 6), Color("e9eef3"), "bakery_deli_top")

func _flour(out: Array, c: Dictionary, hazard: Array) -> void:
	var a := float(hazard[1])
	var b := float(hazard[2])
	var y := float(c.ground) + float(c.y_snap)
	_rect(out, Rect2(_x(c, a), y - 4, b - a, 10), Color(1, 1, 1, 0.8), "flour_coating")
	var x := a
	while x < b:
		_ellipse(out, Vector2(_x(c, x + 30), y), Vector2(34, 7), Color(1, 1, 1, 0.9), "flour_mound")
		x += 60
	if _in_view(c, a - 120, a + 40):
		var sx := _x(c, a - 60)
		var center := Vector2(sx + 40, y - 26)
		var points := PackedVector2Array()
		for i in 64: points.append(center + (Vector2(cos(i * TAU / 64) * 44, sin(i * TAU / 64) * 28)).rotated(-0.25))
		out.append({"type": "polygon", "points": points, "center": center, "radius": Vector2(44, 28), "rotation": -0.25, "colour": Color("e9eef3"), "tag": "flour_sack"})
		_rect(out, Rect2(sx + 18, y - 40, 40, 10), Color("9fe0b8"), "flour_sack_label")
		_ellipse(out, Vector2(sx + 86, y - 6), Vector2(30, 9), Color.WHITE, "flour_sack_spill")
	# Source emits random dust into parts from drawLevel. Deliberately omit this
	# render-count-dependent effect; never write simulation state or consume RNG.

func _conveyor(out: Array, c: Dictionary, belt: Array, speed: float, elapsed: float) -> void:
	var a := float(belt[0])
	var b := float(belt[1])
	var source_y := float(belt[2])
	var y := source_y + float(c.y_snap)
	var ground := float(c.ground) + float(c.y_snap)
	var width := b - a
	var x0 := _x(c, a)
	for leg in [a + 24, (a + b) / 2, b - 36]:
		var x := _x(c, leg)
		_rect(out, Rect2(x, y + 22, 12, float(c.ground) - source_y - 22), Color("8f99ad"), "conveyor_leg")
		_rect(out, Rect2(x - 10, ground - 6, 32, 6), Color("6e778c"), "conveyor_foot")
	_rect(out, Rect2(x0 + 30, y + 22 + (float(c.ground) - source_y - 22) * 0.55, width - 60, 6), Color("8f99ad"), "conveyor_brace")
	_rect(out, Rect2(x0, y, width, 22), Color("3a4258"), "conveyor_bed")
	_rect(out, Rect2(x0, y - 4, width, 6), Color("c7d0dc"), "conveyor_rail")
	_rect(out, Rect2(x0, y + 18, width, 6), Color("c7d0dc"), "conveyor_rail")
	_rect(out, Rect2(x0, y - 4, width, 2), Color("eef3f7"), "conveyor_highlight")
	var roller := fposmod(elapsed * 1000 * speed, 24)
	while roller < width:
		_rect(out, Rect2(_x(c, x0 + roller), y + 4, 4, 12), Color("6e778c"), "conveyor_roller")
		roller += 24
	var bread := a + fposmod(elapsed * 1000 * speed, 120)
	while bread < b - 30:
		_ellipse(out, Vector2(_x(c, bread + 20), y - 9), Vector2(22, 10), Color("e0a040"), "conveyor_bread")
		_rect(out, Rect2(_x(c, bread + 8), y - 16, 20, 3), Color("f6c66a"), "conveyor_bread_highlight")
		for offset in [12, 22]: _rect(out, Rect2(_x(c, bread + offset), y - 12, 3, 5), Color("b8742c"), "conveyor_bread_cut")
		bread += 120

func _table_fallback(out: Array, origin: Vector2, width: float) -> void:
	for row in [[Rect2(0, 0, width, 12), "c7d0dc"], [Rect2(0, 0, width, 3), "eef3f7"], [Rect2(0, 10, width, 4), "8f99ad"]]:
		_rect(out, Rect2(origin + row[0].position, row[0].size), Color(row[1]), "bakery_table_fallback")
	for x in [10, width - 22, source_round(width / 2) - 6]: _rect(out, Rect2(origin + Vector2(x, 12), Vector2(12, 104)), Color("9aa5b8"), "bakery_table_leg")
	_rect(out, Rect2(origin + Vector2(6, 74), Vector2(width - 12, 6)), Color("b8c3d1"), "bakery_table_shelf")
	var x := 16.0
	while x < width - 70:
		_rect(out, Rect2(origin + Vector2(x, 66), Vector2(64, 8)), Color("8f99ad"), "bakery_table_tray")
		for k in 4: _ellipse(out, origin + Vector2(x + 9 + k * 15, 64), Vector2(7, 5), Color("f6efe2"), "bakery_table_dough")
		x += 74

func _swing_fallback(out: Array, origin: Vector2) -> void:
	for row in [[Rect2(0, 0, 260, 320), "9aa5b8"], [Rect2(0, 0, 260, 10), "c7d0dc"], [Rect2(14, 20, 232, 300), "2b3850"]]:
		_rect(out, Rect2(origin + row[0].position, row[0].size), Color(row[1]), "bakery_swing_fallback")
	for x in [18, 132]:
		_rect(out, Rect2(origin + Vector2(x, 24), Vector2(110, 294)), Color("c7d0dc"), "bakery_swing_leaf")
		_rect(out, Rect2(origin + Vector2(x + 4, 28), Vector2(6, 286)), Color("e9eef3"), "bakery_swing_highlight")
		_ellipse(out, origin + Vector2(x + 55, 110), Vector2(30, 30), Color("2b3850"), "bakery_swing_window_rim")
		_ellipse(out, origin + Vector2(x + 55, 110), Vector2(24, 24), Color("ffe9a8"), "bakery_swing_window")
		_rect(out, Rect2(origin + Vector2(x, 250), Vector2(110, 40)), Color("8f99ad"), "bakery_swing_kickplate")

func build_mid(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var c := _context(host)
	var elapsed := float(host.elapsed)
	# Read-only snapshots reuse aisle controls/entities without painting its
	# hazard group twice. Bakery hazard commands retain the source HZ order.
	var controls := _controls(host, runtime)
	var out: Array = super.build_mid(host, {"hazards": [], "hazard_controller": controls, "entities": [], "elapsed": elapsed})
	for hazard in _hazards(host, runtime):
		match hazard[0]:
			"flame":
				if _in_view(c, float(hazard[1]) - 40, float(hazard[1]) + 40): _flame(out, c, hazard, elapsed)
			"belt":
				if _in_view(c, float(hazard[1]), float(hazard[2])): _belt(out, c, hazard, elapsed)
			"ice":
				if _in_view(c, float(hazard[1]), float(hazard[2])): _ice(out, c, hazard)
			"block":
				if _in_view(c, float(hazard[1]) - 80, float(hazard[1]) + 80): _wet_sign(out, c, hazard)
	out.append_array(super.build_mid(host, {"hazards": [], "hazard_controller": {"gates": [], "plates": [], "buttons": []}, "entities": _state(runtime, "entities", []), "elapsed": elapsed}))
	return out

static func flame_phase(hazard: Array, elapsed: float) -> float:
	return fposmod(elapsed * 1000 + (float(hazard[4]) if hazard.size() > 4 else 0.0), float(hazard[3]))

func _flame(out: Array, c: Dictionary, hazard: Array, elapsed: float) -> void:
	var phase := flame_phase(hazard, elapsed)
	var x := _x(c, float(hazard[1]))
	var y := float(hazard[2]) + float(c.y_snap)
	# L.noGrate is true: this shadow replaces the shared metal floor grate.
	_rect(out, Rect2(x - 34, y - 3, 68, 5), Color(40 / 255.0, 30 / 255.0, 30 / 255.0, 0.18), "oven_flame_shadow")
	if phase > float(hazard[3]) - 700:
		_rect(out, Rect2(x - 24, y - 12, 48, 3), Color("ff9d3a" if int(floorf(elapsed * 1000 / 90)) % 2 else "e23b3b"), "oven_flame_warning")
	if phase < 1000:
		var k := phase / 150 if phase < 150 else ((1000 - phase) / 150 if phase > 850 else 1.0)
		var height := 175 * k
		for i in 9:
			var yy := y - 10 - i / 9.0 * height
			var width := (1 - i / 10.0) * 30 + sin(elapsed * 1000 / 40 + i) * 5
			_rect(out, Rect2(x - width / 2, yy - height / 9, width, height / 9 + 1), Color(["fff3b0", "ffd25a", "ff9d3a", "e8562e"][mini(3, int(floorf(i / 2.4)))]), "oven_flame")
			out[-1].merge({"phase_ms": phase, "visual_height": height, "segment": i})

func _wet_sign(out: Array, c: Dictionary, hazard: Array) -> void:
	if hazard.size() > 5 and hazard[5] != "wet": return
	var y := float(hazard[2]) + float(c.y_snap)
	if c.images.has("wet"):
		var size := _size(c, "wet")
		_texture(out, c, "wet", Rect2(_x(c, float(hazard[1]) - size.x / 2), y - size.y, size.x, size.y), "wet_floor_sign")
		return
	var width := float(hazard[3])
	var height := float(hazard[4])
	var origin := Vector2(_x(c, float(hazard[1]) - (width + 8) / 2), y - height - 4)
	_poly(out, [origin + Vector2(width / 2 + 4, 0), origin + Vector2(width, height), origin + Vector2(8, height)], GOLD, "wet_floor_fallback")
	_poly(out, [origin + Vector2(width / 2 + 4, 0), origin + Vector2(width, height), origin + Vector2(width / 2 + 14, height)], Color("d8a520"), "wet_floor_fallback_shade")
	_ellipse(out, origin + Vector2(width / 2 + 4, height * 0.45), Vector2(7, 7), Color("14243b"), "wet_floor_fallback_icon")
	_rect(out, Rect2(origin + Vector2(width / 2 - 6, height * 0.55), Vector2(22, 5)), Color("14243b"), "wet_floor_fallback_icon_body")
	_rect(out, Rect2(origin + Vector2(4, height), Vector2(width, 4)), Color("14243b"), "wet_floor_fallback_base")

func build_front(host, _runtime = null) -> Array:
	if not supports(host.level_id): return []
	# Bakery keeps the pale green banded bollard in both scenes, alpha .94.
	var out: Array = super.build_front(host, {"scene_index": 0})
	for command in out:
		if command.tag in ["foreground_bollard", "foreground_bollard_cap"]: command.colour.a = 0.94
	return out
