extends SceneTree
## Geometry/command, original art, purity and headless CanvasItem tests.
## This suite does not certify screenshots, phone rendering or difficulty.
const Renderer = preload("res://src/festival_renderer.gd")

class Host extends RefCounted:
	var level_id := "3-1"
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
	var level_id := "3-1"
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
	host.meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/3-1.json"))
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
	var original := JSON.stringify(host.meta)
	var runtime := {"scene_index": 0, "elapsed": 0.0, "checkpoint_done": false, "cheer": 0.0}
	check(renderer.supports("3-1") and not renderer.supports("3-2") and not renderer.supports("3-S") and not renderer.supports("2-1"), "only proven field stage claims renderer support")
	check(host.images.fieldA_land.get_size() == Vector2(1238, 585) and host.images.cut_gate.get_size() == Vector2(344, 198), "original image pixels are not META world dimensions")
	check(host.meta.hi.cut_gate != 1.3 and host.meta.hi.fieldA_land == 1.3, "per-asset hi scaling retained")
	var c := renderer._festival_context(host)
	check(renderer._world_size(c, "cut_gate").is_equal_approx(Vector2(213.28, 122.76)), "gate true world size uses original pixels divided by1.6129")
	check(renderer._paint_top(c, host.meta.l3.scenes[0]) == -18, "painting top source round482-635*.81+14")
	var sky := renderer.build_sky(host, runtime)
	check(tagged(sky, "festival_sky")[0].rect == Rect2(0, 16, 952, 415), "sky bottom-lock hides blank strip at normal camera")
	check(tagged(sky, "festival_sky")[0].source == Rect2(0, 0, 1238, 540), "sky uses complete imported pre-cut image, never double-crops")
	var level := renderer.build_level(host, runtime)
	check(tagged(level, "festival_land")[0].rect == Rect2(0, -18, 952, 450), "fieldA land original pre-cut height")
	check(tagged(level, "festival_ground")[0].rect == Rect2(0, 400, 952, 217), "fieldA ground at paintTop+418")
	check(tagged(level, "festival_tent")[0].rect == Rect2(561, 338, 278, 148), "first dome center700 feet482 plus4")
	for cx in [-15.25, 0.0, 951.6, 1400.25, 6800.5, 7900.75, 9300.0, 14000.25]:
		for cy in [0.0, -0.25, -150.5, -360.0]:
			for scene_index in [0, 1]:
				host.camera = Vector2(cx, cy)
				runtime.scene_index = scene_index
				runtime.elapsed = 1.75
				var scene: Dictionary = host.meta.l3.scenes[scene_index]
				var info: Dictionary = host.meta.l3.layerInfo[scene.key]
				var top := -18.0
				for command in tagged(renderer.build_sky(host, runtime), "festival_sky"):
					var scroll: float = cx * 0.05 + 2.5 * 1.75
					var first := floorf(scroll / 952)
					check(is_equal_approx(command.rect.position.x, cx - Renderer.source_round(scroll - first * 952) + (command.index - first) * 952), "sky rounds starting offset once")
					check(is_equal_approx(command.rect.position.y, cy + Renderer.source_round(maxf(top - cy * 0.12, top - cy + float(info.land_top) - float(info.sky_clean)))), "sky drawn before vertical camera translate")
					check(command.flip_h == (command.index % 2 != 0), "sky alternating mirror parity includes negative tile indices")
				level = renderer.build_level(host, runtime)
				for entry in [["festival_far", 0.16, 0], ["festival_land", 0.5, 0], ["festival_ground", 1.0, info.ground_y]]:
					for command in tagged(level, entry[0]):
						var scroll: float = cx * entry[1]
						var first := floorf(scroll / 952)
						check(is_equal_approx(command.rect.position.x, cx - Renderer.source_round(scroll - first * 952) + (command.index - first) * 952), "layer x uses original par rule " + entry[0])
						check(is_equal_approx(command.rect.position.y, Renderer.source_round(top + entry[2]) + cy - Renderer.source_round(cy)), "land uses separately rounded vertical camera " + entry[0])
						check(command.key.begins_with(str(scene.key)) and command.flip_h == (command.index % 2 != 0), "scene key and tile mirror " + entry[0])
	host.camera = Vector2(7530, 0)
	check(renderer._scene(renderer._festival_context(host), {}).key == "fieldA", "scene fallback stays first at camera center7899")
	host.camera.x = 7531
	check(renderer._scene(renderer._festival_context(host), {}).key == "fieldB", "scene fallback switches when camera center reaches7900")
	host.camera = Vector2(500, 0)
	runtime.scene_index = 0
	level = renderer.build_level(host, runtime)
	var prop: Dictionary = tagged(level, "festival_mid_prop")[0]
	check(prop.key == "cut_bales3" and prop.rect.size.is_equal_approx(Vector2(130.32, 118.08)), "fg named source props are72percent middle distance")
	check(prop.rect.position == Vector2(828, 304) and prop.filter == "mid_prop" and prop.type == "festival_texture", "middle prop .78parallax and source brightness/saturation")
	var filtered: Texture2D = renderer._festival_variant(prop, host.images[prop.key])
	check(filtered.get_size() == host.images[prop.key].get_size(), "middle prop filter preserves original pixel dimensions")
	var original_prop: Image = host.images[prop.key].get_image()
	var filtered_pixels := filtered.get_image()
	var sampled_prop := false
	for py in original_prop.get_height():
		if sampled_prop: break
		for px in original_prop.get_width():
			var pixel := original_prop.get_pixel(px, py)
			if pixel.a < 0.9 or maxf(pixel.r, maxf(pixel.g, pixel.b)) < 0.2: continue
			var rgb := Vector3(pixel.r, pixel.g, pixel.b) * 0.9
			var gray := rgb.dot(Vector3(0.213, 0.715, 0.072))
			var expected := rgb * 0.92 + Vector3.ONE * gray * 0.08
			var actual := filtered_pixels.get_pixel(px, py)
			check(Vector3(actual.r, actual.g, actual.b).distance_to(expected) < 0.007 and actual.a == pixel.a, "cached middle prop pixels apply brightness then saturation and preserve alpha")
			sampled_prop = true
			break
	check(sampled_prop and renderer._festival_variant(prop, host.images[prop.key]) == filtered, "middle prop filter result reused without repainting pixel cache")
	check(level.find(prop) > level.find(tagged(level, "festival_land")[0]) and level.find(prop) < level.find(tagged(level, "festival_ground")[0]), "land then middle props then ground order")
	var before_shake: Vector2 = tagged(level, "festival_tent")[0].rect.position
	runtime.tents = [{"x": 700.0, "y": 482.0, "kind": "cut:dome-orange", "shake": 0.17}]
	check(tagged(renderer.build_level(host, runtime), "festival_tent")[0].rect.position == before_shake + Vector2(Renderer.source_round(sin(0.17 / 0.02) * 3), 0), "tent shake clock converts seconds to source20ms")
	runtime.erase("tents")
	host.camera = Vector2(1550.25, -0.25)
	level = renderer.build_level(host, runtime)
	var bales := tagged(level, "festival_bale")
	check(not bales.is_empty() and bales[0].source == Rect2(0, 0, 120, 54), "bales original120by54tile")
	for command in bales: check(command.clip.encloses(command.rect), "every bale rectangle is clipped to authored span")
	var second_row := bales.filter(func(command): return command.row == 1)
	check(second_row[0].rect == Rect2(1740.25, 427.75, 60, 54) and second_row[0].source == Rect2(60, 0, 60, 54), "odd bale row stagger clips left60pixels without stretch")
	host.camera = Vector2(8350, -150)
	level = renderer.build_level(host, runtime)
	check(tagged(level, "festival_decor").any(func(command): return command.key == "cut_caravan-blue" and command.rect == Rect2(8508, 216, 385, 272)), "caravan is authored385by272painting centered8700")
	check(not level.any(func(command): return command.get("rect", Rect2()).position.y == 246 and command.type == "rect"), "vanroof collision line has no duplicate platform art")
	var live := Runtime.new()
	live.rows = [{"row": [330, 450, 350], "plat": false, "style": "bales", "base": 404}]
	live.tents = [{"x": 400, "y": 300, "kind": "cut:dome-orange", "shake": 0.0}]
	host.camera = Vector2.ZERO
	level = renderer.build_level(host, live)
	check(tagged(level, "festival_bale").size() == 1 and tagged(level, "festival_bale")[0].rect == Rect2(330, 350, 120, 54), "live runtime surfaces(host) wins over staticMETA")
	check(tagged(level, "festival_tent")[0].rect.position.y == 156, "live tent y wins over authored row")
	host.camera = Vector2(2000, 0)
	level = renderer.build_level(host, runtime)
	check(tagged(level, "festival_mud").size() == 175 and tagged(level, "festival_puddle").size() == 8, "700pixel mud strip uses175cells andceil8glints")
	check(tagged(level, "festival_mud")[0].colour.a == 0 and is_equal_approx(tagged(level, "festival_mud")[15].colour.a, 0.55), "mud ramps opacity across first60pixels")
	var random := [2001]
	check(is_equal_approx(Renderer._festival_random(random), 33630807.0 / 2147483647), "mud uses source ParkMiller seed not W2 LCG")
	check(tagged(level, "festival_puddle")[0].rect == Rect2(2040, 498, 32, 3), "first puddle exact seeded source geometry")
	host.camera = Vector2(6750.25, -0.25)
	runtime.elapsed = 0.15
	level = renderer.build_level(host, runtime)
	check(tagged(level, "festival_checkpoint_pole")[0].rect == Rect2(6997.25, 281.75, 6, 200), "checkpoint pole uses200pixelW3height")
	check(tagged(level, "festival_checkpoint_flag")[0].points[0] == Vector2(7003, 283.75), "flag x deliberately remains source unrounded")
	runtime.checkpoint_done = true
	check(tagged(renderer.build_level(host, runtime), "festival_checkpoint_label")[0].text == "Saved", "checkpoint saved state comes from runtime")
	host.camera = Vector2(4700.25, -150.25)
	runtime.elapsed = 0.4
	var finds := renderer.build_finds(host, runtime)
	check(tagged(finds, "festival_receipt")[0].rect == Rect2(5051.25, 238.75, 18, 28), "receipt uses authored252y plus sin3bob, noW1orW2offset")
	host.receipts[0].previously_collected = true
	check(is_equal_approx(tagged(renderer.build_finds(host, runtime), "festival_receipt")[0].colour.a, 0.45), "previous receipt remains reacquirable and45percentopaque")
	host.receipts[0].taken = true
	check(renderer.build_finds(host, runtime).is_empty(), "collected currentrun receipt disappears immediately")
	host.receipts[0].taken = false
	host.camera = Vector2.ZERO
	var enemy := bot()
	var commands := renderer.build_enemy(host, enemy)
	check(tagged(commands, "festival_bot")[0].source == Rect2(678, 0, 226, 140), "walk stride28 chooses sourceframe3")
	check(not tagged(commands, "festival_bot")[0].flip_h, "moving left shows unmirrored original leftfacing bot")
	enemy.visual_move = 0
	check(tagged(renderer.build_enemy(host, enemy), "festival_bot")[0].frame == 5, "idlebot source walkframe5")
	enemy.rise = 0.5
	enemy.flash = 1.0
	commands = renderer.build_enemy(host, enemy)
	var rising: Dictionary = tagged(commands, "festival_bot")[0]
	check(rising.rect == Rect2(187, 465, 226, 19) and rising.source == Rect2(1130, 0, 226, 19), "500msrise moves120pixels and clips belowfloor+2")
	renderer.draw_commands(host, commands)
	check(host.recorded.any(func(entry): return entry[0] == "texture" and entry[1] is CanvasTexture and entry[1].texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST), "real submitted textures explicitly use nearestsampling")
	var rising_draw: Array = host.recorded.filter(func(entry): return entry[0] == "texture")[-1]
	check(rising_draw[1].diffuse_texture.get_size() == Vector2(226, 140) and rising_draw[3] == Rect2(0, 0, 226, 19), "clipped hit flash caches full140pixel frame and submits19pixel source crop")

	enemy.rise = 0
	enemy.flash = 0
	enemy.state = "pop"
	enemy.t = 0.36
	enemy.gone = 1.05
	check(is_equal_approx(tagged(renderer.build_enemy(host, enemy), "festival_bot")[0].alpha, 0.5), "sourcepopfade800to1300ms")
	enemy = bot()
	enemy.dz = 1
	commands = renderer.build_enemy(host, enemy)
	check(commands.find(tagged(commands, "festival_bot_dizzy")[0]) < commands.find(tagged(commands, "festival_bot")[0]), "dizzyunderlay before sprite sourceorder")
	host.camera = Vector2(8900.25, -0.25)
	var boss := seller()
	runtime.boss = boss
	commands = renderer.build_boss(host, runtime)
	var sprite: Dictionary = tagged(commands, "festival_boss")[0]
	check(sprite.animation == "run" and sprite.frame == 4 and sprite.rect == Rect2(9069.25, 202.75, 462, 282) and sprite.filter == "seller", "seller original462by282thief and70msentryclock")
	boss.state = "throw"
	boss.t = 0.4
	check(tagged(renderer.build_boss(host, runtime), "festival_boss")[0].source == Rect2(924, 282, 462, 282), "seller throw frame2 original sheet")
	boss.dizzy = 2.6
	check(tagged(renderer.build_boss(host, runtime), "festival_boss")[0].animation == "down", "dizzy overrides throw")
	boss.state = "down"
	boss.t = 1.2
	check(tagged(renderer.build_boss(host, runtime), "festival_boss")[0].frame == 3, "mini downframe3 without jar")
	check(tagged(renderer.build_hud(host, runtime), "festival_boss_health").is_empty(), "down hides healthbar")
	boss = seller()
	boss.hp = 40
	boss.max = 80
	runtime.boss = boss
	check(tagged(renderer.build_hud(host, runtime), "festival_boss_health")[0].rect == Rect2(270, 500, 210, 18), "80HPseller bar true ratio and sourcebottomHUD")
	boss.waves = [{"x": 9200.0, "vx": -420.0, "t": 0.05}]
	commands = renderer.build_boss(host, runtime)
	check(is_equal_approx(tagged(commands, "festival_shockwave")[0].rect.position.y, 482 - 31 - sin(1) * 3 - 0.25), "shockwave source50msclock andground anchor")
	var warm := Color8(200, 100, 40, 120)
	var tint := Renderer.tint_pixel(warm, "seller")
	check(tint == Color8(118, 115, 74, 120), "seller warm pixels transform RGB exactly and preservealpha")
	check(Renderer.tint_pixel(Color8(100, 120, 140, 77), "seller") == Color8(100, 120, 140, 77), "nonwarmspritepixels remainunchanged")
	check(Renderer.tint_pixel(warm, "seller", true) == Color8(214, 213, 201, 120), "hitflash70percentwhite overlays tintedframe")
	host.camera = Vector2(100.25, -0.25)
	var band := renderer.build_band(host, {"p": Vector2(375, 250.5), "age": 0.14})
	check(tagged(band, "festival_wristband")[0].colour == Color("e9c13a") and tagged(band, "festival_wristband")[0].rotation == 2, "wristband colour uses screenx bucket and70msrotation")
	check(tagged(band, "festival_wristband")[0].center == Vector2(375.25, 250.75), "wristband independent coordinate rounding")
	var bill := renderer.build_bill(host, {"p": Vector2(375, 250.5), "age": 0.0, "big": false})
	check(bill.size() == 4 and bill[0].points[0] == Vector2(366.25, 243.75), "ordinary bill has four original ink rectangles")
	check(renderer.build_bill(host, {"p": Vector2.ZERO, "age": 0.1, "tie": true})[0].tag == "festival_wristband", "bill dispatch chooses wristband before ordinary bill")
	host.player = Vector2(1600, 350)
	var shadow := renderer.build_player_back(host)
	check(tagged(shadow, "festival_player_shadow")[0].center == Vector2(1600.25, 425.75), "player shadow lands on highest bale below feet")
	check(is_equal_approx(tagged(shadow, "festival_player_shadow")[0].radius.x, 48 * (1 - 78.0 / 600)), "player shadow shrinks in midair source formula")
	host.player.y = -100
	check(renderer.build_player_back(host).is_empty(), "shadow absent more than400pixels above floor")
	host.player.y = 350
	host.power = "wellies"
	var player_front := renderer.build_player_front(host)
	check(tagged(player_front, "festival_player_tag")[0].rect == Rect2(1581, 137.75, 38, 20) and tagged(player_front, "festival_player_name")[0].text == "P1", "player tag follows actual character height with source unrounded x")
	check(tagged(player_front, "festival_player_power")[0].radius == Vector2(40, 9), "wellies show source shared power ring")
	host.power = ""
	var item := renderer.build_item(host, {"p": Vector2(300, 350), "age": 0.0, "give": "wellies"})
	check(tagged(item, "festival_welly").size() == 4 and tagged(item, "festival_welly")[3].rect == Rect2(288.25, 359.75, 28, 4), "wellies original fourrectangleboot anddarksole")
	check(renderer.build_item(host, {"p": Vector2.ZERO, "age": 9.24, "give": "wellies"}).is_empty(), "itemblink late life source120ms")
	check(renderer.build_crate(host, {"p": Vector2(300, 472), "broken": true}).is_empty(), "brokencrateinvisible")
	var crate := renderer.build_crate(host, {"p": Vector2(300, 472), "broken": false})
	check(tagged(crate, "festival_crate")[0].rect == Rect2(266.25, 407.75, 68, 64), "source68pixelcrate not generic64")
	check(renderer.build_coin(host, {"p": Vector2.ZERO, "age": 9.11}).is_empty(), "coinblink source100ms")
	runtime.elapsed = 8.99
	check(tagged(renderer.build_front(host, runtime), "festival_hint").size() == 1, "sourcehint first9seconds")
	runtime.elapsed = 9.0
	check(tagged(renderer.build_front(host, runtime), "festival_hint").is_empty(), "sourcehint ends at9seconds")
	runtime.wiping = true
	runtime.wipe_elapsed = 1.0
	runtime.wipe_kind = "door"
	runtime.wipe_label = "Food village"
	check(tagged(renderer.build_hud(host, runtime), "wipe_cover").size() == 1 and tagged(renderer.build_hud(host, runtime), "wipe_label")[0].text == "Food village", "door uses shared sourcepolish iris andlabel")
	var state_before := var_to_str([runtime, host.receipts, enemy, host.camera, host.elapsed])
	var commands_before := var_to_str([renderer.build_level(host, runtime), renderer.build_boss(host, runtime), renderer.build_enemy(host, enemy)])
	seed(369)
	var expected_random := randf()
	seed(369)
	for repeat in 3:
		renderer.build_sky(host, runtime); renderer.build_level(host, runtime); renderer.build_mid(host, runtime); renderer.build_boss(host, runtime); renderer.build_enemy(host, enemy); renderer.build_front(host, runtime); renderer.build_hud(host, runtime)
	check(randf() == expected_random, "rendering never consumes gameplay RNG")
	check(state_before == var_to_str([runtime, host.receipts, enemy, host.camera, host.elapsed]) and original == JSON.stringify(host.meta), "rendering leaves all simulation andMETA untouched")
	check(commands_before == var_to_str([renderer.build_level(host, runtime), renderer.build_boss(host, runtime), renderer.build_enemy(host, enemy)]), "same snapshot builds identical commands")
	var calls := [0]
	host.recorded.clear()
	renderer.draw_mid(host, runtime, func(): calls[0] += 1)
	check(calls[0] == 1 and host.recorded.is_empty(), "mid delegates finds callback exactlyonce withoutdoublepaint")
	host.level_id = "3-3"
	check(renderer.build_sky(host, runtime).is_empty() and renderer.build_level(host, runtime).is_empty() and not renderer.draw_enemy(host, enemy), "unsupportedlaterstages remain honest")
	host.level_id = "3-1"
	var draw_host := DrawHost.new()
	load_stage(draw_host)
	root.add_child(draw_host)
	for cx in [500.25, 1500.25, 2000.25, 4900.25, 6750.25, 7900.25, 8900.25, 14000.25]:
		for cy in [0.0, -150.25]:
			draw_host.camera = Vector2(cx, cy)
			draw_host.player = Vector2(cx + 350, 482)
			draw_host.bot = bot()
			draw_host.bot.p = draw_host.player
			draw_host.bot.rise = 0.4
			draw_host.bot.flash = 0.1
			draw_host.runtime = {"scene_index": 1 if cx >= 7900 else 0, "elapsed": 1.2, "boss": seller(), "cheer": 0.5}
			draw_host.runtime.boss.x = cx + 450
			draw_host.runtime.boss.flash = 0.1
			var previous := draw_host.draw_count
			draw_host.queue_redraw()
			for frame in 3: await process_frame
			check(draw_host.draw_count > previous, "actualCanvasItem _draw callback ran at " + str(draw_host.camera))
	check(draw_host.pickup_count == draw_host.draw_count, "CanvasItem picks callback exactlyonce perdraw")
	check(not draw_host.renderer._festival_variants.is_empty(), "actualCanvasItem generated seller and clippedbot cachedvariants")
	draw_host.renderer.clear_cache()
	check(draw_host.renderer._festival_variants.is_empty() and draw_host.renderer._filtered_textures.is_empty(), "restartcacheclear releases filtered and tintedtextures")
	draw_host.queue_free()
	await process_frame
	if failures.is_empty(): print("Festival renderer: %d assertions passed (commands + headless CanvasItem; not framebuffer/device parity)." % assertions)
	else: printerr("Festival renderer: %d failures / %d assertions." % [failures.size(), assertions])
	quit(0 if failures.is_empty() else 1)
