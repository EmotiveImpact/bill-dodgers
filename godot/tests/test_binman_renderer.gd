extends SceneTree
## Source geometry and headless CanvasItem callbacks, not screenshot/device QA.
const Renderer = preload("res://src/binman_renderer.gd")

class Host extends RefCounted:
	var meta: Dictionary = {}
	var images: Dictionary = {}
	var camera := Vector2.ZERO
	var font: Font = ThemeDB.fallback_font
	var recorded: Array = []
	func draw_rect(rect, colour): recorded.append(["rect", rect, colour])
	func draw_colored_polygon(points, colour): recorded.append(["polygon", points, colour])
	func draw_polygon(points, colours, uvs = PackedVector2Array(), texture = null): recorded.append(["texture", points, colours, uvs, texture])
	func draw_polyline(points, colour, width): recorded.append(["outline", points, colour, width])
	func draw_string(font_resource, position, text, alignment, width, size, colour): recorded.append(["text", font_resource, position, text, alignment, width, size, colour])
	func draw_string_outline(font_resource, position, text, alignment, width, size, stroke, colour): recorded.append(["text_outline", font_resource, position, text, alignment, width, size, stroke, colour])

class Boss extends RefCounted:
	var state: Dictionary = {}

class DrawHost extends Node2D:
	var renderer = Renderer.new()
	var boss: Dictionary = {}
	var meta: Dictionary = {}
	var images: Dictionary = {}
	var camera := Vector2.ZERO
	var font: Font = ThemeDB.fallback_font
	var draw_count := 0
	func _draw() -> void:
		draw_set_transform(Vector2(-camera.x * 1.3, 540 * (1 - 1.3) - camera.y * 1.3), 0, Vector2.ONE * 1.3)
		renderer.draw_world(self, boss)
		draw_set_transform(Vector2.ZERO)
		renderer.draw_hud(self, boss)
		draw_count += 1

var failures: Array[String] = []
var assertions := 0

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: " + label)

func tagged(commands: Array, tag: String) -> Array:
	return commands.filter(func(command): return command.tag == tag)

func body_state() -> Dictionary:
	return {"x": 3905.0, "fy": 482.0, "hp": 260, "max": 260, "state": "walk", "t": 0.0, "face": -1,
		"flash": 0.0, "dizzy": 0.0, "lid": 0.0, "lid_t": 0.0, "phase": 1, "waves": [], "bins": [], "rain": []}

func points_equal(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() != b.size(): return false
	for i in a.size():
		if not a[i].is_equal_approx(b[i]): return false
	return true

func polygon_matches(commands: Array, tag: String, rectangle: Rect2, transform: Transform2D, colour: Color) -> bool:
	var matches := tagged(commands, tag)
	return matches.size() == 1 and points_equal(matches[0].points, Renderer.rect_points(rectangle, transform)) and matches[0].colour == colour

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host := Host.new()
	host.meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/1-6.json"))
	host.font = load("res://assets/fonts/silk.woff2")
	check(host.font != null and host.font.resource_path.ends_with("silk.woff2"), "original Silkscreen font resource")
	for key in host.meta.imgs:
		host.images[key] = load(host.meta.imgs[key])
		check(host.images[key].get_size() == Vector2(host.meta.dims[key][0], host.meta.dims[key][1]), "original full-resolution source asset " + key)
	check(not host.images.has("binman") and not host.images.has("bin"), "source 1-6 has no Binman or thrown-bin sprite to replace")
	var source_meta := JSON.stringify(host.meta)
	var renderer = Renderer.new()
	check(renderer.build_world_commands(host, null).is_empty(), "no world commands before boss entry")
	check(renderer.build_hud_commands(host, {}).is_empty(), "no HUD for absent boss")
	check(Renderer.source_round(-0.5) == 0 and Renderer.source_round(-1.5) == -1 and Renderer.source_round(1.5) == 2, "JavaScript negative half rounding")
	var b := body_state()
	var original_state := JSON.stringify(b)
	var origin := Vector2(3905, 482)
	var pose := Transform2D(0, origin)
	var commands: Array = renderer.build_world_commands(host, b)
	check(commands[0].tag == "boss_shadow", "shadow is drawn before body")
	check(commands[0].points[0] == Vector2(4015, 480) and commands[0].points[16] == Vector2(3905, 492), "source 110x12 boss shadow")
	check(polygon_matches(commands, "left_boot", Rect2(-70, -40, 56, 40), pose, Color("3a2a1e")), "left boot source shape")
	check(polygon_matches(commands, "right_boot", Rect2(14, -40, 56, 40), pose, Color("3a2a1e")), "right boot source shape")
	check(polygon_matches(commands, "body_shell", Rect2(-105, -250, 210, 220), pose, Color("1d4a30")), "source wheelie-bin body is 210x220 with 300px pose height")
	check(polygon_matches(commands, "body_panel", Rect2(-97, -242, 194, 204), pose, Color("2c6a45")), "inner green body panel")
	check(polygon_matches(commands, "reflective_stripe", Rect2(-97, -150, 194, 14), pose, Color("f07a1c")), "orange reflective body stripe")
	check(polygon_matches(commands, "stripe_highlight", Rect2(-97, -144, 194, 3), pose, Color("f4e27a")), "three-pixel stripe highlight")
	check(tagged(commands, "active_arm_rib").size() == 6 and tagged(commands, "rear_arm_rib").size() == 6, "six ribs per arm")
	check(polygon_matches(commands, "mouth", Rect2(-95, -250, 190, 30), pose, Color("081a10")), "closed mouth height")
	check(tagged(commands, "eye_glow").is_empty() and tagged(commands, "left_eye").is_empty(), "closed lid conceals eyes")
	check(polygon_matches(commands, "hinged_lid", Rect2(-226, -16, 226, 18), pose * Transform2D(0, Vector2(105, -250)), Color("163a26")), "closed hinged lid source geometry")
	check(tagged(commands, "boss_sprite").is_empty() and commands.all(func(command): return command.type != "textured_polygon"), "procedural boss never borrows Jar Thief sprite")
	check(JSON.stringify(b) == original_state, "rendering never changes boss data")
	var wrapped := Boss.new()
	wrapped.state = b
	check(renderer.build_world_commands(host, wrapped) == commands, "runtime RefCounted state contract matches dictionary")

	# Poses retain seconds-based source motion and both facing directions.
	for state in ["enter", "walk", "throw", "roll", "slam", "down"]:
		for face in [-1, 1]:
			b = body_state()
			b.state = state
			b.face = face
			b.t = 0.36
			b.lid = 0.75
			commands = renderer.build_world_commands(host, b)
			var rotation: float = -0.35 * 0.72 * face if state == "down" else 0.0
			pose = Transform2D(rotation, origin)
			var step := sin(3.0) * 6 if state == "enter" or state == "walk" else 0.0
			check(polygon_matches(commands, "left_boot", Rect2(-70 + step, -40, 56, 40), pose, Color("3a2a1e")), "%s facing %s boot step and death tilt" % [state, face])
			var arm := -0.9 * 1.6 if state == "throw" or state == "roll" else sin(0.36 / 0.16) * 0.2
			var arm_transform := pose * Transform2D(arm * face, Vector2(face * 99, -190))
			var ribs := tagged(commands, "active_arm_rib")
			check(points_equal(ribs[0].points, Renderer.rect_points(Rect2(face * 2, 0, face * 26, 13), arm_transform)), "%s facing %s articulated arm" % [state, face])
			check(polygon_matches(commands, "active_hand", Rect2(0, 96, face * 34, 26), arm_transform, Color("c3c9d4")), "%s facing %s attached hand" % [state, face])
			check(polygon_matches(commands, "mouth", Rect2(-95, -250, 190, 60), pose, Color("081a10")), "%s open mouth growth" % state)
			check(polygon_matches(commands, "hinged_lid", Rect2(0 if face > 0 else -226, -16, 226, 18), pose * Transform2D(-0.9 * face, Vector2(-face * 105, -250)), Color("163a26")), "%s facing %s hinge/angle" % [state, face])
			var glow: Dictionary = tagged(commands, "eye_glow")[0]
			check(glow.colour == Color(1, 222 / 255.0, 89 / 255.0, 0.25) and glow.points[0].is_equal_approx(pose * Vector2(0, -220) + Vector2(70, 0)), "%s eye glow follows tilted center" % state)
			check(commands.find(tagged(commands, "right_eye")[0]) < commands.find(glow) and commands.find(glow) < commands.find(tagged(commands, "hinged_lid")[0]), "source eye/glow/lid order")

	b = body_state()
	b.lid = 0.3
	check(tagged(renderer.build_world_commands(host, b), "eye_glow").is_empty(), "eyes remain hidden at exact 0.3 threshold")
	b.lid = 0.3001
	check(tagged(renderer.build_world_commands(host, b), "eye_glow").size() == 1, "eyes appear strictly above 0.3")
	b.state = "down"
	b.t = 10.0
	b.flash = 0.08
	commands = renderer.build_world_commands(host, b)
	check(polygon_matches(commands, "body_shell", Rect2(-105, -250, 210, 220), Transform2D(0.35, origin), Color("1d4a30")), "death rotation caps after 500ms")
	check(tagged(commands, "hurt_flash")[0].rect == Rect2(3800, 222, 210, 260) and tagged(commands, "hurt_flash")[0].colour == Color(1, 1, 1, 0.3), "hurt flash remains unrotated outside body transform")

	# Camera-relative rounding is independent of the local pose rotations.
	host.camera = Vector2(3300.25, -0.5)
	b = body_state()
	b.x = 3300.75
	commands = renderer.build_world_commands(host, b)
	pose = Transform2D(0, Vector2(3301.25, 481.5))
	check(polygon_matches(commands, "body_shell", Rect2(-105, -250, 210, 220), pose, Color("1d4a30")), "world art snaps relative to fractional camera using source camY rounding")
	b.fy = 600.0
	commands = renderer.build_world_commands(host, b)
	check(tagged(commands, "boss_shadow")[0].points[0] == Vector2(3411.25, 597.5), "runtime fy supplies boss ground")
	host.camera = Vector2.ZERO

	# Shockwaves, tumbling wheelie bins and three recycling colors, not boxes
	# borrowed from generic enemy rendering. Markers must not double-paint bins.
	b = body_state()
	b.waves = [{"x": 3650.0, "vx": -450.0, "t": 0.1}, {"x": 3990.0, "vx": 450.0, "t": 0.2}, {"x": 3700.0, "vx": 0.0, "t": 0.0, "bin": true}]
	b.bins = [{"x": 3700.5, "y": 441.5, "rot": PI / 3, "roll": true, "hp": 2, "t": 0.2}, {"x": 3790.0, "y": 210.0, "rot": -0.8, "roll": false, "hp": 2, "t": 0.15}]
	b.rain = [{"x": 3550.5, "y": 210.5, "k": 0}, {"x": 3600.0, "y": 250.0, "k": 1}, {"x": 3700.0, "y": 290.0, "k": 2}]
	commands = renderer.build_world_commands(host, b)
	var waves := tagged(commands, "shockwave")
	check(waves.size() == 8, "two four-block shockwaves; bin marker ignored")
	for i in 4:
		check(waves[i].rect == Rect2(3644 + i * 8, 472 - (3 - i) * 7 - sin(2.0 + i) * 3, 12, 10 + (3 - i) * 4), "left shockwave block %s" % i)
		check(waves[i + 4].rect == Rect2(3984 - i * 8, 472 - (3 - i) * 7 - sin(4.0 + i) * 3, 12, 10 + (3 - i) * 4), "right shockwave block %s" % i)
	var bin_bodies := tagged(commands, "bin_body")
	check(bin_bodies.size() == 2 and tagged(commands, "bin_wheel").size() == 4, "each wheelie bin has a body/panel/lid/two wheels")
	check(points_equal(bin_bodies[0].points, Renderer.rect_points(Rect2(-30, -40, 60, 80), Transform2D(PI / 3, Vector2(3701, 442)))), "rolling bin rotates around rounded world center")
	check(points_equal(bin_bodies[1].points, Renderer.rect_points(Rect2(-30, -40, 60, 80), Transform2D(-0.8, Vector2(3790, 210)))), "airborne bin keeps full tumbling body")
	check(tagged(commands, "bin_wheel")[0].points[0].is_equal_approx(Transform2D(PI / 3, Vector2(3701, 442)) * Vector2(-18, 40) + Vector2(8, 0)), "bin wheels rotate with body")
	var scraps := tagged(commands, "scrap")
	check(scraps.size() == 3 and scraps[0].rect == Rect2(3533, 197, 36, 28), "rain geometry and source rounding")
	for k in 3:
		check(scraps[k].colour == Renderer.SCRAP_COLOURS[k], "source scrap color %s" % k)
	check(tagged(commands, "scrap_highlight")[0].rect == Rect2(3537, 201, 12, 6), "rain highlight offset")
	check(commands.find(waves[0]) < commands.find(bin_bodies[0]) and commands.find(bin_bodies[0]) < commands.find(scraps[0]), "source body/shockwave/bin/rain layer order")
	var with_hazards := JSON.stringify(b)
	check(renderer.build_world_commands(host, b) == commands and JSON.stringify(b) == with_hazards, "pause/repeated drawing is deterministic and state-preserving")

	# UI-space boss health uses the source 420px bottom bar and original font.
	var hud: Array = renderer.build_hud_commands(host, b)
	check(tagged(hud, "health_background")[0].rect == Rect2(266, 496, 428, 26), "source bottom health frame")
	check(tagged(hud, "health_background")[0].radius == 8 and tagged(hud, "health_background")[0].width == 2, "rounded background and two-pixel outline")
	check(tagged(hud, "health_fill")[0].rect == Rect2(270, 500, 420, 18), "full source health fill")
	check(tagged(hud, "boss_label")[0].text == "Binman Bot" and tagged(hud, "boss_label")[0].position == Vector2(278, 484), "source boss name and label placement")
	b.hp = 130
	b.dizzy = 1.0
	hud = renderer.build_hud_commands(host, b)
	check(tagged(hud, "health_fill")[0].rect.size.x == 210 and tagged(hud, "health_fill")[0].colour == Color("f4c542"), "health proportion and source dizzy color")
	b.hp = 1
	hud = renderer.build_hud_commands(host, b)
	check(is_equal_approx(tagged(hud, "health_fill")[0].rect.size.x, 420.0 / 260) and is_equal_approx(tagged(hud, "health_fill")[0].radius, 210.0 / 260), "near-empty fill keeps accurate width and valid rounded native polygon")
	b.hp = -1
	check(tagged(renderer.build_hud_commands(host, b), "health_fill").is_empty(), "zero/negative health has no fill")
	b.max = 0
	check(tagged(renderer.build_hud_commands(host, b), "health_fill").is_empty(), "invalid zero maximum cannot divide by zero")
	b.state = "down"
	check(renderer.build_hud_commands(host, b).is_empty(), "down boss hides health frame and label")
	b = body_state()
	renderer.draw_world(host, b)
	renderer.draw_hud(host, b)
	check(host.recorded.any(func(call): return call[0] == "polygon" and call[2] == Color("2c6a45")), "drawing calls native body polygons")
	check(host.recorded.any(func(call): return call[0] == "text" and call[1] == host.font and call[3] == "Binman Bot" and call[4] == HORIZONTAL_ALIGNMENT_LEFT), "HUD uses original font with source left alignment")
	check(host.recorded.any(func(call): return call[0] == "text_outline" and call[3] == "Binman Bot"), "boss label retains dark outline")
	check(JSON.stringify(host.meta) == source_meta, "source level metadata remains untouched")

	# Optional future original sprites get uncropped, unscaled frame pixels,
	# never an invented sprite. Test with a synthetic atlas, not shipped art.
	var synthetic := Image.create(128, 144, false, Image.FORMAT_RGBA8)
	synthetic.fill(Color.WHITE)
	host.images.binman = ImageTexture.create_from_image(synthetic)
	host.meta.binman = {"w": 32, "h": 48}
	host.images.bin = ImageTexture.create_from_image(Image.create(40, 72, false, Image.FORMAT_RGBA8))
	b.t = 0.34
	commands = renderer.build_world_commands(host, b)
	check(tagged(commands, "boss_sprite")[0].source == Rect2(64, 0, 32, 48), "optional walk sprite uses source 160ms timing")
	check(tagged(commands, "boss_sprite")[0].rect == Rect2(-16, -42, 32, 48), "optional sprite stays at full source frame resolution")
	b.state = "throw"
	b.t = 0.7
	check(tagged(renderer.build_world_commands(host, b), "boss_sprite")[0].source == Rect2(96, 48, 32, 48), "optional throw row uses source 210ms timing")
	b.state = "walk"
	b.lid = 1.0
	b.lid_t = 2.4
	check(tagged(renderer.build_world_commands(host, b), "boss_sprite")[0].source == Rect2(0, 96, 32, 48), "backup opening repairs negative source frame index")
	b.lid_t = 0.1
	check(tagged(renderer.build_world_commands(host, b), "boss_sprite")[0].source == Rect2(64, 96, 32, 48), "open animation caps at frame two")
	b.face = 1
	b.state = "down"
	b.t = 0.25
	b.flash = 0.01
	commands = renderer.build_world_commands(host, b)
	var sprite_pose := Transform2D(0, origin) * Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2.ZERO) * Transform2D(-0.125, Vector2.ZERO)
	check(points_equal(tagged(commands, "boss_sprite")[0].points, Renderer.rect_points(Rect2(-16, -42, 32, 48), sprite_pose)), "source sprite flip precedes death rotation")
	check(tagged(commands, "hurt_flash")[0].rect == Rect2(3800, 182, 210, 300) and is_equal_approx(tagged(commands, "hurt_flash")[0].colour.a, 0.35), "sprite branch retains separate hurt flash dimensions")
	b.bins = [{"x": 3700.0, "y": 442.0, "rot": 0.3}]
	commands = renderer.build_world_commands(host, b)
	check(tagged(commands, "bin_sprite")[0].source == Rect2(0, 0, 40, 72) and tagged(commands, "bin_body").is_empty(), "optional thrown bin preserves entire original image")
	host.recorded.clear()
	renderer.draw_world(host, b)
	var texture_calls: Array = host.recorded.filter(func(call): return call[0] == "texture")
	check(texture_calls.size() == 2 and texture_calls[0][4].diffuse_texture == host.images.binman, "rotated native polygon draws original atlas texture")
	check(texture_calls[0][4].texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and texture_calls[0][3][0] == Vector2(0.75, 2.0 / 3), "source nearest filter and normalized atlas coordinates")

	# Exercise actual native drawing for every pose, hazardous props, low HP,
	# optional mirrored sprites and fractional cameras. No screenshot claim.
	var draw_host := DrawHost.new()
	draw_host.meta = host.meta.duplicate(true)
	draw_host.meta.erase("binman")
	draw_host.font = host.font
	draw_host.camera = Vector2(3300.25, -0.5)
	draw_host.boss = JSON.parse_string(with_hazards)
	root.add_child(draw_host)
	for state in ["enter", "walk", "throw", "roll", "slam", "down"]:
		for face in [-1, 1]:
			draw_host.boss.state = state
			draw_host.boss.face = face
			draw_host.boss.t = 0.4
			draw_host.boss.flash = 0.08
			draw_host.boss.lid = 1.0
			draw_host.boss.hp = 1
			draw_host.queue_redraw()
			await process_frame
			await process_frame
	check(draw_host.draw_count >= 12, "all procedural poses reach real headless CanvasItem callbacks")
	draw_host.meta = host.meta
	draw_host.images = host.images
	draw_host.boss = b
	draw_host.queue_redraw()
	await process_frame
	await process_frame
	check(draw_host.draw_count >= 13, "optional sprite texture polygons reach CanvasItem callbacks")
	draw_host.queue_free()
	await process_frame
	renderer.clear_cache()
	if failures.is_empty():
		print("Binman renderer passed: %d assertions; source procedural geometry, poses, props, health HUD, optional original assets and headless draw callbacks. No screenshot/device QA." % assertions)
	else:
		printerr("Binman renderer failed %d/%d assertions." % [failures.size(), assertions])
	quit(0 if failures.is_empty() else 1)
