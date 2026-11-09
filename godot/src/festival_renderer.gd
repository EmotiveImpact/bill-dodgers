extends "res://src/aisle_renderer.gd"
## Source World 3 festival painter. Absolute world pixels; clocks in seconds.
## Shared superclass contributes command primitives only, never W2 scene art.
## 3-1 only. The host owns simulation, receipt collection and actor draw order.

const TENT_COLOURS := [["d94a3d", "f06a55"], ["2f7fc9", "4fa0e6"], ["3f9a5a", "5fbf78"], ["ef8a2b", "ffaa4d"], ["8a5bc9", "a87de6"], ["e9c13a", "ffd95c"]]
const HEART_PIXELS := [".XX.XX.", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..."]
var _festival_variants: Dictionary = {}

func supports(id: String) -> bool:
	return id == "3-1"

func _festival_context(host) -> Dictionary:
	var c := _context(host)
	c.l3 = host.meta.get("l3", {})
	c.hi = host.meta.get("hi", {})
	return c

func _world_size(c: Dictionary, key: String) -> Vector2:
	return _size(c, key) / float(c.hi.get(key, 1))

func _scene(c: Dictionary, runtime) -> Dictionary:
	var scenes: Array = c.l3.get("scenes", [])
	if scenes.is_empty(): return {}
	var index := int(_state(runtime, "scene_index", -1))
	if index >= 0: return scenes[clampi(index, 0, scenes.size() - 1)]
	var selected: Dictionary = scenes[0]
	for scene in scenes:
		if float(c.camera.x) + float(c.width) / 2 >= float(scene.get("to", scene.x)): selected = scene
	return selected

func _paint_top(c: Dictionary, scene: Dictionary) -> float:
	return source_round(float(c.ground) - float(c.l3.layerInfo[scene.key].h) * float(scene.get("feet", c.l3.get("feet", 0.81))) + 14)

func _par(out: Array, c: Dictionary, key: String, factor: float, y: float, tag: String, elapsed: float = 0, drift: float = 0, sky: bool = false) -> void:
	var size := _world_size(c, key)
	if size == Vector2.ZERO: return
	var w := source_round(size.x)
	var h := source_round(size.y)
	var scroll := float(c.camera.x) * factor + drift * elapsed
	var first := int(floorf(scroll / w))
	var offset := source_round(scroll - first * w)
	var i := 0
	# Source rounds the first offset once, not each floating world position.
	while -offset + i * w < float(c.width) + 2:
		_texture(out, c, key, Rect2(float(c.camera.x) - offset + i * w, source_round(y) + (float(c.camera.y) if sky else float(c.y_snap)), w, h), tag, Rect2(), (first + i) % 2 != 0, {"index": first + i, "factor": factor})
		i += 1

func build_sky(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _festival_context(host)
	var stops := [-10.0, 0.0, 297.0, 540.0, 550.0]
	var colours := [Color("5fb4ef"), Color("5fb4ef"), Color("a9dcf7"), Color("f8e7b5"), Color("f8e7b5")]
	for i in range(stops.size() - 1):
		out.append({"type": "gradient", "rect": Rect2(c.camera.x - 10, c.camera.y + stops[i], c.width + 20, stops[i + 1] - stops[i]), "colours": PackedColorArray([colours[i], colours[i], colours[i + 1], colours[i + 1]]), "tag": "festival_sky_gradient"})
	var scene := _scene(c, runtime)
	if scene.is_empty(): return out
	var info: Dictionary = c.l3.layerInfo[scene.key]
	var top := _paint_top(c, scene)
	var lock := top - float(c.camera.y) + float(info.land_top) - float(info.sky_clean)
	_par(out, c, str(scene.key) + "_sky", float(scene.get("skyF", 0.05)), maxf(top - float(c.camera.y) * 0.12, lock), "festival_sky", float(_state(runtime, "elapsed", host.elapsed)), float(scene.get("drift", 2.5)), true)
	return out

func _surfaces(host, runtime) -> Array:
	if runtime != null and runtime is Object and runtime.has_method("surfaces"): return runtime.surfaces(host)
	var existing = _state(runtime, "live_surfaces", _state(runtime, "surfaces", null))
	if existing is Array: return existing
	var result: Array = []
	for rows in [host.level.get("solids", []), host.level.get("plats", [])]:
		for row in rows:
			var q: Dictionary = row[3].duplicate() if row.size() > 3 and row[3] is Dictionary else {}
			q.row = row
			q.plat = rows == host.level.get("plats", [])
			result.append(q)
	return result

func _tents(host, runtime) -> Array:
	var existing = _state(runtime, "tents", null)
	if existing is Array: return existing
	var result: Array = []
	for row in host.level.get("tents", []): result.append({"x": row[0], "y": row[1], "kind": row[3], "shake": 0.0})
	return result

func build_level(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _festival_context(host)
	var scene := _scene(c, runtime)
	if not scene.is_empty():
		var info: Dictionary = c.l3.layerInfo[scene.key]
		var top := _paint_top(c, scene)
		if info.has("far"): _par(out, c, str(scene.key) + "_far", 0.16, top + float(info.far.y), "festival_far")
		_par(out, c, str(scene.key) + "_land", float(scene.get("landF", 0.5)), top + float(info.get("land", {}).get("y", 0)), "festival_land")
		_mid_props(out, c, top + float(info.ground_y) + 22)
		_par(out, c, str(scene.key) + "_ground", 1, top + float(info.ground_y), "festival_ground")
	for decor in c.level.get("decor", []):
		if decor[4] == "back": _decor_cut(out, c, decor)
	for tent in _tents(host, runtime):
		var key := "cut_" + str(tent.kind).trim_prefix("cut:")
		var size := _world_size(c, key)
		var x := float(tent.x)
		if x - c.camera.x < -260 or x - c.camera.x > c.width + 260: continue
		var shake := float(tent.get("shake", 0))
		var jitter := sin(shake / 0.02) * 3 if shake > 0 else 0.0
		_texture(out, c, key, Rect2(_x(c, x - size.x / 2 + jitter), source_round(float(tent.y) - size.y + 4) + float(c.y_snap), size.x, size.y), "festival_tent")
	for q in _surfaces(host, runtime): _surface(out, c, q)
	_mud(out, c)
	for decor in c.level.get("decor", []):
		if decor[4] not in ["back", "front"]: _decor_cut(out, c, decor)
	_checkpoint(out, c, runtime, float(_state(runtime, "elapsed", host.elapsed)))
	# Finds are the final source drawLevel phase, exposed as draw_mid to allow
	# an explicit host callback without double-drawing or mutating collection.
	return out

func _mid_props(out: Array, c: Dictionary, base: float) -> void:
	for prop in c.l3.get("fg", []):
		var key := "cut_" + str(prop[0])
		var size := _world_size(c, key) * 0.72
		var x := (float(prop[1]) - float(c.camera.x)) * 0.78 + float(c.width) / 2 * 0.22 - size.x / 2
		if x > float(c.width) + 20 or x + size.x < -20: continue
		var start := out.size()
		_texture(out, c, key, Rect2(float(c.camera.x) + source_round(x), source_round(base - size.y) + float(c.y_snap), size.x, size.y), "festival_mid_prop", Rect2(), false, {"filter": "mid_prop"})
		for i in range(start, out.size()): out[i].type = "festival_texture"

func _decor_cut(out: Array, c: Dictionary, decor: Array) -> void:
	var key := "cut_" + str(decor[0]).trim_prefix("cut:")
	var x := float(decor[1])
	if x - c.camera.x < -560 or x - c.camera.x > c.width + 560: return
	var scale := float(decor[5]) if decor.size() > 5 and float(decor[5]) != 0 else 1.0
	var size := _world_size(c, key) * scale
	var flip := int(decor[3]) == 1
	var left := _x(c, x + size.x / 2) - size.x if flip else _x(c, x - size.x / 2)
	_texture(out, c, key, Rect2(left, source_round(float(decor[2]) - size.y) + float(c.y_snap), size.x, size.y), "festival_decor", Rect2(), flip)

func _clip_texture(command: Dictionary, clip: Rect2) -> Dictionary:
	var rectangle: Rect2 = command.rect
	var intersection := rectangle.intersection(clip)
	if not intersection.has_area(): return {}
	var source: Rect2 = command.source
	var ratio := source.size / rectangle.size
	var delta := intersection.position - rectangle.position
	if command.flip_h: delta.x = rectangle.end.x - intersection.end.x
	var clipped := command.duplicate()
	clipped.rect = intersection
	clipped.source = Rect2(source.position + delta * ratio, intersection.size * ratio)
	clipped.clip = clip
	clipped.unclipped_rect = rectangle
	return clipped

func _surface(out: Array, c: Dictionary, q: Dictionary) -> void:
	var row: Array = q.get("row", [q.get("x0", 0), q.get("x1", 0), q.get("top", 0)])
	var a := float(row[0])
	var b := float(row[1])
	if not _in_view(c, a, b): return
	var style := str(q.get("style", "plank" if q.get("plat", false) else "ground"))
	# Painted ground and caravan roofs are deliberately not painted twice.
	if style != "bales": return
	var base := float(q.get("base", c.ground))
	var clip := Rect2(_x(c, a), float(row[2]) - 2 + float(c.y_snap), source_round(b - a), base - float(row[2]) + 4)
	var y := float(row[2])
	var r := 0
	while y < base:
		var x := a - (r % 2) * 60
		while x < b:
			var commands: Array = []
			_texture(commands, c, "baletile", Rect2(_x(c, x), source_round(y) + float(c.y_snap), 120, 54), "festival_bale", Rect2(), false, {"row": r})
			for command in commands:
				var clipped := _clip_texture(command, clip)
				if not clipped.is_empty(): out.append(clipped)
			x += 120
		y += 54
		r += 1

static func _festival_random(state: Array) -> float:
	state[0] = (int(state[0]) * 16807) % 2147483647
	return float(state[0]) / 2147483647.0

func _mud(out: Array, c: Dictionary) -> void:
	for mud in c.level.get("mud", []):
		var a := float(mud[0]) - float(c.camera.x)
		var b := float(mud[1]) - float(c.camera.x)
		if b < -20 or a > float(c.width) + 20: continue
		var x := floorf(a / 4) * 4
		while x < b:
			var edge := minf(1, minf((x - a) / 60, (b - x) / 60))
			# The first four-pixel cell can have a negative Canvas CSS alpha;
			# clamp it to zero rather than rendering an opaque invalid colour.
			_rect(out, Rect2(c.camera.x + x, c.ground - 6 + (int(floorf(x + float(c.camera.x))) * 13) % 3 + c.y_snap, 4, 26), Color(52 / 255.0, 30 / 255.0, 18 / 255.0, clampf(0.55 * edge, 0, 1)), "festival_mud")
			x += 4
		var random := [absi(int(floorf(float(mud[0])))) % 2147483646 + 1]
		for i in int(ceilf((b - a) / 90)):
			var px := a + 30 + _festival_random(random) * (b - a - 90)
			var pw := 24 + _festival_random(random) * 40
			var py := float(c.ground) + 4 + source_round(_festival_random(random) * 12) + float(c.y_snap)
			_rect(out, Rect2(c.camera.x + source_round(px), py, source_round(pw), 3), Color(190 / 255.0, 220 / 255.0, 240 / 255.0, 0.55), "festival_puddle")
			_rect(out, Rect2(c.camera.x + source_round(px) + 4, py, 6, 1), Color(1, 1, 1, 0.5), "festival_puddle_glint")

func _checkpoint(out: Array, c: Dictionary, runtime, elapsed: float) -> void:
	if not c.l3.has("check"): return
	var wx := float(c.l3.check)
	var sx := wx - float(c.camera.x)
	if sx < -60 or sx > float(c.width) + 60: return
	var x := _x(c, wx)
	var y := float(c.l3.get("checkY", c.ground)) + float(c.y_snap)
	var saved := bool(_state(runtime, "checkpoint_done", false))
	_rect(out, Rect2(x - 3, y - 200, 6, 200), Color("d9dde4"), "festival_checkpoint_pole")
	_poly(out, [Vector2(wx + 3, y - 198), Vector2(wx + 70, y - 180 + sin(elapsed / 0.15) * 4), Vector2(wx + 3, y - 150)], Color("2d6a4f") if saved else GOLD, "festival_checkpoint_flag")
	out.append({"type": "outlined_text", "position": Vector2(x, y - 218), "text": "Saved" if saved else "Checkpoint", "size": 11, "colour": Color("9fe0b8") if saved else GOLD, "outline": Color("0e1726"), "outline_size": 3, "tag": "festival_checkpoint_label"})

func build_mid(host, runtime = null) -> Array:
	return build_finds(host, runtime)

func draw_mid(host, runtime = null, pickups: Callable = Callable()) -> void:
	if not supports(host.level_id): return
	if pickups.is_valid(): pickups.call()
	else: draw_finds(host, runtime)

func draw_finds(host, runtime = null) -> void:
	draw_commands(host, build_finds(host, runtime))

func build_finds(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _festival_context(host)
	var receipts = _state(host, "receipts", null)
	if not receipts is Array:
		receipts = []
		for row in c.level.get("receipts", []): receipts.append({"position": Vector2(row[0], row[1]), "taken": false})
	var elapsed := float(_state(runtime, "elapsed", host.elapsed))
	for i in receipts.size():
		var receipt: Dictionary = receipts[i]
		if receipt.get("taken", receipt.get("got", false)): continue
		var p: Vector2 = receipt.get("position", receipt.get("p", Vector2.ZERO))
		if p.x - c.camera.x < -40 or p.x - c.camera.x > c.width + 40: continue
		var alpha := 0.45 if receipt.get("previously_collected", false) else 1.0
		var point := Vector2(_x(c, p.x), source_round(p.y + sin(elapsed / 0.2 + i + 1) * 4) + float(c.y_snap))
		_ellipse(out, point, Vector2.ONE * (20 + sin(elapsed / 0.12) * 2), Color(1, 243 / 255.0, 176 / 255.0, 0.3 * alpha), "festival_receipt_glow")
		_rect(out, Rect2(point - Vector2(9, 14), Vector2(18, 28)), Color(1, 1, 1, alpha), "festival_receipt")
		for line in 4: _rect(out, Rect2(point + Vector2(-6, -9 + line * 6), Vector2(7 if line == 3 else 12, 2)), Color(154 / 255.0, 163 / 255.0, 178 / 255.0, alpha), "festival_receipt_line")
		for tooth in 3: _rect(out, Rect2(point + Vector2(-9 + tooth * 7, 14), Vector2(4, 3)), Color(1, 1, 1, alpha), "festival_receipt_tooth")
	return out

func build_enemy(host, bot: Dictionary) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _festival_context(host)
	var p: Vector2 = bot.p
	if p.x - c.camera.x < -150 or p.x - c.camera.x > c.width + 150: return out
	var x := _x(c, p.x)
	_ellipse(out, Vector2(x, p.y - 2 + float(c.y_snap)), Vector2(34, 6), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.25), "festival_bot_shadow")
	var animation := "pop" if bot.state == "pop" else ("throw" if bot.state == "throw" else "walk")
	var move := int(bot.get("visual_move", 0))
	var frame := mini(3, int(float(bot.t) / 0.11)) if animation != "walk" else (int(float(bot.get("stride", 0)) / 9) % 6 if move else 5)
	var alpha := maxf(0, 1 - (float(bot.get("gone", 0)) - 0.8) / 0.5) if bot.state == "pop" else 1.0
	var rise := float(bot.get("rise", 0))
	var face := -int(bot.face) if rise > 0 or animation != "walk" or not move else -move
	if float(bot.get("dz", 0)) > 0:
		for i in 3:
			var angle := float(host.elapsed) / 0.15 + i * 2.1
			_rect(out, Rect2(_x(c, p.x + cos(angle) * 26) - 3, source_round(p.y - 130 + sin(angle) * 6) - 3 + float(c.y_snap), 6, 6), GOLD, "festival_bot_dizzy")
	var commands := _sprite_commands(host, c, "bot", animation, frame, Vector2(p.x, p.y + rise * 240), face, alpha, "", float(bot.get("flash", 0)) > 0, "festival_bot")
	if rise > 0:
		var clip := Rect2(p.x - 160, p.y - 230 + float(c.y_snap), 320, 232)
		for command in commands:
			var clipped := _clip_texture(command, clip)
			if not clipped.is_empty(): out.append(clipped)
	else: out.append_array(commands)
	if bot.get("type", bot.get("kind", "")) == "flat" and bot.state != "pop": _rect(out, Rect2(x - 3, p.y - 128 + float(c.y_snap), 6, 6), Color("e23b3b"), "festival_flat_marker")
	return out

func _sprite_commands(host, c: Dictionary, key: String, animation: String, frame: int, feet: Vector2, face: int, alpha: float, tint: String, flash: bool, tag: String) -> Array:
	var sheet: Dictionary = host.meta.get("sheets", {}).get(key, {})
	var texture: Texture2D = host.images.get(key)
	if texture == null and _state(host, "sheets", null) != null: texture = host.sheets.get(key)
	if texture == null or sheet.is_empty(): return []
	var anim: Dictionary = sheet.anims[animation]
	frame = clampi(frame, 0, int(anim.frames) - 1)
	var x := _x(c, feet.x)
	var left := x + source_round(float(sheet.w) / 2) - float(sheet.w) if face < 0 else x - source_round(float(sheet.w) / 2)
	return [{"type": "festival_texture", "texture": texture, "rect": Rect2(left, source_round(feet.y - (float(sheet.h) - 3)) + float(c.y_snap), sheet.w, sheet.h), "source": Rect2(frame * float(sheet.w), float(anim.row) * float(sheet.h), sheet.w, sheet.h), "flip_h": face < 0, "alpha": alpha, "filter": tint, "flash": flash, "tag": tag, "animation": animation, "frame": frame}]

func _boss(host, runtime) -> Dictionary:
	var owner = _state(runtime, "boss", _state(host, "boss", null))
	if owner == null: return {}
	if owner is Dictionary: return owner.get("state", owner) if owner.get("state") is Dictionary else owner
	var state = owner.get("state")
	return state if state is Dictionary else {}

func draw_boss(host, runtime = null) -> void:
	draw_commands(host, build_boss(host, runtime))

func build_boss(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var b := _boss(host, runtime)
	if b.is_empty(): return []
	var c := _festival_context(host)
	var out: Array = []
	var hop = b.get("hop", null)
	var hopping: bool = hop != null and (not hop is Dictionary or not hop.is_empty())
	_ellipse(out, Vector2(_x(c, float(b.x)), (float(c.ground) if hopping else float(b.fy)) - 2 + float(c.y_snap)), Vector2(90, 10), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.3), "festival_boss_shadow")
	var time := float(b.t)
	var animation := "run"
	var frame := int(time / (0.07 if b.state in ["enter", "charge"] else 0.13)) % 6
	if float(b.get("dizzy", 0)) > 0: animation = "down"; frame = int(time / 0.22) % 2
	elif hopping: animation = "throw"; frame = 0
	elif b.state in ["throw", "stomp"]: animation = "throw"; frame = mini(3, int(time / 0.16)) if b.state == "throw" else (0 if time < 0.32 else 1)
	if b.state == "down": animation = "down"; frame = 2 if not b.get("jar", {}).is_empty() else mini(3, int(time / 0.3))
	out.append_array(_sprite_commands(host, c, "thief", animation, frame, Vector2(b.x, b.fy), -int(b.face), 1, str(b.kind), float(b.get("flash", 0)) > 0, "festival_boss"))
	for wave in b.get("waves", b.get("wave", [])):
		var x := _x(c, float(wave.x))
		for i in 4: _rect(out, Rect2(x - 6 - i * 8 * signf(float(wave.vx)), float(c.ground) - 10 - (3 - i) * 7 - sin(float(wave.t) / 0.05 + i) * 3 + float(c.y_snap), 12, 10 + (3 - i) * 4), Color("e8e1d2"), "festival_shockwave")
		_rect(out, Rect2(x - 14, float(c.ground) - 6 + float(c.y_snap), 28, 6), Color("c9bfae"), "festival_shockwave_base")
	return out

func draw_bill(host, bullet: Dictionary) -> void:
	draw_commands(host, build_bill(host, bullet))

func build_bill(host, bullet: Dictionary) -> Array:
	if not supports(host.level_id): return []
	if bullet.get("tie", false): return build_band(host, bullet)
	var c := _festival_context(host)
	var p: Vector2 = bullet.get("p", Vector2(bullet.get("x", 0), bullet.get("y", 0)))
	var origin := Vector2(_x(c, p.x), source_round(p.y) + float(c.y_snap))
	var transform := Transform2D(float(bullet.get("age", bullet.get("t", 0))) / 0.09, origin)
	var rows: Array = [[Rect2(-14, -9, 28, 18), "3f7d4c"], [Rect2(-12, -7, 24, 14), "9fd18d"], [Rect2(-4, -4, 8, 8), "3f7d4c"], [Rect2(-14, -1, 28, 3), "e8d9a8"]] if bullet.get("big", false) else [[Rect2(-9, -7, 18, 14), "4f8f5a"], [Rect2(-7, -5, 6, 4), "a8d79a"], [Rect2(1, 0, 6, 5), "a8d79a"], [Rect2(-3, -2, 6, 4), "2f5d3a"]]
	var out: Array = []
	for row in rows:
		var rectangle: Rect2 = row[0]
		_poly(out, [rectangle.position, Vector2(rectangle.end.x, rectangle.position.y), rectangle.end, Vector2(rectangle.position.x, rectangle.end.y)], Color(row[1]), "festival_bill", transform)
	return out

func _player_floor(host, p: Vector2) -> Dictionary:
	var runtime = _state(host, "world_three", null)
	if runtime != null and runtime is Object and runtime.has_method("below"): return runtime.below(host, p.x, p.y - 2)
	var selected: Dictionary = {}
	for surface in _surfaces(host, runtime):
		var row: Array = surface.row
		if p.x >= float(row[0]) and p.x <= float(row[1]) and float(row[2]) >= p.y - 4:
			if selected.is_empty() or float(row[2]) < float(selected.row[2]): selected = surface
	return selected

func draw_player_back(host, player = null) -> void:
	draw_commands(host, build_player_back(host, player))

func build_player_back(host, player = null) -> Array:
	if not supports(host.level_id): return []
	var p: Vector2 = player if player is Vector2 else host.player
	var floor := _player_floor(host, p)
	if floor.is_empty() or float(floor.row[2]) - p.y >= 400: return []
	var c := _festival_context(host)
	var out: Array = []
	_ellipse(out, Vector2(_x(c, p.x), float(floor.row[2]) - 2 + float(c.y_snap)), Vector2(maxf(16, 48 * (1 - (float(floor.row[2]) - p.y) / 600)), 6), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.28), "festival_player_shadow")
	return out

func draw_player_front(host, player = null) -> void:
	draw_commands(host, build_player_front(host, player))

func build_player_front(host, player = null) -> Array:
	if not supports(host.level_id): return []
	var p: Vector2 = player if player is Vector2 else host.player
	var c := _festival_context(host)
	var out: Array = []
	var floor := _player_floor(host, p)
	var floor_y := float(floor.row[2]) if not floor.is_empty() else p.y
	var character := str(_state(host, "character", "jp"))
	var height := float(host.meta.get("heights", {}).get(character, 180))
	if not str(_state(host, "power", "")).is_empty():
		_oval_arc(out, Vector2(p.x, floor_y - 2 + float(c.y_snap)), Vector2(40, 9), 0, 6.3, 3, Color(GOLD, 0.5 + 0.3 * sin(float(host.elapsed) / 0.12)), "festival_player_power")
	var y := p.y - height - 22 + float(c.y_snap)
	_rounded(out, Rect2(p.x - 19, y - 10, 38, 20), 6, GOLD, "festival_player_tag")
	out.append({"type": "text", "position": Vector2(p.x, y + 1), "text": "P1", "size": 12, "colour": Color("14243b"), "tag": "festival_player_name"})
	_poly(out, [Vector2(p.x - 6, y + 10), Vector2(p.x + 6, y + 10), Vector2(p.x, y + 16)], GOLD, "festival_player_arrow")
	return out

func draw_band(host, bullet: Dictionary) -> void:
	draw_commands(host, build_band(host, bullet))

func _oval_arc(out: Array, origin: Vector2, radii: Vector2, rotation: float, sweep: float, width: float, colour: Color, tag: String) -> void:
	var points := PackedVector2Array()
	var steps := maxi(1, int(ceilf(sweep * 16)))
	for i in range(steps + 1):
		var angle := sweep * i / steps
		points.append(origin + (Vector2(cos(angle), sin(angle)) * radii).rotated(rotation))
	out.append({"type": "line", "points": points, "colour": colour, "width": width, "tag": tag, "rotation": rotation, "center": origin, "radius": radii, "sweep": sweep})

func build_band(host, bullet: Dictionary) -> Array:
	if not supports(host.level_id): return []
	var c := _festival_context(host)
	var p: Vector2 = bullet.get("p", Vector2(bullet.get("x", 0), bullet.get("y", 0)))
	var time := float(bullet.get("age", bullet.get("t", 0)))
	var screen_x := p.x - float(c.camera.x)
	var colours: Array = TENT_COLOURS[posmod(int(floorf(screen_x / 50)), 6)]
	var origin := Vector2(_x(c, p.x), source_round(p.y) + float(c.y_snap))
	var rotation := time / 0.07
	var out: Array = []
	_oval_arc(out, origin, Vector2(13, 9), rotation, 6.3, 5, Color(colours[0]), "festival_wristband")
	_oval_arc(out, origin, Vector2(13, 9), rotation, 3, 2, Color(colours[1]), "festival_wristband_glint")
	_poly(out, [Vector2(9, -3), Vector2(16, -3), Vector2(16, 3), Vector2(9, 3)], Color("f5f1ea"), "festival_wristband_clasp", Transform2D(rotation, origin))
	return out

func draw_crate(host, crate: Dictionary) -> void:
	draw_commands(host, build_crate(host, crate))

func build_crate(host, crate: Dictionary) -> Array:
	if not supports(host.level_id) or crate.get("broken", false): return []
	var c := _festival_context(host)
	var p: Vector2 = crate.get("p", Vector2(crate.get("x", 0), crate.get("fy", c.ground)))
	# Source random draw-time shake is intentionally replaced by an explicit
	# simulation snapshot offset, default zero. No renderer RNG or state write.
	var origin := Vector2(_x(c, p.x) + float(crate.get("visual_jitter", 0)), p.y - 64 + float(c.y_snap))
	var out: Array = []
	for row in [[Rect2(-34, 0, 68, 64), "7a5226"], [Rect2(-31, 3, 62, 58), "c48a4a"], [Rect2(-31, 26, 62, 6), "a8743c"], [Rect2(-28, 6, 24, 4), "e0b070"], [Rect2(-14, 10, 28, 28), "f5f1ea"]]: _rect(out, Rect2(origin + row[0].position, row[0].size), Color(row[1]), "festival_crate")
	out.append({"type": "text", "position": origin + Vector2(0, 25), "text": "?", "size": 22, "colour": Color("2d6a4f"), "tag": "festival_crate_label"})
	return out

func draw_item(host, item: Dictionary) -> void:
	draw_commands(host, build_item(host, item))

func build_item(host, item: Dictionary) -> Array:
	if not supports(host.level_id): return []
	var time := float(item.get("age", item.get("t", 0)))
	if time > 9 and int(time / 0.12) % 2: return []
	var c := _festival_context(host)
	var p: Vector2 = item.get("p", Vector2(item.get("x", 0), item.get("y", 0)))
	var origin := Vector2(_x(c, p.x), source_round(p.y + sin(time / 0.15) * 3) + float(c.y_snap))
	var out: Array = []
	_ellipse(out, origin, Vector2.ONE * (24 + sin(time / 0.12) * 2), Color(1, 1, 1, 0.25), "festival_item_glow")
	match str(item.give):
		"wellies":
			for row in [[Rect2(-10, -18, 14, 26), "2f9a4a"], [Rect2(-10, 2, 24, 10), "2f9a4a"], [Rect2(-8, -16, 4, 18), "5fcf74"], [Rect2(-12, 10, 28, 4), "1d5f2e"]]: _rect(out, Rect2(origin + row[0].position, row[0].size), Color(row[1]), "festival_welly")
		"heart":
			for r in HEART_PIXELS.size():
				for col in 7:
					if HEART_PIXELS[r][col] == "X": _rect(out, Rect2(origin + Vector2(-14 + col * 4, -10 + r * 4), Vector2(4, 4)), Color("ffb3b3" if r == 1 and col == 1 else "e23b3b"), "festival_heart")
		_:
			_border(out, Rect2(origin - Vector2(20, 20), Vector2(40, 40)), 10, Color("2d6a4f" if item.give == "split" else "14243b"), GOLD, 3, "festival_power")
			out.append({"type": "text", "position": origin + Vector2(0, 1), "text": "x3" if item.give == "split" else "DD", "size": 15, "colour": GOLD, "tag": "festival_power_label"})
	return out

func draw_coin(host, coin: Dictionary) -> void:
	draw_commands(host, build_coin(host, coin))

func build_coin(host, coin: Dictionary) -> Array:
	if not supports(host.level_id): return []
	var time := float(coin.get("age", coin.get("t", 0)))
	if time > 9 and int(time / 0.1) % 2: return []
	var c := _festival_context(host)
	var p: Vector2 = coin.get("p", Vector2(coin.get("x", 0), coin.get("y", 0)))
	var k := 1.3
	var w := float([12, 9, 4, 9][posmod(int(floorf(time / 0.06)), 4)]) * k
	var h := 12 * k
	var out: Array = []
	for row in [[Rect2(-w / 2 - k, -h / 2 - k, w + 2 * k, h + 2 * k), "7a5410"], [Rect2(-w / 2, -h / 2, w, h), "f4c542"]]:
		_rect(out, Rect2(_x(c, p.x + row[0].position.x), source_round(p.y + row[0].position.y) + float(c.y_snap), source_round(row[0].size.x), source_round(row[0].size.y)), Color(row[1]), "festival_coin")
	if w > 5 * k:
		for row in [[Rect2(-w / 2 + k, -h / 2 + k, 2 * k, 5 * k), "fff1a8"], [Rect2(-k, -3 * k, 2 * k, 6 * k), "c99a1d"]]:
			_rect(out, Rect2(_x(c, p.x + row[0].position.x), source_round(p.y + row[0].position.y) + float(c.y_snap), source_round(row[0].size.x), source_round(row[0].size.y)), Color(row[1]), "festival_coin_glint")
	return out

func build_front(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var c := _festival_context(host)
	var out: Array = []
	for decor in c.level.get("decor", []):
		if decor[4] == "front": _decor_cut(out, c, decor)
	var elapsed := float(_state(runtime, "elapsed", host.elapsed))
	var boss := _boss(host, runtime)
	if float(_state(runtime, "cheer", 0)) > 0 and not boss.is_empty():
		out.append({"type": "outlined_text", "position": Vector2(_x(c, float(boss.x)), float(boss.fy) - 300 + float(c.y_snap)), "text": ["Ooh!", "Yes!", "Go on!"][int(elapsed / 0.7) % 3], "size": 18, "colour": Color("ffd23f"), "outline": Color("0e1726"), "outline_size": 4.5, "tag": "festival_cheer"})
	if elapsed < 9 and str(_state(host, "mode", "play")) == "play":
		out.append({"type": "outlined_text", "position": Vector2(c.camera.x + c.width / 2 - 40, c.view.position.y + 112 + c.y_snap), "text": str(c.l3.get("hint", "")), "size": 11, "colour": Color("f5f1ea"), "outline": Color("0e1726"), "outline_size": 3, "tag": "festival_hint"})
	return out

func build_hud(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var b := _boss(host, runtime)
	if not b.is_empty() and b.state != "down":
		_border(out, Rect2(266, 496, 428, 26), 8, Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.85), Color("f5f1ea"), 2, "festival_boss_health_back")
		_rounded(out, Rect2(270, 500, 420 * maxf(0, float(b.hp) / maxf(1, float(b.max))), 18), 6, GOLD if float(b.get("dizzy", 0)) > 0 else Color("e23b3b"), "festival_boss_health")
		out.append({"type": "festival_left_text", "position": Vector2(278, 484), "text": str(b.name), "size": 14, "colour": Color("f5f1ea"), "outline": Color("0e1726"), "tag": "festival_boss_name"})
	# polish.js intentionally gives door/lift/stairs the same iris since Nov9.
	out.append_array(super.build_hud(host, runtime))
	return out

static func tint_pixel(pixel: Color, kind: String, flash: bool = false) -> Color:
	var r := float(pixel.r8)
	var g := float(pixel.g8)
	var b := float(pixel.b8)
	if r > g + 18 and g > b:
		var sh: Vector3 = {"seller": Vector3(0.55, 1.15, 0.6), "bailiff": Vector3(0.75, 0.8, 0.95), "tout": Vector3(1.05, 0.55, 1.25)}.get(kind, Vector3.ONE)
		if not kind.is_empty():
			pixel.r = _clamped_byte(r * sh.x + b * 0.2) / 255.0
			pixel.g = _clamped_byte(g * sh.y) / 255.0
			pixel.b = _clamped_byte(b * sh.z + r * 0.25) / 255.0
	if flash:
		pixel.r = _clamped_byte(pixel.r8 * 0.3 + 255 * 0.7) / 255.0
		pixel.g = _clamped_byte(pixel.g8 * 0.3 + 255 * 0.7) / 255.0
		pixel.b = _clamped_byte(pixel.b8 * 0.3 + 255 * 0.7) / 255.0
	return pixel

static func _clamped_byte(value: float) -> float:
	# Uint8ClampedArray uses nearest with ties to even, unlike Math.round.
	value = clampf(value, 0, 255)
	var lower := floorf(value)
	if value - lower == 0.5: return lower if int(lower) % 2 == 0 else lower + 1
	return source_round(value)

func _festival_variant(command: Dictionary, original: Texture2D) -> Texture2D:
	var source: Rect2 = command.get("variant_source", command.source)
	var key := "%d:%s:%s:%s" % [original.get_instance_id(), source, command.get("filter", ""), command.get("flash", false)]
	if _festival_variants.has(key): return _festival_variants[key]
	var frame := original.get_image().get_region(Rect2i(source))
	frame.convert(Image.FORMAT_RGBA8)
	for y in frame.get_height():
		for x in frame.get_width():
			var pixel := frame.get_pixel(x, y)
			if pixel.a <= 0: continue
			if command.get("filter", "") == "mid_prop":
				# CSS brightness(.9) then saturate(.92), in sRGB channels.
				var rgb := Vector3(pixel.r, pixel.g, pixel.b) * 0.9
				var gray := rgb.dot(Vector3(0.213, 0.715, 0.072))
				rgb = rgb * 0.92 + Vector3.ONE * gray * 0.08
				pixel = Color(rgb.x, rgb.y, rgb.z, pixel.a)
			else: pixel = tint_pixel(pixel, str(command.get("filter", "")), bool(command.get("flash", false)))
			frame.set_pixel(x, y, pixel)
	var texture := ImageTexture.create_from_image(frame)
	_festival_variants[key] = texture
	return texture

func clear_cache() -> void:
	super.clear_cache()
	_festival_variants.clear()

func draw_commands(host, commands: Array) -> void:
	for command in commands:
		match command.type:
			"festival_texture":
				var texture: Texture2D = command.get("texture", host.images.get(command.get("key", "")))
				var source: Rect2 = command.source
				if not str(command.get("filter", "")).is_empty() or bool(command.get("flash", false)):
					# Use full un-clipped frame for variants so tent emergence
					# cannot quantize a fractional clip or pollute another frame.
					var full: Dictionary = command.duplicate()
					if command.has("unclipped_rect"):
						var ratio: Vector2 = command.source.size / command.rect.size
						var delta: Vector2 = command.rect.position - command.unclipped_rect.position
						if command.flip_h: delta.x = command.unclipped_rect.end.x - command.rect.end.x
						full.source = Rect2(command.source.position - delta * ratio, command.unclipped_rect.size * ratio)
					texture = _festival_variant(full, texture)
					source.position -= full.source.position
				var rectangle: Rect2 = command.rect
				if command.flip_h: rectangle.size.x = -rectangle.size.x
				host.draw_texture_rect_region(_nearest(texture), rectangle, source, Color(1, 1, 1, command.alpha))
			"festival_left_text":
				var baseline: Vector2 = command.position + Vector2(0, (host.font.get_ascent(command.size) - host.font.get_descent(command.size)) / 2)
				host.draw_string_outline(host.font, baseline, command.text, HORIZONTAL_ALIGNMENT_LEFT, -1, command.size, 2, command.outline)
				host.draw_string(host.font, baseline, command.text, HORIZONTAL_ALIGNMENT_LEFT, -1, command.size, command.colour)
			_: super.draw_commands(host, [command])
