extends SceneTree
## Geometry/command, original art, purity and headless CanvasItem tests.
## This suite does not certify screenshots, phone rendering or difficulty.
const Renderer = preload("res://src/festival_night_renderer.gd")

class Host extends RefCounted:
	var level_id := "3-3"
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


const Overlay = preload("res://src/festival_night_overlay.gd")
var renderer = Renderer.new()
var count := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	count += 1
	if not ok: failures.append(label); printerr("FAIL: "+label)
func tagged(commands: Array, tag: String) -> Array:
	return commands.filter(func(c): return c.tag==tag)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var h := Host.new()
	h.meta=JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/3-3.json"))
	h.level=h.meta.level
	for key in h.meta.imgs: h.images[key]=load(h.meta.imgs[key])
	var rt := {"scene_index":0,"elapsed":0.22,"wipe_kind":"fade","wiping":true,"wipe_elapsed":0.26,"wipe_label":"The far field","stage_data":{"flash_time":0.0,"fireworks":[]}}
	var original := JSON.stringify(h.meta)
	check(renderer.supports("3-3") and not renderer.supports("3-1"),"stage dispatch")
	check(h.level.tents.size()==15,"15 authored cutout tents")
	var sky := renderer.build_sky(h,rt)
	check(tagged(sky,"festival_sky_gradient")[0].colours[0]==Color("060a1f"),"night gradient")
	check(tagged(sky,"festival_sky")[0].key=="campsite_sky","campsite original sky")
	rt.scene_index=1
	check(tagged(renderer.build_sky(h,rt),"festival_sky")[0].key=="fieldAnight_sky","far field original sky")
	rt.scene_index=0
	var level := renderer.build_level(h,rt)
	check(not tagged(level,"night_lantern").is_empty(),"procedural lantern")
	check(tagged(level,"festival_decor").filter(func(c): return c.key.begins_with("cut_flag")).is_empty(),"flags already in painting")
	var tent_count := 0
	for row in h.level.tents:
		h.camera.x=row[0]
		var tents := tagged(renderer.build_level(h,rt),"festival_tent")
		check(not tents.is_empty(),"tent original art visible")
		tent_count+=1
	check(tent_count==15,"all tent camera positions")
	h.camera=Vector2(1000.25,-10.25)
	level=renderer.build_level(h,rt)
	var flames := tagged(level,"night_fire_flames")
	check(not flames.is_empty(),"fire additive crop")
	if not flames.is_empty():
		check(flames[0].source==Rect2(18,0,54,92) and flames[0].alpha==0.55 and flames[0].frame==2,"exact crop alpha110ms frame")
	check(Renderer.fire_geometry(0)==Renderer.fire_geometry(4),"four deterministic flame frames")
	check(Renderer.fire_geometry(0)!=Renderer.fire_geometry(1),"animated seeded fire")
	check(Renderer.fire_geometry(0).size()==44,"40 flame blocks plus logs and core")
	h.camera=Vector2.ZERO
	h.enemies=[{"p":Vector2(350,482),"state":"walk"},{"p":Vector2(450,482),"state":"pop"}]
	h.bullets=[{"p":Vector2(350,400),"enemy":false},{"p":Vector2(350,400),"enemy":true}]
	var dark := renderer.build_darkness(h,rt)
	var mask: Dictionary=dark[0]
	check(mask.alpha==0.5 and mask.rect.size==Vector2(738,420),"source mask size and alpha")
	check(mask.holes.filter(func(v):return v.z==120).is_empty(),"fifth tent field does not activate glow")
	check(mask.holes.filter(func(v):return v.z==60).size()==1,"player shots only")
	check(mask.holes.filter(func(v):return v.z==70).size()==1,"live bot light only")
	check(tagged(dark,"night_bot_eye").size()==2,"live red eyes after darkness")
	check(is_zero_approx(Renderer.darkness_at(Vector2(300,482-90-h.view_top()),mask.holes,mask.alpha)),"player center hole fully clears")
	var test_holes: Array=[Vector4(0,0,100,0.5),Vector4(0,0,100,0.5)]
	check(is_equal_approx(Renderer.darkness_at(Vector2.ZERO,test_holes,0.8),0.2),"destination-out multiplies overlap")
	check(is_equal_approx(Renderer.darkness_at(Vector2(100,0),test_holes,0.8),0.8),"outer light radius no effect")
	rt.stage_data.flash_time=0.5
	check(is_equal_approx(renderer.build_darkness(h,rt)[0].alpha,1.0/12),"500ms flash source darkness")
	rt.stage_data.fireworks=[{"x":400.0,"y":200.0,"col":"#ff8fc7","t":0.7,"s":[Vector2(1,0)]}]
	var spark: Dictionary=tagged(renderer.build_darkness(h,rt),"night_firework")[0]
	check(spark.rect==Rect2(484,220,4,4) and is_equal_approx(spark.colour.a,0.5),"firework displacement gravity and fading")
	var hud := renderer.build_hud(h,rt)
	check(tagged(hud,"wipe_iris").is_empty() and tagged(hud,"wipe_cover").size()==1,"actual fade not iris")
	check(is_equal_approx(tagged(hud,"wipe_cover")[0].colour.a,0.5),"half closure fade alpha")
	check(JSON.stringify(h.meta)==original,"source metadata immutable")
	var front := renderer.build_front(h,rt)
	check(front==renderer.build_front(h,rt),"repeat draw deterministic")
	check(front[-1].tag=="festival_hint","hint after mask and fireworks")
	check(Renderer.night_bale_pixel(Color.WHITE).is_equal_approx(Color(0.5,0.5,0.5)),"night bale brightness half")
	check(is_equal_approx(Renderer.night_bale_pixel(Color(1,0,0,0.7)).a,0.7),"bale filter preserves alpha")
	var overlay := Overlay.new()
	root.add_child(overlay)
	overlay.configure(h,renderer)
	overlay.refresh(rt)
	await process_frame
	await process_frame
	# Headless does not render frames automatically, but emits valid CanvasItem
	# draw notifications; shader/material data and callback behavior are tested.
	for pass_node in overlay.passes:
		pass_node.notification(CanvasItem.NOTIFICATION_DRAW)
		check(pass_node.draw_count>0,"real CanvasItem front callback")
	check(overlay.passes[0].material.shader.code==Renderer.DARK_SHADER,"GPU destination-out equivalent shader")
	var commands: Array=tagged(renderer.build_level(h,rt),"night_fire_flames")
	if commands.is_empty():
		h.camera.x=1000
		commands=tagged(renderer.build_level(h,rt),"night_fire_flames")
	if not commands.is_empty():
		overlay.refresh(rt,commands)
		for pass_node in overlay.passes:
			if pass_node.visible: pass_node.notification(CanvasItem.NOTIFICATION_DRAW)
		check(overlay.passes[0].material.shader.code==Renderer.ADD_SHADER,"additive flame callback material")
	overlay.configure(h,renderer,"level")
	overlay.refresh(rt)
	check(overlay.show_behind_parent,"level overlay behind actor parent")
	for pass_node in overlay.passes:
		if pass_node.visible: pass_node.notification(CanvasItem.NOTIFICATION_DRAW)
	h.level_id="3-1"
	overlay.refresh(rt)
	check(not overlay.visible and overlay.passes[0].commands.is_empty(),"stage change hides and clears")
	overlay.queue_free()
	await process_frame
	renderer.clear_cache()
	h.images.clear()
	print("festival night renderer: %d checks, %d failures"%[count,failures.size()])
	quit(0 if failures.is_empty() else 1)
