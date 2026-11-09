extends "res://src/festival_renderer.gd"
## Queue jump: original painted scenes and source procedural obstacles.
## Only simulation snapshots are read; drawing never advances clocks or RNG.

var _crowd_shaded: Texture2D

func supports(id: String) -> bool:
	return id == "3-2"

func _festival_context(host) -> Dictionary:
	var c := super._festival_context(host)
	c.elapsed = float(host.elapsed)
	return c

func build_sky(host, runtime = null) -> Array:
	var out := super.build_sky(host, runtime)
	var colours := [Color("3b3270"), Color("3b3270"), Color("d8668a"), Color("f7b267"), Color("f7b267")]
	var i := 0
	for command in out:
		if command.tag == "festival_sky_gradient":
			command.colours = PackedColorArray([colours[i], colours[i], colours[i + 1], colours[i + 1]])
			i += 1
	return out

func _decor_cut(out: Array, c: Dictionary, decor: Array) -> void:
	# These props are already present in the painting (source drawLevel955).
	if decor[4] == "back" and (str(decor[0]).begins_with("flag") or decor[0] == "speaker"): return
	super._decor_cut(out, c, decor)

func build_level(host, runtime = null) -> Array:
	var out := super.build_level(host, runtime)
	if not supports(host.level_id): return out
	var c := _festival_context(host)
	# Banners precede checkpoint flags, rather than covering their labels.
	var checkpoint: Array = []
	var body: Array = []
	for command in out:
		if str(command.tag).begins_with("festival_checkpoint"): checkpoint.append(command)
		else: body.append(command)
	for z in c.level.get("duck", []):
		if z.size() > 3 and z[3] == "banner": _banner(body, c, z, float(_state(runtime, "elapsed", host.elapsed)))
	body.append_array(checkpoint)
	return body

func _surface(out: Array, c: Dictionary, q: Dictionary) -> void:
	var row: Array = q.get("row", [q.get("x0", 0), q.get("x1", 0), q.get("top", 0)])
	var a := float(row[0])
	var b := float(row[1])
	if not _in_view(c, a, b): return
	var style := str(q.get("style", "ground"))
	if style == "barrier":
		var x := a
		while x < b - 4:
			_barrier(out, Vector2(_x(c, x), float(row[2]) + float(c.y_snap)), Vector2(minf(120, b - x) / 120, (float(q.get("base", c.ground)) - float(row[2]) + 4) / 112))
			x += 120
	elif style == "crowd":
		_crowd(out, c, a, b, float(row[2]))
	else: super._surface(out, c, q)

func _barrier(out: Array, origin: Vector2, scale: Vector2) -> void:
	var parts: Array = [[0, 0, 120, 8, "9aa6b8"], [0, 0, 8, 102, "9aa6b8"], [112, 0, 8, 102, "9aa6b8"], [0, 72, 120, 6, "9aa6b8"]]
	for x in range(16, 110, 12):
		parts.append([x, 8, 4, 64, "c8d0db"])
		parts.append([x + 3, 8, 1, 64, "7d889a"])
	parts.append_array([[0, 0, 120, 3, "e8eef5"], [2, 0, 3, 100, "e8eef5"], [-6, 102, 30, 10, "5d6678"], [96, 102, 30, 10, "5d6678"]])
	for part in parts:
		# Source art is a 120x112 canvas, clipping its protruding feet first.
		var rect := Rect2(part[0], part[1], part[2], part[3]).intersection(Rect2(0, 0, 120, 112))
		_rect(out, Rect2(origin + rect.position * scale, rect.size * scale), Color(part[4]), "queue_barrier")

func _crowd(out: Array, c: Dictionary, a: float, b: float, top: float) -> void:
	var size := _world_size(c, "crowdband")
	if size.x <= 0: return
	var hi := float(c.hi.get("crowdband", 1))
	var clip := Rect2(_x(c, a), top - 40 + float(c.y_snap), source_round(b - a), float(c.camera.y) + 560 - top + 40)
	for layer in [[-26, 1.0, 0.0], [30, 0.62, 0.37]]:
		var x := floorf(a / 96) * 96
		while x < b:
			var wx := source_round(x) + float(layer[2]) * 517
			var bob := source_round(sin(float(c.elapsed) / 0.17 + wx * 0.011) * 4)
			var sx := fposmod(source_round(wx), size.x)
			var first := minf(96, size.x - sx)
			var regions := [[sx, first, 0.0]]
			if first < 96: regions.append([0.0, 96 - first, first])
			for region in regions:
				var commands: Array = []
				_texture(commands, c, "crowdband", Rect2(_x(c, x) + float(region[2]), top + float(layer[0]) + bob + float(c.y_snap), float(region[1]), size.y), "queue_crowd", Rect2(float(region[0]) * hi, 0, float(region[1]) * hi, size.y * hi), false, {"shade": layer[1], "bob": bob, "world_slice": x})
				for command in commands:
					var clipped := _clip_texture(command, clip)
					if not clipped.is_empty():
						clipped.type = "queue_crowd_texture"
						out.append(clipped)
			x += 96

func _banner(out: Array, c: Dictionary, z: Array, elapsed: float) -> void:
	var a := float(z[0]) - 14
	var b := float(z[1]) + 14
	if b - float(c.camera.x) < -30 or a - float(c.camera.x) > float(c.width) + 30: return
	var y := float(z[2]) + float(c.y_snap)
	var wave := sin(elapsed / 0.26 + float(z[0])) * 2
	var colours: Array = TENT_COLOURS[posmod(int(floorf(float(z[0]) / 700)), 6)]
	for x in [a, b]:
		_rect(out, Rect2(_x(c, x) - 4, y - 70, 9, float(c.ground) - float(z[2]) + 70), Color("1b1426"), "queue_banner_pole")
		_rect(out, Rect2(_x(c, x) - 2, y - 68, 5, float(c.ground) - float(z[2]) + 66), Color("c8d0db"), "queue_banner_pole")
	_rect(out, Rect2(_x(c, a), source_round(float(z[2]) - 52 + wave) + float(c.y_snap), source_round(b - a), 56), Color("1b1426"), "queue_banner_back")
	for i in 6:
		_rect(out, Rect2(_x(c, a + 2 + i * (b - a - 4) / 6), source_round(float(z[2]) - 50 + wave) + float(c.y_snap), ceilf((b - a - 4) / 6), 52), Color(colours[i % 2]), "queue_banner_stripe")
	_rect(out, Rect2(_x(c, a + 2), source_round(float(z[2]) - 50 + wave) + float(c.y_snap), source_round(b - a - 4), 5), Color(1, 1, 1, 0.25), "queue_banner_highlight")
	_rect(out, Rect2(_x(c, a + 2), source_round(float(z[2]) - 4 + wave) + float(c.y_snap), source_round(b - a - 4), 4), Color(0, 0, 0, 0.2), "queue_banner_shadow")
	out.append({"type": "outlined_text", "position": Vector2(_x(c, (a + b) / 2), source_round(float(z[2]) - 25 + wave) + float(c.y_snap)), "text": "DUCK", "size": 12, "colour": Color.WHITE, "outline": Color("1b1426"), "outline_size": 3, "tag": "queue_banner_label"})

func build_front(host, runtime = null) -> Array:
	var out: Array = []
	if not supports(host.level_id): return out
	if str(_state(host, "mode", "play")) == "play":
		var c := _festival_context(host)
		var elapsed := float(_state(runtime, "elapsed", host.elapsed))
		var end_run := float(_state(runtime, "stage_data", {}).get("end_run", 0))
		# Preserve source Math.min: nonnegative ending clock never moves him.
		var x := float(c.camera.x) + minf(float(c.width) - 70, float(c.width) - 70 + end_run * 400)
		var fy := float(c.ground)
		var best := INF
		for q in _surfaces(host, runtime):
			var row: Array = q.get("row", [q.get("x0", 0), q.get("x1", 0), q.get("top", 0)])
			if x >= float(row[0]) and x <= float(row[1]) and float(row[2]) >= float(c.view.position.y) - 2 and float(row[2]) < best:
				best = float(row[2])
				fy = best
		var sprite := _sprite_commands(host, c, "bot", "walk", int(floorf(elapsed * 1000 / 70 + 0.000000001)) % 6, Vector2(x, fy), -1, 0.5, "", false, "queue_jar_runner")
		if not sprite.is_empty():
			out.append_array(sprite)
			_jar_icon(out, Vector2(x + 6, fy - 128 + sin(elapsed / 0.09) * 3 + float(c.y_snap)))
	out.append_array(super.build_front(host, runtime))
	return out

func _jar_icon(out: Array, p: Vector2) -> void:
	var k := 1.2
	_rect(out, Rect2(p + Vector2(-9, -22) * k, Vector2(18, 6) * k), Color("b07a2a"), "queue_jar_lid")
	_border(out, Rect2(p + Vector2(-14, -16) * k, Vector2(28, 30) * k), 8 * k, Color(200 / 255.0, 230 / 255.0, 1, 0.3), Color("dce8f0"), 2 * k, "queue_jar_glass")
	_rounded(out, Rect2(p + Vector2(-12, -14) * k, Vector2(24, 26) * k), 7 * k, GOLD, "queue_jar_coins")
	for i in 6: _rect(out, Rect2(p + Vector2(-10 + (i * 7) % 20, 10 - (i * 5) % 26) * k, Vector2(4, 2) * k), Color("c99a1d"), "queue_jar_coin_detail")
	_rect(out, Rect2(p + Vector2(-10, -12) * k, Vector2(3, 8) * k), Color.WHITE, "queue_jar_highlight")

func clear_cache() -> void:
	super.clear_cache()
	_crowd_shaded = null

func draw_commands(host, commands: Array) -> void:
	for command in commands:
		if command.type == "queue_crowd_texture":
			var texture: Texture2D = host.images.crowdband
			if float(command.shade) < 1:
				if _crowd_shaded == null:
					var pixels: Image = texture.get_image().duplicate()
					pixels.convert(Image.FORMAT_RGBA8)
					for y in pixels.get_height():
						for x in pixels.get_width():
							var pixel := pixels.get_pixel(x, y)
							pixels.set_pixel(x, y, Color(_clamped_byte(pixel.r8 * 0.62) / 255, _clamped_byte(pixel.g8 * 0.62) / 255, _clamped_byte(pixel.b8 * 0.62) / 255, pixel.a))
					_crowd_shaded = ImageTexture.create_from_image(pixels)
				texture = _crowd_shaded
			host.draw_texture_rect_region(_nearest(texture), command.rect, command.source, Color.WHITE)
		else: super.draw_commands(host, [command])
