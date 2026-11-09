extends SceneTree
## Geometry/resource/real CanvasItem command regression, not screenshot,
## device, performance, gameplay-completion or native-support validation.
const Renderer = preload("res://src/shopping_street_renderer.gd")
const SharedRenderer = preload("res://src/supermarket_renderer.gd")

class Host extends RefCounted:
	var level_id := "2-S"
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
	var level_id := "2-S"
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
	var pickup_count := 0
	func view_width() -> float: return 738.0
	func view_top() -> float: return camera.y + 540 - 540 / 1.3
	func _draw_pickups() -> void:
		pickup_count += 1
		# Only a callback probe: actual receipt art remains host-owned.
		draw_rect(Rect2(camera.x + 100, 322, 22, 34), Color.WHITE)
	func _draw() -> void:
		draw_set_transform(Vector2(-camera.x * 1.3, 540 * (1 - 1.3) - camera.y * 1.3), 0, Vector2.ONE * 1.3)
		renderer.draw_sky(self, runtime)
		renderer.draw_level(self, runtime)
		renderer.draw_mid(self, runtime, _draw_pickups)
		for actor in bots: renderer.draw_enemy(self, actor)
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

func load_stage(host) -> void:
	host.meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/2-S.json"))
	host.level = host.meta.level
	for key in host.meta.imgs:
		host.images[key] = load(host.meta.imgs[key])
		check(host.images[key].get_size() == Vector2(host.meta.dims[key][0], host.meta.dims[key][1]), "original dimensions " + key)
	host.sheets.bot = load("res://assets/sprites/bot-sheet.png")

func bot(kind: String, position := Vector2(300, 482)) -> Dictionary:
	return {"p": position, "kind": kind, "type": kind, "state": "cart" if kind == "cart" else "walk", "face": -1,
		"big": false, "hp": 3, "max_hp": 3, "t": 0.3, "flash": 0.0, "gone": 0.0, "stride": 28.0, "visual_move": -1 if kind == "rush" else 0}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host := Host.new()
	load_stage(host)
	var state := {"scene_index": 0, "entities": [], "elapsed": 0.0, "wiping": false}
	var original := JSON.stringify(host.meta)
	check(renderer.supports("2-S"), "shopping painter supports2-S")
	for id in ["1-S", "1-1", "2-1", "2-2", "2-3", "2-4", "2-5", "2-6", "3-S", "2-s"]:
		check(not renderer.supports(id), "does not claim unrelated stage " + id)
	check(host.level.solids.size() == 1 and Vector3(host.level.solids[0][0], host.level.solids[0][1], host.level.solids[0][2]) == Vector3(-400, 9400, 482) and host.level.plats.is_empty(), "source stalls have no authored collision")
	check(host.level.stalls.size() == 9 and host.level.timer == 100000, "source nine stalls and dormant timer retained")
	check(host.level.receipts.map(func(r): return Vector2(r[0], r[1])) == [Vector2(2000, 362), Vector2(5300, 362), Vector2(8200, 482)], "shared W2 receipt positions preserved")
	check(host.level.hz.all(func(h): return h[0] == "coins"), "all22authored zones are coins rather than physical hazards")
	var coins := 0
	for h in host.level.hz: coins += int(h[4])
	check(host.level.hz.size() == 22 and coins == 128, "128authored coins remain runtime-owned")
	check(host.level.get("scenes", []).is_empty(), "bonus street has no authored iris scene")

	var sky: Array = renderer.build_sky(host, state)
	var shops: Dictionary = tagged(sky, "shopping_shops")[0]
	check(tagged(sky, "shopping_sky_fill")[0].rect == Rect2(-10, -10, 758, 560), "source sky fallback canvas rectangle")
	check(tagged(sky, "shopping_sky_fill")[0].colour == Color("4aa3e8"), "sunny blue sky color")
	check(shops.source == Rect2(0, 0, 1503, 764), "street shops cropped at independently rounded85.5percent")
	check(shops.rect == Rect2(0, -312, 1503, 764), "shop row original scale and source ground-minus30anchor")
	var level_commands: Array = renderer.build_level(host, state)
	var pavement: Dictionary = tagged(level_commands, "shopping_pavement")[0]
	check(pavement.source == Rect2(0, 764, 1503, 130), "pavement lower14.5percent crop")
	check(pavement.rect == Rect2(0, 452, 1503, 130), "pavement original scale and ground-minus30anchor")
	check(tagged(level_commands, "shopping_floor")[0].rect == Rect2(-10, 482, 758, 540), "source grey floor extends a full540px")
	check(tagged(level_commands, "shopping_floor")[0].colour == Color("9aa3b4"), "source pavement underfill color")
	check(shops.rect.end.y == pavement.rect.position.y, "painting halves meet without seam at integral vertical camera")
	check(tagged(level_commands, "sample_stall")[0].rect == Rect2(700, 190, 270, 298), "first original stall base ground-plus6")
	check(tagged(level_commands, "sample_stall_shadow")[0].rect == Rect2(708, 480, 254, 8), "original stall shadow geometry")

	for camera_x in [0.0, 300.5, 1502.5, 1503.0, 1503.5, 2732.72, 3006.0, 7900.25, 8262.0]:
		for camera_y in [0.0, -0.5, -32.25, -100.75]:
			host.camera = Vector2(camera_x, camera_y)
			sky = renderer.build_sky(host, state)
			level_commands = renderer.build_level(host, state)
			for tag in ["shopping_shops", "shopping_pavement"]:
				var row := tagged(sky if tag == "shopping_shops" else level_commands, tag)
				check(row.is_empty() == (tag == "shopping_pavement" and camera_y == -100.75), "painting row culled only when wholly below view " + tag)
				var factor := 0.55 if tag == "shopping_shops" else 1.0
				for command in row:
					check(command.factor == factor, "source horizontal parallax " + tag)
					check(command.rect.position.x == Vector2(host.camera.x + Renderer.source_round(command.index * 1503 - host.camera.x * factor), 0).x, "source snapped tile origin " + tag)
					check(command.flip_h == (command.index % 2 != 0), "alternate tile reflection " + tag)
					check(command.rect.size == command.source.size, "native-sized painting " + tag)
					var expected_y: float = camera_y + Renderer.source_round(482 - 30 - 0.855 * 894 - camera_y) if tag == "shopping_shops" else 452 + camera_y - Renderer.source_round(camera_y)
					check(command.rect.position.y == expected_y, "source sky/world vertical transform " + tag)
				if row.size() > 1: check(row[0].rect.end.x == row[1].rect.position.x, "no gap at mirrored tile join " + tag)
			for command in tagged(level_commands, "sample_stall"):
				check(command.rect.position.y == 190 + camera_y - Renderer.source_round(camera_y), "stall shares rounded world vertical transform")

	var seen: Array[int] = []
	for k in 9:
		var x := 700 + 900 * k
		check(host.level.stalls[k] == x, "authored stall location %d" % k)
		host.camera = Vector2(x - 200.25, -0.25)
		var stalls := tagged(renderer.build_level(host, state), "sample_stall")
		check(stalls.size() == 1, "one visible authored stall atcamera%d" % k)
		var stall: Dictionary = stalls[0]
		check(stall.stall_index == k and stall.key == "stall%d" % (k % 4), "four source paintings cycle without mirror%d" % k)
		check(not stall.flip_h and stall.world_x == x, "stalls stay at world positions%d" % k)
		check(stall.rect == Rect2(x - 0.25, 189.75, 270, 298), "stall fractional camera snapping%d" % k)
		seen.append(stall.stall_index)
	check(seen.size() == 9, "all nine stalls exercised")
	# Source inView padding uses strict comparisons; shadow retains these bounds
	# even when the shared texture helper culls wholly off-canvas image pixels.
	host.camera = Vector2(1040, 0)
	check(tagged(renderer.build_level(host, state), "sample_stall_shadow").all(func(c): return c.rect.position.x != 708), "left visibility boundary excludes stall exactly atcam-minus40")
	host.camera.x = 1039.5
	check(tagged(renderer.build_level(host, state), "sample_stall_shadow").any(func(c): return c.rect.position.x == 708.5), "left visibility boundary includes half pixel before exit")
	host.camera.x = -98
	check(tagged(renderer.build_level(host, state), "sample_stall_shadow").is_empty(), "right visibility boundary excludes exactly atcam-pluswidth-plus40")
	host.camera.x = -97.5
	check(tagged(renderer.build_level(host, state), "sample_stall_shadow").size() == 1, "right visibility boundary enters half pixel later")

	host.camera = Vector2(500, -0.25)
	var front := renderer.build_front(host, state)
	check(tagged(front, "foreground_bollard")[0].rect == Rect2(750, 501.75, 20, 46), "requested12px front width is actually clamped20px low bollard")
	check(tagged(front, "foreground_bollard_cap")[0].radius == Vector2(10, 6), "source half-width bollard cap")
	check(tagged(front, "foreground_bollard")[0].colour == Color(20 / 255.0, 24 / 255.0, 40 / 255.0, 0.92), "street foreground differs from parking color")
	check(tagged(front, "foreground_bollard_highlight")[0].colour == Color(1, 214 / 255.0, 150 / 255.0, 0.55), "street foreground warm highlight")
	check(tagged(front, "foreground_bollard_cap")[0].center.y - 6 > 494, "source foreground is never a tall lamp post")
	for index in 6:
		host.camera = Vector2((index * 2100.0 + 900 - 250) / 1.3, 0)
		front = renderer.build_front(host, state)
		check(tagged(front, "foreground_bollard").size() == 1, "2100pxstreet foreground period%d" % index)
		check(is_equal_approx(tagged(front, "foreground_bollard")[0].rect.position.x - host.camera.x, 250), "foreground1.3parallax%d" % index)
	for sx in [-33.0, -32.0, 758.0, 759.0]:
		host.camera.x = (900 - sx) / 1.3
		check(renderer.build_front(host, state).is_empty() == (sx == -33 or sx == 759), "foreground source12px cull boundaries%f" % sx)

	host.camera = Vector2.ZERO
	check(renderer.build_mid(host, state).is_empty(), "authored bonus has no invented mid-layer hazards")
	var calls: Array = []
	renderer.draw_mid(host, state, func(): calls.append("pickups"))
	check(calls == ["pickups"], "shared receipts drawn by host callback once")
	var shared = SharedRenderer.new()
	for kind in ["rush", "cart"]:
		var actor := bot(kind)
		var before := actor.duplicate(true)
		var commands := renderer.build_enemy(host, actor)
		host.level_id = "2-1"
		var shared_commands := shared.build_enemy(host, actor)
		host.level_id = "2-S"
		check(commands == shared_commands and actor == before, "shared source bot painter inherited unchanged " + kind)
		check(renderer.draw_enemy(host, actor), "handles authored2-Senemy " + kind)
		if kind == "cart": check(tagged(commands, "trolley_mesh").size() == 14, "cart enemy uses shared source trolley mesh")
	for elapsed in [0.0, 99.0, 100.0, 200.0]:
		state.elapsed = elapsed
		state.timer = elapsed
		host.elapsed = elapsed
		check(renderer.build_hud(host, state).is_empty(), "dormant100second metadata never produces countdown%f" % elapsed)
	var state_before := state.duplicate(true)
	var first := renderer.build_level(host, state)
	check(renderer.build_level(host, state) == first and state == state_before, "repeated painting leaves runtime untouched")
	state.merge({"wiping": true, "wipe_elapsed": 0.26, "wipe_kind": "fade"}, true)
	check(tagged(renderer.build_hud(host, state), "wipe_cover").size() == 1, "optional generic iris HUD contract inherited")
	state.wipe_kind = "lift"
	check(tagged(renderer.build_hud(host, state), "wipe_iris").size() == 1, "generic captured-focus iris helper remains compatible")
	check(JSON.stringify(host.meta) == original, "draw passes never add collision or change imported metadata")
	var street: Texture2D = host.images.street
	host.images.erase("street")
	check(renderer.build_level(host, state).is_empty(), "missing street returns before stalls/floor as source")
	check(renderer.build_sky(host, state).size() == 1, "missing street leaves sunny sky fallback")
	host.images.street = street
	host.images.erase("stall0")
	check(tagged(renderer.build_level(host, state), "sample_stall").is_empty() and tagged(renderer.build_level(host, state), "sample_stall_shadow").is_empty(), "missing stall omits both art and shadow")
	for id in ["2-1", "1-1"]:
		host.level_id = id
		check(renderer.build_sky(host, state).is_empty() and renderer.build_level(host, state).is_empty() and renderer.build_mid(host, state).is_empty() and renderer.build_front(host, state).is_empty() and renderer.build_hud(host, state).is_empty(), "all command builders reject " + id)
		check(not renderer.draw_enemy(host, bot("rush")), "enemy renderer declines " + id)

	# Exercise native CanvasItem calls, all four paintings and shared cart/bot/
	# HUD command paths. A synthetic iris tests compatibility, not stage design.
	var canvas := DrawHost.new()
	load_stage(canvas)
	root.add_child(canvas)
	for k in 4:
		canvas.camera = Vector2(500 + k * 900, -0.25)
		canvas.bots = [bot("rush", Vector2(canvas.camera.x + 300, 482)), bot("cart", Vector2(canvas.camera.x + 500, 482))]
		canvas.runtime = {"entities": [], "wiping": true, "wipe_elapsed": [0.0, 0.26, 1.0, 1.87][k], "wipe_label": ""}
		canvas.queue_redraw()
		await process_frame
		await process_frame
	check(canvas.draw_count >= 4 and canvas.pickup_count == canvas.draw_count, "real Node2D draws all street variants and pickup callback")
	canvas.queue_free()
	await process_frame
	print("Shopping street renderer checks: %d assertions; %d failures. Geometry/CanvasItem QA only, not screenshots or devices." % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
