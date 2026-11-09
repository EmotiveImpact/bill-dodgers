extends "res://src/aisle_renderer.gd"
## Source 2-6 checkout lanes and TB painter. Absolute world pixels / seconds.
## TB is world_two.checkout, never host.boss. Drawing does not mutate gameplay.
## The host supplies the shared bottom-anchored 1.3x world transform.

const TILL_CANVAS := Vector2(390, 360)
const TILL_ORIGIN := Vector2(4565, 132)
const TRAY_RECT := Rect2(4816, 354, 119, 0)
const BODY_RECT := Rect2(4635, 122, 250, 360)
const SCREEN_RECT := Rect2(4715, 182, 108, 68)

func supports(id: String) -> bool:
	return id == "2-6"

func _checkout_state(host, runtime = null) -> Dictionary:
	var owner = runtime
	if owner == null: owner = _state(host, "world_two", null)
	if owner == null: return {}
	var checkout = _state(owner, "checkout", null)
	if checkout == null and owner is Dictionary and owner.has("boss"): return owner
	if checkout is Dictionary: return checkout
	if checkout != null and checkout.has_method("snapshot"): return checkout.snapshot()
	return {}

func build_sky(host, _runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	var cam: Vector2 = c.camera
	var size := _size(c, "checkout")
	if size == Vector2.ZERO:
		_rect(out, Rect2(cam.x - 10, cam.y - 10, c.width + 20, HEIGHT + 20), Color("e9f0ec"), "checkout_missing_painting")
		return out
	var top := float(c.ground) - 0.82 * size.y - cam.y
	_rect(out, Rect2(cam.x - 10, cam.y - 10, c.width + 20, top + 12).abs(), Color("1e2738"), "checkout_roof_fill")
	_tile_row(out, c, "checkout", _crop(c, "checkout", 0, 0, 1, 0.1), 0.4, top, "checkout_roof")
	_tile_row(out, c, "checkout", _crop(c, "checkout", 0, 0.1, 1, 0.265), 0.7, top + source_round(0.1 * size.y), "checkout_pipes")
	var first := out.size()
	_tile_row(out, c, "checkout", _crop(c, "checkout", 0, 0.265, 1, 1), 1, top + source_round(0.265 * size.y), "checkout_wall")
	# Source tileRow(..., true): lane numbers never mirror in the last band.
	for i in range(first, out.size()): out[i].flip_h = false
	return out

func build_level(host, _runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	var ground := float(c.ground)
	var ys := float(c.y_snap)
	var crop := _crop(c, "checkout", 0.03, 0.555, 0.70, 0.775)
	if not crop.has_area():
		_rect(out, Rect2(c.camera.x - 60, ground + ys, c.width + 120, maxf(0, c.camera.y + HEIGHT + 20 - ground)), Color("e8edf0"), "checkout_floor_fallback")
	var lanes: Array = c.level.get("lanes", [])
	for i in lanes.size():
		var x := float(lanes[i])
		if not _in_view(c, x - 20, x + 420): continue
		var origin := Vector2(_x(c, x), ground - 260 + ys)
		_lane_sign(out, origin, i + 1)
		if crop.has_area():
			_texture(out, c, "checkout", Rect2(origin.x, ground - 96 + ys, 380, source_round(380 * crop.size.y / crop.size.x)), "checkout_lane", crop, i % 2 != 0, {"lane": i + 1})
			_rect(out, Rect2(origin.x + 6, ground - 4 + ys, 368, 6), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.35), "checkout_lane_shadow")
		else:
			for row in [[Rect2(0, 170, 380, 90), "2d6a4f"], [Rect2(0, 170, 380, 6), "3f8f63"], [Rect2(10, 186, 360, 60), "e9f0ec"], [Rect2(300, 120, 60, 50), "2b3850"], [Rect2(306, 126, 48, 30), "3f7fd8"]]:
				_rect(out, Rect2(origin + row[0].position, row[0].size), Color(row[1]), "checkout_lane_fallback")
	var arena := float(c.level.get("arena", 4162))
	var end := float(c.level.get("w", 4900))
	if _in_view(c, arena, end):
		_rect(out, Rect2(_x(c, arena), ground + ys, end - arena, 6), GOLD, "checkout_arena_stripe")
		var x := arena
		while x < end:
			_rect(out, Rect2(_x(c, x), ground + ys, 20, 6), Color("14243b"), "checkout_arena_band")
			x += 40
	return out

func _lane_sign(out: Array, origin: Vector2, number: int) -> void:
	for row in [[Rect2(360, 0, 8, 170), Color("9aa5b8")], [Rect2(340, 0, 50, 44), Color("14243b")], [Rect2(346, 6, 38, 32), Color("9fe0b8") if number % 2 else GOLD]]:
		_rect(out, Rect2(origin + row[0].position, row[0].size), row[1], "checkout_lane_sign")
	_text(out, origin + Vector2(365, 23), str(number), 24, Color("14243b"), "checkout_lane_number")

func draw_mid(host, runtime = null, pickups: Callable = Callable()) -> void:
	if not supports(host.level_id): return
	# Source lvDrawMid ends with drawPicks() then L.mid(). Both crates and bags
	# belong here, behind loot, enemies, jar and the players, even while carried.
	draw_commands(host, super.build_mid(host, runtime))
	if pickups.is_valid(): pickups.call()
	draw_commands(host, build_checkout_mid(host, runtime))

func build_mid(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = super.build_mid(host, runtime)
	out.append_array(build_checkout_mid(host, runtime))
	return out

func build_checkout_mid(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var state := _checkout_state(host, runtime)
	var b: Dictionary = state.get("boss", {})
	if b.is_empty(): return []
	var c := _context(host)
	var out: Array = []
	var ys := float(c.y_snap)
	var x := float(b.get("x", 4760))
	var elapsed := float(host.elapsed)
	_ellipse(out, Vector2(_x(c, x), 480 + ys), Vector2(150, 12), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.3), "checkout_boss_shadow")
	_till(out, c, b, elapsed)
	# Source codes/dizzy never activate. Empty inherited fields stay harmless;
	# existing supplied codes can still be displayed without creating attacks.
	for code in b.get("codes", []):
		var p: Vector2 = code.get("p", Vector2(code.get("x", 0), code.get("y", 0)))
		p = Vector2(_x(c, p.x), source_round(p.y) + ys)
		_border(out, Rect2(p - Vector2(26, 18), Vector2(52, 36)), 4, GOLD if code.get("back", false) else Color.WHITE, Color("14243b"), 2, "checkout_code")
		for i in 9: _rect(out, Rect2(p + Vector2(-20 + i * 4.6, -12), Vector2(2 if i % 3 else 3, 22)), Color("14243b"), "checkout_code_bar")
	var beam = b.get("beam")
	if beam != null and float(beam.t) < 0.9 and b.get("state", "") == "fight":
		var high := float(beam.y) < 382
		_rect(out, Rect2(_x(c, x - 195 + 146), 132 + (126 if high else 140) + ys, 66, 12), Color(1, 80 / 255.0, 80 / 255.0, 0.95) if _clock_step(float(beam.t), 0.15) % 2 else Color(1, 190 / 255.0, 190 / 255.0, 0.9), "scanner_window_tell")
		out[-1].merge({"high": high, "beam_seconds": beam.t})
	var steps := int(b.get("steps", 0))
	for i in steps:
		var origin := Vector2(_x(c, x - 375 + i * 80), 412 - i * 65 + ys)
		_rect(out, Rect2(origin + Vector2(6, 6), Vector2(90, 14)), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.25), "receipt_step_shadow")
		_rect(out, Rect2(origin, Vector2(90, 14)), Color.WHITE, "receipt_step")
		out[-1].step = i
		_rect(out, Rect2(origin + Vector2(0, 11), Vector2(90, 3)), Color("d7dde6"), "receipt_step_edge")
		for k in 4: _rect(out, Rect2(origin + Vector2(10 + k * 18, 5), Vector2(12, 2)), Color("9aa5b8"), "receipt_step_print")
	if steps > 0:
		var end := x - 285 + (steps - 1) * 80
		_quadratic(out, Vector2(_x(c, x + 25), 272 + ys), Vector2(_x(c, end + 30), 202 + ys), Vector2(_x(c, end), 412 - (steps - 1) * 65 + 4 + ys), Color.WHITE, 6, "receipt_paper_feed")
	for crate in b.get("crates", []):
		var key := "crate%d" % int(crate.get("k", 0))
		var size := _size(c, key)
		if size == Vector2.ZERO: continue
		var p: Vector2 = crate.p
		if crate.st == "fall": _ellipse(out, Vector2(_x(c, p.x), 482 + ys), Vector2(30, 6), Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.25), "checkout_crate_shadow")
		_texture(out, c, key, Rect2(_x(c, p.x - size.x / 2), source_round(p.y - size.y) + ys, size.x, size.y), "checkout_crate", Rect2(), false, {"state": crate.st, "kind": crate.k, "bottom": p, "by": crate.get("by"), "layer": "mid"})
	for player in state.get("players", {}).values():
		if float(player.get("bag", 0)) <= 0: continue
		_bag(out, c, player)
	return out

static func _clock_step(seconds: float, interval: float) -> int:
	# Exact source millisecond boundaries, avoiding division residue in seconds.
	return int(floorf(seconds / interval + 0.000000001))

func _till(out: Array, c: Dictionary, b: Dictionary, elapsed: float) -> void:
	var down: bool = b.get("state", "") == "down"
	var time := float(b.get("t", 0))
	var wob := sin(elapsed / 0.06) * 4 if float(b.get("dizzy", 0)) > 0 else 0.0
	var sink := minf(60, time * 50) if down else 0.0
	var angle := minf(0.1, time / 6) if down else 0.0
	var alpha := maxf(0.35, 1 - time / 2.5) if down else 1.0
	var origin := Vector2(_x(c, float(b.get("x", 4760)) - 195) + wob, 132 + sink + float(c.y_snap))
	var pivot := Vector2(195, 340)
	var transform := Transform2D(0, origin) * Transform2D(0, pivot) * Transform2D(angle, Vector2.ZERO) * Transform2D(0, -pivot)
	var local: Array = []
	var painted: bool = c.images.has("boss")
	if painted:
		var size := _size(c, "boss")
		var width := source_round(size.x * 360 / size.y)
		local.append({"type": "texture", "key": "boss", "rect": Rect2(source_round((390 - width) / 2), 0, width, 360), "source": Rect2(Vector2.ZERO, size), "flip_h": false, "alpha": 1.0, "flash": float(b.get("flash", 0)) > 0, "tag": "checkout_boss_painting"})
	else:
		_till_fallback(local)
	var screen := Rect2(150, 50, 108, 68) if painted else Rect2(106, 16, 178, 88)
	if down:
		_text(local, Vector2(screen.get_center().x, screen.position.y + 44), "X  X", 28, Color("e23b3b"), "checkout_screen_down")
	elif float(b.get("frozen", 0)) > 0:
		_rect(local, screen, Color("c62828" if _clock_step(elapsed, 0.25) % 2 else "e23b3b"), "checkout_screen_error")
		_text(local, Vector2(screen.get_center().x, screen.position.y + screen.size.y * 0.38), "ERROR", 18, Color.WHITE, "checkout_error_text")
		_text(local, Vector2(screen.get_center().x, screen.position.y + screen.size.y * 0.78), "!", 22, Color.WHITE, "checkout_error_mark")
	elif float(b.get("dizzy", 0)) > 0:
		_rect(local, screen, Color("3f7fd8"), "checkout_screen_wait")
		_text(local, Vector2(screen.get_center().x, screen.position.y + 30), "WAIT", 22, Color.WHITE, "checkout_wait_text")
		_text(local, Vector2(screen.get_center().x, screen.position.y + 60), "...", 22, Color.WHITE, "checkout_wait_mark")
	elif painted:
		if int(b.get("phase", 1)) > 1: _rect(local, screen, Color(1, 60 / 255.0, 60 / 255.0, 0.28) if int(b.phase) == 3 else Color(1, 170 / 255.0, 60 / 255.0, 0.22), "checkout_phase_overlay")
	else:
		var colour := Color("ff5a5a" if int(b.get("phase", 1)) == 3 else ("ffb347" if int(b.get("phase", 1)) == 2 else "9fe0b8"))
		var blink := _clock_step(elapsed, 2.6) % 7 == 0 and fposmod(elapsed, 2.6) < 0.14
		for ex in [screen.position.x + 34, screen.end.x - 64]:
			_rect(local, Rect2(ex, screen.position.y + (40 if blink else 30), 30, 4 if blink else 22), colour, "checkout_fallback_eye")
		_rect(local, Rect2(screen.get_center().x - 30, screen.position.y + 68, 60, 6), colour, "checkout_fallback_mouth")
	var mouth := float(b.get("mouth", 0)) > 0
	if mouth or not painted:
		_rect(local, Rect2(146, 128, 66, 24) if painted else Rect2(118, 136, 154, 28), Color(1, 59 / 255.0, 59 / 255.0, 0.75) if painted else (Color("ff3b3b") if mouth else Color(226 / 255.0, 59 / 255.0, 59 / 255.0, 0.55)), "checkout_scanner_mouth")
		if mouth: _rect(local, Rect2(146, 138, 66, 4) if painted else Rect2(118, 148, 154, 4), Color("ffd2d2"), "checkout_scanner_mouth_core")
	out.append({"type": "checkout_pose", "commands": local, "transform": transform, "alpha": alpha, "origin": origin, "art_rect": Rect2(origin, TILL_CANVAS), "angle": angle, "sink": sink, "pivot": pivot, "tag": "checkout_till"})
	# Source down smoke mutates particles and Math.random from drawing. Omitted
	# deliberately, not replaced by random draw-time writes to simulation state.

func _till_fallback(out: Array) -> void:
	# Missing-asset geometry only. Shipped levels always use the original boss.
	for row in [[Rect2(90, 316, 210, 24), "2b3850"], [Rect2(70, 60, 250, 256), "1f4d39"], [Rect2(76, 66, 238, 244), "e9f0ec"], [Rect2(76, 210, 238, 100), "2d6a4f"], [Rect2(76, 210, 238, 8), "3f8f63"], [Rect2(76, 302, 238, 6), "f4c542"], [Rect2(90, 0, 210, 120), "1f4d39"], [Rect2(96, 6, 198, 108), "c7d0dc"], [Rect2(106, 16, 178, 88), "0e1726"], [Rect2(110, 130, 170, 40), "3a4258"], [Rect2(260, 186, 34, 8), "14243b"], [Rect2(100, 186, 60, 30), "14243b"], [Rect2(104, 190, 52, 22), "3f7fd8"], [Rect2(6, 200, 70, 12), "9aa5b8"], [Rect2(0, 186, 80, 16), "c7d0dc"], [Rect2(10, 212, 8, 40), "2b3850"]]:
		_rect(out, row[0], Color(row[1]), "checkout_till_fallback")
	for wx in [110, 280]:
		_ellipse(out, Vector2(wx, 344), Vector2(14, 14), Color("121822"), "checkout_fallback_wheel")
		_ellipse(out, Vector2(wx, 344), Vector2(5, 5), Color("9aa5b8"), "checkout_fallback_hub")
	for i in 4: _rect(out, Rect2(100 + i * 52, 230, 34, 60), Color("1f4d39"), "checkout_fallback_panel")

func _bag(out: Array, c: Dictionary, player: Dictionary) -> void:
	var p: Vector2 = player.get("p", Vector2.ZERO)
	var x := _x(c, p.x)
	var feet := p.y + float(c.y_snap)
	var height := float(player.get("height", 180))
	_poly(out, [Vector2(x - 46, feet), Vector2(x - 38, feet - height * 0.8), Vector2(x + 38, feet - height * 0.8), Vector2(x + 46, feet)], Color(245 / 255.0, 248 / 255.0, 250 / 255.0, 0.86), "checkout_player_bag")
	for dx in [-16, 16]:
		var points := PackedVector2Array()
		for i in 25:
			var angle := PI + PI * i / 24
			points.append(Vector2(x + dx, feet - height * 0.8) + Vector2(cos(angle), sin(angle)) * 12)
		out.append({"type": "line", "points": points, "width": 5.0, "colour": Color("2d6a4f"), "tag": "checkout_bag_handle"})
	_rect(out, Rect2(x - 30, feet - height * 0.45, 60, 14), Color("2d6a4f"), "checkout_bag_logo")

func build_player_back(_host, _player = null) -> Array: return []
func build_player_front(_host, _player = null) -> Array: return []

func build_front(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var c := _context(host)
	var scroll := float(c.camera.x) * 1.3
	var until := float(c.level.get("w", 4900)) - float(c.width) - 400
	for index in range(int(floorf(scroll / 2300)) - 1, int(floorf((scroll + float(c.width)) / 2300)) + 2):
		if index * 2300 + 900 > until * 1.3: continue
		var sx := source_round(index * 2300 + 900 - scroll)
		if sx < -50 or sx > float(c.width) + 20: continue
		var x := float(c.camera.x) + sx
		var top := HEIGHT - 46 + float(c.y_snap)
		var colour := Color(22 / 255.0, 30 / 255.0, 58 / 255.0, 0.92)
		_rect(out, Rect2(x, top + 8, 30, 46), colour, "foreground_bollard")
		_ellipse(out, Vector2(x + 15, top + 8), Vector2(15, 6), colour, "foreground_bollard_cap")
		_rect(out, Rect2(x + 4, top + 10, 3, 46), Color(120 / 255.0, 140 / 255.0, 200 / 255.0, 0.6), "foreground_bollard_highlight")
		_rect(out, Rect2(x, top + 18, 30, 8), Color("e23b3b"), "foreground_bollard_band")
	var b: Dictionary = _checkout_state(host, runtime).get("boss", {})
	var beam = b.get("beam")
	if beam == null: return out
	var length := source_round(float(b.get("x", 4760)) - 125 - float(c.camera.x))
	var y := float(beam.y) + float(c.y_snap)
	var time := float(beam.t)
	if time < 0.9:
		if _clock_step(time, 0.12) % 2:
			_rect(out, Rect2(c.camera.x, y - 2, length, 4), Color(1, 59 / 255.0, 59 / 255.0, 0.5), "scanner_warning_line")
			_text(out, Vector2(c.camera.x + length - 120, y - 26), "Jump!" if beam.y > 382 else "Duck!", 18, Color("ffd2d2"), "scanner_warning_text", true)
	elif time < 1.45:
		_rect(out, Rect2(c.camera.x, y - 10, length, 20), Color(1, 59 / 255.0, 59 / 255.0, 0.35), "scanner_beam_glow")
		_rect(out, Rect2(c.camera.x, y - 4, length, 8), Color("ff3b3b"), "scanner_beam")
		_rect(out, Rect2(c.camera.x, y - 1, length, 2), Color("ffd2d2"), "scanner_beam_core")
	# Visual turns red at exactly900ms; source damage is strictly after900ms.
	return out

func build_jar(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var jar: Dictionary = _checkout_state(host, runtime).get("jar", {})
	if jar.is_empty(): return []
	var out: Array = []
	var c := _context(host)
	var age := float(jar.get("t", 0))
	var got := bool(jar.get("got", false))
	var p: Vector2 = jar.p + Vector2(0, (0.0 if got else sin(age / 0.14) * 2) + float(c.y_snap))
	# drawJar deliberately uses unrounded x, unlike most checkout geometry.
	if not got:
		var radius := 44 + sin(age / 0.1) * 4
		_ellipse(out, p - Vector2(0, 4), Vector2.ONE * radius, Color(1, 241 / 255.0, 168 / 255.0, 0.35), "checkout_jar_glow")
	_rect(out, Rect2(p + Vector2(-18, -44), Vector2(36, 12)), Color("b07a2a"), "checkout_jar_lid")
	_border(out, Rect2(p + Vector2(-28, -32), Vector2(56, 60)), 16, Color(200 / 255.0, 230 / 255.0, 1, 0.3), Color("dce8f0"), 4, "checkout_jar_glass")
	_rounded(out, Rect2(p + Vector2(-24, -28), Vector2(48, 52)), 14, GOLD, "checkout_jar_coins")
	for i in 6: _rect(out, Rect2(p + Vector2((-10 + (i * 7) % 20) * 2, (10 - (i * 5) % 26) * 2), Vector2(8, 4)), Color("c99a1d"), "checkout_jar_coin_detail")
	_rect(out, Rect2(p + Vector2(-20, -24), Vector2(6, 16)), Color.WHITE, "checkout_jar_highlight")
	return out

func draw_jar(host, runtime = null) -> void:
	draw_commands(host, build_jar(host, runtime))

func build_hud(host, runtime = null) -> Array:
	if not supports(host.level_id): return []
	var out: Array = []
	var b: Dictionary = _checkout_state(host, runtime).get("boss", {})
	if not b.is_empty() and b.get("state", "") != "down":
		_border(out, Rect2(266, 496, 428, 26), 8, Color(14 / 255.0, 23 / 255.0, 38 / 255.0, 0.85), Color("f5f1ea"), 2, "checkout_boss_health_back")
		var fraction := maxf(0, float(b.get("hp", 0)) / maxf(1, float(b.get("max", 70))))
		if fraction > 0: _rounded(out, Rect2(270, 500, 420 * fraction, 18), 6, GOLD if float(b.get("dizzy", 0)) > 0 else Color("e23b3b"), "checkout_boss_health")
		_text(out, Vector2(278, 484), "Giant self-checkout", 14, Color("f5f1ea"), "checkout_boss_name", true, "left")
	out.append_array(super.build_hud(host, _state(host, "world_two", null) if runtime == null else runtime))
	return out

func _text(out: Array, position: Vector2, value: String, size: int, colour: Color, tag: String, outlined: bool = false, align: String = "center") -> void:
	out.append({"type": "checkout_text", "position": position, "text": value, "size": size, "colour": colour, "tag": tag, "outlined": outlined, "align": align})

func _quadratic(out: Array, start: Vector2, control: Vector2, end: Vector2, colour: Color, width: float, tag: String) -> void:
	var points := PackedVector2Array()
	for i in 33:
		var k := i / 32.0
		points.append((1 - k) * (1 - k) * start + 2 * (1 - k) * k * control + k * k * end)
	out.append({"type": "line", "points": points, "colour": colour, "width": width, "control": control, "tag": tag})

func _world_transform(host) -> Transform2D:
	return Transform2D(0, Vector2.ONE * 1.3, 0, Vector2(-host.camera.x * 1.3, 540 * (1 - 1.3) - host.camera.y * 1.3))

func draw_commands(host, commands: Array) -> void:
	for command in commands:
		match command.type:
			"checkout_pose":
				var base := _world_transform(host)
				host.draw_set_transform_matrix(base * command.transform)
				var local: Array = []
				for child in command.commands:
					var copy: Dictionary = child.duplicate(true)
					if copy.has("colour"): copy.colour.a *= float(command.alpha)
					if copy.has("alpha"): copy.alpha *= float(command.alpha)
					local.append(copy)
				draw_commands(host, local)
				host.draw_set_transform_matrix(base)
			"checkout_text":
				var width: float = host.font.get_string_size(command.text, HORIZONTAL_ALIGNMENT_LEFT, -1, command.size).x
				var position: Vector2 = command.position + Vector2(0 if command.align == "left" else -width / 2, (host.font.get_ascent(command.size) - host.font.get_descent(command.size)) / 2)
				if command.outlined: host.draw_string_outline(host.font, position, command.text, HORIZONTAL_ALIGNMENT_LEFT, -1, command.size, int(source_round(maxf(3, command.size / 4.0) / 2)), Color("0e1726"))
				host.draw_string(host.font, position, command.text, HORIZONTAL_ALIGNMENT_LEFT, -1, command.size, command.colour)
			"texture":
				if command.get("flash", false):
					var copy: Dictionary = command.duplicate(true)
					copy.type = "bot_texture"
					copy.texture = host.images[command.key]
					copy.big = false
					super.draw_commands(host, [copy])
				else: super.draw_commands(host, [command])
			_: super.draw_commands(host, [command])
