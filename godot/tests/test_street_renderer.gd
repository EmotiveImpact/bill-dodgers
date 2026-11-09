extends SceneTree
## Draw geometry and resource checks, not screenshot, visual or device QA.
const Renderer = preload("res://src/street_renderer.gd")
const WorldOne = preload("res://src/world_one.gd")

class Host extends RefCounted:
	var level_id := "1-4"
	var meta: Dictionary = {}
	var level: Dictionary = {}
	var images: Dictionary = {}
	var camera := Vector2.ZERO
	var elapsed := 0.0
	var player := Vector2(260, 482)
	var combat = null
	var font: Font = load("res://assets/fonts/silk.woff2")
	var recorded: Array = []
	func view_width() -> float: return 738.0
	func view_top() -> float: return camera.y + 540.0 - 540.0 / 1.3
	func draw_texture_rect_region(texture, rect, source, colour): recorded.append(["texture", texture, rect, source, colour])
	func draw_rect(rect, colour): recorded.append(["rect", rect, colour])
	func draw_colored_polygon(points, colour): recorded.append(["polygon", points, colour])
	func draw_style_box(style, rect): recorded.append(["style", style, rect])
	func draw_string(font_resource, position, text, alignment, width, size, colour): recorded.append(["text", font_resource, position, text, alignment, width, size, colour])

class DrawHost extends Node2D:
	var renderer = Renderer.new()
	var scene = WorldOne.new()
	var level_id := "1-4"
	var meta: Dictionary = {}
	var level: Dictionary = {}
	var images: Dictionary = {}
	var camera := Vector2.ZERO
	var elapsed := 0.0
	var player := Vector2(260, 482)
	var combat = null
	var font: Font = load("res://assets/fonts/silk.woff2")
	var draw_count := 0
	func view_width() -> float: return 738.0
	func view_top() -> float: return camera.y + 540.0 - 540.0 / 1.3
	func _draw() -> void:
		draw_set_transform(Vector2(-camera.x * 1.3, 540 * (1 - 1.3) - camera.y * 1.3), 0, Vector2.ONE * 1.3)
		renderer.draw_scene(self, scene)
		renderer.draw_front(self, scene)
		draw_count += 1

var assertions := 0
var failures: Array[String] = []
var renderer = Renderer.new()

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: " + label)

func tagged(commands: Array, tag: String) -> Array:
	return commands.filter(func(command): return command.tag == tag)

func textures(commands: Array) -> Array:
	return commands.filter(func(command): return command.type == "texture")

func load_stage(host, id: String) -> void:
	host.level_id = id
	host.meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/%s.json" % id))
	host.level = host.meta.level
	host.images = {}
	host.camera = Vector2.ZERO
	host.elapsed = 0.0
	host.combat = null
	for key in host.meta.imgs:
		check(ResourceLoader.exists(host.meta.imgs[key]), id + " imported resource " + key)
		host.images[key] = load(host.meta.imgs[key])
		check(host.images[key].get_size() == Vector2(host.meta.dims[key][0], host.meta.dims[key][1]), id + " unchanged native dimensions " + key)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host := Host.new()
	var scene := WorldOne.new()
	check(host.font != null and not host.font == ThemeDB.fallback_font, "uses bundled Silkscreen")
	check(Renderer.source_round(-0.5) == 0 and Renderer.source_round(-1.5) == -1 and Renderer.source_round(1.5) == 2, "source JavaScript half rounding")
	for id in ["1-4", "1-5", "1-S", "1-6"]:
		load_stage(host, id)
		scene.reset(host)
		var original := JSON.stringify(host.meta)
		var original_scene := [scene.next_coin, scene.coin_pattern, scene.end_time]
		check(renderer.supports(id), id + " supported")
		check(not renderer.supports("1-1"), "does not claim unrelated renderer")
		var commands: Array = renderer.build_scene(host, scene)
		var expected_colour := Color(host.level.get("skyCol", "#2a3348"))
		check(tagged(commands, "sky_fill").size() == 1 and tagged(commands, "sky_fill")[0].colour == expected_colour, id + " exact source background fill")
		check(tagged(commands, "sky_fill")[0].rect == Rect2(-10, -10, 758, 560), id + " sky edge overscan")
		for x in [0.0, 450.0, 947.5, 948.0, 1896.25, float(host.level.w) - 738]:
			host.camera = Vector2(x, -32.25)
			commands = renderer.build_scene(host, scene)
			for command in textures(commands):
				check(command.rect.size == command.source.size and command.source.position == Vector2.ZERO, id + " native pixels are not stretched/cropped " + command.key)
				check(command.rect.size == host.images[command.key].get_size(), id + " full original texture " + command.key)
				check(not command.smooth and command.alpha == 1.0, id + " source nearest filtering and opacity " + command.key)
			check(not commands.any(func(command): return command.get("key", "") in ["flamp", "fleaf"]), id + " bd-fixes removes sweeping foreground")
			if id != "1-6":
				var backgrounds := tagged(commands, "scene_tile")
				var first := int(floorf(x / 948))
				check(not backgrounds.is_empty() and backgrounds[0].index == first, id + " source start tile at %.2f" % x)
				for painting in backgrounds:
					check(painting.key == "t%d" % (painting.index % 2) and not painting.flip_h, id + " alternating painting keys without reflection")
					check(painting.rect == Rect2(x + floorf(painting.index * 948 - x + 0.5), host.camera.y, 948, 540), id + " source scene camera rounding")
				for tree in tagged(commands, "join_tree"):
					check(tree.rect == Rect2(x + floorf(tree.index * 948 - x - 491 * 0.44 + 0.5), 30.75, 491, 459), id + " source seam tree anchor")
					check(tree.flip_h == (tree.index % 2 != 0), id + " seam tree mirror alternates at joins")
			else:
				for painting in tagged(commands, "street_chunk"):
					check(painting.rect.position == Vector2(x + floorf(painting.index * 2048 - x + 0.5), host.camera.y), "Bin Day nonrepeating chunk camera position")
					check(painting.key == "st%d" % painting.index, "Bin Day chunk asset selection")
		# Source checkpoints get runtime hit state and surface height, not a
		# hard-coded ground baseline. Alley flag stands on an obstacle.
		for checkpoint_x in host.level.get("checks", []):
			host.camera = Vector2(checkpoint_x - 300.25, -32.25)
			host.elapsed = PI * 0.08
			host.combat = {"checks": [{"x": float(checkpoint_x), "hit": false}]}
			commands = renderer.build_scene(host, scene)
			var y := float(scene.below(host, checkpoint_x, -9999).row[2]) - 0.25
			var x := float(host.camera.x) + 300
			check(tagged(commands, "checkpoint_pole")[0].rect == Rect2(x - 3, y - 150, 6, 150), id + " exact flag pole")
			check(tagged(commands, "checkpoint_cap")[0].rect == Rect2(x - 6, y - 156, 12, 8), id + " gold pole cap")
			check(tagged(commands, "checkpoint_mark")[0].rect == Rect2(x + 14, y - 132, 12, 4), id + " white flag mark")
			var flag: Dictionary = tagged(commands, "checkpoint_flag")[0]
			check(flag.points == PackedVector2Array([Vector2(x + 3, y - 146), Vector2(x + 58, y - 129), Vector2(x + 3, y - 112)]), id + " source flag waving seconds converted from milliseconds")
			check(flag.colour == Color("7a8aa8"), id + " inactive flag colour")
			host.combat.checks[0].hit = true
			check(tagged(renderer.build_scene(host, scene), "checkpoint_flag")[0].colour == Color("2d6a4f"), id + " active checkpoint colour")
			check(renderer.build_scene(host, scene) == renderer.build_scene(host, scene), id + " paused draw is stable")
			host.camera.x = checkpoint_x + 800
			check(tagged(renderer.build_scene(host, scene), "checkpoint_flag").is_empty(), id + " remote checkpoint culled")
		check(JSON.stringify(host.meta) == original and [scene.next_coin, scene.coin_pattern, scene.end_time] == original_scene, id + " renderer never mutates metadata or gameplay")
		if id == "1-4": test_park(host, scene)
		if id == "1-5": test_alley(host, scene)
		if id == "1-S": test_bonus(host, scene)
		if id == "1-6": test_bin_day(host, scene)
		# Call actual headless CanvasItem APIs at source joins, the elevated
		# surfaces, checkpoints and end camera for every supported stage.
		var draw_host := DrawHost.new()
		draw_host.level_id = id
		draw_host.meta = host.meta
		draw_host.level = host.level
		draw_host.images = host.images
		draw_host.combat = host.combat
		draw_host.scene.reset(draw_host)
		root.add_child(draw_host)
		for camera_position in [Vector2.ZERO, Vector2(900.25, -32.25), Vector2(1300, -80), Vector2(float(host.level.w) - 738, 0)]:
			draw_host.camera = camera_position
			draw_host.elapsed = 5.7
			draw_host.queue_redraw()
			await process_frame
			await process_frame
		check(draw_host.draw_count > 0, id + " headless CanvasItem draw callback executed")
		draw_host.renderer.clear_cache()
		draw_host.queue_free()
		await process_frame
	renderer.clear_cache()
	if failures.is_empty():
		print("Street renderer checks passed: %d assertions across Park, Alley, Late Shop Bonus and Bin Day; resources, native geometry, repeats, layers, checkpoints, awnings and headless draw calls. No screenshot/device QA." % assertions)
	else:
		printerr("Street renderer failed %d/%d checks." % [failures.size(), assertions])
	quit(0 if failures.is_empty() else 1)

func test_park(host, scene) -> void:
	host.combat = null
	host.camera = Vector2.ZERO
	var commands: Array = renderer.build_scene(host, scene)
	var tree: Dictionary = tagged(commands, "join_tree")[0]
	check(tree.rect == Rect2(732, 31, 491, 459) and tree.flip_h, "Park first seam tree overlaps the right edge")
	for row in host.level.decor:
		host.camera = Vector2(float(row[1]) - 260.25, -32.25)
		commands = renderer.build_scene(host, scene)
		var matching := tagged(commands, "decor").filter(func(command): return command.key == row[0] and is_equal_approx(command.rect.position.x, float(row[1]) - 0.25))
		check(matching.size() == 1, "Park every source decor has its own artwork: %s at %s" % [row[0], row[1]])
		if matching.size() != 1: continue
		check(matching[0].flip_h == bool(row[3]) and matching[0].rect.position.y == float(row[2]) - 0.25, "Park decor reflection and y snap")
		check(commands.find(matching[0]) > commands.find(tagged(commands, "scene_tile")[0]), "Park collision props over full paintings")
	check(not renderer.build_front(host, scene).size(), "Park has no reintroduced front layer")
	host.camera = Vector2(3200, 0)
	commands = renderer.build_scene(host, scene)
	var frame := tagged(commands, "decor").filter(func(command): return command.key == "frame")
	check(frame.size() == 1 and frame[0].rect == Rect2(3252, 276, 352, 210), "Park climbing frame is original painting, not two platform bars")

func test_alley(host, scene) -> void:
	host.combat = null
	for row in host.level.obs:
		host.camera = Vector2(float(row[1]) - 300.25, -32.25)
		var commands: Array = renderer.build_scene(host, scene)
		var size: Vector2 = host.images[row[0]].get_size()
		var expected := Rect2(float(row[1]) - 0.25 - size.x / 2, 482 - size.y + 4 - 0.25, size.x, size.y)
		var matching := tagged(commands, "alley_obstacle").filter(func(command): return command.key == row[0] and command.rect == expected)
		check(matching.size() == 1, "Alley all 52 source obstacles, including half-pixel odd widths: %s" % row[1])
		var gloom := tagged(commands, "alley_gloom")
		check(gloom.size() == 1 and gloom[0].rect == Rect2(host.camera.x, -0.25, 738, 322) and gloom[0].colour == Color(20 / 255.0, 24 / 255.0, 48 / 255.0, 0.18), "Alley exact dusk overlay area/alpha")
		check(matching.size() == 1 and commands.find(gloom[0]) > commands.find(matching[0]), "Alley overlay after obstacle artwork")
	host.camera = Vector2(19300, 0)
	var commands: Array = renderer.build_scene(host, scene)
	check(tagged(commands, "checkpoint_pole")[0].rect.position.y == 248, "Alley elevated checkpoint uses obstacle y398")
	check(commands.find(tagged(commands, "checkpoint_flag")[0]) < commands.find(tagged(commands, "alley_obstacle")[0]), "Alley checks before obstacles and dusk overlay")
	host.recorded.clear()
	renderer.draw_scene(host, scene)
	check(host.recorded.any(func(call): return call[0] == "texture" and call[1].diffuse_texture == host.images.tree and call[2].size.x < 0), "source join tree reflection reaches CanvasItem API")
	check(host.recorded.filter(func(call): return call[0] == "texture").all(func(call): return call[1].texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST), "painted textures are native and source-filtered")
	# Source drawChecks calls drawPicks between backdrop/decor and flags.
	# An explicit host callback preserves that order without exposing tags.
	host.recorded.clear()
	renderer.draw_scene(host, scene, func(): host.recorded.append(["pickups"]))
	var pickup_index: int = host.recorded.find(["pickups"])
	var tree_index := -1
	var flag_index := -1
	var obstacle_index := -1
	var gloom_index := -1
	for index in range(host.recorded.size()):
		var call: Array = host.recorded[index]
		if call[0] == "texture" and call[1].diffuse_texture == host.images.tree: tree_index = index
		if call[0] == "polygon": flag_index = index
		if call[0] == "texture" and call[1].diffuse_texture == host.images.bing: obstacle_index = index
		if call[0] == "rect" and call[1] == Rect2(host.camera.x, 0, 738, 322): gloom_index = index
	check(tree_index >= 0 and tree_index < pickup_index and pickup_index < flag_index and flag_index < obstacle_index and obstacle_index < gloom_index, "callback order: backdrop/tree, shared pickups, flag, obstacle, dusk")
	check(host.recorded.count(["pickups"]) == 1, "pickups callback invoked exactly once")

func test_bonus(host, scene) -> void:
	host.combat = null
	for row in host.level.plats:
		host.camera = Vector2(float(row[0]) - 200.25, -32.25)
		var commands: Array = renderer.build_scene(host, scene)
		var stripes := tagged(commands, "awning_stripe")
		check(stripes.size() == 10, "Bonus ten 26px stripes on all 17 source awnings")
		for index in range(stripes.size()):
			check(stripes[index].rect == Rect2(float(row[0]) - 0.25 + index * 26, float(row[2]) - 2.25, 26, 18), "Bonus exact stripe geometry")
			check(stripes[index].colour == (Color("f5f1ea") if index % 2 else Color("2d6a4f")), "Bonus original alternating stripe colours")
		check(tagged(commands, "awning_edge")[0].rect == Rect2(float(row[0]) - 0.25, float(row[2]) + 15.75, 260, 4), "Bonus 4px underside")
		var posts := tagged(commands, "awning_post")
		check(posts.size() == 2 and posts[0].rect == Rect2(float(row[0]) + 5.75, float(row[2]) + 19.75, 4, 462 - float(row[2])), "Bonus support posts reach source ground")
		check(posts.size() == 2 and posts[1].rect.position.x == float(row[1]) - 10.25, "Bonus right support post anchor")
	host.camera = Vector2(900.25, -80.25)
	host.elapsed = 0
	var front := renderer.build_front(host, scene)
	check(front.size() == 2 and front[0].rect == Rect2(1099.25, 79.75, 340, 34), "Bonus source strip width and camera-relative position")
	check(front[0].radius == 17 and front[0].width == 2 and is_equal_approx(front[0].colour.a, 0.85), "Bonus source rounded partner strip")
	check(front[1].text == "Bonus level with thanks to our partner" and front[1].size == 11 and front[1].position == Vector2(1269.25, 97.75), "Bonus source partner text preserved")
	host.elapsed = 5.7
	front = renderer.build_front(host, scene)
	check(is_equal_approx(front[0].colour.a, 0.425) and is_equal_approx(front[1].colour.a, 0.5), "Bonus final 600ms fade")
	host.recorded.clear()
	renderer.draw_front(host, scene)
	check(host.recorded[0][0] == "style" and host.recorded[0][2] == front[0].rect.grow(1), "partner outline straddles source path")
	check(host.recorded[1][0] == "text" and host.recorded[1][1] == host.font, "bonus text uses existing Silkscreen, no outline")
	host.elapsed = 6
	check(renderer.build_front(host, scene).is_empty(), "Bonus strip ends at six seconds")
	# Native source widths are 260. Synthetic partial width checks that no
	# invented clip shrinks/changes the final source stripe.
	var saved_level: Dictionary = host.level
	host.level = {"plats": [[1400, 1665, 282]]}
	host.camera = Vector2(1300, 0)
	var stripes := tagged(renderer.build_scene(host), "awning_stripe")
	check(stripes.size() == 11 and stripes.back().rect == Rect2(1660, 280, 26, 18), "partial awning stripe preserves source overhang")
	host.level = saved_level

func test_bin_day(host, scene) -> void:
	host.combat = null
	host.camera = Vector2(3417, -32.25)
	var commands: Array = renderer.build_scene(host, scene)
	var chunks := tagged(commands, "street_chunk")
	check(chunks.size() == 2 and chunks[0].key == "st1" and chunks[0].rect == Rect2(2048, -32.25, 2048, 540), "Bin Day complete second source chunk")
	check(chunks.size() == 2 and chunks[1].key == "st2" and chunks[1].rect == Rect2(4096, -32.25, 59, 540), "Bin Day exact 59px final chunk at world boundary")
	check(chunks.back().rect.end.x == float(host.level.w), "Bin Day artwork ends at source world width")
	check(tagged(commands, "decor").is_empty() and tagged(commands, "join_tree").is_empty(), "Bin Day no invented trees/solid platforms")
	host.camera = Vector2(4155, 0)
	check(tagged(renderer.build_scene(host, scene), "street_chunk").is_empty(), "Bin Day paints no repeated chunks beyond world end")
	check(renderer.build_front(host, scene).is_empty(), "Bin Day no extra front props")
	host.camera = Vector2(2048, 100)
	var background := renderer.build_background(host, 0.5)
	check(tagged(background, "street_chunk")[0].rect.position.y == 100, "Bin Day sky art ignores vertical world translation")
	check(tagged(background, "background_dim")[0].rect == Rect2(2048, 100, 960, 540) and tagged(background, "background_dim")[0].colour.a == 0.5, "source dim uses full VW rectangle")
