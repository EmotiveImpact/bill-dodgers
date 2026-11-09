extends SceneTree
const Painter = preload("res://src/holiday_renderer.gd")
const RuntimeTest = preload("res://tests/test_holiday_runtime.gd")
const Drawing = preload("res://tests/test_festival_hayride_renderer.gd")
class Host extends RuntimeTest.Host:
	var images:Dictionary={}
	var sheets:Dictionary={}
	var elapsed:=1.25
	var receipts:Array=[]
	var font:Font=load("res://assets/fonts/silk.woff2")
	var character:="jp"
	func load_art(id:String)->void:
		load_source(id)
		images.clear();sheets.clear();receipts.clear()
		for key in meta.imgs:images[key]=load(meta.imgs[key])
		for key in meta.sheets:
			var path: String = "res://assets/sprites/%s-sheet.png" % key
			if ResourceLoader.exists(path):sheets[key]=load(path)
		for i in level.receipts.size():receipts.append({"position":world_four.receipt_position(self,i),"taken":false})
class TextureSpy extends RefCounted:
	var images:Dictionary={}
	var draws:Array=[]
	func draw_texture_rect_region(_texture,rect,source,colour)->void:
		draws.append({"rect":rect,"source":source,"colour":colour})
var failures:Array[String]=[]
var checks:=0
var painter=Painter.new()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func tagged(cmd:Array,tag:String)->Array:return cmd.filter(func(c):return c.tag==tag)
func _initialize()->void:call_deferred("run")
func run()->void:
	var h:=Host.new();var all:Array=[]
	for id in RuntimeTest.World.SUPPORTED_LEVELS:
		h.load_art(id)
		check(painter.supports(id),id+" painterdispatch")
		for part in h.level.scenes.size():
			h.camera=Vector2(maxf(0,h.level.scenes[part].x),0)
			var before:=JSON.stringify(h.meta)
			var state:=var_to_str(h.world_four.snapshot())
			var rng_state:int=h.world_four.rng.state
			var sky:Array=painter.build_sky(h,h.world_four)
			var level:Array=painter.build_level(h,h.world_four)
			check(not sky.is_empty() and not level.is_empty(),id+" scene%d actualart"%part)
			check(tagged(sky,"holiday_sky")[0].colours[0]==Color(h.level.scenes[part].sky[0]),id+" scene palette")
			check(before==JSON.stringify(h.meta) and state==var_to_str(h.world_four.snapshot()) and rng_state==h.world_four.rng.state,id+" purepaint")
			all=sky+level+painter.build_front(h,h.world_four)+painter.build_hud(h,h.world_four)+painter.build_finds(h,h.world_four)
			var node:=Drawing.DrawNode.new();node.painter=painter;node.host=h;node.commands=all
			root.add_child(node);await process_frame;await process_frame
			check(node.calls>0,id+" realCanvasItem scene%d"%part)
			node.queue_free();await process_frame
	h.load_art("4-1");h.camera.x=1500
	var level:Array=painter.build_level(h,h.world_four)
	check(not tagged(level,"holiday_carousel").is_empty() and not tagged(level,"holiday_belt_slats").is_empty(),"paintedcarousels andanimatedslats")
	var q:Dictionary=h.world_four.surfaces(h).filter(func(s):return s.get("belt",0))[0]
	var carousel:Dictionary=tagged(level,"holiday_carousel")[0]
	check(carousel.rect.size.y==painter.source_round((482-q.row[2])/0.62),"sourcecarouselline alignment")
	for x in [2600,6000,9500,14000]:
		h.camera.x=x
		level=painter.build_level(h,h.world_four)
		check(not tagged(level,"holiday_block_top").is_empty(),"airportsource floorx%d"%x)
	h.load_art("4-4");q=h.world_four.surfaces(h).filter(func(s):return s.has("bob"))[0]
	h.camera.x=q.row[0]-100;h.world_four.pre_motion(0.016,h)
	level=painter.build_level(h,h.world_four)
	check(not tagged(level,"holiday_boat").is_empty() and not tagged(level,"holiday_water").is_empty(),"sourceboatwater rendering")
	var boat:Dictionary=tagged(level,"holiday_boat")[0]
	check(boat.rect.size.x==q.row[1]-q.row[0]+70,"authoredboathull deckwidth+70")
	h.load_art("4-5");level=painter.build_level(h,h.world_four)
	var deck:Dictionary=tagged(level,"holiday_deck")[0]
	check(deck.rect.position.y==482-h.level.deckLine,"painteddecktopsourceanchor")
	h.load_art("4-3");h.camera.x=h.world_four.cfg.hold.cam;h.world_four.hold.on=true
	check(tagged(painter.build_level(h,h.world_four),"holiday_towel").size()==4,"fourphysicaltowelpaintings")
	check(tagged(painter.build_hud(h,h.world_four),"holiday_hold_time")[0].text=="Hold on 2:30","150secondholdHUD")
	h.world_four.spawn_foe("r","grab",h);h.elapsed=0.31
	check(not tagged(painter.build_level(h,h.world_four),"holiday_towel_warning").is_empty(),"source targetedtowel flasheswarning")
	h.elapsed=1.25
	h.load_art("4-S")
	check(tagged(painter.build_hud(h,h.world_four),"holiday_dash_time")[0].text=="Time 1:40","100secondbonusHUD")
	for kind in ["case","drop","bailiff","jet","ring","banana","melon","grab"]:
		h.load_art("4-3" if kind=="grab" else ("4-2" if kind=="melon" else ("4-1" if kind in ["case","drop","bailiff"] else "4-5")))
		h.world_four.foes.entries.clear()
		if kind=="bailiff":h.load_art("4-1");h.world_four.foes.entries.clear()
		h.world_four.spawn_foe("r",kind,h)
		if h.world_four.foes.entries.is_empty():
			# Water-stage nobot source geometry has no melon/case ground;
			# test them on their actual source airport/terrace stage instead.
			h.load_art("4-2" if kind=="melon" else "4-1");h.world_four.foes.entries.clear();h.world_four.spawn_foe("r",kind,h)
		check(not h.world_four.foes.entries.is_empty(),kind+" authoredspawn")
		if h.world_four.foes.entries.is_empty():continue
		var f:Dictionary=h.world_four.foes.entries[0];f.x=h.camera.x+400
		var state:=var_to_str(h.world_four.snapshot());var rng_state:int=h.world_four.rng.state
		var commands:Array=painter.build_foes(h,h.world_four)+painter.build_front(h,h.world_four)
		check(not commands.is_empty(),kind+" customdrawing")
		check(var_to_str(h.world_four.snapshot())==state and h.world_four.rng.state==rng_state,kind+" pureactorpaint")
		var node:=Drawing.DrawNode.new();node.painter=painter;node.host=h;node.commands=commands
		root.add_child(node);await process_frame;await process_frame
		check(node.calls>0,kind+" realCanvasItem")
		node.queue_free();await process_frame
	# Final executable wrapper removes fast foreground art and moves standing
	# front props behind actors. Imported metadata stays untouched.
	h.load_art("4-3")
	check(tagged(painter.build_front(h,h.world_four),"holiday_foreground").is_empty(),"final wrapper suppresses foregroundparallax")
	check(tagged(painter.build_level(h,h.world_four),"holiday_front_behind").size()==h.level.get("front",[]).size(),"sourcefront props move behindactors")
	h.load_art("4-1")
	var finds:Array=painter.build_finds(h,h.world_four)
	check(tagged(finds,"holiday_receipt_tooth").size()==4,"source receipt fourteeth")
	var first:Dictionary=h.receipts[0]
	check(tagged(finds,"holiday_receipt")[0].type=="polygon","source receipt rotates as polygon")
	first.taken=true;first.age=0.3
	check(is_equal_approx(tagged(painter.build_finds(h,h.world_four),"holiday_receipt")[0].colour.a,0.5),"source receipt half fade at0.3s")
	first.age=0.6
	check(tagged(painter.build_finds(h,h.world_four),"holiday_receipt").is_empty(),"source receipt removed at0.6s")
	h.combat.go_time=1.9
	check(tagged(painter.build_hud(h,h.world_four),"holiday_go").size()==1,"source Go blink visible")
	h.combat.go_time=1.6
	check(tagged(painter.build_hud(h,h.world_four),"holiday_go").is_empty(),"source Go blink hidden")
	h.world_four.end_time=0.001;h.combat.go_time=1.9
	check(tagged(painter.build_hud(h,h.world_four),"holiday_go").is_empty(),"source ending hides Go")
	h.load_art("4-6");h.world_four.captain.start(h)
	var hud:Array=painter.build_hud(h,h.world_four)
	check(tagged(hud,"holiday_captain_health")[0].rect==Rect2(270,500,420,18),"source Captain full90 healthbar")
	check(tagged(hud,"holiday_captain_name")[0].text=="Captain Overcharge","source Captain label not JarThief")
	h.world_four.captain.boss.hp=45;h.world_four.captain.boss.dizzy=1
	var bar:Dictionary=tagged(painter.build_hud(h,h.world_four),"holiday_captain_health")[0]
	check(bar.rect.size.x==210 and bar.colour==painter.GOLD,"source halfhp dizzy bar")
	h.world_four.captain.boss.state="down"
	check(tagged(painter.build_hud(h,h.world_four),"holiday_captain_health").is_empty(),"source down hides bar")
	h.world_four.foes.clear();h.world_four.spawn_foe("r","ring",h)
	h.world_four.foes.entries[0].x=400
	var ring:Array=painter.build_foes(h,h.world_four)
	check(tagged(ring,"holiday_ring_fallback").size()==1,"Captain ring uses procedural source fallback")
	check(tagged(ring,"holiday_ring_fallback")[0].points.size()==65,"closedellipse ring outline")
	h.world_four.wiping=true;h.world_four.wipe_kind="stairs";h.world_four.wipe_label="Upstairs";h.world_four.wipe_elapsed=0.26
	hud=painter.build_hud(h,h.world_four)
	check(tagged(hud,"wipe_iris").size()==1,"source stairs iris closing")
	h.world_four.wipe_elapsed=1.0;hud=painter.build_hud(h,h.world_four)
	check(tagged(hud,"wipe_cover").size()==1 and tagged(hud,"wipe_label")[0].text=="Upstairs","source wipe coverandlabel")
	h.world_four.wipe_elapsed=1.8;hud=painter.build_hud(h,h.world_four)
	check(tagged(hud,"wipe_iris").size()==1,"source stairs iris opening")
	h.world_four.wipe_elapsed=2.17
	check(tagged(painter.build_hud(h,h.world_four),"wipe_iris").is_empty(),"wipe disappearsatend")
	var node:=Drawing.DrawNode.new();node.painter=painter;node.host=h;node.commands=ring+hud+finds
	root.add_child(node);await process_frame;await process_frame
	check(node.calls>0,"new HUD/iris/ring/receipt commands actualCanvasItem")
	node.queue_free();await process_frame
	# Source BD.parallax mirrors alternate tiles without changing coverage.
	# Godot's negative destination width is an in-place reflection, not a
	# Canvas2D scale around x=0. Record actual CanvasItem arguments as well
	# as the pure builder positions to prevent a hidden draw-time offset.
	h.load_art("4-6");h.camera.x=float(h.level.w)-h.view_width()
	var sky_tiles:Array=tagged(painter.build_sky(h,h.world_four),"holiday_parallax")
	var spy:=TextureSpy.new();spy.images=h.images
	for command in sky_tiles:
		painter.draw_commands(spy,[command])
		var actual:Dictionary=spy.draws.back()
		check(actual.rect.position==command.rect.position,"W4 actual tile draw keeps source left/top")
		check(absf(actual.rect.size.x)==command.rect.size.x and actual.rect.size.y==command.rect.size.y,"W4 tile destination retains dimensions")
		check((actual.rect.size.x<0)==command.flip_h and actual.source==command.source,"W4 odd tile mirrored in place with unchanged crop")
	var coast:Array=sky_tiles.filter(func(c):return c.key=="coast")
	check(coast.size()>=5,"Captain skyline spans viewport with source142px tiles")
	for i in range(1,coast.size()):
		check(coast[i-1].rect.end.x==coast[i].rect.position.x,"Captain coastline no alternating gaps or overlapping tiles")
	painter.clear_cache()
	print("Holiday renderer: %d checks, %d failures; command/CanvasItem verification, no screenshot/device parity."%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
