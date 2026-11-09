extends SceneTree
const Renderer = preload("res://src/shared_effects_renderer.gd")
const Support = preload("res://tests/test_support.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)
func tagged(commands: Array, tag: String) -> Array:
	return commands.filter(func(c): return c.tag == tag)
func run() -> void:
	var source := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../game/1-1/index.html"))
	for snippet in ["coinIcon(x, y, 1.4, t / 50)", "const a0 = t / 90", "Math.round(Math.sin(t / 90))", "g.lineTo(-9, -7)", "const yy = Math.round(y - Math.abs(Math.sin(t / 80)) * 6)", "coinIcon(x, y, 2.3, sh.t / 45)", "66 + Math.sin(AB.t / 200 + b.x) * 3", "football(fx.x - cam, fx.y, 22, fx.spin)", "a.ready && !sp", "g.scale(p.face * 5.6, 2.8)", "0.55, RAINBOW[i]"]:
		check(source.contains(snippet), "source visual contract: " + snippet)
	var game = load("res://src/main.gd").new()
	root.add_child(game); await process_frame
	Support.silence(game); game.set_physics_process(false); game.load_level("1-1", false)
	var painter = game.shared_effects_renderer
	game.camera = Vector2(0.25, 0.25)
	var shot := {"p": Vector2(300.6, 300.2), "v": Vector2(780, -300), "age": 0.137, "enemy": false, "life": 20.0, "kind": "jp"}
	var all: Array = []
	for who in Renderer.SHOTS:
		game.character = who; shot.kind = who
		var before := var_to_str(shot)
		var commands: Array = painter.build_shot(game, shot)
		check(not commands.is_empty(), "%s distinctive projectile commands" % who)
		check(before == var_to_str(shot), "%s projectile rendering does not mutate" % who)
		check(commands.any(func(c): return str(c.tag).begins_with("shot_" + Renderer.SHOTS[who])), "%s maps to source %s" % [who, Renderer.SHOTS[who]])
		all.append_array(commands)
	shot.kind = "jp"; shot.age = 0
	var commands: Array = painter.build_shot(game, shot)
	check(tagged(commands, "shot_coin")[0].rect == Rect2(292.25, 292.25, 17, 17), "coin rounds source screen coordinates before exact camera compensation")
	shot.age = 0.1
	check(tagged(painter.build_shot(game, shot), "shot_coin")[0].rect.size.x == 6, "coin thin spin frame")
	shot.kind = "maya"
	commands = painter.build_shot(game, shot)
	check(tagged(commands, "shot_flower_petal").size() == 5 and tagged(commands, "shot_flower_light").size() == 5, "Maya five rotating orange petals plus highlights")
	shot.kind = "ama"; shot.age = 0
	commands = painter.build_shot(game, shot)
	check(tagged(commands, "shot_bubble")[0].radius == 7 and tagged(commands, "shot_bubble")[0].colour.a < 0.36, "Ama transparent7px bubble not solid dot")
	check(tagged(commands, "shot_bubble_edge")[0].width == 2, "Ama outlined bubble")
	shot.kind = "leo"; shot.v = Vector2(780, 0)
	commands = painter.build_shot(game, shot)
	var right_points: PackedVector2Array = tagged(commands, "shot_plane")[0].points
	shot.v.x = -780
	commands = painter.build_shot(game, shot)
	var left_points: PackedVector2Array = tagged(commands, "shot_plane")[0].points
	check(right_points[0].x > right_points[1].x and left_points[0].x < left_points[1].x, "Leo plane flips with shot direction")
	check(tagged(commands, "shot_plane_fold").size() == 1 and tagged(commands, "shot_plane_edge")[0].width == 1, "Leo folded-paper shading and border")
	shot.kind = "theo"
	commands = painter.build_shot(game, shot)
	check(tagged(commands, "shot_ball_patch")[0].points.size() == 5 and tagged(commands, "shot_ball_spot").size() == 5, "Theo real football markings")
	shot.kind = "mei"
	commands = painter.build_shot(game, shot)
	check(tagged(commands, "shot_sweet_wrap").size() == 2 and tagged(commands, "shot_sweet_light").size() == 1, "Mei wrapper wings and shine")
	shot.ghost = true; check(painter.build_shot(game, shot).is_empty(), "invisible collision ghosts stay invisible"); shot.erase("ghost")
	shot.ab_rain = true; check(painter.build_shot(game, shot).is_empty(), "rain drawn only in ability layer"); shot.erase("ab_rain")
	check(is_equal_approx(Renderer.shot_age({"kind":"jp","life":19.8}),0.2), "W1 standard shot age from existing20-second life")
	check(is_equal_approx(Renderer.shot_age({"kind":"rain","life":4.8}),0.2), "W1 rain age from existing5-second life")
	check(Renderer.shot_age({"age":0.3,"life":20}) == 0.3, "source-order worlds use explicit age")
	var bill := {"p":Vector2(400,300),"v":Vector2(-300,0),"age":0.09,"enemy":true}
	commands = painter.build_bill(game, bill)
	check(commands.size() == 4 and commands[0].type == "polygon", "bill has four rotating printed layers")
	check(not is_equal_approx(commands[0].points[0].y, commands[0].points[1].y), "bill rotates on source90ms clock")
	bill.big = true
	commands = painter.build_bill(game, bill)
	check(commands[3].colour == Color("e8d9a8"), "large bill printed horizontal band")
	all.append_array(commands)
	game.character = "jp"; game.bullets = [{"p":Vector2(360,200),"v":Vector2(0,800),"kind":"rain","life":4.8,"ab_rain":true,"enemy":false}]
	commands = painter.build_fx(game)
	check(tagged(commands, "coin_rain")[0].rect.size.y == 28, "rain enlarged2.3-scale source coin")
	var trail: Dictionary = tagged(commands, "coin_rain_trail")[0]
	check(trail.points[2].y - trail.points[0].y == 60 and is_equal_approx(trail.colours[2].a, 0.85), "rain60px alpha gradient glint")
	all.append_array(commands)
	game.enemies = [{"p":Vector2(400,400),"hp":2,"state":"walk","ab_bubble":2.0}]
	commands = painter.build_fx(game)
	check(tagged(commands,"trapped_bubble").size()==1 and tagged(commands,"trapped_bubble_light")[0].width==4, "trapped enemy translucent shell and crescent")
	all.append_array(commands)
	game.enemies[0].ab_bubble=0.15
	check(tagged(painter.build_fx(game),"trapped_bubble").is_empty(),"trapped bubble expiry blink")
	game.enemies.clear()
	game.abilities.effects=[{"kind":"ball","p":Vector2(450,400),"age":0.5,"life":3.6,"spin":1.0,"trail":[Vector2(430,380),Vector2(440,390)]}]
	commands=painter.build_fx(game)
	check(tagged(commands,"ricochet_ball")[0].radius==22,"special football source radius22")
	check(tagged(commands,"ricochet_trail").size()==2 and tagged(commands,"ricochet_shadow").size()==1,"special ball source trail and nearby ground shadow")
	check(tagged(commands,"ricochet_spot").size()==5,"special ball five football patches")
	all.append_array(commands)
	game.bullets.clear();game.abilities.effects.clear()
	for who in Renderer.SHOTS:
		game.character=who; game.abilities.reset(who);game.abilities.meter=1
		commands=painter.build_aura(game,true,game.player)
		check(tagged(commands,"special_ready_aura").size()==1,"%s ready aura"%who)
		game.abilities.active=who;game.abilities.remaining=2;game.abilities.duration=4
		commands=painter.build_aura(game,true,game.player)
		check(tagged(commands,"special_ready_aura").is_empty(),"%s active suppresses ready aura"%who)
		all.append_array(commands)
		commands=painter.build_aura(game,false,game.player);all.append_array(commands)
		if who=="maya": check(tagged(commands,"shield_flower_center").size()==8,"Maya eight orbiting flowers")
		if who=="leo": check(tagged(commands,"glider").size()==1 and tagged(commands,"glider_string").size()==2,"Leo suspended original paper glider")
		if who=="mei":
			game.player_animation="run";game.face=1
			var right: Array=painter.build_aura(game,true,game.player)
			check(tagged(right,"sugar_rush_fade").size()==5,"Mei five rainbow speed gradients")
			game.face=-1
			var left: Array=painter.build_aura(game,true,game.player)
			check(tagged(right,"sugar_rush_fade")[0].points[0].x<game.player.x and tagged(left,"sugar_rush_fade")[0].points[0].x>game.player.x,"Mei trails face away from motion")
		game.abilities.reset(who)
		check(painter.build_aura(game,false,game.player).is_empty(),"%s reset has no stale previous special"%who)
	game.movement_skills.ground_pounding=true
	check(tagged(painter.build_aura(game,false,game.player),"ground_pound_streak").size()==3,"ground-pound source streaks")
	game.movement_skills.ground_pounding=false
	var state_before:=var_to_str([game.bullets,game.enemies,game.abilities.effects,game.abilities.remaining,game.abilities.rng.state,game.player])
	painter.build_fx(game);painter.build_aura(game,true,game.player);painter.build_aura(game,false,game.player)
	check(state_before==var_to_str([game.bullets,game.enemies,game.abilities.effects,game.abilities.remaining,game.abilities.rng.state,game.player]),"all effect builders preserve gameplay and RNG")
	var canvas:=DrawCommands.new();canvas.renderer=painter;canvas.commands=all;root.add_child(canvas)
	await process_frame;await process_frame
	check(canvas.calls>0,"all shape primitives submitted by real CanvasItem draw callback")
	# Real main draw path: no generic bullets or old shield/bubble double draws.
	game.load_level("1-1",false);game.character="maya";game.abilities.reset("maya");game.abilities.active="maya";game.abilities.remaining=4;game.abilities.duration=6
	game.bullets=[{"p":Vector2(400,300),"v":Vector2(780,0),"kind":"maya","life":20.0,"enemy":false}]
	var old_submitted: int=painter.submitted
	game.queue_redraw();await process_frame;await process_frame
	check(painter.submitted>old_submitted,"real main draws shared projectile + actor aura")
	var main_source:=FileAccess.get_file_as_string("res://src/main.gd")
	check(main_source.contains("_draw_world_objects()\n\t\t_draw_boss()\n\t\t_draw_enemy_actors()\n\t\t_draw_player_actor()"),"W1 source boss/enemies-before-player ordering")
	game.queue_free();canvas.queue_free();await process_frame
	if failures.is_empty():print("Shared visual effects: %d checks passed."%checks);quit(0)
	else:printerr("Shared visual effects failed: %d/%d"%[failures.size(),checks]);quit(1)
class DrawCommands extends Node2D:
	var renderer
	var commands:Array=[]
	var calls:=0
	func _draw():renderer.draw_commands(self,commands);calls+=1
