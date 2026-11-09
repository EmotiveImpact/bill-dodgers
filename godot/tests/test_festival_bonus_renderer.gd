extends SceneTree
## Pure command geometry plus real headless CanvasItem submission. No
## screenshot comparison, handset GPU or complete-stage claim is implied.
const Renderer = preload("res://src/festival_bonus_renderer.gd")
const Drawing = preload("res://tests/test_festival_hayride_renderer.gd")
var renderer = Renderer.new()
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ",label)

func tagged(commands: Array, tag: String) -> Array:
	return commands.filter(func(c):return c.tag == tag)

func near(a: float, b: float) -> bool: return absf(a-b) < 0.001

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var h := Drawing.Host.new()
	h.level_id = "3-S"
	h.meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/3-S.json"))
	h.level = h.meta.level
	for key in h.meta.imgs: h.images[key] = load(h.meta.imgs[key])
	for row in h.level.receipts: h.receipts.append({"position":Vector2(row[0],row[1]),"taken":false})
	var rt := {"elapsed":0.5,"scene_index":0,"stage_data":{"timer_elapsed":0.0}}
	h.world_three = rt
	h.elapsed = 0.5
	h.camera = Vector2(0.25,0.25)
	var original := JSON.stringify(h.meta)
	var all: Array = []
	check(renderer.supports("3-S") and not renderer.supports("2-S") and not renderer.supports("3-6"), "Bonus renderer dispatch only")
	check(h.level.tents.is_empty() and h.meta.l3.scenes.size() == 1, "Source has no physical tents and one fieldB scene")
	var sky: Array = renderer.build_sky(h,rt)
	var level: Array = renderer.build_level(h,rt)
	check(tagged(sky,"festival_sky_gradient")[0].colours[0] == Color("5fb4ef"), "Daytime festival base palette")
	check(tagged(sky,"festival_sky")[0].key == "fieldB_sky", "Source fieldB sky asset")
	check(tagged(level,"festival_far")[0].key == "fieldB_far" and tagged(level,"festival_land")[0].key == "fieldB_land" and tagged(level,"festival_ground")[0].key == "fieldB_ground", "Source far/land/ground assets")
	check(tagged(level,"festival_far")[0].factor == 0.16 and tagged(level,"festival_land")[0].factor == 0.5 and tagged(level,"festival_ground")[0].factor == 1.0, "Source parallax factors")
	var c: Dictionary = renderer._festival_context(h)
	check(renderer._paint_top(c,h.meta.l3.scenes[0]) == -18, "FieldB paint top from635px source canvas")
	check(tagged(level,"festival_ground")[0].rect.position.y == 407.25, "Ground artwork425 below paint top plus snapped camera remainder")
	var expected_sky_width: float = renderer.source_round(h.images.fieldB_sky.get_width()/1.3)
	check(tagged(sky,"festival_sky")[0].rect.size.x == expected_sky_width, "Only authored hi factor unscales sky")
	check(renderer._world_size(c,"cut_caravan-yellow") == Vector2(384,274), "Caravan remains original unscaled cutout")
	check(tagged(level,"festival_tent").is_empty(), "No invented tent texture")
	all.append_array(sky)
	all.append_array(level)
	_signs(h,rt,all)
	_surfaces_and_decor(h,rt,all)
	_receipts(h,rt,all)
	_timer(h,rt,all)
	_coin_blink(h,all)
	var runtime_before := var_to_str(rt)
	var finds_before := var_to_str(h.receipts)
	for i in 3:
		renderer.build_sky(h,rt)
		renderer.build_level(h,rt)
		renderer.build_mid(h,rt)
		renderer.build_front(h,rt)
		renderer.build_hud(h,rt)
	check(var_to_str(rt) == runtime_before and var_to_str(h.receipts) == finds_before and JSON.stringify(h.meta) == original, "Repeated paint never changes timer, finds or imported content")
	_source_contract()
	var node := Drawing.DrawNode.new()
	node.painter = renderer
	node.host = h
	node.commands = all
	root.add_child(node)
	await process_frame
	await process_frame
	check(node.calls > 0, "Real headless CanvasItem _draw submitted every command type")
	node.queue_free()
	await process_frame
	renderer.clear_cache()
	all.clear()
	h.images.clear()
	print("Festival bonus renderer: %d checks, %d failures (headless commands only)" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _signs(h,rt,all: Array) -> void:
	var signs: Array = h.level.decor.filter(func(d):return d[0] == "sign")
	check(signs.size() == 4, "Four source Partner stall signs")
	for i in signs.size():
		var row: Array = signs[i]
		h.camera = Vector2(float(row[1])-300.25,0.25)
		var commands: Array = renderer.build_level(h,rt)
		var sign: Dictionary = tagged(commands,"bonus_stall_sign")[0]
		var post: Dictionary = tagged(commands,"bonus_stall_sign_post")[0]
		var label: Dictionary = tagged(commands,"bonus_stall_sign_label")[0]
		check(sign.rect.size == Vector2(230,56) and sign.radius == 10 and sign.width == 3, "Exact sign rounded geometry %d" % i)
		check(sign.colour == Color(["d94a3d","2f7fc9","3f9a5a","ef8a2b"][i]) and sign.stroke == Color("f5f1ea"), "Sign palette index is not flip %d" % i)
		check(near(sign.rect.position.x,float(row[1])-115.25) and sign.rect.position.y == 292.25, "Sign camera-relative rounding %d" % i)
		check(post.rect.size == Vector2(8,134) and post.rect.end.y == 482.25, "Sign post reaches ground %d" % i)
		check(label.text == "Partner stall" and label.position.y == 320.25 and label.size == 13 and label.outline == Color("14243b"), "Exact label style %d" % i)
		check(commands.find(sign) < commands.find(post) and commands.find(post) < commands.find(label), "Sign source draw order %d" % i)
		all.append_array(commands)
	var c: Dictionary = renderer._festival_context(h)
	var out: Array = []
	c.camera.x = 1060
	renderer._decor_cut(out,c,signs[0])
	check(not out.is_empty(), "Sign cull retains exact-560 edge")
	out.clear()
	c.camera.x = 1060.01
	renderer._decor_cut(out,c,signs[0])
	check(out.is_empty(), "Sign cull rejects beyond-560")
	c.camera.x = float(signs[0][1])-float(c.width)-560
	renderer._decor_cut(out,c,signs[0])
	check(not out.is_empty(), "Sign cull retains right edge")
	out.clear()
	c.camera.x -= 0.01
	renderer._decor_cut(out,c,signs[0])
	check(out.is_empty(), "Sign cull rejects beyond right edge")

func _surfaces_and_decor(h,rt,all: Array) -> void:
	for i in h.level.plats.size():
		var roof: Array = h.level.plats[i]
		h.camera = Vector2(float(roof[0])-200.25,-30.25)
		var level: Array = renderer.build_level(h,rt)
		var vans: Array = tagged(level,"festival_decor").filter(func(cmd):return cmd.key.begins_with("cut_caravan"))
		check(vans.size() == 1 and vans[0].flip_h == (i == 2), "Authored caravan cutout and flip %d" % i)
		check(vans[0].rect.size == (Vector2(385,272) if i == 1 else Vector2(384,274)), "Caravan original image dimensions %d" % i)
		var c: Dictionary = renderer._festival_context(h)
		var invisible: Array = []
		renderer._surface(invisible,c,{"row":roof,"plat":true,"style":"vanroof"})
		check(invisible.is_empty(), "Roof remains invisible collision surface %d" % i)
		all.append_array(level)
	var bales: Array = h.level.solids.filter(func(row):return row[3].style == "bales")
	check(bales.size() == 16, "All16 authored stepped bale surfaces")
	for i in bales.size():
		var row: Array = bales[i]
		h.camera = Vector2(float(row[0])-50.25,0.25)
		var c: Dictionary = renderer._festival_context(h)
		var out: Array = []
		renderer._surface(out,c,{"row":row,"plat":false,"style":"bales"})
		check(not out.is_empty() and out.all(func(cmd):return cmd.key == "baletile" and cmd.rect.size.x <= 120 and cmd.rect.size.y == 54), "Source120x54 tiles for bale step %d" % i)
		check(out.all(func(cmd):return cmd.rect.position.x >= float(row[0])-0.25 and cmd.rect.end.x <= float(row[1])+0.75), "Bale row clipping %d" % i)
		if float(row[2]) == 374:
			check(out.any(func(cmd):return cmd.row == 1 and cmd.rect.size.x == 60), "Odd bale row stagger clips60px %d" % i)
		all.append_array(out)
	h.camera = Vector2(1200.25,0.25)
	var prop_level: Array = renderer.build_level(h,rt)
	var props: Array = tagged(prop_level,"festival_mid_prop")
	check(props.size() == 1 and props[0].key == "cut_bales3" and near(props[0].rect.size.x,181*0.72), "Source behind-player prop uses0.72 scale")
	check(props[0].filter == "mid_prop" and prop_level.find(props[0]) < prop_level.find(tagged(prop_level,"festival_ground")[0]), "Midprop filter and order precede ground/player")
	all.append_array(prop_level)
	h.camera.x = 7000
	var sky: Array = tagged(renderer.build_sky(h,rt),"festival_sky")
	check(sky.all(func(cmd):return cmd.flip_h == (int(cmd.index)%2 != 0)), "Painted sky alternates tile mirroring")
	all.append_array(sky)

func _receipts(h,rt,all: Array) -> void:
	for i in h.level.receipts.size():
		var row: Array = h.level.receipts[i]
		h.camera = Vector2(float(row[0])-300, -100)
		var commands: Array = renderer.build_mid(h,rt)
		check(tagged(commands,"festival_receipt").size() == 1 and tagged(commands,"festival_receipt_line").size() == 4 and tagged(commands,"festival_receipt_tooth").size() == 3, "Original receipt art %d" % i)
		var receipt: Dictionary = tagged(commands,"festival_receipt")[0]
		check(receipt.rect.position.x == float(row[0])-9 and receipt.rect.size == Vector2(18,28), "Receipt center and size %d" % i)
		all.append_array(commands)
		h.receipts[i].taken = true
		check(tagged(renderer.build_mid(h,rt),"festival_receipt").is_empty(), "Taken receipt hidden %d" % i)
		h.receipts[i].taken = false

func _timer(h,rt,all: Array) -> void:
	h.camera = Vector2(8000,-200)
	for row in [[0.0,"90s",false],[0.001,"90s",false],[1.0,"89s",false],[79.999,"11s",false],[80.0,"10s",true],[89.001,"1s",true],[90.0,"0s",true],[100.0,"0s",true]]:
		rt.stage_data.timer_elapsed = row[0]
		var hud: Array = renderer.build_hud(h,rt)
		var box: Dictionary = tagged(hud,"bonus_timer_back")[0]
		var text: Dictionary = tagged(hud,"bonus_timer")[0]
		check(text.text == row[1], "Source ceiling/clamp timer at %s" % row[0])
		check(box.stroke == (Color("ff8f8f") if row[2] else Color("f4c542")) and text.colour == (Color("ffb3b3") if row[2] else Color("f4c542")), "Urgency uses rounded seconds at %s" % row[0])
		check(box.rect == Rect2(410,78,140,38) and box.radius == 12 and box.width == 2 and text.position == Vector2(480,98) and text.size == 22, "Timer is camera-independent logical HUD geometry")
		all.append_array(hud)
	check(tagged(renderer.build_hud(h,{"timer_elapsed":80.0}),"bonus_timer")[0].text == "10s", "Direct bonus snapshot accepted")
	h.elapsed = 1000
	check(tagged(renderer.build_hud(h),"bonus_timer")[0].text == "90s", "HUD never substitutes wall clock for bonus clock")
	h.mode = "paused"
	check(tagged(renderer.build_hud(h,rt),"bonus_timer")[0].text == "0s", "Painting paused clock does not advance it")
	h.mode = "play"
	rt.wiping = true
	rt.wipe_elapsed = 0.8
	rt.wipe_label = ""
	var covered: Array = renderer.build_hud(h,rt)
	check(covered.find(tagged(covered,"wipe_cover")[0]) > covered.find(tagged(covered,"bonus_timer")[0]), "Any shared wipe remains above timer")
	all.append_array(covered)
	rt.wiping = false
	h.level_id = "3-1"
	check(renderer.build_sky(h,rt).is_empty() and renderer.build_level(h,rt).is_empty() and renderer.build_hud(h,rt).is_empty(), "Wrong-level paint remains inactive")
	h.level_id = "3-S"

func _source_contract() -> void:
	var source := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../game/3-S/index.html"))
	for snippet in ["txt('Partner stall', Math.round(x), y - 42, 13", "w / 2, y - 70, w, 56, 10, TENTCOL[d[3] || 0][0]", "Math.max(0, Math.ceil((L3.timer - timerT) / 1000))", "VW / 2 - 70, 78, 140, 38, 12", "s <= 10 ? '#ffb3b3' : '#f4c542'", "if (st === 'vanroof') return;", "y += 54, row++", "(row % 2) * 60"]:
		check(source.contains(snippet), "Original painter contract: "+snippet)

func _coin_blink(h,all: Array) -> void:
	h.camera = Vector2(0,0)
	var coin := {"p":Vector2(500,442),"age":9.0,"rest":true,"stay":true}
	check(not renderer.build_coin(h,coin).is_empty(), "Stay coin is visible exactly at9s")
	coin.age = 9.15
	check(renderer.build_coin(h,coin).is_empty(), "Stay coin blinks off after9s like ordinary source coin")
	coin.age = 9.25
	var visible: Array = renderer.build_coin(h,coin)
	check(not visible.is_empty(), "Stay coin blinks on next interval")
	all.append_array(visible)
	coin.age = 90.15
	check(renderer.build_coin(h,coin).is_empty() and coin.stay and coin.age == 90.15, "Long-lived stay coin keeps blinking without renderer expiry")
