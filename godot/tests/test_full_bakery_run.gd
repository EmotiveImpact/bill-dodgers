extends SceneTree
## Input-driven 2-5 progression, not difficulty/device QA. Explicit invulnerability
## is the sole assist. It DOES retain the source wet-block bounce; no course bypass.
const SaveStore = preload("res://src/save_store.gd")
const DT := 1.0 / 60.0
const MAX_TICKS := 36000
const EXPECTED_WAVES := [0,1,2,3,4,5,6,7,8,9,10]
const WAVE_AT := [400,1700,3300,4800,6200,7200,8800,10600,12000,13300,14262]
const ENEMY_COUNTS := {"rush":19,"throw":11,"cart":5,"drone":4,"flat":3,"big":3}
const RECEIPTS := [[3350,352],[7600,292],[13600,370]]
const PLATFORMS := [[804,1296,370],[5004,5596,370],[9804,10496,370],[13204,13696,370],[2000,2900,352],[3300,4400,352],[6400,7400,352],[7800,8900,232],[7500,7700,292]]
const BELTS := [[2000,2900,352,-0.09],[3300,4400,352,-0.09],[6400,7400,352,0.1],[7800,8900,232,-0.08]]
const FLAMES := [[1920,482,2600,2200],[2440,482,2600,640],[2960,482,2600,1680],[3480,482,2600,120],[4000,482,2600,1160],[4520,482,2600,2200],[6320,482,2200,1000],[6780,482,2200,180],[7240,482,2200,1560],[7700,482,2200,740],[8160,482,2200,2120],[8620,482,2200,1300],[9080,482,2200,480]]
const BLOCKS := [[12600,482,62,84,"wet"],[14250,482,62,84,"wet"]]
const COINS := [[2050,2850,302,7,0],[3350,4350,302,8,0],[6450,7350,302,7,0],[7850,8850,182,8,0],[850,1250,322,4,0],[9850,10450,322,5,0],[13250,13650,322,4,0],[12900,13100,422,3,0]]
# Ground approaches at wave thresholds preserve the actual camera-dependent
# spawn search. The third belt is revisited after the two security bots so the
# card is earned via352 ->292 rack ->232 belt using only the ordinary jump.
const BAKEHOUSE_ROUTE := [Vector2(1100,370),Vector2(2050,352),Vector2(2830,352),Vector2(3350,352),Vector2(4330,352),Vector2(5300,370),Vector2(6500,482),Vector2(6500,352),Vector2(7320,352),Vector2(7350,482),Vector2(7660,482),Vector2(7350,352),Vector2(7380,352),Vector2(7600,292),Vector2(7665,292),Vector2(7850,232),Vector2(8850,232),Vector2(8870,482),Vector2(9400,482)]
const SHOP_ROUTE := [Vector2(10350,370),Vector2(10530,482),Vector2(11000,482),Vector2(12250,482),Vector2(12700,482),Vector2(13600,370),Vector2(13600,482),Vector2(14400,482),Vector2(14950,482)]
var failures: Array[String] = []
var debug_run := false
var route_step := 0
var route_scene := 0
var card_frame := -1
var live_double_jump_frame := -1
var double_jump_probe := 0
var recovery_rung := Vector2.INF
var recovery_target := Vector2.INF

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	if not game.has_method("step"):
		printerr("Bakery input run: main script did not load")
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
				printerr("Unknown housemate: ", selected)
				game.queue_free()
				await process_frame
				quit(1)
				return
			characters = [selected]
	debug_run = "--trace" in args
	var passed := true
	for character in characters:
		if not run_character(game, character): passed = false
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)

func check(condition: bool, message: String) -> void:
	if not condition and message not in failures: failures.append(message)

func source_equal(actual: Variant, expected: Variant) -> bool:
	if actual is Array and expected is Array:
		if actual.size() != expected.size(): return false
		for i in range(actual.size()):
			if not source_equal(actual[i], expected[i]): return false
		return true
	if (actual is int or actual is float) and (expected is int or expected is float):
		return absf(float(actual) - float(expected)) < 0.00001
	return actual == expected

func source_rows(level: Dictionary, kind: String) -> Array:
	var rows: Array = []
	for hazard in level.hz:
		if hazard[0] == kind: rows.append(hazard.slice(1))
	return rows

func run_character(game, character: String) -> bool:
	failures.clear()
	route_step = 0
	route_scene = 0
	card_frame = -1
	live_double_jump_frame = -1
	double_jump_probe = 0
	recovery_rung = Vector2.INF
	recovery_target = Vector2.INF
	game.character = character
	game.save = {"schema":1,"receipts":{}}
	check(SaveStore.write_save(game.save) == OK, "fresh isolated save failed")
	check(not SaveStore.read_save().get("cleared",{}).get("2-5",false), "stale bakery clear")
	check(SaveStore.read_save().get("skills",[]).is_empty(), "stale earned skill")
	check(game.load_level("2-5"), "2-5 did not load")
	check(game.is_native_supported() and game._native_world_two(), "2-5 is still a preview or has the wrong runtime")
	check(game.player == Vector2(300,482) and game.camera == Vector2.ZERO, "source starting position changed")
	check(game.level.w == 15000 and game.view_width() == 738, "source width/view changed")
	check(source_equal(game.level.solids,[[-400,15400,482]]) and source_equal(game.level.plats,PLATFORMS), "source one solid/nine platforms changed")
	check(source_equal(game.level.racks,[[7500,7700]]) and source_equal(game.level.counters,[[800,1300],[5000,5600],[9800,10500],[13200,13700]]), "source rack/four deli counters changed")
	check(source_equal(game.level.ovens,[1800,2320,2840,3360,3880,4400,6200,6660,7120,7580,8040,8500,8960]), "source thirteen oven bodies changed")
	check(source_equal(game.level.crates,[[1550,472,"split"],[4900,472,"heart"],[9500,472,"debit"],[12750,472,"heart"],[14000,472,"split"]]), "source five pickup crates changed")
	check(source_equal(game.level.receipts,RECEIPTS) and game.receipts.size() == 3, "source receipts changed")
	check(source_equal(game.level.card,[8850,232]), "source double-jump card changed")
	check(source_equal(game.level.scenes,[[9400,"door","Shop floor","Through the swing doors!"]]), "source swing-door scene changed")
	check(game.level.check == 9500 and game.level.start == 300, "source checkpoint/start changed")
	check(source_equal(source_rows(game.level,"belt"),BELTS), "source four conveyors changed")
	check(source_equal(source_rows(game.level,"flame"),FLAMES), "source thirteen oven flame positions/periods/offsets changed")
	check(source_equal(source_rows(game.level,"slow"),[[10800,12200,482]]), "source flour zone changed")
	check(source_equal(source_rows(game.level,"block"),BLOCKS), "source wet blocks changed")
	check(source_equal(source_rows(game.level,"coins"),COINS), "source eight coin rows changed")
	check(game.movement_skills.skills.is_empty() and game.abilities.skills.is_empty(), "run inherited movement skills")
	check(game.combat.waves.size() == 11, "expected all eleven source waves")
	if not failures.is_empty():
		printerr("Bakery input run [",character,"]: FAIL ",failures)
		return false
	check(game.world_two.unsupported_hazards.is_empty(), "bakery still has unsupported hazards")
	check(absf(game.world_two.camera_cap(game)-8962) < 0.01, "source door camera cap changed")
	for i in range(11):
		check(game.combat.waves[i].at == WAVE_AT[i], "wave trigger changed: %d" % i)
		check(game.combat.waves[i].group == game.level.waves[i].g, "solo group differs from source: %d" % i)
	check(source_equal(game.combat.waves[5].group,[[0,"r","big"],[1800,"l","big"],[4000,"r","rush"],[5600,"r","throw"]]), "two-security-bot wave changed")
	var source_geometry := JSON.stringify(game.level)
	var started: Array[int] = []
	var completed: Array[int] = []
	var collected: Array[int] = []
	var platforms: Array[int] = []
	var belt_frames := [0,0,0,0]
	var crossed_flames: Array[int] = []
	var hot_contacts := 0
	var flame_active_frames := 0
	var flame_warning_frames := 0
	var block_bounces := [0,0]
	var crossed_blocks: Array[int] = []
	var flour_frames := 0
	var flour_movement_frames := 0
	var seen_enemies: Array = []
	var seen_coin_positions: Array[Vector2] = []
	var ordinary_damage := false
	var specials := 0
	var jumps := 0
	var falls := 0
	var aim_frames := 0
	var down_frames := 0
	var ticks := 0
	var ending_frame := -1
	var wipe_start := -1
	var wipe_mid := -1
	var wipe_end := -1
	var wipe_motion := 0.0
	var checkpoint_frame := -1
	var boss_seen := false
	var consumed := 0
	var failed_spawns: Array = []
	for frame in range(MAX_TICKS):
		ticks = frame+1
		game.invincible = 999 # Sole assist; source blocks still bounce invulnerable players.
		var controls := controls_for(game,frame,wipe_start)
		var position_before: Vector2 = game.player
		var elapsed_before: float = game.elapsed
		var scene_before: int = game.world_two.scene_index
		var wipe_before: bool = game.world_two.wiping
		var active_before: String = game.abilities.active
		var grounded_before: bool = game.grounded
		var velocity_before: Vector2 = game.velocity
		var skill_before: bool = game.movement_skills.has_skill("double-jump")
		var jump_held_before: bool = game.jump_held
		var hp_before: Array = []
		for enemy in game.enemies: hp_before.append([enemy,enemy.hp])
		var indices: Array[int] = []
		for wave in game.combat.waves: indices.append(wave.index)
		var only_normal: bool = game.abilities.active.is_empty() and not controls.special and game.abilities.effects.is_empty() and game.bullets.all(func(b): return b.enemy or b.get("kind","") == character)
		game.step(DT,controls)
		if active_before.is_empty() and not game.abilities.active.is_empty():
			specials += 1
			check(game.abilities.active == character, "activated another housemate's special")
		if grounded_before and not game.grounded and game.velocity.y < 0 and controls.jump and not controls.down: jumps += 1
		if controls.aim: aim_frames += 1
		if controls.down: down_frames += 1
		for pair in hp_before:
			if only_normal and pair[0].hp < pair[1]: ordinary_damage = true
		boss_seen = boss_seen or game.boss != null
		if position_before.y > game.level.fall and game.player.y < position_before.y-100: falls += 1
		check(absf(game.player.x-position_before.x) < 20 or scene_before != game.world_two.scene_index, "unexpected teleport outside source door")
		if game.world_two.scene_index == 0:
			check(game.player.x <= 9400.01 and game.camera.x <= 8962.01, "crossed closed door/camera cap")
			check(not game.world_two.checkpoint_hit, "checkpoint triggered before source door")
		if game.world_two.wiping and wipe_start < 0:
			wipe_start = frame
			check(game.combat.waves.slice(0,7).all(func(w): return w.started and w.done) and game.combat.waves.slice(7).all(func(w): return not w.started), "door started before seven preceding waves cleared")
			check(game.player.x >= 9350 and game.player.x <= 9400, "door started outside source entry interval")
			check(game.world_two.wipe_kind == "door" and game.world_two.wipe_label == "Shop floor", "incorrect source wipe")
		if wipe_before:
			check(absf(game.elapsed-elapsed_before-DT) < 0.0001, "simulation paused during source door wipe")
			if scene_before == 0 and game.world_two.scene_index == 0: wipe_motion += absf(game.player.x-position_before.x)
		if scene_before != game.world_two.scene_index:
			wipe_mid = frame
			check(scene_before == 0 and game.world_two.scene_index == 1, "unexpected scene transition")
			check(game.world_two.wipe_elapsed >= 1.43 and game.world_two.wipe_elapsed < 1.43+DT+0.0001, "door midpoint is not source1.43 seconds")
			check(game.player == Vector2(9820,370) and game.grounded, "source door did not land on actual deli platform at(9820,370)")
			check(game.camera == Vector2(9660,0) and game.camera_speed == 0, "source door camera reset changed")
			check(game.velocity == Vector2.ZERO and game.bullets.is_empty(), "source door did not clear momentum/projectiles")
			check(not game.world_two.checkpoint_hit, "checkpoint ran after end-of-frame callback")
		if wipe_before and not game.world_two.wiping:
			wipe_end = frame
			check(game.world_two.scene_index == 1 and game.world_two.wipe_elapsed >= 2.17, "wipe ended before source duration")
		if game.world_two.checkpoint_hit and checkpoint_frame < 0:
			checkpoint_frame = frame
			check(wipe_mid >= 0 and frame == wipe_mid+1, "checkpoint did not trigger first update after callback")
			check(game.hearts == 3, "checkpoint did not leave full hearts")
		var new_enemies: Array = []
		for enemy in game.enemies:
			if enemy not in seen_enemies:
				seen_enemies.append(enemy)
				new_enemies.append(enemy)
				if debug_run: print("Bakery spawn ",enemy.kind," frame=",frame," p=",enemy.p)
				if enemy.kind == "big": check(enemy.big and enemy.max_hp == 24 and enemy.hw == 58 and enemy.hh == 186, "security bot lost solo24HP geometry")
				if enemy.kind == "drone": check(enemy.max_hp == 2 and not enemy.get("fly",false), "barcode drone has World1 contract")
				if enemy.kind == "cart": check(enemy.max_hp == 2, "cart bot source health changed")
		for i in range(11):
			var wave: Dictionary = game.combat.waves[i]
			if wave.started and i not in started: started.append(i)
			if wave.done and i not in completed:
				completed.append(i)
				check(wave.index == wave.group.size(), "wave finished before every entry dispatched")
				if debug_run: print("Bakery wave ",i," done frame=",frame," player=",game.player)
			consumed += wave.index-indices[i]
			if wave.index > indices[i]:
				var dispatched: Array = wave.group.slice(indices[i],wave.index)
				if debug_run: print("Bakery dispatch wave=",i," entries=",dispatched," frame=",frame," camera=",game.camera," player=",game.player)
				if new_enemies.size() < dispatched.size(): failed_spawns.append({"wave":i,"entries":dispatched,"frame":frame,"camera":game.camera,"player":game.player})
		if game.grounded:
			for i in range(PLATFORMS.size()):
				var platform: Array = PLATFORMS[i]
				if game.player.x >= platform[0] and game.player.x <= platform[1] and absf(game.player.y-platform[2]) < 0.1 and i not in platforms: platforms.append(i)
		for i in range(4):
			var belt: Array = BELTS[i]
			if grounded_before and position_before.x > belt[0] and position_before.x < belt[1] and absf(position_before.y-belt[2]) < 4: belt_frames[i] += 1
		for i in range(FLAMES.size()):
			var flame: Array = FLAMES[i]
			var hazard_elapsed: float = game.elapsed if game.mode == "play" else elapsed_before
			var phase := fposmod(hazard_elapsed*1000.0+flame[3],flame[2])/1000.0
			var row: Array = ["flame"]+flame
			check(absf(game.world_two.course_controller.flame_phase(row)-phase) < 0.0001, "oven phase stopped following source elapsed time")
			if phase < 1: flame_active_frames += 1
			if phase > float(flame[2])/1000.0-0.7: flame_warning_frames += 1
			if absf(game.player.x-flame[0]) < 36 and game.player.y > flame[1]-175 and game.player.y <= flame[1]+4 and phase < 1: hot_contacts += 1
			if position_before.x <= flame[0] and game.player.x > flame[0] and i not in crossed_flames: crossed_flames.append(i)
		for i in range(BLOCKS.size()):
			var block: Array = BLOCKS[i]
			if absf(game.player.x-block[0]) < float(block[2])/2+12 and game.player.y > block[1]-block[3]+8 and game.player.y <= block[1]+4:
				check(game.velocity.y == -700 and not game.grounded, "invulnerable wet-block contact lost source bounce")
				block_bounces[i] += 1
			if position_before.x <= block[0] and game.player.x > block[0] and i not in crossed_blocks: crossed_blocks.append(i)
		if grounded_before and position_before.x > 10800 and position_before.x < 12200 and absf(position_before.y-482) < 4:
			flour_frames += 1
			if (controls.left != controls.right) and not controls.down:
				var expected: float = (1 if controls.right else -1)*148.5
				check(absf(game.world_two.hazard_controller.ice_velocity.get(game.get_instance_id(),INF)-expected) < 0.0001, "flour lost source0.55 base movement factor")
				flour_movement_frames += 1
		for coin in game.coins:
			if not coin.get("keep",false): continue
			if absf(coin.age-0.3) < 0.00001 and coin.p not in seen_coin_positions: seen_coin_positions.append(coin.p)
			if coin.rest: check(coin.age <= 2.0001, "resting authored coin lost keep-age cap")
		for i in range(3):
			if game.receipts[i].taken and i not in collected:
				collected.append(i)
				check(absf(game.player.x-RECEIPTS[i][0]) < 42 and game.player.y > RECEIPTS[i][1]-30 and game.player.y-game.character_height() < RECEIPTS[i][1], "receipt collected without source overlap")
				if debug_run: print("Bakery receipt ",i," frame=",frame," player=",game.player)
		if not skill_before and game.movement_skills.has_skill("double-jump"):
			card_frame = frame
			check(game.world_two.scene_index == 0 and absf(game.player.x-8850) < 42 and game.player.y > 202 and game.player.y-game.character_height() < 232, "card awarded without actual source pickup")
			check(game.movement_skills.card_collected and game.movement_skills.skills == ["double-jump"] and game.abilities.skills == ["double-jump"], "card not delivered to both actual skill owners")
			check(SaveStore.read_save().get("skills",[]) == ["double-jump"], "earned card not persisted at actual pickup")
			if debug_run: print("Bakery card frame=",frame," player=",game.player)
		if "double-jump" in game.movement_skills.events:
			check(skill_before and card_frame >= 0 and frame > card_frame, "double jump occurred before earning card")
			check(not grounded_before and controls.jump and not controls.down and not jump_held_before and velocity_before.y > -900, "double jump did not use real fresh airborne input")
			check(game.velocity.y < -700 and game.player.y < position_before.y, "double jump did not change actual trajectory")
			if live_double_jump_frame < 0:
				live_double_jump_frame = frame
				if debug_run: print("Bakery double jump frame=",frame," player=",game.player)
		if game.world_two.end_time > 0 and ending_frame < 0:
			ending_frame = frame
			check(completed == EXPECTED_WAVES and game.camera.x >= 14260, "exit started before source endpoint/waves")
		if debug_run and frame%900 == 0: print("Bakery trace [",character,"] frame=",frame," route=",route_scene,"/",route_step," p=",game.player," camera=",game.camera," receipts=",collected," live=",enemy_summary(game))
		if game.mode in ["clear","over"]: break
	var exit_ticks := ticks-1-ending_frame if ending_frame >= 0 else -1
	check(game.mode == "clear", "bounded input route did not clear")
	check(started == EXPECTED_WAVES and completed == EXPECTED_WAVES, "all eleven waves did not start/finish in order")
	check(consumed == 45 and seen_enemies.size() == 45 and failed_spawns.is_empty(), "not all45 authored enemies actually spawned")
	for kind in ENEMY_COUNTS:
		check(seen_enemies.filter(func(e): return e.kind == kind).size() == ENEMY_COUNTS[kind], "source enemy count changed: "+kind)
	check(seen_enemies.all(func(e): return e.state == "pop" and e.hp <= 0), "an authored enemy escaped instead of being defeated")
	check(not boss_seen, "bakery invented a separate boss objective")
	check(collected == [0,1,2], "did not collect all three source receipts in route order")
	check(belt_frames.all(func(n): return n > 10) and platforms.size() == 9, "actual four conveyors/rack/four deli platform route missing")
	check(crossed_flames.size() == 13 and flame_active_frames > 0 and flame_warning_frames > 0 and hot_contacts > 0, "oven traversal/real active-warning phases missing")
	check(crossed_blocks == [0,1], "did not cross both actual wet-floor blocks")
	check(flour_frames > 200 and flour_movement_frames > 100, "actual flour movement missing")
	check(specials > 0 and jumps >= 8 and ordinary_damage and aim_frames > 0 and down_frames > 0, "missing actual special/jump/down/aim/ordinary damage coverage")
	check(falls == 0, "route relied on fall-safe recovery")
	check(wipe_start >= 0 and wipe_mid > wipe_start and wipe_end > wipe_mid and wipe_motion > 10, "source door/input simulation coverage missing")
	check(checkpoint_frame == wipe_mid+1, "source checkpoint not observed")
	check(game.world_two.coins_done.size() == 8 and seen_coin_positions.size() == 46, "not all8 rows/46 authored coins appeared once")
	check(authored_coin_positions_match(game.level.hz,seen_coin_positions), "authored coin positions differ from source")
	check(route_scene == 1 and route_step == SHOP_ROUTE.size(), "actual shop-floor route not completed")
	check(exit_ticks == 155, "source2.6-second exit timing changed")
	check(JSON.stringify(game.level) == source_geometry, "runtime/test mutated imported source data")
	check(card_frame >= 0 and live_double_jump_frame > card_frame, "card and subsequent actual double jump missing")
	check(game.movement_skills.skills == ["double-jump"] and game.abilities.skills == ["double-jump"], "unearned movement skills appeared")
	check(game.save.get("cleared",{}).get("2-5",false), "real clear missing in memory")
	var persisted: Dictionary = SaveStore.read_save()
	check(persisted.get("cleared",{}).get("2-5",false), "real clear missing after disk reload")
	check(persisted.get("receipts",{}).get("2-5",[]) == [0,1,2], "receipts missing after disk reload")
	check(persisted.get("skills",[]) == ["double-jump"], "earned card missing after disk reload")
	var remaining_live := enemy_summary(game)
	var end_position: Vector2 = game.player
	var end_mode: String = game.mode
	var reload_jump := verify_reloaded_skill(game,persisted)
	var passed := failures.is_empty()
	print("Bakery input run [",character,"]: ","PASS" if passed else "FAIL"," ticks=",ticks," waves=",completed.size(),"/11 enemies=",seen_enemies.size(),"/45 receipts=",collected," platforms=",platforms," belts=",belt_frames," coins=",seen_coin_positions.size(),"/46 flames=",crossed_flames.size()," hot_contacts=",hot_contacts," flour=",flour_frames," blocks=",crossed_blocks," block_bounces=",block_bounces," jumps=",jumps," specials=",specials," aim=",aim_frames," down=",down_frames," door=",wipe_start,"/",wipe_mid,"/",wipe_end," checkpoint=",checkpoint_frame," card=",card_frame," double_jump=",live_double_jump_frame," reloaded_jump=",reload_jump," exit_ticks=",exit_ticks," route=",route_scene,"/",route_step," player=",end_position," mode=",end_mode)
	if not passed:
		printerr("Bakery failures [",character,"]: ",failures)
		printerr("Remaining live enemies: ",remaining_live)
		printerr("Consumed source spawn failures: ",failed_spawns)
	return passed

func verify_reloaded_skill(game, persisted: Dictionary) -> bool:
	# Real level restart uses only the earned disk save. This is AFTER recording
	# the legitimate clear, never a mid-run shortcut or pre-earned-card setup.
	game.save = persisted
	check(game.load_level("2-5"), "earned-save level reload failed")
	check(game.movement_skills.skills == ["double-jump"] and game.abilities.skills == ["double-jump"], "earned skill did not reload in both owners")
	var observed := false
	for frame in range(30):
		game.invincible = 999
		var controls := {"left":false,"right":false,"jump":frame in [1,13],"down":false,"aim":false,"shoot":false,"special":false}
		var before: Vector2 = game.player
		var grounded_before: bool = game.grounded
		game.step(DT,controls)
		if "double-jump" in game.movement_skills.events:
			check(frame == 13 and not grounded_before and game.player.y < before.y and game.velocity.y < -700, "reloaded card did not cause actual airborne second jump")
			observed = true
	check(observed, "reloaded earned card did not work through fresh jump inputs")
	return observed

func enemy_summary(game) -> Array:
	var summary: Array = []
	for enemy in game.enemies:
		if enemy.state != "pop": summary.append([enemy.kind,enemy.p,enemy.hp,enemy.state])
	return summary

func authored_coin_positions_match(hazards: Array, positions: Array[Vector2]) -> bool:
	var expected := 0
	for h in hazards:
		if h[0] != "coins": continue
		for i in range(int(h[4])):
			var fraction := float(i)/float(h[4]-1) if h[4] > 1 else 0.5
			var point := Vector2(lerpf(h[1],h[2],fraction),float(h[3])-sin(PI*float(i)/maxf(1,h[4]-1))*float(h[5]))
			if not positions.any(func(p): return p.distance_to(point) < 0.002): return false
			expected += 1
	return positions.size() == expected

func walk_toward(game, controls: Dictionary, x: float, tolerance := 4.0) -> void:
	controls.right = x-game.player.x > tolerance
	controls.left = x-game.player.x < -tolerance

func navigate(game, controls: Dictionary, goal: Vector2) -> void:
	if recovery_target != goal:
		recovery_rung = Vector2.INF
		recovery_target = goal
	if recovery_rung != Vector2.INF and game.grounded and absf(game.player.x-recovery_rung.x) < 20 and absf(game.player.y-recovery_rung.y) < 1:
		recovery_rung = Vector2.INF
	if recovery_rung != Vector2.INF:
		goal = recovery_rung
	elif goal.y < game.player.y-145:
		var best := INF
		var rung := goal
		for row in PLATFORMS:
			if row[2] < game.player.y-140 or row[2] >= game.player.y-6 or row[2] <= goal.y: continue
			var x := clampf(goal.x,float(row[0])+30,float(row[1])-30)
			if x < game.camera.x+35 or x > game.camera.x+game.view_width()-35: continue
			var distance: float = absf(x-goal.x)+absf(x-game.player.x)*0.25
			if distance < best:
				best = distance
				rung = Vector2(x,row[2])
		if rung != goal: recovery_rung = rung
		goal = rung
	walk_toward(game,controls,goal.x)
	if not game.grounded or game.jump_held: return
	var dx: float = goal.x-game.player.x
	if goal.y < game.player.y-6 and absf(dx) < 110: controls.jump = true
	if goal.y > game.player.y+6 and game.on_platform and absf(dx) < 10:
		controls.down = true
		controls.jump = true
	# Raised rack/belt gaps require launching from the actual surface edge.
	if goal.y < game.player.y-6 and game.on_platform:
		var surface: Dictionary = game.world_two.below(game,game.player.x,game.player.y)
		if not surface.is_empty():
			if dx > 0 and game.player.x >= float(surface.row[1])-28: controls.jump = true
			if dx < 0 and game.player.x <= float(surface.row[0])+28: controls.jump = true
	# Wet signs are hazard rectangles, not artificial solid ledges. Jump using
	# ordinary input; any incidental invulnerable bounce remains source state.
	for block in BLOCKS:
		if dx > 0 and block[0]-game.player.x > 0 and block[0]-game.player.x < 95 and goal.x > block[0]: controls.jump = true

func controls_for(game, frame: int, wipe_start: int) -> Dictionary:
	var controls := {"left":false,"right":false,"jump":false,"down":false,"aim":false,"shoot":true,"special":false}
	if game.world_two.wiping and game.world_two.scene_index == 0:
		controls.left = frame-wipe_start < 25
		controls.right = not controls.left
		return controls
	if route_scene != game.world_two.scene_index:
		route_scene = game.world_two.scene_index
		route_step = 0
	var route: Array = BAKEHOUSE_ROUTE if route_scene == 0 else SHOP_ROUTE
	if route_step < route.size():
		var goal: Vector2 = route[route_step]
		if game.grounded and absf(game.player.x-goal.x) < 15 and absf(game.player.y-goal.y) < 1 and not (route_scene == 0 and route_step == 10 and not game.combat.waves[5].done):
			route_step += 1
			if debug_run: print("Bakery route=",route_scene,"/",route_step," frame=",frame," p=",game.player)
	if route_step < route.size(): navigate(game,controls,route[route_step])
	else: walk_toward(game,controls,9400 if route_scene == 0 else 14950)
	# Hold the real ground approach until camera y returns into the source
	# spawn window. This does not change the camera or consume a wave early.
	if route_scene == 0 and route_step == 10 and game.grounded and game.camera.y < -50:
		controls.left = false; controls.right = false
	var target: Dictionary = {}
	for enemy in game.enemies:
		if enemy.state == "pop": continue
		if target.is_empty() or (target.kind == "drone" and enemy.kind != "drone") or (target.kind == enemy.kind or (target.kind != "drone" and enemy.kind != "drone")) and absf(enemy.p.x-game.player.x) < absf(target.p.x-game.player.x): target = enemy
	if not target.is_empty():
		var dx: float = target.p.x-game.player.x
		var dy: float = target.p.y-game.player.y
		if absf(dy) < 80 and game.grounded:
			controls.left = false
			controls.right = false
			controls.jump = false
			if game.face != (1 if dx >= 0 else -1):
				controls.right = dx >= 0
				controls.left = dx < 0
			if frame%180 == 0: controls.down = true
		elif dy > 80:
			navigate(game,controls,Vector2(target.p.x,target.p.y))
		elif target.kind == "drone" and game.grounded:
			controls.aim = true
			walk_toward(game,controls,target.p.x,20)
			controls.jump = false
		if game.abilities.meter >= 1 and absf(dy) < 100: controls.special = true
		return controls
	# Perform an explicit two-press double jump only AFTER real card contact.
	# Wait for active glider expiry, rather than modifying a special's lifetime.
	if card_frame >= 0 and live_double_jump_frame < 0 and route_scene == 0:
		controls.left = false; controls.right = false
		controls.jump = false; controls.down = false
		if game.abilities.active == "leo": return controls
		if double_jump_probe == 0 and game.grounded and not game.jump_held:
			controls.jump = true
			double_jump_probe = 1
		elif double_jump_probe == 1 and not game.grounded and not game.jump_held and game.velocity.y > -700:
			controls.jump = true
		return controls
	return controls
