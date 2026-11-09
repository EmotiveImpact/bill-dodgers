extends SceneTree
## Command geometry and actual CanvasItem callbacks, not screenshot/device QA.
const Renderer = preload("res://src/checkout_renderer.gd")
const Checkout = preload("res://src/checkout_boss.gd")

class Host extends RefCounted:
	var level_id := "2-6"
	var meta: Dictionary = {}
	var level: Dictionary = {}
	var images: Dictionary = {}
	var sheets: Dictionary = {}
	var camera := Vector2.ZERO
	var player := Vector2(4300, 482)
	var elapsed := 0.0
	var font: Font = load("res://assets/fonts/silk.woff2")
	var world_two: Dictionary = {}
	var boss = null
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
	func draw_set_transform_matrix(transform): recorded.append(["transform", transform])

class DrawHost extends Node2D:
	var renderer = Renderer.new()
	var level_id := "2-6"
	var meta: Dictionary = {}
	var level: Dictionary = {}
	var images: Dictionary = {}
	var sheets: Dictionary = {}
	var camera := Vector2(4162, 0)
	var player := Vector2(4300, 482)
	var elapsed := 0.0
	var font: Font = load("res://assets/fonts/silk.woff2")
	var world_two: Dictionary = {}
	var draw_count := 0
	var pickup_count := 0
	var order: Array = []
	func view_width() -> float: return 738.0
	func view_top() -> float: return camera.y + 540 - 540 / 1.3
	func _draw() -> void:
		order.clear()
		draw_set_transform(Vector2(-camera.x * 1.3, 540 * (1 - 1.3) - camera.y * 1.3), 0, Vector2.ONE * 1.3)
		renderer.draw_sky(self, world_two)
		renderer.draw_level(self, world_two)
		renderer.draw_mid(self, world_two, func(): pickup_count += 1; order.append("pickups"))
		order.append("checkout_mid")
		var bot := {"p": Vector2(camera.x + 150, 482), "kind": "big", "type": "big", "state": "walk", "face": -1, "big": true, "hp": 12, "max_hp": 24, "t": 0.3, "stride": 28.0, "visual_move": -1}
		renderer.draw_enemy(self, bot)
		order.append("enemy")
		renderer.draw_jar(self, world_two)
		order.append("jar")
		renderer.draw_player_back(self, player)
		draw_rect(Rect2(player - Vector2(15, 80), Vector2(30, 80)), Color("ff8fc7"))
		order.append("player")
		renderer.draw_player_front(self, player)
		renderer.draw_front(self, world_two)
		order.append("beam")
		draw_set_transform(Vector2.ZERO)
		renderer.draw_hud(self, world_two)
		order.append("hud")
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
	var found: Array = []
	for command in commands:
		if command.tag == tag: found.append(command)
		if command.has("commands"): found.append_array(tagged(command.commands, tag))
	return found

func load_stage(host) -> void:
	host.meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/2-6.json"))
	host.level = host.meta.level
	for key in host.meta.imgs: host.images[key] = load(host.meta.imgs[key])
	host.sheets.bot = load("res://assets/sprites/bot-sheet.png")

func fresh_boss() -> Dictionary:
	return {"x": 4760.0, "hp": 70, "max": 70, "state": "fight", "t": 0.0, "phase": 1, "flash": 0.0, "mouth": 0.0, "beam": null, "codes": [], "dizzy": 0.0, "frozen": 0.0, "crates": [], "steps": 0}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host := Host.new()
	load_stage(host)
	var meta_before := JSON.stringify(host.meta)
	var checkout := Checkout.new()
	checkout.boss = fresh_boss()
	host.world_two = {"checkout": checkout, "elapsed": 99.0}
	var b: Dictionary = checkout.boss
	check(renderer.supports("2-6") and not renderer.supports("2-5") and not renderer.supports("1-6"), "only checkout stage claims support")
	for key in ["boss", "checkout", "crate0", "crate1", "crate2"]:
		check(host.images[key].get_size() == Vector2(host.meta.dims[key][0], host.meta.dims[key][1]), "original image dimensions " + key)
	check(host.images.boss.get_size() == Vector2(404, 400) and host.images.checkout.get_size() == Vector2(651, 461), "original checkout and boss paintings")
	var crops := {"checkout_roof": [Rect2(0, 0, 651, 46), 0.4], "checkout_pipes": [Rect2(0, 46, 651, 76), 0.7], "checkout_wall": [Rect2(0, 122, 651, 339), 1.0]}
	for cx in [0.0, 500.25, 651.0, 1302.0, 4162.25]:
		for cy in [0.0, -0.25, -160.5]:
			host.camera = Vector2(cx, cy)
			var sky := renderer.build_sky(host, host.world_two)
			for tag in crops:
				for command in tagged(sky, tag):
					check(command.source == crops[tag][0] and command.factor == crops[tag][1], "exact source crop and parallax " + tag)
					var offset := 0 if tag == "checkout_roof" else (46 if tag == "checkout_pipes" else 122)
					check(command.rect.position == Vector2(cx + Renderer.source_round(command.index * 651 - cx * command.factor), cy + Renderer.source_round(482 - 0.82 * 461 - cy + offset)), "source camera rounding " + tag)
					check(command.flip_h == (false if tag == "checkout_wall" else command.index % 2 != 0), "roof pipes alternate mirrors but numbers never mirror")
	host.camera = Vector2(500, 0)
	var level := renderer.build_level(host)
	check(tagged(level, "checkout_lane")[0].source == Rect2(20, 256, 436, 101), "lane crop retains independent source start and extent rounding")
	check(tagged(level, "checkout_lane")[0].rect == Rect2(700, 386, 380, 88), "first lane art aligns four pixels above platform top390")
	check(tagged(level, "checkout_lane_number")[0].position == Vector2(1065, 245) and tagged(level, "checkout_lane_number")[0].text == "1", "source lane sign origin and number")
	for i in 5:
		host.camera = Vector2(700 + i * 600 - 100, 0)
		var lane: Dictionary = tagged(renderer.build_level(host), "checkout_lane")[0]
		check(lane.lane == i + 1 and lane.flip_h == (i % 2 != 0), "all five authored lanes retain alternating row art")
	host.camera = Vector2(4162, 0)
	level = renderer.build_level(host)
	check(tagged(level, "checkout_arena_stripe")[0].rect == Rect2(4162, 482, 738, 6), "arena exact yellow stripe")
	check(tagged(level, "checkout_arena_band").size() == 19, "nineteen source alternating arena bands")
	check(tagged(renderer.build_mid(host), "checkout_boss_painting")[0].source == Rect2(0, 0, 404, 400), "boss retains entire source painting")
	var mid := renderer.build_mid(host)
	var till: Dictionary = tagged(mid, "checkout_till")[0]
	var painting: Dictionary = tagged(mid, "checkout_boss_painting")[0]
	check(till.art_rect == Rect2(4565, 132, 390, 360) and painting.rect == Rect2(13, 0, 364, 360), "tillArt exact390x360 canvas and fitted centered364x360 painting")
	check(till.transform * painting.rect.position == Vector2(4578, 132), "actual opaque image starts13px inside art origin")
	check(Renderer.TRAY_RECT == Rect2(4816, 354, 119, 0) and Renderer.BODY_RECT == Rect2(4635, 122, 250, 360), "painted tray and logical body retain distinct origins")
	check(tagged(mid, "checkout_phase_overlay").is_empty() and tagged(mid, "checkout_screen_wait").is_empty() and tagged(mid, "checkout_code").is_empty(), "phase1 original angry face and no invented dormant attacks")
	b.phase = 2
	var phase_overlay: Dictionary = tagged(renderer.build_mid(host), "checkout_phase_overlay")[0]
	check(phase_overlay.rect == Rect2(150, 50, 108, 68) and till.transform * phase_overlay.rect.position == Renderer.SCREEN_RECT.position, "painted screen exact world4715/182")
	check(phase_overlay.colour == Color(1, 170 / 255.0, 60 / 255.0, 0.22), "phase2 amber glaze")
	b.phase = 3
	check(tagged(renderer.build_mid(host), "checkout_phase_overlay")[0].colour == Color(1, 60 / 255.0, 60 / 255.0, 0.28), "phase3 red glaze")
	b.frozen = 5.0
	for elapsed in [0.0, 0.249, 0.25, 0.499, 0.5, 2.75]:
		host.elapsed = elapsed
		mid = renderer.build_mid(host)
		check(tagged(mid, "checkout_screen_error")[0].colour == Color("c62828" if int(floor(elapsed / 0.25)) % 2 else "e23b3b"), "frozen250ms blink uses host elapsed rather than runtimeelapsed99")
		check(tagged(mid, "checkout_error_text")[0].position.is_equal_approx(Vector2(204, 75.84)) and tagged(mid, "checkout_error_mark")[0].position.is_equal_approx(Vector2(204, 103.04)), "source ERROR and bang screen positions")
		check(tagged(mid, "checkout_phase_overlay").is_empty(), "error takes precedence over phase glaze")
	b.frozen = 0.0
	b.flash = 0.08
	b.mouth = 0.1
	mid = renderer.build_mid(host)
	check(tagged(mid, "checkout_boss_painting")[0].flash and tagged(mid, "checkout_scanner_mouth")[0].rect == Rect2(146, 128, 66, 24), "white flash only painting and source scanner mouth rectangle")
	check(tagged(mid, "checkout_scanner_mouth_core")[0].rect == Rect2(146, 138, 66, 4), "scanner mouth white core")
	b.flash = 0.0
	b.mouth = 0.0

	# Seconds correspond to source ms, including visual900ms / harm>900ms.
	for y in [448.0, 332.0]:
		for time in [0.0, 0.119, 0.12, 0.15, 0.24, 0.3, 0.84, 0.899, 0.9, 0.900001, 1.449999, 1.45, 1.6]:
			b.beam = {"y": y, "t": time}
			mid = renderer.build_mid(host)
			var front := renderer.build_front(host)
			check(tagged(mid, "scanner_window_tell").size() == (1 if time < 0.9 else 0), "scanner window tell ends exactly900ms")
			if time < 0.9:
				var tell: Dictionary = tagged(mid, "scanner_window_tell")[0]
				check(tell.rect == Rect2(4711, 258 if y == 332 else 272, 66, 12), "high low source window tell positions")
				check(tell.colour == (Color(1, 80 / 255.0, 80 / 255.0, 0.95) if Renderer._clock_step(time, 0.15) % 2 else Color(1, 190 / 255.0, 190 / 255.0, 0.9)), "150ms scanner window blink")
			var warning: bool = time < 0.9 and Renderer._clock_step(time, 0.12) % 2 != 0
			check(tagged(front, "scanner_warning_line").size() == (1 if warning else 0), "120ms front warning blink")
			if warning:
				check(tagged(front, "scanner_warning_line")[0].rect == Rect2(4162, y - 2, 473, 4), "warning spans screen edge to logical tillLeft")
				check(tagged(front, "scanner_warning_text")[0].text == ("Duck!" if y == 332 else "Jump!"), "correct high/low scanner instruction")
			var firing: bool = time >= 0.9 and time < 1.45
			check(tagged(front, "scanner_beam").size() == (1 if firing else 0), "front beam exact900 inclusive1450 exclusive visual interval")
			if firing:
				check(tagged(front, "scanner_beam_glow")[0].rect == Rect2(4162, y - 10, 473, 20) and tagged(front, "scanner_beam")[0].rect == Rect2(4162, y - 4, 473, 8) and tagged(front, "scanner_beam_core")[0].rect == Rect2(4162, y - 1, 473, 2), "scanner three exact20/8/2px layers")
			check(tagged(front, "foreground_bollard").is_empty(), "no foreground bollard in boss arena")
	b.state = "enter"
	b.beam = {"y": 332.0, "t": 0.15}
	check(tagged(renderer.build_mid(host), "scanner_window_tell").is_empty(), "window tell only in fight state")
	b.state = "fight"
	b.beam = null

	# All three paper steps and curved feed live in mid, not generic solids art.
	b.steps = 3
	mid = renderer.build_mid(host)
	var steps := tagged(mid, "receipt_step")
	check(steps.size() == 3, "three receipt steps")
	for i in 3:
		check(steps[i].rect == Rect2(4385 + i * 80, 412 - i * 65, 90, 14), "step matches live receipt surface " + str(i))
		check(checkout.receipt_step(i).row == [steps[i].rect.position.x, steps[i].rect.end.x, steps[i].rect.position.y], "controller and painter receipt coordinates agree")
	var feed: Dictionary = tagged(mid, "receipt_paper_feed")[0]
	check(feed.points[0] == Vector2(4785, 272) and feed.points[-1] == Vector2(4635, 286) and feed.control == Vector2(4665, 202) and feed.width == 6, "quadratic paper source control and endpoints")
	b.crates = []
	var states := ["fall", "ground", "carry", "fly", "on"]
	for i in states.size(): b.crates.append({"p": Vector2(4300 + i * 100, 380 if i % 2 else 482), "st": states[i], "k": i % 3, "by": 11 if i == 2 else null})
	checkout.players = {11: {"bag": 1.5, "p": Vector2(4300, 482), "height": 200.0}, 12: {"bag": 0.5, "p": Vector2(4400, 400), "height": 160.0}, 13: {"bag": 0.0, "p": Vector2(4500, 482), "height": 180.0}}
	mid = renderer.build_mid(host)
	var crates := tagged(mid, "checkout_crate")
	check(crates.size() == 5 and tagged(mid, "checkout_crate_shadow").size() == 1, "fall ground carry fly on all visible with only falling shadow")
	for i in 5:
		var image_size: Vector2 = host.images["crate%d" % (i % 3)].get_size()
		check(crates[i].rect == Rect2(b.crates[i].p - Vector2(image_size.x / 2, image_size.y), image_size) and crates[i].state == states[i] and crates[i].layer == "mid", "crate bottom-centered native-size art " + states[i])
	var bags := tagged(mid, "checkout_player_bag")
	check(bags.size() == 2 and tagged(mid, "checkout_bag_handle").size() == 4, "all bagged participants including CPU shape contract")
	check(bags[0].points == PackedVector2Array([Vector2(4254, 482), Vector2(4262, 322), Vector2(4338, 322), Vector2(4346, 482)]), "source bag uses full200px height .8 factor")
	check(tagged(mid, "checkout_bag_logo")[0].rect == Rect2(4270, 392, 60, 14), "source bag .45height logo")
	check(mid.find(crates[-1]) < mid.find(bags[0]) and mid.find(tagged(mid, "receipt_paper_feed")[0]) < mid.find(crates[0]), "source till steps crates bags mid ordering")
	check(renderer.build_player_back(host).is_empty() and renderer.build_player_front(host).is_empty(), "bags and carried crates never duplicated around sprite")
	# A placed crate target extends six pixels past world width by design.
	b.crates = [{"p": Vector2(4906, 354), "st": "on", "k": 1}]
	var on: Dictionary = tagged(renderer.build_mid(host), "checkout_crate")[0]
	check(on.rect == Rect2(4874, 292, 64, 62), "right tray crate deliberately extends past world width4900")

	# Mid callback really occurs before TB, and draw transforms restore world.
	host.recorded.clear()
	var callback_at := [-1]
	renderer.draw_mid(host, host.world_two, func(): callback_at[0] = host.recorded.size(); host.recorded.append(["pickups"]))
	check(callback_at[0] == 0 and host.recorded[0][0] == "pickups" and host.recorded[1][0] == "polygon", "arena pickups precede boss shadow and all boss art")
	var transforms := host.recorded.filter(func(row): return row[0] == "transform")
	check(transforms.size() == 2 and transforms[-1][1] == renderer._world_transform(host), "posed boss restores host world transform before steps bags and sprites")

	b.state = "down"
	b.frozen = 0.0
	for time in [0.0, 0.6, 1.2, 1.5, 2.5, 10.0]:
		b.t = time
		mid = renderer.build_mid(host)
		till = tagged(mid, "checkout_till")[0]
		check(till.sink == minf(60, time * 50) and is_equal_approx(till.angle, minf(0.1, time / 6)) and is_equal_approx(till.alpha, maxf(0.35, 1 - time / 2.5)), "source down sink rotation fade clocks")
		check(till.pivot == Vector2(195, 340) and tagged(mid, "checkout_screen_down")[0].text == "X  X", "down rotates around original195340 pivot and crossed eyes")
		check(renderer.build_hud(host).is_empty(), "down hides boss HUD")
	b.state = "fight"
	b.t = 0.0
	b.hp = 21
	b.max = 70
	var hud := renderer.build_hud(host)
	check(tagged(hud, "checkout_boss_health_back")[0].rect == Rect2(266, 496, 428, 26), "source HUD at bottom y500 with428x26frame")
	check(tagged(hud, "checkout_boss_health")[0].rect == Rect2(270, 500, 126, 18), "source420px boss bar ratio")
	check(tagged(hud, "checkout_boss_name")[0].position == Vector2(278, 484) and tagged(hud, "checkout_boss_name")[0].align == "left", "source left-aligned boss name")
	host.world_two.merge({"wiping": true, "wipe_elapsed": 1.0, "wipe_label": "Test only"})
	check(tagged(renderer.build_hud(host), "wipe_cover").size() == 1, "shared source iris retained")
	host.world_two.wiping = false
	checkout.jar = {"p": Vector2(4610.25, 262), "t": 0.14, "got": false}
	var jar := renderer.build_jar(host)
	var bob := sin(1.0) * 2
	check(tagged(jar, "checkout_jar_lid")[0].rect.position.is_equal_approx(Vector2(4592.25, 218 + bob)), "jar exact2x art origin unroundedx and140ms bob")
	check(tagged(jar, "checkout_jar_glow")[0].radius.is_equal_approx(Vector2.ONE * (44 + sin(1.4) * 4)), "jar100ms glow pulse")
	check(tagged(jar, "checkout_jar_glass")[0].rect.size == Vector2(56, 60) and tagged(jar, "checkout_jar_coins")[0].rect.size == Vector2(48, 52), "source full kitty jar scale2")
	checkout.jar.got = true
	jar = renderer.build_jar(host)
	check(tagged(jar, "checkout_jar_glow").is_empty() and tagged(jar, "checkout_jar_lid")[0].rect.position == Vector2(4592.25, 218), "collected jar still draws without bob or glow")
	checkout.jar.got = false
	host.camera = Vector2(500, -0.25)
	var front := renderer.build_front(host)
	check(tagged(front, "foreground_bollard")[0].rect == Rect2(750, 501.75, 30, 46) and tagged(front, "foreground_bollard_band")[0].rect == Rect2(750, 511.75, 30, 8), "source approach bollard low30px with red band")
	# Shared lane belts use source elapsed; boss default source clock is host.
	host.elapsed = 0.125
	host.world_two.elapsed = 0.125
	check(not tagged(renderer.build_mid(host), "belt_tread").is_empty(), "checkout approach retains inherited belt geometry")
	host.camera = Vector2(4162.25, -0.25)
	mid = renderer.build_mid(host)
	check(tagged(mid, "checkout_till")[0].origin == Vector2(4565.25, 131.75), "fractional camera keeps source horizontal and vertical snap")
	var snapshot := checkout.snapshot()
	var snapshot_before := var_to_str(snapshot)
	var host_before := [host.camera, host.player, host.elapsed, host.boss]
	seed(7719)
	var expected := randf()
	seed(7719)
	var first := [renderer.build_sky(host), renderer.build_level(host), renderer.build_mid(host), renderer.build_front(host), renderer.build_jar(host), renderer.build_hud(host)]
	var second := [renderer.build_sky(host), renderer.build_level(host), renderer.build_mid(host), renderer.build_front(host), renderer.build_jar(host), renderer.build_hud(host)]
	check(first == second and randf() == expected, "repeat draw is deterministic and leaves simulation RNG untouched")
	check(snapshot_before == var_to_str(checkout.snapshot()) and host_before == [host.camera, host.player, host.elapsed, host.boss], "all builders preserve TB jar player and host state")
	check(renderer.build_checkout_mid(host, snapshot) == renderer.build_checkout_mid(host), "detached snapshot and world_two.checkout controller share painter contract")
	check(meta_before == JSON.stringify(host.meta), "imported stage geometry and assets never mutated")
	var no_boss := {"checkout": {"boss": {}, "jar": {}, "players": {}}}
	host.boss = {"state": {"hp": 100, "max": 100}}
	check(renderer.build_checkout_mid(host, no_boss).is_empty() and renderer.build_hud(host, no_boss).is_empty(), "generic host.boss never treated as TB")
	host.boss = null
	host.level_id = "2-5"
	check(renderer.build_sky(host).is_empty() and renderer.build_level(host).is_empty() and renderer.build_mid(host).is_empty() and renderer.build_front(host).is_empty() and renderer.build_hud(host).is_empty() and renderer.build_jar(host).is_empty(), "all checkout builders decline unrelated stages")
	host.level_id = "2-6"

	# Real CanvasItem draw methods execute both texture flash and transformed
	# death, source text, masks, all crate kinds, bags, beam, jar and inheritedbot.
	var canvas := DrawHost.new()
	load_stage(canvas)
	var live := Checkout.new()
	canvas.world_two = {"checkout": live, "elapsed": 0.0}
	root.add_child(canvas)
	for stage in ["approach", "enter", "low_warning", "high_warning", "beam", "frozen", "phase3", "down", "jar"]:
		live.boss = fresh_boss()
		live.players = {1: {"p": canvas.player, "height": 200.0, "bag": 1.5}}
		live.jar = {}
		canvas.camera = Vector2(500.25 if stage == "approach" else 4162.25, -0.25)
		canvas.elapsed = 0.3
		live.boss.crates = [{"p": Vector2(4300, 400), "st": "fall", "k": 0}, {"p": Vector2(4400, 482), "st": "ground", "k": 1}, {"p": Vector2(4500, 300), "st": "carry", "k": 2}]
		match stage:
			"approach": live.boss = {}
			"enter": live.boss.state = "enter"
			"low_warning": live.boss.beam = {"y": 448.0, "t": 0.15}
			"high_warning": live.boss.beam = {"y": 332.0, "t": 0.15}
			"beam": live.boss.beam = {"y": 448.0, "t": 0.95}; live.boss.mouth = 0.1
			"frozen": live.boss.frozen = 5.0; live.boss.flash = 0.08
			"phase3": live.boss.phase = 3; live.boss.steps = 3
			"down": live.boss.state = "down"; live.boss.t = 1.5
			"jar": live.boss.state = "down"; live.boss.t = 2.5; live.jar = {"p": Vector2(4610, 262), "t": 0.4, "got": false}
		canvas.queue_redraw()
		await process_frame
		await process_frame
		check(canvas.order == ["pickups", "checkout_mid", "enemy", "jar", "player", "beam", "hud"], "actual draw callback ordering " + stage)
	check(canvas.draw_count >= 9 and canvas.pickup_count == canvas.draw_count, "CanvasItem callbacks cover all source boss layers")
	canvas.queue_free()
	await process_frame
	renderer.clear_cache()
	check(renderer._filtered_textures.is_empty() and renderer._sprite_variants.is_empty(), "shared art and white flash cache cleanup")
	print("Checkout renderer checks: %d assertions; %d failures. Command/CanvasItem QA only; no screenshots, device or gameplay claims." % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
