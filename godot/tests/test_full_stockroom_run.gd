extends SceneTree
## Input-driven 2-3 progression, not difficulty/device QA. Explicit invulnerability
## is the sole assist. Never edit actor, wave, geometry, ability, or objective state.
const SaveStore = preload("res://src/save_store.gd")
const DT := 1.0 / 60.0
const MAX_TICKS := 36000
const EXPECTED_WAVES := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
const WAVE_AT := [300, 1600, 3100, 4500, 6000, 6900, 8150, 9700, 10900, 12300, 13862]
const ENEMY_COUNTS := {"rush": 22, "throw": 11, "drone": 4, "cart": 4, "flat": 3, "big": 2}
const RECEIPTS := [[9305, 422], [8760, 122], [11620, 2]]
const TOWERS := [[3000, 4400, 360], [4650, 5600, 240], [6000, 7400, 240], [7700, 8800, 360], [10500, 11700, 480], [12100, 13000, 360]]
const STACKS := [[1000, 1230, 110], [1700, 2000, 110], [2300, 2560, 220], [9900, 10130, 110], [13500, 13760, 110]]
const PLATFORMS := [[2150, 2296, 367], [2850, 2994, 362], [2870, 2994, 242], [4500, 4644, 362], [4400, 4650, 122], [5850, 5994, 362], [7550, 7694, 362], [7570, 7694, 242], [7400, 7700, 242], [9110, 9200, 452], [9270, 9340, 422], [10350, 10494, 362], [10370, 10494, 242], [10350, 10494, 122], [11700, 12100, 122], [11950, 12094, 362], [11970, 12094, 242], [13006, 13150, 362], [13006, 13130, 242]]
const BELTS := [[4400, 4650, 122, 0.08], [7400, 7700, 242, -0.07], [11700, 12100, 122, 0.1]]
const DROPS := [[3000, 5600, 1900, "box"], [10400, 13000, 1600, "box"]]
const LOWER_ROUTE := [Vector2(1070,372), Vector2(1770,372), Vector2(2210,367), Vector2(2340,262), Vector2(2530,262), Vector2(2925,362), Vector2(2935,242), Vector2(3030,122), Vector2(4340,122), Vector2(4520,122), Vector2(4680,242), Vector2(5575,242), Vector2(5910,362), Vector2(6050,242), Vector2(7350,242), Vector2(7520,242), Vector2(7650,242), Vector2(7730,122), Vector2(8760,122), Vector2(8865,482)]
const UPPER_ROUTE := [Vector2(8987,482), Vector2(9180,452), Vector2(9320,422), Vector2(9480,482), Vector2(9970,372), Vector2(10200,482), Vector2(10425,362), Vector2(10430,242), Vector2(10430,122), Vector2(10535,2), Vector2(11620,2), Vector2(11680,2), Vector2(11800,122), Vector2(12160,122), Vector2(12970,122), Vector2(13060,242), Vector2(13060,362), Vector2(13180,482), Vector2(13570,372), Vector2(13830,482), Vector2(14550,482)]
var failures: Array[String] = []
var debug_run := false
var route_step := 0
var route_scene := 0

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	if not game.has_method("step"):
		printerr("Stockroom input run: main script did not load")
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
	game.character = character
	game.save = {"schema": 1, "receipts": {}}
	check(SaveStore.write_save(game.save) == OK, "fresh isolated save failed")
	check(not SaveStore.read_save().get("cleared", {}).get("2-3", false), "stale stockroom clear")
	check(game.load_level("2-3"), "2-3 did not load")
	check(game.is_native_supported() and game._native_world_two(), "2-3 is still a preview or has the wrong runtime")
	check(game.player == Vector2(300,482) and game.camera == Vector2.ZERO, "source starting position changed")
	check(game.level.w == 14600 and game.view_width() == 738, "source width/view changed")
	check(source_equal(game.level.grounds, [[-400,9000],[9440,15000]]) and source_equal(game.level.gap, [9000,9440]), "source loading-bay gap changed")
	check(source_equal(game.level.plats, PLATFORMS), "source nineteen one-way platforms changed")
	check(source_equal(game.level.towers, TOWERS) and source_equal(game.level.stacks, STACKS), "source six towers/five stacks changed")
	var solids: Array = [[-400,9000,482],[9440,15000,482],[1000,1230,372],[1700,2000,372],[2300,2560,262],[3000,4400,122],[4650,5600,242],[6000,7400,242],[7700,8800,122],[9900,10130,372],[10500,11700,2],[12100,13000,122],[13500,13760,372]]
	check(source_equal(game.level.solids, solids), "source solid geometry changed")
	check(source_equal(game.level.receipts, RECEIPTS) and game.receipts.size() == 3, "source receipt coordinates changed")
	check(source_equal(game.level.scenes, [[8910,"lift","Top floor","Goods lift up!"]]), "source goods-lift scene changed")
	check(game.level.check == 8950 and game.level.start == 300, "source checkpoint/start changed")
	check(source_equal(source_rows(game.level,"belt"), BELTS), "source three belts changed")
	check(source_equal(source_rows(game.level,"drops"), DROPS), "source two falling-stock zones changed")
	check(game.movement_skills.skills.is_empty() and game.abilities.skills.is_empty(), "run inherited movement skills")
	check(game.combat.waves.size() == 11, "expected all eleven source waves")
	if not failures.is_empty():
		printerr("Stockroom input run [", character, "]: FAIL ", failures)
		return false
	check(game.world_two.unsupported_hazards.is_empty(), "stockroom still has unsupported hazards")
	check(absf(game.world_two.camera_cap(game) - 8292) < 0.01, "stockroom sceneView120 camera cap missing")
	for i in range(11):
		check(game.combat.waves[i].at == WAVE_AT[i], "wave trigger changed: %d" % i)
		check(game.combat.waves[i].group == game.level.waves[i].g, "solo group differs from source: %d" % i)
	var source_geometry := JSON.stringify(game.level)
	var started: Array[int] = []
	var completed: Array[int] = []
	var collected: Array[int] = []
	var towers: Array[int] = []
	var platforms: Array[int] = []
	var belt_frames := [0,0,0]
	var zone_frames := [0,0]
	var seen_enemies: Array = []
	var seen_drops: Array = []
	var fallen_drops: Array = []
	var drops_by_zone: Array = [[],[]]
	var falls_by_zone: Array = [[],[]]
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
	var maximum_y := 482.0
	for frame in range(MAX_TICKS):
		ticks = frame + 1
		game.invincible = 999 # Explicit sole progression assist.
		var controls := controls_for(game, frame, wipe_start)
		var position_before: Vector2 = game.player
		var elapsed_before: float = game.elapsed
		var scene_before: int = game.world_two.scene_index
		var wipe_before: bool = game.world_two.wiping
		var active_before: String = game.abilities.active
		var grounded_before: bool = game.grounded
		var hp_before: Array = []
		for enemy in game.enemies: hp_before.append([enemy,enemy.hp])
		var indices: Array[int] = []
		for wave in game.combat.waves: indices.append(wave.index)
		var only_normal: bool = game.abilities.active.is_empty() and not controls.special and game.abilities.effects.is_empty() and game.bullets.all(func(b): return b.enemy or b.get("kind", "") == character)
		game.step(DT, controls)
		if active_before.is_empty() and not game.abilities.active.is_empty():
			specials += 1
			check(game.abilities.active == character, "activated another housemate's special")
		if grounded_before and not game.grounded and game.velocity.y < 0: jumps += 1
		if controls.aim: aim_frames += 1
		if controls.down: down_frames += 1
		for pair in hp_before:
			if only_normal and pair[0].hp < pair[1]: ordinary_damage = true
		boss_seen = boss_seen or game.boss != null
		if position_before.y > 600 and game.player.y < position_before.y - 100 and scene_before == game.world_two.scene_index:
			falls += 1
			if debug_run: print("Stockroom fall frame=",frame," from=",position_before," to=",game.player," active=",active_before)
		check(absf(game.player.x-position_before.x) < 20 or scene_before != game.world_two.scene_index, "unexpected teleport outside source lift")
		if game.world_two.scene_index == 0:
			check(game.player.x <= 8910.01, "player crossed closed scene boundary")
			check(game.camera.x <= 8292.01, "camera exceeded source sceneView120 cap")
			check(not game.world_two.checkpoint_hit, "checkpoint triggered before source lift")
		if game.world_two.wiping and wipe_start < 0:
			wipe_start = frame
			check(game.combat.waves.slice(0,7).all(func(w): return w.started and w.done) and game.combat.waves.slice(7).all(func(w): return not w.started), "lift started before seven preceding waves cleared")
			check(game.player.x >= 8860 and game.player.x <= 8910, "lift started outside source entry interval")
			check(game.world_two.wipe_kind == "lift" and game.world_two.wipe_label == "Top floor", "incorrect source wipe")
		if wipe_before:
			check(absf(game.elapsed-elapsed_before-DT) < 0.0001, "simulation paused during source lift wipe")
			if scene_before == 0 and game.world_two.scene_index == 0: wipe_motion += absf(game.player.x-position_before.x)
		if scene_before != game.world_two.scene_index:
			wipe_mid = frame
			check(scene_before == 0 and game.world_two.scene_index == 1, "unexpected scene transition")
			check(game.world_two.wipe_elapsed >= 1.43 and game.world_two.wipe_elapsed < 1.43+DT+0.0001, "lift midpoint is not source1.43 seconds")
			check(game.player == Vector2(8910,482) and game.grounded, "sceneLand0/landY476 did not land at (8910,482)")
			check(game.camera == Vector2(8710,0) and game.camera_speed == 0, "sceneCam200 camera reset changed")
			check(game.velocity == Vector2.ZERO and game.bullets.is_empty(), "source lift did not clear momentum/projectiles")
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
				if debug_run: print("Stockroom spawn ", enemy.kind, " frame=", frame, " p=", enemy.p)
				if enemy.kind == "big": check(enemy.big and enemy.max_hp == 24 and enemy.hw == 58 and enemy.hh == 186, "security bot lost solo24HP geometry")
				if enemy.kind == "drone": check(enemy.max_hp == 2 and not enemy.get("fly",false), "barcode drone has World1 contract")
				if enemy.kind == "cart": check(enemy.max_hp == 2, "cart bot source health changed")
		for i in range(11):
			var wave: Dictionary = game.combat.waves[i]
			if wave.started and i not in started: started.append(i)
			if wave.done and i not in completed:
				completed.append(i)
				check(wave.index == wave.group.size(), "wave finished before every entry dispatched")
				if debug_run: print("Stockroom wave ",i," done frame=",frame," player=",game.player)
			consumed += wave.index-indices[i]
			if wave.index > indices[i]:
				var dispatched: Array = wave.group.slice(indices[i],wave.index)
				if debug_run: print("Stockroom dispatch wave=",i," entries=",dispatched," frame=",frame," camera=",game.camera," player=",game.player)
				if new_enemies.size() < dispatched.size(): failed_spawns.append({"wave":i,"entries":dispatched,"frame":frame,"camera":game.camera,"player":game.player})
		if game.grounded:
			maximum_y = minf(maximum_y,game.player.y)
			for i in range(TOWERS.size()):
				var tower: Array = TOWERS[i]
				if game.player.x >= tower[0] and game.player.x <= tower[1] and absf(game.player.y-(482-tower[2])) < 0.1 and i not in towers: towers.append(i)
			for i in range(PLATFORMS.size()):
				var platform: Array = PLATFORMS[i]
				if game.player.x >= platform[0] and game.player.x <= platform[1] and absf(game.player.y-platform[2]) < 0.1 and i not in platforms: platforms.append(i)
		for i in range(3):
			var belt: Array = BELTS[i]
			if grounded_before and position_before.x > belt[0] and position_before.x < belt[1] and absf(position_before.y-belt[2]) < 4: belt_frames[i] += 1
		for i in range(2):
			if game.player.x > DROPS[i][0] and game.player.x < DROPS[i][1]: zone_frames[i] += 1
		for entity in game.world_two.entities:
			if entity.k != "drop": continue
			if entity not in seen_drops:
				seen_drops.append(entity)
				for zone in range(DROPS.size()):
					if game.player.x > DROPS[zone][0] and game.player.x < DROPS[zone][1]: drops_by_zone[zone].append(entity)
				check(entity.kind == "box" and absf(entity.warn-0.95) < 0.0001, "falling-stock kind/warning changed")
				check(entity.vy == 0 and absf(entity.p.y-(game.view_top()-80)) < 0.0001, "drop skipped actual warning/spawn position")
			if entity.vy > 0 and entity not in fallen_drops:
				fallen_drops.append(entity)
				for zone in range(DROPS.size()):
					if entity in drops_by_zone[zone]: falls_by_zone[zone].append(entity)
				check(entity.t >= 0.95-0.0001, "stock fell before source warning elapsed")
		for coin in game.coins:
			if not coin.get("keep",false): continue
			if absf(coin.age-0.3) < 0.00001 and coin.p not in seen_coin_positions: seen_coin_positions.append(coin.p)
			if coin.rest: check(coin.age <= 2.0001, "resting authored coin lost keep-age cap")
		for i in range(3):
			if game.receipts[i].taken and i not in collected:
				collected.append(i)
				check(absf(game.player.x-RECEIPTS[i][0]) < 42, "receipt collected outside actual horizontal contact")
				check(game.player.y > RECEIPTS[i][1]-30 and game.player.y-game.character_height() < RECEIPTS[i][1], "receipt lost World2 vertical contact bounds")
				if debug_run: print("Stockroom receipt ",i," frame=",frame," player=",game.player)
		if game.world_two.end_time > 0 and ending_frame < 0:
			ending_frame = frame
			check(completed == EXPECTED_WAVES, "exit started before all waves cleared")
			check(game.camera.x >= 13860, "exit started before source endpoint")
		if debug_run and frame%900 == 0: print("Stockroom trace [",character,"] frame=",frame," route=",route_scene,"/",route_step," p=",game.player," camera=",game.camera," receipts=",collected," live=",enemy_summary(game))
		if game.mode in ["clear","over"]: break
	var exit_ticks := ticks-1-ending_frame if ending_frame >= 0 else -1
	check(game.mode == "clear", "bounded input route did not clear")
	check(started == EXPECTED_WAVES and completed == EXPECTED_WAVES, "all eleven waves did not start/finish in order")
	check(consumed == 46 and seen_enemies.size() == 46 and failed_spawns.is_empty(), "not all46 authored enemies actually spawned")
	for kind in ENEMY_COUNTS:
		check(seen_enemies.filter(func(e): return e.kind == kind).size() == ENEMY_COUNTS[kind], "source enemy count changed: "+kind)
	check(seen_enemies.all(func(e): return e.state == "pop" and e.hp <= 0), "an authored enemy escaped instead of being defeated")
	check(not boss_seen, "stockroom invented a separate boss objective")
	check(collected == [1,0,2], "did not collect all three source receipts in route order")
	check(towers == [0,1,2,3,4,5] and maximum_y == 2, "did not land on all six towers including top2")
	check(9 in platforms and 10 in platforms, "did not land on both static chained pallets")
	check(belt_frames.all(func(n): return n > 10), "did not walk all three real conveyor surfaces")
	check(specials > 0 and jumps >= 15 and ordinary_damage and aim_frames > 0 and down_frames > 0, "missing actual special/jump/down/aim/ordinary damage coverage")
	check(falls == 0, "route relied on fall-safe recovery")
	check(wipe_start >= 0 and wipe_mid > wipe_start and wipe_end > wipe_mid and wipe_motion > 10, "source lift/input simulation coverage missing")
	check(checkpoint_frame == wipe_mid+1, "source checkpoint not observed")
	check(zone_frames.all(func(n): return n > 200), "did not traverse both falling-stock zones")
	check(drops_by_zone.all(func(es): return not es.is_empty()) and falls_by_zone.all(func(es): return not es.is_empty()), "actual box warning/falling execution missing in a source zone")
	check(route_scene == 1 and route_step == UPPER_ROUTE.size(), "actual upper-floor route not completed")
	check(game.world_two.coins_done.size() == 6 and seen_coin_positions.size() == 40, "not all6 rows/40 authored coins appeared once")
	check(authored_coin_positions_match(game.level.hz,seen_coin_positions), "authored coin positions/arcs differ from source")
	check(exit_ticks == 155, "source2.6-second exit timing changed")
	check(JSON.stringify(game.level) == source_geometry, "runtime/test mutated imported source data")
	check(game.movement_skills.skills.is_empty() and game.abilities.skills.is_empty(), "unearned movement skills appeared")
	check(game.save.get("cleared",{}).get("2-3",false), "real clear missing in memory")
	var persisted: Dictionary = SaveStore.read_save()
	check(persisted.get("cleared",{}).get("2-3",false), "real clear missing after disk reload")
	check(persisted.get("receipts",{}).get("2-3",[]) == [1,0,2], "receipts missing after disk reload")
	var passed := failures.is_empty()
	print("Stockroom input run [",character,"]: ","PASS" if passed else "FAIL"," ticks=",ticks," waves=",completed.size(),"/11 enemies=",seen_enemies.size(),"/46 receipts=",collected," towers=",towers," platforms=",platforms," belts=",belt_frames," coins=",seen_coin_positions.size(),"/40 drops=",seen_drops.size()," jumps=",jumps," specials=",specials," aim=",aim_frames," down=",down_frames," lift=",wipe_start,"/",wipe_mid,"/",wipe_end," checkpoint=",checkpoint_frame," exit_ticks=",exit_ticks," route=",route_scene,"/",route_step," player=",game.player," mode=",game.mode)
	if not passed:
		printerr("Stockroom failures [",character,"]: ",failures)
		printerr("Remaining live enemies: ",enemy_summary(game))
		printerr("Consumed source spawn failures: ",failed_spawns)
	return passed

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
	# If combat displaced us below a tall goal, take its real lower rungs
	# again rather than trying to jump through a220/360/480px solid wall.
	if goal.y < game.player.y-145:
		var best := INF
		var rung := goal
		for row in PLATFORMS:
			if row[2] < game.player.y-140 or row[2] >= game.player.y-6 or row[2] <= goal.y: continue
			var x := (float(row[0])+float(row[1]))*0.5
			if x < game.camera.x+35 or x > game.camera.x+game.view_width()-35: continue
			var distance: float = absf(x-goal.x)+absf(x-game.player.x)*0.25
			if distance < best:
				best = distance
				rung = Vector2(x,row[2])
		goal = rung
	walk_toward(game,controls,goal.x)
	if not game.grounded or game.jump_held: return
	var dx: float = goal.x-game.player.x
	var forward := 1 if dx >= 0 else -1
	if goal.y < game.player.y-6 and absf(dx) < 110: controls.jump = true
	for row in game.level.solids:
		if row[2] >= game.player.y-6: continue
		var edge: float = row[0] if forward > 0 else row[1]
		var distance: float = (edge-game.player.x)*forward
		if distance >= 0 and distance < 65 and absf(dx) > distance: controls.jump = true
	if goal.y > game.player.y+6 and game.on_platform and absf(dx) < 10:
		controls.down = true
		controls.jump = true
	# Ground ends at9000. The two pallets are static one-way ledges, so
	# approaching each actual edge is essential before an ordinary jump.
	if game.player.x >= 8975 and game.player.x < 9440 and goal.x > game.player.x:
		var surface: Dictionary = game.world_two.below(game,game.player.x,game.player.y)
		if not surface.is_empty() and game.player.x >= float(surface.row[1])-23: controls.jump = true

func controls_for(game, frame: int, wipe_start: int) -> Dictionary:
	var controls := {"left":false,"right":false,"jump":false,"down":false,"aim":false,"shoot":true,"special":false}
	if game.world_two.wiping and game.world_two.scene_index == 0:
		controls.left = frame-wipe_start < 25
		controls.right = not controls.left
		return controls
	if route_scene != game.world_two.scene_index:
		route_scene = game.world_two.scene_index
		route_step = 0
	# Leo's active glider clamps upward speed. Let the actual special expire
	# on the safe bank before attempting the first30px-up pallet jump.
	if route_scene == 1 and game.player.x < 9000 and game.grounded and game.abilities.active == "leo": return controls
	var route: Array = LOWER_ROUTE if route_scene == 0 else UPPER_ROUTE
	if route_step < route.size():
		var goal: Vector2 = route[route_step]
		if game.grounded and absf(game.player.x-goal.x) < 15 and absf(game.player.y-goal.y) < 1:
			route_step += 1
			if debug_run: print("Stockroom route=",route_scene,"/",route_step," frame=",frame," p=",game.player)
	if route_step < route.size(): navigate(game,controls,route[route_step])
	else: walk_toward(game,controls,8910 if route_scene == 0 else 14550)
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
			# Descend/backtrack through real ledges to a lower stranded bot.
			navigate(game,controls,Vector2(target.p.x,target.p.y))
		elif target.kind == "drone" and game.grounded:
			controls.aim = true
			var obstructed := false
			var height: float = target.base_y
			for row in game.level.solids:
				if row[2] < game.player.y-6 and row[0] < maxf(game.player.x,target.p.x) and row[1] > minf(game.player.x,target.p.x):
					obstructed = true
					height = minf(height,row[2])
			if obstructed:
				# Reach the actual intervening shelf before aiming through it.
				navigate(game,controls,Vector2(target.p.x,height))
			else:
				var support: Dictionary = game.world_two.below(game,game.player.x,game.player.y)
				if not support.is_empty():
					var x: float = clampf(target.p.x,maxf(support.row[0]+30,game.camera.x+35),minf(support.row[1]-30,game.camera.x+game.view_width()-40))
					walk_toward(game,controls,x,20)
				controls.jump = false
		if game.abilities.meter >= 1 and absf(dy) < 100: controls.special = true
	return controls
