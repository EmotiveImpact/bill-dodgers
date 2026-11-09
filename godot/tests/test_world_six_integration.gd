extends SceneTree
## Deliberate seam fixtures complement the separate unscripted-position full routes.
const SaveStore=preload("res://src/save_store.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
func near(a:float,b:float,label:String)->void:check(absf(a-b)<0.01,label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var g=load("res://main.tscn").instantiate();root.add_child(g);g.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(g)
	g.save={"schema":1,"receipts":{},"skills":[],"kitty":0}
	g.load_level("6-1")
	g.camera=Vector2(1900,0);g.player=Vector2(1999,420);g.velocity=Vector2.ZERO;g.grounded=true;g.on_platform=false;g.invincible=999
	g.step(0.1,{"right":true})
	near(g.player.x,2036,"old position belt carry retained stepping off edge")
	check(not g.grounded,"then walks off belt this frame")
	g.load_level("6-1")
	g.player=Vector2(70,482);g.coins.clear();g.invincible=999
	g.step(0.01,{})
	check(g.receipts[0].taken,"actual main W6 receipt half-height predicate")
	check(g.score==0 and g.receipt_score==0,"W6 receipts not free pounds")
	check(0 in SaveStore.read_save().receipts["6-1"] and 1 not in SaveStore.read_save().receipts["6-1"],"one-based source converted to zero-based save")
	g.load_level("6-1")
	check(g.receipts[0].previously_collected and not g.receipts[0].taken,"receipt replay ghost but collectible again")
	var time:float=g.world_six.level_time
	var world_time:float=g.world_six.world_time
	g._pause();g.step(10,{"right":true})
	near(g.world_six.level_time,time,"pause freezes level clock")
	near(g.world_six.world_time,world_time,"pause freezes world clock")
	g._resume();g.step(0.1,{})
	check(g.world_six.level_time>time,"resume world clock")
	g.mode="story";world_time=g.world_six.world_time
	g.world_six.world_tick(1,g)
	near(g.world_six.world_time,world_time,"unrelated story callbacks not eligible")
	g.mode="clear";g.world_six.world_tick(1,g)
	near(g.world_six.world_time,world_time,"unrelated clear callbacks not eligible")
	g.load_level("6-5")
	g.camera=Vector2.ZERO;g.player=Vector2(649,482);g.grounded=true;g.velocity=Vector2.ZERO;g.invincible=999
	g.step(0.1,{"right":true})
	near(g.player.x,686,"cradle edge old-position carry plus walk")
	near(g.camera.x,10,"ride camera after carried player")
	near(g.world_six.ride.row[0],140,"live deck shifted with camera")
	g.load_level("6-4")
	g.player=Vector2(369,-5552);g.grounded=true;g.on_platform=true;g.camera.y=-5600;g.invincible=999
	g.step(0.01,{})
	check(g.movement_skills.has_skill("super") and "super" in g.abilities.skills,"super card updates movement and ability systems")
	check("super" in SaveStore.read_save().get("skills",[]),"super persisted")
	g.load_level("6-S")
	g.world_six.dash.left=0.001
	g.step(0.001,{})
	check(g.mode=="play" and g.world_six.end_time==0.001,"timeout happens after objective")
	g.world_six.end_time=2.599;g.hearts=0
	g.step(0.01,{})
	check(g.mode=="clear","source clear-before-all-down precedence")
	g.load_level("6-6")
	for wave in g.combat.waves:wave.done=true
	g.camera.x=g.level.w-g.view_width();g.player=Vector2(g.camera.x+150,482);g.invincible=999
	g.step(0.01,{})
	check(g.boss!=null and g.boss.state.hp==110,"production dispatch actual Sir Charge")
	g.boss.state.state="fight";g.boss.state.x=g.player.x+100;g.boss.state.yo=-180;g.boss.state.fy=302;g.boss.state.hp=70;g.boss.state.phase=2
	g.damage_boss(5)
	g.combat.projectiles_tick(0,g)
	check(g.boss.state.hp==69,"shared special targets finite actual boss feet and source hit scalar")
	for id in ["6-1","6-2","6-3","6-4","6-5","6-6","6-S"]:
		g.load_level(id)
		await process_frame
		await process_frame
		check(g.player.is_finite() and g.camera.is_finite(),id+" actual scene draws through all W6 painter layers")
	g.queue_free();await process_frame;await process_frame
	print("World 6 host seams: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
