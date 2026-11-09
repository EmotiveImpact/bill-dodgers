extends "res://src/festival_renderer.gd"
## Ticket Tout finale. Original per-move strips and their authored foot anchors.
## Builders only read simulation snapshots; repeated draws never advance frames.

const QueuePainter = preload("res://src/festival_queue_renderer.gd")
const BigTopPainter = preload("res://src/festival_big_top_renderer.gd")
const FRAME_EPS := 0.000000001
var _queue_painter = QueuePainter.new()
var _cases_painter = BigTopPainter.new()
var _tout_flashes: Dictionary = {}

func supports(id: String) -> bool:
	return id == "3-6"

func build_sky(host, runtime = null) -> Array:
	var out := super.build_sky(host, runtime)
	var colours := [Color("3b3270"), Color("3b3270"), Color("d8668a"), Color("f7b267"), Color("f7b267")]
	var index := 0
	for command in out:
		if command.tag == "festival_sky_gradient":
			command.colours = PackedColorArray([colours[index], colours[index], colours[index + 1], colours[index + 1]])
			index += 1
	return out

func _decor_cut(out: Array, c: Dictionary, decor: Array) -> void:
	# Source955 suppresses flags/speakers already present in scene paintings.
	if decor[4] == "back" and (str(decor[0]).begins_with("flag") or decor[0] == "speaker"): return
	super._decor_cut(out, c, decor)

func _surface(out: Array, c: Dictionary, q: Dictionary) -> void:
	# Reuse the already source-grounded obstacle builders. Stage index zero is
	# a real live platform, not a truthy flag; no painter owns its collision row.
	match str(q.get("style", "")):
		"barrier": _queue_painter._surface(out, c, q)
		"cases": _cases_painter._surface(out, c, q)
		_: super._surface(out, c, q)

static func tout_move(b: Dictionary, elapsed: float) -> Dictionary:
	var t := float(b.get("t", 0))
	var state := str(b.get("state", "walk"))
	var animation := "hide"
	var frame := 0
	var hop: Dictionary = b.get("hop", {}) if b.get("hop") is Dictionary else {}
	if state == "down":
		animation = "down"
		frame = 3 if not b.get("jar", {}).is_empty() else mini(3, int(floorf((t + FRAME_EPS) / 0.28)))
	elif not hop.is_empty():
		if not hop.get("slam", false):
			animation = "surf"
			frame = int(floorf((t + FRAME_EPS) / 0.14)) % 4
		else:
			animation = "stomp"
			var k := minf(1, float(hop.t) / float(hop.duration))
			frame = 0 if k < 0.12 else (1 if k < 0.7 else 2)
	elif float(b.get("land_t", 0)) > 0:
		animation = "stomp"
		frame = 3
	elif float(b.get("dizzy", 0)) > 0:
		animation = "dizzy"
		frame = int(floorf((t + FRAME_EPS) / 0.17)) % 4
	elif state == "throw":
		animation = "throw"
		frame = mini(3, int(floorf((t + FRAME_EPS) / 0.16)))
	elif state == "stomp":
		animation = "stomp"
		var phase := int(floorf((t + FRAME_EPS) / 0.16))
		frame = 0 if phase < 1 else (1 if phase < 2 else 3)
	elif state in ["enter", "charge"] or bool(b.get("moved", b.get("visual_move", false))):
		animation = "walk"
		frame = int(floorf((elapsed + FRAME_EPS) / 0.15)) % 4
	else:
		var phase := int(floorf((elapsed + FRAME_EPS) / 0.26)) % 12
		frame = 1 if phase == 5 else (2 if phase >= 8 and phase < 11 else 0)
	return {"animation": animation, "frame": frame}

func build_boss(host, runtime = null) -> Array:
	var common := super.build_boss(host, runtime)
	if not supports(host.level_id): return common
	var b := _boss(host, runtime)
	if b.is_empty() or b.kind != "tout" or host.meta.get("l3", {}).get("toutfr", {}).is_empty(): return common
	var c := _festival_context(host)
	var move := tout_move(b, float(_state(runtime, "elapsed", host.elapsed)))
	var key := "cut_tout_" + str(move.animation)
	var painted: Dictionary = {}
	if host.images.has(key):
		var f: Dictionary = c.l3.toutfr[move.animation]
		var hi := float(c.hi.get(key, 1))
		var width := float(f.cw) / hi
		var anchor_x := float(f.ax) / hi
		var anchor_y := float(f.ay) / hi
		var flip := float(b.face) > 0
		var x := _x(c, float(b.x))
		var left := x + anchor_x - width if flip else x - anchor_x
		painted = {"type": "tout_texture", "key": key, "tag": "tout_boss", "animation": move.animation, "frame": move.frame,
			"rect": Rect2(left, source_round(float(b.fy)) - anchor_y + float(c.y_snap), width, float(f.ch) / hi),
			"source": Rect2(int(move.frame) * float(f.cw), 0, f.cw, f.ch), "flip_h": flip,
			"flash": float(b.get("flash", 0)) > 0, "anchor": Vector2(anchor_x, anchor_y), "hi": hi, "alpha": 1.0}
	var out: Array = []
	# Retain parent shadow and shockwaves, replacing only its thief sprite.
	# Missing authored textures intentionally do not substitute a different actor.
	for command in common:
		if command.tag == "festival_boss": continue
		out.append(command)
		if command.tag == "festival_boss_shadow" and not painted.is_empty(): out.append(painted)
	return out

func build_jar(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var jar: Dictionary = _boss(host, runtime).get("jar", {})
	if jar.is_empty(): return []
	var c := _festival_context(host)
	var t := float(jar.get("t", 0))
	var got := bool(jar.get("got", false))
	# Source drawJar does not round its floating center before jarIcon.
	var point := Vector2(float(jar.x), float(jar.y) + (0.0 if got else sin(t / 0.14) * 2) + float(c.y_snap))
	var out: Array = []
	if not got: _ellipse(out, point + Vector2(0, -4), Vector2.ONE * (44 + sin(t / 0.1) * 4), Color(1, 241 / 255.0, 168 / 255.0, 0.35), "tout_jar_glow")
	var scale := 2.0
	_rect(out, Rect2(point + Vector2(-9, -22) * scale, Vector2(18, 6) * scale), Color("b07a2a"), "tout_jar_lid")
	_border(out, Rect2(point + Vector2(-14, -16) * scale, Vector2(28, 30) * scale), 8 * scale, Color(200 / 255.0, 230 / 255.0, 1, 0.3), Color("dce8f0"), 2 * scale, "tout_jar_glass")
	_rounded(out, Rect2(point + Vector2(-12, -14) * scale, Vector2(24, 26) * scale), 7 * scale, GOLD, "tout_jar_coins")
	for i in 6: _rect(out, Rect2(point + Vector2(-10 + (i * 7) % 20, 10 - (i * 5) % 26) * scale, Vector2(4, 2) * scale), Color("c99a1d"), "tout_jar_coin_detail")
	_rect(out, Rect2(point + Vector2(-10, -12) * scale, Vector2(3, 8) * scale), Color.WHITE, "tout_jar_highlight")
	return out

func draw_jar(host, runtime = null) -> void:
	draw_commands(host, build_jar(host, runtime))

static func flash_pixel(pixel: Color) -> Color:
	# Canvas CSS brightness(2), not the generic sprite's white-flash blend.
	return Color(minf(1, pixel.r * 2), minf(1, pixel.g * 2), minf(1, pixel.b * 2), pixel.a)

func _flash_texture(texture: Texture2D, source: Rect2) -> Texture2D:
	var key := "%d:%s" % [texture.get_instance_id(), source]
	if not _tout_flashes.has(key):
		var pixels := texture.get_image().get_region(Rect2i(source))
		pixels.convert(Image.FORMAT_RGBA8)
		for y in pixels.get_height():
			for x in pixels.get_width(): pixels.set_pixel(x, y, flash_pixel(pixels.get_pixel(x, y)))
		_tout_flashes[key] = ImageTexture.create_from_image(pixels)
	return _tout_flashes[key]

func draw_commands(host, commands: Array) -> void:
	for command in commands:
		if command.type == "tout_texture":
			var texture: Texture2D = host.images[command.key]
			var source: Rect2 = command.source
			if command.flash:
				texture = _flash_texture(texture, source)
				source.position = Vector2.ZERO
			var rect: Rect2 = command.rect
			if command.flip_h: rect.size.x = -rect.size.x
			host.draw_texture_rect_region(_nearest(texture), rect, source, Color.WHITE)
		else: super.draw_commands(host, [command])

func clear_cache() -> void:
	super.clear_cache()
	_queue_painter.clear_cache()
	_cases_painter.clear_cache()
	_tout_flashes.clear()
