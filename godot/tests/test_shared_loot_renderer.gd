extends SceneTree
const Loot=preload("res://src/shared_loot_renderer.gd")
const Support=preload("res://tests/test_support.gd")
var checks:=0
var failures:Array[String]=[]
class DrawNode extends Node2D:
	var font:Font=load("res://assets/fonts/silk.woff2")
	var commands:Array=[]
	var calls:=0
	func _draw()->void:Loot.draw_commands(self,commands);calls+=1
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL: ",label)
func tagged(cmd:Array,tag:String)->Array:return cmd.filter(func(c):return c.tag==tag)
func run()->void:
	for id in ["1-1","2-1"]:
		var source:=FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../game/"+id+"/index.html"))
		for snippet in ["heart(-14, -10, true, 4)","24 + Math.sin(it.t / 120) * 2","Math.sin(it.t / 150) * 3","it.t > 9000 && Math.floor(it.t / 120) % 2","rrect(-20, -20, 40, 40, 10","it.give === 'split' ? 'x3' : 'DD'","coinIcon(c.x - cam, c.y, 1.3, c.t / 60)","c.t > 9000 && Math.floor(c.t / 100) % 2", "fillRect(-34, 0, 68, 64)", "fillRect(-31, 3, 62, 58)", "fillRect(-31, 26, 62, 6)", "fillRect(-28, 6, 24, 4)", "fillRect(-14, 10, 28, 28)", "txtRaw('?', 0, 25, 22, '#2d6a4f')", "c.hitT > 0 ? (Math.random() - 0.5) * 4 : 0"]:
			check(source.contains(snippet),id+" source contract "+snippet)
	var camera:=Vector2(20.25,-31.6);var item:={"p":Vector2(320.5,400.25),"age":0.0,"give":"heart"}
	var before:=var_to_str(item);var commands:Array=Loot.build_item(item,camera);var hearts:=tagged(commands,"loot_heart")
	check(hearts.size()==27,"original27 pixel heart cells")
	check(hearts.all(func(c):return c.rect.size==Vector2(4,4)),"heart uses4px square cells")
	check(hearts.filter(func(c):return c.colour==Color("ffb3b3")).size()==1,"exactly one pink highlight")
	check(hearts.filter(func(c):return c.colour==Color("e23b3b")).size()==26,"red source heart body")
	check(hearts[0].rect.position==Vector2(310.25,390.4),"screen/world snapping respects fractional camera")
	check(commands[0].radius==24 and commands[0].colour==Color(1,1,1,.25),"source translucent white glow not opaque pink disc")
	check(tagged(commands,"loot_label").is_empty(),"heart has no plus text")
	check(before==var_to_str(item),"item builder never mutates state")
	item.age=.15;var moved:Array=Loot.build_item(item,camera)
	check(is_equal_approx(moved[0].center.y,403.4) and is_equal_approx(moved[0].radius,24+sin(1.25)*2),"source independent bob/glow clocks")
	var all:Array=commands+moved
	for give in ["split","debit"]:
		item.give=give;item.age=0;commands=Loot.build_item(item,camera);all.append_array(commands)
		var badge:Dictionary=tagged(commands,"loot_power")[0];var label:Dictionary=tagged(commands,"loot_label")[0]
		check(badge.rect.size==Vector2(40,40) and badge.radius==10 and badge.width==3,"source40px rounded3px outlined badge")
		check(badge.colour==Color("2d6a4f" if give=="split" else "14243b") and badge.stroke==Loot.GOLD,"source power colour")
		check(label.text==("x3" if give=="split" else "DD") and label.size==15,"source power label size and case")
	item.age=9;check(not Loot.build_item(item,camera).is_empty(),"exact9s still visible")
	item.age=9.01;check(Loot.build_item(item,camera).is_empty(),"item late120ms blink hidden")
	item.age=9.12;check(not Loot.build_item(item,camera).is_empty(),"item next blink visible")
	var coin:={"p":Vector2(320.5,400.25),"age":0.0};before=var_to_str(coin)
	for phase in 4:
		coin.age=phase*.06;commands=Loot.build_coin(coin,camera);all.append_array(commands)
		check(commands[1].rect.size==Vector2([16,12,5,12][phase],16),"coin four source spin widths")
		check(commands.size()==(2 if phase==2 else 4),"edge-on coin omits glint and center")
		check(commands[0].colour==Color("7a5410") and commands[1].colour==Loot.GOLD,"source coin palette")
	coin.age=9.11;check(Loot.build_coin(coin,camera).is_empty(),"coin100ms late blink hidden")
	coin.age=9.21;check(not Loot.build_coin(coin,camera).is_empty(),"coin100ms blink visible")
	coin.age=0.0;check(var_to_str(coin)==before,"coin state unchanged by building")
	var crate:={"p":Vector2(320.5,482.25),"broken":false,"hit":0.0}
	var crate_before:=var_to_str(crate);commands=Loot.build_crate(crate,camera,1.5);all.append_array(commands)
	var crate_rows:=tagged(commands,"loot_crate")
	check(crate_rows.size()==5,"source crate five layers")
	var expected:Array=[[Rect2(-34,0,68,64),"7a5226"],[Rect2(-31,3,62,58),"c48a4a"],[Rect2(-31,26,62,6),"a8743c"],[Rect2(-28,6,24,4),"e0b070"],[Rect2(-14,10,28,28),"f5f1ea"]]
	var crate_origin:=Vector2(320.25,418.65)
	for i in expected.size():
		check(crate_rows[i].rect.position.is_equal_approx(crate_origin+expected[i][0].position) and crate_rows[i].rect.size==expected[i][0].size,"source crate exact layer%d geometry"%i)
		check(crate_rows[i].colour==Color(expected[i][1]),"source crate layer%d colour"%i)
	var crate_label:Dictionary=tagged(commands,"loot_crate_label")[0]
	check(crate_label.text=="?" and crate_label.size==22 and crate_label.position.is_equal_approx(crate_origin+Vector2(0,25)),"source question mark centered in pale panel")
	check(var_to_str(crate)==crate_before,"crate rendering leaves state unchanged")
	check(Loot.crate_jitter(crate,1.5)==0,"unhit crate never jitters")
	crate.hit=.12;crate_before=var_to_str(crate);var first_jitter:=Loot.crate_jitter(crate,1.5)
	check(absf(first_jitter)<=2 and first_jitter==Loot.crate_jitter(crate,1.5),"read-only jitter matches source2px bound and stable frame")
	check(not is_equal_approx(first_jitter,Loot.crate_jitter(crate,1.52)),"active hit jitters on next visual frame")
	check(crate_before==var_to_str(crate),"cosmetic jitter never writes crate")
	crate.visual_jitter=1.25;check(Loot.crate_jitter(crate,2)==1.25,"explicit cosmetic snapshot supported")
	crate.broken=true;check(Loot.build_crate(crate,camera).is_empty(),"broken crate paints nothing")
	var node:=DrawNode.new();node.commands=all;root.add_child(node);await process_frame;await process_frame
	check(node.calls>0,"real CanvasItem draws hearts badges coins")
	node.queue_free();await process_frame
	var game=load("res://src/main.gd").new();root.add_child(game);await process_frame;Support.silence(game);game.set_physics_process(false)
	for id in ["1-1","2-1"]:
		game.load_level(id,false);game.items=[{"p":Vector2(330,390),"age":.2,"give":"heart"},{"p":Vector2(390,390),"age":.2,"give":"split"},{"p":Vector2(450,390),"age":.2,"give":"debit"}];game.coins=[{"p":Vector2(500,390),"age":.12}];game.crates=[{"p":Vector2(600,482),"broken":false,"hit":.12}]
		var state:=var_to_str([game.items,game.coins,game.crates,game.score,game.combat.rng.state]);game.queue_redraw();await process_frame;await process_frame
		check(state==var_to_str([game.items,game.coins,game.crates,game.score,game.combat.rng.state]),id+" actual main loot rendering leaves simulation/RNG untouched")
	game.queue_free();await process_frame
	if failures.is_empty():print("Shared loot renderer: %d checks passed."%checks);quit(0)
	else:printerr("Shared loot renderer failures: %d/%d"%[failures.size(),checks]);quit(1)
