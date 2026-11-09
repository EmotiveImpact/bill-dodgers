extends SceneTree
## Original resource/geometry/canvas-call regressions, not screenshot QA.
const Renderer = preload("res://src/bus_renderer.gd")
const KEYS := ["sky", "town0", "embank", "bus", "bridgeback", "bridge", "branch", "scooter", "jtree", "girder", "drone"]

class Host extends RefCounted:
	var meta: Dictionary = {}
	var level: Dictionary = {}
	var images: Dictionary = {}
	var camera := Vector2(0, -235)
	var font: Font = ThemeDB.fallback_font
	var recorded: Array = []
	func view_width() -> float: return 738.0
	func view_top() -> float: return camera.y + 540.0 - 540.0 / 1.3
	func draw_texture_rect_region(texture, rect, source, colour): recorded.append(["texture", texture, rect, source, colour])
	func draw_rect(rect, colour): recorded.append(["rect", rect, colour])
	func draw_polygon(points, colours): recorded.append(["gradient", points, colours])
	func draw_colored_polygon(points, colour): recorded.append(["polygon", points, colour])
	func draw_circle(position, radius, colour): recorded.append(["circle", position, radius, colour])
	func draw_string(font_resource, position, text, alignment, width, size, colour): recorded.append(["text", font_resource, position, text, alignment, width, size, colour])
	func draw_string_outline(font_resource, position, text, alignment, width, size, stroke, colour): recorded.append(["text_outline", font_resource, position, text, alignment, width, size, stroke, colour])

class Scene extends RefCounted:
	var drive := 0.0
	var obstacles: Array = []
	var scooters: Array = []
	var warn_time := 0.0

class DrawHost extends Node2D:
	var renderer = Renderer.new()
	var scene = Scene.new()
	var meta: Dictionary = {}
	var level: Dictionary = {}
	var images: Dictionary = {}
	var camera := Vector2(0, -235)
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
	host.meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/1-3.json"))
	host.level = host.meta.level.duplicate(true)
	for key in KEYS:
		check(host.meta.imgs.has(key), "original imported resource " + key)
		if not host.meta.imgs.has(key): continue
		check(ResourceLoader.exists(host.meta.imgs[key]), "loadable original art " + key)
		host.images[key] = load(host.meta.imgs[key])
		check(host.images[key].get_size() == Vector2(host.meta.dims[key][0], host.meta.dims[key][1]), "full-resolution original pixels " + key)
	var renderer = Renderer.new()
	var scene := Scene.new()
	var original_level := JSON.stringify(host.level)
	check(Renderer.source_round(-1.5) == -1 and Renderer.source_round(-0.5) == 0 and Renderer.source_round(0.5) == 1, "source Math.round including negative halves")
	var commands: Array = renderer.build_scene(host, scene)
	check(named(commands, "sky").size() == 1, "skyline is one painting, never tiled")
	check(named(commands, "sky")[0].rect == Rect2(0, -475, 1536, 430), "sky draws before camera y translation at roof minus 390")
	check(named(commands, "sky")[0].source == Rect2(0, 0, 1536, 430), "sky preserves entire original texture")
	check(not named(commands, "sky")[0].smooth, "source 1-3 sky uses nearest canvas sampling")
	var gradients := tagged(commands, "sky_gradient")
	check(gradients[0].rect == Rect2(-10, -235, 758, 297), "sunset midpoint remains source 55 percent")
	check(gradients[0].colours[0] == Color("5b4a8a") and gradients[0].colours[2] == Color("e98a6a"), "source upper sunset colours")
	check(gradients[1].colours[2] == Color("f6c27a"), "source lower sunset colour")
	check(named(commands, "town0")[0].rect == Rect2(0, -180, 815, 620), "native town painting at roof minus 330")
	check(named(commands, "embank").is_empty(), "offscreen town batch culled without cropping artwork")
	check(named(commands, "bus")[0].rect == Rect2(19, 146, 700, 385), "original red bus placement and size")
	check(named(commands, "jtree").is_empty(), "no join trees for source single-town configuration")
	check(renderer.build_front(host, scene).is_empty(), "no unrequested foreground props or collision rectangles")
	check(renderer.build_scene(host) == commands, "default scene draws static source layout")

	# Each source town batch, including the one-off embankment, at full scale.
	for distance in [700.0, 1500.0, 3000.0, 6000.0]:
		scene.drive = distance
		commands = renderer.build_scene(host, scene)
		var towns := tagged(commands, "town")
		check(not towns.is_empty(), "visible town batches at distance %s" % distance)
		var base_index := int(floorf(distance * 0.7 / 815))
		var base_x := fmod(-Renderer.source_round(distance * 0.7), 815)
		for town in towns:
			var index: int = town.town_index
			check(town.rect == Rect2(base_x + (index - base_index) * 815, -180, 815, 620), "town 0.7 parallax and 815px stride %s:%s" % [distance, index])
			check(town.key == ("embank" if index == 1 else "town0"), "one-off embankment selection %s:%s" % [distance, index])
			check(town.flip_h == (index % 2 != 0), "alternating native town reflection %s:%s" % [distance, index])
		check(named(commands, "sky")[0].rect.position.x == -Renderer.source_round(distance * 0.006), "skyline 0.006 parallax %s" % distance)
	check(renderer.town_at(host, 1) == "embank", "source embankAt index")
	check(renderer.town_at(host, 0) == "town0" and renderer.town_at(host, 2) == "town0" and renderer.town_at(host, 101) == "town0", "embankment never repeats")
	scene.drive = 814.6 / 0.7
	commands = renderer.build_scene(host, scene)
	check(tagged(commands, "town")[0].town_index == 0 and is_zero_approx(tagged(commands, "town")[0].rect.position.x), "rounding before remainder retains source wrap-boundary behaviour")
	scene.drive = 815.0 / 0.7
	check(tagged(renderer.build_scene(host, scene), "town")[0].key == "embank", "next batch after unrounded distance crosses stride")
	scene.drive = 200000
	var sky := named(renderer.build_scene(host, scene), "sky")
	check(sky.size() == 1 and sky[0].rect.position.x == -798, "skyline stops at right image edge and never wraps")
	scene.drive = 400000
	check(named(renderer.build_scene(host, scene), "sky")[0].rect == sky[0].rect, "sky remains capped for rest of ride")

	# Multi-town source branch retains join trees and post-embank indexing.
	host.level.towns = ["town0", "embank"]
	check(renderer.town_at(host, 0) == "town0" and renderer.town_at(host, 1) == "embank" and renderer.town_at(host, 2) == "embank" and renderer.town_at(host, 3) == "town0", "insertion shifts multi-town sequence only after embankment")
	check(renderer.town_at(host, -1) == "embank", "negative town indices wrap like source normalized modulo")
	scene.drive = 600
	commands = renderer.build_scene(host, scene)
	check(tagged(commands, "town").all(func(command): return not command.flip_h), "multiple town paintings are never reflected")
	check(named(commands, "jtree").size() == 1 and named(commands, "jtree")[0].rect == Rect2(208, -35, 428, 400), "join tree trunk source proportion and native size")
	host.level = host.meta.level.duplicate(true)
	host.level.erase("towns")
	check(renderer.town_at(host, 2) == "town0", "town image name discovery when towns field absent")
	host.level = host.meta.level.duplicate(true)
	host.camera.y = 0
	commands = renderer.build_scene(host, scene)
	check(tagged(commands, "town_base")[0].rect == Rect2(-10, 438, 758, 600) and tagged(commands, "town_base")[0].colour == Color("3b2f3a"), "source opaque street fill below paintings")
	host.camera.y = -235

	for sample in [[0.0, 0], [PI * 20, 1], [PI * 60, -1]]:
		scene.drive = sample[0]
		check(named(renderer.build_scene(host, scene), "bus")[0].rect.position.y == 146 + sample[1], "source bus bob phase %s" % sample[0])
	scene.drive = 700
	scene.obstacles = [{"k": "bridge", "x": 100.5, "w": 330.0, "hit": false}, {"k": "branch", "x": 500.49, "w": 150.0, "hit": false}]
	scene.scooters = [{"x": 300.5, "y": 290.5, "face": 1}, {"x": 500.49, "y": 260.49, "face": -1}]
	var state_before := [scene.drive, scene.warn_time, JSON.stringify(scene.obstacles), JSON.stringify(scene.scooters)]
	commands = renderer.build_scene(host, scene)
	check(tagged(commands, "bridge_back")[0].rect == Rect2(101, 18, 330, 507), "bridgeback piers behind bus at roof minus 132")
	var scooters := tagged(commands, "scooter")
	check(scooters[0].rect == Rect2(217.5, 141, 167, 150) and scooters[0].flip_h, "positive-facing scooter reflects around rounded centre")
	check(scooters[1].rect == Rect2(416.5, 110, 167, 150) and not scooters[1].flip_h, "negative-facing scooter native orientation")
	check(tagged(commands, "obstacle_shadow")[0].rect == Rect2(101, 144, 330, 10), "source obstacle shadow on roof")
	check(is_equal_approx(tagged(commands, "obstacle_shadow")[0].colour.a, 0.35), "source obstacle shadow alpha")
	check(commands.find(tagged(commands, "bridge_back")[0]) < commands.find(named(commands, "bus")[0]), "back abutment draws behind red bus")
	check(commands.find(named(commands, "bus")[0]) < commands.find(scooters[0]) and commands.find(scooters[1]) < commands.find(tagged(commands, "obstacle_shadow")[0]), "bus then scooters then roof shadows")
	var front := renderer.build_front(host, scene)
	check(tagged(front, "bridge_front")[0].rect == Rect2(87, -110, 358, 132), "front bridge offset and bottom lip")
	check(tagged(front, "branch_front")[0].rect == Rect2(480, -168, 237, 200), "front branch source offset and canopy size")
	check(commands.all(func(command): return command.tag not in ["bridge_front", "branch_front"]), "occluding obstacles stay out of actor background pass")
	check(state_before == [scene.drive, scene.warn_time, JSON.stringify(scene.obstacles), JSON.stringify(scene.scooters)], "rendering never advances or mutates ride simulation")

	# Fractional cameras reproduce canvas rounding without moving fixed arena art.
	host.camera = Vector2(23.5, -235.25)
	commands = renderer.build_scene(host, scene)
	check(tagged(commands, "bridge_back")[0].rect.position == Vector2(124.5, 17.75), "level artwork compensates camera x and vertical rounding")
	check(named(commands, "sky")[0].rect.position == Vector2(19.5, -475.25), "sky ignores world vertical camera and uses rounded drive offset")
	check(named(commands, "bus")[0].rect.position.x - host.camera.x == 19, "bus does not drift with host camera x")
	host.camera = Vector2(0, -235)
	for sample in [[0.0, false], [0.19, true], [0.2, false], [0.4, true], [1.2, true], [1.6, true], [1.9, false]]:
		scene.warn_time = sample[0]
		check((not tagged(renderer.build_front(host, scene), "duck_warning").is_empty()) == sample[1], "source 200ms warning blink at %s seconds" % sample[0])
	scene.warn_time = 1.2
	front = renderer.build_front(host, scene)
	check(tagged(front, "duck_warning")[0].position == Vector2(648, -20) and tagged(front, "duck_warning")[0].stroke_width == 6.5, "source Duck text position, size and outline")
	check(tagged(front, "duck_arrow")[0].points == PackedVector2Array([Vector2(648, 34), Vector2(630, 8), Vector2(666, 8)]), "source downward warning triangle")
	host.level.front = [["bus", 1.9, 1300, 200, "bottom", "drive"]]
	check(named(renderer.build_front(host, scene), "bus").is_empty(), "bd-fixes removed sweeping foreground remains absent")
	host.level = host.meta.level.duplicate(true)
	check(JSON.stringify(host.level) == original_level, "source level stays unchanged")
	var background: Array = renderer.build_background(host, scene, 0.62)
	check(background.back().tag == "background_dim" and is_equal_approx(background.back().colour.a, 0.62), "source drawBG optional dim overlay after sky")
	check(named(background, "town0").is_empty() and named(background, "bus").is_empty(), "background API does not paint level actors")

	# Missing assets preserve the source's own fallbacks, not new placeholder art.
	var saved_images: Dictionary = host.images
	host.images = {}
	commands = renderer.build_scene(host, scene)
	front = renderer.build_front(host, scene)
	check(commands.all(func(command): return command.type != "texture"), "missing texture planning is safe")
	check(not tagged(commands, "sky_gradient").is_empty(), "sunset gradient remains without sky painting")
	check(tagged(commands, "scooter_wheel_fallback").size() == 4, "source scooter fallback wheels")
	check(tagged(front, "bridge_fallback")[0].rect == Rect2(101, -12, 330, 30), "source missing-bridge fallback beam")
	check(tagged(front, "branch_leaves_fallback").size() == 9, "source missing-branch fallback leaves")
	renderer.draw_scene(host, scene)
	renderer.draw_front(host, scene)
	check(host.recorded.any(func(call): return call[0] == "circle"), "source fallback circles reach canvas API")
	host.images = saved_images
	host.recorded.clear()
	renderer.draw_scene(host, scene)
	renderer.draw_front(host, scene)
	var texture_calls: Array = host.recorded.filter(func(call): return call[0] == "texture")
	check(not texture_calls.is_empty(), "native draw_scene issues actual texture calls")
	check(texture_calls.any(func(call): return call[1].diffuse_texture == host.images.embank and call[2].size.x == -815), "mirrored embankment uses unchanged texture and negative destination width")
	check(texture_calls.any(func(call): return call[1].diffuse_texture == host.images.scooter and call[2].size.x == -167), "scooter texture reflection reaches canvas API")
	check(texture_calls.all(func(call): return call[1].texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST), "source sampler chosen per texture without asset resampling")
	check(host.recorded.any(func(call): return call[0] == "text" and call[3] == "Duck!"), "warning text reaches canvas API")
	check(host.recorded.any(func(call): return call[0] == "text_outline" and call[3] == "Duck!"), "warning source dark outline retained")
	check(host.recorded.any(func(call): return call[0] == "polygon"), "warning triangle reaches canvas API")
	# A real Node2D exercises the native CanvasItem methods under headless Godot.
	var draw_host := DrawHost.new()
	draw_host.meta = host.meta
	draw_host.level = host.level
	draw_host.images = host.images
	draw_host.scene = scene
	root.add_child(draw_host)
	for distance in [0.0, 700.0, 1500.0, 6000.0, 200000.0]:
		scene.drive = distance
		draw_host.queue_redraw()
		await process_frame
		await process_frame
	check(draw_host.draw_count > 0, "headless CanvasItem draw callback exercised")
	draw_host.images = {}
	draw_host.queue_redraw()
	await process_frame
	await process_frame
	draw_host.queue_free()
	await process_frame
	renderer.clear_cache()
	if failures.is_empty():
		print("Bus renderer checks passed: %d assertions; original art, layering, sky/town parallax, embankment, bridges, branches, scooters, warning and native draw calls. No screenshot/device QA." % assertions)
	else:
		printerr("Bus renderer failed %d/%d checks." % [failures.size(), assertions])
	quit(0 if failures.is_empty() else 1)
