extends SceneTree
## Production rendering with deliberately triggered cosmetic event fixtures.
const Support=preload("res://tests/test_support.gd")
func _initialize()->void:call_deferred("run")
func snap(game,output:String,name:String)->void:
	game.queue_redraw();game.player_hud.queue_redraw()
	await process_frame;await RenderingServer.frame_post_draw
	var result:=root.get_texture().get_image().save_png(output.path_join(name))
	if result!=OK:printerr("Capture failed: ",name);quit(1)
func run()->void:
	if DisplayServer.get_name()=="headless":printerr("Actual rendering backend required");quit(1);return
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(960,540);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var args:=OS.get_cmdline_user_args();var output:=args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://../visual-captures")
	DirAccess.make_dir_recursive_absolute(output)
	var game=load("res://src/main.gd").new();root.add_child(game);await process_frame;Support.silence(game);game.set_physics_process(false)
	game.character="maya";game.load_level("1-1",false);game.player=Vector2(230,482);game.hearts=2
	game.abilities.meter=1;game.abilities._start(game)
	game.combat.hit_crate(game,{"p":Vector2(400,482),"hp":1,"broken":false,"hit":0.0,"give":"heart"},1)
	game.fx_puff(Vector2(540,350),Color.WHITE,4,200);game.fx_item(Vector2(400,400),"heart")
	game.visual_feedback.tick(.18);game.player_hud.notifications.reset()
	game.status="Native feedback fixture: flower burst, crate fragments, hit and pickup text";game.status_label.text=game.status
	await snap(game,output,"native-feedback-shared-fixture.png")
	game.character="jp";game.load_level("4-6",false);game.world_four.captain.start(game)
	var boss:Dictionary=game.world_four.captain.boss
	boss.x=game.level.w-330;boss.state="drift";boss.phase=3;boss.hp=24;boss.face=-1
	game.camera=Vector2(game.level.w-game.view_width(),0);game.player=Vector2(game.camera.x+180,482)
	game.holiday_event({"type":"hit","p":Vector2(boss.x+70,boss.y-120),"valve":true})
	game.holiday_event({"type":"text","p":Vector2(boss.x,152),"text":"Crew!"})
	game.visual_feedback.tick(.10);game.player_hud.notifications.reset()
	game.status="Native Captain fixture: phase-three valve hit (source reinforcement text lies behind HUD)";game.status_label.text=game.status
	await snap(game,output,"native-feedback-captain-fixture.png")
	# Shared source loot fixtures use real W1/W2 routing; time is held only
	# so the four rectangular coin spin frames can be compared in one image.
	for id in ["1-1","2-1"]:
		game.character="jp";game.load_level(id,false);game.player=Vector2(180,482)
		game.items=[];game.coins=[];game.crates=[{"p":Vector2(610,482),"broken":false,"hit":0.0}]
		var index:=0
		for give in ["heart","split","debit"]:
			game.items.append({"p":Vector2(310+index*100,370),"age":.15,"give":give});index+=1
		for phase in 4:game.coins.append({"p":Vector2(315+phase*64,425),"age":phase*.06})
		game.player_hud.notifications.reset()
		game.status="Native loot fixture %s: pixel heart, power badges, spinning coins and source crate"%id;game.status_label.text=game.status
		await snap(game,output,"native-loot-%s-fixture.png"%id)
	print("Native feedback captures saved: ",output)
	game.queue_free();await process_frame;quit(0)
