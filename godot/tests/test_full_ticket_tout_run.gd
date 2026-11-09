extends SceneTree
## Actual-main 3-6 routes. Invulnerability is the ONLY gameplay assist.
## All movement, damage, waves, receipts, stage hops and the jar are real updates.
const SaveStore = preload("res://src/save_store.gd")
const ToutPainter = preload("res://src/festival_tout_renderer.gd")
const DT := 1.0 / 60.0
const MAX_TICKS := 30000
const WAVE_AT := [400,1500,2600]
const ROUTE := [Vector2(940,372),Vector2(1350,482),Vector2(1820,428),Vector2(2000,374),Vector2(2400,482),Vector2(2840,372),Vector2(3300,482),Vector2(3970,482),Vector2(4170,354),Vector2(3880,482)]
var failures: Array[String] = []
var trace := false
var route_step := 0
var ground_throw := false
var ground_stomp := false
var stage_hop := false
var stage_land := false
var stage_throw := false
var return_hop := false
var return_slam := false
var late_hop := false
var late_slam := false
var late_throw := false
var jar_goal := 0.0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok and label not in failures: failures.append(label)
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	if not game.has_method("step"):
		printerr("Ticket Tout main failed to load")
		game.free(); quit(1); return
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	var characters: Array = game.CHARACTERS
	for arg in OS.get_cmdline_user_args():
		if arg == "--trace": trace = true
		if arg.begins_with("--character="):
			var selected := arg.trim_prefix("--character=")
			if selected not in game.CHARACTERS:
				printerr("Unknown housemate: ",selected)
				game.queue_free(); await process_frame; quit(1); return
			characters = [selected]
	var passed := true
	for character in characters:
		if not run_character(game,character): passed = false
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)

func run_character(game, character: String) -> bool:
	failures.clear(); route_step = 0; jar_goal = 0
	ground_throw=false; ground_stomp=false; stage_hop=false; stage_land=false; stage_throw=false
	return_hop=false; return_slam=false; late_hop=false; late_slam=false; late_throw=false
	game.character = character
	game.save = {"schema":1,"receipts":{}}
	check(SaveStore.write_save(game.save)==OK,"fresh isolated save failed")
	check(game.load_level("3-6"),"level failed to load")
	check(game.is_native_supported() and game._native_world_three(),"3-6 native gate not enabled; gate not bypassed")
	if not failures.is_empty(): printerr(failures); return false
	check(game.player==Vector2(300,482) and game.camera==Vector2.ZERO,"incorrect source spawn")
	check(game.level.w==4400 and game.view_width()==738,"incorrect source world/view width")
	check(game.world_three.surfaces(game).size()==9 and game.level.solids.size()==8,"incorrect source geometry inventory")
	check(game.meta.l3.stage==0 and game.level.plats[0][0]==4040 and game.level.plats[0][1]==4290 and game.level.plats[0][2]==354,"numeric stage0 not preserved")
	check(game.receipts.size()==3 and game.receipts[0].position==Vector2(1820,312) and game.receipts[1].position==Vector2(2000,252) and game.receipts[2].position==Vector2(4170,282),"wrong receipt centers")
	check(game.movement_skills.skills.is_empty() and game.abilities.skills.is_empty(),"inherited unearned skills")
	check(game.level.crates.size()==3 and game.level.coinRows.is_empty(),"wrong crate/authored coin inventory")
	var imported := JSON.stringify(game.meta)
	var planned := 0; var pair_entries := 0
	check(game.combat.waves.size()==3,"wrong wave count")
	for i in range(game.combat.waves.size()):
		check(game.combat.waves[i].at==WAVE_AT[i],"wrong wave trigger")
		planned += game.combat.waves[i].group.size()
	for wave in game.meta.l3.waves: pair_entries += wave[1].size()
	check(planned==10 and pair_entries==13,"wrong solo/pair authored entries")
	var seen: Array=[]; var popped: Array=[]; var retired: Array=[]; var removed: Array=[]
	var started: Array=[]; var completed: Array=[]; var receipts: Array=[]; var landed: Array=[]
	var states: Array=[]; var animations: Array=[]; var receipt_frames: Array=[]
	var consumed:=0; var failed_spawns:=0; var helpers:=0; var timeouts:=0; var culls:=0
	var jumps:=0; var falls:=0; var enemy_contacts:=0; var body_contacts:=0; var wave_contacts:=0; var projectile_contacts:=0; var tied_frames:=0
	var ordinary_damage:=false; var boss_damage:=0; var dizzy_frame:=-1; var dizzy_damage:=false
	var boss_start:=-1; var boss_down:=-1; var jar_spawn:=-1; var jar_pickup:=-1
	var stage_hop_frame:=-1; var stage_land_frame:=-1; var return_frame:=-1; var return_land_frame:=-1; var late_frame:=-1; var late_land_frame:=-1
	var jar_age:=0.0; var jar_magnet_frames:=0; var pause_checked:=false; var ticks:=0; var late_from_stage:=false
	for frame in range(MAX_TICKS):
		ticks=frame+1
		game.invincible=999 # Sole progression assist. Ties and collisions still happen.
		var c:=controls_for(game)
		var p0: Vector2=game.player
		var grounded0: bool=game.grounded
		var hp0: int=game.boss.state.hp if game.boss!=null else -1
		var b0: Dictionary=game.boss.state.duplicate(true) if game.boss!=null else {}
		var indices: Array=[]; var before_hp: Array=[]
		for wave in game.combat.waves: indices.append(wave.index)
		for enemy in game.enemies: before_hp.append([enemy,enemy.hp])
		var coins0: Array=game.coins.duplicate()
		var score0: int=game.score
		var bullets0: Array=game.bullets.duplicate()
		game.step(DT,c)
		if grounded0 and not game.grounded and game.velocity.y<0: jumps+=1
		if p0.y>650 and game.player.y<p0.y-100: falls+=1
		check(absf(game.player.x-p0.x)<25 or (p0.y>float(game.level.fall)-30 and game.player==game.world_three.safe_position),"unexpected horizontal teleport")
		check(game.world_three.end_time==0,"ordinary timed end activated in jar finale")
		for pair in before_hp:
			if pair[0].hp<pair[1]: ordinary_damage=true
		var born:=0
		for enemy in game.enemies:
			if enemy not in seen:
				seen.append(enemy); born+=1
				if trace: print("Tout spawn frame=",frame," kind=",enemy.kind," side=",enemy.get("spawn_side","")," p=",enemy.p)
			if enemy.state!="pop" and absf(enemy.p.x-game.player.x)<44 and game.player.y>enemy.p.y-95 and game.player.y<enemy.p.y+24: enemy_contacts+=1
		for enemy in seen:
			if enemy.state=="pop" and enemy not in popped: popped.append(enemy)
			if enemy.get("lost",false) and enemy not in retired:
				retired.append(enemy)
				check(enemy.age-enemy.get("hit_age",0)>12,"retirement preceded source12seconds")
			if enemy not in game.enemies and enemy.state!="pop" and not enemy.get("lost",false) and enemy not in removed:
				removed.append(enemy)
				if not enemy.entered and enemy.get("wait",0)>6: timeouts+=1
				elif enemy.p.x<game.camera.x-400 or enemy.p.x>game.camera.x+game.view_width()+400: culls+=1
		var dispatched:=0
		for i in range(game.combat.waves.size()):
			var w: Dictionary=game.combat.waves[i]
			dispatched+=w.index-indices[i]
			if w.started and i not in started: started.append(i)
			if w.done and i not in completed:
				completed.append(i)
				check(w.index==w.group.size(),"wave done before all entries consumed")
				if trace: print("Tout wave done=",i," frame=",frame," p=",game.player)
		consumed+=dispatched; failed_spawns+=maxi(0,dispatched-born); helpers+=maxi(0,born-dispatched)
		for i in range(3):
			if game.receipts[i].taken and i not in receipts:
				receipts.append(i); receipt_frames.append(frame)
				check(game.world_three.finds_near(game,game.receipts[i].position),"receipt collected without actual body overlap")
				check(game.score-score0==coins0.filter(func(coin): return coin.get("dead",false)).size(),"receipt granted currency")
				if trace: print("Tout receipt=",i," frame=",frame," p=",game.player)
		if game.grounded:
			for i in range(game.world_three.surfaces(game).size()):
				var s: Dictionary=game.world_three.surfaces(game)[i]
				if game.world_three._standing_surface==s and i not in landed: landed.append(i)
		if game.world_three.tied>0: tied_frames+=1
		for bill in bullets0:
			if not bill.enemy: continue
			var height: float=game.character_height()*(0.56 if game.crouching else 0.86)
			if bill.get("dead",false) and absf(bill.p.x-game.player.x)<26 and bill.p.y>game.player.y-height and bill.p.y<game.player.y: projectile_contacts+=1
		if game.boss!=null:
			var b: Dictionary=game.boss.state
			if boss_start<0:
				boss_start=frame
				check(completed.size()==3 and consumed==10 and game.camera.x>=3660,"boss started before actual approach completion")
				check(b.max==160 and b.kind=="tout" and b.cam==3662 and not b.cfg.get("mini",false),"wrong actual160HP main Tout")
				check(b.hp==160 and b.state=="enter" and b.x==4310,"first source enter clamp changed")
				check(game.camera_lock==3662,"wrong arena lock")
			if b.state not in states: states.append(b.state)
			var move: Dictionary=ToutPainter.tout_move(b,game.world_three.level_time)
			if move.animation not in animations: animations.append(move.animation)
			if hp0>=0:
				boss_damage+=maxi(0,hp0-b.hp)
				if hp0>b.hp and b0.dizzy>0:
					dizzy_damage=true
					check((hp0-int(b.hp))%2==0,"dizzy projectile damage was not doubled")
			check(b.visual_t==game.world_three.level_time and b.visual_x==b.x,"simulation-owned Tout visual snapshot stale")
			if b.state not in ["enter","down"] and not b.has("hop") and absf(b.x-game.player.x)<62 and absf(b.fy-game.player.y)<120: body_contacts+=1
			for wave in b.waves:
				if absf(wave.x-game.player.x)<24 and game.player.y>452: wave_contacts+=1
			var new_bills:=0
			for bill in game.bullets:
				if bill.enemy and bill not in bullets0 and bill.get("tie",false): new_bills+=1
			if new_bills>0:
				if b.fy==482 and float(b.hp)/b.max>=0.66: ground_throw=true; check(new_bills==3,"ground throw not3wristbands")
				elif b.fy==354: stage_throw=true; check(new_bills==5,"stage throw not5wristbands")
				elif b.fy==482 and float(b.hp)/b.max<0.33: late_throw=true; check(new_bills==4,"late throw not4wristbands")
			if b.waves.any(func(wave): return absf(wave.vx)==420): ground_stomp=true
			if b.has("hop"):
				var h: Dictionary=b.hop
				if not h.get("slam",false):
					if not stage_hop: stage_hop_frame=frame
					stage_hop=true
					check(h.end==Vector2(4165,354) and h.duration==0.8 and h.height==160,"stage0 ascent endpoints/timing wrong")
				elif h.duration==0.9:
					if not return_hop: return_frame=frame
					return_hop=true
					check(h.start.y==354 and h.end.y==482 and h.height==140,"stage return slam wrong")
				else:
					if not late_hop: late_frame=frame
					late_hop=true
					late_from_stage=late_from_stage or h.start.y==354
					check(float(b.hp)/b.max<0.33 and h.duration==0.85 and h.height==230 and h.end.x>=3752 and h.end.x<=4310,"late jump-slam wrong")
			if stage_hop and not stage_land and not b.has("hop") and b.fy==354: stage_land=true; stage_land_frame=frame
			if b.land_t>0 and not b.has("hop") and b.waves.any(func(wave): return absf(wave.vx)==460):
				if return_hop and not return_slam: return_slam=true; return_land_frame=frame
				elif late_hop and not late_slam: late_slam=true; late_land_frame=frame
			if b.get("dz",false) and dizzy_frame<0:
				dizzy_frame=frame
				check(b.hp<80 and b.dizzy==2.6,"halfhealth source dizzy threshold/timer wrong")
			if b.state=="down" and boss_down<0:
				boss_down=frame
				check(game.mode=="play" and b.jar.is_empty(),"boss death prematurely cleared or spawned jar")
				check(b.hp<=0 and b.called==[true,true],"boss defeated without actual threshold helpers")
				jar_goal=4360 if b.x<4030 else 3720
			if not b.jar.is_empty():
				if jar_spawn<0:
					jar_spawn=frame
					check(frame-boss_down>=90 and b.t>1.5,"jar spawned before source down delay")
					check(game.mode=="play" and b.jar.t<=DT+0.000001,"jar spawn itself cleared")
				var j: Dictionary=b.jar
				if not b0.is_empty() and not b0.jar.is_empty() and not b0.jar.got:
					var old: Dictionary=b0.jar
					var expected_x: float=old.x
					if old.t>1.4:
						expected_x=move_toward(expected_x,game.player.x,120*DT)
						jar_magnet_frames+=1
					if old.y<452 or old.vy<0: expected_x+=old.vx*DT
					check(absf(j.x-expected_x)<0.001,"jar magnet/physics order or speed wrong")
				if j.t<=0.6: check(not j.got and game.mode=="play","jar collected before strict600ms age")
				if j.got and jar_pickup<0:
					jar_pickup=frame; jar_age=j.t
					check(j.t>1.4 and absf(game.player.x-j.x)<50 and game.mode=="clear","clear did not come from actual aged jar pickup")
				elif not j.got: check(game.mode=="play","cleared without jar pickup")
			if stage_land and not pause_checked:
				pause_checked=true
				var snapshot:=JSON.stringify([game.player,game.camera,game.world_three.level_time,b,game.combat.waves,game.enemies,game.bullets,game.score])
				game._pause()
				check(game.mode=="paused","pause callback failed")
				for i in range(60): game.step(DT,{"right":true,"jump":true,"shoot":true,"special":true})
				check(JSON.stringify([game.player,game.camera,game.world_three.level_time,b,game.combat.waves,game.enemies,game.bullets,game.score])==snapshot,"paused simulation changed live stage encounter")
				game._resume()
				check(game.mode=="play" and game.boss.state==b,"resume replaced live boss")
		if trace and frame%300==0: print("Tout frame=",frame," route=",route_step," p=",game.player," cam=",game.camera," boss=",[game.boss.state.hp,game.boss.state.state,game.boss.state.fy,game.boss.state.stage_t] if game.boss!=null else []," milestones=",[ground_throw,ground_stomp,stage_hop,stage_land,stage_throw,return_slam,late_hop,late_throw]," live=",game.enemies.size())
		if game.mode!="play": break
	check(game.mode=="clear","no actual jar clear")
	check(started.size()==3 and completed.size()==3 and consumed==10,"incomplete three approach waves/ten entries")
	check(consumed-failed_spawns+helpers==seen.size(),"spawn ledger does not balance")
	check(popped.size()+retired.size()+removed.size()==seen.size() and removed.size()==timeouts+culls,"unclassified actor outcome")
	check(helpers==4,"four solo threshold helpers not instantiated")
	check(ordinary_damage and popped.size()>0,"no ordinary bullet enemy damage/pop")
	check(receipts==[0,1,2] and route_step==ROUTE.size(),"all receipts/full physical route not completed")
	check(4 in landed and 5 in landed and 6 in landed and 7 in landed and 8 in landed,"both barriers/bales/stage not physically landed")
	check(falls==0,"route used source fall recovery")
	check(boss_damage>=160 and boss_down>boss_start and jar_spawn>boss_down and jar_pickup>jar_spawn,"incomplete real160HP boss/down/jar lifecycle")
	check(ground_throw and ground_stomp and stage_hop and stage_land and stage_throw and return_hop and return_slam and late_hop and late_slam and late_throw,"required source boss attacks/stage0/return/late phases not observed")
	check(dizzy_frame>=0 and dizzy_damage,"halfhealth dizzy and real doubled damage not observed")
	check(stage_land_frame-stage_hop_frame>=47 and return_frame-stage_land_frame>=540 and return_land_frame-return_frame>=53 and late_land_frame-late_frame>=50,"boss hop/stage residence timing shortened")
	check(animations.size()==7,"not all seven source Tout move selections observed")
	check(pause_checked and jar_magnet_frames>0,"pause/resume or actual latejar magnet not covered")
	check(JSON.stringify(game.meta)==imported,"imported source metadata mutated")
	var saved: Dictionary=SaveStore.read_save()
	check(saved.get("cleared",{}).get("3-6",false),"clear missing after save reload")
	check(saved.get("receipts",{}).get("3-6",[])==[0,1,2],"receipts missing after save reload")
	check(saved.get("skills",[]).is_empty(),"unearned skills persisted")
	check(saved.get("kitty",0)==game.score,"banked score differs from real pickups")
	var banked:=JSON.stringify(saved)
	var score: int=game.score
	for i in range(180): game.step(DT,{"right":true,"shoot":true})
	check(game.score==score and JSON.stringify(SaveStore.read_save())==banked,"postclear duplicated settlement")
	print("Ticket Tout [",character,"] ","PASS" if failures.is_empty() else "FAIL"," ticks=",ticks," waves=",completed.size()," entries=",consumed," failed_placements=",failed_spawns," helpers=",helpers," seen=",seen.size()," popped=",popped.size()," retired12s=",retired.size()," entry_timeouts6s=",timeouts," camera_culls=",culls," receipts=",receipts," receipt_frames=",receipt_frames," landed=",landed," jumps=",jumps," falls=",falls," enemy_contacts=",enemy_contacts," body_contacts=",body_contacts," wave_contacts=",wave_contacts," projectile_contacts=",projectile_contacts," tied_frames=",tied_frames," boss_damage=",boss_damage," boss_start=",boss_start," stage_hop/land=",stage_hop_frame,"/",stage_land_frame," return/land=",return_frame,"/",return_land_frame," dizzy=",dizzy_frame," late_from_stage=",late_from_stage," late/land=",late_frame,"/",late_land_frame," down/jar/pickup=",boss_down,"/",jar_spawn,"/",jar_pickup," jar_age=",jar_age," magnet_frames=",jar_magnet_frames," states=",states," animations=",animations," pause=",pause_checked," score=",score," mode=",game.mode," failures=",failures)
	return failures.is_empty()

func walk(game, c: Dictionary, x: float, tolerance:=3.0) -> void:
	c.right=x-game.player.x>tolerance; c.left=x-game.player.x < -tolerance
func face_target(game, c: Dictionary, x: float) -> void:
	if game.face!=(1 if x>=game.player.x else -1):
		c.right=x>=game.player.x; c.left=x<game.player.x
func navigate(game, c: Dictionary, target: Vector2) -> void:
	walk(game,c,target.x)
	if not game.grounded or game.jump_held: return
	var direction:=1 if target.x>=game.player.x else -1
	if target.y<game.player.y-6 and absf(target.x-game.player.x)<115: c.jump=true
	for row in game.level.solids:
		if row[2]>=game.player.y-6: continue
		var distance: float=((row[0] if direction>0 else row[1])-game.player.x)*direction
		if distance>=0 and distance<65 and absf(target.x-game.player.x)>distance: c.jump=true
	if target.y>game.player.y+6 and game.on_platform and absf(target.x-game.player.x)<10: c.down=true; c.jump=true
func controls_for(game) -> Dictionary:
	var c: Dictionary={"left":false,"right":false,"jump":false,"down":false,"aim":false,"shoot":true,"special":false}
	if game.boss!=null: c.shoot=false
	if route_step<ROUTE.size():
		var goal: Vector2=ROUTE[route_step]
		if game.grounded and absf(game.player.x-goal.x)<12 and absf(game.player.y-goal.y)<2:
			var receipt_index: int=0 if route_step==2 else (1 if route_step==3 else (2 if route_step==8 else -1))
			if receipt_index>=0 and not game.receipts[receipt_index].taken:
				c.jump=not game.jump_held
				return c
			route_step+=1
			if trace: print("Tout waypoint=",route_step," p=",game.player)
		if route_step<ROUTE.size(): navigate(game,c,ROUTE[route_step])
	if game.boss!=null and route_step>=ROUTE.size():
		var b: Dictionary=game.boss.state
		if b.state=="down": walk(game,c,jar_goal); return c
		if absf(b.x-game.player.x)<180 and b.fy>450:
			walk(game,c,b.x-230 if b.x>4030 else b.x+230)
		else: face_target(game,c,b.x)
		if b.fy<450 and return_slam: c.aim=true
		if ground_throw and ground_stomp:
			if not return_slam: c.shoot=b.hp>102 and not stage_hop
			elif not late_hop or not late_slam or not late_throw: c.shoot=b.hp>50
			else: c.shoot=true
		return c
	if game.boss!=null: return c
	var target: Dictionary={}
	for enemy in game.enemies:
		if enemy.state=="pop": continue
		if target.is_empty() or absf(enemy.p.x-game.player.x)<absf(target.p.x-game.player.x): target=enemy
	if not target.is_empty():
		var dy: float=target.p.y-game.player.y
		if absf(dy)<70 and game.grounded:
			c.left=false; c.right=false; c.jump=false
			face_target(game,c,target.p.x)
		elif dy < -70: c.aim=true
	return c
