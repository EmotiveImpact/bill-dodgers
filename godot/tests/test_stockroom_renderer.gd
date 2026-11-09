extends SceneTree
## Source crops, geometry, clocks and real CanvasItem callback checks only.
## Headless execution cannot certify screenshot, mobile or gameplay parity.
const Renderer = preload("res://src/stockroom_renderer.gd")

class Host extends RefCounted:
	var level_id := "2-3"
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
	var level_id := "2-3"
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

class Surfaces extends RefCounted:
	var rows: Array = []
	func surfaces(_host) -> Array: return rows

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
	host.meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/2-3.json"))
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
	check(renderer.supports("2-3") and not renderer.supports("2-1") and not renderer.supports("2-2") and not renderer.supports("1-3"), "stockroom alone claims support")
	host.camera = Vector2(0, -200)
	var sky := renderer.build_sky(host, state)
	check(tagged(sky, "stockroom_roof")[0].source == Rect2(0, 0, 868, 104), "original stockroom roof17percent crop")
	check(tagged(sky, "stockroom_roof")[0].rect == Rect2(0, -99, 868, 104), "ground plus10 minus80percent background height anchor")
	check(tagged(sky, "stockroom_wall")[0].source == Rect2(0, 104, 868, 510), "stockroom wall keeps full lower83percent painting")
	check(tagged(sky, "stockroom_wall")[0].rect == Rect2(0, 5, 868, 510), "wall top uses unrounded17percent source height offset")
	check(sky[-1].tag == "stockroom_shade" and sky[-1].colour == Color(20 / 255.0, 28 / 255.0, 44 / 255.0, 0.3), "downstairs source dark overlay follows painted layers")
	state.scene_index = 1
	sky = renderer.build_sky(host, state)
	check(tagged(sky, "mezz_roof")[0].source == Rect2(0, 0, 1186, 212), "mezz roof original30percent crop")
	check(tagged(sky, "mezz_roof")[0].rect == Rect2(0, -153, 1186, 212), "mezz uses90percent height and full vertical camera compensation")
	check(tagged(sky, "mezz_racking")[0].source == Rect2(0, 212, 1186, 395), "mezz middle original30to86percent crop")
	check(tagged(sky, "mezz_racking")[0].rect == Rect2(0, 59, 1186, 395), "mezz middle rounded fractional origin")
	# Ground view includes the last painting strip that the high camera culls.
	host.camera.y = 0
	check(tagged(renderer.build_sky(host, state), "mezz_floor")[0].source == Rect2(0, 607, 1186, 99), "mezz floor original14percent mesh painting")
	check(tagged(renderer.build_sky(host, state), "mezz_floor")[0].rect == Rect2(0, 454, 1186, 99), "mezz floor image is not stretched to physical floor")
	for scene in [0, 1]:
		state.scene_index = scene
		for cx in [0.0, 868.25, 1500.5, 8910.75, 10500.25, 13000.5]:
			for cy in [0.0, -32.25, -200.5, -410.75]:
				host.camera = Vector2(cx, cy)
				sky = renderer.build_sky(host, state)
				for command in sky:
					if command.type != "texture": continue
					var factor: float = {"stockroom_roof": 0.3, "stockroom_wall": 0.55, "mezz_roof": 0.6, "mezz_racking": 0.85, "mezz_floor": 1.0}[command.tag]
					check(command.factor == factor and command.rect.position.x == cx + Renderer.source_round(command.index * command.rect.size.x - cx * factor), "source parallax and screen rounding " + command.tag)
					check(command.flip_h == (command.index % 2 != 0), "source alternating background mirror " + command.tag)
					var y: float
					if scene == 0:
						y = cy + Renderer.source_round(482 + 10 - 0.8 * 614 - cy * 0.5 + (0.17 * 614 if command.tag == "stockroom_wall" else 0))
					else:
						var offset := 212 if command.tag == "mezz_racking" else (607 if command.tag == "mezz_floor" else 0)
						y = cy + Renderer.source_round(482 - 0.9 * 706 - cy) + offset
					check(is_equal_approx(command.rect.position.y, y), "source vertical camera relation " + command.tag)
					check(command.rect.size == command.source.size, "painting bands retain native resolution " + command.tag)
	# Art canvas tests use a wide inspection view to retain every source tile.
	host.camera = Vector2.ZERO
	var c: Dictionary = renderer._context(host)
	c.view = Rect2(-1000, -1000, 20000, 4000)
	var rows: Array = []
	renderer._rack(rows, c, Vector2(3000, 122), 1400, 360)
	var racks := tagged(rows, "rack_row")
	check(racks.size() == 12, "three source120pixel rows and four columns build1400wide tower")
	check(racks[0].source == Rect2(141, 200, 293, 98) and racks[0].rect == Rect2(3000, 362, 359, 120), "bottom rack row original cropA and scale")
	check(racks[1].source == Rect2(141, 298, 293, 87) and racks[1].flip_h, "second column alternate cropB mirrored")
	check(racks[4].source == racks[0].source and racks[4].flip_h, "next row begins mirrored cropA not different cropB")
	check(racks[3].rect == Rect2(4077, 362, 323, 120), "last rack column is clipped at authored tower edge")
	check(is_equal_approx(racks[3].source.end.x, 434) and is_equal_approx(racks[3].source.size.x, 293.0 * 323 / 359), "mirrored last rack column retains right side of crop")
	check(tagged(rows, "rack_top_beam")[0].source == Rect2(141, 182, 293, 18) and tagged(rows, "rack_top_beam")[0].rect == Rect2(3000, 122, 359, 16), "rack deck uses original orange beam crop scaled to16pixels")
	check(tagged(rows, "rack_frame")[-1].rect == Rect2(3000, 482, 1400, 6), "rack canvas base extends6pixels below ground")
	for command in racks + tagged(rows, "rack_top_beam"):
		check(command.art_bounds.encloses(command.rect), "rack command clipped within cached-art canvas")
		check(is_equal_approx(command.rect.size.x / command.source.size.x, command.tile_rect.size.x / command.tile_source.size.x), "rack clipping preserves horizontal scale")
	var odd_height: Array = []
	renderer._rack(odd_height, c, Vector2(50, 50), 100, 250)
	var clipped_top: Dictionary = tagged(odd_height, "rack_row")[-1]
	check(clipped_top.rect == Rect2(50, 50, 100, 10), "partial upper rack row clips negative drawing origin")
	check(is_equal_approx(clipped_top.source.position.y, 200 + 98.0 * 110 / 120), "partial top row advances source pixels rather than compressing")
	var stacks: Array = []
	renderer._stack(stacks, c, Vector2(1000, 372), 230, 110)
	check(stacks.size() == 2 and stacks[0].source == Rect2(278, 390, 143, 77), "wrapped stock crop comes from original lower stockroom painting")
	check(stacks[0].rect == Rect2(1000, 372, 204, 110) and stacks[1].rect == Rect2(1204, 372, 26, 110), "stack repeats204pixel tiles with26pixel final crop")
	check(stacks[1].flip_h and is_equal_approx(stacks[1].source.end.x, 421), "mirrored stack clips from correct edge")
	stacks.clear()
	renderer._stack(stacks, c, Vector2(2150, 367), 146, 115)
	check(stacks.size() == 2 and stacks[1].rect == Rect2(2150, 367, 146, 5), "authored115pixel platform stock clips top row to5pixels")
	check(stacks[1].flip_h and stacks[1].source.position.y == 463.5 and stacks[1].source.size.y == 3.5, "stack row count preserves continuous mirror phase across rows")
	var expected_towers := [Vector3(3000, 4400, 360), Vector3(4650, 5600, 240), Vector3(6000, 7400, 240), Vector3(7700, 8800, 360), Vector3(10500, 11700, 480), Vector3(12100, 13000, 360)]
	check(host.level.towers.size() == 6, "six authored stockroom towers")
	for i in expected_towers.size():
		var tower: Array = host.level.towers[i]
		check(Vector3(tower[0], tower[1], tower[2]) == expected_towers[i], "exact authored stockroom tower %d" % i)
	check(host.level.plats.size() == 19, "nineteen authored ladder bridge pallet platforms preserved")
	for tower in host.level.towers:
		host.camera = Vector2(float(tower[0]) - 100, -200.25)
		var commands := renderer.build_level(host, state)
		var origin := Vector2(float(tower[0]), 482 - float(tower[2]) - 0.25)
		check(tagged(commands, "rack_frame").any(func(q): return q.rect == Rect2(origin, Vector2(10, float(tower[2])))), "authored tower left edge and source height " + str(tower[0]))
		check(tagged(commands, "rack_shadow").any(func(q): return q.rect == Rect2(float(tower[0]) - 6, 477.75, float(tower[1]) - float(tower[0]) + 16, 10)), "authored tower shadow " + str(tower[0]))
	host.camera = Vector2(2750.25, -0.25)
	var level := renderer.build_level(host, state)
	check(tagged(level, "ladder_upright")[0].rect == Rect2(2844.25, 121.75, 10, 360), "ladder empty bay upright at tower start minus156")
	check(tagged(level, "ladder_beam")[0].rect == Rect2(2844.25, 361.75, 156, 10) and tagged(level, "ladder_beam")[3].rect == Rect2(2844.25, 241.75, 156, 10), "authored ladder steps362and242 align with orange beams")
	host.camera = Vector2(12800, 0)
	level = renderer.build_level(host, state)
	check(tagged(level, "ladder_upright")[0].rect == Rect2(13146, 122, 10, 360), "right-hand ladder upright at tower end plus146")
	check(tagged(level, "ladder_beam")[0].rect == Rect2(13000, 362, 156, 10), "right-hand ladder begins at tower face")
	for hazard in host.level.hz:
		if hazard[0] != "belt": continue
		host.camera = Vector2(float(hazard[1]) - 50.25, -250.25)
		level = renderer.build_level(host, state)
		check(tagged(level, "belt_support").size() == 2, "two blue supports per authored conveyor")
		check(tagged(level, "belt_support")[0].rect == Rect2(float(hazard[1]) + 19.75, float(hazard[3]) + 19.75, 10, 482 - float(hazard[3]) - 20), "belt support starts below20pixel conveyor body")
		check(not tagged(level, "ladder_beam").any(func(q): return q.rect.position.is_equal_approx(Vector2(float(hazard[1]) - 0.25, float(hazard[3]) - 0.25))), "belt platform never receives duplicate rack-step painting")
		state.elapsed = 0.1
		var belt := renderer.build_mid(host, state)
		check(tagged(belt, "belt_base")[0].rect == Rect2(float(hazard[1]) - 0.25, float(hazard[3]) - 0.25, float(hazard[2]) - float(hazard[1]), 20), "source conveyor shares authored collision top")
		var direction := signf(float(hazard[4]))
		check(signf(tagged(belt, "belt_arrow")[0].points[0].x - tagged(belt, "belt_arrow")[0].points[1].x) == direction, "conveyor arrow follows signed authored speed")
	# All floor segments are painted independently. The hoist remains a hole.
	host.camera = Vector2(8800.25, -0.25)
	state.scene_index = 1
	level = renderer.build_level(host, state)
	check(tagged(level, "stockroom_floor").size() == 2 and tagged(level, "concrete_floor_line").is_empty(), "upstairs gap separates two metal floor segments")
	check(tagged(level, "hoist_opening")[0].rect == Rect2(9000.25, 481.75, 440, 77.75), "source440pixel hoist opening remains empty at ground line")
	check(tagged(level, "hoist_edge_stripe")[0].rect == Rect2(8990.25, 481.75, 10, 24) and tagged(level, "hoist_edge_stripe")[1].colour == Color("f4c542"), "opening outer-edge24pixel alternating safety bands")
	check(tagged(level, "pallet_chain").size() == 4, "both static gap pallets have two source chains")
	check(tagged(level, "pallet_chain")[0].rect.position.is_equal_approx(Vector2(9118.25, host.view_top() - 10.25)), "chain begins10pixels above visible world top")
	check(is_equal_approx(tagged(level, "pallet_chain")[0].rect.end.y, 451.75), "first chain ends at452platform top")
	check(tagged(level, "chained_pallet_base")[0].rect == Rect2(9110.25, 475.75, 90, 16) and tagged(level, "chained_pallet_base")[1].rect == Rect2(9270.25, 445.75, 70, 16), "procedural pallet platforms at452and422 use original90and70widths")
	check(tagged(level, "chained_pallet_box")[0].rect == Rect2(9114.25, 451.75, 38, 24), "pallet box negative10pixel top is canvas-clipped")
	check(tagged(level, "chained_pallet_box_highlight")[0].rect.size.y == 4, "pallet top highlight clips to4pixels")
	check(tagged(level, "chained_pallet_foot")[2].rect.size.x == 12, "pallet final foot clips at canvas right edge")
	check(not level.any(func(q): return q.get("key", "") == "pallet"), "imported pallet image is deliberately unused by active painter")
	var stationary := tagged(level, "chained_pallet_base")
	state.elapsed = 100.0
	check(tagged(renderer.build_level(host, state), "chained_pallet_base") == stationary, "source chained platforms never sway or follow cosmetic elapsed clock")
	state.scene_index = 0
	level = renderer.build_level(host, state)
	check(not tagged(level, "concrete_floor_line").is_empty() and tagged(level, "mezz_floor_grate").is_empty(), "downstairs concrete lane paint replaces upstairs grating")
	check(tagged(level, "goods_lift")[0].rect == Rect2(8725.25, 105.75, 329, 380), "original goods-lift painting source halfwidth and screen rounding")
	state.scene_index = 1
	check(tagged(renderer.build_level(host, state), "goods_lift").is_empty(), "goods lift painting occurs only before scene change")
	# Live surface adapters are read-only and take precedence over metadata.
	var provider := Surfaces.new()
	provider.rows = [{"row": [9110, 9200, 452], "plat": true}, {"row": [0, 15000, 482], "plat": false}]
	check(renderer._platform_rows(host, provider) == [[9110, 9200, 452]], "runtime surface provider keeps only live one-way platforms")
	state.surfaces = provider.rows
	check(tagged(renderer.build_level(host, state), "pallet_chain").size() == 2, "surface snapshot replaces static authored platforms")
	state.surfaces = []
	check(tagged(renderer.build_level(host, state), "pallet_chain").is_empty(), "present empty surface list never restores removed platforms")
	state.erase("surfaces")
	# Drop state is shared with the controller; no simulation is run in paint.
	host.camera = Vector2(3000.25, -300.25)
	var drop := {"k": "drop", "p": Vector2(3300.5, 70.4), "top": 122, "vy": 0.0, "warn": 0.95, "t": 0.475, "kind": "box", "dead": false}
	state.entities = [drop]
	var mid := renderer.build_mid(host, state)
	check(tagged(mid, "drop_shadow")[0].center == Vector2(3300.25, 119.75) and tagged(mid, "drop_shadow")[0].radius == Vector2(24, 5), "drop telegraph follows elevated rack landing top")
	check(tagged(mid, "drop_warning").size() == 1 and tagged(mid, "falling_box").is_empty(), "drop shadow and warning precede falling box")
	check(tagged(mid, "drop_warning")[0].position.is_equal_approx(Vector2(3300.25, host.view_top() + 99.75)), "warning remains100pixels below moving view top")
	drop.t = 0.949
	check(tagged(renderer.build_mid(host, state), "falling_box").is_empty(), "falling box hidden until950ms")
	drop.t = 0.95
	mid = renderer.build_mid(host, state)
	check(tagged(mid, "falling_box")[0].rect == Rect2(3268.25, 11.75, 64, 58), "box appears at inclusive950ms with rounded bottom minus58")
	check(tagged(mid, "drop_shadow")[0].radius == Vector2(34, 5), "falling shadow clamps at34pixel width")
	drop.dead = true
	check(tagged(renderer.build_mid(host, state), "drop_shadow").is_empty(), "dead drop omitted")
	drop.dead = false
	var snapshot := JSON.stringify(state)
	seed(12345)
	var random_value := randf()
	seed(12345)
	renderer.build_sky(host, state)
	renderer.build_level(host, state)
	renderer.build_mid(host, state)
	check(randf() == random_value and JSON.stringify(state) == snapshot, "all stockroom painting preserves state and simulation RNG")
	var callbacks: Array = []
	renderer.draw_mid(host, state, func(): callbacks.append(host.recorded.size()))
	check(callbacks.size() == 1 and callbacks[0] == host.recorded.size(), "common pickup callback executes once after hazard layer")
	# Source low foreground bollards remain identical in both stockroom scenes.
	host.camera = Vector2(500, -0.25)
	var front := renderer.build_front(host, state)
	check(tagged(front, "foreground_bollard")[0].rect == Rect2(750, 501.75, 30, 46), "foreground body is source low30by46bollard")
	check(tagged(front, "foreground_bollard")[0].colour == Color(14 / 255.0, 20 / 255.0, 34 / 255.0, 0.9), "stockroom bollard uses source dark tint")
	check(tagged(front, "foreground_bollard_band")[0].rect == Rect2(750, 511.75, 30, 8) and tagged(front, "foreground_bollard_band")[0].colour == Color("f4c542"), "stockroom foreground yellow safety band")
	check(tagged(front, "foreground_bollard_highlight")[0].colour == Color(47 / 255.0, 111 / 255.0, 184 / 255.0, 0.7), "stockroom blue bollard highlight")
	state.scene_index = 0
	check(renderer.build_front(host, state) == front, "scene change does not replace source foreground bollards")
	# Missing asset fallbacks are the source ones, never generic stage art.
	host.camera = Vector2(8500, 0)
	var lift: Texture2D = host.images.glift
	host.images.erase("glift")
	level = renderer.build_level(host, state)
	check(tagged(level, "goods_lift_fallback")[0].rect == Rect2(8790, 102, 200, 380), "fallback lift exact200by380canvas anchor")
	check(tagged(level, "goods_lift_fallback_stripe")[-1].rect.size.x == 4, "fallback lift final hazard stripe clips to200pixel canvas")
	host.images.glift = lift
	state.scene_index = 1
	var mezz: Texture2D = host.images.mezz
	host.images.erase("mezz")
	host.camera = Vector2(9200.25, -200.25)
	sky = renderer.build_sky(host, state)
	check(tagged(sky, "mezz_fallback_wall")[0].factor == 0.3, "missing mezz uses source small stockroom wall at0.3parallax")
	check(is_equal_approx(tagged(sky, "mezz_fallback_wall")[0].rect.size.y, 614 * 0.62 * 0.83), "fallback wall source0.62scale and83percent crop height")
	check(not tagged(sky, "mezz_fallback_truss_brace").is_empty() and not tagged(sky, "mezz_fallback_lamp_glow").is_empty(), "fallback has source hanging lamps and truss diagonals")
	check(tagged(sky, "mezz_fallback_rail")[0].rect.position.y == host.camera.y + 372, "fallback safety rail uses source sky-space coordinates")
	renderer.draw_commands(host, sky)
	check(renderer._stockroom_glow != null and renderer._stockroom_glow.get_size() == Vector2(300, 400), "fallback clipped two-centre gradient texture built at source resolution")
	host.images.mezz = mezz
	var stockroom: Texture2D = host.images.stockroom
	host.images.erase("stockroom")
	check(renderer.build_sky(host, state).size() == 1, "missing stockroom uses source dark fill even if mezz remains available")
	host.images.stockroom = stockroom
	host.camera = Vector2.ZERO
	check(renderer.draw_enemy(host, bot()) and tagged(renderer.build_enemy(host, bot("big")), "security_cap").size() == 1, "common bot and elevated security rendering inherited")
	state.merge({"wiping": true, "wipe_elapsed": 1.0, "wipe_kind": "lift", "wipe_label": "Top floor"}, true)
	check(tagged(renderer.build_hud(host, state), "wipe_label")[0].text == "Top floor", "source goods-lift iris label inherited unchanged")
	check(JSON.stringify(host.meta) == original, "all renderer passes preserve imported source metadata")
	host.level_id = "2-2"
	check(renderer.build_sky(host, state).is_empty() and renderer.build_level(host, state).is_empty() and renderer.build_mid(host, state).is_empty() and renderer.build_front(host, state).is_empty() and not renderer.draw_enemy(host, bot()), "stockroom painter never takes another stage")
	host.level_id = "2-3"
	renderer.clear_cache()
	check(renderer._stockroom_glow == null and renderer._filtered_textures.is_empty(), "clear_cache releases source fallback and inherited texture caches")
	# Actual Node2D draw callbacks exercise full command dispatch, not mocks.
	var canvas := DrawHost.new()
	load_stage(canvas)
	root.add_child(canvas)
	var visits := [[0, Vector2(900, 0)], [0, Vector2(2150, 0)], [0, Vector2(2850, -200)], [0, Vector2(4300, -250)], [0, Vector2(8500, 0)], [1, Vector2(8800, 0)], [1, Vector2(10300, -420)], [1, Vector2(11600, -200)], [1, Vector2(12800, -100)]]
	for visit in visits:
		canvas.camera = visit[1]
		var center := canvas.camera.x + 300
		canvas.runtime = {"scene_index": visit[0], "elapsed": 0.45, "entities": [{"k": "drop", "p": Vector2(center, 150), "top": 122, "warn": 0.95, "t": 0.475, "kind": "box"}, {"k": "drop", "p": Vector2(center + 100, 250), "top": 482, "warn": 0.95, "t": 1.0, "kind": "box"}], "wiping": true, "wipe_elapsed": 0.26, "wipe_label": "Top floor"}
		var actor := bot("big")
		actor.p = Vector2(center, 242)
		canvas.bots = [actor]
		canvas.queue_redraw()
		await process_frame
		await process_frame
	check(canvas.draw_count >= visits.size() and canvas.pickup_count == canvas.draw_count, "actual Node2D callbacks cover both scenes, tall racks, belts, hoist, drops, shared bots and iris")
	canvas.images.erase("mezz")
	canvas.camera = Vector2(9200.25, -200.25)
	canvas.queue_redraw()
	await process_frame
	await process_frame
	check(canvas.draw_count >= visits.size() + 1, "actual CanvasItem renders fallback trusses lamps and gradient")
	canvas.runtime.scene_index = 0
	canvas.images.erase("glift")
	canvas.camera = Vector2(8500, 0)
	canvas.queue_redraw()
	await process_frame
	await process_frame
	check(canvas.draw_count >= visits.size() + 2, "actual CanvasItem renders fallback goods lift")
	canvas.queue_free()
	await process_frame
	print("Stockroom renderer checks: %d assertions; %d failures. Geometry/command QA only, not screenshots, devices or completed gameplay." % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
