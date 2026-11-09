extends SceneTree
## Command/anchor/source-asset tests and real headless CanvasItem callbacks.
## No screenshot, mobile device or complete stage-playthrough certification.
const Renderer = preload("res://src/festival_tout_renderer.gd")
const Boss = preload("res://src/festival_boss.gd")

class Host extends RefCounted:
	var level_id := "3-6"
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
	var enemies: Array = []
	var bullets: Array = []
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


const Proxy = preload("res://src/festival_night_overlay.gd").DrawProxy
class DrawNode extends Node2D:
	var painter
	var host
	var commands: Array=[]
	var calls := 0
	func _draw() -> void:
		painter.draw_commands(Proxy.new(self,host),commands)
		calls+=1

var renderer = Renderer.new()
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)

func tagged(commands: Array, tag: String) -> Array:
	return commands.filter(func(c): return c.tag == tag)

func boss_state() -> Dictionary:
	return {"kind": "tout", "name": "The Ticket Tout", "x": 4165.37, "fy": 354.61,
		"face": -1, "hp": 160, "max": 160, "state": "walk", "t": 0.0, "dizzy": 0.0,
		"flash": 0.0, "moved": false, "land_t": 0.0, "jar": {}, "waves": []}

func choose(animation: String, frame: int) -> Dictionary:
	var b := boss_state()
	var elapsed := 0.0
	match animation:
		"walk": b.state = "enter"; elapsed = frame * 0.15
		"throw": b.state = "throw"; b.t = frame * 0.16
		"down": b.state = "down"; b.t = frame * 0.28
		"dizzy": b.dizzy = 1.0; b.t = frame * 0.17
		"surf": b.hop = {"t": 0.1, "duration": 0.8, "slam": false}; b.t = frame * 0.14
		"stomp":
			if frame == 2: b.hop = {"t": 0.72, "duration": 0.9, "slam": true}
			elif frame == 3: b.land_t = 0.32
			else: b.state = "stomp"; b.t = frame * 0.16
		"hide": elapsed = [0.0, 1.3, 2.08, 0.0][frame]
	return {"boss": b, "elapsed": elapsed}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var h := Host.new()
	h.meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/3-6.json"))
	h.level = h.meta.level
	for key in h.meta.imgs: h.images[key] = load(h.meta.imgs[key])
	h.sheets.thief = load("res://assets/sprites/thief-sheet.png")
	h.sheets.bot = load("res://assets/sprites/bot-sheet.png")
	var original_meta := var_to_str(h.meta)
	var original_images: Dictionary = {}
	for animation in h.meta.l3.toutfr:
		original_images[animation] = h.images["cut_tout_" + animation].get_image().get_data()
	check(renderer.supports("3-6") and not renderer.supports("3-4") and not renderer.supports("3-5"), "only finale dispatch")
	check(h.meta.l3.stage is float and int(h.meta.l3.stage) == 0, "numeric stage zero retained")
	check(h.level.plats[0] == [4040.0,4290.0,354.0,{"base":482.0,"style":"cases"}], "stage zero exact cases bounds")
	var expected := {"walk":[322,457,173,455],"throw":[287,432,181,431],"stomp":[339,406,154,404],"dizzy":[260,464,118,462],"down":[358,430,181,429],"surf":[346,241,155,239],"hide":[332,488,154,487]}
	var source := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../game/3-6/index.html"))
	for anchor in ["Math.floor(t / 280)","Math.floor(t / 140) % 4","k < 0.12 ? 0 : k < 0.7 ? 1 : 2","Math.floor(t / 170) % 4","Math.floor(levelT / 150) % 4","Math.floor(levelT / 260) % 12","typeof L3.stage === 'number'","mv[1] * f.cw, 0, f.cw, f.ch, -f.ax / hi, -f.ay / hi","g.filter = 'brightness(2)'","b.face > 0) g.scale(-1, 1)"]:
		check(source.contains(anchor), "source anchor: " + anchor)
	h.camera = Vector2(3662.25,-90.35)
	var all_frames: Array = []
	for animation in expected:
		var f: Dictionary = h.meta.l3.toutfr[animation]
		var key := "cut_tout_" + str(animation)
		check([int(f.cw),int(f.ch),int(f.ax),int(f.ay)] == expected[animation] and int(f.n) == 4, "exact authored metadata " + animation)
		check(h.images[key].get_size() == Vector2(f.cw * 4, f.ch) and h.meta.hi[key] == 1.3, "four complete frames at hi1.3 " + animation)
		for frame in 4:
			var rt := choose(animation, frame)
			var pose := Renderer.tout_move(rt.boss, rt.elapsed)
			check(pose.animation == animation and pose.frame == (0 if animation == "hide" and frame == 3 else frame), "source move selection %s:%d" % [animation,frame])
			for face in [-1,1]:
				rt.boss.face = face
				var commands := renderer.build_boss(h, rt)
				check(tagged(commands,"festival_boss").is_empty() and tagged(commands,"tout_boss").size() == 1, "authored sprite replaces thief %s:%d:%d" % [animation,frame,face])
				var cmd: Dictionary = tagged(commands,"tout_boss")[0]
				var x := h.camera.x + Renderer.source_round(float(rt.boss.x) - h.camera.x)
				var left := x - float(f.ax) / 1.3 if face < 0 else x + float(f.ax-f.cw) / 1.3
				var top := Renderer.source_round(rt.boss.fy) - float(f.ay) / 1.3 + h.camera.y - Renderer.source_round(h.camera.y)
				check(cmd.rect.position.is_equal_approx(Vector2(left,top)) and cmd.rect.size.is_equal_approx(Vector2(f.cw,f.ch)/1.3), "fractional camera/feet and per-move anchor %s:%d:%d" % [animation,frame,face])
				check(cmd.source == Rect2(pose.frame*f.cw,0,f.cw,f.ch) and cmd.flip_h == (face > 0) and cmd.hi == 1.3, "crop and source facing %s:%d:%d" % [animation,frame,face])
				if face == -1:
					# hide frame3 is authored but intentionally never selected by toutMove.
					cmd = cmd.duplicate(true)
					cmd.frame = frame
					cmd.source.position.x = frame*f.cw
					all_frames.append(cmd)
			var pixels: Image = h.images[key].get_image().get_region(Rect2i(frame*int(f.cw),0,int(f.cw),int(f.ch)))
			check(pixels.get_used_rect().has_area(), "nonempty original pixels %s:%d" % [animation,frame])
			var before := var_to_str(rt)
			var repeat := renderer.build_boss(h,rt)
			check(repeat == renderer.build_boss(h,rt) and before == var_to_str(rt), "repeat boss builder purity %s:%d" % [animation,frame])
	# Explicit priority and boundary checks, including surf/stomp while dizzy.
	var b := boss_state()
	b.hop = {"t":0.1,"duration":1.0,"slam":true}; b.dizzy=1.0; b.land_t=0.2
	check(Renderer.tout_move(b,0) == {"animation":"stomp","frame":0}, "hop outranks landing and dizziness")
	for pair in [[0.119999,0],[0.12,1],[0.699999,1],[0.7,2],[1.0,2]]:
		b.hop.t=pair[0]
		check(Renderer.tout_move(b,0).frame == pair[1], "slam fraction boundary %s" % pair[0])
	b.erase("hop")
	check(Renderer.tout_move(b,0) == {"animation":"stomp","frame":3}, "landing holds final stomp despite dizzy")
	b.land_t=0.0; b.state="throw"; b.t=0.34
	check(Renderer.tout_move(b,0) == {"animation":"dizzy","frame":2}, "dizzy outranks throw")
	b.state="down"; b.t=0.1; b.jar={"got":true}
	check(Renderer.tout_move(b,0) == {"animation":"down","frame":3}, "jar existence pins down3 even collected")
	b= boss_state(); b.moved=true
	check(Renderer.tout_move(b,0.45) == {"animation":"walk","frame":3}, "moving snapshot uses level clock")
	b.moved=false
	for pair in [[1.299999,0],[1.3,1],[1.56,0],[2.08,2],[2.6,2],[2.86,0],[3.12,0]]:
		check(Renderer.tout_move(b,pair[0]) == {"animation":"hide","frame":pair[1]}, "idle blink/peek phase %s" % pair[0])
	check(Renderer.flash_pixel(Color(0.2,0.4,0.7,0.3)).is_equal_approx(Color(0.4,0.8,1,0.3)), "flash doubles channels, clamps and retains alpha")
	check(Renderer.flash_pixel(Color(0,0,0,1)) == Color(0,0,0,1), "brightness does not whiten black")
	var rt := {"boss":boss_state(),"elapsed":2.08,"live_surfaces":[]}
	for row in h.level.solids+h.level.plats:
		var q: Dictionary=row[3].duplicate(true)
		q.row=row.duplicate(true)
		rt.live_surfaces.append(q)
	var sky := renderer.build_sky(h,rt)
	check(tagged(sky,"festival_sky_gradient")[0].colours[0] == Color("3b3270"), "dusk palette")
	check(not tagged(sky,"festival_sky").is_empty() and tagged(sky,"festival_sky")[0].key == "crowd_sky", "original crowd sky strip")
	var level := renderer.build_level(h,rt)
	var cases := tagged(level,"big_top_cases")
	check(cases.size() == 10 and cases[0].rect.position == Vector2(4040.25,353.65) and cases[5].rect.position == Vector2(4040.25,417.65), "two source case tiers with live stage0 anchor")
	check(tagged(level,"festival_decor").is_empty(), "painted flags/speakers not doubled")
	check(tagged(level,"festival_land")[0].key == "crowd_land" and tagged(level,"festival_land")[0].factor == 0.45, "crowd land parallax")
	check(tagged(level,"festival_far")[0].factor == 0.16 and tagged(level,"festival_ground")[0].factor == 1.0, "far/ground source parallax")
	for camera in [700.25,1750.25,2600.25]:
		h.camera.x=camera
		level=renderer.build_level(h,rt)
		check(not tagged(level,"festival_bale" if camera == 1750.25 else "queue_barrier").is_empty(), "authored obstacle geometry at %s" % camera)
	for row in h.level.receipts:
		h.receipts=[{"p":Vector2(row[0],row[1]),"taken":false}]
		h.camera.x=float(row[0])-200
		check(tagged(renderer.build_finds(h,rt),"festival_receipt").size() == 1, "receipt at exact authored center %s" % row[0])
	h.camera=Vector2(3662.25,-90.35)
	rt.boss.waves=[{"x":4100.7,"vx":-420.0,"t":0.1}]
	var boss_commands := renderer.build_boss(h,rt)
	check(boss_commands[0].tag == "festival_boss_shadow" and boss_commands[1].tag == "tout_boss" and boss_commands[2].tag == "festival_shockwave", "shadow actor shockwave ordering")
	check(is_equal_approx(boss_commands[0].center.y, rt.boss.fy-2-0.35), "stage shadow follows feet")
	rt.boss.hop={"t":0.1,"duration":0.8,"slam":false}
	check(is_equal_approx(renderer.build_boss(h,rt)[0].center.y,479.65), "hop shadow stays on ground")
	rt.boss.erase("hop")
	var hud := renderer.build_hud(h,rt)
	check(tagged(hud,"festival_boss_name")[0].text == "The Ticket Tout" and tagged(hud,"festival_boss_health")[0].rect.size.x == 420, "Tout HUD name/full HP")
	rt.boss.hp=80; rt.boss.dizzy=1.0
	check(tagged(renderer.build_hud(h,rt),"festival_boss_health")[0].rect.size.x == 210 and tagged(renderer.build_hud(h,rt),"festival_boss_health")[0].colour == Renderer.GOLD, "half-health dizzy HUD")
	rt.boss.state="down"; rt.boss.jar={"x":4100.7,"y":452.0,"t":0.21,"got":false}
	check(tagged(renderer.build_hud(h,rt),"festival_boss_health").is_empty(), "down hides boss health")
	var jar := renderer.build_jar(h,rt)
	var center := Vector2(4100.7,452+sin(1.5)*2-0.35)
	check(tagged(jar,"tout_jar_glow")[0].center.is_equal_approx(center+Vector2(0,-4)), "source jar bob and unsnapped x")
	check(tagged(jar,"tout_jar_glass")[0].rect.size == Vector2(56,60) and tagged(jar,"tout_jar_coin_detail").size() == 6, "full size2 jar glass and coins")
	rt.boss.jar.got=true
	check(tagged(renderer.build_jar(h,rt),"tout_jar_glow").is_empty() and tagged(renderer.build_jar(h,rt),"tout_jar_lid")[0].rect.position.is_equal_approx(Vector2(4082.7,407.65)), "collected jar remains drawn without bob/glow")
	# Actual boss API: stage-zero transition produces the painted surf, landing,
	# throw, defeat and delayed jar snapshots without renderer simulation writes.
	var boss = Boss.new()
	var config: Dictionary=h.meta.l3.boss.duplicate(true)
	config.cam=3662.0
	boss.reset(config,738,482,1,31,rt.live_surfaces[-1],false)
	boss.state.x=4000.0; boss.state.state="walk"; boss.state.hp=100; boss.state.t=2.0; boss.state.next=1.0
	var players: Array[Dictionary]=[{"position":Vector2(3800,482),"alive":true}]
	boss.boss_tick(0.016,players)
	check(boss.state.has("hop") and boss.state.hop.end == Vector2(4165,354), "real boss starts stage0 hop")
	check(tagged(renderer.build_boss(h,{"boss":boss,"elapsed":4.0}),"tout_boss")[0].animation == "surf", "real stage hop uses surf art")
	boss.boss_tick(0.8,players)
	check(boss.state.fy == 354 and not boss.state.has("hop"), "real stage0 landing")
	boss.state.state="throw"; boss.state.t=0.32
	check(tagged(renderer.build_boss(h,{"boss":boss}),"tout_boss")[0].frame == 2, "real stage throw frame2")
	boss.state.hp=1
	check(boss.hit(Vector2(boss.state.x,boss.state.fy-100)), "actual last hit accepted")
	boss.boss_tick(1.501,players)
	check(tagged(renderer.build_boss(h,{"boss":boss}),"tout_boss")[0].frame == 3 and not renderer.build_jar(h,{"boss":boss}).is_empty(), "defeat down3 and actual delayed jar")
	var before := var_to_str(rt)
	seed(810)
	var next_random := randf()
	seed(810)
	for i in 3:
		renderer.build_sky(h,rt); renderer.build_level(h,rt); renderer.build_boss(h,rt); renderer.build_jar(h,rt); renderer.build_hud(h,rt)
	check(randf() == next_random and before == var_to_str(rt) and original_meta == var_to_str(h.meta), "all builders preserve RNG/runtime/imported metadata")
	var node := DrawNode.new()
	node.host=h; node.painter=renderer
	root.add_child(node)
	await process_frame
	for frame in all_frames:
		for flash in [false,true]:
			var command: Dictionary=frame.duplicate(true)
			command.flash=flash
			command.flip_h=flash
			node.commands=renderer.build_sky(h,rt)+renderer.build_level(h,rt)+[command]+renderer.build_jar(h,rt)+hud
			node.queue_redraw()
			await process_frame
			node.notification(CanvasItem.NOTIFICATION_DRAW)
	check(node.calls >= 56 and renderer._tout_flashes.size() == 28, "all 28 original crops and flashes in actual CanvasItem callbacks")
	for animation in original_images:
		check(original_images[animation] == h.images["cut_tout_"+animation].get_image().get_data(), "drawing/flash cache leaves original pixels intact " + animation)
	check(before == var_to_str(rt), "CanvasItem draw callbacks preserve runtime")
	node.queue_free()
	await process_frame
	renderer.clear_cache()
	check(renderer._tout_flashes.is_empty(), "reset clears flash cache")
	h.images.clear(); h.sheets.clear()
	print("festival Tout renderer: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
