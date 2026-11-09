extends SceneTree
## Source two-actor HUD fixtures, not complete co-op/device acceptance.
const HUD=preload("res://src/player_hud.gd")
const Menu=preload("res://src/mobile_game_menu.gd")
const Support=preload("res://tests/test_support.gd")
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL: ",label)
func tagged(commands:Array,tag:String)->Array:return commands.filter(func(c):return c.tag==tag)
func snapshot(session)->String:
	var state:Array=[]
	for actor in session.runtime.actors:state.append([actor.character,actor.hearts,actor.coins,actor.power,actor.power_time,actor.abilities.meter,actor.abilities.remaining,actor.player,actor.down,actor.cpu])
	return var_to_str(state)
func run()->void:
	var source:=FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../game/1-1/index.html"))
	for snippet in ["px = right ? VW - 12 - 54 : 12", "tx = right ? px - 10 : px + 64", "p.cpu ? 'CPU '", "p.slot === 0 ? '#f4c542' : '#ff8fc7'", "tx - 24 - i * 26", "right ? tx - 100 : tx + 92", "txt('x' + p.coins", "right ? tx - 170 : tx + 160", "VW - 76 - w", "i === 0 ? x : x + w - fw", "p.cpu ? 'READY'", "p.slot === 0 ? 'C' : 'R'"]:
		check(source.contains(snippet),"original pair HUD: "+snippet)
	var game=load("res://src/main.gd").new();root.add_child(game);await process_frame;Support.silence(game);game.set_physics_process(false)
	game.character="jp";check(game.configure_party("p2","maya"),"explicit pair fixture configured")
	game.load_level("1-1",false);game.safe_padding=Vector2(12,14);game._layout_game_hud()
	var session=game.party_session;var first=session.runtime.actors[0];var second=session.runtime.actors[1]
	first.coins=7;first.hearts=1;first.power="split";first.power_time=4.2;first.abilities.meter=.25
	second.coins=12;second.hearts=2;second.power="debit";second.power_time=6.1;second.abilities.meter=.75
	game.score=24;game.receipt_score=5
	var before:=snapshot(session);var commands:Array=game.player_hud.build_commands(game)
	check(tagged(commands,"portrait").size()==1 and tagged(commands,"p2_portrait").size()==1,"two separate portraits")
	check(tagged(commands,"p2_portrait")[0].rect==Rect2(896,8,50,50) and tagged(commands,"p2_portrait")[0].source==Rect2(41,17,49,49),"source right Maya crop and position")
	check(tagged(commands,"player_name")[0].text=="P1 Jean Phil" and tagged(commands,"p2_player_name")[0].text=="P2 Maya","source player slot labels")
	var name:Dictionary=tagged(commands,"p2_player_name")[0]
	check(name.position==Vector2(884,18) and name.right and name.colour==Color("ff8fc7"),"P2 name right aligned and pink")
	check(tagged(commands,"player_coins")[0].text=="x7" and tagged(commands,"p2_player_coins")[0].text=="x12","personal actor coins never shared Kitty minus receipts")
	check(tagged(commands,"kitty_label")[0].text=="Kitty £24","one shared Kitty")
	check(tagged(commands,"p2_player_coins")[0].position==Vector2(772,40) and tagged(commands,"p2_player_coins")[0].right,"source mirrored coin text anchor")
	check(tagged(commands,"heart_1").all(func(c):return c.colour==Color("3a4458")),"P1 runtime damage independent of native facade")
	check(tagged(commands,"p2_heart_1").any(func(c):return c.colour==Color("e23b3b")) and tagged(commands,"p2_heart_2").all(func(c):return c.colour==Color("3a4458")),"P2 own hearts")
	check(tagged(commands,"p2_heart_0")[0].rect.position.x>tagged(commands,"p2_heart_1")[0].rect.position.x,"P2 hearts count from portrait right to left")
	check(tagged(commands,"weapon_countdown")[0].text=="x3 5" and tagged(commands,"p2_weapon_countdown")[0].text=="DD 7","separate power countdowns")
	check(tagged(commands,"p2_weapon_countdown")[0].position==Vector2(714,40) and tagged(commands,"p2_weapon_countdown")[0].right,"source P2 weapon anchor")
	check(tagged(commands,"special_fill")[0].rect==Rect2(76,54,38,8),"P1 own charge grows from left")
	check(tagged(commands,"p2_special_fill")[0].rect==Rect2(771,54,113,8),"P2 charge grows from right edge")
	check(snapshot(session)==before,"pair drawing mutates no actor state")
	second.abilities.meter=1;commands=game.player_hud.build_commands(game)
	check(tagged(commands,"p2_special_label")[0].text in ["R","TAP"] and tagged(commands,"p2_special_label")[0].right,"P2 ready uses source R or touch label")
	second.cpu=true;commands=game.player_hud.build_commands(game)
	check(tagged(commands,"p2_player_name")[0].text=="CPU Maya" and tagged(commands,"p2_special_label")[0].text=="READY","CPU identity and READY independent from human controls")
	second.abilities.active="maya";second.abilities.duration=6;second.abilities.remaining=2
	commands=game.player_hud.build_commands(game)
	check(tagged(commands,"p2_special_fill")[0].rect==Rect2(834,54,50,8) and tagged(commands,"p2_special_label")[0].text=="FLOWER","P2 active remaining timer and ability name")
	first.abilities.active="jp";first.abilities.duration=1.8;first.abilities.remaining=1.6
	second.abilities.remaining=5.9;commands=game.player_hud.build_commands(game)
	check(tagged(commands,"special_flash").size()==1 and tagged(commands,"special_flash")[0].colour.is_equal_approx(Color(Color("ff8fc7"),.16*(1-.1/.26))),"single global flash uses newest actor activation")
	for control in game.hud_controls:
		check(control.position.y>=78 and control.size.y>=44 and control.position.x>=game.safe_padding.x and control.get_rect().end.x<=960-game.safe_padding.x,"pair native controls below authored HUD and safe")
	check(game.status_label.position==Vector2(12,132),"pair status clear of native control row")
	for viewport in [Vector2(960,540),Vector2(1280,720)]:
		for safe in [Vector2(12,14),Vector2(44,20)]:
			var boxes:=HUD.layout(viewport,safe,true)
			var menu:=Menu.layout(viewport,safe)
			check(boxes.right_portrait.end.x<=viewport.x-safe.x and menu.launcher.end.x<=viewport.x-safe.x,"pair right-safe area")
			check(not menu.launcher.intersects(boxes.right_portrait) and menu.launcher.position.y>69,"menu never covers source P2 panel")
	var draw_count:int=game.player_hud.draw_count;game.player_hud.queue_redraw();await process_frame;await process_frame
	check(game.player_hud.draw_count>draw_count,"actual paired HUD CanvasItem draws")
	game._pause();check(game.player_hud.is_game_visible(game),"pair remains visible frozen below pause");game._resume()
	game._show_menu();game.configure_party("solo");game.load_level("1-1",false);game.safe_padding=Vector2(12,14);game._layout_game_hud()
	commands=game.player_hud.build_commands(game)
	check(not HUD.has_pair(game) and tagged(commands,"p2_portrait").is_empty(),"solo never shows stale pair")
	check(game.hud_controls.size()==1,"solo has one mobile menu launcher")
	for control in game.hud_controls:check(control.position.y>=78,"solo menu also leaves authored HUD untouched")
	check(game.status_label.position==Vector2(12,132),"solo status clear of menu")
	game._show_menu();game.configure_party("cpu","ama");game.load_level("6-1",false)
	check(HUD.has_pair(game) and tagged(game.player_hud.build_commands(game),"p2_portrait").size()==1,"Final adapted world renders the real pair HUD")
	game.level_id="future-preview";game.party_session.start(game)
	check(not HUD.has_pair(game) and tagged(game.player_hud.build_commands(game),"p2_portrait").is_empty(),"Unknown future content never advertises pair HUD")
	game.mode="menu"
	game.queue_free();await process_frame
	if failures.is_empty():print("Party HUD: %d checks passed (bounded fixtures, not co-op/device acceptance)."%checks);quit(0)
	else:printerr("Party HUD failures: %d/%d"%[failures.size(),checks]);quit(1)
