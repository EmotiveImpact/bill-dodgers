extends SceneTree
## Actual main loads and bounded input frames, not full route acceptance.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("FAIL: ",label)
func run() -> void:
	var game=load("res://main.tscn").instantiate(); root.add_child(game)
	game.set_physics_process(false);preload("res://tests/test_support.gd").silence(game)
	for mode in ["p2","cpu"]:
		for world in [2,3]:
			for stage in ["1","2","3","4","5","6","S"]:
				var id:="%d-%s"%[world,stage]
				game._show_menu();game.character="jp";game.save={"schema":1,"receipts":{},"skills":[]}
				check(game.configure_party(mode,"ama"),id+" configure")
				check(game.load_level(id),id+" load")
				check(game.party_session.active and game.party_session.runtime.actors.size()==2,id+" active actual pair")
				check(game.combat.participant_count==2,id+" real wave scaling")
				var metadata:=JSON.stringify(game.meta)
				var initial_age:float=game.receipts[0].age
				for i in 10:game.party_session.step(game,1.0/60,{"right":true,"shoot":true},{"left":true,"shoot":true})
				check(absf(game.elapsed-10.0/60)<.0001,id+" world clock once")
				check(game.mode=="play" and JSON.stringify(game.meta)==metadata,id+" no false clear or imported mutation")
				check(game.party_session.runtime.actors.all(func(a):return a.player.is_finite()),id+" both positions finite")
				if world==2:check(absf(game.receipts[0].age-initial_age-10.0/60)<.0001,id+" shared receipt timer once")
				if id=="2-6":
					check(game.world_two.checkout.players.size()==2 and game.world_two.checkout.players.has(0) and game.world_two.checkout.players.has(1),"Checkout fresh slot identities after prior stage")
	game.queue_free();await process_frame
	print("Party family loading: %d checks, %d failures (bounded28 load/frame fixtures)"%[checks,failures]);quit(0 if failures==0 else 1)
