extends RefCounted
## Source-grounded World 2 Car park painter. Coordinates are absolute world
## pixels; times are seconds. Host applies the bottom-anchored 1.3x camera.
## This renderer never changes physics, random generators, pickups or progress.
## Only 2-1 is supported. Other supermarket stages remain explicit previews.

const HEIGHT := 540.0
const WIDTH := 960.0
const LAMP_RANGES := [[0.094, 0.159], [0.499, 0.566], [0.906, 0.970]]
const INK := Color("100b1a")
const GOLD := Color("f4c542")
var _sprite_variants: Dictionary = {}
var _filtered_textures: Dictionary = {}

func supports(id: String) -> bool:
	return id == "2-1"

func draw_sky(host, runtime = null) -> void:
	draw_commands(host, build_sky(host, runtime))

func draw_level(host, runtime = null) -> void:
	draw_commands(host, build_level(host, runtime))

func draw_mid(host, runtime = null, pickups: Callable = Callable()) -> void:
	draw_commands(host, build_mid(host, runtime))
	if pickups.is_valid(): pickups.call()

func draw_enemy(host, bot: Dictionary) -> bool:
	if not supports(host.level_id): return false
	draw_commands(host, build_enemy(host, bot))
	return true

func draw_player_back(_host, _player = null) -> void:
	# 2-1 has no player trolley. Do not add the 2-4 ride to parking decks.
	pass

func draw_player_front(_host, _player = null) -> void:
	pass

func draw_front(host, runtime = null) -> void:
	draw_commands(host, build_front(host, runtime))

func draw_hud(host, runtime = null) -> void:
	# Called last, after resetting the host to logical 960x540 UI coordinates.
	draw_commands(host, build_hud(host, runtime))

static func source_round(value: float) -> float:
	return floorf(value + 0.5)

func _state(runtime, key: String, fallback):
	if runtime == null: return fallback
	var value = runtime.get(key)
	return fallback if value == null else value

func _context(host) -> Dictionary:
	return {"images": host.images, "level": host.level, "camera": host.camera,
		"width": float(host.view_width()), "ground": float(host.meta.get("ground", 482)),
		"view": Rect2(host.camera.x, host.view_top(), host.view_width(), host.camera.y + HEIGHT - host.view_top()),
		"y_snap": host.camera.y - source_round(host.camera.y)}

func _x(c: Dictionary, x: float) -> float:
	return float(c.camera.x) + source_round(x - float(c.camera.x))

func _size(c: Dictionary, key: String) -> Vector2:
	return c.images[key].get_size() if c.images.has(key) else Vector2.ZERO

func crop_region(host, key: String, fractions: Rect2) -> Rect2:
	if not host.images.has(key): return Rect2()
	var size: Vector2 = host.images[key].get_size()
	# Source rounds the width/height independently of the starting pixel.
	return Rect2(source_round(size.x * fractions.position.x), source_round(size.y * fractions.position.y),
		source_round(size.x * fractions.size.x), source_round(size.y * fractions.size.y))

func _crop(c: Dictionary, key: String, x0: float, y0: float, x1: float, y1: float) -> Rect2:
	var size := _size(c, key)
	return Rect2(source_round(size.x * x0), source_round(size.y * y0), source_round(size.x * (x1 - x0)), source_round(size.y * (y1 - y0)))

func _texture(out: Array, c: Dictionary, key: String, rect: Rect2, tag: String, source: Rect2 = Rect2(), flip: bool = false, extra: Dictionary = {}) -> void:
	if not c.images.has(key) or not rect.has_area() or not rect.intersects(c.view): return
	if not source.has_area(): source = Rect2(Vector2.ZERO, _size(c, key))
	var command := {"type": "texture", "key": key, "rect": rect, "source": source, "flip_h": flip, "alpha": 1.0, "tag": tag}
	command.merge(extra)
	out.append(command)

func _rect(out: Array, rectangle: Rect2, colour: Color, tag: String) -> void:
	if rectangle.has_area(): out.append({"type": "rect", "rect": rectangle, "colour": colour, "tag": tag})

func _ellipse(out: Array, center: Vector2, radius: Vector2, colour: Color, tag: String) -> void:
	out.append({"type": "ellipse", "center": center, "radius": radius, "colour": colour, "tag": tag})

func _tile_row(out: Array, c: Dictionary, key: String, source: Rect2, factor: float, y: float, tag: String, height: float = 0) -> void:
	if not source.has_area(): return
	var width := source_round(source.size.x * height / source.size.y) if height > 0 else source.size.x
	var hh := height if height > 0 else source.size.y
	var scroll := float(c.camera.x) * factor
	var index := int(floorf(scroll / width))
	while index * width - scroll < float(c.width):
		_texture(out, c, key, Rect2(float(c.camera.x) + source_round(index * width - scroll), float(c.camera.y) + source_round(y), width, hh), tag, source, index % 2 != 0, {"index": index, "factor": factor})
		index += 1

func _dusk(out: Array, c: Dictionary) -> void:
	var stops := [-10.0, 120.0, 301.0, 409.6, 482.0, 550.0]
	var colours := [Color("24345e"), Color("24345e"), Color("4f6aa0"), Color("e58fa0"), Color("f7c08a"), Color("f7c08a")]
	for i in range(stops.size() - 1):
		out.append({"type": "gradient", "rect": Rect2(c.camera.x - 10, c.camera.y + stops[i], c.width + 20, stops[i + 1] - stops[i]),
			"colours": PackedColorArray([colours[i], colours[i], colours[i + 1], colours[i + 1]]), "tag": "dusk_gradient"})

func build_sky(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	var cam: Vector2 = c.camera
	if int(_state(runtime, "scene_index", 0)) == 0 and c.images.has("topdeck"):
		var size := _size(c, "topdeck")
		var top := source_round(float(c.ground) - 50 - 0.62 * size.y - cam.y)
		_rect(out, Rect2(cam.x - 10, cam.y - 10, c.width + 20, top + 12), Color("3b1f63"), "topdeck_fill")
		_tile_row(out, c, "topdeck", _crop(c, "topdeck", 0.164, 0, 0.493, 0.3), 0.05, top, "topdeck_sky")
		_tile_row(out, c, "topdeck", _crop(c, "topdeck", 0.164, 0.3, 0.493, 0.47), 0.2, top + source_round(0.3 * size.y), "topdeck_town")
		_tile_row(out, c, "topdeck", _crop(c, "topdeck", 0, 0.47, 1, 1), 1, top + source_round(0.47 * size.y), "topdeck_deck")
		var index := int(floorf(cam.x / size.x))
		while index * size.x - cam.x < float(c.width):
			for lamp in LAMP_RANGES.size():
				var key := "lamp-td-%d" % lamp
				var lamp_size := _size(c, key)
				var mirror := index % 2 != 0
				var x0: float = size.x - source_round(LAMP_RANGES[lamp][0] * size.x) - lamp_size.x if mirror else source_round(LAMP_RANGES[lamp][0] * size.x)
				_texture(out, c, key, Rect2(_x(c, index * size.x + x0), cam.y + top + source_round(0.18 * size.y), lamp_size.x, lamp_size.y), "topdeck_lamp_head", Rect2(), mirror, {"index": index, "lamp": lamp})
			index += 1
		return out
	_dusk(out, c)
	# All shipped 2-1 assets contain topdeck. Missing content stays visible as a
	# dusk fallback rather than synthesizing an unrelated parking screenshot.
	if int(_state(runtime, "scene_index", 0)) == 0: return out
	var frontage := _crop(c, "carpark", 0, 0, 0.262, 1)
	if not frontage.has_area(): return out
	var y := source_round(float(c.ground) - 150 - cam.y * 0.25 - 0.585 * frontage.size.y)
	_rect(out, Rect2(cam.x - 10, cam.y - 10, c.width + 20, y + 2), Color("1e2738"), "surface_sky_fill")
	var sky := _crop(c, "carpark", 0, 0, 1, 0.11)
	if sky.has_area():
		# polish.js para tiles to canvas width960, not world width738, and
		# rounds the initial offset once rather than rounding every tile.
		var width := source_round(sky.size.x * 80 / sky.size.y)
		var scroll := cam.x * 0.03 + 3 * float(_state(runtime, "elapsed", host.elapsed))
		var first := int(floorf(scroll / width))
		var offset := source_round(scroll - first * width)
		var index := 0
		while -offset + index * width < WIDTH:
			_texture(out, c, "carpark", Rect2(cam.x - offset + index * width, cam.y + y - 66, width, 80), "surface_sky_band", sky, (first + index) % 2 != 0, {"index": first + index})
			index += 1
	_tile_row(out, c, "carpark", frontage, 0.3, y, "surface_frontage")
	return out

func build_level(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	var cam: Vector2 = c.camera
	var ground := float(c.ground)
	var ys := float(c.y_snap)
	var top_deck := int(_state(runtime, "scene_index", 0)) == 0
	var scenes: Array = c.level.get("scenes", [])
	var scene_x := float(scenes[0][0]) if not scenes.is_empty() else 7600.0
	if top_deck:
		if scene_x + 240 > cam.x and scene_x - 160 < cam.x + c.width:
			var size := _size(c, "lift")
			_rect(out, Rect2(_x(c, scene_x - 112), ground - 4 + ys, size.x + 8, 8), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.35), "lift_shadow")
			_texture(out, c, "lift", Rect2(_x(c, scene_x - 108), ground - size.y + 2 + ys, size.x, size.y), "lift")
	else:
		_rect(out, Rect2(cam.x - 10, ground + ys, c.width + 20, cam.y + HEIGHT + 20 - ground), Color("3a4152"), "surface_floor")
		var line_x := floorf(cam.x / 220) * 220
		while line_x < cam.x + c.width + 220:
			_rect(out, Rect2(_x(c, line_x), ground + 4 + ys, 6, 40), Color("e9edf2"), "parking_bay_line")
			line_x += 220
		_rect(out, Rect2(cam.x - 10, ground + 48 + ys, c.width + 20, 4), GOLD, "parking_yellow_line")
		_rect(out, Rect2(cam.x - 10, ground + ys, c.width + 20, 3), Color("4a5268"), "parking_floor_edge")
		var entrance := _crop(c, "carpark", 0.262, 0.08, 0.8, 0.585)
		var doors := float(c.level.get("doors", 15580))
		if entrance.has_area() and doors + 700 > cam.x and doors - 330 < cam.x + c.width:
			var h := entrance.size.y * 1.4
			var ex := _x(c, doors - 330)
			_texture(out, c, "carpark", Rect2(ex, source_round(ground + 6 - h) + ys, source_round(entrance.size.x * 1.4), source_round(h)), "shop_entrance", entrance)
			_rect(out, Rect2(ex - 24, ground - h + ys, 30, h), Color("2b3850"), "entrance_side")
			_rect(out, Rect2(ex - 20, ground - h + ys, 4, h), Color("3a4a66"), "entrance_side_highlight")
	# Deck lamps already live in the painting. Never double them with props.
	if not top_deck:
		for lamp_x in c.level.get("lamps", []):
			var lx := float(lamp_x)
			if lx < scene_x or lx + 120 <= cam.x or lx - 60 >= cam.x + c.width: continue
			var size := _size(c, "lamp")
			_texture(out, c, "lamp", Rect2(_x(c, lx + 35), ground - size.y + ys, size.x, size.y), "surface_lamp")
			out.append({"type": "radial", "center": Vector2(cam.x + source_round(lx - cam.x + 103), ground - 470 + 30 + ys), "radii": [4.0, 120.0],
				"colours": [Color(1, 243 / 255.0, 176 / 255.0, 0.35), Color(1, 243 / 255.0, 176 / 255.0, 0)], "tag": "lamp_glow"})
	for bay in c.level.get("bays", []):
		if (float(bay) < scene_x) != top_deck: continue
		var size := _size(c, "shelter")
		_texture(out, c, "shelter", Rect2(_x(c, float(bay) + 30), ground - size.y + 4 + ys, size.x, size.y), "trolley_shelter")
	for car in c.level.get("cars", []):
		if (float(car[0]) < scene_x) != top_deck: continue
		var key := "car-%s-%d" % [str(car[2]), int(car[1]) % 2]
		if not c.images.has(key): key = "car-%s-0" % str(car[2])
		var size := _size(c, key)
		_texture(out, c, key, Rect2(_x(c, float(car[0])), ground - size.y + 4 + ys, size.x, size.y), "parked_car", Rect2(), false, {"world_x": float(car[0])})
	return out

func build_mid(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	for entity in _state(runtime, "entities", []):
		if entity.get("k", "") != "trolley" or entity.get("dead", false): continue
		var p: Vector2 = entity.get("p", Vector2(entity.get("x", 0), entity.get("fy", 482)))
		var v: Vector2 = entity.get("v", Vector2(entity.get("vx", 0), 0))
		var center := Vector2(_x(c, p.x), p.y - 52 + float(c.y_snap))
		if not Rect2(center - Vector2(68, 60), Vector2(136, 120)).intersects(c.view): continue
		out.append_array(build_trolley(center, v.x < 0, sin(float(entity.get("t", 0)) / 0.05) * 0.03))
	return out

func build_trolley(center: Vector2, flip: bool = false, angle: float = 0) -> Array:
	# Original120x106 trolley art, anchored60x52, including wire mesh.
	var out: Array = []
	var steel := Color("c7d0dc")
	var dark := Color("6f7c8f")
	var transform := Transform2D(angle, center) * Transform2D(0, Vector2(60 if flip else -60, -52)) * Transform2D(0, Vector2(-1 if flip else 1, 1), 0, Vector2.ZERO)
	_poly(out, [Vector2(14, 14), Vector2(112, 14), Vector2(104, 66), Vector2(24, 66)], Color(199 / 255.0, 208 / 255.0, 220 / 255.0, 0.18), "trolley_basket", transform)
	for i in 9:
		var t := i / 8.0
		_line(out, Vector2(14 + 98 * t, 14), Vector2(24 + 80 * t, 66), steel, 2, "trolley_mesh", transform)
	for j in 5:
		var t := j / 4.0
		_line(out, Vector2(14 + 10 * t, 14 + 52 * t), Vector2(112 - 8 * t, 14 + 52 * t), steel, 2, "trolley_mesh", transform)
	for row in [[Rect2(12, 11, 102, 4), Color("eef2f7"), "rim"], [Rect2(22, 66, 84, 4), dark, "basket_base"], [Rect2(4, 6, 4, 64), steel, "handle"], [Rect2(0, 2, 12, 10), Color("2d6a4f"), "grip"], [Rect2(2, 3, 8, 3), Color("3f8f63"), "grip_highlight"]]:
		var rect: Rect2 = row[0]
		_poly(out, [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)], row[1], "trolley_" + row[2], transform)
	var frame := PackedVector2Array([Vector2(8, 70), Vector2(28, 92), Vector2(104, 92), Vector2(106, 70)])
	out.append({"type": "line", "points": transform * frame, "colour": dark, "width": 4.0, "tag": "trolley_frame"})
	for wx in [28, 98]:
		_ellipse(out, transform * Vector2(wx, 98), Vector2(8, 8), Color("1d2433"), "trolley_wheel")
		_ellipse(out, transform * Vector2(wx, 98), Vector2(3, 3), Color("9aa5b8"), "trolley_hub")
	return out

func _poly(out: Array, points: Array, colour: Color, tag: String, transform: Transform2D = Transform2D.IDENTITY) -> void:
	out.append({"type": "polygon", "points": transform * PackedVector2Array(points), "colour": colour, "tag": tag})

func _line(out: Array, from: Vector2, to: Vector2, colour: Color, width: float, tag: String, transform: Transform2D = Transform2D.IDENTITY) -> void:
	out.append({"type": "line", "points": transform * PackedVector2Array([from, to]), "colour": colour, "width": width, "tag": tag})

func build_enemy(host, bot: Dictionary) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	var p: Vector2 = bot.p
	if p.x - c.camera.x < -150 or p.x - c.camera.x > c.width + 150: return out
	var x := _x(c, p.x)
	var feet := p.y + float(c.y_snap)
	_ellipse(out, Vector2(x, feet - 2), Vector2(34, 6), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.25), "bot_shadow")
	var animation := "pop" if bot.state == "pop" else ("throw" if bot.state == "throw" else "walk")
	var move := int(bot.get("visual_move", 0))
	var frame := mini(3, int(float(bot.t) / 0.11)) if animation != "walk" else (int(float(bot.get("stride", 0)) / 9) % 6 if move else 5)
	var alpha := maxf(0, 1 - (float(bot.get("gone", 0)) - 0.8) / 0.5) if bot.state == "pop" and float(bot.get("gone", 0)) > 0.8 else 1.0
	var big := bool(bot.get("big", false))
	var sheet: Dictionary = host.meta.get("sheets", {}).get("bot", {})
	var texture: Texture2D = host.images.get("bot")
	if texture == null and host.get("sheets") != null: texture = host.sheets.get("bot")
	if texture != null and not sheet.is_empty():
		var anim: Dictionary = sheet.anims[animation]
		var source := Rect2(frame * float(sheet.w), float(anim.row) * float(sheet.h), sheet.w, sheet.h)
		var scale := 1.66 if big else 1.0
		var width := float(sheet.w) * scale
		var top := source_round(p.y - (float(sheet.h) - 3) * scale) + float(c.y_snap)
		var face := -int(bot.face) if big or animation != "walk" or not move else -move
		out.append({"type": "bot_texture", "texture": texture, "rect": Rect2(x + source_round(width / 2) - source_round(width) if face < 0 else x - source_round(width / 2), top, source_round(width), source_round(float(sheet.h) * scale)),
			"source": source, "flip_h": face < 0, "alpha": alpha, "big": big, "flash": float(bot.get("flash", 0)) > 0, "tag": "security_bot" if big else "bot_sprite"})
		if big and bot.state != "pop":
			var hy := top + 4
			_rect(out, Rect2(x - 30, hy + 8, 60, 14), Color("14243b"), "security_cap")
			_rect(out, Rect2(x - int(bot.face) * 26 - 18, hy + 18, 36, 6), Color("14243b"), "security_peak")
			_rect(out, Rect2(x - 6, hy + 11, 12, 7), GOLD, "security_badge")
			_rounded(out, Rect2(x - 46, hy - 16, 92, 10), 4, Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.8), "security_health_back")
			_rounded(out, Rect2(x - 44, hy - 14, 88 * maxf(0, float(bot.hp) / maxf(1, float(bot.get("max_hp", 24)))), 6), 3, Color("e23b3b"), "security_health")
	if bot.state == "drone":
		var y := feet - 118
		var spin := absf(sin(float(host.elapsed) / 0.03) * 34)
		_rect(out, Rect2(x - 3, y, 6, 16), Color("3a4258"), "drone_stem")
		_rect(out, Rect2(float(c.camera.x) + source_round(p.x - float(c.camera.x) - spin), y - 2, source_round(spin * 2), 4), Color(200 / 255.0, 210 / 255.0, 225 / 255.0, 0.85), "drone_propeller")
		_rect(out, Rect2(x - 4, feet - 12, 8, 6), Color("e23b3b"), "drone_light")
		_ellipse(out, Vector2(x, float(bot.get("base_y", p.y + 200)) - 2 + float(c.y_snap)), Vector2(26, 5), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.2), "drone_ground_shadow")
	if bot.get("type", bot.get("kind", "")) == "cart" and bot.state != "pop":
		out.append_array(build_trolley(Vector2(float(c.camera.x) + source_round(p.x - float(c.camera.x) - 58 + int(bot.face) * 18) + 60, feet - 52), int(bot.face) < 0))
	if bot.get("type", bot.get("kind", "")) == "flat" and bot.state != "pop":
		_rect(out, Rect2(x - 3, feet - 128, 6, 6), Color("e23b3b"), "flat_bill_marker")
	return out

func build_front(host, _runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	var scroll := float(c.camera.x) * 1.3
	for index in range(int(floorf(scroll / 2300)) - 1, int(floorf((scroll + float(c.width)) / 2300)) + 2):
		var sx := source_round(index * 2300 + 900 - scroll)
		if sx < -46 or sx > float(c.width) + 20: continue
		var x := float(c.camera.x) + sx
		var top := HEIGHT - 46 + float(c.y_snap)
		var colour := Color(16 / 255.0, 22 / 255.0, 36 / 255.0, 0.88)
		_rect(out, Rect2(x, top + 8, 26, 46), colour, "foreground_bollard")
		_ellipse(out, Vector2(x + 13, top + 8), Vector2(13, 6), colour, "foreground_bollard_cap")
		_rect(out, Rect2(x + 4, top + 10, 3, 46), Color(60 / 255.0, 74 / 255.0, 104 / 255.0, 0.6), "foreground_bollard_highlight")
	return out

static func ease_iris(k: float) -> float:
	return 4 * k * k * k if k < 0.5 else 1 - pow(-2 * k + 2, 3) / 2

func build_hud(host, runtime = null) -> Array:
	var out: Array = []
	if not supports(host.level_id) or not bool(_state(runtime, "wiping", false)): return out
	var time := float(_state(runtime, "wipe_elapsed", 0))
	if time < 0 or time >= 2.17: return out
	var closure := ease_iris(time / 0.52) if time < 0.52 else (1.0 if time < 1.57 else 1 - ease_iris((time - 1.57) / 0.6))
	if closure >= 1:
		_rect(out, Rect2(0, 0, WIDTH, HEIGHT), INK, "wipe_cover")
	elif closure > 0:
		if str(_state(runtime, "wipe_kind", "lift")) == "fade":
			_rect(out, Rect2(0, 0, WIDTH, HEIGHT), Color(INK, closure), "wipe_cover")
		else:
			var default_focus := Vector2(clampf((float(host.player.x) - float(host.camera.x)) * 1.3, WIDTH * 0.22, WIDTH * 0.78), HEIGHT * 0.6)
			var focus: Vector2 = _state(runtime, "wipe_focus_start" if time < 1.57 else "wipe_focus_end", default_focus)
			var far := maxf(maxf(focus.length(), Vector2(WIDTH - focus.x, focus.y).length()), maxf(Vector2(focus.x, HEIGHT - focus.y).length(), Vector2(WIDTH - focus.x, HEIGHT - focus.y).length()))
			var radius := far / 0.7 * (1 - closure)
			out.append({"type": "radial", "center": focus, "radii": [radius * 0.7, radius * 0.865, radius, far * 2],
				"colours": [Color(INK, 0), Color(INK, 0.55), INK, INK], "tag": "wipe_iris"})
			_rect(out, Rect2(0, 0, WIDTH, HEIGHT), Color(INK, closure * closure * 0.35), "wipe_dim")
	var label := str(_state(runtime, "wipe_label", "Ground floor"))
	if not label.is_empty() and time > 0.42 and time < 1.54:
		var alpha := (time - 0.42) / 0.22 if time < 0.64 else (1 - (time - 1.32) / 0.22 if time > 1.32 else 1.0)
		var k := ease_iris(clampf(alpha, 0, 1))
		var size := 46.0
		var text_width: float = host.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
		if text_width > WIDTH * 0.84: size *= WIDTH * 0.84 / text_width
		text_width = host.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
		var cy := HEIGHT * 0.47 + (1 - k) * (12 if time < 1.32 else -12)
		out.append({"type": "text", "position": Vector2(WIDTH / 2, cy + 4), "text": label, "size": int(size), "colour": Color(0, 0, 0, 0.45 * k), "tag": "wipe_label_shadow"})
		out.append({"type": "text", "position": Vector2(WIDTH / 2, cy), "text": label, "size": int(size), "colour": Color(Color("ffd23f"), k), "tag": "wipe_label"})
		var line_width := minf(WIDTH * 0.6, text_width * 0.7 + 40) * minf(1, k * 1.4)
		_rect(out, Rect2(source_round(WIDTH / 2 - line_width / 2), source_round(cy + size * 0.72), source_round(line_width), 3), Color(1, 210 / 255.0, 63 / 255.0, 0.7 * k), "wipe_label_rule")
	return out

func _rounded(out: Array, rect: Rect2, radius: float, colour: Color, tag: String) -> void:
	if rect.has_area(): out.append({"type": "rounded", "rect": rect, "radius": radius, "colour": colour, "tag": tag})

func _variant(command: Dictionary) -> Texture2D:
	var original: Texture2D = command.texture
	var key := "%d:%s:%s:%s" % [original.get_instance_id(), command.source, command.big, command.flash]
	if _sprite_variants.has(key): return _sprite_variants[key]
	var frame := original.get_image().get_region(Rect2i(command.source))
	frame.convert(Image.FORMAT_RGBA8)
	var stripe_y := int(source_round(frame.get_height() * 0.55))
	for y in frame.get_height():
		for x in frame.get_width():
			var colour := frame.get_pixel(x, y)
			if colour.a <= 0: continue
			var alpha := colour.a
			if command.big:
				colour = colour.lerp(Color("1c2c56"), 0.5)
				if y >= stripe_y and y < stripe_y + 7: colour = colour.lerp(GOLD, 0.85)
			if command.flash: colour = colour.lerp(Color.WHITE, 0.7)
			colour.a = alpha
			frame.set_pixel(x, y, colour)
	var texture := ImageTexture.create_from_image(frame)
	_sprite_variants[key] = texture
	return texture

func clear_cache() -> void:
	_sprite_variants.clear()
	_filtered_textures.clear()

func _nearest(texture: Texture2D) -> CanvasTexture:
	var key := texture.get_instance_id()
	if not _filtered_textures.has(key):
		var canvas := CanvasTexture.new()
		canvas.diffuse_texture = texture
		canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_filtered_textures[key] = canvas
	return _filtered_textures[key]

func draw_commands(host, commands: Array) -> void:
	for command in commands:
		match command.type:
			"texture", "bot_texture":
				var texture: Texture2D = host.images[command.key] if command.type == "texture" else command.texture
				var source: Rect2 = command.source
				if command.type == "bot_texture" and (command.big or command.flash):
					texture = _variant(command)
					source = Rect2(Vector2.ZERO, texture.get_size())
				var dest: Rect2 = command.rect
				if command.flip_h:
					# Godot mirrors inside the original left/top bounds.
					dest.size.x = -dest.size.x
				host.draw_texture_rect_region(_nearest(texture), dest, source, Color(1, 1, 1, command.alpha))
			"rect": host.draw_rect(command.rect, command.colour)
			"polygon": host.draw_colored_polygon(command.points, command.colour)
			"line": host.draw_polyline(command.points, command.colour, command.width)
			"ellipse":
				var points := PackedVector2Array()
				for i in 64: points.append(command.center + Vector2(cos(i * TAU / 64), sin(i * TAU / 64)) * command.radius)
				host.draw_colored_polygon(points, command.colour)
			"gradient":
				var r: Rect2 = command.rect
				host.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), command.colours)
			"rounded":
				var style := StyleBoxFlat.new()
				style.bg_color = command.colour
				style.set_corner_radius_all(int(command.radius))
				style.corner_detail = 12
				host.draw_style_box(style, command.rect)
			"radial": _draw_radial(host, command)
			"text":
				var text_size: Vector2 = host.font.get_string_size(command.text, HORIZONTAL_ALIGNMENT_LEFT, -1, command.size)
				var baseline: Vector2 = command.position + Vector2(-text_size.x / 2, (host.font.get_ascent(command.size) - host.font.get_descent(command.size)) / 2)
				host.draw_string(host.font, baseline, command.text, HORIZONTAL_ALIGNMENT_LEFT, -1, command.size, command.colour)

func _draw_radial(host, command: Dictionary) -> void:
	var radii: Array = command.radii
	var colours: Array = command.colours
	var center: Vector2 = command.center
	if colours[0].a > 0:
		var points := PackedVector2Array()
		for i in 96: points.append(center + Vector2(cos(i * TAU / 96), sin(i * TAU / 96)) * float(radii[0]))
		host.draw_colored_polygon(points, colours[0])
	for ring in range(radii.size() - 1):
		for i in 96:
			var a := Vector2(cos(i * TAU / 96), sin(i * TAU / 96))
			var b := Vector2(cos((i + 1) * TAU / 96), sin((i + 1) * TAU / 96))
			host.draw_polygon(PackedVector2Array([center + a * float(radii[ring]), center + a * float(radii[ring + 1]), center + b * float(radii[ring + 1]), center + b * float(radii[ring])]),
				PackedColorArray([colours[ring], colours[ring + 1], colours[ring + 1], colours[ring]]))
