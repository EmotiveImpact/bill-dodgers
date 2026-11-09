extends SceneTree
## Actual-main 3-3 input route. Explicit invulnerability is the sole assist.
## Never writes player/camera, enemy HP, waves, runtime state or native gates.
const SaveStore = preload("res://src/save_store.gd")
const DT := 1.0 / 60.0
const MAX_TICKS := 42000
const WAVE_AT := [500, 1900, 3300, 4700, 5900, 9200, 10600, 12000, 13400, 14662]
const LOWER_ROUTE := [Vector2(1350,482), Vector2(1760,428), Vector2(2000,374), Vector2(2300,482), Vector2(3750,482), Vector2(4200,482), Vector2(4680,428), Vector2(4900,374), Vector2(5240,374), Vector2(5400,319), Vector2(5450,319), Vector2(5800,482), Vector2(7010,482)]
const UPPER_ROUTE := [Vector2(8400,482), Vector2(9000,482), Vector2(9700,428), Vector2(10050,374), Vector2(10440,374), Vector2(10600,322), Vector2(10650,322), Vector2(11100,482), Vector2(12000,482), Vector2(12300,428), Vector2(12500,374), Vector2(13050,374), Vector2(13200,319), Vector2(13300,319), Vector2(13800,482), Vector2(14400,482), Vector2(14700,428), Vector2(15180,482)]
var failures: Array[String] = []
var debug_run := false
var route_step := 0
var route_scene := 0
var stomp_confirmed := false
var boss_patterns_seen := false

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	if not game.has_method("step"):
		printerr("Festival night input run: main script did not load")
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

func run_character(game, character: String) -> bool:
	failures.clear()
	route_step = 0
	route_scene = 0
	stomp_confirmed = false
	boss_patterns_seen = false
	game.character = character
	game.save = {"schema": 1, "receipts": {}}
	check(SaveStore.write_save(game.save) == OK, "fresh isolated save failed")
	check(game.load_level("3-3"), "3-3 failed to load")
	check(game.is_native_supported() and game.has_method("_native_world_three") and game._native_world_three(), "3-3 is still preview or not wired to WorldThree; gate was not bypassed")
	if not failures.is_empty():
		printerr("Festival night input run [", character, "]: BLOCKED ", failures)
		return false
	check(game.player == Vector2(300,482) and game.camera == Vector2.ZERO, "source initial position changed")
	check(game.level.w == 15400 and game.view_width() == 738, "source width/view changed")
	check(game.world_three.surfaces(game).size() == 26 and game.world_three.surfaces(game,true).size() == 23, "source26surface geometry changed")
	check(game.world_three.tents.size() == 15 and game.world_three.trailer.is_empty(), "source tents/trailer changed")
	check(game.level.fires.size() == 5 and game.level.mud.size() == 4, "source fire/mud inventory changed")
	check(game.receipts.size() == 3 and game.receipts[0].position == Vector2(5450,222) and game.receipts[1].position == Vector2(10650,222) and game.receipts[2].position == Vector2(13300,222), "receipt coordinates have an incorrect display/pickup offset")
	check(game.movement_skills.skills.is_empty() and game.abilities.skills.is_empty(), "run inherited skills")
	check(game.combat.waves.size() == 10, "missing source ten waves")
	var planned := 0
	for i in range(game.combat.waves.size()):
		var wave: Dictionary = game.combat.waves[i]
		check(wave.at == WAVE_AT[i], "wave trigger changed: " + str(i))
		planned += wave.group.size()
	var pair_planned := 0
	for authored_wave in game.meta.l3.waves: pair_planned += authored_wave[1].size()
	check(pair_planned == 65, "pair source plan must retain65 entries")
	check(planned == 48, "solo plan must contain48 authored entries")
	if not failures.is_empty():
		printerr("Festival night input run [", character, "]: FAIL ", failures)
		return false
	var imported := JSON.stringify(game.meta)
	var started: Array[int] = []
	var completed: Array[int] = []
	var collected: Array[int] = []
	var seen: Array = []
	var popped: Array = []
	var retired: Array = []
	var other_removed: Array = []
	var tent_spawns: Array = []
	var tent_shakes: Array[int] = []
	var landed_bales: Array[int] = []
	var landed_roofs: Array[int] = []
	var seen_authored: Array[Vector2] = []
	var mud_frames := 0
	var wellies_frames := 0
	var wellies_stomps := 0
	var tied_frames := 0
	var jumps := 0
	var falls := 0
	var consumed := 0
	var failed_spawn_entries := 0
	var extra_spawns := 0
	var entry_timeouts := 0
	var camera_culls := 0
	var scene_removals := 0
	var ordinary_damage := false
	var boss_seen := false
	var boss_down := false
	var boss_min_hp := 70
	var boss_damage := 0
	var jar_seen := false
	var mini_done_frame := -1
	var checkpoint_frame := -1
	var wipe_start := -1
	var wipe_mid := -1
	var wipe_end := -1
	var ending_frame := -1
	var fire_contacts := 0
	var boss_states: Array[String] = []
	var shockwave_seen := false
	var ticks := 0
	for frame in range(MAX_TICKS):
		ticks = frame + 1
		game.invincible = 999 # The sole explicit progression assist.
		var controls := controls_for(game, frame)
		var p0: Vector2 = game.player
		var scene0: int = game.world_three.scene_index
		var wipe0: bool = game.world_three.wiping
		var grounded0: bool = game.grounded
		var wellies0: bool = game.power == "wellies"
		var vy0: float = game.velocity.y
		var boss_hp0: int = game.boss.state.hp if game.boss != null else -1
		var indices: Array[int] = []
		for wave in game.combat.waves: indices.append(wave.index)
		var hp_before: Array = []
		for enemy in game.enemies: hp_before.append([enemy, enemy.hp, enemy.state])
		var only_normal: bool = game.abilities.active.is_empty() and not controls.special and game.abilities.effects.is_empty() and game.bullets.all(func(b): return b.enemy or b.get("kind", "") == character)
		var receipts_before: Array = game.receipts.map(func(r): return r.taken)
		var score_before: int = game.score
		var coins_before: Array = game.coins.duplicate()
		game.step(DT, controls)
		if grounded0 and not game.grounded and game.velocity.y < 0: jumps += 1
		for fire in game.level.fires:
			if absf(game.player.x-float(fire[0])) < 34 and absf(game.player.y-float(fire[1])) < 30:
				if debug_run: print("Night fire contact frame=",frame," p=",game.player," fire=",fire)
				fire_contacts += 1
		if game.world_three.in_mud(game): mud_frames += 1
		if game.power == "wellies": wellies_frames += 1
		if game.world_three.tied > 0: tied_frames += 1
		if p0.y > 650 and game.player.y < p0.y - 100 and scene0 == game.world_three.scene_index:
			falls += 1
			if debug_run: print("Night source fall frame=",frame," from=",p0," to=",game.player)
		check(absf(game.player.x-p0.x) < 25 or scene0 != game.world_three.scene_index or (p0.y > float(game.level.fall)-30 and game.player == game.world_three.safe_position), "unexpected teleport outside actual source scene")
		for pair in hp_before:
			if pair[0].hp < pair[1] and only_normal: ordinary_damage = true
			if debug_run and wellies0 and pair[2] != "pop" and pair[0].state == "pop": print("Festival wellies pop frame=",frame," before=",p0," grounded=",grounded0," vy_before=",vy0," vy_after=",game.velocity.y," enemy=",pair[0].p," hp=",pair[1],"/",pair[0].hp)
			if wellies0 and not grounded0 and vy0+3300*DT > 100 and pair[2] != "pop" and pair[0].state == "pop" and pair[0].hp == pair[1] and game.velocity.y <= -799 and absf(game.player.x-pair[0].p.x) < 52 and game.player.y > pair[0].p.y-135 and game.player.y < pair[0].p.y-50:
				wellies_stomps += 1
				stomp_confirmed = true
		var newly_spawned := 0
		for enemy in game.enemies:
			if enemy not in seen:
				newly_spawned += 1
				seen.append(enemy)
				if enemy.get("spawn_side", "") == "t": tent_spawns.append(enemy)
				if debug_run: print("Festival spawn ", enemy.kind, " side=", enemy.get("spawn_side", ""), " frame=", frame, " p=", enemy.p)
		for enemy in seen:
			if enemy.state == "pop" and enemy not in popped: popped.append(enemy)
			if enemy.get("lost", false) and enemy not in retired:
				retired.append(enemy)
				check(float(enemy.age)-float(enemy.get("hit_age",0)) > 12, "retirement preceded source12seconds since hit")
			if enemy not in game.enemies and enemy.state != "pop" and not enemy.get("lost", false) and enemy not in other_removed:
				other_removed.append(enemy)
				if not enemy.entered and float(enemy.get("wait",0)) > 6: entry_timeouts += 1
				elif enemy.p.x < game.camera.x-400 or enemy.p.x > game.camera.x+game.view_width()+400: camera_culls += 1
				elif scene0 != game.world_three.scene_index: scene_removals += 1
				if debug_run: print("Festival removal frame=",frame," bot=",enemy.kind," entered=",enemy.entered," wait=",enemy.get("wait",0)," age=",enemy.get("age",0)," p=",enemy.p)
		var dispatched_frame := 0
		for i in range(10):
			var wave: Dictionary = game.combat.waves[i]
			consumed += wave.index-indices[i]
			dispatched_frame += wave.index-indices[i]
			if wave.started and i not in started: started.append(i)
			if wave.done and i not in completed:
				completed.append(i)
				check(wave.index == wave.group.size(), "wave completed before dispatching every source entry")
				if debug_run: print("Festival wave ", i, " done frame=", frame, " player=", game.player)
		failed_spawn_entries += maxi(0,dispatched_frame-newly_spawned)
		extra_spawns += maxi(0,newly_spawned-dispatched_frame)
		for i in range(game.world_three.tents.size()):
			if game.world_three.tents[i].shake > 0 and i not in tent_shakes: tent_shakes.append(i)
		if game.grounded:
			for i in range(game.level.solids.size()):
				var row: Array = game.level.solids[i]
				if row[3].get("style", "") == "bales" and game.player.x >= row[0] and game.player.x <= row[1] and absf(game.player.y-row[2]) < 0.01 and i not in landed_bales: landed_bales.append(i)
			for i in range(game.level.plats.size()):
				var row: Array = game.level.plats[i]
				if game.player.x >= row[0] and game.player.x <= row[1] and absf(game.player.y-row[2]) < 0.01 and i not in landed_roofs: landed_roofs.append(i)
		for coin in game.coins:
			if coin.get("stay", false) and absf(coin.age-0.3) < 0.00001 and coin.p not in seen_authored: seen_authored.append(coin.p)
		for i in range(3):
			if game.receipts[i].taken and i not in collected:
				collected.append(i)
				check(not receipts_before[i], "receipt was already taken before real overlap")
				var picked_coins := coins_before.filter(func(c): return c.get("dead", false)).size()
				check(game.score-score_before == picked_coins, "receipt added currency beyond actual coin pickups")
				if debug_run: print("Festival receipt ",i," frame=",frame," p=",game.player," score_delta=",game.score-score_before," coins=",picked_coins)
		if game.world_three.checkpoint_done and checkpoint_frame < 0:
			checkpoint_frame = frame
			check(game.player.x > 7000 and game.hearts == 3 and absf(game.invincible-1.5) < 0.0001, "checkpoint did not use livingx7000/fullheal1.5s")
		if game.world_three.wiping and wipe_start < 0:
			wipe_start = frame
			check(game.player.x > 7000 and game.world_three.wipe_label == "The far field" and game.world_three.wipe_kind == "fade", "wrong actual source scene trigger")
			check(game.world_three.wipe_elapsed == 0, "trigger frame advanced wipe clock")
		if scene0 != game.world_three.scene_index:
			wipe_mid = frame
			check(game.world_three.scene_index == 1 and game.camera.x == 7900, "scene callback did not move camera to7900")
			check(game.world_three.safe_position == game.player and game.bullets.is_empty() and game.enemies.is_empty(), "scene did not update safe/clear sourceactors")
			check(game.world_three.wipe_elapsed >= 1.43 and game.world_three.wipe_elapsed < 1.43+DT+0.0001, "scene callback time changed")
		if wipe0 and not game.world_three.wiping:
			wipe_end = frame
			check(game.world_three.wipe_elapsed >= 2.17, "wipe ended before source duration")
		if game.boss != null:
			var state: Dictionary = game.boss.state
			if state.state not in boss_states: boss_states.append(state.state)
			shockwave_seen = shockwave_seen or not state.get("waves", []).is_empty()
			boss_patterns_seen = shockwave_seen and "throw" in boss_states and "charge" in boss_states
			if not boss_seen:
				boss_seen = true
				check(state.kind == "bailiff" and state.max == 70 and state.cfg.mini == "Bailiff sorted!" and state.cam == 8000, "wrong70HP Bailiff mini config")
			if state.hp < boss_min_hp: boss_min_hp = state.hp
			if boss_hp0 >= 0 and state.hp < boss_hp0: boss_damage += boss_hp0-state.hp
			boss_down = boss_down or state.state == "down"
			jar_seen = jar_seen or not state.jar.is_empty()
		if game.world_three.mini_done and mini_done_frame < 0:
			mini_done_frame = frame
			check(boss_down and game.boss == null and game.camera_lock == null, "mini completion was not real down/dismissal")
		if game.world_three.end_time > 0 and ending_frame < 0:
			ending_frame = frame
			check(completed.size() == 10 and game.boss == null and game.world_three.mini_done, "actual ending skipped waves or Bailiff")
		if debug_run and frame%600 == 0: print("Festival frame=",frame," p=",game.player," camera=",game.camera," route=",route_scene,"/",route_step," power=",game.power," boss=",game.boss.state if game.boss != null else {}," live=",enemy_summary(game))
		if game.mode != "play": break
	check(game.mode == "clear", "did not reach actual timed clear")
	check(started.size() == 10 and completed.size() == 10 and consumed == 48, "not all48 solo entries/tenwaves dispatched and completed")
	check(fire_contacts == 0 and falls == 0, "route touched fire or used fall recovery; inspect honest counters")
	check(ordinary_damage and popped.size() > 0, "normal shooting never damaged/popped an enemy")
	check(not tent_spawns.is_empty() and not tent_shakes.is_empty(), "no authored tent emergence observed")
	check(mud_frames > 0, "mud was not traversed")

	check(consumed-failed_spawn_entries+extra_spawns == seen.size(), "spawn accounting does not balance source entries and boss summons")
	check(popped.size()+retired.size()+other_removed.size() == seen.size() and entry_timeouts+camera_culls+scene_removals == other_removed.size(), "enemy outcome accounting includes unclassified removal")
	check(landed_bales.size() >= 8 and 0 in landed_roofs and 1 in landed_roofs and 2 in landed_roofs, "route did not physically climb bales and all three receipt vanroofs")
	check(collected == [0,1,2], "three receipts not actually collected in order")
	check(seen_authored.size() == 15 and authored_coins_match(game.level.coinRows,seen_authored), "15 exact authored coin seeds not observed")
	check(checkpoint_frame >= 0 and wipe_start >= 0 and wipe_mid > wipe_start and wipe_end > wipe_mid, "checkpoint/far-field fade timeline incomplete")
	check(boss_seen and boss_down and mini_done_frame > 0 and boss_min_hp <= 0 and boss_damage >= 70 and not jar_seen, "Bailiff was not genuinely defeated/dismissed without a jar")
	check(shockwave_seen, "Bailiff stomp shockwaves not observed")
	check("throw" in boss_states and "charge" in boss_states, "Bailiff throw/charge not observed")
	check(ending_frame >= 0 and ticks-1-ending_frame >= 155 and ticks-1-ending_frame <= 157, "timed exit duration is not source2.6seconds")
	check(game.world_three.scene_index == 1 and game.world_three.mini_done and game.world_three.clear_reported, "runtime objective did not finish")
	check(JSON.stringify(game.meta) == imported, "runtime/test mutated imported source metadata")
	check(game.save.get("cleared",{}).get("3-3",false), "clear was not persisted in memory")
	var saved: Dictionary = SaveStore.read_save()
	check(saved.get("cleared",{}).get("3-3",false), "clear missing after disk reload")
	check(saved.get("receipts",{}).get("3-3",[]) == [0,1,2], "receipts missing after disk reload")
	check(saved.get("skills",[]).is_empty(), "run saved unearned skills")
	check(saved.get("kitty",0) == game.score, "banked score missing after disk reload")
	var banked := JSON.stringify(saved)
	var banked_score: int = game.score
	for i in range(180): game.step(DT,{})
	check(game.score == banked_score and JSON.stringify(SaveStore.read_save()) == banked, "postclear frames duplicated score/save")
	var passed := failures.is_empty()
	print("Festival night input run [",character,"]: ","PASS" if passed else "FAIL"," ticks=",ticks," waves=",completed.size(),"/10 entries=",consumed,"/48 failed_placements=",failed_spawn_entries," extra_spawns=",extra_spawns," seen=",seen.size()," popped=",popped.size()," retired12s=",retired.size()," other_removed=",other_removed.size()," entry_timeouts6s=",entry_timeouts," camera_culls=",camera_culls," scene_removals=",scene_removals," tents=",tent_spawns.size()," receipts=",collected," authored_coins=",seen_authored.size()," bales=",landed_bales.size()," roofs=",landed_roofs," mud_frames=",mud_frames," wellies_frames=",wellies_frames," wellies_stomps=",wellies_stomps," tied_frames=",tied_frames," boss_damage=",boss_damage," mini_done=",mini_done_frame," checkpoint=",checkpoint_frame," wipe=",wipe_start,"/",wipe_mid,"/",wipe_end," boss_states=",boss_states," shockwave_seen=",shockwave_seen," fire_contacts=",fire_contacts," jumps=",jumps," falls=",falls," ending=",ending_frame," score=",game.score," route=",route_scene,"/",route_step," player=",game.player," mode=",game.mode)
	if not passed:
		printerr("Festival failures [",character,"]: ",failures)
		printerr("Remaining enemies: ",enemy_summary(game))
	return passed

func authored_coins_match(rows: Array, positions: Array[Vector2]) -> bool:
	var count := 0
	for row in rows:
		for i in range(int(row[3])):
			var expected := Vector2(float(row[0])+i*float(row[2]),float(row[1])-sin(i/float(maxi(1,int(row[3])-1))*PI)*float(row[4]))
			if not positions.any(func(p): return p.distance_to(expected) < 0.002): return false
			count += 1
	return positions.size() == count

func enemy_summary(game) -> Array:
	var result: Array = []
	for enemy in game.enemies:
		if enemy.state != "pop": result.append([enemy.kind,enemy.p,enemy.hp,enemy.state,enemy.get("age",0)])
	return result

func walk(game, controls: Dictionary, x: float, tolerance := 4.0) -> void:
	controls.right = x-game.player.x > tolerance
	controls.left = x-game.player.x < -tolerance

func navigate(game, controls: Dictionary, goal: Vector2) -> void:
	walk(game,controls,goal.x)
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

func controls_for(game, frame: int) -> Dictionary:
	var controls := {"left":false,"right":false,"jump":false,"down":false,"aim":false,"shoot":true,"special":false}
	if game.world_three.wiping and game.world_three.scene_index == 0: return controls
	if route_scene != game.world_three.scene_index:
		route_scene = game.world_three.scene_index
		route_step = 0
	var route: Array = LOWER_ROUTE if route_scene == 0 else UPPER_ROUTE
	if route_step < route.size():
		var goal: Vector2 = route[route_step]
		if game.grounded and absf(game.player.x-goal.x) < 15 and absf(game.player.y-goal.y) < 1:
			route_step += 1
			if debug_run: print("Festival route=",route_scene,"/",route_step," frame=",frame," p=",game.player)
	if route_step < route.size(): navigate(game,controls,route[route_step])
	else: walk(game,controls,7010 if route_scene == 0 else 15180)
	if game.boss != null:
		var b: Dictionary = game.boss.state
		controls.shoot = boss_patterns_seen
		if game.player.y < 450: return controls # Walk off the real van roof before fighting.
		if b.state != "down":
			controls.left = false
			controls.right = false
			controls.jump = false
			controls.down = false
			if game.face != (1 if b.x >= game.player.x else -1):
				controls.right = b.x >= game.player.x
				controls.left = b.x < game.player.x
		if b.state != "down": return controls

	var target: Dictionary = {}
	for enemy in game.enemies:
		if enemy.state == "pop": continue
		if target.is_empty() or absf(enemy.p.x-game.player.x) < absf(target.p.x-game.player.x): target = enemy
	if not target.is_empty():
		var dx: float = target.p.x-game.player.x
		var dy: float = target.p.y-game.player.y
		if absf(dy) < 70 and game.grounded:
			controls.left = false
			controls.right = false
			controls.jump = false
			if game.face != (1 if dx >= 0 else -1):
				controls.right = dx >= 0
				controls.left = dx < 0
		elif dy < -70: controls.aim = true
		if frame%300 == 0 and absf(dy) < 70: controls.down = true
	for fire in game.level.fires:
		var distance: float = float(fire[0])-game.player.x
		if distance > -65 and distance < 70 and game.player.y > float(fire[1])-95:
			controls.left = false
			controls.right = true
			controls.down = false
			if game.grounded and not game.jump_held: controls.jump = true
	return controls
