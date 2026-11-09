extends SceneTree
## Headless draw-command/resource regression, not screenshot or device QA.
const Renderer = preload("res://src/rooftop_renderer.gd")
const WorldOne = preload("res://src/world_one.gd")
const KEYS := ["sky", "far", "climb", "front", "roof", "chimney", "tank", "aerial", "pigeon", "washing", "landing", "slates", "ladder"]

class Host extends RefCounted:
	var level_id := "1-2"
	var meta: Dictionary = {}
	var level: Dictionary = {}
	var images: Dictionary = {}
	var camera := Vector2.ZERO
	var mode := "play"
	var elapsed := 0.0
	var hearts := 3
	var player := Vector2(300, 482)
	var font: Font = ThemeDB.fallback_font
	var recorded: Array = []
	func view_width() -> float: return 738.0
	func view_top() -> float: return camera.y + 540.0 - 540.0 / 1.3
	func draw_texture_rect_region(texture, rect, source, colour): recorded.append(["texture", texture, rect, source, colour])
	func draw_rect(rect, colour): recorded.append(["rect", rect, colour])
	func draw_polygon(points, colours): recorded.append(["gradient", points, colours])
	func draw_polyline(points, colour, width): recorded.append(["outline", points, colour, width])
	func draw_colored_polygon(points, colour): recorded.append(["polygon", points, colour])
	func draw_string(font_resource, position, text, alignment, width, size, colour): recorded.append(["text", font_resource, position, text, alignment, width, size, colour])
	func draw_string_outline(font_resource, position, text, alignment, width, size, stroke, colour): recorded.append(["text_outline", font_resource, position, text, alignment, width, size, stroke, colour])

class DrawHost extends Node2D:
	var renderer = Renderer.new()
	var scene = WorldOne.new()
	var level_id := "1-2"
	var meta: Dictionary = {}
	var level: Dictionary = {}
	var images: Dictionary = {}
	var camera := Vector2.ZERO
	var mode := "play"
	var elapsed := 4.0
	var hearts := 3
	var player := Vector2(300, 482)
	var font: Font = ThemeDB.fallback_font
	var draw_count := 0
	func view_width() -> float: return 738.0
	func view_top() -> float: return camera.y + 540.0 - 540.0 / 1.3
	func _draw() -> void:
		draw_set_transform(Vector2(-camera.x * 1.3, 540 * (1 - 1.3) - camera.y * 1.3), 0, Vector2.ONE * 1.3)
		renderer.draw_scene(self, scene)
		renderer.draw_front(self, scene)
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

func named(commands: Array, key: String) -> Array:
	return commands.filter(func(command): return command.type == "texture" and command.key == key)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host := Host.new()
	host.meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/1-2.json"))
	host.level = host.meta.level
	for key in KEYS:
		check(host.meta.imgs.has(key), "imported source resource " + key)
		if not host.meta.imgs.has(key): continue
		check(ResourceLoader.exists(host.meta.imgs[key]), "loadable source resource " + key)
		host.images[key] = load(host.meta.imgs[key])
		check(host.images[key].get_size() == Vector2(host.meta.dims[key][0], host.meta.dims[key][1]), "unaltered full-resolution artwork " + key)
	var renderer = Renderer.new()
	var scene = WorldOne.new()
	scene.reset(host)
	var original_level := JSON.stringify(host.level)
	var original_scene := JSON.stringify(scene.crumbles)
	check(scene.crumbles.size() == 12, "all source crumble decorations available")
	check(Renderer.source_round(-0.5) == 0 and Renderer.source_round(-1.5) == -1 and Renderer.source_round(1.5) == 2, "JavaScript negative-half rounding")
	# Partial tiles are cropped in source pixels, not resized or leaked outside.
	var clip := Renderer.clipped_region(Rect2(100, 200, 332, 126), Rect2(0, 0, 332, 126), Rect2(120, 220, 100, 80))
	check(clip.rect == Rect2(120, 220, 100, 80) and clip.source == Rect2(20, 20, 100, 80), "two-axis unscaled clipping")
	clip = Renderer.clipped_region(Rect2(100, 200, 332, 126), Rect2(0, 0, 664, 252), Rect2(120, 220, 100, 80), true)
	check(clip.source == Rect2(424, 40, 200, 160), "mirrored scaled crop selects matching original pixels")
	check(Renderer.clipped_region(Rect2(0, 0, 100, 100), Rect2(0, 0, 100, 100), Rect2(100, 100, 20, 20)).is_empty(), "touching boundary does not draw a tile")
	check(Renderer.clipped_region(Rect2(0, 0, 100, 100), Rect2(0, 0, 100, 100), Rect2(0, 0, 0, 20)).is_empty(), "empty clip stays empty")

	var commands: Array = renderer.build_scene(host, scene)
	var mirror := tagged(commands, "climb_mirror")
	var climb := tagged(commands, "climb")
	check(mirror.size() == 1 and mirror[0].rect == Rect2(-311, -194, 451, 676) and mirror[0].flip_h, "initial mirrored-left house painting")
	check(climb.size() == 1 and climb[0].rect == Rect2(140, -194, 451, 676) and not climb[0].flip_h, "regular right-hand fire escape painting is retained")
	var fronts := tagged(commands, "climb_front")
	check(fronts.size() == 2, "first house facade tiles")
	check(fronts.size() == 2 and fronts[1].rect == Rect2(472, 480, 119, 126) and fronts[1].source == Rect2(0, 0, 119, 126), "last facade tile clipped at 451px house boundary")
	check(tagged(commands, "yard_gate")[0].rect == Rect2(50, 378, 54, 104), "source gate coordinates")
	check(tagged(commands, "yard_cap")[0].rect == Rect2(-400, 356, 540, 8), "source garden wall cap")
	check(commands.find(tagged(commands, "climb_front_shade")[0]) < commands.find(tagged(commands, "yard_wall")[0]), "yard wall draws over climbing house extension")
	var sky := named(commands, "sky")
	check(sky.size() == 1 and sky[0].rect == Rect2(0, 152, 1306, 366) and sky[0].smooth, "sky uses native 1306x366 painting and source sky height")
	check(tagged(commands, "sky_gradient")[0].colours[0] == Color("5b4a8a") and tagged(commands, "sky_gradient")[0].colours[2] == Color("e98a6a"), "sunset top and midpoint gradient stops")
	check(tagged(commands, "far_back")[0].rect.position.y == 484, "far roofs first row baseline")
	check(tagged(commands, "far_front")[0].rect.position.y == 524 and tagged(commands, "far_front")[0].alpha == 0.85, "nearer far row offset and alpha")
	check(JSON.stringify(host.level) == original_level and JSON.stringify(scene.crumbles) == original_scene, "render planning leaves source and simulation untouched")

	# A fractional camera must match source Math.round in camera-relative space.
	host.camera = Vector2(601.25, -300.25)
	commands = renderer.build_scene(host, scene)
	var roofs := tagged(commands, "roof")
	check(roofs.size() >= 2 and roofs[0].rect.position == Vector2(591.25, -156.25), "source artwork pixel snap with noninteger camera")
	check(roofs.size() >= 2 and roofs[1].rect.position.x - roofs[0].rect.position.x == 332, "roof repetition stays at native 332px stride")
	check(commands.find(tagged(commands, "roof_front")[0]) < commands.find(roofs[0]), "roof covers the upper 4px of its facade")
	sky = named(commands, "sky")
	var expected_bottom := Renderer.source_round(470 + (host.camera.y + 604) * 0.08)
	check(sky[0].rect.position.y == host.camera.y + expected_bottom - 366, "screen-fixed background compensates camera.y")
	check(sky[0].rect.position.x - host.camera.x == -Renderer.source_round(host.camera.x * 0.12), "sky horizontal parallax 0.12")
	for command in tagged(commands, "far_back"):
		var relative_x: float = command.rect.position.x - host.camera.x
		check(is_zero_approx(fposmod(relative_x + Renderer.source_round(host.camera.x * 0.3), 158)), "far back horizontal parallax 0.30")
	for command in tagged(commands, "far_front"):
		var relative_x: float = command.rect.position.x - host.camera.x
		check(is_zero_approx(fposmod(relative_x + Renderer.source_round(host.camera.x * 0.42) + 79, 158)), "far front 0.42 parallax and half-tile offset")
	# Mirror sky images on every other tile, including when the camera crosses
	# the source rounding discontinuity at a complete tile.
	for camera_x in [10883.0, 10883.333333333334, 11200.0, 19922.0]:
		host.camera = Vector2(camera_x, -900)
		sky = named(renderer.build_scene(host, scene), "sky")
		var actual_x := float(host.camera.x)
		var n0 := int(floorf(actual_x * 0.12 / 1306))
		var first_x := fmod(-Renderer.source_round(actual_x * 0.12), 1306)
		for command in sky:
			var index := int(roundf((command.rect.position.x - actual_x - first_x) / 1306))
			check(command.flip_h == ((n0 + index) % 2 != 0), "source sky mirror parity at %.3f" % camera_x)
	# Exact source final partial roof/facade column; no art bridges the gap.
	var saved_level: Dictionary = host.level
	host.level = {"roofs": [[591, 1042, -152]], "ridge": 4}
	host.camera = Vector2(580, -300)
	commands = renderer.build_scene(host, scene)
	roofs = tagged(commands, "roof")
	check(roofs.size() == 2 and roofs[1].rect == Rect2(923, -156, 119, 212) and roofs[1].source == Rect2(0, 0, 119, 212), "partial roof end crops original artwork")
	for command in tagged(commands, "roof_front") + roofs:
		check(command.rect.end.x <= 1042 and command.rect.position.x >= 591, "roof and facade contained in original clip")
		check(command.rect.size == command.source.size, "no partial roof or facade stretching")
	host.camera = Vector2(580, -634)
	roofs = tagged(renderer.build_scene(host, scene), "roof")
	check(roofs.size() == 2 and roofs[1].rect == Rect2(923, -156, 119, 84) and roofs[1].source == Rect2(0, 0, 119, 84), "source camera-bottom clipping crops both axes")
	host.level = saved_level
	host.camera = Vector2(7750, -900)
	commands = renderer.build_scene(host, scene)
	check(tagged(commands, "climb_mirror").is_empty(), "second climbing house has no reflected duplicate")
	climb = tagged(commands, "climb")
	check(climb.size() == 1 and climb[0].rect == Rect2(7870, -604, 451, 676), "second climbing house native position and dimensions")

	# Both decor flags preserve source artwork; crumbling never changes rows.
	host.camera = Vector2(1600, -575)
	commands = renderer.build_scene(host, scene)
	check(named(commands, "pigeon").any(func(command): return command.flip_h and command.rect == Rect2(1795, -128, 44, 38)), "decor mirror flag is retained")
	host.camera = Vector2(5600, -634)
	commands = renderer.build_scene(host, scene)
	var slate_commands := named(commands, "slates")
	check(slate_commands.size() == 3 and slate_commands[0].rect == Rect2(5679, -230, 195, 96), "slates use decor origin, not collision origin")
	scene.crumbles[0].t = 0.3
	var shaken: Dictionary = named(renderer.build_scene(host, scene), "slates")[0]
	check(absf(shaken.rect.position.x - 5679) <= 2 and shaken.rect.position.y == -230, "pre-fall shake stays within source horizontal range")
	check(shaken == named(renderer.build_scene(host, scene), "slates")[0], "repeat/paused rendering does not consume gameplay randomness")
	scene.crumbles[0].fall = 0.25
	var fallen: Dictionary = named(renderer.build_scene(host, scene), "slates")[0]
	check(fallen.rect.position == Vector2(5679, -155) and is_equal_approx(fallen.alpha, 1 - 0.25 / 0.7), "seconds-based quadratic fall and source fade")
	check(scene.crumbles[0].row == host.level.crumble[0] and scene.crumbles[0].row[2] == -222, "fall rendering never moves collision/source rows")
	scene.crumbles[0].fall = 0.701
	check(not named(renderer.build_scene(host, scene), "slates").any(func(command): return command.rect.position.x == 5679), "fallen slate hidden after 700ms")
	scene.reset(host)
	check(named(renderer.build_scene(host, scene), "slates")[0].rect.position == Vector2(5679, -230), "reset restores original slate artwork")
	# Every source decoration and every roof run is exercised at its own camera
	# position, rather than only testing the initial screen.
	for decor in host.level.decor:
		host.camera = Vector2(float(decor[1]) - 100, float(decor[2]) - 150)
		commands = renderer.build_scene(host, scene)
		var key: String = "climb" if decor[0] == "climb2" else decor[0]
		var size := Vector2(host.meta.dims[key][0], host.meta.dims[key][1])
		var expected := Rect2(float(decor[1]), float(decor[2]), size.x, size.y)
		check(named(commands, key).any(func(command): return command.rect == expected and command.source == Rect2(Vector2.ZERO, size)), "source decor artwork at %s:%s" % [key, decor[1]])
	for roof in host.level.roofs:
		host.camera = Vector2(float(roof[0]) - 50, float(roof[2]) - 200)
		commands = renderer.build_scene(host, scene)
		check(tagged(commands, "roof").any(func(command): return command.rect.position == Vector2(roof[0], roof[2] - host.level.ridge)), "source roof restarts painting at %s" % roof[0])
	check(JSON.stringify(scene.crumbles) == original_scene, "all source-view traversals keep crumble state unchanged")
	# Missing assets should not crash or substitute generic grey geometry.
	var saved_images: Dictionary = host.images
	host.images = {}
	commands = renderer.build_scene(host, scene)
	check(commands.all(func(command): return command.type != "texture"), "missing images are skipped safely")
	check(not tagged(commands, "sky_gradient").is_empty(), "sunset still draws when sky texture unavailable")
	host.images = saved_images
	host.camera = Vector2.ZERO
	host.elapsed = 3.4
	check(renderer.build_front(host).is_empty(), "hint does not appear before source delay")
	host.elapsed = 4
	check(renderer.build_front(host).size() == 2, "source fire-escape text and arrow")
	host.player.y = 442
	check(renderer.build_front(host).is_empty(), "hint disappears after climbing")
	host.player.y = 482
	host.mode = "paused"
	check(renderer.build_front(host).is_empty(), "paused hint suppressed")
	host.mode = "play"
	host.hearts = 0
	check(renderer.build_front(host).is_empty(), "downed player gets no climbing hint")
	host.hearts = 3
	host.level.front = [["climb", 1.3, 300, 0, "bottom"]]
	check(renderer.build_front(host).all(func(command): return command.type != "texture"), "bd-fixes removed foreground stays removed")
	host.level.erase("front")
	check(JSON.stringify(host.level) == original_level, "entire source level remains unchanged after all drawing")
	# Replay commands against a recording host to verify actual canvas calls,
	# texture filter selection, mirror rectangles and per-draw alpha reset.
	host.camera = Vector2.ZERO
	renderer.draw_scene(host, scene)
	renderer.draw_front(host, scene)
	var texture_calls: Array = host.recorded.filter(func(call): return call[0] == "texture")
	check(not texture_calls.is_empty(), "draw_scene issues texture calls")
	check(texture_calls.any(func(call): return call[1].diffuse_texture == host.images.climb and call[2].size.x == -451), "mirrored painting uses negative destination width")
	check(texture_calls.any(func(call): return call[1].diffuse_texture == host.images.sky and call[1].texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR), "source sky smoothing")
	check(texture_calls.any(func(call): return call[1].diffuse_texture == host.images.roof or (call[1].diffuse_texture == host.images.front and call[1].texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)), "source painted tile filtering without resampling assets")
	check(host.recorded.any(func(call): return call[0] == "text" and call[3] == "Up the fire escape!"), "front draw issues tutorial text")
	check(host.recorded.any(func(call): return call[0] == "text_outline" and call[3] == "Up the fire escape!"), "source tutorial text retains dark outline")
	# Drive actual CanvasItem draw APIs in the headless engine. No pixel/readback
	# or graphical rendering assertion is possible on this runner.
	var draw_host := DrawHost.new()
	draw_host.meta = host.meta
	draw_host.level = host.level
	draw_host.images = host.images
	draw_host.scene.reset(draw_host)
	root.add_child(draw_host)
	for camera_position in [Vector2.ZERO, Vector2(580, -634), Vector2(5600, -634), Vector2(7750, -900), Vector2(11000, -1054), Vector2(17200, -874), Vector2(19184, -864)]:
		draw_host.camera = camera_position
		draw_host.queue_redraw()
		await process_frame
		await process_frame
	check(draw_host.draw_count > 0, "headless CanvasItem draw callback exercised")
	draw_host.queue_free()
	await process_frame
	renderer.clear_cache()
	if failures.is_empty():
		print("Rooftop renderer checks passed: %d assertions; original resources, layers, clipping, parallax, crumble visuals, hint and headless draw calls. No screenshot/device QA." % assertions)
	else:
		printerr("Rooftop renderer failed %d/%d checks." % [failures.size(), assertions])
	quit(0 if failures.is_empty() else 1)
