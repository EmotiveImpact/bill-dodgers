extends SceneTree
const Fixture = preload("res://tests/test_world_five.gd")
const Renderer = preload("res://src/moving_day_renderer.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)
func tagged(commands: Array, tag: String) -> Array: return commands.filter(func(c): return c.get("tag", "") == tag)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var h := Fixture.Host.new()
	var r := Renderer.new()
	for id in ["5-1", "5-2", "5-3", "5-4", "5-5", "5-6", "5-S"]:
		h.load_source(id); h.images.clear()
		for key in h.meta.imgs:
			h.images[key] = load(h.meta.imgs[key])
			check(h.images[key].get_size() == Vector2(h.meta.dims[key][0], h.meta.dims[key][1]), id + " original image dimensions " + key)
		h.sheets.bot = load("res://assets/sprites/bot-sheet.png")
		var before := JSON.stringify(h.meta); var state: Dictionary = h.world_five.snapshot(); var rng_state: int = h.world_five.rng.state
		var all: Array = []
		for x in [0.0, float(h.level.w) / 2, maxf(0, float(h.level.w) - 738)]:
			h.camera.x = x; h.camera.y = -1650 if id == "5-3" else 0
			var sky: Array = r.build_sky(h, h.world_five); var level: Array = r.build_level(h, h.world_five)
			check(not sky.is_empty(), id + " nonempty authored background")
			check(not level.is_empty(), id + " live source geometry visible")
			all.append_array(sky); all.append_array(level); all.append_array(r.build_mid(h, h.world_five)); all.append_array(r.build_front(h, h.world_five)); all.append_array(r.build_hud(h, h.world_five))
		for c in all:
			if c.type == "texture": check(c.source.has_area() and c.rect.has_area() and h.images.has(c.key), id + " valid texture command")
		r.draw_commands(h, all)
		check(not h.recorded.is_empty(), id + " command dispatcher runs")
		check(before == JSON.stringify(h.meta) and state == h.world_five.snapshot() and rng_state == h.world_five.rng.state, id + " pure render without RNG or mutation")
	h.load_source("5-2")
	for key in h.meta.imgs: h.images[key] = load(h.meta.imgs[key])
	var sofa_cmd: Dictionary = tagged(r.build_mid(h, h.world_five), "moving_day_sofa")[0]
	check(sofa_cmd.rect.size == Vector2(h.meta.dims.sofa[0], h.meta.dims.sofa[1]), "sofa native painted size, not collision rectangle stretch")
	h.world_five.sofa.tip = true
	check(tagged(r.build_mid(h, h.world_five), "moving_day_sofa")[0].key == "sofaUp", "separate authored tipped sofa")
	h.load_source("5-4"); h.camera = Vector2(5800, 0)
	for key in h.meta.imgs: h.images[key] = load(h.meta.imgs[key])
	check(not tagged(r.build_level(h, h.world_five), "moving_day_belt_arrow").is_empty(), "raised conveyor direction markers")
	h.load_source("5-5")
	for key in h.meta.imgs: h.images[key] = load(h.meta.imgs[key])
	check(tagged(r.build_level(h, h.world_five), "moving_day_lorry")[0].key == "lorry", "player lorry uses original asset")
	h.combat.spawn(h, "l", "van")
	for i in 120: h.world_five._tick_movers(1.0 / 60, h)
	check(not tagged(r.build_level(h, h.world_five), "moving_day_robot_vehicle").is_empty(), "live van painted after arrival")
	h.load_source("5-6"); h.camera.x = 3662
	for key in h.meta.imgs: h.images[key] = load(h.meta.imgs[key])
	h.combat.start_boss(h); h.boss.state.state = "walk"; h.boss.state.x = 4100
	var a: Array = r.build_boss(h, h.world_five)
	check(tagged(a, "moving_day_box").size() == 10, "King phase one uses nine boxes plus crown")
	h.boss._set_phase(2)
	check(tagged(r.build_boss(h, h.world_five), "moving_day_box").size() == 18, "King phase three grows to seventeen boxes plus crown")
	for kind in ["rush", "tape", "big"]:
		h.combat.spawn(h, "r", kind)
		var enemy: Dictionary = h.enemies[-1]; enemy.p = Vector2(4050, 482)
		var commands: Array = r.build_enemy(h, enemy)
		check(not commands.is_empty(), kind + " original bot sprite drawn")
		r.draw_commands(h, commands)
	h.boss.state.jar = {"x": 4000.0, "y": 452.0, "t": 0.7, "got": false}
	r.draw_jar(h, h.world_five)
	h.receipts = [{"position": Vector2(60, 482), "taken": true}, {"position": Vector2(2096, 370), "taken": false}, {"position": Vector2(3900, 482), "taken": false}]
	var hud: Array = r.build_hud(h, h.world_five)
	check(tagged(hud, "moving_day_receipt_count")[0].text == "Receipts 1/3", "source receipt counter and current-run count")
	check(tagged(hud, "festival_boss_name")[0].text == "Cardboard King 3/3", "source King phase name")
	check(tagged(hud, "festival_boss_health_back")[0].rect == Rect2(266, 496, 428, 26), "source King health bar position")
	h.world_five.wiping = true; h.world_five.wipe_elapsed = 0.8; h.world_five.wipe_label = "Out to the lorry"
	check(tagged(r.build_hud(h, h.world_five), "wipe_cover").size() == 1 and tagged(r.build_hud(h, h.world_five), "wipe_label").size() == 1, "W5 wipe completely covers HUD at midpoint")
	h.boss._set_phase(0); h.boss.state.hp = 1; h.boss.hit(Vector2(h.boss.state.x, 400))
	var flying: Array = r.build_boss(h, h.world_five)
	check(tagged(flying, "moving_day_flying_box").size() == 9, "collapsed King draws rotating original boxes")
	r.draw_commands(h, flying)
	h.load_source("5-2")
	for key in h.meta.imgs: h.images[key] = load(h.meta.imgs[key])
	h.recorded.clear(); r.draw_mid(h, h.world_five)
	check(h.recorded.any(func(c): return c[0] == "texture"), "draw_mid dispatches sofa commands, not inherited find-only painter")
	print("World 5 renderer: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
