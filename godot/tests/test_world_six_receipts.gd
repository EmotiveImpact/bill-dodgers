extends SceneTree
## Four authored void receipts: geometry proof and actual-input local pickup.
## These are local doorway-arrival fixtures, NOT whole-stage completion routes.
const SaveStore = preload("res://src/save_store.gd")
const REPAIRS := [
	["6-1",2,Vector2(8090,-988),Vector2(8440,412),8300.0],
	["6-2",1,Vector2(6530,-988),Vector2(6880,412),6740.0],
	["6-2",2,Vector2(9830,-988),Vector2(10180,412),10040.0],
	["6-3",1,Vector2(7820,-988),Vector2(8180,412),8040.0],
]
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var g=load("res://main.tscn").instantiate();root.add_child(g);g.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(g)
	for row in REPAIRS:
		for character in g.CHARACTERS:
			var label:String=row[0]+" receipt "+str(row[1])+"/"+character
			g.character=character;g.save={"schema":1,"receipts":{},"skills":[],"kitty":0};SaveStore.write_save(g.save)
			check(g.load_level(row[0]),label+" loads")
			var source:String=JSON.stringify(g.meta)
			var raw:Array=g.level.receipts[row[1]]
			check(Vector2(raw[0],raw[1])==row[2],label+" retains authored void coordinate")
			check(g.receipts[row[1]].position==row[3],label+" repair load hook")
			check(g.world_six.inside_wall(g,Vector2(row[2].x,482)),label+" original lies over 1400px void wall")
			check(not g.world_six.inside_wall(g,Vector2(row[3].x,481)),label+" repaired route not inside solid")
			check(g.floor_at(row[3].x,400)==482,label+" actual grounded floor")
			place_at_door_arrival(g,row[4])
			for frame in range(24):g.step(1.0/60,{"right":true})
			check(g.receipts[row[1]].taken,label+" ordinary right input collects")
			check(g.score==0 and g.receipt_score==0,label+" zero reward")
			check(SaveStore.read_save().receipts[row[0]]==[row[1]],label+" exact zero-based persisted identity")
			check(JSON.stringify(g.meta)==source,label+" imported META immutable")
			g.load_level(row[0])
			check(g.receipts[row[1]].previously_collected and not g.receipts[row[1]].taken,label+" replay ghost")
			check(g.receipts[row[1]].position==row[3],label+" replay anchor stable")
			place_at_door_arrival(g,row[4])
			for frame in range(24):g.step(1.0/60,{"right":true})
			check(g.receipts[row[1]].taken and SaveStore.read_save().receipts[row[0]]==[row[1]],label+" replay collectible but no duplicate save")
			check(g.score==0 and g.receipt_score==0,label+" replay zero reward")
	g.queue_free();await process_frame;await process_frame
	print("World 6 receipt repairs: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
func place_at_door_arrival(g,to:float)->void:
	# Same player/camera placement as source door callback, with no collectible writes.
	g.player=Vector2(to+80,482);g.camera=Vector2(to-60,0);g.velocity=Vector2.ZERO
	g.grounded=true;g.on_platform=false;g.invincible=999;g.coins.clear()
