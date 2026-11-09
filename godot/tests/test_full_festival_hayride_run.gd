extends SceneTree
## Real main/input routes. Repeated invulnerability is the only progression assist.
## The seventh no-shoot run earns three falls/knockout, Continues, and clears live.
const SaveStore = preload("res://src/save_store.gd")
const DT := 1.0 / 60.0
const MAX_TICKS := 15000
const WAVE_AT := [700,2400,4100,5800,7500,9200,10900,12600,14300,21100,22800,24500,26200,27900,29600,31300]
class AudioProbe extends RefCounted:
	var enabled := false
	var paused := false
	var music_requested := false
	var calls: Array[bool] = []
	func set_enabled(value: bool) -> void: enabled = value
	func set_paused(value: bool) -> void: paused = value
	func play_effect(_effect: String) -> void: pass
	func start_music(boss: bool = false) -> void: music_requested = true; calls.append(boss)
	func stop_music() -> void: music_requested = false
	func shutdown() -> void: pass
var failures: Array[String] = []
var trace := false
var receipt_jump := -1
var receipt_airborne := false
var recovery_mode := false
var recovery_done := false
var defeat := true

func _initialize() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok and why not in failures: failures.append(why)
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	if not game.has_method("step"):
		printerr("Hay ride main script failed to load")
		game.free(); quit(1); return
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	game.audio = AudioProbe.new()
	var chars: Array = game.CHARACTERS
	var include_live := true
	for arg in OS.get_cmdline_user_args():
		if arg == "--trace": trace = true
		if arg == "--no-live": include_live = false
		if arg.begins_with("--character="): chars = [arg.trim_prefix("--character=")]
	var passed := true
	for character in chars:
		if character not in game.CHARACTERS or not run_character(game,character,true): passed = false
	if include_live and not run_character(game,"jp",false): passed = false
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)

func controls_for(game) -> Dictionary:
	var c := {"left":false,"right":false,"down":false,"jump":false,"shoot":defeat,"aim":false,"special":false}
	if game.world_three.wiping: return c
	if recovery_mode:
		c.left = true
		return c
	if receipt_jump >= 0:
		if not game.grounded: receipt_airborne = true
		if receipt_airborne and game.grounded:
			receipt_jump = -1
			receipt_airborne = false
		else:
			c.right = game.player.x < game.receipts[receipt_jump].position.x-16
			return c
	for row in game.level.duck:
		if game.player.x >= row[0]-25 and game.player.x <= row[1]+12:
			c.down = true
			var h: Dictionary = game.world_three.hayride.harvester
			if not h.is_empty() and not h.dead: c.left = true
			return c
	for i in range(game.receipts.size()):
		var r: Dictionary = game.receipts[i]
		if not r.taken and r.position.x-game.player.x < 80 and r.position.x-game.player.x > -20:
			c.jump = game.grounded and not game.jump_held
			c.right = true
			if c.jump: receipt_jump = i
			return c
	# Stay near the center of the only support. Facing is changed with normal
	# directional taps, never a player/face write; airborne players get no carry.
	var relative: float = game.player.x-game.camera.x
	c.right = relative < 294
	c.left = relative > 306
	if not c.left and not c.right:
		var h: Dictionary = game.world_three.hayride.harvester
		var want_face := -1 if not h.is_empty() and not h.dead and defeat else 1
		if game.face != want_face:
			c.left = want_face < 0
			c.right = want_face > 0
	return c

func run_character(game, character: String, defeat_harvester: bool) -> bool:
	failures.clear(); receipt_jump = -1; receipt_airborne = false
	recovery_mode = false; recovery_done = false; defeat = defeat_harvester
	game.character = character
	game.save = {"schema":1,"receipts":{}}
	check(SaveStore.write_save(game.save) == OK,"fresh isolated save failed")
	check(game.load_level("3-5"),"3-5 load failed")
	check(game.is_native_supported() and game._native_world_three(),"native 3-5 routing pending; no bypass")
	if not failures.is_empty(): printerr("Hay ride BLOCKED ",failures); return false
	var runtime = game.world_three
	var deck: Dictionary = runtime.trailer
	# Source mkPlayer starts onPlat=false despite this spawn being supported.
	check(game.player == Vector2(300,402) and game.grounded and not game.on_platform,"deck absent before spawn lookup")
	check(deck == runtime.surfaces(game)[0] and deck.row[0]==60 and deck.row[1]==540 and deck.row[2]==402 and deck.nodrop and deck.nospawn and deck.style=="trailer","wrong initial live deck")
	check(deck.get("dx",-1) == 0 and not runtime.allow_drop(game),"initial deck delta/nodrop changed")
	check(game.movement_skills.skills.is_empty() and game.abilities.skills.is_empty(),"unearned skills")
	check(game.level.w == 34000 and game.level.auto == 0.17 and game.level.fall == 572,"source course timing/width changed")
	check(game.level.solids.is_empty() and game.crates.is_empty() and game.level.coinRows.is_empty(),"invented solids/crates/coin rows")
	check(game.level.duck.size() == 18 and game.receipts.size() == 3,"wrong branches/find inventory")
	check(game.receipts.map(func(r): return r.position) == [Vector2(8000,212),Vector2(20000,212),Vector2(30000,212)],"source receipt centers changed")
	check(game.combat.waves.size() == 16,"wrong authored wave count")
	var planned := 0; var pair_entries := 0
	for i in range(game.combat.waves.size()):
		check(game.combat.waves[i].at == WAVE_AT[i],"wrong wave trigger")
		planned += game.combat.waves[i].group.size()
	for wave in game.meta.l3.waves: pair_entries += wave[1].size()
	check(planned == 39 and pair_entries == 62,"source solo/pair entries changed")
	var imported := JSON.stringify(game.meta)
	var seen: Array = []; var popped: Array = []; var retired: Array = []; var culled: Array = []
	var timed_out: Array = []; var scene_removed: Array = []; var unknown: Array = []
	var receipts: Array[int] = []; var ducked: Array[int] = []; var hops: Array = []; var landed: Array = []
	var drones: Array = []; var cleaned_drones: Array = []; var pop_detach := 0
	var carrier_count := 0; var flyer_count := 0; var dispatched := 0; var failed_placements := 0
	var jumps := 0; var falls := 0; var contacts := 0; var branch_contacts := 0
	var carried := 0; var air_no_carry := 0; var auto_frames := 0; var warmup_frames := 0; var wipe_frames := 0
	var checkpoint := -1; var wipe_start := -1; var wipe_mid := -1; var wipe_end := -1; var ending := -1
	var harv_start := -1; var lethal := -1; var down := -1; var done := -1; var hp_damage := 0; var drop_coins := 0
	var shot_hits := 0; var ordinary_damage := false; var paused := false; var continued := false; var ticks := 0
	for frame in range(MAX_TICKS):
		ticks = frame+1
		game.invincible = 999 # Sole gameplay assist. Fall recovery deliberately clears it.
		if not defeat and harv_start >= 0 and not recovery_done: recovery_mode = true
		var c := controls_for(game)
		var p0: Vector2 = game.player
		var cam0: float = game.camera.x
		var ground0: bool = game.grounded
		var scene0: int = runtime.scene_index
		var wiping0: bool = runtime.wiping
		var end0: float = runtime.end_time
		var carry0: float = deck.dx
		var row0: Array = deck.row.duplicate(true)
		var v0: Vector2 = game.velocity
		var harv0: Dictionary = runtime.hayride.harvester.duplicate(true)
		var old_indices: Array = game.combat.waves.map(func(w): return w.index)
		var enemy_hp: Array = []; var carrying: Array = []
		for enemy in game.enemies:
			enemy_hp.append([enemy,enemy.hp])
			if enemy.get("carry",false): carrying.append(enemy)
		var score0: int = game.score
		var coins0: Array = game.coins.duplicate()
		var shots0: Array = game.bullets.filter(func(shot): return not shot.enemy and not shot.get("dead",false))
		game.step(DT,c)
		var recovered: bool = p0.y > 500 and game.player.y == 402 and not ground0 and scene0 == runtime.scene_index
		if recovered:
			falls += 1
			check(game.player.x >= deck.row[0] and game.player.x <= deck.row[1],"fall recovery missed live support")
			check(game.hearts == 3-falls,"fall did not apply source one-heart cost")
		if ground0 and not game.grounded and game.velocity.y < 0: jumps += 1
		if scene0 == runtime.scene_index:
			check(absf(game.player.x-p0.x)<25 or recovered,"unexpected player teleport")
			check(absf(deck.row[0]-row0[0]-(game.camera.x-cam0)) < 0.001,"deck failed current-camera carry")
			if ground0 and game.grounded and not c.left and not c.right and not c.jump and v0.x == 0 and not recovered:
				check(absf(game.player.x-p0.x-carry0) < 0.002,"player not carried by previous-frame deck delta")
				if carry0>0: carried += 1
			if not ground0 and not game.grounded and not c.left and not c.right and v0.x == 0 and p0.x>cam0+35 and not recovered:
				check(absf(game.player.x-p0.x)<0.002,"airborne player incorrectly deck-carried")
				air_no_carry += 1
			if wiping0:
				wipe_frames += 1
				check(game.camera.x==cam0,"auto advanced during wipe")
			elif runtime.level_time<=1.8:
				warmup_frames += 1
				check(game.camera.x==cam0,"auto advanced during warmup")
			elif end0>0: check(game.camera.x==cam0,"auto advanced during ending")
			elif cam0<33260-170*DT:
				auto_frames += 1
				check(absf(game.camera.x-cam0-170*DT)<0.003,"auto is not170px/s")
		for i in range(game.level.duck.size()):
			var row: Array = game.level.duck[i]
			if game.player.x>row[0] and game.player.x<row[1] and game.crouching and i not in ducked: ducked.append(i)
			if runtime.hayride.banner_hits(row,game.player,game.character_height(),game.player_animation): branch_contacts += 1
		for pair in enemy_hp:
			if pair[0].hp<pair[1]: ordinary_damage = true
		var born := 0
		for enemy in game.enemies:
			if enemy not in seen:
				seen.append(enemy); born += 1
				if enemy.get("spawn_side","")=="k": carrier_count += 1
				elif enemy.get("spawn_side","")=="d": flyer_count += 1
				else: check(false,"noncarrier/nonflyer authored actor")
			if enemy.has("hop") and enemy not in hops:
				hops.append(enemy)
				check(enemy.hop.duration==0.42 and enemy.hop.surface==deck and enemy.hop.segment==deck.row,"source420ms/live-deck hop changed")
				check(absf(enemy.hop.end.x-clampf(enemy.p.x,float(deck.row[0])-runtime.cam_dx+60,float(deck.row[1])-runtime.cam_dx-60)-runtime.cam_dx*30)<0.002,"carrier hop lost30-frame camera lead")
			if enemy in hops and not enemy.has("hop") and enemy.state!="pop" and enemy.surface==deck and enemy not in landed: landed.append(enemy)
			if enemy.state!="pop" and absf(enemy.p.x-game.player.x)<44 and game.player.y>enemy.p.y-95 and game.player.y<enemy.p.y+24: contacts += 1
		for enemy in carrying:
			if enemy.state=="pop" and not enemy.carry: pop_detach += 1
		for drone in game.combat.ex_drones:
			if drone not in drones: drones.append(drone)
		for drone in drones:
			if drone not in game.combat.ex_drones and drone not in cleaned_drones:
				cleaned_drones.append(drone)
				check(drone.age>=2.6,"exit drone removed before2.6s")
		for enemy in seen:
			if enemy.state=="pop" and enemy not in popped: popped.append(enemy)
			if enemy in game.enemies or enemy in popped or enemy in retired or enemy in culled or enemy in timed_out or enemy in scene_removed or enemy in unknown: continue
			if enemy.get("lost",false):
				retired.append(enemy)
				check(enemy.age-enemy.get("hit_age",0)>12,"early12s retirement")
			elif not enemy.entered and enemy.get("wait",0)>6: timed_out.append(enemy)
			elif scene0!=runtime.scene_index: scene_removed.append(enemy)
			elif enemy.p.x<=game.camera.x-400 or enemy.p.x>=game.camera.x+game.view_width()+400: culled.append(enemy)
			else: unknown.append(enemy)
		var frame_dispatch := 0
		for i in range(16): frame_dispatch += game.combat.waves[i].index-old_indices[i]
		dispatched += frame_dispatch; failed_placements += maxi(0,frame_dispatch-born)
		for i in range(3):
			if game.receipts[i].taken and i not in receipts:
				receipts.append(i)
				check(not game.grounded and runtime.finds_near(game,game.receipts[i].position),"receipt not earned by real jump/overlap")
				check(game.score-score0==coins0.filter(func(coin): return coin.get("dead",false)).size(),"receipt added noncoin currency")
				if trace: print("Hay receipt ",i," frame=",frame," p=",game.player)
		if runtime.checkpoint_done and checkpoint<0:
			checkpoint = frame
			check(game.player.x>13300 and game.hearts==3 and absf(game.invincible-1.5)<0.001,"wrong checkpoint refill")
		if runtime.wiping and wipe_start<0:
			wipe_start = frame
			check(runtime.wipe_label=="Later that evening" and runtime.wipe_kind=="fade" and runtime.wipe_elapsed==0,"wrong dusk trigger")
		if scene0!=runtime.scene_index:
			wipe_mid = frame
			check(game.camera.x==14500 and runtime.scene_index==1,"wrong dusk destination")
			check(absf((game.player.x-game.camera.x)-(p0.x-cam0))<0.001 and game.player.y==p0.y,"scene lost player offsets/feet")
			check(absf((deck.row[0]-game.camera.x)-(row0[0]-cam0))<0.001 and deck.row[2]==402 and deck.dx==carry0,"scene lost deck offset/delta")
			check(game.enemies.is_empty() and game.bullets.is_empty(),"scene failed to clear actors")
			check(runtime.wipe_elapsed>=1.43 and runtime.wipe_elapsed<1.43+DT+0.0001,"wrong1.43s midpoint")
		if wiping0 and not runtime.wiping:
			wipe_end = frame
			check(absf(runtime.wipe_elapsed-2.17)<0.0001,"wrong2.17s wipe")
		var harv: Dictionary = runtime.hayride.harvester
		check(game.boss==null,"harvester replaced ordinary boss slot")
		if not harv.is_empty() and harv_start<0:
			harv_start = frame
			check(game.camera.x>=15000 and harv.max==70 and harv.hp==70 and not harv.dead,"wrong solo harvester trigger/HP")
			check(game.audio.calls.back()==true,"harvester did not start boss music")
		if not harv0.is_empty() and not harv0.get("done",false) and not harv.get("done",false):
			var damage: int = int(harv0.hp-harv.hp)
			hp_damage += damage
			if damage>0:
				# Main expires late dead shots before returning. Preserve references to
				# real pre-frame bullets, then inspect their post-step hit positions.
				var consumed_shots: int = shots0.filter(func(s): return s.get("dead",false) and s.p.y>102 and s.p.x<harv0.x+runtime.cam_dx+50*DT+10 and s.p.x>harv0.x+runtime.cam_dx-50*DT-340-6*damage).size()
				check(damage==consumed_shots,"harvester damage not fixed one per surviving ordinary shot")
				shot_hits += consumed_shots
				check(harv.flash==0.08,"harvester hit flash changed")
		if not harv0.is_empty() and harv0.get("dead",false) and not harv0.get("done",false) and not harv.get("done",false):
			check(absf(harv.x-harv0.x-runtime.cam_dx+300*DT)<0.003,"harvester retreat not300px/s plus camera")
		if not harv0.is_empty() and harv0.get("done",false):
			check(harv.get("done",false) and harv.dead and harv.hp==0,"completed harvester respawned")
		if not harv.is_empty() and harv.hp<=0 and not harv.dead and lethal<0:
			lethal = frame
			check(not game.coins.any(func(coin): return coin.age==0),"harvester dropped coins in lethal rather than death frame")
		if not harv.is_empty() and harv.dead and down<0:
			down = frame
			check(frame==lethal+1 and harv.t==0,"harvester death not deferred one late frame")
			var drops: Array = game.coins.filter(func(coin): return coin.age==0)
			drop_coins = drops.size()
			check(drop_coins==14 and drops.all(func(coin): return absf(coin.p.x-deck.row[0]-80)<=15.002 and coin.p.y==302),"harvester did not drop14coins at live deck")
			check(game.audio.calls.back()==false,"harvester death did not restore stage music")
		if not harv.is_empty() and harv.get("done",false) and done<0:
			done = frame
			check(frame-down>=180 and frame-down<=181 and harv0.t<=3 and harv0.t+DT>3 and harv.x==-1e9,"wrong strict3s retreat sentinel")
		if not paused and not harv.is_empty() and harv.get("hp",0)>0:
			paused = true
			var paused_state := JSON.stringify([runtime.snapshot(),game.player,game.camera,game.enemies,game.bullets,game.coins])
			game._pause()
			for idle in range(30): game.step(DT,{"right":true,"jump":true,"shoot":true})
			check(game.mode=="paused" and JSON.stringify([runtime.snapshot(),game.player,game.camera,game.enemies,game.bullets,game.coins])==paused_state,"pause changed live encounter")
			game._resume()
		if game.mode=="over" and recovery_mode:
			check(falls==3 and game.hearts==0,"knockout did not follow three real falls")
			var retained := JSON.stringify([runtime.snapshot(),game.player,game.camera,game.enemies,game.bullets,game.coins,game.score,game.receipts])
			game._continue_level()
			check(game.mode=="play" and game.hearts==3 and game.invincible==2.5,"Continue did not revive")
			check(JSON.stringify([runtime.snapshot(),game.player,game.camera,game.enemies,game.bullets,game.coins,game.score,game.receipts])==retained,"Continue reset live ride/encounter")
			continued = true; recovery_done = true; recovery_mode = false
		if runtime.end_time>0 and ending<0:
			ending = frame
			check(game.camera.x>=33260,"ending before source distance")
			if not defeat: check(not harv.dead and harv.hp==70,"live harvester was cleared before end")
		if trace and frame%600==0: print("Hay frame=",frame," char=",character," p=",game.player," cam=",game.camera," receipts=",receipts," harv=",harv)
		if game.mode!="play": break
	check(game.mode=="clear","no actual timed clear")
	check(dispatched==39 and seen.size()==39 and failed_placements==0 and carrier_count==23 and flyer_count==16,"39authored actors not actually spawned")
	check(game.combat.waves.all(func(w): return w.started and w.done and w.index==w.group.size()),"not all16waves dispatched")
	check(unknown.is_empty(),"unclassified actor removal")
	var alive := seen.filter(func(e): return e in game.enemies and e not in popped).size()
	check(popped.size()+retired.size()+culled.size()+timed_out.size()+scene_removed.size()+unknown.size()+alive==seen.size(),"actor outcome ledger imbalance")
	check(not hops.is_empty() and not landed.is_empty() and not drones.is_empty() and not cleaned_drones.is_empty(),"missing natural carrier hop/land/detach/cleanup")
	check(receipts==[0,1,2] and jumps>=3,"three high receipts not earned")
	check(ducked.size()==18 and branch_contacts==0,"missing safe18branch traversal")
	check(warmup_frames>0 and auto_frames>0 and carried>0 and air_no_carry>0 and wipe_frames>0,"missing warmup/auto/ground/air/wipe observations")
	check(checkpoint>=0 and wipe_start==checkpoint and wipe_mid>wipe_start and wipe_end>wipe_mid,"checkpoint/dusk timeline incomplete")
	check(harv_start>wipe_end and paused,"harvester/pause not exercised")
	check(ending>=0 and ticks-1-ending>=155 and ticks-1-ending<=157,"wrong2.6s clear")
	check(runtime.stage_data.events_done==[0],"missing main-road announcement")
	if defeat:
		check(falls==0 and ordinary_damage and popped.size()>0 and pop_detach>0,"route needed recovery or missed real damage/carrier pop detach")
		check(hp_damage==70 and shot_hits==70 and lethal>=0 and down==lethal+1 and done>down and drop_coins==14,"ordinary-input harvester defeat incomplete")
	else:
		check(continued and falls==3 and hp_damage==0 and runtime.hayride.harvester.hp==70 and not runtime.hayride.harvester.dead,"live-harvester Continue/clear incomplete")
		check(popped.is_empty() and alive>0,"no-shoot clear unexpectedly killed every actor")
	check(JSON.stringify(game.meta)==imported,"immutable imported metadata changed")
	var saved: Dictionary = SaveStore.read_save()
	check(saved.get("cleared",{}).get("3-5",false) and saved.get("receipts",{}).get("3-5",[])==[0,1,2],"earned clear/receipts missing on disk")
	check(saved.get("skills",[]).is_empty() and saved.get("kitty",0)==game.score,"unearned skills/bank mismatch")
	var banked := JSON.stringify(saved)
	var final_score: int = game.score
	for idle in range(180): game.step(DT,{})
	check(game.score==final_score and JSON.stringify(SaveStore.read_save())==banked,"postclear duplicate banking")
	game.save = saved
	check(game.load_level("3-5"),"fresh replay failed")
	check(game.player==Vector2(300,402) and game.world_three.trailer.row[0]==60 and game.world_three.trailer.row[1]==540 and game.world_three.trailer.dx==0 and game.world_three.hayride.harvester.is_empty(),"translated trailer/harvester leaked into fresh replay")
	check(game.receipts.all(func(r): return not r.taken) and SaveStore.read_save().receipts["3-5"]==[0,1,2],"fresh finds versus earned save changed")
	print("Hay ride [",character," ","defeat" if defeat else "live/Continue","] ","PASS" if failures.is_empty() else "FAIL"," ticks=",ticks," dispatch=",dispatched," k/d=",carrier_count,"/",flyer_count," popped=",popped.size()," retired=",retired.size()," culled=",culled.size()," timeout=",timed_out.size()," scene_removed=",scene_removed.size()," live=",alive," hops/landed=",hops.size(),"/",landed.size()," pop_detach=",pop_detach," drones/cleaned=",drones.size(),"/",cleaned_drones.size()," receipts=",receipts," branches=",ducked.size()," branch_contacts=",branch_contacts," jumps/falls=",jumps,"/",falls," carry/air=",carried,"/",air_no_carry," contacts=",contacts," wipe=",wipe_start,"/",wipe_mid,"/",wipe_end," harvester=",harv_start,"/",lethal,"/",down,"/",done," damage/hits/drops=",hp_damage,"/",shot_hits,"/",drop_coins," ending=",ending," score=",final_score," failures=",failures)
	return failures.is_empty()
