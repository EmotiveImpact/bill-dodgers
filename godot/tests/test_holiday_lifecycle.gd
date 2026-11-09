extends SceneTree
## Actual-main lifecycle fixtures, distinct from input-only progression tests.
## The six-character repaired receipt routes use left input only and no assists.
const Store=preload("res://src/save_store.gd")
const DT:=1.0/60.0
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func walk_for_receipt(game)->int:
	var ticks:=0
	while ticks<150 and not game.receipts[0].taken:
		game.step(DT,{"left":true})
		check(game.camera.x==0 and game.player.x>=30,"leftwalk retains source camera/clamp")
		ticks+=1
	return ticks
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	for character in game.CHARACTERS:
		game.character=character
		game.save={"schema":1,"receipts":{},"skills":[],"kitty":0}
		check(Store.write_save(game.save)==OK,character+" fresh isolated save")
		check(game.load_level("4-2"),character+" first load")
		check(game.player==Vector2(300,482),character+" source spawn")
		check(game.level.receipts[0][0]==-300 and game.receipts[0].position==Vector2(60,482),character+" imported source vs named repair")
		var other_positions:Array=[game.receipts[1].position,game.receipts[2].position]
		var ticks:=walk_for_receipt(game)
		check(game.receipts[0].taken and game.player.x<102,character+" left input physically picks receipt")
		check(game.score==5 and game.receipt_score==5 and game.score-game.receipt_score==0,character+" 5 kitty zero personal coins")
		check(game.hearts==3 and game.invincible==0,character+" unassisted safe leftwalk")
		check(Store.read_save().receipts["4-2"]==[0],character+" saves native receipt identity0")
		for frame in 30:game.step(DT,{})
		check(game.score==5 and Store.read_save().receipts["4-2"]==[0],character+" one reward per run")
		# A death/Continue fixture does not reload or duplicate the physical find.
		game.hearts=0;game._game_over()
		var before:Vector2=game.player
		game._continue_level()
		check(game.mode=="play" and game.player==before and game.receipts[0].taken and game.score==5,character+" Continue retains current receipt/run")
		game.save=Store.read_save();check(game.load_level("4-2"),character+" replay load")
		check(not game.receipts[0].taken and game.receipts[0].previously_collected and game.receipts.size()==3,character+" replay physical pickup restored with history")
		check([game.receipts[1].position,game.receipts[2].position]==other_positions,character+" later receipts unchanged")
		walk_for_receipt(game)
		check(game.score==5 and game.receipt_score==5 and Store.read_save().receipts["4-2"]==[0],character+" replay reward repeats but save history deduplicates")
		print("Holiday repaired receipt input [",character,"]: ticks=",ticks," no assists; replay/Continue persistence verified")
	# Explicit far-camera transition fixtures. These are not route evidence.
	for previous in ["3-1","4-1"]:
		check(game.load_level(previous),previous+" transition source load")
		game.camera=Vector2(18000,-1200)
		check(game.load_level("4-5"),"pedalo transition load")
		check(game.camera==Vector2.ZERO and game.player==Vector2(330,482),previous+" pedalo starts independent stale camera")
		check(game.world_four.deck.row==[210.0,659.0,482.0],previous+" deck geometry before floor lookup")
		game.camera=Vector2(18000,-1200)
		check(game.load_level("4-S"),"bonus transition load")
		check(game.coins.size()==258 and game.coins.all(func(c):return c.keep and c.age==0.4),previous+" post-reset seeds all258 kept coins")
		check(game.world_four.dash.left==100 and game.world_four.dash.mult==1,"bonus resets timer multiplier")
	# Pause/focus loss freezes both hold/bonus clocks and pending wipe callback.
	for id in ["4-3","4-S"]:
		game.load_level(id)
		var rt=game.world_four
		if id=="4-3":rt.hold.on=true
		var state:String=var_to_str(rt.snapshot())
		game._pause();game.step(20,{"right":true})
		check(game.mode=="paused" and var_to_str(rt.snapshot())==state,id+" pause freezes runtime")
		game._resume();game.step(DT,{})
		check(game.mode=="play" and var_to_str(rt.snapshot())!=state,id+" resume advances runtime")
	game.load_level("4-1")
	game.world_four._start_gate(game,game.world_four.gates[0])
	game.step(0.5,{})
	var wipe_time:float=game.world_four.wipe_elapsed
	game._pause();game.step(4,{})
	check(game.world_four.wipe_elapsed==wipe_time and not game.world_four.gates[0].passed,"pause cannot fire gate callback")
	game.load_level("4-5")
	game.world_four.finish_frame(game)
	check(not game.world_four.wiping and game.player==Vector2(330,482),"old wipe cannot relocate a newly loaded stage")
	game.queue_free();await process_frame
	print("Holiday lifecycle: %d checks, %d failures; named fixtures are not full-route/device evidence."%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
