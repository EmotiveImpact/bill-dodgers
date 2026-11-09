extends SceneTree
## Source crops, geometry, clocks and real CanvasItem callback checks only.
## Headless execution cannot certify screenshot, mobile or gameplay parity.
const Renderer = preload("res://src/aisle_renderer.gd")

class Host extends RefCounted:
	var level_id := "2-2"
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
	func draw_string_outline(font_resource, position, text, alignment, width, size, outline, colour): recorded.append(["text_outline", font_resource, position, text, alignment, width, size, outline, colour])

class DrawHost extends Node2D:
	var renderer = Renderer.new()
	var level_id := "2-2"
	var meta: Dictionary = {}
	var level: Dictionary = {}
	var images: Dictionary = {}
	var sheets: Dictionary = {}
	var camera := Vector2.ZERO
	var player := Vector2(300, 482)
	var elapsed := 0.0
	var font: Font = load("res://assets/fonts/silk.woff2")
	var runtime: Dictionary = {}
	var bots: Array = []
	var draw_count := 0
	var pickup_count := 0
	func view_width() -> float: return 738.0
	func view_top() -> float: return camera.y + 540 - 540 / 1.3
	func _draw() -> void:
		draw_set_transform(Vector2(-camera.x * 1.3, 540 * (1 - 1.3) - camera.y * 1.3), 0, Vector2.ONE * 1.3)
		renderer.draw_sky(self, runtime)
		renderer.draw_level(self, runtime)
		renderer.draw_mid(self, runtime, func(): pickup_count += 1)
		for bot in bots: renderer.draw_enemy(self, bot)
		renderer.draw_player_back(self)
		renderer.draw_player_front(self)
		renderer.draw_front(self, runtime)
		draw_set_transform(Vector2.ZERO)
		renderer.draw_hud(self, runtime)
		draw_count += 1

class Controller extends RefCounted:
	var gates: Array = []
	var plates: Array = []
	var buttons: Array = []

var renderer = Renderer.new()
var assertions := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)

func tagged(commands: Array, tag: String) -> Array:
	return commands.filter(func(command): return command.tag == tag)

func load_stage(host) -> void:
	host.meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/2-2.json"))
	host.level = host.meta.level
	for key in host.meta.imgs:
		host.images[key] = load(host.meta.imgs[key])
		check(host.images[key].get_size() == Vector2(host.meta.dims[key][0], host.meta.dims[key][1]), "original painting dimensions " + key)
	host.sheets.bot = load("res://assets/sprites/bot-sheet.png")

func bot(kind: String = "rush") -> Dictionary:
	return {"p": Vector2(300, 482), "kind": kind, "type": kind, "state": "walk", "face": -1, "big": kind == "big", "hp": 12, "max_hp": 24, "t": 0.3, "flash": 0.0, "gone": 0.0, "stride": 28.0, "visual_move": -1}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host := Host.new()
	load_stage(host)
	var original := JSON.stringify(host.meta)
	var state := {"scene_index": 0, "elapsed": 0.0, "entities": [], "wiping": false}
	check(renderer.supports("2-2") and not renderer.supports("2-1") and not renderer.supports("2-3") and not renderer.supports("1-1"), "only aisle painter claims support")
	var sky := renderer.build_sky(host, state)
	var ceil_command: Dictionary = tagged(sky, "aisle_ceiling")[0]
	check(ceil_command.key == "aisle" and ceil_command.source == Rect2(0, 0, 293, 101), "ceiling crop excludes painted number7 sign")
	check(ceil_command.rect.position == Vector2(0, 104) and ceil_command.rect.size.is_equal_approx(Vector2(294, 101.42)), "ceiling uses fractional22percent height and resized aspect")
	check(tagged(sky, "aisle_wall")[0].source == Rect2(0, 101, 651, 360), "wall and painted floor crop at22percent")
	check(tagged(sky, "aisle_wall")[0].rect == Rect2(0, 205, 651, 360), "painted floor line stays at original0.82 height anchor")
	check(tagged(sky, "aisle_sign_number")[0].text == "7" and tagged(sky, "aisle_sign_number")[0].position == Vector2(560, 166), "independent source number7 sign geometry")
	check(sky.find(tagged(sky, "aisle_ceiling")[0]) < sky.find(tagged(sky, "aisle_sign")[0]) and sky.find(tagged(sky, "aisle_sign_number")[0]) < sky.find(tagged(sky, "aisle_wall")[0]), "ceiling-sign-wall paint order")
	for cx in [0.0, 293.5, 651.0, 2600.25, 9900.75, 11800.5]:
		for cy in [0.0, -32.25, -400.5]:
			host.camera = Vector2(cx, cy)
			for scene in [0, 1]:
				state.scene_index = scene
				sky = renderer.build_sky(host, state)
				for tag in ["aisle_ceiling", "aisle_wall"]:
					for command in tagged(sky, tag):
						var factor := 0.6 if tag == "aisle_ceiling" else 1.0
						check(command.rect.position.x == cx + Renderer.source_round(command.index * command.rect.size.x - cx * factor), "rounded horizontal parallax " + tag)
						check(command.flip_h == (command.index % 2 != 0), "alternating painting mirror " + tag)
						var expected_y: float = cy + Renderer.source_round(482 - 0.82 * 461 - cy + (0.22 * 461 if tag == "aisle_wall" else 0))
						check(is_equal_approx(command.rect.position.y, expected_y), "fractional vertical camera round " + tag)
						check(command.key == ("aisle" if scene == 0 else "freezer"), "scene painting selection " + tag)
	state.scene_index = 1
	host.camera = Vector2.ZERO
	sky = renderer.build_sky(host, state)
	check(tagged(sky, "aisle_ceiling")[0].source == Rect2(0, 0, 651, 101), "freezer ceiling keeps full painting width")
	check(tagged(sky, "aisle_sign_number")[0].text == "8", "frozen section source number8 sign")
	state.scene_index = 0
	host.camera = Vector2(700, -0.25)
	var level := renderer.build_level(host, state)
	var bays := tagged(level, "island_bay")
	check(bays.size() == 2 and bays[0].source == Rect2(42, 212, 182, 145), "island crops the same shelf painting")
	check(bays[0].rect == Rect2(900, 255.75, 284, 226) and not bays[0].flip_h, "island top and bay scale preserve authored climbing heights")
	check(bays[1].rect == Rect2(1184, 255.75, 216, 226) and bays[1].flip_h, "last island tile is clipped rather than squashed")
	check(is_equal_approx(bays[1].source.end.x, 224) and is_equal_approx(bays[1].source.size.x, 182.0 * 216 / 284), "mirrored clipped island selects right source pixels")
	check(tagged(level, "island_shadow")[0].rect == Rect2(894, 477.75, 522, 12), "source island ground shadow")
	check(tagged(level, "island_frame")[0].rect == Rect2(900, 245.75, 500, 12), "island top is236pixels above ground")
	check(tagged(level, "island_frame").any(func(c): return c.rect == Rect2(900, 477.75, 500, 4)), "island base at ground minus4")
	check(level.all(func(c): return c.tag != "floor_tiles"), "no replacement checkerboard covers original painted floor")
	state.scene_index = 1
	check(tagged(renderer.build_level(host, state), "island_bay").is_empty(), "aisle islands are hidden after scene change")
	host.camera = Vector2(10800, 0)
	level = renderer.build_level(host, state)
	bays = tagged(level, "island_bay")
	check(bays.size() == 2 and bays[0].source == Rect2(29, 124, 212, 226), "frozen island uses original freezer doors crop")
	check(bays[0].rect == Rect2(11100, 256, 212, 226) and bays[1].rect == Rect2(11312, 256, 188, 226), "freezer island repeated cropped doors preserve source scale")
	check(tagged(level, "island_frame")[0].colour == Color("9aa5b8"), "freezer island silver frame")
	host.camera = Vector2(9900.25, -0.25)
	state.scene_index = 0
	level = renderer.build_level(host, state)
	check(tagged(level, "strip_doors")[0].rect == Rect2(10279.25, 155.75, 242, 330), "original strip door painting anchors at authored10400 transition")
	check(tagged(level, "strip_door_shadow")[0].rect == Rect2(10279.25, 477.75, 242, 8), "strip door floor shadow")
	state.scene_index = 1
	check(tagged(renderer.build_level(host, state), "strip_doors").is_empty(), "strip doors exist only before frozen scene")
	state.scene_index = 0
	var strip: Texture2D = host.images.strip
	host.images.erase("strip")
	var fallback := renderer.build_level(host, state)
	check(tagged(fallback, "strip_door_fallback_strip").size() == 9, "source nine animated fallback strips")
	check(tagged(fallback, "strip_door_fallback_text")[0].position == Vector2(10400.25, 181.75) and tagged(fallback, "strip_door_fallback_text")[0].type == "text", "fallback frozen placard uses source play middle baseline")
	renderer.draw_commands(host, fallback)
	state.elapsed = 0.5
	check(tagged(fallback, "strip_door_fallback_strip") != tagged(renderer.build_level(host, state), "strip_door_fallback_strip"), "fallback sway uses500ms source divisor")
	host.images.strip = strip
	var aisle_image: Texture2D = host.images.aisle
	host.images.erase("aisle")
	check(tagged(renderer.build_sky(host, state), "missing_painting_fill").size() == 1, "missing background gives explicit source plain fill")
	host.images.aisle = aisle_image

	# Before controller integration, authored controls paint closed and inert.
	host.camera = Vector2(2200, -350)
	var mid := renderer.build_mid(host, state)
	check(tagged(mid, "gate_shelf_frame")[0].rect == Rect2(2464, -78, 72, 568), "authored560pixel sliding shelf fallback geometry")
	check(tagged(mid, "gate_product").size() == 31, "gate source seeded stocking count")
	check(tagged(mid, "gate_product")[0].rect == Rect2(2474, -48, 12, 46) and tagged(mid, "gate_product")[0].colour == Color("1fa39a"), "first source LCG product geometry and palette")
	check(tagged(mid, "gate_product_label")[1].rect == Rect2(2490, -27, 7, 3), "source R0 rounds fractional package labels")
	check(tagged(mid, "gate_timer").is_empty(), "unwired controller never invents countdown progress")
	var controls := {"gates": [{"x": 2500, "floor": 482, "h": 560, "id": 0, "open": 0.5, "timer": 2.6, "held": false}], "plates": [{"x": 2400, "y": 482, "id": 0, "on": false}], "buttons": [{"x": 2600, "y": 152, "id": 0, "hit": 0.0}]}
	state.hazard_controller = controls
	state.elapsed = 0.45
	mid = renderer.build_mid(host, state)
	check(tagged(mid, "gate_shelf_frame")[0].rect == Rect2(2464, -378, 72, 568), "half-open source shelf lifts300pixels")
	check(tagged(mid, "gate_rail")[0].rect.position.is_equal_approx(Vector2(2460, host.view_top() - 10)), "rails use source view top rather than screen top")
	check(tagged(mid, "gate_timer")[0].center == Vector2(2500, -138) and is_equal_approx(tagged(mid, "gate_timer")[0].sweep, 6.283 / 2), "source countdown always divides by5.2seconds")
	check(is_equal_approx(tagged(mid, "gate_timer")[0].start, -1.57) and tagged(mid, "gate_timer")[0].width == 5, "source countdown start angle and thickness")
	check(tagged(mid, "pressure_plate_arrow").is_empty(), "plate arrow requires gate strictly belowhalf")
	controls.gates[0].open = 0.499
	mid = renderer.build_mid(host, state)
	check(tagged(mid, "pressure_plate_arrow").size() == 1, "closed pad source400ms flash")
	check(tagged(mid, "pressure_plate")[0].rect == Rect2(2352, 475, 96, 10), "released plate source dimensions")
	check(tagged(mid, "pressure_plate_groove").size() == 5 and tagged(mid, "pressure_plate_groove")[0].rect.size == Vector2(7, 8), "plate five source grooves")
	check(tagged(mid, "gate_button")[0].colour == Color("3fbf6e"), "button bright source300ms cycle")
	state.elapsed = 0.29
	check(tagged(renderer.build_mid(host, state), "gate_button")[0].colour == Color("2d8f52"), "button dark before300ms")
	controls.buttons[0].hit = 0.3
	check(tagged(renderer.build_mid(host, state), "gate_button")[0].colour == Color.WHITE, "button shot flash has priority over blink")
	controls.gates[0].open = 0.501
	check(tagged(renderer.build_mid(host, state), "gate_button")[0].colour == Color("9fe0b8"), "open gate green overrides hit flash")
	controls.gates[0].timer = 6.5
	check(is_equal_approx(tagged(renderer.build_mid(host, state), "gate_timer")[0].sweep, 6.283), "6500ms button timer clamps countdown atfull")
	controls.gates[0].held = true
	controls.plates[0].on = true
	mid = renderer.build_mid(host, state)
	check(tagged(mid, "gate_timer").is_empty(), "held gate hides countdown ring")
	check(tagged(mid, "pressure_plate")[0].rect == Rect2(2352, 479, 96, 6) and tagged(mid, "pressure_plate")[0].colour == Color("9fe0b8"), "pressed plate lowers and changes colour")
	check(tagged(mid, "pressure_plate_groove")[0].rect == Rect2(2360, 480, 7, 4), "pressed grooves flatten to4pixels")
	var object_controller := Controller.new()
	object_controller.gates = controls.gates
	object_controller.plates = controls.plates
	object_controller.buttons = controls.buttons
	state.hazard_controller = object_controller
	check(renderer.build_mid(host, state) == mid, "live component object and snapshot dictionary share contract")
	state.hazard_controller = {"gates": [], "plates": [], "buttons": []}
	check(tagged(renderer.build_mid(host, state), "gate_shelf_frame").is_empty(), "present empty controller does not revive fallback gates")

	# Ice remains a thin highlight over the frozen-floor painting.
	host.camera = Vector2(10800.25, -0.25)
	state.scene_index = 1
	mid = renderer.build_mid(host, state)
	check(tagged(mid, "ice_reflection")[0].rect == Rect2(10800.25, 479.75, 2900, 6), "ice zone source6pixel overlay")
	check(tagged(mid, "ice_glint").size() == 32 and tagged(mid, "ice_glint")[0].rect == Rect2(10840.25, 481.75, 26, 2), "source90pixel reflection spacing and modulo phase")
	# No belts are authored in2-2; exercise shared hook without modifying META.
	state.hazards = [["belt", 10800, 11200, 482, -0.12]]
	state.elapsed = 0.1
	mid = renderer.build_mid(host, state)
	check(tagged(mid, "belt_tread")[0].rect == Rect2(10812.25, 482.75, 10, 3), "negative source belt speed wraps24pixel tread")
	check(tagged(mid, "belt_arrow")[0].points == PackedVector2Array([Vector2(10850.25, 493.75), Vector2(10866.25, 488.75), Vector2(10866.25, 498.75)]), "belt direction and source arrow shape")
	state.erase("hazards")

	var drop := {"k": "drop", "p": Vector2(11100.5, 300.4), "top": 482, "vy": 0.0, "warn": 0.95, "t": 0.475, "kind": "box", "dead": false}
	state.entities = [drop]
	mid = renderer.build_mid(host, state)
	check(tagged(mid, "drop_shadow")[0].center == Vector2(11100.25, 479.75) and tagged(mid, "drop_shadow")[0].radius == Vector2(24, 5), "warning shadow halfage has24pixel radius")
	check(is_equal_approx(tagged(mid, "drop_shadow")[0].colour.a, 0.3), "warning shadow alpha grows from0.15to0.45")
	check(tagged(mid, "falling_box").is_empty() and tagged(mid, "drop_warning").size() == 1, "warning is visible but object hidden before950ms")
	check(tagged(mid, "drop_warning")[0].position.is_equal_approx(Vector2(11100.25, host.view_top() + 99.75)), "warning remains100pixels below source view top")
	for row in [[0.0, false], [0.119, false], [0.12, true], [0.24, false], [0.36, true], [0.949, true]]:
		drop.t = row[0]
		check((not tagged(renderer.build_mid(host, state), "drop_warning").is_empty()) == row[1], "source120ms warning flash at%.3f" % row[0])
	drop.t = 0.95
	mid = renderer.build_mid(host, state)
	check(tagged(mid, "drop_warning").is_empty() and tagged(mid, "falling_box").size() == 5, "drop appears at inclusive950ms warning boundary")
	check(tagged(mid, "falling_box")[0].rect == Rect2(11068.25, 241.75, 64, 58), "box source sprite anchors at bottom minus58 rounded")
	check(tagged(mid, "falling_box_label")[0].rect == Rect2(11076.25, 278.75, 12, 6), "box seed floorworldx modulo5 keeps source LCG label")
	check(tagged(mid, "drop_shadow")[0].radius == Vector2(34, 5), "falling drop keeps full34pixel landing shadow")
	drop.kind = "icicle"
	drop.t = 1.4
	mid = renderer.build_mid(host, state)
	check(tagged(mid, "falling_icicle")[0].points == PackedVector2Array([Vector2(11086.25, 230.15), Vector2(11114.25, 230.15), Vector2(11100.25, 300.15)]), "icicle keeps28by70 source triangle and unsnapped vertical motion")
	check(tagged(mid, "icicle_highlight")[0].rect.position.is_equal_approx(Vector2(11094.25, 234.15)), "icicle source white highlight")
	drop.dead = true
	check(tagged(renderer.build_mid(host, state), "drop_shadow").is_empty(), "dead drop omitted after runtime removal")
	drop.dead = false
	var snapshot := JSON.stringify(state)
	var before_commands := renderer.build_mid(host, state)
	seed(90210)
	var expected_random := randf()
	seed(90210)
	renderer.build_mid(host, state)
	check(randf() == expected_random, "painter never consumes simulation or global random stream")
	check(renderer.build_mid(host, state) == before_commands and JSON.stringify(state) == snapshot, "draw repeat never mutates hazards or clocks")
	var callbacks: Array = []
	renderer.draw_mid(host, state, func(): callbacks.append(host.recorded.size()))
	check(callbacks.size() == 1 and callbacks[0] == host.recorded.size(), "inherited pickup callback occurs once after all mid commands")

	host.camera = Vector2(500, -0.25)
	state.scene_index = 0
	var front := renderer.build_front(host, state)
	check(tagged(front, "foreground_bollard")[0].rect == Rect2(750, 501.75, 30, 46), "source34pixel option clamps bollard body to30pixels")
	check(tagged(front, "foreground_bollard_cap")[0].radius == Vector2(15, 6), "bollard low ellipse cannot become fullheight occluding pillar")
	check(tagged(front, "foreground_bollard_band")[0].rect == Rect2(750, 511.75, 30, 8), "aisle bollard has green band")
	state.scene_index = 1
	front = renderer.build_front(host, state)
	check(tagged(front, "foreground_bollard_band").is_empty() and tagged(front, "foreground_bollard")[0].colour == Color(170 / 255.0, 200 / 255.0, 225 / 255.0, 0.9), "frozen bollard is blue without green band")
	host.camera = Vector2.ZERO
	check(renderer.draw_enemy(host, bot()) and tagged(renderer.build_enemy(host, bot("big")), "security_cap").size() == 1, "common W2 bot and security render methods inherited")
	state.merge({"wiping": true, "wipe_elapsed": 1.0, "wipe_kind": "door", "wipe_label": "Frozen foods"}, true)
	check(tagged(renderer.build_hud(host, state), "wipe_label")[0].text == "Frozen foods" and tagged(renderer.build_hud(host, state), "wipe_cover").size() == 1, "common scene iris and destination label inherited")
	host.level_id = "2-1"
	check(renderer.build_sky(host, state).is_empty() and renderer.build_level(host, state).is_empty() and renderer.build_mid(host, state).is_empty() and renderer.build_front(host, state).is_empty() and not renderer.draw_enemy(host, bot()), "no drawing ownership leaks into parking")
	host.level_id = "2-2"
	check(JSON.stringify(host.meta) == original, "all painter passes preserve imported metadata")
	check(not renderer._gate_art_cache.is_empty(), "source gate geometry cache populated")
	renderer.clear_cache()
	check(renderer._gate_art_cache.is_empty() and renderer._filtered_textures.is_empty(), "cache clearing retains inherited texture cleanup")

	# Actual CanvasItem draw callbacks cover outlines, texture crops, countdown
	# arcs, warnings, controls, both paintings, bots and the inherited iris.
	var canvas := DrawHost.new()
	load_stage(canvas)
	root.add_child(canvas)
	for row in [[0, Vector2(700, 0)], [0, Vector2(2200, -350)], [0, Vector2(9900, 0)], [1, Vector2(10800, 0)]]:
		canvas.camera = row[1]
		var center := float(canvas.camera.x) + 300
		canvas.runtime = {"scene_index": row[0], "elapsed": 0.45, "hazard_controller": {"gates": [{"x": center, "floor": 482, "h": 180, "id": 0, "open": 0.3, "timer": 2.6, "held": false}], "plates": [{"x": center - 100, "y": 482, "id": 0, "on": false}], "buttons": [{"x": center + 100, "y": 372, "id": 0, "hit": 0.3}]}, "entities": [{"k": "drop", "p": Vector2(center, 300), "top": 482, "warn": 0.95, "t": 0.475, "kind": "box"}, {"k": "drop", "p": Vector2(center + 150, 350), "top": 482, "warn": 0.95, "t": 1.0, "kind": "icicle"}], "wiping": true, "wipe_elapsed": 0.26, "wipe_label": "Frozen foods"}
		var actor := bot("big")
		actor.p.x = center
		canvas.bots = [actor]
		canvas.queue_redraw()
		await process_frame
		await process_frame
	check(canvas.draw_count >= 4 and canvas.pickup_count == canvas.draw_count, "actual Node2D callbacks execute both aisle scenes and shared layers")
	canvas.camera = Vector2(9900, 0)
	canvas.runtime.scene_index = 0
	canvas.images.erase("strip")
	canvas.queue_redraw()
	await process_frame
	await process_frame
	check(canvas.draw_count >= 5, "actual CanvasItem renders fallback placard text and animated strips")
	canvas.queue_free()
	await process_frame
	print("Aisle renderer checks: %d assertions; %d failures. Geometry/command QA only, not screenshots, devices or completed gameplay." % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
