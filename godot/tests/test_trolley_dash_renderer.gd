extends SceneTree
## Commands, source geometry and actual Node2D draw callbacks only.
## Headless checks do not certify screenshots, mobile devices or a stage run.
const Renderer = preload("res://src/trolley_dash_renderer.gd")

class Host extends RefCounted:
	var level_id := "2-4"
	var meta: Dictionary = {}
	var level: Dictionary = {}
	var images: Dictionary = {}
	var sheets: Dictionary = {}
	var camera := Vector2.ZERO
	var player := Vector2(330, 482)
	var face := 1
	var grounded := true
	var player_animation := "idle"
	var hearts := 3
	var elapsed := 0.0
	var mode := "play"
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
	var level_id := "2-4"
	var meta: Dictionary = {}
	var level: Dictionary = {}
	var images: Dictionary = {}
	var sheets: Dictionary = {}
	var camera := Vector2.ZERO
	var player := Vector2(330, 482)
	var face := 1
	var grounded := true
	var player_animation := "run"
	var elapsed := 0.3
	var hearts := 3
	var mode := "play"
	var font: Font = load("res://assets/fonts/silk.woff2")
	var runtime: Dictionary = {}
	var draw_count := 0
	var pickup_count := 0
	var order: Array = []
	func view_width() -> float: return 738.0
	func view_top() -> float: return camera.y + 540 - 540 / 1.3
	func _draw() -> void:
		order.clear()
		draw_set_transform(Vector2(-camera.x * 1.3, 540 * (1 - 1.3) - camera.y * 1.3), 0, Vector2.ONE * 1.3)
		renderer.draw_sky(self, runtime)
		renderer.draw_level(self, runtime)
		renderer.draw_mid(self, runtime, func(): pickup_count += 1; order.append("pickups"))
		var bot := {"p": player + Vector2(140, 0), "kind": "big", "type": "big", "state": "walk", "face": -1, "big": true, "hp": 12, "max_hp": 24, "t": 0.3, "stride": 28.0, "visual_move": -1}
		renderer.draw_enemy(self, bot)
		renderer.draw_player_back(self, player)
		order.append("rear")
		# Host contract: only the sprite feet move up30. This marker exercises
		# the sandwich order without importing or changing main's actor code.
		draw_rect(Rect2(player - Vector2(15, Renderer.PLAYER_RIDE + 80), Vector2(30, 80)), Color("ff8fc7"))
		order.append("sprite")
		renderer.draw_player_front(self, player)
		order.append("front")
		renderer.draw_front(self, runtime)
		draw_set_transform(Vector2.ZERO)
		renderer.draw_hud(self, runtime)
		order.append("hud")
		draw_count += 1

class Course extends RefCounted:
	var speed := 200.0
	var boost := false
	var elapsed := 0.0

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
	host.meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/2-4.json"))
	host.level = host.meta.level
	for key in host.meta.imgs:
		host.images[key] = load(host.meta.imgs[key])
		check(host.images[key].get_size() == Vector2(651, 371), "original651x371 painting " + key)
	host.sheets.bot = load("res://assets/sprites/bot-sheet.png")

func inside(points: PackedVector2Array, rectangle: Rect2) -> bool:
	for point in points:
		if point.x < rectangle.position.x - 0.001 or point.x > rectangle.end.x + 0.001 or point.y < rectangle.position.y - 0.001 or point.y > rectangle.end.y + 0.001: return false
	return true

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host := Host.new()
	load_stage(host)
	var original := JSON.stringify(host.meta)
	var state := {"entities": [], "wiping": false, "elapsed": 99.0, "course_controller": {"speed": 200.0, "boost": false, "elapsed": 77.0}}
	check(renderer.supports("2-4") and not renderer.supports("2-1") and not renderer.supports("2-5") and not renderer.supports("1-3"), "only2-4 claims painter support")
	check(Renderer.PLAYER_RIDE == host.level.ride, "host sprite-only offset matches source30px ride")
	var sky := renderer.build_sky(host, state)
	check(tagged(sky, "dash_painting").size() == 2, "initial view uses two full original tiles")
	check(tagged(sky, "dash_painting")[0].rect == Rect2(0, 194, 651, 371), "source.777 floor alignment")
	check(tagged(sky, "dash_painting")[0].source == Rect2(0, 0, 651, 371), "original painting full source region")
	check(sky.find(tagged(sky, "dash_painting")[0]) < sky.find(tagged(sky, "dash_ceiling")[0]) and sky.find(tagged(sky, "dash_ceiling")[0]) < sky.find(tagged(sky, "dash_sign_number")[0]), "painting-ceiling-number sign order")
	check(tagged(sky, "dash_sign_number")[0].text == "1" and tagged(sky, "dash_sign_number")[0].position == Vector2(460, 162), "first overhead sign position and number")
	check(tagged(sky, "dash_sign_number")[0].size == 60, "source60px number font")
	check(tagged(sky, "dash_ceiling")[0].rect == Rect2(-10, -10, 758, 210), "source200px ceiling fill")
	check(tagged(sky, "ceiling_light_frame")[1].rect == Rect2(0, 174, 170, 14), "source strip light dimensions")
	var seen: Dictionary = {}
	for cx in [0.0, 3200.0, 3254.75, 3255.0, 6400.25, 9800.0, 13020.0, 16275.0, 19530.0, 39100.5]:
		for cy in [0.0, -0.25, -140.5]:
			host.camera = Vector2(cx, cy)
			sky = renderer.build_sky(host, state)
			for command in tagged(sky, "dash_painting"):
				var expected := "aisle%d" % (Renderer.aisle_at(command.index * 651) % 6)
				seen[command.key] = true
				check(command.key == expected and command.source == Rect2(0, 0, 651, 371), "tile origin selects source aisle modulo6")
				check(command.rect == Rect2(cx + Renderer.source_round(command.index * 651 - cx), cy + Renderer.source_round(482 - 0.777 * 371 - cy), 651, 371), "tile source snapping at fractional camera")
				check(not command.flip_h, "source painted() does not mirror aisle tiles")
			for command in tagged(sky, "dash_sign_number"):
				var n := int(command.text) - 1
				check(command.position == Vector2(cx + Renderer.source_round(n * 3200 * 0.8 + 400 - cx * 0.8) + 60, cy + 162), "number sign independent.8 parallax")
	check(seen.size() == 6, "all six source aisle images used")
	host.camera = Vector2(3000.25, -0.25)
	var level := renderer.build_level(host, state)
	check(tagged(level, "aisle_boundary_post")[0].rect == Rect2(3239.25, host.view_top() - 10.25, 32, 482 - host.view_top() + 10), "aisle boundary waits until ceil3200/651 tile seam3255")
	check(tagged(level, "aisle_boundary_band")[0].rect == Rect2(3239.25, 361.75, 32, 60) and tagged(level, "aisle_boundary_band")[0].colour == Color("3f7fd8"), "second aisle source colour and height")
	check(tagged(level, "floor_speed_line")[0].rect == Rect2(2880.25, 511.75, 60, 3), "source speed lines scroll every180pixels")
	check(level.all(func(command): return "floor_tiles" not in command.tag), "painted floor never replaced with extra pixel grid")
	state.course_controller.speed = 430.0
	check(renderer.build_level(host, state) == level, "speed lines follow source camera rather than invented speed effects")
	var image_one: Texture2D = host.images.aisle1
	host.images.erase("aisle1")
	check(tagged(renderer.build_sky(host, state), "dash_painting").all(func(command): return command.key == "aisle0"), "missing secondary image falls back to source aisle0")
	host.images.aisle1 = image_one
	var image_zero: Texture2D = host.images.aisle0
	host.images.erase("aisle0")
	check(tagged(renderer.build_sky(host, state), "missing_painting_fill").size() == 1, "missing mandatory painting gives explicit neutral fill")
	host.images.aisle0 = image_zero

	# Walk the actual source inventory, checking every obstacle and boost tell.
	var counts := {"block": 0, "low": 0, "boost": 0}
	for hazard in host.level.hz:
		if hazard[0] not in counts: continue
		counts[hazard[0]] += 1
		host.camera = Vector2(float(hazard[1]) - 300.25, -0.25)
		host.elapsed = 0.3
		var mid := renderer.build_mid(host, state)
		var matching := mid.filter(func(command): return command.get("hazard_x", -1) == float(hazard[1]))
		check(not matching.is_empty(), "authored %s at%s is visible" % [hazard[0], hazard[1]])
		if hazard[0] == "block":
			var size := Vector2(float(hazard[3]) + 8, float(hazard[4]) + 4)
			var origin := Vector2(host.camera.x + Renderer.source_round(float(hazard[1]) - host.camera.x - size.x / 2), float(hazard[2]) - size.y - 0.25)
			for command in matching:
				check(command.art_rect == Rect2(origin, size) and command.kind == hazard[5], "every block keeps source art bounds outside collision tuple")
				check(command.type == "polygon" and inside(command.points, command.art_rect), "block canvas clips pallet/cone overflow")
			if hazard[5] == "pallet":
				check(tagged(matching, "pallet_box").size() == 9, "source pallet keeps nine boxes including clipped top row")
				check(tagged(matching, "pallet_box").any(func(command): return Array(command.points).any(func(point): return is_equal_approx(point.y, origin.y))), "pallet negative top row clipped to source canvas")
			elif hazard[5] == "wet": check(tagged(matching, "wet_sign").size() == 1 and size == Vector2(70, 88), "source procedural wet sign not invented painted asset")
			elif hazard[5] == "cones": check(tagged(matching, "cone").size() == 2 and tagged(matching, "cone_base").size() == 2, "both source cones retained")
		elif hazard[0] == "low":
			var sign: Dictionary = tagged(matching, "low_sign")[0]
			check(sign.art_rect == Rect2(float(hazard[1]) - 60.25, float(hazard[2]) - float(hazard[3]) - 64.25, 120, 64), "all low signs underside matches source collision clearance")
			check(sign.underside == float(hazard[2]) - float(hazard[3]) - 0.25, "low sign underside property")
			check(tagged(matching, "low_sign")[1].colour == Color(["2d6a4f", "e23b3b", "3f7fd8"][int(hazard[5]) % 3]), "all low sign source palettes")
		else:
			check(matching.size() == 12, "each800px boost retains source12 chevrons")
			check(matching[0].points == PackedVector2Array([Vector2(float(hazard[1]) - 0.25, 489.75), Vector2(float(hazard[1]) + 25.75, 499.75), Vector2(float(hazard[1]) - 0.25, 509.75), Vector2(float(hazard[1]) + 9.75, 499.75)]), "boost exact fourpoint source arrow")
			var colour: Color = Color("f4c542" if int(floorf(host.elapsed * 1000 / 120 + float(hazard[1]) / 70)) % 2 else "ffe08a")
			check(matching[0].colour == colour, "boost colour follows host levelT120ms not stale runtime time")
	check(counts == {"block": 36, "low": 14, "boost": 7}, "all36blocks14low signs7boosts inspected")

	# Shared autonomous hazard trolley rendering precedes the pickup callback.
	host.camera = Vector2(19500.25, -0.25)
	var trolley := {"k": "trolley", "p": Vector2(19700.5, 482), "v": Vector2(-400, 0), "t": 0.075, "dead": false}
	state.entities = [trolley]
	var mid := renderer.build_mid(host, state)
	var trolley_commands := mid.filter(func(command): return command.tag.begins_with("trolley_"))
	check(trolley_commands == renderer.build_trolley(Vector2(19700.25, 429.75), true, sin(1.5) * 0.03), "autonomous trolley uses shared source flip bob and feet anchor")
	check(mid.find(trolley_commands[0]) > mid.find(tagged(mid, "wet_sign")[0]), "authored obstacles precede autonomous trolleys")
	trolley.dead = true
	check(tagged(renderer.build_mid(host, state), "trolley_wheel").is_empty(), "dead runtime trolley never renders")
	trolley.dead = false
	var callbacks: Array = []
	renderer.draw_mid(host, state, func(): callbacks.append(host.recorded.size()))
	check(callbacks.size() == 1 and callbacks[0] == host.recorded.size(), "pickups callback once after every mid command")

	# Rear and clipped front wrap the same native feet without changing physics.
	host.camera = Vector2(100.25, -0.25)
	host.player = Vector2(330.6, 482.4)
	for facing in [-1, 1]:
		for animation in ["idle", "run", "crouch", "jump", "shoot"]:
			for on_ground in [false, true]:
				host.face = facing
				host.player_animation = animation
				host.grounded = on_ground
				host.elapsed = 0.105
				var bob := sin(1.75) if on_ground and animation == "run" else 0.0
				var origin := Vector2(270.25, Renderer.source_round(482.4 - 104 + bob) - 0.25)
				var rear := renderer.build_player_back(host, host.player)
				var front := renderer.build_player_front(host, host.player)
				check(rear.size() == 25 and not front.is_empty(), "trolley wrapper geometry exists for every pose")
				check(rear[0].art_rect == Rect2(origin, Vector2(120, 106)), "rear source rounding and60ms run-only bob")
				check(is_equal_approx(rear[0].colour.a, 0.18 * 0.95) and is_equal_approx(tagged(rear, "trolley_rim")[0].colour.a, 0.95), "rear basket opacity multiplies source0.95")
				for command in front:
					check(command.source_region == Rect2(0, 12, 120, 30) and command.layer == "player_front" and command.clip_rect == Rect2(origin + Vector2(0, 12), Vector2(120, 30)), "front exact source120x30 clip metadata")
					check(command.type == "polygon" and inside(command.points, command.clip_rect), "all clipped stroke thickness and fills stay in front basket strip")
				check(tagged(front, "trolley_wheel").is_empty() and tagged(front, "trolley_frame").is_empty() and tagged(front, "trolley_basket_base").is_empty(), "front never redraws wheels frame or basket base over sprite")
				check(tagged(front, "trolley_rim")[0].colour.a == 1, "front restores sourcefull alpha")
				check(front[0].flip_h == (facing < 0), "both player trolley directions")
				var actor := {"p": host.player, "face": facing, "on_ground": on_ground, "act": animation, "down": false}
				check(renderer.build_player_front(host, actor) == front and renderer.build_player_back(host, actor) == rear, "native Vector2 and dictionary wrappers share feet contract")
	host.hearts = 0
	check(renderer.build_player_back(host).is_empty() and renderer.build_player_front(host).is_empty(), "down host hides both trolley passes")
	host.hearts = 3
	check(renderer.build_player_back(host, {"p": host.player, "down": true}).is_empty(), "down participant hides trolley")
	host.mode = "clear"
	host.player_animation = "run"
	host.grounded = true
	check(renderer.build_player_back(host)[0].bob == 0, "clear win animation does not inherit running bob")
	host.mode = "play"

	# Source clock and par are display only; use host elapsed, not runtime timer.
	host.elapsed = 210.99
	host.camera = Vector2((40000 - 738) * 0.5, 0)
	var hud := renderer.build_hud(host, state)
	check(tagged(hud, "dash_elapsed")[0].text == "3:30" and tagged(hud, "dash_par")[0].text == "par 3:30", "elapsed source timer and nonbindingpar3:30")
	check(tagged(hud, "dash_timer_back")[0].type == "rounded", "unboosted timer has no outline")
	check(tagged(hud, "dash_progress")[0].rect == Rect2(280, 514, 200, 10), "progress usescam overWORLD_WminusWV")
	check(tagged(hud, "dash_progress_trolley")[0].art_rect == Rect2(466, 494, 30, 26), "HUD trolley source30x26 and roundedprogress position")
	for command in tagged(hud, "dash_progress_trolley"): check(inside(command.points, command.art_rect), "mini trolley source art bound")
	state.course_controller.boost = true
	host.elapsed = 0.249
	check(tagged(renderer.build_hud(host, state), "dash_boost_label").is_empty(), "boost label offbefore250ms")
	host.elapsed = 0.25
	hud = renderer.build_hud(host, state)
	check(tagged(hud, "dash_timer_back")[0].type == "outlined_rounded" and tagged(hud, "dash_boost_label")[0].text == "Reduced aisle! Faster!", "source boost outline and250ms blink")
	host.elapsed = 0.5
	check(tagged(renderer.build_hud(host, state), "dash_boost_label").is_empty(), "boost label offat500ms")
	var course := Course.new()
	course.boost = true
	state.course_controller = course
	host.elapsed = 360.25
	host.camera.x = 40000
	hud = renderer.build_hud(host, state)
	check(tagged(hud, "dash_elapsed")[0].text == "6:00" and tagged(hud, "dash_progress")[0].rect.size.x == 400, "clock continues beyondpar and progress capsatone")
	check(tagged(hud, "dash_boost_label").size() == 1, "live course object supports boost state")
	for mode in ["menu", "paused", "game_over"]:
		host.mode = mode
		check(renderer.build_hud(host, state).is_empty(), "source dash HUD hiddenin" + mode)
	host.mode = "clear"
	check(not renderer.build_hud(host, state).is_empty(), "source dash HUD remains duringclear")
	host.mode = "play"
	host.camera = Vector2(500, -0.25)
	var front := renderer.build_front(host, state)
	check(tagged(front, "foreground_bollard")[0].rect == Rect2(775, 501.75, 30, 46), "dash bollard1.25 parallax sourceclamp30px")
	check(tagged(front, "foreground_bollard")[0].colour.a == Color(0, 0, 0, 0.94).a, "dash foreground sourcealpha.94")
	check(tagged(front, "foreground_bollard_band")[0].rect == Rect2(775, 511.75, 30, 8), "sourcegreen bollard band")
	state.merge({"wiping": true, "wipe_elapsed": 1.0, "wipe_label": "Test transition"}, true)
	check(tagged(renderer.build_hud(host, state), "wipe_cover").size() == 1, "shared iris still available without inventing2-4 scene")
	state.wiping = false

	var snapshot := JSON.stringify(state)
	var physics := [host.player, host.camera, host.grounded, host.face, host.hearts, host.elapsed]
	var before := [renderer.build_sky(host, state), renderer.build_level(host, state), renderer.build_mid(host, state), renderer.build_player_back(host), renderer.build_player_front(host), renderer.build_front(host, state), renderer.build_hud(host, state)]
	seed(31700)
	var random_expected := randf()
	seed(31700)
	var after := [renderer.build_sky(host, state), renderer.build_level(host, state), renderer.build_mid(host, state), renderer.build_player_back(host), renderer.build_player_front(host), renderer.build_front(host, state), renderer.build_hud(host, state)]
	check(randf() == random_expected, "all draw builders leave global simulationRNG untouched")
	check(before == after and snapshot == JSON.stringify(state) and physics == [host.player, host.camera, host.grounded, host.face, host.hearts, host.elapsed], "draw repeat never mutates actor clocks camera or course state")
	check(original == JSON.stringify(host.meta), "all draw passes preserve all imported hazard tuples")
	host.level_id = "2-5"
	check(renderer.build_sky(host, state).is_empty() and renderer.build_level(host, state).is_empty() and renderer.build_mid(host, state).is_empty() and renderer.build_player_back(host).is_empty() and renderer.build_player_front(host).is_empty() and renderer.build_front(host, state).is_empty() and renderer.build_hud(host, state).is_empty(), "all builders decline unrelated stage")
	host.level_id = "2-4"
	renderer.clear_cache()
	check(renderer._filtered_textures.is_empty(), "shared original texturecache cleanup preserved")

	# Real CanvasItem callback covers every block kind, sign, boost, trolley,
	# both directions, source images, text, HUD, shared bot and inheritediris.
	var canvas := DrawHost.new()
	load_stage(canvas)
	root.add_child(canvas)
	for cx in [1200.25, 2000.25, 2800.25, 4200.25, 4884.25, 19500.25, 39100.25]:
		canvas.camera = Vector2(cx, -0.25)
		canvas.player = Vector2(cx + 330.3, 482.4)
		canvas.face = -canvas.face
		canvas.runtime = {"entities": [{"k": "trolley", "p": Vector2(cx + 500, 482), "v": Vector2(-400, 0), "t": 0.075}], "course_controller": {"boost": true}, "wiping": cx > 39000, "wipe_elapsed": 0.26, "wipe_label": "Test only"}
		canvas.queue_redraw()
		await process_frame
		await process_frame
		check(canvas.order == ["pickups", "rear", "sprite", "front", "hud"], "real draw callbacks preserve source sprite sandwich and HUD order")
	check(canvas.draw_count >= 7 and canvas.pickup_count == canvas.draw_count, "actualNode2D callbacks execute every source hazard kind")
	canvas.queue_free()
	await process_frame
	print("Trolley dash renderer checks: %d assertions; %d failures. Geometry/command QA only, not screenshots, devices or completed gameplay." % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
