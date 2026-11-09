extends "res://src/festival_renderer.gd"
## Source W5 painter. Imported room art is kept at META.dims; physical surfaces,
## robot vehicle riders, lift, sofa, bridges and King use live runtime snapshots.
## Inherited code is shared command/sprite/crate/item/coin machinery only.
const PALETTES := {"stair": ["8c5a3c", "a86e4a", "3b2a26"], "flat": ["9a6238", "b87a48", "3a2a22"], "lockup": ["7d838e", "959ba6", "2a2e36"], "loft": ["b9875a", "d3a072", "3a2a22"], "bonus": ["9aa6b2", "b9c3cd", "3a4250"], "road": ["3a3d44", "4a4e57", "24262b"]}
func supports(id: String) -> bool: return id in ["5-1", "5-2", "5-3", "5-4", "5-5", "5-6", "5-S"]
func _festival_context(host) -> Dictionary:
	var c := super._festival_context(host); c.dims = host.meta.get("dims", {}); return c
func _world_size(c: Dictionary, key: String) -> Vector2:
	if c.dims.has(key): return Vector2(c.dims[key][0], c.dims[key][1])
	return _size(c, key)
func _wall_key(c: Dictionary, x: float) -> String:
	var key := "wall"
	for z in c.level.get("zones", []):
		if x >= float(z[0]): key = str(z[1])
	return key
func _floor_at(host, runtime, x: float) -> float:
	var widest := -1.0; var y: float = host.meta.ground
	for q in _surfaces(host, runtime):
		if not q.plat and q.get("look", "") == "floor" and x >= q.row[0] and x <= q.row[1] and q.row[1] - q.row[0] > widest: widest = q.row[1] - q.row[0]; y = q.row[2]
	return y
func _clipped_texture(out: Array, c: Dictionary, key: String, dest: Rect2, clip: Rect2, tag: String, flip: bool = false) -> void:
	var commands: Array = []
	_texture(commands, c, key, dest, tag, Rect2(), flip)
	for cmd in commands:
		var cropped := _clip_texture(cmd, clip)
		if not cropped.is_empty(): out.append(cropped)
func _layer(out: Array, c: Dictionary, key: String, scroll: float, top: float, height: float, mirror: bool = false) -> void:
	var sz := _world_size(c, key)
	if sz == Vector2.ZERO: return
	var w := sz.x * height / sz.y
	var first := int(floorf(scroll / w))
	for i in range(first, first + int(ceilf(c.width / w)) + 2): _texture(out, c, key, Rect2(c.camera.x + i * w - scroll, c.camera.y + top, w, height), "moving_day_parallax", Rect2(), mirror and i % 2 != 0)
func build_sky(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var c := _festival_context(host)
	var out: Array = []
	var time := float(_state(runtime, "elapsed", host.elapsed))
	if c.level.theme == "road":
		out.append({"type": "gradient", "rect": Rect2(c.camera.x - 10, c.camera.y - 10, c.width + 20, 560), "colours": PackedColorArray([Color("f09a6a"), Color("f09a6a"), Color("f7d9a0"), Color("f7d9a0")]), "tag": "moving_day_sunset"})
		var sky_size := _world_size(c, "sky")
		_texture(out, c, "sky", Rect2(c.camera.x + source_round((c.width - sky_size.x) / 2), 200 - sky_size.y, sky_size.x, sky_size.y), "moving_day_sky")
		for layer in [["far", 50, 540 - _world_size(c, "road").y + 334], ["skyline", 100, 238], ["fields", 250, 292], ["road", 620, 544]]:
			var sz := _world_size(c, layer[0])
			if sz != Vector2.ZERO: _layer(out, c, layer[0], time * float(layer[1]), float(layer[2]) - sz.y, sz.y)
		return out
	_rect(out, Rect2(c.camera.x - 10, c.camera.y - 10, c.width + 20, 560), Color("2a2230"), "moving_day_room_back")
	var theme: String = c.level.get("wallTheme", {}).get(_wall_key(c, c.camera.x + c.width / 2), c.level.theme)
	var windows: Array = {"flat": [150, 210], "stair": [205, 300], "loft": [190, 300]}.get(theme, [205, 300])
	_layer(out, c, "wsky", c.camera.x * 0.02, 540 - 540 / 1.3 - 20, 330, true)
	_layer(out, c, "wcity", c.camera.x * 0.15, windows[0] + clampf(-c.camera.y * 0.04, -60, 160), 215, true)
	_layer(out, c, "wroof", c.camera.x * 0.4, windows[1] + clampf(-c.camera.y * 0.12, -60, 400), _world_size(c, "wroof").y, true)
	var vt: float = host.view_top() - 10
	var vb: float = host.camera.y + 550
	for slice in range(int(floorf(c.camera.x / 300)), int(ceilf((c.camera.x + c.width + 300) / 300))):
		var x0 := slice * 300.0
		var key := _wall_key(c, x0)
		var sz := _world_size(c, key)
		if sz == Vector2.ZERO: continue
		var tx := floorf(x0 / sz.x) * sz.x
		var base: float = _floor_at(host, runtime, x0 + 150) + 4 if key in c.level.get("anchor", []) else c.ground + 6
		var bottom := base
		while bottom > vt:
			if bottom - sz.y <= vb:
				for xx in [tx, tx + sz.x]: _clipped_texture(out, c, key, Rect2(_x(c, xx), source_round(bottom - sz.y) + c.y_snap, sz.x, sz.y), Rect2(_x(c, x0), source_round(bottom - sz.y) + c.y_snap, 300, sz.y + 1), "moving_day_wall")
			bottom -= sz.y
	return out
func _moving_box(out: Array, c: Dictionary, key: String, feet: Vector2, size: Vector2 = Vector2.ZERO) -> void:
	var sz := _world_size(c, key) if size == Vector2.ZERO else size
	_texture(out, c, key, Rect2(_x(c, feet.x - sz.x / 2), source_round(feet.y - sz.y) + c.y_snap, sz.x, sz.y), "moving_day_box")
func _column(out: Array, c: Dictionary, x: float, top: float, base: float, seed_value: int) -> void:
	var y := base; var i := 0
	while y > top + 4 and i < 30:
		var key: String = ["box1", "box2", "box3"][posmod(seed_value + i, 3)]
		var sz := _world_size(c, key)
		if sz == Vector2.ZERO: break
		var h := minf(sz.y, y - top)
		_texture(out, c, key, Rect2(_x(c, x - sz.x / 2 + (posmod(seed_value + i, 3) - 1) * 3), y - h + c.y_snap, sz.x, h), "moving_day_stack", Rect2(0, sz.y - h, sz.x, h))
		y -= h; i += 1
func build_level(host, runtime = null) -> Array:
	var out: Array = []; var c := _festival_context(host)
	var time := float(_state(runtime, "elapsed", host.elapsed))
	var palette: Array = PALETTES.get(c.level.theme, PALETTES.stair)
	var bottom: float = host.camera.y + 560
	for q in _state(runtime, "movers", []):
		if q.off: continue
		var key: String = "rvan" if q.kind == "van" else "rlorry"
		var sz := _world_size(c, key)
		if sz == Vector2.ZERO: continue
		var bob := source_round(sin(time / 0.09 + float(q.wob)) * 1.2)
		var h: float = 221 if q.kind == "van" else sz.y
		var w: float = source_round(sz.x * h / sz.y)
		_texture(out, c, key, Rect2(_x(c, q.row[0]), float(q.row[2]) + (-4 if q.kind == "van" else -129) + bob + c.y_snap, w, h), "moving_day_robot_vehicle", Rect2(), q.from > 0)
	for q in _surfaces(host, runtime):
		if q.get("off", false) or q.get("slot", false): continue
		var row: Array = q.row
		var x0 := _x(c, row[0]); var x1 := _x(c, row[1]); var y: float = row[2] + c.y_snap; var w := x1 - x0
		if x1 < c.camera.x - 30 or x0 > c.camera.x + c.width + 30 or y > bottom: continue
		var look: String = q.get("look", "landing" if q.plat else "floor")
		if look in ["floor", "step"]:
			var key := "fl_" + _wall_key(c, maxf(row[0], c.camera.x))
			var sz := _world_size(c, key)
			var upper: bool = row[2] < c.ground - 40 and _wall_key(c, maxf(row[0], c.camera.x)) not in c.level.get("anchor", []) and c.images.has(_wall_key(c, maxf(row[0], c.camera.x)))
			var bot := y + minf(sz.y, 26) if upper and sz != Vector2.ZERO else bottom
			if sz != Vector2.ZERO:
				var start := floorf(maxf(row[0], c.camera.x - sz.x) / sz.x) * sz.x
				while start < minf(row[1], c.camera.x + c.width):
					_clipped_texture(out, c, key, Rect2(_x(c, start), y, sz.x, sz.y), Rect2(x0, y, w, bot - y), "moving_day_floor"); start += sz.x
				if not upper: _rect(out, Rect2(x0, y + sz.y, w, bottom - y - sz.y), Color(palette[2]), "moving_day_floor_depth")
			else:
				_rect(out, Rect2(x0, y, w, bottom - y), Color(palette[2]), "moving_day_floor_depth")
				_rect(out, Rect2(x0, y, w, 14), Color(palette[0]), "moving_day_floor")
			_rect(out, Rect2(x0, y, w, 3), Color(0.05, 0.09, 0.15, 0.35), "moving_day_floor_edge")
		elif look == "stack":
			var x: float = row[0] + 32
			while x < row[1]: _column(out, c, x, row[2], q.get("base", row[2] + 200), int(roundf(x / 64))); x += 64
		elif look == "boxplat":
			var base: float = q.get("base", y + 112)
			for x in [x0 + 8, x1 - 16]: _rect(out, Rect2(x, y + 70, 8, base - y - 70), Color("5a3a26"), "moving_day_trestle")
			_rect(out, Rect2(x0, y + 56, w, 14), Color("8a5a3a"), "moving_day_trestle")
			var x: float = row[0] + 32
			while x < row[1]: _column(out, c, x, row[2], row[2] + 56, int(roundf(x / 64)) + 1); x += 64
		elif look == "landing":
			_rect(out, Rect2(x0, y, w, 16), Color("5a3a26"), "moving_day_landing")
			_rect(out, Rect2(x0, y, w, 5), Color("8a5a3a"), "moving_day_landing")
			for x in range(int(x0 + 6), int(x1 - 4), 16): _rect(out, Rect2(x, y - 54, 3, 54), Color("2a2a32"), "moving_day_banister")
			_rect(out, Rect2(x0, y - 60, w, 8), Color("6a4228"), "moving_day_banister")
			if q.get("base", 0):
				for x in [x0 + 10, x1 - 16]: _rect(out, Rect2(x, y + 20, 6, q.base - row[2] - 20), Color("2a2a32"), "moving_day_landing_leg")
		elif look == "shelf":
			if q.get("base", 0):
				for x in [x0 + 2, x1 - 14]: _rect(out, Rect2(x, y, 12, q.base - row[2]), Color("2f5f9e"), "moving_day_shelf_leg")
			_rect(out, Rect2(x0, y, w, 14), Color("e8742a"), "moving_day_shelf"); _rect(out, Rect2(x0, y, w, 4), Color("f59a5a"), "moving_day_shelf")
		elif look == "belt":
			if not q.plat: _rect(out, Rect2(x0, y, w, bottom - y), Color(palette[2]), "moving_day_belt_depth")
			_rect(out, Rect2(x0, y + 4, w, 24), Color("4a4e57"), "moving_day_belt"); _rect(out, Rect2(x0, y, w, 8), Color("23252b"), "moving_day_belt")
			var phase := fposmod(time * 1000 * float(q.get("push", 0)), 24)
			for x in range(int(x0 - 24 + phase), int(x1), 24): _rect(out, Rect2(maxf(x0, x), y + 1, minf(10, x1 - maxf(x0, x)), 6), Color("3c3f47"), "moving_day_tread")
			for x in range(int(x0 + 10), int(x1 - 6), 30): _ellipse(out, Vector2(x, y + 18), Vector2(6, 6), Color("9aa3ad"), "moving_day_roller")
			for x in range(int(x0 + 40), int(x1 - 30), 120):
				var d := 1 if q.get("push", 0) > 0 else -1
				out.append({"type": "polygon", "points": PackedVector2Array([Vector2(x + 10 * d, y + 18), Vector2(x - 4 * d, y + 11), Vector2(x - 4 * d, y + 25)]), "colour": GOLD, "tag": "moving_day_belt_arrow"})
		elif look == "slab":
			_rect(out, Rect2(x0, y, w, 34), Color(palette[2]), "moving_day_slab"); _rect(out, Rect2(x0, y, w, 12), Color(palette[0]), "moving_day_slab"); _rect(out, Rect2(x0, y + 30, w, 6), Color("e6dfcf"), "moving_day_ceiling")
			if q.get("lamp", false): _rect(out, Rect2((x0 + x1) / 2 - 1, y + 36, 2, 20), Color("3a3f4a"), "moving_day_lamp"); _rect(out, Rect2((x0 + x1) / 2 - 8, y + 56, 16, 8), Color("fff1a8"), "moving_day_lamp")
		elif look == "mattress":
			var sq: float = q.get("squash", 0) * 10
			_border(out, Rect2(x0, y - 4 + sq, w, 34 - sq), 10, Color("8fb8e0"), Color("2f5f9e"), 3, "moving_day_mattress")
			_rect(out, Rect2(x0 + 6, y + 22, w - 12, 3), Color("ff8fc7"), "moving_day_mattress_trim")
		elif look == "deck":
			var sz := _world_size(c, "lorry"); var offset: Array = c.level.get("lorry", [0, -129])
			_texture(out, c, "lorry", Rect2(x0 + offset[0], y + offset[1] + source_round(sin(time / 0.09) * 1.2), sz.x, sz.y), "moving_day_lorry")
	for d in c.level.get("decor", []):
		var sz := _world_size(c, d[0]); _texture(out, c, d[0], Rect2(_x(c, d[1]), d[2] + c.y_snap, sz.x, sz.y), "moving_day_decor", Rect2(), bool(d[3]))
	out.append_array(_build_back(host, runtime, c))
	return out
func _build_back(host, runtime, c: Dictionary) -> Array:
	var out: Array = []
	var time := float(_state(runtime, "elapsed", host.elapsed))
	for s in _state(runtime, "shutters", []):
		var painted: Dictionary = host.level.get("paintShut", {})
		if not painted.is_empty() and s.open < 0.01: continue
		var w: float = painted.get("w", 118); var h: float = painted.get("h", 150)
		var x := _x(c, s.x) - w / 2; var y: float = s.top + float(painted.get("dy", 0)) - h + c.y_snap
		_rect(out, Rect2(x, y, w, h), Color("16191f"), "moving_day_shutter_open")
		for yy in range(0, int(roundf(h * (1 - float(s.open)))) , 7): _rect(out, Rect2(x, y + yy, w, 7), Color("d9631f" if int(yy / 7) % 2 else "ef7f2e"), "moving_day_shutter")
	if host.level.get("check", 0):
		var x := _x(c, host.level.check); var chk: Dictionary = _state(runtime, "checkpoint", {})
		var top := _floor_at(host, runtime, host.level.check) if chk.is_empty() else float(chk.y)
		_rect(out, Rect2(x - 2, top - 170, 5, 170), Color("3a4458"), "moving_day_checkpoint_pole")
		out.append({"type": "polygon", "points": PackedVector2Array([Vector2(x + 3, top - 168), Vector2(x + 62, top - 152 + sin(time / 0.16) * 3), Vector2(x + 3, top - 132)]), "colour": Color("e9e4da" if chk.is_empty() else "6fbf8e"), "tag": "moving_day_checkpoint"})
	return out
func draw_mid(host, runtime = null, pickups: Callable = Callable()) -> void:
	if not supports(host.level_id): return
	draw_commands(host, build_mid(host, runtime))
	if pickups.is_valid(): pickups.call()
	else: draw_commands(host, build_finds(host, runtime))
func build_finds(host, runtime = null) -> Array:
	var out: Array = []; var c := _festival_context(host)
	var receipts: Array = _state(host, "receipts", [])
	var time := float(_state(runtime, "elapsed", host.elapsed))
	for i in receipts.size():
		var r: Dictionary = receipts[i]
		if r.get("taken", r.get("got", false)): continue
		var p: Vector2 = r.get("position", r.get("p", Vector2.ZERO))
		if p.x - c.camera.x < -40 or p.x - c.camera.x > c.width + 40: continue
		var x := _x(c, p.x); var y: float = source_round(p.y - 46 + sin(time / 0.26) * 4) + c.y_snap
		_rect(out, Rect2(x - 11, y - 16, 22, 32), Color("f5f1ea"), "moving_day_receipt")
		for tooth in range(-12, 12, 6): _rect(out, Rect2(x + tooth, y + 14, 3, 3), Color("c9c2b4"), "moving_day_receipt_tooth")
		for line in 5: _rect(out, Rect2(x - 7, y - 11 + line * 5, 8 if line == 4 else 14, 2), Color("8a8478"), "moving_day_receipt_line")
		_rect(out, Rect2(x - 7, y + 10, 14, 2), Color("2d6a4f"), "moving_day_receipt_line")
	var skill = _state(host, "movement_skills", null)
	if host.level.has("card") and not bool(_state(skill, "card_collected", false)):
		var p := Vector2(host.level.card[0], host.level.card[1] - 60 + sin(time / 0.2) * 5)
		_ellipse(out, p, Vector2.ONE * (34 + sin(time / 0.12) * 3), Color(0.96, 0.77, 0.26, 0.3), "moving_day_card_glow")
		_border(out, Rect2(p - Vector2(22, 30), Vector2(44, 60)), 6, Color("2d6a4f"), GOLD, 3, "moving_day_card")
		out.append({"type": "text", "position": p - Vector2(0, 6), "text": "W", "size": 18, "colour": GOLD, "tag": "moving_day_card_label"})
		out.append({"type": "text", "position": p + Vector2(0, 16), "text": "JUMP", "size": 9, "colour": Color("f5f1ea"), "tag": "moving_day_card_label"})
	return out
func build_mid(host, runtime = null) -> Array:
	var out: Array = []; var c := _festival_context(host)
	for m in _state(runtime, "mimics", []):
		if not m.sprung and not m.surface.is_empty(): _moving_box(out, c, "boxM", Vector2(m.x, m.surface.row[2]))
	for d in _state(runtime, "drops", []):
		if d.state == "warn": _ellipse(out, Vector2(_x(c, d.x), d.top - 3), Vector2(20 + d.t / 0.65 * 18, 6), Color(0.05, 0.09, 0.15, 0.15 + d.t / 0.65 * 0.3), "moving_day_drop_warning")
		elif d.state == "fall": _moving_box(out, c, "box2", Vector2(d.x, d.y))
	for b in _state(runtime, "beams", []):
		if b.warn > 0:
			if int(b.t / 0.2) % 2: out.append({"type": "text", "position": Vector2(c.camera.x + c.width - 120, 230), "text": "Low bridge!", "size": 16, "colour": Color("ffb3b3"), "tag": "moving_day_bridge_warning"})
		else:
			var sz := _world_size(c, "bridge")
			if sz != Vector2.ZERO: _texture(out, c, "bridge", Rect2(_x(c, b.x - sz.x / 2), 270 - sz.y, sz.x, sz.y), "moving_day_bridge")
			else:
				var x := _x(c, b.x)
				_rect(out, Rect2(x - 70, host.view_top() - 40, 140, 270 - host.view_top() + 40), Color("8a8f99"), "moving_day_bridge")
				_rect(out, Rect2(x - 90, 236, 180, 34), Color("6b7079"), "moving_day_bridge_beam")
				for i in 6: _rect(out, Rect2(x - 84 + i * 30, 260, 16, 6), GOLD, "moving_day_bridge_stripe")
	var sofa: Dictionary = _state(runtime, "sofa", {})
	if not sofa.is_empty():
		var r: Rect2 = runtime.sofa_rect()
		var key := "sofaUp" if sofa.tip else "sofa"
		_ellipse(out, Vector2(_x(c, sofa.x), sofa.fy - 2), Vector2(r.size.x / 2, 7), Color(0.05, 0.09, 0.15, 0.28), "moving_day_sofa_shadow")
		var sz := _world_size(c, key)
		_texture(out, c, key, Rect2(_x(c, r.position.x) + source_round((r.size.x - sz.x) / 2), source_round(r.position.y) + r.size.y - sz.y, sz.x, sz.y), "moving_day_sofa")
		if sofa.door != null and not sofa.tip: out.append({"type": "text", "position": Vector2(_x(c, sofa.x), r.position.y - 30), "text": "Hold duck to tip it up", "size": 13, "colour": GOLD, "tag": "moving_day_sofa_hint"})
	var lift: Dictionary = _state(runtime, "lift", {})
	if not lift.is_empty():
		var q: Dictionary = lift.surface
		var x: float = _x(c, q.row[0]); var y: float = q.row[2]; var w: float = q.row[1] - q.row[0]
		for xx in [x + 10, x + w - 14]: _rect(out, Rect2(xx, host.view_top() - 20, 4, y - 230 - host.view_top() + 20), Color("3a3f4a"), "moving_day_lift_cable")
		_border(out, Rect2(x + 1, y - 229, w - 2, 228), 0, Color(0.12, 0.13, 0.16, 0.55), Color("9aa3ad"), 3, "moving_day_lift")
		for xx in range(int(x + 16), int(x + w - 8), 16): _rect(out, Rect2(xx, y - 226, 2, 222), Color(0.6, 0.64, 0.68, 0.5), "moving_day_lift_gate")
		_rect(out, Rect2(x - 4, y, w + 8, 14), Color("7c8490"), "moving_day_lift_floor")
		_rect(out, Rect2(x + w / 2 - 6, y - 252, 12, 10), Color("e23b3b" if lift.state in ["shake", "drop"] else "6fbf8e"), "moving_day_lift_light")
	return out
func build_enemy(host, bot: Dictionary) -> Array:
	var out := super.build_enemy(host, bot)
	var c := _festival_context(host); var p: Vector2 = bot.p
	if bot.get("big", false):
		for cmd in out:
			if cmd.type == "festival_texture":
				cmd.rect = Rect2(Vector2(_x(c, p.x), p.y) + (cmd.rect.position - Vector2(_x(c, p.x), p.y)) * 1.7, cmd.rect.size * 1.7)
		if bot.state != "pop":
			_rect(out, Rect2(_x(c, p.x) - 26, p.y - 205, 52, 16), Color("2d6a4f"), "moving_day_removal_cap")
			_rect(out, Rect2(_x(c, p.x) - 30, p.y - 113, 60, 10), GOLD, "moving_day_removal_vest")
			_rect(out, Rect2(_x(c, p.x) - 40, p.y - 223, 80, 8), Color("14243b"), "moving_day_removal_hp_back")
			_rect(out, Rect2(_x(c, p.x) - 39, p.y - 222, 78 * maxf(0, float(bot.hp) / float(bot.max_hp)), 6), Color("e23b3b"), "moving_day_removal_hp")
	elif bot.type == "tape" and bot.state != "pop":
		for r in [[13, "c9a25a"], [9, "e8cf98"], [5, "2a2230"]]: _ellipse(out, Vector2(_x(c, p.x), p.y - 132), Vector2.ONE * r[0], Color(r[1]), "moving_day_tape_roll")
		_rect(out, Rect2(_x(c, p.x) + bot.face * 26 - 8, p.y - 70, 16, 10), Color("e23b3b"), "moving_day_tape_gun")
	return out
func build_boss(host, runtime = null) -> Array:
	if host.boss == null: return []
	var out: Array = []; var c := _festival_context(host); var b: Dictionary = host.boss.state
	for f in b.flying:
		var size := _world_size(c, f.key)
		var points := PackedVector2Array()
		for corner in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]: points.append(f.p + (corner * size).rotated(float(f.angle)))
		out.append({"type": "moving_day_box_quad", "points": points, "texture": c.images[f.key], "tag": "moving_day_flying_box"})
	if b.state in ["collapse", "rebuild"]: return out
	if b.state == "down":
		for i in 7: _moving_box(out, c, "box1" if i % 2 else "box2", Vector2(b.x - 150 + i * 48, c.ground))
		for i in 4: _moving_box(out, c, "box2" if i % 2 else "box3", Vector2(b.x - 100 + i * 60, c.ground - 46))
		_moving_box(out, c, "crown", Vector2(b.x + 20, c.ground - 100), _world_size(c, "crown") * 0.6)
		return out
	var sh: Dictionary = host.boss.shape()
	_ellipse(out, Vector2(_x(c, b.x), c.ground - 2), Vector2(b.hw + 10, 12), Color(0.05, 0.09, 0.15, 0.3), "moving_day_king_shadow")
	out.append({"type": "polygon", "points": PackedVector2Array([Vector2(b.x - b.hw + 20, c.ground + sh.top + 90), Vector2(b.x + b.hw - 20, c.ground + sh.top + 90), Vector2(b.x + b.hw + 10, c.ground - 40), Vector2(b.x - b.hw - 10, c.ground - 40)]), "colour": Color(0.78, 0.9, 1, 0.55), "tag": "moving_day_king_cape"})
	for q in sh.boxes:
		var begin := out.size()
		_moving_box(out, c, q.key, Vector2(b.x + q.dx, c.ground + q.dy), Vector2(q.w, q.h))
		if b.flash > 0:
			for index in range(begin, out.size()):
				out[index].type = "festival_texture"; out[index].texture = c.images[q.key]; out[index].flash = true; out[index].filter = ""
		if q.get("head", false):
			var ey: float = c.ground + q.dy - q.h + 26; var ex: float = b.x + b.face * 6
			for x in [ex - 22, ex + 10]: _rect(out, Rect2(x, ey - 2, 12, 9), GOLD if b.dizzy > 0 else Color("ff3b3b"), "moving_day_king_eye")
			_rect(out, Rect2(ex - 16, ey + 20, 32, 5), Color("2a1a10"), "moving_day_king_mouth")
			_moving_box(out, c, "crown", Vector2(b.x, c.ground + q.dy - q.h + 4))
	for wave in b.waves:
		for i in 4: _moving_box(out, c, "box3", Vector2(wave.x - i * 14 * signf(wave.vx), c.ground - (3 - i) * 6 - absf(sin(wave.t / 0.06 + i)) * 10), Vector2(24, 20))
	return out
func build_bill(host, bill: Dictionary) -> Array:
	var c := _festival_context(host)
	if bill.get("box", false):
		var out: Array = []; _moving_box(out, c, "box2", bill.p + Vector2(0, 24), Vector2(56, 48)); return out
	if bill.get("tape", false):
		var out: Array = []; _rect(out, Rect2(bill.p - Vector2(16, 6), Vector2(32, 12)), Color("e8cf98"), "moving_day_tape_bill"); return out
	return super.build_bill(host, bill)
func build_front(host, _runtime = null) -> Array:
	var out: Array = []; var c := _festival_context(host)
	for h in host.level.get("hints", []):
		if host.elapsed * 1000 < (float(h[3]) if h.size() > 3 else 0): continue
		if host.player.x < h[0] + 60 and host.player.x > h[0] - 700: out.append({"type": "text", "position": Vector2(_x(c, h[0]), h[1] - 40 + sin(host.elapsed / 0.18) * 5), "text": str(h[2]), "size": 13, "colour": GOLD, "tag": "moving_day_hint"})
	return out
func build_hud(host, runtime = null) -> Array:
	var out: Array = []
	var receipts: Array = _state(host, "receipts", [])
	if host.mode == "play" and not host.level.get("receipts", []).is_empty():
		var found := receipts.filter(func(r): return r.get("taken", r.get("got", false))).size()
		out.append({"type": "text", "position": Vector2(490, 476 if host.boss != null and host.boss.state.state != "down" else 522), "text": "Receipts %d/3" % found, "size": 11, "colour": Color("dce8d3"), "tag": "moving_day_receipt_count"})
	if host.level.get("clock", 0):
		var remaining := int(ceilf(float(_state(runtime, "clock_left", 0))))
		out.append({"type": "text", "position": Vector2(490, 92), "text": "%d:%02d" % [remaining / 60, remaining % 60], "size": 22, "colour": Color("ffb3b3" if remaining < 15 else "f5f1ea"), "tag": "moving_day_clock"})
	if host.level.get("timed", 0):
		var f := minf(1, float(_state(runtime, "elapsed", host.elapsed)) * 1000 / float(host.level.timed))
		_border(out, Rect2(340, 84, 300, 12), 6, Color("14243b"), Color("f5f1ea"), 2, "moving_day_trip_back")
		_rounded(out, Rect2(342, 86, maxf(8, 296 * f), 8), 4, Color("6fbf8e"), "moving_day_trip")
		out.append({"type": "text", "position": Vector2(686, 91), "text": "New flat", "size": 11, "colour": Color("dce8d3"), "tag": "moving_day_trip_label"})
	# Shared command-only health bar and polish iris; King supplies phase name.
	out.append_array(super.build_hud(host, runtime))
	return out
func build_player_back(_host, _player = null) -> Array: return []
func build_player_front(_host, _player = null) -> Array: return []

func draw_jar(host, _runtime = null) -> void:
	if host.boss == null: return
	var jar: Dictionary = host.boss.state.get("jar", {})
	if jar.is_empty(): return
	var out: Array = []; var c := _festival_context(host)
	var p := Vector2(_x(c, jar.x), jar.y + (0 if jar.got else sin(jar.t / 0.14) * 2))
	if not jar.got: _ellipse(out, p - Vector2(0, 4), Vector2.ONE * (44 + sin(jar.t / 0.1) * 4), Color(1, 0.95, 0.66, 0.35), "moving_day_jar_glow")
	_border(out, Rect2(p - Vector2(20, 24), Vector2(40, 46)), 8, Color("e8e1d2"), Color("3a4250"), 3, "moving_day_jar")
	_rect(out, Rect2(p - Vector2(22, 28), Vector2(44, 8)), GOLD, "moving_day_jar_lid")
	out.append({"type": "text", "position": p, "text": "£", "size": 24, "colour": Color("2d6a4f"), "tag": "moving_day_jar_label"})
	draw_commands(host, out)

func build_coin(host, coin: Dictionary) -> Array:
	if not coin.get("stay", false): return super.build_coin(host, coin)
	var visual := coin.duplicate()
	visual.age = fposmod(float(coin.get("age", 0)), 0.24)
	return super.build_coin(host, visual)

func draw_commands(host, commands: Array) -> void:
	for command in commands:
		if command.type == "moving_day_box_quad": host.draw_polygon(command.points, PackedColorArray([Color.WHITE]), PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]), _nearest(command.texture))
		else: super.draw_commands(host, [command])
