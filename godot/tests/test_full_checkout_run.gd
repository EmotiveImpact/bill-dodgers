extends SceneTree
## Input-driven 2-6 progression, not difficulty/device QA. Invulnerability is
## the only assist; it suppresses bags and cannot replace real-damage fixtures.
## Use detached controller snapshots to choose ordinary inputs. No state writes.
const SaveStore = preload("res://src/save_store.gd")
const DT := 1.0/60.0
const MAX_TICKS := 24000
const RECEIPTS := [[1100,390],[2900,390],[3500,390]]
const LANES := [[700,1080,390],[1300,1680,390],[1900,2280,390],[2500,2880,390],[3100,3480,390]]
const STEPS := [[4385,4475,412],[4465,4555,347],[4545,4635,282]]
const WAVE_AT := [500,1700,3000]
const ENEMY_COUNTS := {"rush":5,"throw":3,"cart":4,"drone":1,"big":1}
const TRAY_TARGETS := [Vector2(4846,354),Vector2(4906,354),Vector2(4876,292)]
var failures: Array[String] = []
var trace := false
var trace_limit := 160
var trace_count := 0
var climbed := 0
var special_used := false

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	if not game.has_method("step"):
		printerr("Checkout input run: main script did not load")
		game.free(); quit(1); return
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	var characters: Array = game.CHARACTERS
	var args := OS.get_cmdline_user_args()
	if "--jp-only" in args: characters = ["jp"]
	for arg in args:
		if arg.begins_with("--character="):
			var chosen := arg.trim_prefix("--character=")
			if chosen not in game.CHARACTERS:
				printerr("Unknown housemate: ",chosen)
				game.queue_free(); await process_frame; quit(1); return
			characters = [chosen]
		if arg.begins_with("--trace-limit="): trace_limit = clampi(int(arg.trim_prefix("--trace-limit=")),1,1000)
	trace = "--trace" in args
	var passed := true
	for character in characters:
		if not run_character(game,character): passed = false
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)

func check(condition: bool, message: String) -> void:
	if not condition and message not in failures: failures.append(message)

func note(message: String) -> void:
	if trace and trace_count < trace_limit:
		print(message)
		trace_count += 1

func equal_rows(actual: Variant, expected: Variant) -> bool:
	if actual is Array and expected is Array:
		if actual.size() != expected.size(): return false
		for i in range(actual.size()):
			if not equal_rows(actual[i],expected[i]): return false
		return true
	if (actual is int or actual is float) and (expected is int or expected is float): return absf(float(actual)-float(expected)) < 0.00001
	return actual == expected

func run_character(game, character: String) -> bool:
	failures.clear(); trace_count = 0; climbed = 0; special_used = false
	game.character = character
	game.save = {"schema":1,"receipts":{}}
	check(SaveStore.write_save(game.save) == OK,"fresh isolated save failed")
	check(not SaveStore.read_save().get("cleared",{}).get("2-6",false),"stale checkout clear")
	check(SaveStore.read_save().get("skills",[]).is_empty(),"stale earned skills")
	check(game.load_level("2-6"),"2-6 did not load")
	check(game.is_native_supported() and game._native_world_two(),"2-6 is still a preview or has the wrong runtime")
	if not failures.is_empty():
		printerr("Checkout input run [",character,"]: BLOCKED ",failures)
		return false
	check(game.world_two.get("checkout") != null,"world_two.checkout host integration missing")
	if not failures.is_empty():
		printerr("Checkout input run [",character,"]: BLOCKED ",failures)
		return false
	check(game.player == Vector2(300,482) and game.camera == Vector2.ZERO,"source starting position changed")
	check(game.level.w == 4900 and game.level.arena == 4162 and game.view_width() == 738,"source arena/view changed")
	check(equal_rows(game.level.solids,[[-400,5300,482]]) and equal_rows(game.level.plats,LANES),"source lane geometry changed")
	check(equal_rows(game.level.receipts,RECEIPTS) and game.receipts.size() == 3,"source receipt coordinates changed")
	check(equal_rows(game.level.crates,[[1300,472,"heart"],[2600,472,"split"],[4282,472,"heart"]]),"ordinary source pickup crates changed")
	check(game.combat.waves.size() == 3,"all three source approach waves required")
	check(game.movement_skills.skills.is_empty() and game.abilities.skills.is_empty(),"run inherited earned skills")
	for i in range(3):
		check(game.combat.waves[i].at == WAVE_AT[i] and game.combat.waves[i].group == game.level.waves[i].g,"source solo wave changed: %d" % i)
	if not failures.is_empty():
		printerr("Checkout input run [",character,"]: FAIL ",failures)
		return false
	var imported := JSON.stringify(game.level)
	var started: Array[int] = []; var completed: Array[int] = []; var collected: Array[int] = []
	var approach_enemies: Array = []; var seen_enemies: Array = []
	var consumed := 0; var phases: Array[int] = []
	var entry_frame := -1; var fight_frame := -1; var phase2_frame := -1; var floor_frame := -1; var phase3_frame := -1
	var down_frame := -1; var jar_frame := -1; var clear_frame := -1
	var beam_starts := 0; var beam_completions := 0; var beam_warning_frames := 0; var beam_harm_frames := 0
	var beam_heights: Array = []; var phase1_shot_frames := 0; var special_frames := 0
	var batch := 0; var crate_history: Dictionary = {}; var flights := 0; var freeze_count := 0
	var floor_observed := false; var frozen_damage := 0; var phase3_damage := 0; var normal_fixed_hits := 0
	var step_frames: Array = []; var landed: Array[int] = []
	var jumps := 0; var aim_frames := 0; var down_inputs := 0; var ordinary_enemy_damage := false
	var age_blocked_overlap := 0; var collection_gap := 0.0; var expected_bank := -1; var ticks := 0
	for frame in range(MAX_TICKS):
		ticks = frame+1
		game.invincible = 999 # ONLY assist. No scanner bag proof is claimed.
		var before: Dictionary = game.world_two.checkout.snapshot()
		var b0: Dictionary = before.boss
		var controls := controls_for(game,frame,before)
		var point0: Vector2 = game.player
		var grounded0: bool = game.grounded
		var active0: String = game.abilities.active
		var power0: String = game.power
		var score0: int = game.score+game.coins.size()
		var hp0: Array = []
		for enemy in game.enemies: hp0.append([enemy,enemy.hp])
		var wave_indices: Array = []
		for wave in game.combat.waves: wave_indices.append(wave.index)
		game.step(DT,controls)
		var after: Dictionary = game.world_two.checkout.snapshot()
		var b: Dictionary = after.boss
		check(game.boss == null,"TB leaked into generic boss slot and changed special targeting")
		check(game.movement_skills.skills.is_empty() and game.abilities.skills.is_empty(),"unearned skill appeared")
		check(absf(game.player.x-point0.x) < 20,"route used a teleport/barrier snap instead of ordinary movement")
		check(game.player.y <= game.level.fall,"route relied on fall recovery")
		check(game.world_two.end_time == 0,"normal timed exit started instead of checkout jar objective")
		if grounded0 and not game.grounded and game.velocity.y < 0 and controls.jump: jumps += 1
		if controls.aim: aim_frames += 1
		if controls.down: down_inputs += 1
		if active0.is_empty() and not game.abilities.active.is_empty():
			special_used = true
			check(game.abilities.active == character,"activated wrong housemate special")
		if not game.abilities.active.is_empty() and not b.is_empty(): special_frames += 1
		for pair in hp0:
			if pair[0].hp < pair[1] and active0.is_empty(): ordinary_enemy_damage = true
		for enemy in game.enemies:
			if enemy not in seen_enemies:
				seen_enemies.append(enemy)
				if b.is_empty(): approach_enemies.append(enemy)
				note("Checkout spawn %s frame=%d p=%s" % [enemy.kind,frame,enemy.p])
		for i in range(3):
			var wave: Dictionary = game.combat.waves[i]
			consumed += wave.index-int(wave_indices[i])
			if wave.started and i not in started: started.append(i)
			if wave.done and i not in completed:
				completed.append(i)
				check(wave.index == wave.group.size(),"approach wave finished before all dispatches")
				note("Checkout wave %d done frame=%d p=%s" % [i,frame,game.player])
		for i in range(3):
			if game.receipts[i].taken and i not in collected:
				collected.append(i)
				check(absf(game.player.x-RECEIPTS[i][0]) < 42 and game.player.y > RECEIPTS[i][1]-30 and game.player.y-game.character_height() < RECEIPTS[i][1],"receipt lacked real source body contact")
		if not b.is_empty():
			check(b.x == 4760 and b.max == 70,"source stationary solo boss changed")
			check(b.codes.is_empty() and b.dizzy == 0,"dormant codes/dizzy or auto-target stun invented")
			check(game.camera.x <= 4162.01,"checkout camera cap exceeded")
			if entry_frame < 0:
				entry_frame = frame
				check(completed == [0,1,2] and game.camera.x >= 4160,"TB booted before all approach waves/source endpoint")
				check(b.state == "enter" and b.hp == 70 and b.phase == 1,"source boot state changed")
				note("Checkout entry frame=%d p=%s" % [frame,game.player])
			if b.phase not in phases: phases.append(b.phase)
			if b.state == "fight" and fight_frame < 0:
				fight_frame = frame
				check(frame-entry_frame == 84,"boot did not last strictly more than1.4 seconds")
			if b.phase == 1:
				check(b.hp == 70,"phase1 shots/special wrongly damaged TB")
				if controls.shoot and b.state == "fight": phase1_shot_frames += 1
				if b.beam != null:
					if b0.is_empty() or b0.beam == null:
						beam_starts += 1
						if b.beam.y not in beam_heights: beam_heights.append(b.beam.y)
					if b.beam.t <= 0.9: beam_warning_frames += 1
					if b.beam.t > 0.9 and b.beam.t < 1.45: beam_harm_frames += 1
			if not b0.is_empty() and b.beams > b0.beams and b0.phase == 1:
				beam_completions += 1
				check(b0.beam != null and b0.beam.t <= 1.6+0.00001 and b0.beam.t+DT > 1.6,"scanner completion did not follow actual full beam")
			if b.phase == 2 and phase2_frame < 0:
				phase2_frame = frame
				check(b0.phase == 1 and b0.beams == 3 and b0.beam == null,"phase2 was not next update after actual third beam")
				note("Checkout phase2 frame=%d p=%s" % [frame,game.player])
			if b.crates.size() == 3 and (b0.is_empty() or b0.crates.is_empty()): batch += 1
			for crate in b.crates:
				var key := "%d:%d" % [batch,crate.k]
				if not crate_history.has(key): crate_history[key] = []
				var history: Array = crate_history[key]
				if crate.st not in history:
					history.append(crate.st)
					note("Checkout crate %s %s frame=%d p=%s" % [key,crate.st,frame,crate.p])
					if crate.st == "carry": check(game.player.y > 422 and crate.by != null,"crate pickup lacked source ground contact")
					if crate.st == "fly":
						flights += 1
						check("carry" in history and game.player.x > 4335,"crate did not auto-throw from a real carrier")
						check(crate.target == TRAY_TARGETS[(b.placed-1)%3],"source tray placement changed")
				if crate.st == "fly":
					var k: float = minf(1,crate.t/0.65)
					var expected: Vector2 = crate.start.lerp(crate.target,k)-Vector2(0,sin(k*PI)*160)
					check(crate.p.distance_to(expected) < 0.001,"crate missed source650ms/sine flight")
				if crate.st == "on": check(crate.p.distance_to(crate.target) < 0.001 and crate.t >= 0.65,"crate teleported to tray early")
			if b.frozen > 0 and (b0.is_empty() or b0.frozen <= 0):
				freeze_count += 1
				check(b.placed >= 3 and b.crates.size() == 3 and b.crates.all(func(c): return c.st == "on"),"freeze happened without three completed real flights")
				check(b.frozen == 5 and b.beam == null,"freeze did not begin source5s/cancel beam")
				note("Checkout frozen frame=%d hp=%d" % [frame,b.hp])
			if not b0.is_empty() and b.hp < b0.hp:
				var damage: int = b0.hp-b.hp
				var hits0: int = before.players.get(game.get_instance_id(),{}).get("boss_hits",0)
				var hits1: int = after.players.get(game.get_instance_id(),{}).get("boss_hits",0)
				if b0.phase == 2:
					frozen_damage += damage
					check(b0.frozen > 0 and b.hp >= 21,"phase2 damage bypassed freeze or21HP floor")
					if power0.is_empty() and active0.is_empty() and game.abilities.effects.is_empty():
						check((damage in [2,3] or (b.hp == 21 and damage == 1)) and hits1-hits0 == 1,"single normal frozen projectile did not use fixed2/3 damage/floor truncation/hit credit")
						normal_fixed_hits += 1
				elif b0.phase == 3:
					phase3_damage += damage
					if power0.is_empty() and active0.is_empty() and game.abilities.effects.is_empty():
						check(damage == 3 and hits1-hits0 == 1,"real phase3 screen shot lost fixed3 damage/hit credit")
			if b.phase == 2 and b.hp == 21:
				floor_observed = true
				if floor_frame < 0: floor_frame = frame
			if b.phase == 3 and phase3_frame < 0:
				phase3_frame = frame
				check(floor_observed and b0.phase == 2 and b0.frozen == 0 and b.hp == 21,"phase3 bypassed source floor/freeze-expiry ordering")
				check(game.enemies.filter(func(e): return e.state != "pop").size() >= 2,"phase3 immediate helper pair missing")
				note("Checkout phase3 frame=%d hp=%d" % [frame,b.hp])
			var surfaces: Array = game.world_two.surfaces(game).filter(func(s): return s.get("receipt",false))
			check(surfaces.size() == b.steps,"generated receipt stairs are not real collision surfaces")
			for i in range(surfaces.size()):
				check(equal_rows(surfaces[i].row,STEPS[i]) and surfaces[i].plat,"source receipt step geometry changed")
				if i >= step_frames.size():
					step_frames.append(frame)
					check(frame-(phase3_frame-1 if i == 0 else step_frames[i-1]) == 37,"receipt step did not emit at strictly greater than600ms")
				if game.grounded and game.on_platform and game.player.x >= STEPS[i][0] and game.player.x <= STEPS[i][1] and absf(game.player.y-STEPS[i][2]) < 0.01 and i not in landed:
					landed.append(i)
					note("Checkout landed step%d frame=%d p=%s" % [i,frame,game.player])
			if b.state == "down" and down_frame < 0:
				down_frame = frame
				check(landed == [0,1,2] and b.hp <= 0,"defeat preceded actual three-step climb/real damage")
				check(game.mode == "play" and after.jar.is_empty(),"defeat incorrectly cleared without jar")
				check(b.crates.is_empty() and b.beam == null and game.enemies.all(func(e): return e.state == "pop"),"defeat cleanup/helper pops missing")
				note("Checkout down frame=%d p=%s" % [frame,game.player])
		if not after.jar.is_empty():
			var jar: Dictionary = after.jar
			if jar_frame < 0:
				jar_frame = frame
				check(frame-down_frame == 90,"jar did not spawn strictly after1.5-second down state")
				check(absf(jar.t-DT) < 0.00001 and jar.p.distance_to(Vector2(4607.5,247.6666667)) < 0.001,"jar spawn frame skipped source physics")
			if jar.t <= 0.6+0.0000001 and absf(game.player.x-jar.p.x) < 50:
				age_blocked_overlap += 1
				check(not jar.got and game.mode == "play","jar collected before age gate")
			if jar.got:
				clear_frame = frame
				expected_bank = score0
				collection_gap = absf(game.player.y-jar.p.y)
				check(jar.t > 0.6 and absf(game.player.x-jar.p.x) < 50 and after.clear_reported,"clear lacked genuine age-gated horizontal jar contact")
				check(game.mode == "clear","jar collected but real completion was not called")
		if game.mode == "play": check(not game.save.get("cleared",{}).get("2-6",false),"checkout clear saved before real jar collection")
		if frame%900 == 0: note("Checkout trace [%s] frame=%d p=%s camera=%s receipts=%s boss=%s live=%s" % [character,frame,game.player,game.camera,collected,b if b.is_empty() else [b.state,b.phase,b.hp,b.beams,b.placed,b.frozen,b.steps],enemy_summary(game)])
		if game.mode in ["clear","over"]: break
	check(game.mode == "clear","bounded input-only route did not clear")
	check(started == [0,1,2] and completed == [0,1,2] and consumed == 14,"three source waves/all14 solo entries did not execute")
	check(approach_enemies.size() == 14,"not all14 authored approach enemies spawned")
	for kind in ENEMY_COUNTS: check(approach_enemies.filter(func(e): return e.kind == kind).size() == ENEMY_COUNTS[kind],"approach enemy count changed: "+kind)
	check(approach_enemies.all(func(e): return e.state == "pop" and e.hp <= 0),"approach enemy abandonment substituted for genuine defeat")
	check(collected == [0,1,2],"all three actual receipts were not collected in order")
	check(phases == [1,2,3] and beam_starts == 3 and beam_completions == 3,"real three-phase/three-scanner sequence missing")
	check(beam_warning_frames > 0 and beam_harm_frames > 0 and phase1_shot_frames > 0,"scanner tell/harm/bouncing shot coverage missing")
	check(batch >= 1 and flights >= 3 and freeze_count >= 1,"three distinct crate deliveries/freeze missing")
	for key in crate_history: check(crate_history[key] == ["fall","ground","carry","fly","on"],"crate bypassed a real lifecycle state: "+key)
	check(floor_observed and frozen_damage == 49 and phase3_damage >= 21 and normal_fixed_hits > 0,"real fixed damage/21HP floor/screen defeat missing")
	check(step_frames.size() == 3 and landed == [0,1,2],"three real generated stairs were not landed on")
	check(special_used and special_frames > 0 and jumps > 0 and aim_frames > 0 and down_inputs > 0 and ordinary_enemy_damage,"ordinary movement/jump/down/aim/fire/special coverage incomplete")
	check(age_blocked_overlap > 0 and clear_frame > jar_frame and collection_gap > 50,"age-gated horizontal-only jar collection not demonstrated")
	check(expected_bank == game.score,"clear did not bank all actual loose coins exactly once")
	check(JSON.stringify(game.level) == imported,"runtime/test mutated imported source content")
	check(game.save.get("cleared",{}).get("2-6",false),"real checkout clear missing in memory")
	var persisted: Dictionary = SaveStore.read_save()
	check(persisted.get("cleared",{}).get("2-6",false),"real checkout clear missing after disk reload")
	check(persisted.get("receipts",{}).get("2-6",[]) == [0,1,2],"receipts missing after disk reload")
	check(persisted.get("skills",[]).is_empty(),"saved unearned skills")
	check(persisted.get("kitty",0) == game.score,"real reward missing after disk reload")
	var banked_score: int = game.score
	var banked_save := JSON.stringify(persisted)
	for frame in range(180): game.step(DT,{})
	check(game.score == banked_score and JSON.stringify(SaveStore.read_save()) == banked_save,"post-clear frames duplicated reward/save")
	var passed := failures.is_empty()
	print("Checkout input run [",character,"]: ","PASS" if passed else "FAIL"," ticks=",ticks," waves=",completed," approach=",approach_enemies.size(),"/14 receipts=",collected," beams=",beam_completions," heights=",beam_heights," crates=",flights," freezes=",freeze_count," floor_frame=",floor_frame," stairs=",landed," jumps=",jumps," special=",special_used," aim=",aim_frames," duck=",down_inputs," jar_blocked=",age_blocked_overlap," jar_gap=",collection_gap," score=",game.score," mode=",game.mode)
	if not passed:
		printerr("Checkout failures [",character,"]: ",failures)
		printerr("Checkout last snapshot: ",game.world_two.checkout.snapshot())
		printerr("Remaining enemies: ",enemy_summary(game))
	return passed

func enemy_summary(game) -> Array:
	var result: Array = []
	for enemy in game.enemies:
		if enemy.state != "pop": result.append([enemy.kind,enemy.p,enemy.hp,enemy.state])
	return result

func walk(game, controls: Dictionary, x: float, tolerance := 4.0) -> void:
	controls.right = x-game.player.x > tolerance
	controls.left = x-game.player.x < -tolerance

func face_right(game, controls: Dictionary) -> void:
	if game.face != 1: controls.right = true

func controls_for(game, frame: int, state: Dictionary) -> Dictionary:
	var controls := {"left":false,"right":false,"jump":false,"down":false,"aim":false,"shoot":true,"special":false}
	var b: Dictionary = state.boss
	if b.is_empty():
		var target: Dictionary = {}
		for enemy in game.enemies:
			if enemy.state == "pop": continue
			if target.is_empty() or (target.kind == "drone" and enemy.kind != "drone") or ((target.kind == "drone") == (enemy.kind == "drone") and absf(enemy.p.x-game.player.x) < absf(target.p.x-game.player.x)): target = enemy
		if not target.is_empty():
			var dx: float = target.p.x-game.player.x
			if target.kind == "drone":
				controls.aim = true
				walk(game,controls,target.p.x,20)
			elif game.player.y < target.p.y-80 and game.on_platform:
				controls.down = true
				controls.jump = not game.jump_held
			else:
				if game.face != (1 if dx >= 0 else -1):
					controls.right = dx >= 0; controls.left = dx < 0
				if frame%180 == 0: controls.down = true
			return controls
		var destination := 4510.0
		for i in range(3):
			if not game.receipts[i].taken:
				destination = float(RECEIPTS[i][0]); break
		walk(game,controls,destination)
		return controls
	if b.state == "down":
		controls.shoot = false
		if not state.jar.is_empty(): walk(game,controls,state.jar.p.x,5)
		else: walk(game,controls,4590)
		return controls
	if b.phase == 1:
		walk(game,controls,4390)
		if absf(game.player.x-4390) < 8: face_right(game,controls)
		if b.state == "fight" and not special_used and game.abilities.meter >= 1: controls.special = true
		if b.beam != null:
			if b.beam.y < 382 and b.beam.t > 0.5 and b.beam.t < 1.5:
				controls.down = true; controls.left = false; controls.right = false
			elif b.beam.y > 382 and b.beam.t > 0.78 and b.beam.t < 1.0 and game.grounded and not game.jump_held: controls.jump = true
		return controls
	if b.phase == 2:
		if b.frozen > 0:
			walk(game,controls,4390)
			face_right(game,controls)
			if game.grounded and not game.jump_held: controls.jump = true
			return controls
		controls.shoot = false
		if b.crates.any(func(c): return c.st == "carry"): walk(game,controls,4375)
		else:
			var ground: Array = b.crates.filter(func(c): return c.st == "ground")
			ground.sort_custom(func(a,c): return absf(a.p.x-game.player.x) < absf(c.p.x-game.player.x))
			if not ground.is_empty(): walk(game,controls,ground[0].p.x)
		return controls
	# Do not chip TB from the floor and skip the intended receipt climb.
	controls.shoot = false
	if climbed < 3:
		var row: Array = STEPS[climbed]
		if game.grounded and absf(game.player.y-row[2]) < 0.01 and game.player.x >= row[0] and game.player.x <= row[1]:
			climbed += 1
			if climbed == 3: return controls
			row = STEPS[climbed]
		if b.steps <= climbed: return controls
		var destination: float = (float(row[0])+float(row[1]))/2.0
		walk(game,controls,destination,3)
		if game.grounded and not game.jump_held and absf(destination-game.player.x) < 110: controls.jump = true
		return controls
	face_right(game,controls)
	controls.shoot = true
	return controls
