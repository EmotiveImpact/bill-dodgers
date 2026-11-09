extends "res://src/festival_renderer.gd"
## World 6 original painted tower and authored procedural machinery.
## Inherits drawing primitives, common crate/coin/item and exact sprite cropping,
## never festival scenery. Rendering is pure: no mutations of runtime state.
const LEVELS := ["6-1", "6-2", "6-3", "6-4", "6-5", "6-6", "6-S"]
func supports(id: String) -> bool: return id in LEVELS
func _billing_context(host) -> Dictionary:
	var c := _context(host)
	c.meta = host.meta
	c.pal = host.level.get("pal", {})
	return c
func _colour(c: Dictionary, key: String, fallback: String) -> Color: return Color(c.pal.get(key, fallback))
func _r(out: Array, x: float, y: float, w: float, h: float, colour: String, tag: String) -> void: _rect(out, Rect2(x, y, w, h), Color(colour), tag)
func _label(out: Array, p: Vector2, text: String, size: int, colour: Color, tag: String) -> void: out.append({"type": "text", "position": p, "text": text, "size": size, "colour": colour, "tag": tag})
func _tile(out: Array, c: Dictionary, key: String, factor: float, y: float, source: Rect2, clip: Rect2, tag: String, mirror: bool = true, height: float = 0) -> void:
	if source.size.x <= 0 or source.size.y <= 0: return
	var width := source.size.x
	var first := floori(float(c.camera.x) * factor / width)
	var i := first
	while i * width - float(c.camera.x) * factor < float(c.width) + 2:
		var x := _x(c, float(c.camera.x) + i * width - float(c.camera.x) * factor)
		var command := {"type": "texture", "key": key, "rect": Rect2(x, y, width, height if height > 0 else source.size.y), "source": source, "flip_h": mirror and posmod(i, 2) != 0, "alpha": 1.0, "tag": tag, "factor": factor, "index": i}
		var clipped := _clip_texture(command, clip)
		if not clipped.is_empty(): out.append(clipped)
		i += 1
func build_sky(host, _runtime = null) -> Array:
	var out: Array = []
	var c := _billing_context(host)
	var sky0 := _colour(c, "sky0", "121a34")
	var sky1 := _colour(c, "sky1", "3a3570")
	out.append({"type": "gradient", "rect": Rect2(c.camera.x - 10, c.camera.y - 10, c.width + 20, 560), "colours": PackedColorArray([sky0, sky0, sky1, sky1]), "tag": "billing_sky"})
	if c.level.art == "shaft": return out
	# Source seeded, chunky 32-bit city, four independently scrolling layers.
	var random := RandomNumberGenerator.new()
	random.seed = 11
	for i in range(90):
		var x := fposmod(random.randf() * 1400 - float(c.camera.x) * 0.02, 1400)
		_r(out, float(c.camera.x) + x, float(c.camera.y) + random.randf() * 208, 2, 2, "ffe9a8" if i % 3 == 0 else "cfd8ff", "billing_star")
	var outdoors: bool = c.level.art == "facade"
	for li in range(3):
		var factor: float = [0.1, 0.2, 0.34][li] if outdoors else [0.06, 0.1, 0.15][li]
		var base: float = [0.55, 0.7, 0.85][li]
		var lit: float = [0.5, 0.75, 1.0][li]
		var x := -20.0
		while x < 1400:
			var w := (14 + floorf(random.randf() * 26)) * 2
			var h := (30 + floorf(random.randf() * 110 * lit)) * 2
			var y: float = 540 - 520 + 10 + 520 * base - h * 0.6 - float(c.camera.y) * (0.2 + li * 0.08 if outdoors else 0.06) + (200 if outdoors else 0) + float(c.camera.y)
			var screen_x := fposmod(x - float(c.camera.x) * factor + 1400, 1400) - w
			var px := float(c.camera.x) + screen_x
			_rect(out, Rect2(px, y, w, 1040), _colour(c, "city%d" % li, ["232a4c", "1b2140", "141a33"][li]), "billing_city")
			for wy in range(int(y + 8), int(c.camera.y + 540), 10):
				for wx in range(int(px + 4), int(px + w - 4), 8):
					if random.randf() < 0.32 * lit: _r(out, wx, wy, 4, 4, "ffd776" if random.randf() < 0.8 else "9fd0ff", "billing_city_window")
			x += w + floorf(random.randf() * 8)
	return out
func build_level(host, runtime = null) -> Array:
	var out: Array = []
	var c := _billing_context(host)
	if c.level.art == "shaft":
		var dims := _size(c, "shaft")
		if dims != Vector2.ZERO:
			var off := float(c.camera.y) * 0.22
			var y := floorf((host.view_top() - off - 20) / dims.y) * dims.y
			while y < float(c.camera.y) + 560 - off:
				_texture(out, c, "shaft", Rect2(float(c.camera.x) + source_round((float(c.width) - dims.x) / 2), source_round(y + off) + c.y_snap, dims.x, dims.y), "billing_shaft")
				y += dims.y
	else:
		var zones: Array = c.level.get("zones", [{"x0": -100000, "x1": 1000000, "art": c.level.art}])
		for zone in zones:
			if float(zone.x1) < float(c.camera.x) - 10 or float(zone.x0) > float(c.camera.x) + float(c.width) + 10: continue
			var clip := Rect2(maxf(float(zone.x0), float(c.camera.x) - 10), host.view_top() - 10, minf(float(zone.x1), float(c.camera.x) + float(c.width) + 10) - maxf(float(zone.x0), float(c.camera.x) - 10), 560)
			_wall(out, c, zone, clip, host.view_top())
	for d in c.level.get("decor", []):
		if d[5] == "back": _decor(out, c, d)
	if c.level.kind == "hold": _lift_door(out, c, runtime)
	var surfaces: Array = runtime.surfaces(host).duplicate() if runtime != null and runtime is Object else []
	surfaces.sort_custom(func(a, b): return (a.art == "floor" and b.art != "floor") or (a.art == b.art and a.row[2] > b.row[2]) or (a.art != "floor" and b.art != "floor" and a.row[2] > b.row[2]))
	for s in surfaces: _surface_six(out, c, s, runtime, host)
	for d in c.level.get("decor", []):
		if d[5] != "back": _decor(out, c, d)
	for h in _state(runtime, "hazards", []):
		var key := "p_gargoyle" if h.kind == "beam" else "p_acunit"
		var size := _size(c, key)
		var t := float(_state(runtime, "ride", {}).get("row", [0, 0, c.ground])[2])
		_texture(out, c, key, Rect2(_x(c, float(h.x) - size.x / 2), t - size.y - (136 if h.kind == "beam" else 0) + c.y_snap, size.x, size.y), "billing_" + h.kind)
	return out
func _wall(out: Array, c: Dictionary, zone: Dictionary, clip: Rect2, view_top: float) -> void:
	var wall: Dictionary = c.meta.get("walls", {}).get(zone.art, {})
	if wall.is_empty():
		# The inter-room wall is authored black void, not a missing image fallback.
		_rect(out, clip, Color("0b0f1a"), "billing_void_wall")
		return
	var key: String = wall.key
	var size := _size(c, key)
	var base := minf(size.y - 4, float(wall.base))
	var top := float(c.ground) - float(wall.floor)
	if view_top - 10 < top:
		_tile(out, c, key, 1, view_top - 10 + c.y_snap, Rect2(0, 0, size.x, 6), clip, "billing_wall_extension", true, top - view_top + 12)
		_rect(out, clip.intersection(Rect2(clip.position.x, view_top - 10, clip.size.x, top - view_top + 12)), Color(0.03, 0.04, 0.08, 0.55), "billing_ceiling_shadow")
	if wall.has("far"):
		var far_size := _size(c, wall.far)
		_tile(out, c, wall.far, 0.15, top + float(wall.farTop) + c.y_snap, Rect2(Vector2.ZERO, far_size), clip, "billing_far", false)
	_tile(out, c, key, 1, top + c.y_snap, Rect2(0, 0, size.x, minf(size.y, base + 10)), clip, "billing_wall")
	if zone.art != "facade":
		_tile(out, c, key, 1, top + base + c.y_snap, Rect2(0, base, size.x, size.y - base), clip, "billing_painted_floor")
		var bottom := top + size.y
		if clip.end.y > bottom: _rect(out, Rect2(clip.position.x, bottom, clip.size.x, clip.end.y - bottom), Color("0b0f1a"), "billing_below_floor")
func _decor(out: Array, c: Dictionary, d: Array) -> void:
	var name: String = d[0]
	if name == "palm" and c.images.has("p_plant"): name = "plant"
	var x := _x(c, float(d[1]))
	var y := float(d[2]) + float(c.y_snap)
	var w := float(d[3])
	var h := float(d[4])
	if x + w < float(c.camera.x) - 40 or x - w > float(c.camera.x) + float(c.width) + 40: return
	var key := "p_" + name
	if c.images.has(key):
		var size := _size(c, key)
		if name == "lamp": _r(out, x - 2, y - 900, 4, 906 - size.y, "3a2f22", "billing_lamp_chain")
		_texture(out, c, key, Rect2(x - source_round(size.x / 2), y - size.y, size.x, size.y), "billing_decor_" + name)
		return
	var left := x - w / 2
	if name == "firedoor":
		for a in [[-10, -h - 10, w + 20, h + 10, "14161e"], [-6, -h - 6, w + 12, h + 6, "8a95ad"], [0, -h, w, h, "2d6a4f"], [10, -h * 0.45, w - 20, h * 0.38, "245a42"], [w * 0.25, -h + 26, w * 0.5, h * 0.3, "9fc7e0"], [6, -h * 0.52, w - 12, 8, "c9d4e6"], [6, -h * 0.52, w - 12, 2, "f4c542"], [w / 2 - 28, -h - 44, 56, 26, "1a3a2a"], [w / 2 - 25, -h - 41, 50, 20, "57c785"]]: _r(out, left + a[0], y + a[1], a[2], a[3], a[4], "billing_firedoor")
		_label(out, Vector2(x, y - h - 30), "EXIT", 12, Color.WHITE, "billing_exit_sign")
	elif name in ["lamp", "strip", "globe"]:
		_r(out, x - 1, y - 900, 2, 870, "c99a3a", "billing_light_cable")
		if name == "globe": _ellipse(out, Vector2(x, y - 16), Vector2(16, 16), Color("fff3c4"), "billing_globe")
		elif name == "strip":
			_r(out, x - 64, y - 8, 128, 8, "d9e4f2", "billing_strip")
			_r(out, x - 60, y - 2, 120, 3, "ffffff", "billing_strip")
		else:
			_r(out, x - 20, y - 26, 40, 14, "2f6b4a", "billing_lamp")
			_r(out, x - 16, y - 12, 32, 4, "fff3c4", "billing_lamp")
	elif name == "curtain":
		for xx in range(int(left), int(left + w), 12):
			_r(out, xx, y - h, 12, h, "6a1e2e", "billing_curtain")
			_r(out, xx + 2, y - h, 4, h, "8a2e40", "billing_curtain")
		_r(out, left, y - h, w, 10, "c99a3a", "billing_curtain")
		_r(out, left, y - h * 0.45, w, 6, "c99a3a", "billing_curtain")
	elif name == "case":
		_r(out, left, y - 20, w, 20, "2a1a24", "billing_case")
		_rect(out, Rect2(left + 4, y - h, w - 8, h - 20), Color(0.7, 0.86, 1, 0.25), "billing_case_glass")
		for yy in range(int(y - 28), int(y - h + 16), -8):
			for xx in range(int(left + 10), int(left + w - 16), 18): _r(out, xx, yy, 16, 6, "9fd18d" if yy % 24 else "ffd1e6", "billing_case_cash")
		_r(out, left + 4, y - h, w - 8, 4, "c99a3a", "billing_case")
	elif name == "espresso":
		_r(out, left + 4, y - h + 20, w - 8, h - 20, "c9d4dc", "billing_espresso")
		_r(out, left + 12, y - h + 32, w - 24, 20, "2a3448", "billing_espresso")
		for i in range(3):
			_r(out, left + 16 + i * (w - 32) / 3, y - h + 56, 10, 12, "1a1a22", "billing_espresso")
			_r(out, left + 14 + i * (w - 32) / 3, y - 16, 16, 12, "f5f1ea", "billing_espresso")
	elif name == "lampstd":
		_r(out, x - 2, y - h + 16, 4, h - 24, "c99a3a", "billing_lampstd")
		_r(out, x - 12, y - 8, 24, 8, "c99a3a", "billing_lampstd")
		_r(out, x - 16, y - h, 32, 20, "2f6b4a", "billing_lampstd")
	elif name == "phone":
		_r(out, left + 4, y - 16, w - 8, 16, "222838", "billing_phone")
		_r(out, left, y - 28, w, 12, "2e3650", "billing_phone")
	elif name == "clock":
		_ellipse(out, Vector2(x, y - h / 2), Vector2(w / 2, h / 2), Color("c99a3a"), "billing_clock")
		_ellipse(out, Vector2(x, y - h / 2), Vector2(w / 2 - 6, h / 2 - 6), Color("f5f1ea"), "billing_clock")
		_line(out, Vector2(x, y - h / 2), Vector2(x, y - h / 2 - 18), Color("14243b"), 4, "billing_clock")
		_line(out, Vector2(x, y - h / 2), Vector2(x + 14, y - h / 2), Color("c0485a"), 4, "billing_clock")
	else:
		# All remaining original props are explicit designs, never generic boxes.
		_prop(out, c, name, Rect2(left, y - h, w, h))
func _prop(out: Array, _c: Dictionary, name: String, r: Rect2) -> void:
	if name in ["plant", "palm"]:
		_r(out, r.get_center().x - 16, r.end.y - 28, 32, 28, "f2efe8", "billing_plant_pot")
		for i in range(9):
			var a := -1.4 + i * 0.35
			for t in range(0, int(r.size.y * 0.55 + (i % 3) * 8), 4): _r(out, r.get_center().x + sin(a) * t * 0.6 - 4, r.end.y - 28 - cos(a * 0.5) * t, 8, 6, "2f7d4a" if i % 2 else "3f9a5c", "billing_plant_leaf")
	elif name == "chair":
		for a in [[12, 4, r.size.x - 32, r.size.y * 0.45, "232a3a"], [8, r.size.y * 0.5, r.size.x - 12, 12, "232a3a"], [r.size.x / 2 - 4, r.size.y * 0.5 + 12, 8, r.size.y * 0.3, "56607a"], [4, r.size.y - 8, r.size.x - 8, 4, "56607a"]]: _r(out, r.position.x + a[0], r.position.y + a[1], a[2], a[3], a[4], "billing_chair")
	elif name == "cooler":
		_r(out, r.position.x + 8, r.position.y + r.size.y * 0.45, r.size.x - 16, r.size.y * 0.55, "e8ecf2", "billing_cooler")
		_r(out, r.position.x + 12, r.position.y + 4, r.size.x - 24, r.size.y * 0.42, "5fb3ff", "billing_cooler")
		_r(out, r.get_center().x - 6, r.position.y + r.size.y * 0.55, 12, 6, "3d4a63", "billing_cooler")
func _surface_six(out: Array, c: Dictionary, s: Dictionary, runtime, host) -> void:
	var x := _x(c, float(s.row[0]))
	var end := _x(c, float(s.row[1]))
	var w := end - x
	var t := float(s.row[2]) + float(c.y_snap)
	var ground := float(c.ground) + float(c.y_snap)
	var time := float(_state(runtime, "world_time", 0))
	var art: String = s.art
	if end < float(c.camera.x) - 40 or x > float(c.camera.x) + float(c.width) + 40 or t > float(c.camera.y) + 560: return
	if art == "floor": return
	if art == "void":
		_r(out, x, t, w, float(c.camera.y) + 560 - t, "0b0f1a", "billing_void_solid")
		return
	if art == "belt" and c.images.has("p_belt"):
		var size := _size(c, "p_belt")
		var cap := source_round(size.x * 0.22)
		var mid := size.x - cap * 2
		var y := t - 4
		_texture(out, c, "p_belt", Rect2(x, y, cap, ground - y), "billing_belt_cap", Rect2(0, 0, cap, size.y))
		var xx := x + cap
		while xx < end - cap:
			var ww := minf(mid, end - cap - xx)
			_texture(out, c, "p_belt", Rect2(xx, y, ww, ground - y), "billing_belt_mid", Rect2(cap, 0, ww, size.y))
			xx += ww
		_texture(out, c, "p_belt", Rect2(end - cap, y, cap, ground - y), "billing_belt_cap", Rect2(size.x - cap, 0, cap, size.y))
		var off := fposmod(time * 1000 * float(s.vx), 24)
		for xx2 in range(int(x + cap - 24 + off), int(end - cap), 24):
			if xx2 > x + cap: _rect(out, Rect2(xx2, y + 2, 6, 6), Color(1, 0.9, 0.63, 0.18), "billing_belt_motion")
		for ax in range(int(x + 60), int(end - 50), 170):
			var d := signf(float(s.vx))
			_poly(out, [Vector2(ax + 8 * d, y - 12), Vector2(ax - 6 * d, y - 18), Vector2(ax - 6 * d, y - 6)], Color("f4c542"), "billing_belt_arrow")
		return
	if art == "desk" and c.meta.has("desk"):
		var key := "p_desk" if c.images.has("p_desk") else "p_desk2"
		var d: Dictionary = c.meta.desk
		var sup: Dictionary = runtime.below(host, (float(s.row[0]) + float(s.row[1])) / 2, float(s.row[2]) + 6)
		var fy: float = sup.row[2] if not sup.is_empty() else c.ground
		var off: float = d.h - d.surf
		var ys: Array = []
		var yy := float(s.row[2])
		while yy <= fy - off + 2:
			ys.append(yy)
			yy += off
		ys.reverse()
		for y in ys: _texture(out, c, key, Rect2(x, y - d.surf + c.y_snap, d.w, d.h), "billing_desk")
		return
	if art in ["cabinet", "parcels", "pallet", "cage", "archive", "index", "btrolley", "fridge", "vending"] and c.images.has("p_" + art):
		var size := _size(c, "p_" + art)
		_texture(out, c, "p_" + art, Rect2(x, ground - size.y, size.x, size.y), "billing_solid_" + art)
		return
	var front := "p_front_kitchen" if art == "kcounter" else "p_front_" + String(c.level.art) if art in ["counter", "plinth"] else "p_docktex" if art == "dock" else ""
	if front and c.images.has(front):
		var size := _size(c, front)
		var height := ground - t
		var tw := size.x if art == "dock" else source_round(size.x * height / size.y)
		var xx := x - fmod(int(s.row[0]) * (0.37 if art == "dock" else 0.61), tw)
		while xx < end:
			var command := {"type": "texture", "key": front, "rect": Rect2(xx, t, tw, height), "source": Rect2(Vector2.ZERO, size), "flip_h": false, "alpha": 1.0, "tag": "billing_counter_painting"}
			var clipped := _clip_texture(command, Rect2(x, t, w, height))
			if not clipped.is_empty(): out.append(clipped)
			xx += tw
		_rect(out, Rect2(x, t, 4, height), Color(0.03, 0.04, 0.08, 0.5), "billing_counter_edge")
		_rect(out, Rect2(end - 4, t, 4, height), Color(0.03, 0.04, 0.08, 0.5), "billing_counter_edge")
		_rect(out, Rect2(x, t, w, 2), Color(1, 0.9, 0.67, 0.35), "billing_counter_top")
		return
	if art == "girder":
		var side := x if float(s.row[0]) < float(c.width) / 2 else end
		_poly(out, [Vector2(side, t + 12), Vector2(side, t + 70), Vector2(side + (40 if float(s.row[0]) < float(c.width) / 2 else -40), t + 12)], Color("22293a"), "billing_girder_brace")
		_r(out, x, t, w, 14, "5a6a8a", "billing_girder")
		_r(out, x, t, w, 3, "8a9ab8", "billing_girder")
		_r(out, x, t + 11, w, 3, "39445c", "billing_girder")
		for xx in range(int(x + 8), int(end - 4), 22): _r(out, xx, t + 6, 3, 3, "c9d4e6", "billing_girder_bolt")
		_r(out, x, t + 14, 8, 4, "f4c542", "billing_girder_edge")
		_r(out, end - 8, t + 14, 8, 4, "f4c542", "billing_girder_edge")
	elif art == "lift":
		_r(out, x, t, w, maxf(40, float(c.camera.y) + 600 - t), "20263a", "billing_lift_car")
		_r(out, x, t, w, 10, "c99a1d", "billing_lift_top")
		for xx in range(int(x), int(end), 40):
			_poly(out, [Vector2(xx, t + 10), Vector2(xx + 20, t + 10), Vector2(xx + 10, t + 22), Vector2(xx - 10, t + 22)], Color("14161e"), "billing_lift_hazard_stripe")
			_poly(out, [Vector2(xx + 20, t + 10), Vector2(xx + 40, t + 10), Vector2(xx + 30, t + 22), Vector2(xx + 10, t + 22)], Color("f4c542"), "billing_lift_hazard_stripe")
		_r(out, x, t + 22, w, 30, "3a4258", "billing_lift_car")
		for factor in [0.3, 0.5, 0.7]: _r(out, float(c.width) * factor - 4, t - 900, 8, 900, "c99a3a", "billing_lift_cable")
		for xx in [x + 40, end - 58]: _r(out, xx, t - 14, 18, 14, "ff4a4a" if int(time / 0.25) % 2 else "7a1a1a", "billing_lift_alarm")
	elif art == "cradle":
		for a in [[30, -1200, 3, 1130, "c9d4e6"], [w - 33, -1200, 3, 1130, "c9d4e6"], [22, -76, 20, 12, "e45b5b"], [w - 42, -76, 20, 12, "e45b5b"], [0, -64, 6, 64, "8a95ad"], [w - 6, -64, 6, 64, "8a95ad"], [0, -66, w, 5, "8a95ad"], [0, -34, w, 3, "8a95ad"], [0, 0, w, 16, "56607a"], [0, 0, w, 3, "c9d4e6"], [6, 16, w - 12, 8, "2b3348"], [60, -22, 22, 22, "3d82c4"], [62, -20, 18, 4, "5fb3ff"], [w - 90, -30, 4, 30, "f4c542"], [w - 100, -32, 24, 4, "f4c542"]]: _r(out, x + a[0], t + a[1], a[2], a[3], a[4], "billing_cradle")
	elif art in ["shelf", "desk", "gallery"]:
		var fl: Dictionary = runtime.below(host, float(s.row[0]) + 4, float(s.row[2]) + 6)
		var fy: float = fl.row[2] if not fl.is_empty() else ground
		var steel := art == "gallery"
		_r(out, x + 8, t + 10, 8, fy - t - 10, "2b3348" if steel else "1e3c25", "billing_" + art + "_leg")
		_r(out, end - 16, t + 10, 8, fy - t - 10, "2b3348" if steel else "1e3c25", "billing_" + art + "_leg")
		_r(out, x, t, w, 10, "8a95ad" if steel else "386542", "billing_" + art)
		_r(out, x, t, w, 2, "c9d4e6" if steel else "8bab91", "billing_" + art)
		if steel:
			_r(out, x, t - 66, w, 4, "8a95ad", "billing_gallery_rail")
			for xx in range(int(x), int(end), 70): _r(out, xx, t - 66, 4, 66, "56607a", "billing_gallery_rail")
		else:
			for yy in range(int(t + 40), int(fy - 10), 46):
				_r(out, x + 8, yy, w - 16, 8, "23462b", "billing_shelf")
				for xx in range(int(x + 14), int(end - 24), 30): _r(out, xx, yy - 14, 22, 14, ["ffffff", "ffd1e6", "cfe8ff"][posmod(int(xx / 30), 3)], "billing_shelf_mail")
func _lift_door(out: Array, c: Dictionary, runtime) -> void:
	var size := _size(c, "p_liftdoor")
	var x := float(c.level.hold.door)
	var t := float(c.ground)
	_texture(out, c, "p_liftdoor", Rect2(x - source_round(size.x / 2), t - size.y, size.x, size.y), "billing_lift_door")
	var h: Dictionary = _state(runtime, "hold", {})
	var fraction := minf(1, float(h.get("t", 0)) / maxf(1, float(h.get("secs", 90)))) if h.get("on", false) else 1.0 if h.get("done", false) else 0.0
	var angle := PI + fraction * PI
	var center := Vector2(x, t - size.y + source_round(size.y * 0.13))
	_line(out, center, center + Vector2(cos(angle), sin(angle)) * 30, Color("e43b3b"), 3, "billing_lift_dial")
	if h.get("done", false):
		var opened := minf(1, (float(_state(runtime, "world_time", 0)) - float(h.get("open_at", 0))) / 0.9)
		_r(out, x - size.x * 0.22 * opened, t - size.y * 0.66, size.x * 0.44 * opened, size.y * 0.66, "fff1c4", "billing_lift_open")
func build_mid(host, runtime = null) -> Array:
	var out: Array = []
	var c := _billing_context(host)
	for v in _state(runtime, "vents", []):
		var size := _size(c, "p_vent")
		if size != Vector2.ZERO: _texture(out, c, "p_vent", Rect2(_x(c, v.x - size.x / 2), v.y + c.y_snap, size.x, size.y), "billing_vent", Rect2(), false, {"alpha": maxf(0, 1 - float(v.t) / 0.7)})
		else:
			_r(out, _x(c, v.x) - 34, v.y, 68, 10, "c9d4e6", "billing_vent")
			for xx in range(-30, 30, 8): _r(out, _x(c, v.x) + xx, v.y + 2, 4, 6, "56607a", "billing_vent_slot")
	var m: Dictionary = _state(runtime, "mini_boss", {})
	if not m.is_empty():
		var key := "p_franker" if m.kind == "franker" else "p_copier"
		var size := _size(c, key)
		_ellipse(out, Vector2(_x(c, m.x), m.y - 2), Vector2(float(m.w) / 2 + 10, 10), Color(0.05, 0.09, 0.15, 0.3), "billing_mini_shadow")
		_texture(out, c, key, Rect2(_x(c, float(m.x) - size.x / 2) + (3 if m.flash > 0 else 0), m.y - size.y + c.y_snap, size.x, size.y), "billing_mini_" + m.kind)
		if m.state == "down": _rect(out, Rect2(m.x - float(m.w) / 2, m.y - m.h + 40, m.w, m.h - 40), Color(0.05, 0.09, 0.15, 0.55), "billing_mini_down")
		for s in m.shock: _shock(out, c, s, m.y, "billing_mini_shock")
	for f in _state(runtime, "fliers", []):
		var animation: String = "pop" if f.state == "pop" else "drop" if f.drop > 0 else "fly"
		var frame := mini(3, int(float(f.gone) / 0.12)) if f.state == "pop" else int(float(f.t) / 0.09) % 4
		out.append_array(_sprite_commands(host, c, "mailer", animation, frame, f.p + Vector2(0, 46), -int(f.face), maxf(0, 1 - float(f.gone) / 0.7) if f.state == "pop" else 1.0, "", f.flash > 0, "billing_mailer"))
	for f in _state(runtime, "fees", []):
		var x := _x(c, float(f.x))
		if f.t < f.warn + 0.4:
			var k := minf(1, float(f.t) / float(f.warn))
			_ellipse(out, Vector2(x, float(c.ground) - 3), Vector2(float(f.r) + 10 * k, 6), Color(0.89, 0.23, 0.23, 0.25 + 0.35 * k), "billing_fee_warning")
		if f.t < f.warn: continue
		if f.kind == "rock":
			_r(out, x - f.r, float(f.y) - f.r, f.r * 2, f.r * 2, "6a7090", "billing_rock")
			_r(out, x - f.r, float(f.y) - f.r, f.r * 2, 5, "9aa3b5", "billing_rock")
			_r(out, x - 4, float(f.y) - f.r + 8, 4, 10, "3a3f55", "billing_rock")
		else: _paper(out, Vector2(x, f.y), float(f.t) / 0.12, [[Rect2(-14, -10, 28, 20), "ffffff"], [Rect2(-14, -10, 28, 6), "e43b3b"], [Rect2(-6, 0, 12, 2), "e43b3b"], [Rect2(-6, 4, 8, 2), "e43b3b"]], "billing_fee")
	return out
func _shock(out: Array, c: Dictionary, s: Dictionary, y: float, tag: String) -> void:
	var x := _x(c, float(s.x))
	for i in range(4): _r(out, x - 6 - i * 8 * signf(float(s.vx)), y - 10 - (3 - i) * 7 - sin(float(s.t) / 0.05 + i) * 3, 12, 10 + (3 - i) * 4, "f5f1ea", tag)
func build_enemy(host, bot: Dictionary) -> Array:
	if bot.type != "debit": return super.build_enemy(host, bot)
	var out: Array = []
	var c := _billing_context(host)
	var transform := Transform2D(float(bot.gone) / 0.15 if bot.state == "pop" else 0, Vector2(_x(c, bot.p.x), bot.p.y + c.y_snap))
	var step := int(float(bot.t) / 0.07) % 2
	var flash: bool = bot.flash > 0
	var rows: Array = [[Rect2(-12, -14 + step * 2, 6, 14 - step * 2), "14161e"], [Rect2(6, -12 - step * 2, 6, 12 + step * 2), "14161e"], [Rect2(-18, -60, 36, 46), "ffffff" if flash else "2a4a9a"], [Rect2(-18, -60, 36, 6), "ffffff" if flash else "3d6ad0"], [Rect2(-14, -36, 28, 6), "f4c542"], [Rect2(-12, -50, 8, 8), "14161e"], [Rect2(4, -50, 8, 8), "14161e"], [Rect2(-10, -48, 4, 4), "ffd776"], [Rect2(6, -48, 4, 4), "ffd776"], [Rect2(-26, -40, 10, 4), "c9d4e6"], [Rect2(-30, -44, 4, 12), "c9d4e6"], [Rect2(-1, -68, 2, 8), "e45b5b"], [Rect2(-3, -72, 6, 4), "e45b5b"]]
	for row in rows:
		var r: Rect2 = row[0]
		var points := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		if bot.face > 0:
			for i in range(points.size()): points[i].x *= -1
		var colour := Color(row[1])
		if bot.state == "pop": colour.a = maxf(0, 1 - float(bot.gone) / 0.6)
		_poly(out, points, colour, "billing_debit", transform)
	return out
func build_boss(host, _runtime = null) -> Array:
	var out: Array = []
	if host.boss == null or host.boss.state.is_empty(): return out
	var b: Dictionary = host.boss.state
	var c := _billing_context(host)
	_ellipse(out, Vector2(_x(c, b.x), c.ground - 2), Vector2(80 + float(b.yo) * 0.1, 10), Color(0.05, 0.09, 0.15, 0.3), "sir_charge_shadow")
	var animation: String = "down" if b.state == "down" else "walk" if b.dizzy > 0 else "slam" if b.act in ["slam", "volley"] else "float" if b.act == "float" else "walk"
	var frame := mini(3, int(float(b.t) / 0.3)) if animation == "down" else mini(3, int(float(b.at) / 0.16)) if animation == "slam" else int(float(b.t) / (0.09 if b.act == "charge" else 0.16)) % 4
	out.append_array(_sprite_commands(host, c, "charge", animation, frame, Vector2(b.x, float(c.ground) + b.yo), -int(b.face), 1, "", b.flash > 0, "sir_charge"))
	if b.dizzy > 0 and b.state != "down":
		for i in range(3):
			var a: float = host.elapsed / 0.2 + i * 2.1
			_label(out, Vector2(b.x + cos(a) * 40, b.fy - 330 + sin(a) * 10), "£", 16, Color("f4c542"), "sir_charge_dizzy")
	for s in b.waves:
		_shock(out, c, s, c.ground, "sir_charge_shock")
		_r(out, float(s.x) - 14, float(c.ground) - 6, 28, 6, "e43b3b", "sir_charge_shock_base")
	return out
func draw_jar(host, runtime = null) -> void: draw_commands(host, build_jar(host, runtime))
func build_jar(host, _runtime = null) -> Array:
	var out: Array = []
	if host.boss == null: return out
	var jar: Dictionary = host.boss.state.get("jar", {})
	if jar.is_empty(): return out
	var x := _x(_context(host), float(jar.x))
	var y: float = float(jar.y) + (0 if jar.got else sin(float(jar.t) / 0.14) * 2)
	if not jar.got: _ellipse(out, Vector2(x, y - 4), Vector2.ONE * (44 + sin(float(jar.t) / 0.1) * 4), Color(1, 0.95, 0.66, 0.35), "sir_charge_jar_glow")
	_r(out, x - 20, y - 32, 40, 10, "c99a3a", "sir_charge_jar")
	_rect(out, Rect2(x - 24, y - 22, 48, 44), Color(0.86, 0.94, 1, 0.65), "sir_charge_jar")
	_r(out, x - 18, y, 36, 16, "f4c542", "sir_charge_jar_coins")
	_label(out, Vector2(x, y - 6), "£", 20, Color("2d6a4f"), "sir_charge_jar_label")
	return out
func _paper(out: Array, origin: Vector2, angle: float, rows: Array, tag: String) -> void:
	for row in rows:
		var r: Rect2 = row[0]
		_poly(out, [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)], Color(row[1]), tag, Transform2D(angle, origin))
func build_bill(host, bill: Dictionary) -> Array:
	if float(bill.get("delay", 0)) > 0: return []
	var c := _billing_context(host)
	var out: Array = []
	var origin := Vector2(_x(c, bill.p.x), source_round(bill.p.y) + c.y_snap)
	var age := float(bill.get("age", 0))
	if bill.get("leaf", false): _paper(out, origin, sin(age / 0.16) * 0.6, [[Rect2(-10, -7, 20, 14), "ffffff"], [Rect2(-10, -7, 20, 4), "ff8fc7"], [Rect2(-7, 0, 14, 2), "7fa8d8"], [Rect2(-7, 3, 9, 2), "7fa8d8"]], "billing_leaflet")
	elif bill.get("stamp", false):
		var rows: Array = [[Rect2(-13, -13, 26, 26), "c0303a"], [Rect2(-7, -7, 14, 14), "ffd2d2"], [Rect2(-3, -3, 6, 6), "c0303a"]]
		for i in range(-13, 13, 6): rows.append_array([[Rect2(i, -15, 3, 3), "ffffff"], [Rect2(i, 12, 3, 3), "ffffff"], [Rect2(-15, i, 3, 3), "ffffff"], [Rect2(12, i, 3, 3), "ffffff"]])
		_paper(out, origin, age / 0.09, rows, "billing_stamp")
	elif bill.get("sheet", false):
		_r(out, origin.x - 18, origin.y - 12, 36, 24, "ffffff", "billing_sheet")
		for y in range(-7, 9, 4): _r(out, origin.x - 14, origin.y + y, 28, 2, "c9d4e6", "billing_sheet")
		_r(out, origin.x - 18, origin.y - 12, 4, 24, "7cff9a", "billing_sheet")
	elif bill.get("big", false): _paper(out, origin, age / 0.09, [[Rect2(-15, -11, 30, 22), "ffffff"], [Rect2(-15, -11, 30, 6), "e43b3b"], [Rect2(-10, -1, 20, 2), "9aa3b5"], [Rect2(-10, 3, 14, 2), "9aa3b5"], [Rect2(4, 3, 7, 5), "e43b3b"]], "billing_big_bill")
	else: _paper(out, origin, age / 0.09, [[Rect2(-9, -7, 18, 14), "4f8f5a"], [Rect2(-7, -5, 6, 4), "a8d79a"], [Rect2(1, 0, 6, 5), "a8d79a"], [Rect2(-3, -2, 6, 4), "2f5d3a"]], "billing_bill")
	return out
func _player_floor(host, p: Vector2) -> Dictionary: return host.world_six.below(host, p.x, p.y - 2)
func build_front(host, runtime = null) -> Array:
	var out: Array = []
	for f in _state(runtime, "floating", []):
		_label(out, f.position - Vector2(0, float(f.age) * 40), f.text, 16, f.colour, "billing_float")
	if host.level.kind == "ride":
		for h in _state(runtime, "hazards", []):
			var sx: float = float(h.x) - host.camera.x
			if sx > host.view_width() and sx < host.view_width() + 700:
				var y := float(host.meta.ground) - (150 if h.kind == "beam" else 40)
				var bob := sin(float(host.elapsed) / 0.12) * 4
				_label(out, Vector2(host.camera.x + host.view_width() - 70 + bob, y - 40), "Duck!" if h.kind == "beam" else "Jump!", 15, Color("f4c542"), "billing_ride_warning")
				_poly(out, [Vector2(host.camera.x + host.view_width() - 30 + bob, y - 14), Vector2(host.camera.x + host.view_width() - 60 + bob, y - 30), Vector2(host.camera.x + host.view_width() - 60 + bob, y + 2)], Color("f4c542"), "billing_ride_warning")
	if host.level.kind == "climb" and host.mode == "play" and float(_state(runtime, "level_time", 0)) < float(host.level.climb.delay) / 1000 + 0.6: _label(out, Vector2(host.camera.x + host.view_width() / 2, host.view_top() + 150), "Climb! The lift is coming", 18, Color("f4c542"), "billing_climb_warning")
	return out
func _progress(out: Array, label: String, fraction: float, colour: Color, tag: String, bottom: bool = false) -> void:
	var w := 420.0 if bottom else 300.0
	var x := (960 - w) / 2
	var y := 500.0 if bottom else 82.0
	_border(out, Rect2(x - 4, y - 4, w + 8, 26 if bottom else 22), 8, Color(0.05, 0.09, 0.15, 0.85), Color("f5f1ea"), 2, tag)
	if fraction > 0: _rounded(out, Rect2(x, y, maxf(10, w * clampf(fraction, 0, 1)), 18 if bottom else 14), 5, colour, tag + "_fill")
	_label(out, Vector2(480, y - 16 if bottom else y + 30), label, 14 if bottom else 13, Color("f5f1ea"), tag + "_label")
func build_hud(host, runtime = null) -> Array:
	var out: Array = []
	var hold_state: Dictionary = _state(runtime, "hold", {})
	var dash_state: Dictionary = _state(runtime, "dash", {})
	var lift_state: Dictionary = _state(runtime, "lift", {})
	var m: Dictionary = _state(runtime, "mini_boss", {})
	if hold_state.get("on", false):
		var left := maxi(0, ceili(float(hold_state.secs) - float(hold_state.t)))
		_progress(out, "Lift arriving in %d:%02d" % [int(left / 60), left % 60], float(hold_state.t) / float(hold_state.secs), Color("9fe0b8"), "billing_hold_hud")
	if not dash_state.is_empty():
		var seconds := ceili(float(dash_state.left))
		_progress(out, "Coffee run: %ds" % seconds, float(dash_state.left) / float(host.level.dash.secs), Color("e23b3b" if seconds < 15 else "f4c542"), "billing_dash_hud")
	if not lift_state.is_empty() and host.mode == "play" and host.hearts > 0:
		var progress := clampf((float(host.level.climb.start) - host.player.y) / (float(host.level.climb.start) - float(host.level.climb.top)), 0, 1)
		_progress(out, "Floor %d of %d" % [1 + floori(progress * float(host.level.climb.floors)), host.level.climb.floors], progress, Color("8fb8e0"), "billing_climb_hud")
	if host.level.kind == "ride" and host.mode == "play": _progress(out, "To the top terrace", host.camera.x / (float(host.level.w) - host.view_width()), Color("8fb8e0"), "billing_ride_hud")
	if not m.is_empty() and m.state == "fight": _progress(out, m.name, float(m.hp) / float(m.max), Color("e23b3b"), "billing_mini_hud", true)
	if host.boss != null and host.boss.state.state != "down":
		var b: Dictionary = host.boss.state
		_progress(out, "Sir Charge", float(b.hp) / float(b.max), Color("f4c542" if b.dizzy > 0 else "e23b3b"), "sir_charge_hud", true)
	var count := 0
	for receipt in host.receipts:
		if receipt.get("taken", false): count += 1
	_label(out, Vector2(880, 82), "Receipts %d/3" % count, 12, Color("9fe0b8"), "billing_receipts_hud")
	return out
func draw_mid(host, runtime = null, _pickups: Callable = Callable()) -> void:
	draw_commands(host, build_finds(host, runtime))
	draw_commands(host, build_mid(host, runtime))
func build_finds(host, runtime = null) -> Array:
	var out: Array = []
	var c := _billing_context(host)
	var time := float(_state(runtime, "elapsed", host.elapsed))
	for i in host.receipts.size():
		var receipt: Dictionary = host.receipts[i]
		if receipt.get("taken", false): continue
		var p: Vector2 = receipt.position
		if p.x - float(c.camera.x) < -40 or p.x - float(c.camera.x) > float(c.width) + 40: continue
		var x := _x(c, p.x)
		var y := source_round(p.y + sin(time / 0.26 + i) * 3) + float(c.y_snap)
		var paper := Color(1, 1, 1, 0.55 if receipt.get("previously_collected", false) else 1)
		_rect(out, Rect2(x - 9, y - 13, 18, 22), paper, "billing_receipt")
		for tooth in range(3): _poly(out, [Vector2(x - 9 + tooth * 6, y + 9), Vector2(x - 6 + tooth * 6, y + 13), Vector2(x - 3 + tooth * 6, y + 9)], paper, "billing_receipt_tooth")
		for a in [[-6,-9,12,2],[-6,-5,8,2],[-6,-1,10,2]]: _r(out,x+a[0],y+a[1],a[2],a[3],"9aa3b5","billing_receipt_line")
		_r(out,x-6,y+4,12,2,"2d6a4f","billing_receipt_line")
		if int(time/0.3+i)%3==0:
			_r(out,x+8,y-16,3,9,"fff1a8","billing_receipt_spark")
			_r(out,x+5,y-13,9,3,"fff1a8","billing_receipt_spark")
	var movement = _state(host, "movement_skills", null)
	if c.level.has("card") and not bool(_state(movement, "card_collected", false)):
		var p := Vector2(c.level.card[0], c.level.card[1])
		p.y += sin(time / 0.2) * 5
		_ellipse(out,p,Vector2.ONE*34,Color(0.96,0.77,0.26,0.3),"billing_skill_glow")
		_paper(out,p,sin(time/0.5)*0.2,[[Rect2(-22,-28,44,56),"f4c542"],[Rect2(-18,-24,36,48),"14243b"]],"billing_skill_card")
		_label(out,p,"S",24,Color("f4c542"),"billing_skill_card_label")
	return out
