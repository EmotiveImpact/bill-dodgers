extends SceneTree
## Geometry/command, original art, purity and headless CanvasItem tests.
## This suite does not certify screenshots, phone rendering or difficulty.
const Renderer = preload("res://src/festival_hayride_renderer.gd")

class Host extends RefCounted:
	var level_id := "3-5"
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
	func draw_polygon(points, colours, uv = null, texture = null): recorded.append(["gradient", points, colours])
	func draw_polyline(points, colour, width): recorded.append(["line", points, colour, width])
	func draw_style_box(style, rect): recorded.append(["rounded", style, rect])
	func draw_string(font_resource, position, text, alignment, width, size, colour): recorded.append(["text", font_resource, position, text, alignment, width, size, colour])
	func draw_string_outline(font_resource, position, text, alignment, width, size, outline, colour): recorded.append(["text_outline", font_resource, position, text, alignment, width, size, outline, colour])


class Proxy extends RefCounted:
	var canvas: CanvasItem
	var images: Dictionary
	var font: Font
	func _init(node, host): canvas=node; images=host.images; font=host.font
	func draw_texture_rect_region(t,r,s,c): canvas.draw_texture_rect_region(t,r,s,c)
	func draw_rect(r,c): canvas.draw_rect(r,c)
	func draw_colored_polygon(p,c): canvas.draw_colored_polygon(p,c)
	func draw_polygon(p,c,uv=PackedVector2Array(),t=null): canvas.draw_polygon(p,c,uv,t)
	func draw_polyline(p,c,w): canvas.draw_polyline(p,c,w)
	func draw_style_box(s,r): canvas.draw_style_box(s,r)
	func draw_string(f,p,t,a,w,s,c): canvas.draw_string(f,p,t,a,w,s,c)
	func draw_string_outline(f,p,t,a,w,s,o,c): canvas.draw_string_outline(f,p,t,a,w,s,o,c)
class DrawNode extends Node2D:
	var painter
	var host
	var commands: Array=[]
	var calls := 0
	func _draw(): painter.draw_commands(Proxy.new(self,host),commands); calls+=1
var renderer=Renderer.new()
var count:=0
var failures: Array[String]=[]
func check(ok: bool,label: String):
	count+=1
	if not ok: failures.append(label); printerr("FAIL: "+label)
func tagged(commands: Array,tag: String)->Array: return commands.filter(func(c):return c.tag==tag)
func _initialize(): call_deferred("run")
func run():
	var source := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../game/3-5/index.html"))
	for snippet in ["const tw = (x1 - x0) / 0.858", "T - th * 0.469 + bob", "Math.sin(levelT / 260 + b.x * 0.01) * 0.06", "art.naturalHeight * 0.6", "d.dir * k * 0.22", "k * k * 0.00002", "Math.max(8, w * harv.hp / harv.max)"]:
		check(source.contains(snippet), "original executable source: "+snippet)
	var h:=Host.new()
	h.meta=JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/3-5.json"))
	h.level=h.meta.level
	for row in h.level.receipts: h.receipts.append({"position":Vector2(row[0],row[1]),"taken":false})
	for key in h.meta.imgs: h.images[key]=load(h.meta.imgs[key])
	h.images.bot=load("res://assets/sprites/bot-sheet.png")
	var rt: Dictionary={"elapsed":0.5,"scene_index":0,"live_surfaces":[{"row":[1060,1540,402],"plat":true,"style":"trailer"}],"stage_data":{"harvester":{"x":1100,"hp":35,"max":70,"flash":0.1}},"ex_drones":[{"p":Vector2(1350,209),"age":1.0,"dir":1}]}
	h.elapsed=0.5; h.camera=Vector2(1000.25,0.25); h.world_three=rt

	check(renderer.supports("3-5") and not renderer.supports("3-4"),"dispatch")
	check(h.level.duck.size()==18 and h.level.decor.size()==18,"18 authored oak branch hazards")
	var all: Array=[]
	for scene in 2:
		rt.scene_index=scene
		var sky: Array=renderer.build_sky(h,rt)
		check(sky[0].colours[0]==Color("6aa8e8"),"lane base palette remains at dusk")
		var level: Array=renderer.build_level(h,rt)
		check(tagged(sky,"festival_sky")[0].key==("lane_sky" if scene==0 else "lanedusk_sky"),"scene sky")
		check(tagged(level,"festival_land")[0].key==("lane_land" if scene==0 else "lanedusk_land"),"scene land")
		check(tagged(level,"festival_far").size()>0 and tagged(level,"festival_ground").size()>0,"road hedge far layers")
		var tr: Dictionary=tagged(level,"hayride_trailer")[0]
		check(is_equal_approx(tr.rect.size.x,480/0.858),"deck width to painted 0.858 span")
		check(is_equal_approx(tr.rect.size.y,tr.rect.size.x*180/560),"authoritative dims")
		check(tr.rect.position.x==1060.25,"live deck snapped relative camera")
		all.append_array(sky); all.append_array(level)
	for row in h.level.decor:
		h.camera.x=float(row[1])-300
		var decor: Array=tagged(renderer.build_level(h,rt),"festival_decor")
		check(decor.any(func(c):return c.key=="cut_oak" and c.flip_h==(int(row[3])==1)),"alternating oak cutout")
	h.camera=Vector2(1000.25,0.25)
	var front: Array=renderer.build_front(h,rt)
	check(tagged(front,"hayride_harvester")[0].brightness==1.8,"harvester flash brightness")
	check(tagged(front,"hayride_harvester")[0].alpha==0.7,"harvester flash opacity")
	var departed: Dictionary=tagged(front,"hayride_departing_drone")[0]
	check(is_equal_approx(departed.transform.get_origin().y,29.25),"detached ballistic age seconds")
	check(is_equal_approx(departed.source.size.y,h.images.cut_drone.get_height()*0.6),"drone parcel removed")
	all.append_array(front)
	var bot: Dictionary={"p":Vector2(1400,327),"face":1,"state":"walk","t":0.22,"carry":true,"fly":false,"type":"flat","flash":0.1,"stride":27,"visual_move":1}
	var bot_before:=var_to_str(bot)
	var carry: Array=renderer.build_enemy(h,bot)
	check(tagged(carry,"festival_bot_shadow").is_empty(),"carrier no shadow")
	check(tagged(carry,"hayride_carrier")[0].flip_h,"carrier faces right by mirroring")
	check(tagged(carry,"hayride_carried_robot")[0].frame==1,"hanging walk frame")
	check(tagged(carry,"festival_flat_marker").size()==1,"flat marker remains with drone")
	check(var_to_str(bot)==bot_before,"build carrier pure")
	all.append_array(carry)
	bot.state="throw"
	check(tagged(renderer.build_enemy(h,bot),"hayride_carried_robot")[0].frame==2,"throw clock")
	bot.carry=false; bot.fly=true; bot.state="walk"
	var fly: Array=renderer.build_enemy(h,bot)
	check(tagged(fly,"hayride_flying_drone")[0].brightness==2,"fly flash")
	check(tagged(fly,"festival_bot_shadow").size()==1,"fly shadow preserved")
	all.append_array(fly)
	bot.state="pop"; bot.gone=1.05
	var pop: Array=renderer.build_enemy(h,bot)
	check(tagged(pop,"hayride_flying_drone").is_empty(),"pop uses robot art")
	check(tagged(pop,"hayride_rotor").size()==1,"pop retains rotor")
	check(is_equal_approx(tagged(pop,"festival_bot")[0].alpha,0.5),"pop fade")
	all.append_array(pop)
	bot.fly=false; bot.state="walk"; bot.flash=0
	check(tagged(renderer.build_enemy(h,bot),"festival_bot")[0].frame==3,"stride snapshot")
	bot.rise=0.4
	var rise: Dictionary=tagged(renderer.build_enemy(h,bot),"festival_bot")[0]
	check(rise.rect.end.y<=329.25,"rise clip at source ground plus two")
	h.player=Vector2(1200,402)
	check(renderer.build_player_back(h)[0].center.y==400.25,"live player deck shadow")
	check(not renderer.build_player_front(h).is_empty(),"player tag wrapper")
	all.append_array(renderer.build_player_back(h)); all.append_array(renderer.build_player_front(h))
	var hud: Array=renderer.build_hud(h,rt)
	check(tagged(hud,"hayride_health")[0].rect.size.x==210,"half health")
	rt.stage_data.harvester.hp=0.1
	check(tagged(renderer.build_hud(h,rt),"hayride_health")[0].rect.size.x==8,"minimum health width")
	rt.stage_data.harvester.hp=0; rt.stage_data.harvester.dead=true
	check(tagged(renderer.build_hud(h,rt),"hayride_health").is_empty(),"dead health hidden")
	check(tagged(renderer.build_front(h,rt),"hayride_harvester").size()==1,"dead body remains while retreating")
	rt.wiping=true; rt.wipe_kind="fade"; rt.wipe_elapsed=0.5; rt.wipe_label="Later that evening"
	check(tagged(renderer.build_hud(h,rt),"wipe_cover").size()==1,"dusk full viewport fade")
	check(tagged(renderer.build_hud(h,rt),"wipe_iris").is_empty(),"fade not iris")
	all.append_array(renderer.build_hud(h,rt))
	all.append_array(hud)
	for row in h.level.receipts:
		h.camera.x=row[0]-300
		var finds: Array=renderer.build_mid(h,rt)
		check(not finds.is_empty(),"receipt source art")
		all.append_array(finds)
	h.camera.x=13000
	check(not tagged(renderer.build_level(h,rt),"festival_checkpoint_pole").is_empty(),"checkpoint source art")
	var snapshot:=var_to_str(rt)
	renderer.build_level(h,rt); renderer.build_front(h,rt); renderer.build_hud(h,rt)
	check(var_to_str(rt)==snapshot,"runtime read only")
	var node:=DrawNode.new(); node.painter=renderer; node.host=h; node.commands=all
	root.add_child(node)
	await process_frame; await process_frame
	check(node.calls>0,"actual CanvasItem draw callback")
	node.queue_free(); await process_frame
	renderer.clear_cache(); all.clear(); h.images.clear(); h.sheets.clear()
	print("Hayride renderer: %d checks, %d failures"%[count,failures.size()])
	quit(0 if failures.is_empty() else 1)
