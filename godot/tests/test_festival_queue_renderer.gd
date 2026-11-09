extends SceneTree
## Geometry/command, original art, purity and headless CanvasItem tests.
## This suite does not certify screenshots, phone rendering or difficulty.
const Renderer = preload("res://src/festival_queue_renderer.gd")

class Host extends RefCounted:
	var level_id := "3-2"
	var meta: Dictionary = {}
	var level: Dictionary = {}
	var images: Dictionary = {}
	var sheets: Dictionary = {}
	var camera := Vector2.ZERO
	var player := Vector2(300, 482)
	var elapsed := 0.0
	var mode := "play"
	var receipts: Array = []
	var boss = null
	var character := "jp"
	var power := ""
	var world_three = null
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

class Runtime extends RefCounted:
	var scene_index := 0
	var elapsed := 0.0
	var tents: Array = []
	var checkpoint_done := false
	var rows: Array = []
	func surfaces(_host) -> Array: return rows

class DrawHost extends Node2D:
	var renderer = Renderer.new()
	var level_id := "3-2"
	var meta: Dictionary = {}
	var level: Dictionary = {}
	var images: Dictionary = {}
	var sheets: Dictionary = {}
	var camera := Vector2.ZERO
	var player := Vector2(300, 482)
	var elapsed := 0.0
	var mode := "play"
	var receipts: Array = []
	var boss = null
	var character := "jp"
	var power := ""
	var world_three = null
	var font: Font = load("res://assets/fonts/silk.woff2")
	var runtime: Dictionary = {}
	var bot: Dictionary = {}
	var draw_count := 0
	var pickup_count := 0
	func view_width() -> float: return 738.0
	func view_top() -> float: return camera.y + 540 - 540 / 1.3
	func _draw() -> void:
		draw_set_transform(Vector2(-camera.x * 1.3, 540 * (1 - 1.3) - camera.y * 1.3), 0, Vector2.ONE * 1.3)
		renderer.draw_sky(self, runtime)
		renderer.draw_level(self, runtime)
		renderer.draw_mid(self, runtime, func(): pickup_count += 1; renderer.draw_finds(self, runtime))
		renderer.draw_crate(self, {"p": player, "broken": false})
		for give in ["wellies", "heart", "split", "debit"]: renderer.draw_item(self, {"p": player - Vector2(0, 90), "age": 0.2, "give": give})
		renderer.draw_coin(self, {"p": player - Vector2(0, 130), "age": 0.1})
		renderer.draw_boss(self, runtime)
		renderer.draw_enemy(self, bot)
		renderer.draw_player_back(self, player)
		renderer.draw_player_front(self, player)
		renderer.draw_bill(self, {"p": player - Vector2(0, 80), "age": 0.2, "tie": true})
		renderer.draw_bill(self, {"p": player - Vector2(0, 100), "age": 0.3, "big": true})
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
	host.meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/3-2.json"))
	host.level = host.meta.level
	for key in host.meta.imgs: host.images[key] = load(host.meta.imgs[key])
	host.sheets.bot = load("res://assets/sprites/bot-sheet.png")
	host.sheets.thief = load("res://assets/sprites/thief-sheet.png")
	for row in host.level.receipts: host.receipts.append({"position": Vector2(row[0], row[1]), "taken": false, "previously_collected": false})

func bot() -> Dictionary:
	return {"p": Vector2(300, 482), "kind": "rush", "type": "rush", "state": "walk", "face": -1, "hp": 2, "max_hp": 2, "t": 0.3, "flash": 0.0, "gone": 0.0, "stride": 28.0, "visual_move": -1, "rise": 0.0, "dz": 0.0}

func seller() -> Dictionary:
	return {"x": 9300.0, "fy": 482.0, "state": "enter", "t": 0.3, "face": -1, "flash": 0.0, "dizzy": 0.0, "name": "Wristband seller", "kind": "seller", "hp": 60.0, "max": 60.0, "waves": [], "hop": {}, "jar": {}}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host := Host.new()
	load_stage(host)
	var runtime := {"scene_index": 0, "elapsed": 0.0, "checkpoint_done": false, "stage_data": {"end_run": 0.0}}
	var original := JSON.stringify(host.meta)
	check(renderer.supports("3-2") and not renderer.supports("3-1"), "queue-only dispatch")
	var sky := renderer.build_sky(host, runtime)
	check(tagged(sky, "festival_sky_gradient")[0].colours[0] == Color("3b3270"), "dusk source top colour")
	check(tagged(sky, "festival_sky")[0].source.size == host.images.fieldB_sky.get_size(), "fieldB pre-cut sky sampled whole")
	check(tagged(renderer.build_level(host, runtime), "festival_ground")[0].rect.position.y == 407, "fieldB ground paintTop-18+425")
	host.camera = Vector2(15000.25, -10.25)
	runtime.scene_index = 1
	var level := renderer.build_level(host, runtime)
	check(tagged(level, "festival_ground")[0].rect.position.y == 425.75, "crowd ground444 plus paintTop-18 and camera snap")
	check(tagged(level, "festival_land")[0].source.size == host.images.crowd_land.get_size(), "crowd pre-cut land whole")
	check(tagged(level, "festival_decor").is_empty(), "painted flags and speakers not duplicated")
	host.camera = Vector2(900, 0)
	level = renderer.build_level(host, runtime)
	var barriers := tagged(level, "queue_barrier")
	check(not barriers.is_empty(), "barrier emitted")
	check(barriers[0].rect == Rect2(1100, 372, 80, 8 * 114.0 / 112), "source barrier scales full120px canvas into80px width")
	for command in barriers: check(command.rect.position.x >= 1100 and command.rect.end.x <= 1180.001, "barrier feet clipped in original canvas")
	host.camera = Vector2(1600, 0)
	level = renderer.build_level(host, runtime)
	check(tagged(level, "queue_banner_stripe").size() == 6, "six original alternating banner panels")
	check(tagged(level, "queue_banner_pole")[0].rect == Rect2(1819, 292, 9, 190), "banner extends14px each end and down to ground")
	check(tagged(level, "queue_banner_label")[0].text == "DUCK", "duck notice")
	host.camera = Vector2(4000.25, -3.25)
	level = renderer.build_level(host, runtime)
	var crowd := tagged(level, "queue_crowd")
	check(not crowd.is_empty(), "painted crowd slices emitted")
	var hi := float(host.meta.hi.crowdband)
	var shades: Dictionary = {}
	for command in crowd:
		shades[command.shade] = true
		check(command.rect.position.x >= 4105.25 and command.rect.end.x <= 4805.25, "crowd clipped at conveyor edges")
		check(command.source.position.x >= 0 and command.source.end.x <= host.images.crowdband.get_width() + 0.001, "crowd wrapped source stays inside image")
		check(command.source.size.is_equal_approx(command.rect.size * hi), "crowd clip removes source pixels, never compresses")
	check(shades.has(1.0) and shades.has(0.62), "both source crowd depth rows")
	host.elapsed = 0.21
	runtime.elapsed = host.elapsed
	check(tagged(renderer.build_level(host, runtime), "queue_crowd") != crowd, "crowd bobs on170ms clock")
	var runner: Dictionary = tagged(renderer.build_front(host, runtime), "queue_jar_runner")[0]
	check(runner.frame == 3 and runner.alpha == 0.5 and runner.flip_h, "runner70ms walk half-alpha left facing")
	check(runner.rect.position.y == 304.75, "runner uses highest crowd support442")
	runtime.stage_data.end_run = 2.5
	check(tagged(renderer.build_front(host, runtime), "queue_jar_runner")[0] == runner, "source min prevents ending runner advance")
	host.mode = "clear"
	check(tagged(renderer.build_front(host, runtime), "queue_jar_runner").is_empty(), "runner hidden outside play")
	host.mode = "play"
	var b := bot()
	b.p = Vector2(4300, 442)
	var enemy := renderer.build_enemy(host, b)
	b.stride += 10
	check(renderer.build_enemy(host, b) != enemy, "ordinary bot frames advance by travelled stride")
	for cx in [-15.25, 951.6, 4105.5, 8875.25, 15300.75, 19305.5, 24410.25, 29800.0]:
		host.camera.x = cx
		var layers := renderer.build_level(host, runtime)
		for command in layers:
			if command.tag in ["festival_far", "festival_land", "festival_ground"]:
				check(command.flip_h == (int(command.index) % 2 != 0), "global parity mirrors painted layers")
				check(command.source.size == host.images[command.key].get_size(), "moving scene layers never double-cropped")
		host.camera.x = 7800
		var bales := tagged(renderer.build_level(host, runtime), "festival_bale")
		check(not bales.is_empty(), "inherited stepped bales present")
		for command in bales: check(command.clip.encloses(command.rect), "inherited bale source clipping")
	host.camera = Vector2(4000.25, -3.25)
	var wipe := {"wiping": true, "wipe_elapsed": 0.8, "wipe_kind": "iris", "wipe_label": "Into the arena"}
	check(tagged(renderer.build_hud(host, wipe), "wipe_cover").size() == 1, "inherited iris full cover")
	check(tagged(renderer.build_hud(host, wipe), "wipe_label")[0].text == "Into the arena", "source scene label during iris")
	wipe.wipe_elapsed = 0.25
	check(tagged(renderer.build_hud(host, wipe), "wipe_iris").size() == 1, "inherited radial iris closing")
	check(tagged(renderer.build_front(host, runtime), "festival_hint")[0].text == host.meta.l3.hint, "auto-run help uses source hint")
	var before := JSON.stringify(runtime)
	var commands := renderer.build_level(host, runtime)
	check(commands == renderer.build_level(host, runtime), "repeated draw plans stable")
	seed(817)
	var expected := randf()
	seed(817)
	renderer.build_level(host, runtime)
	renderer.build_front(host, runtime)
	check(randf() == expected, "render consumes no gameplay RNG")
	check(JSON.stringify(runtime) == before and JSON.stringify(host.meta) == original, "render preserves runtime and metadata")
	renderer.draw_commands(host, commands)
	check(renderer._crowd_shaded != null, "crowd dark row caches original full image")
	var source: Image = host.images.crowdband.get_image()
	var shaded: Image = renderer._crowd_shaded.get_image()
	var pixel := source.get_pixel(30, 30)
	check(shaded.get_pixel(30, 30).r8 == int(renderer._clamped_byte(pixel.r8 * 0.62)) and shaded.get_pixel(30, 30).a8 == pixel.a8, "crowd CSS brightness applied in byte sRGB preserving alpha")
	var canvas := DrawHost.new()
	load_stage(canvas)
	canvas.camera = Vector2(4000, 0)
	canvas.player = Vector2(4300, 442)
	canvas.bot = bot()
	canvas.runtime = runtime
	root.add_child(canvas)
	canvas.queue_redraw()
	await process_frame
	await process_frame
	check(canvas.draw_count > 0 and canvas.pickup_count > 0, "real CanvasItem callback runs inherited and queue draw paths")
	canvas.camera = Vector2(1600, 0)
	canvas.queue_redraw()
	await process_frame
	await process_frame
	canvas.queue_free()
	renderer.clear_cache()
	check(renderer._crowd_shaded == null, "cache clears")
	print("Festival queue renderer: %d assertions, %d failures" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
