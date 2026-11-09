extends SceneTree
## Source crops, geometry, clocks and real CanvasItem callback checks only.
## Headless execution cannot certify screenshot, mobile or gameplay parity.
const Renderer = preload("res://src/bakery_renderer.gd")

class Host extends RefCounted:
	var level_id := "2-5"
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
	var level_id := "2-5"
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
	host.meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/2-5.json"))
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
	var state := {"scene_index": 0, "elapsed": 99.0, "entities": [], "wiping": false}
	check(renderer.supports("2-5") and not renderer.supports("2-4") and not renderer.supports("2-2") and not renderer.supports("1-1"), "only bakery painter claims support")
	check(Vector2(host.level.card[0], host.level.card[1]) == Vector2(8850, 232) and host.level.scenes[0][0] == 9400 and host.level.check == 9500, "authored high card, swing-door boundary and checkpoint are distinct")
	var sky := renderer.build_sky(host, state)
	check(tagged(sky, "bakery_roof")[0].rect == Rect2(0, 104, 651, 32), "roof original height at ground camera")
	host.camera.y = -150
	sky = renderer.build_sky(host, state)
	check(tagged(sky, "bakery_roof")[0].source == Rect2(0, 0, 651, 32), "original sevenpercent roof crop")
	check(tagged(sky, "bakery_pipes")[0].source == Rect2(0, 32, 651, 28), "original seven-to-thirteenpercent pipe crop")
	check(tagged(sky, "bakery_wall")[0].source == Rect2(23, 60, 368, 401), "bakehouse crop keeps ovens and racks")
	check(tagged(sky, "bakery_wall")[0].rect == Rect2(0, 164, 368, 401), "wall uses fractional thirteenpercent placement independent of crop rounding")
	check(sky.find(tagged(sky, "bakery_roof")[0]) < sky.find(tagged(sky, "bakery_pipes")[0]) and sky.find(tagged(sky, "bakery_pipes")[0]) < sky.find(tagged(sky, "bakery_wall")[0]), "source roof, pipe, wall order")
	for cx in [0.0, 368.5, 651.0, 2600.25, 8800.75, 11800.5]:
		for cy in [0.0, -32.25, -400.5]:
			host.camera = Vector2(cx, cy)
			for scene in [0, 1]:
				state.scene_index = scene
				sky = renderer.build_sky(host, state)
				for row in [["bakery_roof", 0.4, 0.0], ["bakery_pipes", 0.7, 32.0], ["bakery_wall", 1.0, 59.93]]:
					for command in tagged(sky, row[0]):
						check(command.rect.position.x == cx + Renderer.source_round(command.index * command.rect.size.x - cx * row[1]), "screen-rounded parallax " + row[0])
						check(command.flip_h == (command.index % 2 != 0), "alternating original painting tiles " + row[0])
						check(is_equal_approx(command.rect.position.y, cy + Renderer.source_round(482 - 0.82 * 461 - cy + row[2])), "source fractional vertical camera alignment " + row[0])
						check(command.key == "bakery", "original bakery texture retained " + row[0])
				for wall in tagged(sky, "bakery_wall"):
					check(wall.source == (Rect2(23, 60, 368, 401) if scene == 0 else Rect2(293, 60, 358, 401)), "scene chooses original oven or deli wall crop")
	state.scene_index = 0
	host.camera = Vector2(1700.25, -0.25)
	var level := renderer.build_level(host, state)
	var ovens := tagged(level, "bakery_oven")
	check(ovens[0].source == Rect2(85, 138, 215, 191), "oven source crop uses independently rounded dimensions")
	check(ovens[0].rect == Rect2(1779.25, 227.75, 281, 250), "oven250pixel height and center at authored xplus120")
	check(tagged(level, "bakery_oven_shadow")[0].rect == Rect2(1779.25, 475.75, 281, 8), "oven bottom source shadow")
	check(level.find(ovens[0]) < level.find(tagged(level, "conveyor_leg")[0]), "oven paintings are behind cooling conveyors")
	state.scene_index = 1
	check(tagged(renderer.build_level(host, state), "bakery_oven").is_empty(), "ovens hidden after shop-floor transition")
	state.scene_index = 0
	host.camera = Vector2(700.25, -0.25)
	level = renderer.build_level(host, state)
	var tables := tagged(level, "bakery_table")
	check(tables.size() == 4 and tables[0].rect == Rect2(800.25, 369.75, 165, 116), "original165by116 table aligns with370platform")
	check(tables[3].rect == Rect2(1277.25, 369.75, 165, 116) and tables[3].flip_h, "source159pixel stride with untrimmed fourth table overhang")
	check(tables[0].source == Rect2(0, 0, 165, 116) and not tables[0].flip_h, "painted table unscaled first tile")
	var table_image: Texture2D = host.images.table
	host.images.erase("table")
	level = renderer.build_level(host, state)
	check(tagged(level, "bakery_table_fallback")[0].rect == Rect2(800.25, 369.75, 500, 12), "missing table uses source500pixel steel fallback")
	check(tagged(level, "bakery_table_leg").size() == 3 and tagged(level, "bakery_table_dough").size() == 24, "fallback source three legs and six four-piece trays")
	host.images.table = table_image
	host.camera = Vector2(7460.25, -0.25)
	level = renderer.build_level(host, state)
	var racks := tagged(level, "bakery_rack")
	check(racks.size() == 2 and racks[0].source == Rect2(296, 152, 88, 177), "source bread-rack crop and repeat count")
	check(racks[0].rect == Rect2(7500.25, 291.75, 96, 194) and racks[1].rect == Rect2(7596.25, 291.75, 96, 194), "rack194pixel art aligns with292platform")
	check(not racks[0].flip_h and racks[1].flip_h, "rack second copy mirrored")
	var legs := tagged(level, "conveyor_leg")
	check(legs.size() == 3 and legs[0].rect == Rect2(7824.25, 253.75, 12, 228), "highest conveyor has ground-reaching228pixel supports")
	check(tagged(level, "conveyor_brace")[0].rect.position.is_equal_approx(Vector2(7830.25, 379.15)), "conveyor brace at55percent of support height")
	check(tagged(level, "conveyor_bread")[0].center == Vector2(7820.25, 222.75), "source bread sits9pixels above232belt")
	check(tagged(level, "conveyor_bread")[0].radius == Vector2(22, 10), "source bread22by10ellipse")
	host.elapsed = 0.1
	level = renderer.build_level(host, state)
	check(tagged(level, "conveyor_bread")[0].center == Vector2(7932.25, 222.75), "negative belt wraps bread120pixel phase using host clock")
	check(tagged(level, "conveyor_roller")[0].rect == Rect2(7816.25, 235.75, 4, 12), "negative belt wraps roller24pixel phase independently")
	check(tagged(renderer.build_mid(host, state), "belt_tread")[0].rect == Rect2(7816.25, 232.75, 10, 3), "shared belt top overlays conveyor with same host clock")
	check(level.all(func(command): return not str(command.tag).contains("card")), "shared host alone owns double-jump card painting")
	host.camera = Vector2(8800.25, -0.25)
	level = renderer.build_level(host, state)
	check(tagged(level, "bakery_swing_doors")[0].rect == Rect2(9261.25, 165.75, 277, 320), "original swing painting centered on9400 and bottomgroundplus4")
	state.scene_index = 1
	check(tagged(renderer.build_level(host, state), "bakery_swing_doors").is_empty(), "swing doors omitted after scene handoff")
	state.scene_index = 0
	var swing_image: Texture2D = host.images.swing
	host.images.erase("swing")
	level = renderer.build_level(host, state)
	check(tagged(level, "bakery_swing_fallback")[0].rect == Rect2(9270.25, 161.75, 260, 320), "source swing fallback has distinct320pixel ground anchor")
	check(tagged(level, "bakery_swing_window").size() == 2 and tagged(level, "bakery_swing_window")[0].center == Vector2(9343.25, 271.75), "fallback two source portholes")
	host.images.swing = swing_image
	state.scene_index = 1
	host.camera = Vector2(9800.25, -0.25)
	level = renderer.build_level(host, state)
	var deli := tagged(level, "bakery_deli")
	check(deli.size() == 4 and deli[0].source == Rect2(384, 184, 267, 138), "deli original crop and four tiles in700pixel counter")
	check(deli[0].rect == Rect2(9800.25, 365.75, 224, 116) and deli[3].rect == Rect2(10472.25, 365.75, 28, 116), "deli last tile clips28pixels rather than squashing")
	check(deli[3].flip_h and is_equal_approx(deli[3].source.size.x, 33.375) and is_equal_approx(deli[3].source.end.x, 651), "mirrored final deli tile uses right source edge")
	check(tagged(level, "bakery_deli_top")[0].rect == Rect2(9800.25, 361.75, 700, 6), "source deli top trim")
	check(tagged(level, "bakery_table").is_empty() and tagged(level, "bakery_rack").is_empty(), "shop floor hides bakehouse tables and rack")
	host.camera = Vector2(10700.25, -0.25)
	level = renderer.build_level(host, state)
	check(tagged(level, "flour_coating")[0].rect == Rect2(10800.25, 477.75, 1400, 10), "authored10800to12200source flour strip")
	check(tagged(level, "flour_mound").size() == 24 and tagged(level, "flour_mound")[0].center == Vector2(10830.25, 481.75), "source flour mounds60pixels apart")
	check(tagged(level, "flour_sack")[0].center == Vector2(10780.25, 455.75) and is_equal_approx(tagged(level, "flour_sack")[0].rotation, -0.25), "flour sack original tilt and location")
	check(tagged(level, "flour_sack_spill")[0].center == Vector2(10826.25, 475.75), "white flour spill alongside sack")
	host.camera.x = 11100.25
	check(tagged(renderer.build_level(host, state), "flour_sack").is_empty(), "sack independent source view-range culling")
	host.camera = Vector2(12300.25, -0.25)
	var mid := renderer.build_mid(host, state)
	check(tagged(mid, "wet_floor_sign")[0].rect == Rect2(12564.25, 395.75, 71, 86), "wet sign painted71by86size overrides62by84hazard bounds")
	var wet_image: Texture2D = host.images.wet
	host.images.erase("wet")
	mid = renderer.build_mid(host, state)
	check(tagged(mid, "wet_floor_fallback")[0].points[0] == Vector2(12600.25, 393.75), "wet sign missing-art fallback uses70by88canvas")
	check(tagged(mid, "wet_floor_fallback_base")[0].rect == Rect2(12569.25, 477.75, 62, 4), "wet fallback base remains onground")
	host.images.wet = wet_image

	# Deliberately divergent runtime.elapsed proves every bakery phase uses the
	# host source levelT, not the late runtime timer or a render-owned clock.
	host.camera = Vector2(1700.25, -0.25)
	state.hazards = [["flame", 1920, 482, 2600, 0]]
	for row in [[0.0, 0.0], [0.075, 87.5], [0.15, 175.0], [0.85, 175.0], [0.925, 87.5], [0.999, 175.0 / 150]]:
		host.elapsed = row[0]
		mid = renderer.build_mid(host, state)
		var flame := tagged(mid, "oven_flame")
		check(flame.size() == 9, "nine source flame strips at%.3f" % row[0])
		check(is_equal_approx(flame[0].visual_height, row[1]), "source150ms ramp and850ms decay at%.3f" % row[0])
		check(is_equal_approx(flame[8].rect.position.y, 471.75 - row[1]), "flame actual painted peak includes10pixel oven-door offset")
		check(is_equal_approx(flame[0].rect.size.x, 30 + sin(row[0] * 1000 / 40) * 5), "source40ms flame-width oscillation")
		check(flame[0].colour == Color("fff3b0") and flame[8].colour == Color("e8562e"), "flame source four-colour ramp")
		check(tagged(mid, "oven_flame_warning").is_empty(), "no pre-warning during active flame")
	for row in [[1.0, false], [1.9, false], [1.901, true], [2.599, true], [2.6, false]]:
		host.elapsed = row[0]
		mid = renderer.build_mid(host, state)
		check((not tagged(mid, "oven_flame_warning").is_empty()) == row[1], "strict last700ms tell at%.3f" % row[0])
		check(tagged(mid, "oven_flame").is_empty() == (row[0] < 2.6), "flame stops at1000ms and restarts atperiod")
	check(Renderer.flame_phase(["flame", 1920, 482, 2600, 2200], 0.4) == 0, "authored first oven offset wraps2600period")
	check(Renderer.flame_phase(["flame", 6320, 482, 2200, 1000], 1.2) == 0, "second oven group wraps2200period")
	for row in [[1.95, "ff9d3a"], [1.98, "e23b3b"]]:
		host.elapsed = row[0]
		mid = renderer.build_mid(host, state)
		check(tagged(mid, "oven_flame_warning")[0].colour == Color(row[1]), "warning90ms global clock flash")
		check(tagged(mid, "oven_flame_warning")[0].rect == Rect2(1896.25, 469.75, 48, 3), "warning underoven source48by3strip")
		check(tagged(mid, "oven_flame_shadow")[0].rect == Rect2(1886.25, 478.75, 68, 5), "noGrate source68by5shadow")
		check(mid.all(func(command): return not str(command.tag).contains("grate")), "bakery never paints floor grates")
	state.erase("hazards")
	host.elapsed = 0.1
	mid = renderer.build_mid(host, state)
	check(mid.find(tagged(mid, "oven_flame_shadow")[0]) < mid.find(tagged(mid, "belt_base")[0]), "source hazard order retained before shared belt overlay")
	check(tagged(mid, "belt_base").size() == 1, "shared belt drawn once not twice")
	state.entities = [{"k": "drop", "p": Vector2(2000, 300), "top": 482, "t": 0.475, "warn": 0.95, "kind": "box"}]
	mid = renderer.build_mid(host, state)
	check(tagged(mid, "drop_warning").size() == 1 and mid.find(tagged(mid, "drop_shadow")[0]) > mid.find(tagged(mid, "belt_base")[0]), "shared entity/drop helpers stay after hazards")
	var callbacks: Array = []
	renderer.draw_mid(host, state, func(): callbacks.append(host.recorded.size()))
	check(callbacks.size() == 1 and callbacks[0] == host.recorded.size(), "pickup callback occurs once after allmid art")
	var snapshot := JSON.stringify(state)
	var built := renderer.build_level(host, state)
	seed(90210)
	var expected := randf()
	seed(90210)
	renderer.build_sky(host, state)
	renderer.build_level(host, state)
	renderer.build_mid(host, state)
	renderer.build_front(host, state)
	check(randf() == expected and JSON.stringify(state) == snapshot and renderer.build_level(host, state) == built, "all draw passes repeat without runtime or global RNG mutations")
	# Exercise flour's removed render-time particle emission specifically.
	host.camera.x = 10700.25
	seed(47)
	expected = randf()
	seed(47)
	renderer.build_level(host, state)
	check(randf() == expected, "flour painting never samples gameplay RNG or adds particles")
	host.camera = Vector2(500, -0.25)
	var front := renderer.build_front(host, state)
	check(tagged(front, "foreground_bollard")[0].rect == Rect2(750, 501.75, 30, 46) and is_equal_approx(tagged(front, "foreground_bollard")[0].colour.a, 0.94), "source bakery bollard is low30pixelbody and94percentalpha")
	state.scene_index = 0
	check(front == renderer.build_front(host, state), "foreground keeps green band in both bakery scenes")
	var visible_bot := bot("big")
	visible_bot.p.x = 800
	check(renderer.draw_enemy(host, visible_bot) and tagged(renderer.build_enemy(host, visible_bot), "security_cap").size() == 1, "common bots and securitycap inherited")
	state.merge({"wiping": true, "wipe_elapsed": 1.0, "wipe_kind": "door", "wipe_label": "Shop floor"}, true)
	check(tagged(renderer.build_hud(host, state), "wipe_label")[0].text == "Shop floor" and tagged(renderer.build_hud(host, state), "wipe_cover").size() == 1, "shared swing-door iris and actual Shop floor label")
	check(JSON.stringify(host.meta) == original, "all passes preserve original imported metadata")
	host.level_id = "2-4"
	check(renderer.build_sky(host, state).is_empty() and renderer.build_level(host, state).is_empty() and renderer.build_mid(host, state).is_empty() and renderer.build_front(host, state).is_empty() and not renderer.draw_enemy(host, bot()), "bakery support cannot leak into trolley dash")
	host.level_id = "2-5"
	var painting: Texture2D = host.images.bakery
	host.images.erase("bakery")
	check(renderer.build_sky(host, state).size() == 1 and renderer.build_sky(host, state)[0].colour == Color("eaf2ee"), "missing bakery gives source pale fill without invented art")
	host.images.bakery = painting
	renderer.clear_cache()
	check(renderer._filtered_textures.is_empty() and renderer._sprite_variants.is_empty(), "inherited image cache cleanup")

	# Real CanvasItem draw callbacks, not a framebuffer or a device claim.
	var canvas := DrawHost.new()
	load_stage(canvas)
	root.add_child(canvas)
	var cases := [[0, Vector2(700, 0), 0.0], [0, Vector2(1700, -32.25), 0.45], [0, Vector2(7400, -150), 0.1], [0, Vector2(8800, 0), 2.0], [1, Vector2(9700, 0), 0.0], [1, Vector2(10700, 0), 1.0], [1, Vector2(12300, 0), 0.0]]
	for row in cases:
		canvas.camera = row[1]
		canvas.elapsed = row[2]
		canvas.runtime = {"scene_index": row[0], "elapsed": 100.0, "entities": [], "wiping": true, "wipe_elapsed": 0.26, "wipe_label": "Shop floor"}
		var actor := bot("big")
		actor.p.x = canvas.camera.x + 300
		canvas.bots = [actor]
		canvas.queue_redraw()
		await process_frame
		await process_frame
	check(canvas.draw_count >= cases.size() and canvas.pickup_count == canvas.draw_count, "actual Node2D callbacks render both scenes, flames, bread, sack, signs, crops, bot andiris")
	canvas.images.erase("swing")
	canvas.images.erase("table")
	canvas.images.erase("wet")
	for row in [[0, 700], [0, 8800], [1, 12300]]:
		canvas.camera.x = row[1]
		canvas.runtime.scene_index = row[0]
		canvas.queue_redraw()
		await process_frame
		await process_frame
	check(canvas.draw_count >= cases.size() + 3, "actual CanvasItem callbacks render all source missing-art fallbacks")
	canvas.queue_free()
	await process_frame
	print("Bakery renderer checks: %d assertions; %d failures. Geometry/command QA only, not screenshots, devices or completed gameplay." % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
