extends SceneTree
## Actual 2-4 input progression, not difficulty/device QA. Invulnerability is
## the sole assist and retains source block bounces. No actor, damage, wave,
## geometry, timer, spawn, ability-meter or skill edits are allowed in this run.
const SaveStore = preload("res://src/save_store.gd")
const DT := 1.0 / 60.0
const MAX_TICKS := 30000
const RECEIPTS := [[9000,312],[21000,312],[33000,312]]
const WAVE_AT := [2000,5100,8200,11300,14400,17500,20600,23700,26800,29900,33000,36100,39262]
const ENEMIES := {"cart":22,"throw":9,"rush":4,"drone":2,"flat":2,"big":1}
const BOOSTS := [[4884,5684],[10048,10848],[15435,16235],[20576,21376],[25619,26419],[30934,31734],[36237,37037]]
const BLOCKS := [[1500,482,62,84,"wet"],[2316,482,112,104,"pallet"],[3760,482,62,84,"wet"],[4465,482,96,44,"cones"],[6230,482,62,84,"wet"],[6556,482,62,84,"wet"],[7253,482,112,104,"pallet"],[8644,482,62,84,"wet"],[9489,482,96,44,"cones"],[11367,482,62,84,"wet"],[11661,482,62,84,"wet"],[12367,482,112,104,"pallet"],[14085,482,62,84,"wet"],[14860,482,96,44,"cones"],[16738,482,62,84,"wet"],[17148,482,62,84,"wet"],[17848,482,112,104,"pallet"],[19411,482,62,84,"wet"],[20069,482,96,44,"cones"],[21853,482,62,84,"wet"],[22242,482,62,84,"wet"],[23023,482,112,104,"pallet"],[24471,482,62,84,"wet"],[25250,482,96,44,"cones"],[27004,482,62,84,"wet"],[27362,482,62,84,"wet"],[28232,482,112,104,"pallet"],[29753,482,62,84,"wet"],[30513,482,96,44,"cones"],[32241,482,62,84,"wet"],[32774,482,62,84,"wet"],[33472,482,112,104,"pallet"],[34951,482,62,84,"wet"],[35816,482,96,44,"cones"],[37564,482,62,84,"wet"],[38087,482,62,84,"wet"]]
const LOWS := [[3029,482,128,0,2],[5890,482,128,0,0],[8018,482,128,0,0],[11027,482,128,0,1],[13238,482,128,0,1],[16398,482,128,0,2],[18635,482,128,0,2],[21513,482,128,0,0],[23816,482,128,0,0],[26664,482,128,0,1],[28997,482,128,0,1],[31901,482,128,0,2],[34165,482,128,0,2],[37224,482,128,0,0]]
var failures: Array[String] = []
var debug_run := false

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	if not game.has_method("step"):
		printerr("Trolley dash input run: main script did not load")
		game.free()
		quit(1)
		return
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	var characters: Array = game.CHARACTERS
	var args := OS.get_cmdline_user_args()
	if "--jp-only" in args: characters = ["jp"]
	for arg in args:
		if arg.begins_with("--character="):
			var selected := arg.trim_prefix("--character=")
			if selected not in game.CHARACTERS:
				printerr("Unknown housemate: ",selected)
				game.queue_free()
				await process_frame
				quit(1)
				return
			characters = [selected]
	debug_run = "--trace" in args
	var passed := run_elapsed_par_fixture(game)
	for character in characters:
		if not run_character(game,character): passed = false
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)

func check(condition: bool, message: String) -> void:
	if not condition and message not in failures: failures.append(message)

func source_equal(actual: Variant, expected: Variant) -> bool:
	if actual is Array and expected is Array:
		if actual.size() != expected.size(): return false
		for i in range(actual.size()):
			if not source_equal(actual[i],expected[i]): return false
		return true
	if (actual is int or actual is float) and (expected is int or expected is float): return absf(float(actual)-float(expected)) < 0.00001
	return actual == expected

func source_rows(level: Dictionary, kind: String) -> Array:
	var rows: Array = []
	for hazard in level.hz:
		if hazard[0] == kind: rows.append(hazard.slice(1))
	return rows

func run_elapsed_par_fixture(game) -> bool:
	# NONPROGRESSION fixture: no movement/firing for211s. The camera and all
	# source threats continue. Invulnerability prevents death, not the clock.
	failures.clear()
	game.character = "jp"
	game.save = {"schema":1,"receipts":{}}
	check(SaveStore.write_save(game.save) == OK, "par fixture fresh save failed")
	check(game.load_level("2-4") and game.is_native_supported() and game._native_world_two(), "par fixture requires native2-4")
	if failures.is_empty():
		var source_geometry := JSON.stringify(game.level)
		for frame in range(12660):
			game.invincible = 999
			game.step(DT,{})
			check(game.mode == "play", "elapsed3:30 HUD incorrectly ended the course")
		check(game.elapsed > 210 and game.camera.x > 20000 and game.camera.x < 39260, "par fixture did not actually pass210s before the distance end")
		check(game.world_two.end_time == 0 and not game.world_two.clear_reported, "par fixture invented a timed finish")
		check(not SaveStore.read_save().get("cleared",{}).get("2-4",false), "par fixture wrote an unearned clear")
		check(JSON.stringify(game.level) == source_geometry and game.movement_skills.skills.is_empty() and game.abilities.skills.is_empty(), "par fixture altered course/skills")
	var passed := failures.is_empty()
	print("Trolley elapsed-par NONPROGRESSION fixture: ","PASS" if passed else "FAIL"," elapsed=",snappedf(game.elapsed,0.01)," camera=",game.camera.x," mode=",game.mode)
	if not passed: printerr("Trolley elapsed-par failures: ",failures)
	return passed

func run_character(game, character: String) -> bool:
	failures.clear()
	game.character = character
	game.save = {"schema":1,"receipts":{}}
	check(SaveStore.write_save(game.save) == OK, "fresh isolated save failed")
	check(not SaveStore.read_save().get("cleared",{}).get("2-4",false), "stale trolley dash clear")
	check(SaveStore.read_save().get("skills",[]).is_empty(), "stale earned skills")
	check(game.load_level("2-4"), "2-4 did not load")
	check(game.is_native_supported() and game._native_world_two(), "2-4 is still a preview or has the wrong runtime")
	check(game.player == Vector2(330,482) and game.camera == Vector2.ZERO, "source starting position changed")
	check(game.level.w == 40000 and game.view_width() == 738 and game.level.auto == 0.2 and game.level.ride == 30, "source width/auto speed/trolley offset changed")
	check(source_equal(game.level.solids,[[-400,40400,482]]) and game.level.plats.is_empty(), "source flat solid/no-platform course changed")
	check(source_equal(game.level.receipts,RECEIPTS) and game.receipts.size() == 3, "source receipts changed")
	check(source_equal(source_rows(game.level,"block"),BLOCKS), "all36 authored blocks required")
	check(source_equal(source_rows(game.level,"low"),LOWS), "all14 authored low signs required")
	check(source_equal(source_rows(game.level,"boost"),BOOSTS), "all7 authored boosts required")
	check(source_equal(source_rows(game.level,"trolleys"),[[19500,7,750,1],[31000,4,900,-1]]), "source7+4 runaway trolley batches changed")
	check(source_rows(game.level,"coins").size() == 43, "source43 coin rows required")
	check(game.level.check == 20000 and game.level.get("scenes",[]).is_empty() and game.crates.is_empty(), "invented scene/crate or changed checkpoint")
	check(game.movement_skills.skills.is_empty() and game.abilities.skills.is_empty(), "run inherited earned skills")
	check(game.combat.waves.size() == 13, "expected all13 source waves")
	if not failures.is_empty():
		printerr("Trolley dash input run [",character,"]: FAIL ",failures)
		return false
	check(game.world_two.unsupported_hazards.is_empty(), "course still contains unsupported hazards")
	check(game.world_two.course_controller.speed == 200, "source initial camera speed changed")
	for i in range(13):
		check(game.combat.waves[i].at == WAVE_AT[i], "wave camera trigger changed: %d" % i)
		check(game.combat.waves[i].group == game.level.waves[i].g, "solo source group changed: %d" % i)
		var expected_group: Array = [[0,"r","cart"],[900,"l","cart"],[1700,"r","throw"]]
		if i%3 == 1: expected_group = [[0,"r","throw"],[800,"r","cart"],[1600,"r","drone" if i in [1,7] else "flat"]]
		elif i%3 == 2: expected_group = [[0,"l","cart"],[700,"r","rush"],[1500,"r","cart"]]
		if i == 12: expected_group = [[0,"r","cart"],[500,"l","cart"],[1200,"r","throw"],[2000,"r","big"]]
		check(source_equal(game.combat.waves[i].group,expected_group), "authored solo delays/sides/kinds changed: %d" % i)
	check(source_equal(game.combat.waves[12].group,[[0,"r","cart"],[500,"l","cart"],[1200,"r","throw"],[2000,"r","big"]]), "final security wave changed")
	var source_geometry := JSON.stringify(game.level)
	var started: Array[int] = []
	var completed: Array[int] = []
	var collected: Array[int] = []
	var seen_enemies: Array = []
	var seen_trolleys: Array = []
	var spawners: Array = game.world_two.entities.filter(func(e): return e.k == "tspawn")
	var last_trolley_frame := [-1,-1]
	var seen_coins: Array[Vector2] = []
	var failed_spawns: Array = []
	var lost_enemies: Array = []
	var crossed_blocks: Array[int] = []
	var airborne_blocks: Array[int] = []
	var jumped_blocks: Array[int] = []
	var ducked_signs: Array[int] = []
	var sign_contact_frames := 0
	var block_contacts := 0
	var block_bounces := 0
	var trolley_contacts := 0
	var boost_entries: Array[int] = []
	var boost_exits: Array[int] = []
	var wave_slow_frames := 0
	var push_frames := 0
	var pressure_frames := 0
	var speed_min := 200.0
	var speed_max := 200.0
	var ordinary_damage := false
	var specials := 0
	var jumps := 0
	var aim_frames := 0
	var down_frames := 0
	var ticks := 0
	var consumed := 0
	var ending_frame := -1
	var final_death_frame := -1
	var checkpoint_frame := -1
	var exit_score := -1
	var par_passed := false
	for frame in range(MAX_TICKS):
		ticks = frame+1
		game.invincible = 999 # Sole assist; source inv>1.4s block bounce still applies.
		var controls := controls_for(game,frame)
		var before: Vector2 = game.player
		var camera_before: Vector2 = game.camera
		var speed_before: float = game.world_two.course_controller.speed
		var wave_before: bool = game.combat.waves.any(func(w): return w.started and not w.done)
		var active_before: String = game.abilities.active
		var ground_before: bool = game.grounded
		var held_before: bool = game.jump_held
		var indices: Array[int] = []
		for wave in game.combat.waves: indices.append(wave.index)
		var trolley_counts: Array[int] = []
		for spawner in spawners: trolley_counts.append(spawner.done)
		var hp_before: Array = []
		for enemy in game.enemies: hp_before.append([enemy,enemy.hp,enemy.state])
		var normal_only: bool = game.abilities.active.is_empty() and not controls.special and game.abilities.effects.is_empty() and game.bullets.all(func(b): return b.enemy or b.get("kind","") == character)
		if game.mode == "play": exit_score = game.score+game.coins.size()
		game.step(DT,controls)
		if active_before.is_empty() and not game.abilities.active.is_empty():
			specials += 1
			check(game.abilities.active == character, "another housemate's special activated")
		if ground_before and controls.jump and not held_before and not controls.down and not game.grounded:
			jumps += 1
			for i in range(BLOCKS.size()):
				if BLOCKS[i][0]-before.x > 0 and BLOCKS[i][0]-before.x < 160 and i not in jumped_blocks: jumped_blocks.append(i)
		if controls.aim: aim_frames += 1
		if controls.down: down_frames += 1
		for row in hp_before:
			if normal_only and row[0].hp < row[1]: ordinary_damage = true
			if row[2] != "pop" and row[0].state == "pop" and started.size() == 13: final_death_frame = frame
		check(absf(game.player.x-before.x) < 20 and game.player.y <= 482.01, "unexpected teleport/fall recovery")
		check(game.boss == null and not game.world_two.wiping and not game.bus_ride.enabled, "invented boss/scene/fixed bus ride")
		check(game.camera_lock == null and game.camera_speed == 0, "automatic course incorrectly locked/followed camera")
		check(game.world_two.surfaces(game).size() == 1 and not game.on_platform, "block/trolley became a supporting platform")
		var boost_index := -1
		var probe: float = camera_before.x+738*0.4
		for i in range(BOOSTS.size()):
			if probe > BOOSTS[i][0] and probe < BOOSTS[i][1]: boost_index = i
			if probe >= BOOSTS[i][1] and i in boost_entries and i not in boost_exits: boost_exits.append(i)
		if boost_index >= 0 and boost_index not in boost_entries: boost_entries.append(boost_index)
		var push := clampf(((game.player.x-camera_before.x)/738-0.5)*400,0,120)
		var want := 200*(1.55 if boost_index >= 0 else 1.0)*(0.6 if wave_before else 1.0)+push
		var expected_speed := speed_before+(want-speed_before)*minf(1,DT/0.7)
		check(absf(game.world_two.course_controller.speed-expected_speed) < 0.0001, "source boost/wave/push smoothing recurrence changed")
		check(absf(game.camera.x-minf(39262,camera_before.x+expected_speed*DT)) < 0.005, "source automatic camera displacement changed")
		check(game.world_two.course_controller.boost == (boost_index >= 0), "source camera+.4view boost probe changed")
		if wave_before: wave_slow_frames += 1
		if push > 1: push_frames += 1
		if not controls.left and not controls.right and game.player.x > before.x+0.1: pressure_frames += 1
		speed_min = minf(speed_min,game.world_two.course_controller.speed)
		speed_max = maxf(speed_max,game.world_two.course_controller.speed)
		var new_enemies: Array = []
		for enemy in game.enemies:
			if enemy not in seen_enemies:
				seen_enemies.append(enemy)
				new_enemies.append(enemy)
				if enemy.kind == "big": check(enemy.big and enemy.max_hp == 24 and enemy.hw == 58 and enemy.hh == 186, "security bot changed")
				if enemy.kind in ["cart","drone"]: check(enemy.max_hp == 2 and not enemy.get("fly",false), "cart/drone source contract changed")
		for enemy in seen_enemies:
			if enemy.state != "pop" and enemy not in game.enemies and enemy not in lost_enemies: lost_enemies.append(enemy)
		for i in range(13):
			var wave: Dictionary = game.combat.waves[i]
			if wave.started and i not in started:
				started.append(i)
				check(game.camera.x >= WAVE_AT[i]-2, "wave began before source camera trigger")
			if wave.done and i not in completed:
				completed.append(i)
				check(wave.index == wave.group.size() and not game.enemies.any(func(e): return e.state != "pop"), "wave ended before entries/deaths")
				if i == 12: check(final_death_frame >= 0 and frame == final_death_frame+1, "final wave did not complete one frame after last death")
				if debug_run: print("Trolley wave ",i," done frame=",frame," camera=",game.camera," p=",game.player)
			if wave.index > indices[i]:
				var dispatched: Array = wave.group.slice(indices[i],wave.index)
				consumed += dispatched.size()
				if new_enemies.size() < dispatched.size(): failed_spawns.append({"wave":i,"entries":dispatched,"frame":frame,"camera":game.camera,"player":game.player})
				for entry in dispatched: check(wave.t >= float(entry[0])/1000 and wave.t <= float(entry[0])/1000+DT+0.00001, "source enemy dispatch timing changed")
		for i in range(spawners.size()):
			var spawner: Dictionary = spawners[i]
			if spawner.done == trolley_counts[i]: continue
			check(spawner.done == trolley_counts[i]+1, "trolley batch emitted multiple entities in one frame")
			if last_trolley_frame[i] < 0:
				check(camera_before.x < spawner.at and game.camera.x >= spawner.at and spawner.done == 1, "first trolley did not spawn immediately at source camera threshold")
			else: check(frame-last_trolley_frame[i] == (45 if i == 0 else 54), "source750/900ms trolley interval changed")
			last_trolley_frame[i] = frame
		for entity in game.world_two.entities:
			if entity.k != "trolley": continue
			if entity not in seen_trolleys:
				seen_trolleys.append(entity)
				check(absf(entity.t-DT) < 0.00001 and absf(entity.v.x) >= 360 and absf(entity.v.x) <= 440, "runaway trolley spawn age/speed changed")
				var spawn_x: float = game.camera.x+(828 if entity.v.x < 0 else -90)
				check(absf(entity.p.x-(spawn_x+entity.v.x*DT)) < 0.005 and entity.p.y == 482, "runaway trolley source entry changed")
			if absf(game.player.x-entity.p.x) < 46 and game.player.y > entity.p.y-86 and game.player.y < entity.p.y+20: trolley_contacts += 1
		for i in range(BLOCKS.size()):
			var h: Array = BLOCKS[i]
			if before.x < h[0] and game.player.x >= h[0] and i not in crossed_blocks:
				crossed_blocks.append(i)
				if game.player.y <= h[1]-h[3]+8: airborne_blocks.append(i)
			if absf(game.player.x-h[0]) < h[2]/2.0+12 and game.player.y > h[1]-h[3]+8 and game.player.y <= h[1]+4:
				block_contacts += 1
				if game.velocity.y == -700 and not game.grounded: block_bounces += 1
		for i in range(LOWS.size()):
			var h: Array = LOWS[i]
			if absf(game.player.x-h[0]) >= 52: continue
			var underside: float = h[1]-h[2]
			var stand_top: float = game.player.y-game.character_height()*0.86-12
			var duck_top: float = game.player.y-game.character_height()*0.56-12
			if game.grounded and game.crouching and stand_top < underside and duck_top >= underside and i not in ducked_signs: ducked_signs.append(i)
			var actual_top: float = duck_top if game.crouching else stand_top
			if actual_top < underside and game.player.y > underside-40: sign_contact_frames += 1
		for coin in game.coins:
			if coin.get("keep",false) and absf(coin.age-0.3) < 0.00001 and coin.p not in seen_coins: seen_coins.append(coin.p)
		for i in range(3):
			if game.receipts[i].taken and i not in collected:
				collected.append(i)
				check(absf(game.player.x-RECEIPTS[i][0]) < 42 and game.player.y > RECEIPTS[i][1]-30 and game.player.y-game.character_height() < RECEIPTS[i][1], "receipt lacked real source body contact")
				if debug_run: print("Trolley receipt ",i," frame=",frame," p=",game.player)
		if game.world_two.checkpoint_hit and checkpoint_frame < 0:
			checkpoint_frame = frame
			check(camera_before.x+369 < 20000 and game.camera.x+369 >= 20000 and game.hearts == 3, "source checkpoint threshold changed")
		if game.elapsed > 210 and game.mode == "play": par_passed = true
		if game.world_two.end_time > 0 and ending_frame < 0:
			ending_frame = frame
			check(completed.size() == 13 and game.camera.x >= 39260, "exit began before source distance/waves")
		if debug_run and frame%1200 == 0: print("Trolley trace [",character,"] frame=",frame," p=",game.player," camera=",game.camera," speed=",game.world_two.course_controller.speed," boost=",game.world_two.course_controller.boost," waves=",completed.size()," live=",game.enemies.filter(func(e): return e.state != "pop").map(func(e): return [e.kind,e.p,e.hp])," receipts=",collected)
		if game.mode in ["clear","over"]: break
	var exit_ticks := ticks-1-ending_frame if ending_frame >= 0 else -1
	check(game.mode == "clear", "bounded ordinary-input route did not clear")
	check(started.size() == 13 and completed.size() == 13 and consumed == 40, "all13 waves/40 authored entries did not run")
	check(failed_spawns.is_empty() and seen_enemies.size() == 40, "source spawn eligibility consumed an enemy without spawning it")
	for kind in ENEMIES: check(seen_enemies.filter(func(e): return e.kind == kind).size() == ENEMIES[kind], "actual source enemy inventory differs: "+kind)
	check(lost_enemies.is_empty() and seen_enemies.all(func(e): return e.state == "pop") and game.pop_count == 40, "enemy abandonment substituted for a defeat")
	check(collected == [0,1,2], "did not collect all3 actual receipts")
	check(crossed_blocks.size() == 36 and airborne_blocks.size() == 36 and jumped_blocks.size() == 36, "insufficient actual block traversal/voluntary jump coverage")
	check(ducked_signs.size() == 14 and sign_contact_frames == 0, "did not safely crouch through all14 standing-height signs")
	check(seen_trolleys.size() == 11 and seen_trolleys.filter(func(e): return e.v.x > 0).size() == 7 and seen_trolleys.filter(func(e): return e.v.x < 0).size() == 4, "source7+4 runaway trolleys missing")
	check(game.world_two.entities.filter(func(e): return e.k == "tspawn").all(func(e): return e.done == e.n), "runaway trolley batch unfinished")
	check(boost_entries.size() == 7 and boost_exits.size() == 7 and wave_slow_frames > 0 and push_frames > 0 and pressure_frames > 0 and speed_min < 180 and speed_max > 250, "variable camera speed/forward push/left-edge pressure not exercised")
	check(game.world_two.coins_done.size() == 43 and seen_coins.size() == 243, "all43 authored rows/243 coins did not appear")
	check(checkpoint_frame >= 0 and game.hearts == 3, "source checkpoint/sole assist failed")
	check(specials > 0 and jumps > 0 and ordinary_damage and down_frames > 0 and aim_frames > 0, "missing real special/jump/down/aim/ordinary projectile damage")
	check(exit_ticks == 155, "source2.6-second exit timing changed")
	check(game.score == exit_score, "clear did not bank actual remaining coins exactly once")
	check(JSON.stringify(game.level) == source_geometry, "runtime/test mutated imported source")
	check(game.movement_skills.skills.is_empty() and game.abilities.skills.is_empty(), "unearned skills appeared")
	var persisted: Dictionary = SaveStore.read_save()
	check(game.save.get("cleared",{}).get("2-4",false) and persisted.get("cleared",{}).get("2-4",false), "actual clear did not survive save reload")
	check(persisted.get("receipts",{}).get("2-4",[]) == [0,1,2] and persisted.get("kitty",0) == game.score, "actual receipts/reward did not survive save reload")
	check(persisted.get("skills",[]).is_empty(), "save contains unearned skills")
	var banked_score: int = game.score
	var banked_save := JSON.stringify(persisted)
	for frame in range(180): game.step(DT,{})
	check(game.score == banked_score and JSON.stringify(SaveStore.read_save()) == banked_save, "post-clear updates duplicated reward/save")
	var passed := failures.is_empty()
	print("Trolley dash input run [",character,"]: ","PASS" if passed else "FAIL"," ticks=",ticks," elapsed=",snappedf(game.elapsed,0.01)," waves=",completed.size(),"/13 enemies=",seen_enemies.size(),"/40 popped=",game.pop_count," receipts=",collected," blocks=",crossed_blocks.size(),"/36 airborne=",airborne_blocks.size()," jump_blocks=",jumped_blocks.size()," block_contacts=",block_contacts," bounces=",block_bounces," ducked=",ducked_signs.size(),"/14 sign_contacts=",sign_contact_frames," trolleys=",seen_trolleys.size(),"/11 trolley_contacts=",trolley_contacts," speed=",snappedf(speed_min,0.01),"..",snappedf(speed_max,0.01)," jumps=",jumps," specials=",specials," aim=",aim_frames," down=",down_frames," beyond_par=",par_passed," exit_ticks=",exit_ticks," mode=",game.mode)
	if not passed:
		printerr("Trolley failures [",character,"]: ",failures)
		printerr("Spawn failures: ",failed_spawns," lost=",lost_enemies," live=",game.enemies.filter(func(e): return e.state != "pop")," missed signs=",range(14).filter(func(i): return i not in ducked_signs)," missed blocks=",range(36).filter(func(i): return i not in jumped_blocks))
	return passed

func controls_for(game, frame: int) -> Dictionary:
	var c := {"left":false,"right":false,"jump":false,"down":false,"aim":false,"shoot":true,"special":false}
	var target: Dictionary = {}
	for enemy in game.enemies:
		if enemy.state == "pop": continue
		if target.is_empty() or absf(enemy.p.x-game.player.x) < absf(target.p.x-game.player.x): target = enemy
	var destination: float = game.camera.x+390
	if not target.is_empty():
		var dx: float = target.p.x-game.player.x
		destination = target.p.x-(150 if dx >= 0 else -150)
		if target.kind == "drone":
			destination = target.p.x-(100 if dx >= 0 else -100)
			c.aim = true
		if game.face != (1 if dx >= 0 else -1): destination = game.player.x+(10 if dx >= 0 else -10)
		if game.abilities.meter >= 1 and game.combat.waves.filter(func(w): return w.started and not w.done).all(func(w): return w.index == w.group.size()): c.special = true
	else:
		if frame%120 < 10: c.aim = true
	destination = clampf(destination,game.camera.x+75,game.camera.x+650)
	c.right = destination-game.player.x > 4
	c.left = destination-game.player.x < -4
	if not target.is_empty() and target.p.x < game.player.x and c.right: c.right = false
	if not target.is_empty() and target.p.x > game.player.x and c.left: c.left = false
	# Normal down lands Leo's glider before the next sign/dispatch. No y edits.
	if game.abilities.active == "leo" and not game.grounded: c.down = true
	# Let the continuously moving camera carry its ordinary left-edge clamp
	# through each sign while down prevents walking. This is not a fixed arena.
	for h in LOWS:
		if h[0]-game.player.x < 105 and h[0]-game.player.x > -60:
			c.down = true
			c.aim = false
			c.jump = false
			c.special = false
			return c
	for h in BLOCKS:
		var dx: float = h[0]-game.player.x
		var lead: float = 110 if h[4] == "pallet" else 80
		if dx > -float(h[2])/2-14 and dx < lead:
			c.right = true
			c.left = false
			c.aim = false
			if game.grounded and not game.jump_held and dx > 0:
				c.jump = true
				c.down = false
			return c
	for i in range(3):
		if game.receipts[i].taken: continue
		var dx: float = RECEIPTS[i][0]-game.player.x
		if dx < 100 and dx > -38:
			c.right = dx > 5
			c.left = dx < -5
			if game.grounded and not game.jump_held:
				c.jump = true
				c.down = false
			return c
	return c
