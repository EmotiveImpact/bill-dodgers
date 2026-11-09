extends SceneTree
## Geometry/command, original art, purity and headless CanvasItem tests.
## This suite does not certify screenshots, phone rendering or difficulty.
const Renderer = preload("res://src/festival_big_top_renderer.gd")

class Host extends RefCounted:
	var level_id := "3-4"
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
var count := 0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	count+=1
	if not ok: failures.append(label); printerr("FAIL: "+label)
func tagged(commands: Array,tag: String) -> Array: return commands.filter(func(c):return c.tag==tag)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var h := Host.new()
	h.meta=JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/3-4.json"))
	h.level=h.meta.level
	for key in h.meta.imgs: h.images[key]=load(h.meta.imgs[key])
	h.sheets.thief=load("res://assets/sprites/thief-sheet.png")
	var original := JSON.stringify(h.meta)
	var rt := {"elapsed":0.5,"spots":[],"live_surfaces":[]}
	for row in h.level.spots: rt.spots.append({"x":row[0],"y":row[1],"on":false,"t":0.9,"hp":2})
	for row in h.level.solids+h.level.plats:
		var q: Dictionary=row[3].duplicate()
		q.row=row.duplicate(true)
		rt.live_surfaces.append(q)
	check(renderer.supports("3-4") and not renderer.supports("3-3"),"stage dispatch")
	check(h.level.plats.size()==49 and h.level.movers.size()==4,"49 authored platforms and four movers")
	for i in h.level.plats.size():
		var row: Array=h.level.plats[i]
		h.camera=Vector2(row[0],float(row[2])-300)
		var commands := renderer.build_level(h,rt)
		var tag := "big_top_"+str(row[3].style)
		check(not tagged(commands,tag).filter(func(c):return c.rect.position==Vector2(row[0],row[2])).is_empty(),"live platform %d"%i)
	for mover in h.level.movers:
		var index: int = h.level.solids.size()+int(mover[0])
		rt.live_surfaces[index].row[0]+=75
		rt.live_surfaces[index].row[1]+=75
		rt.live_surfaces[index].row[2]-=20
	h.camera=Vector2(4000,-400)
	var level := renderer.build_level(h,rt)
	check(tagged(level,"big_top_rope").size()==8,"eight ropes even when offscreen")
	var rope: Dictionary=tagged(level,"big_top_rope")[0]
	check(rope.points[0]==Vector2(4201,-248) and rope.points[1]==Vector2(4126,h.view_top()-20),"rope live endpoint and immutable ceiling anchor")
	check(tagged(level,"big_top_trapeze")[0].rect.position==Vector2(4195,-248),"moving trapeze painted at live row")
	for spot in rt.spots:
		h.camera=Vector2(float(spot.x)-200,float(spot.y)-80)
		level=renderer.build_level(h,rt)
		check(not tagged(level,"big_top_spot_lens").is_empty() and tagged(level,"big_top_beam").is_empty(),"off lens without beam")
		spot.on=true
		level=renderer.build_level(h,rt)
		var beam: Dictionary=tagged(level,"big_top_beam")[0]
		var angle := sin(1.0)*0.6
		check(beam.points[0]==Vector2(spot.x,float(spot.y)+12),"beam origin offset")
		check(beam.points[1].is_equal_approx(Vector2(spot.x+sin(angle-0.2)*760,spot.y+cos(angle-0.2)*760)),"source cone 760px half angle .2")
		check(is_equal_approx(beam.colour.a,0.18),"beam source alpha no additive")
		spot.on=false
	h.camera=Vector2(5510.25,-1100.25)
	var sky := renderer.build_sky(h,rt)
	var backdrop: Dictionary=tagged(sky,"big_top_backdrop")[0]
	var size: Vector2=Vector2(h.meta.dims.backdrop[0],h.meta.dims.backdrop[1])
	check(backdrop.smooth and backdrop.rect.position.y==h.camera.y+Renderer.source_round(478-size.y-h.camera.y*0.3),"backdrop linear smoothing and vertical parallax")
	check(not tagged(sky,"big_top_pole_extension").is_empty(),"upper-camera pole extends upward with crop")
	for cmd in tagged(sky,"big_top_pole_extension"):
		check(is_equal_approx(cmd.source.position.y,h.images.pole.get_height()*0.3) and is_equal_approx(cmd.source.size.y,h.images.pole.get_height()*0.4) and cmd.brightness==0.82,"pole middle crop brightness")
	level=renderer.build_level(h,rt)
	check(tagged(level,"festival_checkpoint_pole")[0].rect.position.y==-478+h.camera.y-Renderer.source_round(h.camera.y),"checkpoint at -278 authored feet")
	check(float(h.level.skill[0])==5700 and float(h.level.skill[1])==-358 and h.level.skill[2]=="ground-pound","skill authoring retained for host card painter")
	var skill_commands := renderer.build_finds(h,rt)
	var skill_card: Dictionary=tagged(skill_commands,"big_top_skill_card")[0]
	check(skill_card.rect.size==Vector2(40,56) and skill_card.rect.position.y==Renderer.source_round(-358+sin(0.5/0.18)*5)+h.camera.y-Renderer.source_round(h.camera.y)-28,"source skill center bob and card size")
	rt.skill_collected=true
	check(tagged(renderer.build_finds(h,rt),"big_top_skill_card").is_empty(),"collected skill disappears")
	rt.skill_collected=false
	h.receipts=[]
	for row in h.level.receipts:
		h.receipts=[{"p":Vector2(row[0],row[1])}]
		h.camera=Vector2(float(row[0])-200,float(row[1])-200)
		check(tagged(renderer.build_finds(h,rt),"festival_receipt").size()==1,"upper receipt center visible")
	h.camera=Vector2(8500,0)
	rt.boss={"kind":"tout","name":"The Ringmaster bot","x":8800.0,"fy":482.0,"face":-1,"hp":60,"max":60,"state":"throw","t":0.35,"dizzy":0.0}
	var boss := tagged(renderer.build_boss(h,rt),"festival_boss")
	check(boss.size()==1 and boss[0].filter=="tout" and boss[0].animation=="throw" and boss[0].frame==2,"Ringmaster selective tint and animation")
	check(Renderer.tint_pixel(Color(0.2,0.3,0.4),"tout")==Color(0.2,0.3,0.4),"Ringmaster preserves non-orange pixels")
	var hud := renderer.build_hud(h,rt)
	check(tagged(hud,"festival_boss_name")[0].text=="The Ringmaster bot" and tagged(hud,"festival_boss_health")[0].rect.size.x==420,"Ringmaster name and health HUD")
	rt.boss.dizzy=1.0
	check(tagged(renderer.build_hud(h,rt),"festival_boss_health")[0].colour==Renderer.GOLD,"dizzy HUD gold")
	var before := var_to_str(rt)
	level=renderer.build_level(h,rt)
	check(level==renderer.build_level(h,rt) and before==var_to_str(rt) and original==JSON.stringify(h.meta),"repeat painter state metadata immutable")
	var node := DrawNode.new()
	node.host=h
	node.painter=renderer
	root.add_child(node)
	await process_frame
	for camera in [Vector2.ZERO,Vector2(1600,0),Vector2(3400,-600),Vector2(5500,-650),Vector2(10000,-700)]:
		h.camera=camera
		rt.spots[2].on=true
		node.commands=renderer.build_sky(h,rt)+renderer.build_level(h,rt)+renderer.build_finds(h,rt)+renderer.build_boss(h,rt)+renderer.build_hud(h,rt)
		node.queue_redraw()
		await process_frame
		node.notification(CanvasItem.NOTIFICATION_DRAW)
	check(node.calls>=5,"five real CanvasItem callbacks spanning sky ring bleachers cases ropes beams boss HUD")
	check(not renderer._smooth_textures.is_empty(),"linear CanvasTexture cache created")
	node.queue_free()
	await process_frame
	renderer.clear_cache()
	h.images.clear()
	h.sheets.clear()
	print("festival big top renderer: %d checks, %d failures"%[count,failures.size()])
	quit(0 if failures.is_empty() else 1)
