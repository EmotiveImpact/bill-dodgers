extends SceneTree
## All 21 receipts x six characters, plus all-six Super pickup/use/persistence.
## Explicit authored-support/ride fixtures isolate physical collection. They are
## not a claim that the separate full-stage driver collects every optional item.
const SaveStore = preload("res://src/save_store.gd")
const DT := 1.0/60.0
const STAGES := ["6-1","6-2","6-3","6-4","6-5","6-6","6-S"]
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func _initialize() -> void: call_deferred("run")
func fresh_save(g) -> void:
	g.save={"schema":1,"receipts":{},"skills":[],"kitty":0}
	check(SaveStore.write_save(g.save)==OK,"isolated fresh save")
func run() -> void:
	var g=load("res://main.tscn").instantiate();root.add_child(g);g.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(g)
	for id in STAGES:
		for who in g.CHARACTERS:
			g.character=who;fresh_save(g)
			for index in range(3):
				var label:String="%s/%s receipt%d"%[id,who,index]
				check(g.load_level(id),label+" loads")
				var source:String=JSON.stringify(g.meta)
				var p:Vector2=g.receipts[index].position
				var raw:Array=g.level.receipts[index]
				var expected:Vector2=g.world_six.RECEIPT_REPAIRS.get(id,{}).get(index,Vector2(raw[0],raw[1]))
				check(p==expected,label+" exact original or approved repair anchor")
				check(not g.receipts[index].taken and not g.receipts[index].previously_collected,label+" initially untaken")
				check(place_on_source_support(g,p,label),label+" supported fixture")
				check(not g.world_six.finds_near(g,p),label+" begins outside pickup radius")
				approach(g,p,index,false)
				check(g.receipts[index].taken,label+" ordinary movement/jump pickup")
				check(g.score==0 and g.receipt_score==0,label+" source zero reward")
				check(SaveStore.read_save().receipts.get(id,[])==range(index+1),label+" source one-based identity saved zero-based")
				check(JSON.stringify(g.meta)==source,label+" immutable source metadata")
				check(g.world_six.floating.any(func(f):return f.text=="Secret receipt 1/3"),label+" actual-main collection float")
			check(SaveStore.read_save().receipts[id]==[0,1,2],id+"/"+who+" all three identities persisted")
			for index in range(3):
				var label:String="%s/%s replay%d"%[id,who,index]
				g.load_level(id)
				check(g.receipts.all(func(r):return r.previously_collected and not r.taken),label+" all original ghosts reset per run")
				var p:Vector2=g.receipts[index].position
				check(place_on_source_support(g,p,label),label+" actual support")
				approach(g,p,index,false)
				check(g.receipts[index].taken,label+" physical replay pickup")
				check(SaveStore.read_save().receipts[id]==[0,1,2],label+" no duplicate saved identities")
				check(g.score==0 and g.receipt_score==0,label+" still no reward")
	for who in g.CHARACTERS:
		g.character=who;fresh_save(g)
		g.load_level("6-4")
		var p:=Vector2(g.level.card[0],g.level.card[1])
		var source:String=JSON.stringify(g.meta)
		check(not g.movement_skills.has_skill("super") and g.abilities.power()==1.0,who+" unearned Super absent")
		check(place_on_source_support(g,p,who+" Super"),who+" actual source card landing")
		approach(g,p,0,true)
		check(g.movement_skills.card_collected and g.movement_skills.has_skill("super"),who+" physical Super card pickup")
		check(g.abilities.skills==["super"] and g.abilities.power()==1.5,who+" source Super power applied")
		check(SaveStore.read_save().skills==["super"],who+" Super persisted")
		g.abilities.meter=1.0
		g.step(DT,{"special":true})
		check(g.abilities.active==who,who+" actual special input activates learned Super")
		check(absf(g.abilities.duration-float(g.abilities.SPEC[who].duration)*1.5)<0.00001,who+" source empowered duration")
		check(g.abilities.meter==0.0,who+" special consumes meter normally")
		check(JSON.stringify(g.meta)==source,who+" skill pickup/use keeps META immutable")
		g.load_level("6-4")
		check(g.movement_skills.has_skill("super") and g.abilities.power()==1.5,who+" earned power survives reload")
		check(not g.movement_skills.card_collected,who+" source card physical replay reset")
		place_on_source_support(g,p,who+" Super replay")
		approach(g,p,0,true)
		check(g.movement_skills.card_collected and SaveStore.read_save().skills==["super"],who+" replay card collectible without duplicate unlock")
	g.queue_free();await process_frame;await process_frame
	print("World 6 complete collectibles: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
func place_on_source_support(g,p:Vector2,label:String)->bool:
	# Fixture placement only, before controls. All support is real imported/live
	# geometry; no geometry, receipt, card, wave, timer or clear writes occur.
	g.camera=Vector2(maxf(0,p.x-300),0)
	if g.level.kind=="climb":g.camera.x=0
	if g.level.kind=="ride":g.world_six.camera_override(0,g)
	var s:Dictionary=g.world_six.below(g,p.x,p.y+1)
	if s.is_empty():printerr("FAIL: "+label+" has no authored support");return false
	var x:float=clampf(p.x-100,float(s.row[0])+20,float(s.row[1])-20)
	if p.x<150:x=p.x+100
	g.player=Vector2(x,s.row[2]);g.velocity=Vector2.ZERO
	g.camera.y=minf(0,g.player.y-float(g.meta.ground))
	g.grounded=true;g.on_platform=s.plat;g.invincible=999;g.jump_held=false
	g.coins.clear() # Isolate the source's zero-reward receipt/card bookkeeping.
	check(not g.world_six.inside_wall(g,g.player-Vector2(0,1)),label+" starts above a real solid/one-way deck")
	check(not g.world_six.surf_under(g.player.x,g.player.y).is_empty(),label+" support exists at starting x and feet")
	return true
func approach(g,p:Vector2,index:int,card:bool)->void:
	for frame in range(90):
		var dx:float=p.x-g.player.x
		g.invincible=999
		var jump:bool=g.level.kind=="ride" and frame==0
		g.step(DT,{"right":dx>3,"left":dx < -3,"jump":jump})
		if (g.movement_skills.card_collected if card else g.receipts[index].taken):return
