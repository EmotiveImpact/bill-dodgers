extends SceneTree
## Real main/input progression. Invulnerability is the ONLY gameplay assist.
const SaveStore = preload("res://src/save_store.gd")
const DT := 1.0/60.0
const MAX_TICKS := 60000
const WAVE_AT := [400,1300,2500,3300,5650,6700,9700,10700,11662]
# Coordinates are feet. Dynamic trapezes use platform indices instead.
const ROUTE := [Vector2(1550,392),Vector2(1750,302),Vector2(1950,212),Vector2(2285,94),Vector2(2285,-24),Vector2(2285,-142),Vector2(2430,-218),Vector2(2800,-218),Vector2(3190,-158),Vector2(3500,-218),Vector2(3900,-218),Vector2(4085,-158),10,11,12,13,Vector2(5510,-226),Vector2(5700,-278),Vector2(6000,-278),Vector2(6590,-218),Vector2(7100,-278),Vector2(7900,-158),Vector2(8350,482),Vector2(9000,482),Vector2(9500,364),Vector2(9500,246),Vector2(9500,128),Vector2(9500,10),Vector2(9500,-108),Vector2(9500,-226),Vector2(9700,-338),Vector2(10580,-278),Vector2(11000,-338),Vector2(11580,-278),Vector2(12300,-378)]
var failures: Array[String] = []
var route_step := 0
var trace := false
var dwell := 0
var pound_started := false
var pound_landed := false
var pound_test := 0
var mover_landed: Array[int] = []
var mover_carried: Array[int] = []
var spot_activated := false

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok and label not in failures: failures.append(label)
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	if not game.has_method("step"):
		printerr("Big top main failed to load")
		game.free(); quit(1); return
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	var characters: Array = game.CHARACTERS
	for arg in OS.get_cmdline_user_args():
		if arg == "--trace": trace = true
		if arg.begins_with("--character="): characters = [arg.trim_prefix("--character=")]
	var passed := true
	for character in characters:
		if not run_character(game,character): passed = false
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
func run_character(game, character: String) -> bool:
	failures.clear(); route_step = 0; dwell = 0; pound_started = false; pound_landed = false; pound_test = 0
	mover_landed.clear(); mover_carried.clear(); spot_activated = false
	game.character = character
	game.save = {"schema":1,"receipts":{}}
	check(SaveStore.write_save(game.save) == OK,"fresh save failed")
	check(game.load_level("3-4"),"load failed")
	check(game.is_native_supported() and game._native_world_three(),"native gate not enabled; no bypass")
	if not failures.is_empty(): printerr(failures); return false
	check(game.movement_skills.skills.is_empty() and game.abilities.skills.is_empty(),"inherited skills")
	check(game.player == Vector2(300,482),"wrong spawn")
	check(game.world_three.surfaces(game).size() == 64,"wrong geometry count")
	var imported := JSON.stringify(game.meta)
	var planned := 0
	for i in range(game.combat.waves.size()):
		check(game.combat.waves[i].at == WAVE_AT[i],"wrong wave trigger")
		planned += game.combat.waves[i].group.size()
	check(planned == 31,"wrong solo entries")
	var pair_entries := 0
	for wave in game.meta.l3.waves: pair_entries += wave[1].size()
	check(pair_entries == 40,"wrong source pair entries")
	var seen: Array = []; var popped: Array = []; var retired: Array = []; var removed: Array = []
	var completed: Array = []; var receipts: Array = []
	var consumed := 0; var failed_spawns := 0; var helpers := 0; var timeouts := 0; var culls := 0
	var falls := 0; var contacts := 0; var jumps := 0; var dazzle_frames := 0
	var spotlight_one_hit := false
	var ordinary_damage := false; var boss_damage := 0; var boss_down := false
	var checkpoint := -1; var ending := -1; var mini_done := -1; var ticks := 0
	for frame in range(MAX_TICKS):
		ticks = frame+1
		game.invincible = 999 # Sole explicit assist. No positions/actor state changed.
		var controls := controls_for(game)
		var p0: Vector2 = game.player
		var ground0: bool = game.grounded
		var surface0: Dictionary = game.world_three._standing_surface
		var carry := Vector2(float(surface0.get("dx",0)),float(surface0.get("dy",0)))
		var before: Array = []
		for wave in game.combat.waves: before.append(wave.index)
		var hp_before: Array = []
		for enemy in game.enemies: hp_before.append([enemy,enemy.hp])
		var bhp: int = game.boss.state.hp if game.boss != null else -1
		game.step(DT,controls)
		if ground0 and not game.grounded and game.velocity.y < 0: jumps += 1
		if p0.y > 650 and game.player.y < p0.y-100: falls += 1
		check(absf(game.player.x-p0.x)<25 or (p0.y>float(game.level.fall)-30 and game.player==game.world_three.safe_position),"unexpected horizontal teleport")
		for pair in hp_before:
			if pair[0].hp < pair[1]: ordinary_damage = true
		for event in game.movement_skills.events:
			if event == "ground-pound-start": pound_started = true
			if event == "ground-pound-land": pound_landed = true
		var born := 0
		for enemy in game.enemies:
			if enemy not in seen: seen.append(enemy); born += 1
			if enemy.get("dz",0) > 0: dazzle_frames += 1
			if enemy.state != "pop" and absf(enemy.p.x-game.player.x)<44 and game.player.y>enemy.p.y-95 and game.player.y<enemy.p.y+24: contacts += 1
		for enemy in seen:
			if enemy.state == "pop" and enemy not in popped: popped.append(enemy)
			if enemy.get("lost",false) and enemy not in retired:
				retired.append(enemy)
				check(enemy.age-enemy.get("hit_age",0)>12,"early retirement")
			if enemy not in game.enemies and enemy.state != "pop" and not enemy.get("lost",false) and enemy not in removed:
				removed.append(enemy)
				if not enemy.entered and enemy.get("wait",0)>6: timeouts += 1
				elif enemy.p.x<game.camera.x-400 or enemy.p.x>game.camera.x+game.view_width()+400: culls += 1
		var dispatched := 0
		for i in range(game.combat.waves.size()):
			var w: Dictionary = game.combat.waves[i]
			dispatched += w.index-before[i]
			if w.done and i not in completed: completed.append(i)
		consumed += dispatched; failed_spawns += maxi(0,dispatched-born); helpers += maxi(0,born-dispatched)
		for i in range(3):
			if game.receipts[i].taken and i not in receipts: receipts.append(i)
		var surfaces: Array = game.world_three.surfaces(game)
		for index in range(10,14):
			var s: Dictionary = surfaces[15+index]
			if game.grounded and game.world_three._standing_surface == s and index not in mover_landed: mover_landed.append(index)
			if ground0 and surface0 == s and not controls.left and not controls.right and not controls.jump and carry.length()>0.05 and (game.player-p0).distance_to(carry)<0.01 and index not in mover_carried: mover_carried.append(index)
		spotlight_one_hit = spotlight_one_hit or game.world_three.big_top.spots[0].hp == 1
		spot_activated = spot_activated or game.world_three.big_top.spots.any(func(s): return s.on)
		if game.world_three.checkpoint_done and checkpoint<0:
			checkpoint = frame
			check(game.player.x>5600 and game.hearts==3,"wrong checkpoint")
		if game.boss != null:
			check(game.boss.state.max == 60 and game.boss.state.kind == "tout","wrong Ringmaster")
			if bhp>=0: boss_damage += maxi(0,bhp-game.boss.state.hp)
			boss_down = boss_down or game.boss.state.state == "down"
		if game.world_three.mini_done and mini_done<0: mini_done = frame
		if game.world_three.end_time>0 and ending<0:
			ending = frame
			check(completed.size()==9 and game.boss==null and game.world_three.mini_done,"early ending")
		if trace and frame%300==0: print("Big top frame=",frame," route=",route_step," p=",game.player," cam=",game.camera," movers=",mover_landed," live=",game.enemies.size()," boss=",game.boss.state if game.boss != null else {})
		if game.mode != "play": break
	check(game.mode=="clear","no timed clear")
	check(completed.size()==9 and consumed==31,"incomplete waves")
	check(consumed-failed_spawns+helpers==seen.size(),"spawn ledger imbalance")
	check(popped.size()+retired.size()+removed.size()==seen.size() and removed.size()==timeouts+culls,"outcome ledger imbalance")
	check(ordinary_damage and popped.size()>0,"no real normal damage/pop")
	check(receipts==[0,1,2],"not all real receipts")
	check(mover_landed.size()==4 and mover_carried.size()==4,"four real mover lands/carries missing")
	check(pound_started and pound_landed,"earned card not used")
	check(spotlight_one_hit and spot_activated,"no real two-shot spotlight activation")
	check(checkpoint>=0 and mini_done>=0 and boss_down and boss_damage>=60,"checkpoint/Ringmaster incomplete")
	check(ending>=0 and ticks-1-ending>=155 and ticks-1-ending<=157,"wrong2.6second clear")
	check(JSON.stringify(game.meta)==imported,"metadata mutated")
	var saved: Dictionary = SaveStore.read_save()
	check(saved.get("cleared",{}).get("3-4",false),"clear not saved")
	check(saved.get("receipts",{}).get("3-4",[])==[0,1,2],"receipts not saved")
	check(saved.get("skills",[])==["ground-pound"],"earned skill not saved alone")
	check(saved.get("kitty",0)==game.score,"banked score mismatch")
	var banked := JSON.stringify(saved)
	for f in range(180): game.step(DT,{})
	check(JSON.stringify(SaveStore.read_save())==banked,"postclear changed save")
	var run_pound := pound_started and pound_landed
	if game.mode=="clear":
		game.save = saved
		check(game.load_level("3-4"),"reload failed")
		check(game.movement_skills.has_skill("ground-pound"),"reload lost skill")
		pound_started = false; pound_landed = false
		for f in range(90):
			game.invincible = 999
			game.step(DT,{"jump":f==2,"down":f>2 and not game.grounded and game.velocity.y>-650})
			pound_started = pound_started or "ground-pound-start" in game.movement_skills.events
			pound_landed = pound_landed or "ground-pound-land" in game.movement_skills.events
		check(pound_started and pound_landed,"reloaded ground-pound not usable")
	print("Big top [",character,"] ","PASS" if failures.is_empty() else "FAIL"," ticks=",ticks," waves=",completed.size()," entries=",consumed," failed_placements=",failed_spawns," helpers=",helpers," seen=",seen.size()," pop=",popped.size()," retired=",retired.size()," timeouts=",timeouts," culls=",culls," receipts=",receipts," movers=",mover_landed," carried=",mover_carried," pound=",run_pound," reload_pound=",pound_landed," boss_damage=",boss_damage," checkpoint=",checkpoint," mini=",mini_done," ending=",ending," jumps=",jumps," falls=",falls," contact_frames=",contacts," spotlight=",spot_activated," dazzle_frames=",dazzle_frames," failures=",failures)
	return failures.is_empty()
func walk(game, c: Dictionary, x: float, tolerance := 3.0) -> void:
	c.right = x-game.player.x>tolerance; c.left = x-game.player.x < -tolerance
func controls_for(game) -> Dictionary:
	var c := {"left":false,"right":false,"jump":false,"down":false,"aim":false,"shoot":true,"special":false}
	if game.boss!=null and game.player.y>450 and game.boss.state.state!="down":
		if absf(game.boss.state.x-game.player.x)<140:
			walk(game,c,game.boss.state.x-240 if game.boss.state.x>game.camera.x+260 else game.boss.state.x+240)
			return c
		if absf(game.boss.state.x-game.player.x)>280 or game.face!=(1 if game.boss.state.x>=game.player.x else -1): walk(game,c,game.boss.state.x)
		return c
	if game.movement_skills.card_collected and not pound_landed:
		if game.grounded and pound_test==0: c.jump=true; pound_test=1
		elif not game.grounded and game.velocity.y>-650: c.down=true
		return c
	if route_step>=ROUTE.size(): walk(game,c,12300); return c
	var goal = ROUTE[route_step]
	var dynamic := goal is int
	var target: Vector2
	if dynamic:
		var row: Array = game.world_three.surfaces(game)[15+goal].row
		target = Vector2((row[0]+row[1])*0.5,row[2])
		if game.grounded and game.world_three._standing_surface == game.world_three.surfaces(game)[15+goal]:
			dwell += 1
			if dwell>15: route_step+=1; dwell=0
			return c
	else: target = goal
	if not dynamic and game.grounded and absf(game.player.x-target.x)<12 and absf(game.player.y-target.y)<2:
		if route_step==7 and dwell<90:
			dwell+=1; c.aim=true
			return c
		dwell=0
		route_step+=1
		if trace: print("Big top waypoint ",route_step," ",game.player)
		return c
	walk(game,c,target.x)
	if game.grounded and not game.jump_held:
		if target.y<game.player.y-6 and absf(target.x-game.player.x)<150: c.jump=true
		var surface: Dictionary = game.world_three._standing_surface
		if not surface.is_empty() and target.x>game.player.x:
			var edge: float = surface.row[1]
			if edge-game.player.x<12 and target.x>edge:
				if dynamic:
					var future_t: float = game.world_three.level_time+0.54
					var mr: Array = game.level.movers[goal-10]
					var landing_x: float = game.level.plats[goal][0]+90*sin(future_t/3.2*6.283+mr[4])
					if landing_x-game.player.x<140: c.jump=true
					else: c.right=false
				else: c.jump=true
		for row in game.level.solids:
			if row[2]<game.player.y-6 and row[0]-game.player.x>=0 and row[0]-game.player.x<65 and target.x>row[0]: c.jump=true
	return c
