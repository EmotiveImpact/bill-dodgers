extends SceneTree
## Explicit two-actor rendering fixtures. Hidden bounded1-1 integration, not
## enabled co-op UI, a completed route or a physical-device acceptance claim.
const Support=preload("res://tests/test_support.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	if DisplayServer.get_name()=="headless":printerr("Actual renderer required");quit(1);return
	root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(960,540);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var args:=OS.get_cmdline_user_args();var output:=args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://../visual-captures")
	DirAccess.make_dir_recursive_absolute(output)
	var game=load("res://src/main.gd").new();root.add_child(game);await process_frame;Support.silence(game);game.set_physics_process(false)
	for mode in ["p2","cpu"]:
		game._show_menu();game.character="jp";game.configure_party(mode,"maya");game.load_level("1-1",false)
		var first=game.party_session.runtime.actors[0];var second=game.party_session.runtime.actors[1]
		first.player=Vector2(220,482);second.player=Vector2(420,482);second.face=-1
		first.coins=7;first.hearts=2;first.power="split";first.power_time=4.2;first.abilities.meter=.25
		second.coins=12;second.hearts=1;second.power="debit";second.power_time=6.1;second.abilities.meter=1 if mode=="cpu" else .75
		game.score=24;game.receipt_score=5;first.apply_native(game)
		game.player_hud.notifications.reset();game._layout_game_hud()
		game.status="Bounded native1-1 %s HUD fixture: separate hearts, coins, weapons and special charge"%mode;game.status_label.text=game.status
		game.queue_redraw();game.player_hud.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
		var result:=root.get_texture().get_image().save_png(output.path_join("native-party-hud-%s-fixture.png"%mode))
		if result!=OK:printerr("Capture failed");quit(1);return
	print("Native paired HUD captures saved: ",output)
	game.queue_free();await process_frame;quit(0)
