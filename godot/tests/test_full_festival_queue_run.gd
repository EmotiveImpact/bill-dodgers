extends SceneTree
## Input-only Queue jump routes. Invulnerability is the sole progression assist.
const SaveStore = preload("res://src/save_store.gd")
const DT := 1.0/60.0
const MAX_TICKS := 16000
const WAVE_AT := [900,2800,4700,6600,8500,10400,12300,14200,16100,18000,19900,21800,23700,25600,27500]
var failures: Array[String] = []
var trace := false
var receipt_jump := false
var receipt_airborne := false

func _initialize() -> void: call_deferred("run")
func check(ok: bool, why: String) -> void:
	if not ok and why not in failures: failures.append(why)
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	if not game.has_method("step"):
		printerr("Queue main script did not load")
		game.free()
		quit(1)
		return
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	var chars: Array = game.CHARACTERS
	for arg in OS.get_cmdline_user_args():
		if arg == "--trace": trace = true
		if arg == "--jp-only": chars = ["jp"]
		if arg.begins_with("--character="): chars = [arg.trim_prefix("--character=")]
	var passed := true
	for character in chars:
		if character not in game.CHARACTERS or not run_character(game,character): passed = false
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)

func controls_for(game) -> Dictionary:
	var c := {"left":false,"right":false,"down":false,"jump":false,"shoot":true,"aim":false,"special":false}
	if game.world_three.wiping: return c
	if receipt_jump:
		if not game.grounded: receipt_airborne = true
		if receipt_airborne and game.grounded:
			receipt_jump = false
			receipt_airborne = false
		else: return c
	c.right = game.player.x < game.camera.x+320
	# Banners stop ordinary walking while ducked. The source's scrolling
	# left clamp legitimately carries a crouching player under each banner.
	for row in game.level.duck:
		if game.player.x >= row[0]-20 and game.player.x <= row[1]+12:
			c.down = true
			return c
	# Receipt centers are reached by ordinary ground/crowd jumps. Wait above
	# the center until picked, then resume walking. No pickup edits.
	for receipt in game.receipts:
		if not receipt.taken and absf(receipt.position.x-game.player.x) < 20:
			c.right = false
			c.jump = game.grounded and not game.jump_held
			if c.jump: receipt_jump = true
			return c
	if game.grounded and not game.jump_held:
		for gap in game.level.gaps:
			if gap[0]-game.player.x > 0 and gap[0]-game.player.x < 30:
				c.jump = true
				c.right = true
		for row in game.level.solids:
			if row[2] < game.player.y-6 and row[0]-game.player.x >= 0 and row[0]-game.player.x < 62:
				c.jump = true
				c.right = true
	if not game.grounded: c.right = true
	return c

func run_character(game, character: String) -> bool:
	failures.clear()
	receipt_jump = false
	receipt_airborne = false
	game.character = character
	game.save = {"schema":1,"receipts":{}}
	check(SaveStore.write_save(game.save) == OK,"fresh isolated save failed")
	check(game.load_level("3-2"),"3-2 load failed")
	check(game.is_native_supported() and game._native_world_three(),"3-2 native integration pending; no gate bypass")
	if not failures.is_empty():
		printerr("Queue [",character,"] BLOCKED: ",failures)
		return false
	check(game.player == Vector2(320,482) and game.camera == Vector2.ZERO,"source start changed")
	check(game.movement_skills.skills.is_empty() and game.abilities.skills.is_empty(),"unearned skills")
	check(game.level.w == 30000 and game.level.gaps.size() == 6 and game.level.duck.size() == 6,"source course inventory changed")
	check(game.combat.waves.size() == 15,"source15waves missing")
	check(game.receipts.size() == 3 and game.receipts[0].position == Vector2(6000,272) and game.receipts[1].position == Vector2(16500,272) and game.receipts[2].position == Vector2(25000,262),"source receipt centers changed")
	var planned := 0
	for i in range(game.combat.waves.size()):
		check(game.combat.waves[i].at == WAVE_AT[i],"wave trigger changed")
		planned += game.combat.waves[i].group.size()
	check(planned == 51,"source51solo entries missing")
	var imported := JSON.stringify(game.meta)
	var seen: Array = []
	var popped: Array = []
	var retired: Array = []
	var culled: Array = []
	var timed_out: Array = []
	var scene_removed: Array = []
	var unknown: Array = []
	var authored: Array[Vector2] = []
	var receipts: Array[int] = []
	var gaps: Array[int] = []
	var ducked: Array[int] = []
	var carried: Array[int] = []
	var jumps := 0
	var falls := 0
	var contacts := 0
	var banner_contacts := 0
	var dispatched := 0
	var failed_placements := 0
	var auto_frames := 0
	var warmup_frames := 0
	var wipe_frames := 0
	var wipe_start := -1
	var wipe_mid := -1
	var wipe_end := -1
	var checkpoint := -1
	var ending := -1
	var ticks := 0
	for frame in range(MAX_TICKS):
		ticks = frame+1
		game.invincible = 999 # Sole explicit assist, including hazard contacts.
		var c := controls_for(game)
		var p0: Vector2 = game.player
		var cam0: float = game.camera.x
		var grounded0: bool = game.grounded
		var scene0: int = game.world_three.scene_index
		var wiping0: bool = game.world_three.wiping
		var end0: float = game.world_three.end_time
		var old_indices: Array = game.combat.waves.map(func(w): return w.index)
		var score0: int = game.score
		var coins0: Array = game.coins.duplicate()
		game.step(DT,c)
		if grounded0 and not game.grounded and game.velocity.y < 0: jumps += 1
		if p0.y > 650 and game.player.y < p0.y-100 and scene0 == game.world_three.scene_index: falls += 1
		if scene0 == game.world_three.scene_index:
			if trace and absf(game.player.x-p0.x) >= 25: print("Queue recovery frame=",frame," before=",p0," after=",game.player," camera=",game.camera," controls=",c)
			check(absf(game.player.x-p0.x) < 25,"unexpected teleport/fall outside scene")
			if wiping0:
				wipe_frames += 1
				check(game.camera.x == cam0,"auto camera moved during wipe")
			elif game.world_three.level_time <= 1.8:
				warmup_frames += 1
				check(game.camera.x == cam0,"auto camera moved during warmup")
			elif end0 > 0: check(game.camera.x == cam0,"auto camera moved during ending")
			elif cam0 < 29262-140*DT:
				auto_frames += 1
				check(absf(game.camera.x-cam0-140*DT) < 0.001,"auto camera is not140px/s")
		for i in range(game.level.gaps.size()):
			var gap: Array = game.level.gaps[i]
			if p0.x <= gap[1] and game.player.x > gap[1] and scene0 == game.world_three.scene_index and game.player.y <= 482 and i not in gaps: gaps.append(i)
		for i in range(game.level.duck.size()):
			var row: Array = game.level.duck[i]
			if game.player.x > row[0] and game.player.x < row[1]:
				if game.crouching and i not in ducked: ducked.append(i)
			if game.world_three.queue_rush.banner_hits(row,game.player,game.character_height(),game.player_animation): banner_contacts += 1
		for i in range(game.level.solids.size()):
			var row: Array = game.level.solids[i]
			if not row[3].has("conv"): continue
			if grounded0 and game.grounded and absf(p0.y-row[2]) < 0.01 and p0.x > row[0]+20 and game.player.x < row[1]-20 and scene0 == game.world_three.scene_index and not wiping0:
				var movement := 270.0 if c.right and not game.crouching else 0.0
				if absf(game.player.x-p0.x-(movement+120)*DT) < 0.01 and i not in carried: carried.append(i)
		var new_count := 0
		for enemy in game.enemies:
			if enemy not in seen:
				seen.append(enemy)
				new_count += 1
			if enemy.state != "pop" and absf(enemy.p.x-game.player.x) < 44 and game.player.y > enemy.p.y-95 and game.player.y < enemy.p.y+24: contacts += 1
		for enemy in seen:
			if enemy.state == "pop" and enemy not in popped: popped.append(enemy)
			if enemy in game.enemies or enemy in popped or enemy in retired or enemy in culled or enemy in timed_out or enemy in scene_removed or enemy in unknown: continue
			if enemy.get("lost",false):
				retired.append(enemy)
				check(float(enemy.age)-float(enemy.get("hit_age",0)) > 12,"premature12s retirement")
			elif not enemy.entered and enemy.get("wait",0) > 6: timed_out.append(enemy)
			elif scene0 != game.world_three.scene_index: scene_removed.append(enemy)
			elif enemy.p.x <= game.camera.x-400 or enemy.p.x >= game.camera.x+game.view_width()+400: culled.append(enemy)
			else: unknown.append(enemy)
		var frame_dispatch := 0
		for i in range(15): frame_dispatch += game.combat.waves[i].index-old_indices[i]
		dispatched += frame_dispatch
		failed_placements += maxi(0,frame_dispatch-new_count)
		for coin in game.coins:
			if coin.get("stay",false) and absf(coin.age-0.3) < 0.00001 and coin.p not in authored: authored.append(coin.p)
		for i in range(3):
			if game.receipts[i].taken and i not in receipts:
				receipts.append(i)
				check(game.world_three.finds_near(game,game.receipts[i].position),"receipt collected without actual overlap")
				check(game.score-score0 == coins0.filter(func(coin): return coin.get("dead",false)).size(),"receipt awarded noncoin currency")
				if i < 2: check(not game.grounded and game.player.y < 482,"high receipt collected without actual jump")
				if trace: print("Queue receipt",i," frame=",frame," player=",game.player)
		if game.world_three.checkpoint_done and checkpoint < 0:
			checkpoint = frame
			check(game.player.x > 14300 and game.hearts == 3 and absf(game.invincible-1.5) < 0.001,"source checkpoint changed")
		if game.world_three.wiping and wipe_start < 0:
			wipe_start = frame
			check(game.world_three.wipe_label == "Into the arena" and game.world_three.wipe_kind == "iris","wrong scene label/kind")
			check(game.world_three.wipe_elapsed == 0,"trigger frame advanced wipe clock")
		if scene0 != game.world_three.scene_index:
			wipe_mid = frame
			check(game.camera.x == 15300 and game.world_three.scene_index == 1,"source scene destination changed")
			check(game.enemies.is_empty() and game.bullets.is_empty(),"scene failed to clear actors")
			check(game.world_three.wipe_elapsed >= 1.43 and game.world_three.wipe_elapsed < 1.43+DT+0.0001,"source1.43s wipe midpoint changed")
		if wiping0 and not game.world_three.wiping:
			wipe_end = frame
			check(absf(game.world_three.wipe_elapsed-2.17) < 0.0001,"source2.17s wipe duration changed")
		if game.world_three.end_time > 0 and ending < 0: ending = frame
		if trace and frame%600 == 0: print("Queue frame=",frame," p=",game.player," cam=",game.camera," receipts=",receipts," gaps=",gaps)
		if game.mode != "play": break
	check(game.mode == "clear","no actual timed clear")
	check(dispatched == 51 and game.combat.waves.all(func(w): return w.started and w.done and w.index == w.group.size()),"not all15waves/51entries dispatched")
	check(seen.size()+failed_placements == dispatched,"spawn accounting unbalanced")
	check(unknown.is_empty(),"unclassified enemy removal")
	var alive := seen.filter(func(e): return e in game.enemies and e not in popped).size()
	check(popped.size()+retired.size()+culled.size()+timed_out.size()+scene_removed.size()+unknown.size()+alive == seen.size(),"enemy outcome accounting unbalanced")
	check(gaps.size() == 6 and ducked.size() == 6 and carried.size() == 5,"missing gap/duck/crowd traversal")
	check(falls == 0,"route fell and used recovery")
	check(banner_contacts == 0,"route contacted banner collision geometry")
	check(not popped.is_empty(),"ordinary input shooting never popped enemies")
	check(receipts == [0,1,2],"three receipts not actually collected")
	check(authored.size() == 80 and authored_coins_match(game.level.coinRows,authored),"80exact coin seeds not observed")
	check(warmup_frames > 0 and auto_frames > 0 and wipe_frames > 0,"warmup/auto/wipe observations missing")
	check(checkpoint >= 0 and wipe_start >= 0 and wipe_mid > wipe_start and wipe_end > wipe_mid,"scene/checkpoint timeline incomplete")
	check(ending >= 0 and ticks-1-ending >= 155 and ticks-1-ending <= 157,"source2.6s final timer changed")
	check(JSON.stringify(game.meta) == imported,"imported source mutated")
	check(game.world_three.stage_data.events_done == [0,1],"source camera announcements missing")
	check(absf(game.world_three.stage_data.end_run-(ticks-ending)*DT) < 0.001,"jar runner final animation clock changed")
	var saved: Dictionary = SaveStore.read_save()
	check(saved.get("cleared",{}).get("3-2",false) and saved.get("receipts",{}).get("3-2",[]) == [0,1,2],"disk clear/receipts missing")
	check(saved.get("skills",[]).is_empty() and saved.get("kitty",0) == game.score,"disk skills/bank mismatch")
	var banked := JSON.stringify(saved)
	var final_score: int = game.score
	for i in range(180): game.step(DT,{})
	check(game.score == final_score and JSON.stringify(SaveStore.read_save()) == banked,"postclear duplicate save/bank")
	var passed := failures.is_empty()
	print("Queue [",character,"] ","PASS" if passed else "FAIL"," ticks=",ticks," dispatch=",dispatched," failed=",failed_placements," seen=",seen.size()," pops=",popped.size()," retired=",retired.size()," culled=",culled.size()," timeout=",timed_out.size()," scene_removed=",scene_removed.size()," live=",alive," gaps=",gaps," ducks=",ducked," crowds=",carried," receipts=",receipts," coins=",authored.size()," contacts=",contacts," banner_collision_frames=",banner_contacts," jumps=",jumps," falls=",falls," wipe=",wipe_start,"/",wipe_mid,"/",wipe_end," ending=",ending," score=",game.score)
	if not passed: printerr("Queue failures: ",failures)
	return passed

func authored_coins_match(rows: Array, positions: Array[Vector2]) -> bool:
	var count := 0
	for row in rows:
		for i in range(int(row[3])):
			var expected := Vector2(float(row[0])+i*float(row[2]),float(row[1])-sin(i/float(maxi(1,int(row[3])-1))*PI)*float(row[4]))
			if not positions.any(func(p): return p.distance_to(expected) < 0.002): return false
			count += 1
	return positions.size() == count
