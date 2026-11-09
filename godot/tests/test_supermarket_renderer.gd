extends SceneTree
## Source geometry/resource/real CanvasItem command checks. Headless execution
## is not screenshot comparison, mobile rendering QA, or a stage clear test.
const Renderer = preload("res://src/supermarket_renderer.gd")

class Host extends RefCounted:
	var level_id := "2-1"
	var meta: Dictionary = {}
	var level: Dictionary = {}
	var images: Dictionary = {}
	var sheets: Dictionary = {}
	var camera := Vector2.ZERO
	var player := Vector2(300, 482)
	var elapsed := 0.0
	var font: Font = load("res://assets/fonts/silk.woff2")
	var recorded: Array = []
	func view_width() -> float: return 738.0
	func view_top() -> float: return camera.y + 540 - 540 / 1.3
	func draw_texture_rect_region(texture, rect, source, colour): recorded.append(["texture", texture, rect, source, colour])
	func draw_rect(rect, colour): recorded.append(["rect", rect, colour])
	func draw_colored_polygon(points, colour): recorded.append(["polygon", points, colour])
	func draw_polygon(points, colours): recorded.append(["gradient", points, colours])
	func draw_polyline(points, colour, width): recorded.append(["line", points, colour, width])
	func draw_style_box(style, rect): recorded.append(["rounded", style, rect])
	func draw_string(font_resource, position, text, alignment, width, size, colour): recorded.append(["text", font_resource, position, text, alignment, width, size, colour])

class DrawHost extends Node2D:
	var renderer = Renderer.new()
	var level_id := "2-1"
	var meta: Dictionary = {}
	var level: Dictionary = {}
	var images: Dictionary = {}
	var sheets: Dictionary = {}
	var camera := Vector2.ZERO
	var player := Vector2(300, 482)
	var elapsed := 0.05
	var font: Font = load("res://assets/fonts/silk.woff2")
	var runtime: Dictionary = {}
	var bots: Array = []
	var draw_count := 0
	func view_width() -> float: return 738.0
	func view_top() -> float: return camera.y + 540 - 540 / 1.3
	func _draw() -> void:
		draw_set_transform(Vector2(-camera.x * 1.3, 540 * (1 - 1.3) - camera.y * 1.3), 0, Vector2.ONE * 1.3)
		renderer.draw_sky(self, runtime)
		renderer.draw_level(self, runtime)
		renderer.draw_mid(self, runtime)
		for bot in bots: renderer.draw_enemy(self, bot)
		renderer.draw_player_back(self)
		renderer.draw_player_front(self)
		renderer.draw_front(self, runtime)
		draw_set_transform(Vector2.ZERO)
		renderer.draw_hud(self, runtime)
		draw_count += 1

var assertions := 0
var failures: Array[String] = []
var renderer = Renderer.new()

func check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)

func tagged(commands: Array, tag: String) -> Array:
	return commands.filter(func(command): return command.tag == tag)

func close_colour(a: Color, b: Color) -> bool:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), maxf(absf(a.b - b.b), absf(a.a - b.a))) <= 1.0 / 255 + 0.00001

func load_stage(host) -> void:
	host.meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/2-1.json"))
	host.level = host.meta.level
	for key in host.meta.imgs:
		host.images[key] = load(host.meta.imgs[key])
		check(host.images[key].get_size() == Vector2(host.meta.dims[key][0], host.meta.dims[key][1]), "preserves original image dimensions " + key)
	host.sheets.bot = load("res://assets/sprites/bot-sheet.png")

func bot(kind: String, position: Vector2 = Vector2(300, 482)) -> Dictionary:
	return {"p": position, "kind": kind, "type": kind, "state": "cart" if kind == "cart" else ("drone" if kind == "drone" else "walk"),
		"face": -1, "big": kind == "big", "hp": 12, "max_hp": 24, "t": 0.3, "flash": 0.0, "gone": 0.0, "base_y": 482,
		"stride": 28.0, "visual_move": -1 if kind not in ["cart", "drone"] else 0}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host := Host.new()
	load_stage(host)
	var state := {"scene_index": 0, "entities": [], "elapsed": 0.0, "wiping": false}
	var original: String = JSON.stringify(host.meta)
	check(renderer.supports("2-1") and not renderer.supports("2-2") and not renderer.supports("1-1"), "only parking painter claims support")
	check(Renderer.source_round(-0.5) == 0 and Renderer.source_round(-1.5) == -1, "source JS negative half rounding")
	check(renderer.crop_region(host, "topdeck", Rect2(0.164, 0.3, 0.329, 0.17)) == Rect2(208, 226, 417, 128), "independent rounded source crop coordinates")
	check(renderer.crop_region(host, "missing", Rect2(0, 0, 1, 1)) == Rect2(), "missing crop safely empty")
	var sky: Array = renderer.build_sky(host, state)
	check(tagged(sky, "topdeck_sky")[0].source == Rect2(208, 0, 417, 226), "exact far sky crop excludes lamp poles")
	check(tagged(sky, "topdeck_sky")[0].rect == Rect2(0, -35, 417, 226), "source top deck 0.62 ground anchor")
	check(tagged(sky, "topdeck_town")[0].source == Rect2(208, 226, 417, 128), "town crop at30 to47 percent")
	check(tagged(sky, "topdeck_town")[0].rect == Rect2(0, 191, 417, 128), "town drawn under far sky")
	check(tagged(sky, "topdeck_deck")[0].source == Rect2(0, 354, 1266, 399), "deck47 percent crop")
	check(tagged(sky, "topdeck_deck")[0].rect == Rect2(0, 319, 1266, 399), "deck original native scale")
	check(tagged(sky, "topdeck_lamp_head")[0].rect == Rect2(119, 101, 82, 218), "first restored lamp head aligns with floor speed pole")
	check(tagged(sky, "topdeck_lamp_head").size() == 2, "only visible lamp heads emitted")
	for camera_x in [0.0, 1265.5, 1266.0, 1400.25, 2527.5, 7162.0]:
		host.camera = Vector2(camera_x, -32.25)
		sky = renderer.build_sky(host, state)
		for tag in ["topdeck_sky", "topdeck_town", "topdeck_deck"]:
			var factor: float = {"topdeck_sky": 0.05, "topdeck_town": 0.2, "topdeck_deck": 1.0}[tag]
			for command in tagged(sky, tag):
				check(command.rect.position.x == camera_x + Renderer.source_round(command.index * command.source.size.x - camera_x * factor), "camera/factor rounded crop placement " + tag)
				check(command.flip_h == (command.index % 2 != 0), "alternating mirrored row " + tag)
				check(command.rect.size == command.source.size, "no stretched deck crop " + tag)
		for lamp in tagged(sky, "topdeck_lamp_head"):
			var a: float = Renderer.LAMP_RANGES[lamp.lamp][0]
			var x0: float = 1266 - Renderer.source_round(a * 1266) - lamp.rect.size.x if lamp.flip_h else Renderer.source_round(a * 1266)
			check(lamp.rect.position.x == camera_x + Renderer.source_round(lamp.index * 1266 + x0 - camera_x), "mirrored heads align with mirrored deck tiles")
			check(lamp.rect.position.y == 100.75, "sky compensates fractional vertical camera")
	host.camera = Vector2(6800, 0)
	var level_commands := renderer.build_level(host, state)
	check(tagged(level_commands, "lift")[0].rect == Rect2(7492, 134, 304, 350), "lift appears once at authored top-deck transition")
	check(tagged(level_commands, "lift_shadow")[0].rect == Rect2(7488, 478, 312, 8), "lift ground contact shadow")
	check(tagged(level_commands, "surface_lamp").is_empty(), "painting lamps are not duplicated")
	check(tagged(level_commands, "surface_floor").is_empty(), "painted deck is not covered by a generic floor")
	host.camera = Vector2(700, -0.25)
	level_commands = renderer.build_level(host, state)
	check(tagged(level_commands, "parked_car")[0].key == "car-hatch-1", "car seed selects imported variant")
	check(tagged(level_commands, "parked_car")[0].rect == Rect2(900, 320.75, 300, 165), "car ground-imageHeight+4 preserves roof alignment")
	host.camera.x = 3500
	level_commands = renderer.build_level(host, state)
	check(tagged(level_commands, "parked_car").any(func(c): return c.key == "car-van-0"), "odd van seed falls back to available original painting")
	state.scene_index = 1
	check(tagged(renderer.build_level(host, state), "parked_car").is_empty(), "top-deck cars hidden in surface scene regardless camera")
	host.camera = Vector2(8200.25, -32.25)
	state.elapsed = 10.0
	sky = renderer.build_sky(host, state)
	var frontage := tagged(sky, "surface_frontage")
	check(not frontage.is_empty() and frontage[0].source == Rect2(0, 0, 235, 635), "surface frontage excludes unique entrance")
	for command in frontage:
		check(command.rect.position.x == host.camera.x + Renderer.source_round(command.index * 235 - host.camera.x * 0.3), "surface frontage0.3 parallax")
		check(command.rect.position.y == -63.25, "surface frontage0.25 vertical parallax")
		check(command.flip_h == (command.index % 2 != 0), "surface mirrored join")
	check(tagged(sky, "surface_sky_band").is_empty(), "offscreen source sky band is culled without moving frontage")
	host.camera.y = -1000
	var surface_sky: Dictionary = tagged(renderer.build_sky(host, state), "surface_sky_band")[0]
	check(surface_sky.source == Rect2(0, 0, 897, 70), "surface sky11 percent crop")
	check(surface_sky.rect.size == Vector2(1025, 80), "sky band resized with original aspect")
	check(surface_sky.rect.position == Vector2(7924.25, -855), "sky parallax and3pixels per second drift")
	host.camera.y = -32.25
	level_commands = renderer.build_level(host, state)
	check(tagged(level_commands, "lift").is_empty(), "lift does not leak to ground-floor scene")
	check(tagged(level_commands, "parked_car")[0].world_x >= 7600, "only ground-floor car scene")
	check(tagged(level_commands, "surface_lamp")[0].rect.position == Vector2(8335.25, 11.75), "surface lamp original placement")
	check(tagged(level_commands, "lamp_glow")[0].center == Vector2(8403.25, 41.75), "surface lamp glow source anchor")
	host.camera = Vector2(15000, 0)
	level_commands = renderer.build_level(host, state)
	check(tagged(level_commands, "shop_entrance")[0].source == Rect2(235, 51, 483, 321), "unique entrance exact source crop")
	check(tagged(level_commands, "shop_entrance")[0].rect == Rect2(15250, 39, 676, 449), "entrance single1.4scale placement")
	host.camera = Vector2(8200, 0)
	check(tagged(renderer.build_level(host, state), "shop_entrance").is_empty(), "entrance never repeats along frontage")

	# Hazards use the procedural trolley, not a supporting platform or car.
	host.camera = Vector2(2600.25, -0.25)
	state.entities = [{"k": "tspawn", "on": true, "t": 0.5}, {"k": "trolley", "p": Vector2(3000.5, 482), "v": Vector2(-400, 0), "t": 0.0, "dead": false}]
	var entity_before := JSON.stringify(state)
	var mid := renderer.build_mid(host, state)
	check(tagged(mid, "trolley_mesh").size() == 14, "trolley9vertical5horizontal wire mesh")
	check(tagged(mid, "trolley_wheel").size() == 2, "trolley has2eight-pixel wheels")
	check(tagged(mid, "trolley_wheel")[0].center == Vector2(3032.25, 475.75), "negative speed mirrors trolley handle/wheels")
	check(tagged(mid, "trolley_basket")[0].points == PackedVector2Array([Vector2(3046.25, 391.75), Vector2(2948.25, 391.75), Vector2(2956.25, 443.75), Vector2(3036.25, 443.75)]), "source trolley basket silhouette and104px vertical anchor")
	check(renderer.build_mid(host, state) == mid and JSON.stringify(state) == entity_before, "render count never mutates trolley time or spawners")
	state.entities[1].v.x = 400
	check(tagged(renderer.build_mid(host, state), "trolley_wheel")[0].center.x == 2968.25, "positive speed preserves rightward trolley orientation")
	state.entities[1].t = PI * 0.025
	var tilted := tagged(renderer.build_mid(host, state), "trolley_wheel")[0].center as Vector2
	var expected := Vector2(3000.25, 429.75) + Vector2(-32, 46).rotated(0.03)
	check(tilted.distance_to(expected) < 0.0001, "trolley wobble uses seconds50ms sine period")
	state.entities[1].dead = true
	check(renderer.build_mid(host, state).is_empty(), "dead trolley not painted")
	var order: Array = []
	renderer.draw_mid(host, state, func(): order.append("pickup"))
	check(order == ["pickup"], "pickup callback invoked once after shared mid")

	# All W2 foes use the bot sprite with source overlays and simulation stride.
	host.camera = Vector2.ZERO
	host.elapsed = PI * 0.015
	for kind in ["rush", "throw", "flat", "cart", "drone", "big"]:
		var b := bot(kind)
		var before := b.duplicate(true)
		var commands := renderer.build_enemy(host, b)
		var body: Dictionary = tagged(commands, "security_bot" if kind == "big" else "bot_sprite")[0]
		check(body.source.position == Vector2((3 if kind not in ["cart", "drone"] else 5) * 226, 0), kind + " uses movement stride or standing frame5")
		check(body.rect.size == (Vector2(375, 232) if kind == "big" else Vector2(226, 140)), kind + " source sprite dimensions")
		check(b == before and renderer.build_enemy(host, b) == commands, kind + " render does not mutate bot pose")
		check(renderer.draw_enemy(host, b), kind + " renderer owns W2 bot path")
		if kind == "big":
			check(tagged(commands, "security_health")[0].rect.size == Vector2(44, 6), "security half-health red bar")
			check(tagged(commands, "security_cap").size() == 1, "security peaked cap present")
		if kind == "cart": check(tagged(commands, "trolley_mesh").size() == 14, "cart overlays its ordinary bot with trolley")
		if kind == "drone":
			check(tagged(commands, "drone_propeller")[0].rect.size == Vector2(68, 4), "drone procedural propeller maximum width")
			check(tagged(commands, "drone_ground_shadow")[0].center == Vector2(300, 480), "drone ground shadow uses spawn base")
		b.state = "pop"
		b.t = 0.6
		b.gone = 1.05
		commands = renderer.build_enemy(host, b)
		body = tagged(commands, "security_bot" if kind == "big" else "bot_sprite")[0]
		check(body.source.position == Vector2(678, 280) and is_equal_approx(body.alpha, 0.5), kind + " source pop frame and800to1300ms fade")
		check(tagged(commands, "security_cap").is_empty() and tagged(commands, "drone_propeller").is_empty() and tagged(commands, "trolley_mesh").is_empty(), kind + " pop hides extra actor props")
	var flash := bot("big")
	flash.flash = 0.1
	renderer.draw_enemy(host, flash)
	check(renderer._sprite_variants.size() >= 2, "security tint and white flash cached without changing original sheet")
	var security_commands := renderer.build_enemy(host, bot("big"))
	var security: Dictionary = tagged(security_commands, "security_bot")[0]
	check(security.rect == Rect2(112, 255, 375, 232) and not security.flip_h, "security1.66scale top and rounded left anchor")
	var mirrored := bot("big")
	mirrored.face = 1
	var mirrored_body: Dictionary = tagged(renderer.build_enemy(host, mirrored), "security_bot")[0]
	check(mirrored_body.rect == Rect2(113, 255, 375, 232) and mirrored_body.flip_h, "odd375px security reflection preserves original translated anchor")
	var original_image: Image = host.sheets.bot.get_image().get_region(Rect2i(security.source))
	var tint: Image = renderer._variant(security).get_image()
	var white_command: Dictionary = tagged(renderer.build_enemy(host, flash), "security_bot")[0]
	var white_image: Image = renderer._variant(white_command).get_image()
	var checked_body := false
	var checked_stripe := false
	for y in original_image.get_height():
		if checked_body and checked_stripe: break
		for x in original_image.get_width():
			var pixel := original_image.get_pixel(x, y)
			if pixel.a < 0.8: continue
			var stripe := y >= 77 and y < 84
			if (stripe and checked_stripe) or (not stripe and checked_body): continue
			var expected_pixel := pixel.lerp(Color("1c2c56"), 0.5)
			if stripe: expected_pixel = expected_pixel.lerp(Color("f4c542"), 0.85)
			expected_pixel.a = pixel.a
			check(close_colour(tint.get_pixel(x, y), expected_pixel), "source-atop security tint with alpha preserved" + (" stripe" if stripe else " body"))
			var expected_flash := expected_pixel.lerp(Color.WHITE, 0.7)
			expected_flash.a = pixel.a
			check(close_colour(white_image.get_pixel(x, y), expected_flash), "70percent flash overlays tinted security pixels" + (" stripe" if stripe else " body"))
			if stripe: checked_stripe = true
			else: checked_body = true
			break
	check(checked_body and checked_stripe, "pixel regression exercised body and uniform stripe")
	check(renderer._nearest(host.sheets.bot).texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "sprite and painting sampling remains source nearest without host mutation")
	host.level_id = "1-1"
	check(not renderer.draw_enemy(host, bot("rush")) and renderer.build_sky(host, state).is_empty(), "unrelated worlds retain own renderer")
	host.level_id = "2-1"
	host.camera = Vector2(500, -0.25)
	var front := renderer.build_front(host, state)
	check(tagged(front, "foreground_bollard")[0].rect == Rect2(750, 501.75, 26, 46), "source foreground is low bollard at1.3parallax")
	check(tagged(front, "foreground_bollard_cap")[0].center.y - 6 > 494, "foreground never becomes full-height occluding pillar")

	# Scene wipe is UI-space visual only. Runtime owns1.43s callback and2.17s end.
	state.merge({"wiping": true, "wipe_elapsed": 0.0, "wipe_kind": "lift", "wipe_label": "Ground floor", "wipe_focus_start": Vector2(700, 324), "wipe_focus_end": Vector2(211.2, 324)}, true)
	check(renderer.build_hud(host, state).is_empty(), "wipe starts with open view")
	state.wipe_elapsed = 0.26
	var hud := renderer.build_hud(host, state)
	check(tagged(hud, "wipe_iris")[0].center == Vector2(700, 324), "closing iris uses captured departure focus")
	check(is_equal_approx(tagged(hud, "wipe_dim")[0].colour.a, 0.0875), "half-closed iris whole-screen dim")
	for time in [0.52, 1.0, 1.43, 1.56]:
		state.wipe_elapsed = time
		hud = renderer.build_hud(host, state)
		check(tagged(hud, "wipe_cover")[0].rect == Rect2(0, 0, 960, 540), "scene is fully covered at %.2f" % time)
		check(tagged(hud, "wipe_iris").is_empty(), "no iris reveal during source hold %.2f" % time)
	state.wipe_elapsed = 1.0
	check(tagged(renderer.build_hud(host, state), "wipe_label")[0].text == "Ground floor", "lift destination label source text")
	state.wipe_elapsed = 1.43
	check(tagged(renderer.build_hud(host, state), "wipe_label")[0].colour.a > 0 and tagged(renderer.build_hud(host, state), "wipe_label")[0].colour.a < 1, "card departing at callback while scene remains covered")
	state.wipe_elapsed = 1.87
	hud = renderer.build_hud(host, state)
	check(tagged(hud, "wipe_iris")[0].center == Vector2(211.2, 324), "opening iris uses captured landing focus")
	check(tagged(hud, "wipe_label").is_empty(), "destination card gone before opening")
	state.wipe_elapsed = 2.17
	check(renderer.build_hud(host, state).is_empty(), "iris disappears exactly at source2170ms")
	check(JSON.stringify(host.meta) == original, "all draw passes preserve imported source metadata")

	# Exercise every primitive on an actual CanvasItem to catch invalid draw
	# commands, including zero-width propeller and full iris boundaries.
	var canvas := DrawHost.new()
	load_stage(canvas)
	root.add_child(canvas)
	canvas.bots = [bot("rush"), bot("big", Vector2(500, 482)), bot("cart", Vector2(150, 482)), bot("drone", Vector2(650, 282))]
	for scene in [0, 1]:
		canvas.runtime = {"scene_index": scene, "entities": [{"k": "trolley", "p": Vector2(450, 482), "v": Vector2(-400, 0), "t": 0.08}], "wiping": true, "wipe_elapsed": 0.26, "wipe_label": "Ground floor"}
		canvas.queue_redraw()
		await process_frame
		await process_frame
	check(canvas.draw_count >= 2, "actual Node2D draw callbacks execute all parking and iris primitives")
	canvas.queue_free()
	await process_frame
	print("Supermarket renderer checks: %d assertions; %d failures. Geometry/command QA only, not screenshots or devices." % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
