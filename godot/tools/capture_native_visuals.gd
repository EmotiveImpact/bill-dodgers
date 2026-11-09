extends SceneTree
## Run with a real desktop rendering backend, never --headless. These labelled
## snapshots exercise production draw paths with explicit deterministic fixtures.
const Support = preload("res://tests/test_support.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": printerr("Real rendering backend required");quit(1);return
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(960,540);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var args:=OS.get_cmdline_user_args()
	var output:=args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://../visual-captures")
	DirAccess.make_dir_recursive_absolute(output)
	var game=load("res://src/main.gd").new();root.add_child(game);await process_frame
	Support.silence(game);game.set_physics_process(false)
	for who in ["jp","maya","ama","leo","theo","mei"]:
		game.character=who;game.load_level("1-1",false)
		game.status="Native render fixture: %s · health, power, coins, pickup timer"%who
		game.status_label.text=game.status
		game.hearts=2;game.score=65;game.receipt_score=5;game.power="split";game.power_time=6.2
		game.abilities.reset(who);game.abilities.active=who;game.abilities.duration=4;game.abilities.remaining=2;game.abilities._time=1.2
		game.player_animation="run";game.velocity=Vector2(160,-120);game.face=1
		game.bullets=[];game.enemies=[]
		for i in 4:game.bullets.append({"p":Vector2(300+i*95,260),"v":Vector2(780,-120),"kind":who,"age":0.07*i,"life":20.0,"enemy":false})
		if who=="jp":
			for i in 4:game.bullets.append({"p":Vector2(340+i*100,210+i*35),"v":Vector2(0,800),"kind":"rain","age":0.04*i,"life":4.6,"enemy":false,"ab_rain":true})
		if who=="ama":
			game.combat.spawn(game,"r","flat");game.enemies[0].p=Vector2(450,380);game.enemies[0].ab_bubble=2.0;game.enemies[0].ab_bubble_total=4.0
		if who=="theo":game.abilities.effects=[{"kind":"ball","p":Vector2(420,350),"age":1.2,"life":3.6,"spin":1.7,"trail":[Vector2(350,375),Vector2(365,367),Vector2(380,360),Vector2(395,355)]}]
		game.queue_redraw();game.player_hud.queue_redraw()
		await process_frame;await RenderingServer.frame_post_draw
		var result:=root.get_texture().get_image().save_png(output.path_join("native-hud-vfx-%s.png"%who))
		if result!=OK:printerr("Capture failed",result);quit(1);return
	game.character="jp";game.load_level("1-1",false);game.start_boss();game.boss.state.hp=35;game.boss.state.dizzy=0
	game.status="Native render fixture: Jar Thief boss health and classic controls";game.status_label.text=game.status
	game.queue_redraw();game.player_hud.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("native-boss-hud.png"))
	game.character="jp";game.load_level("1-1",false);game.abilities.meter=1
	for style in ["classic", "joystick"]:
		game.touch_control_style=style
		game.status="Native running control preview: %s · provisional comparison"%style;game.status_label.text=game.status
		game.queue_redraw();game.player_hud.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("native-controls-%s.png"%style))
	game._touch(71,game.dpad_rect.get_center()+Vector2(48,-26));game._touch(72,game.buttons.shoot.get_center())
	game.status="Native joystick input fixture: move + aim + shoot together";game.status_label.text=game.status
	game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("native-controls-joystick-held.png"))
	game._release_input();game.touch_control_style="classic"
	game.hud_banner("Warning!","The jar thief is here",true);game.player_hud.notifications.step(.6)
	game.status="Native render fixture: original warning banner";game.status_label.text=game.status
	game.queue_redraw();game.player_hud.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("native-hud-warning.png"))
	game.player_hud.notifications.reset();game.hud_go();game.player_hud.notifications.step(.2)
	game.status="Native render fixture: original Go prompt";game.status_label.text=game.status
	game.queue_redraw();game.player_hud.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("native-hud-go.png"))
	game._show_menu();game.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("native-menu.png"))
	# Synthetic completion fixture, never written to the player's save.
	game.save.schema=1;game.save.cleared={}
	for world in range(1,7):
		for stage in range(1,7): game.save.cleared["%d-%d"%[world,stage]]=true
	game.mode="menu"
	if not game._show_credits():printerr("Synthetic credits fixture refused");quit(1);return
	game.credits_roll.set_process(false);game.credits_roll.tick(game.credits_roll.duration*.34)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("native-credits-midpoint-fixture.png"))
	print("Native rendered capture set saved: ",output)
	game.queue_free();await process_frame;quit(0)
