extends SceneTree
## Real-main seam fixtures. Explicit placements, selected clocks/inventories and
## probe subclasses isolate ordering; these are NOT the input-only full routes.
class CountedGame extends "res://src/main.gd":
	# Observe actual persistence, then execute the production implementation.
	var observed_saves := 0
	func _save_progress() -> void:
		observed_saves += 1
		super._save_progress()
const SaveStore = preload("res://src/save_store.gd")
const Campaign = preload("res://src/campaign_progression.gd")
const NativeLevels = preload("res://src/native_levels.gd")
const Bonus = preload("res://src/festival_bonus.gd")
const AudioLog = preload("res://tests/test_festival_integration.gd").AudioLog
class ProbePainter extends "res://src/festival_bonus_renderer.gd":
	var tags: Array[String] = []
	var calls := 0
	var hud_calls := 0
	func draw_commands(host, commands: Array) -> void:
		calls += 1
		for c in commands:
			var tag: String = c.get("tag","")
			if tag not in tags: tags.append(tag)
			if tag == "bonus_timer": hud_calls += 1
		super.draw_commands(host,commands)
class ProbeCombat extends "res://src/festival_combat.gd":
	var phases: Array = []
	func pickups_tick(dt: float, host) -> void:
		phases.append(["pickups",host.mode,host.world_three.bonus.timer_elapsed,host.coins.size()])
		super.pickups_tick(dt,host)
	func boss_tick(dt: float, host) -> String:
		phases.append(["boss",host.mode,host.world_three.bonus.timer_elapsed,host.coins.size()])
		return super.boss_tick(dt,host)
	func jar_tick(dt: float, host) -> String:
		phases.append(["jar",host.mode,host.world_three.bonus.timer_elapsed,host.coins.size()])
		return super.jar_tick(dt,host)
var game
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ",label)
func near(a: float,b: float) -> bool: return absf(a-b) < 0.00001
func fresh(who: String = "maya") -> void:
	game.character = who
	game.save = {"schema":1,"receipts":{},"skills":[],"kitty":13}
	check(SaveStore.write_save(game.save) == OK,"isolated save write")
	check(game.load_level("3-S"),"real bonus load")
	game.audio.clear_log(); game.combat.phases.clear(); game.observed_saves = 0
func stand(p: Vector2, camera_x: float = 0) -> void:
	game.player = p; game.camera = Vector2(camera_x,0); game.velocity = Vector2.ZERO
	game.camera_speed = 0; game.grounded = true; game.on_platform = false
	game._last_floor = p.y; game.world_three._standing_surface = {}
	game.invincible = 0; game.hurt_lock = 0; game.jump_held = false
func sentinel() -> void:
	game.coins = [{"p":Vector2(9000,442),"v":Vector2.ZERO,"age":0.3,"rest":true,"stay":true}]
func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.set_script(CountedGame)
	if not game.has_method("step"):
		printerr("Festival bonus integration: main script did not load"); game.free(); quit(1); return
	root.add_child(game); game.set_physics_process(false)
	game.audio.shutdown(); game.audio.queue_free(); game.audio = AudioLog.new()
	game.festival_combat = ProbeCombat.new()
	test_runtime_seed()
	test_empty_order()
	test_timeout_order()
	test_camera_cull_and_no_end()
	test_lifecycle()
	test_all_receipts()
	await test_render()
	test_campaign()
	game.queue_free(); await process_frame
	print("Festival bonus actual-main integration: ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
func test_runtime_seed() -> void:
	fresh()
	check(game.is_native_supported() and game._native_world_three() and game.scene_runtime == game.world_three,"production capability selects W3")
	check(game.festival_renderer == game.festival_bonus_renderer,"production selects actual bonus painter")
	check(game.world_three.stage_data == game.world_three.bonus.snapshot(),"stage_data exposes actual bonus snapshot")
	check(game.coins.is_empty() and not game.world_three._coins_started,"fresh inventory waits for late authored seed")
	check(game.combat.waves.is_empty() and game.enemies.is_empty() and game.boss == null and game.crates.is_empty(),"no invented enemies/objectives")
	var source := JSON.stringify(game.meta)
	stand(Vector2(500,482))
	game.step(0.02,{})
	check(game.mode == "play" and game.score == 0 and game.coins.size() == 179,"first empty inventory does not clear or collect newly seeded coins")
	check(game.coins.all(func(c): return c.rest and c.stay and c.age == 0.3 and c.v == Vector2.ZERO),"source late seed properties")
	check(near(game.world_three.bonus.timer_elapsed,0.02),"first late timer phase advances")
	check(game.combat.phases[0] == ["pickups","play",0.0,0],"actual pickup pass precedes authored coin seed and timer")
	check(game.combat.phases[1][0] == "boss" and game.combat.phases[1][3] == 179 and near(game.combat.phases[1][2],0.02),"timer executes before actual boss phase")
	game.step(0,{})
	check(game.score == 1 and game.coins.size() == 178,"source next frame permits physical collection")
	check(JSON.stringify(game.meta) == source,"runtime preserves imported metadata")
func test_empty_order() -> void:
	fresh(); game.step(0,{})
	game.coins = [{"p":Vector2(2600,442),"v":Vector2.ZERO,"age":0.3,"rest":true}]
	stand(Vector2(2000,300),1700)
	game.score = 7; game.world_three.bonus.timer_elapsed = 89.99
	game.world_three.cheer = 1; game.world_three.tied = 1
	game.combat.phases.clear()
	game.step(0.02,{})
	check(game.mode == "clear" and game.world_three.bonus.clear_reason == "empty","actual early empty clear wins over overdue timer")
	check(game.receipts[0].taken and game.save.receipts.get("3-S",[]) == [0],"actual find executes before early clear")
	check(game.score == 8 and game.coins.is_empty(),"normal completion sweeps loose coin even when no stay coin")
	check(game.status == "All collected!. £7 for the jar","source early banner is pre-sweep")
	check(near(game.world_three.bonus.timer_elapsed,89.99) and game.world_three.cheer == 1 and game.world_three.tied == 1,"early return skips timer and other late phases")
	check(game.world_three._coins_started,"empty branch did not reseed authored179")
	check(game.combat.phases[1][0] == "boss" and game.combat.phases[1][1] == "clear" and near(game.combat.phases[1][2],89.99),"base boss callback still follows early level return")
	check(SaveStore.read_save().kitty == 21 and SaveStore.read_save().receipts.get("3-S",[]) == [0],"find and clear persist through real host")
	check(game.observed_saves == 2,"early find and clear each invoke real persistence exactly once")
	var saved := JSON.stringify(SaveStore.read_save())
	game._complete_level(); game.step(10,{})
	check(JSON.stringify(SaveStore.read_save()) == saved and game.audio.effects.count("win") == 1 and game.observed_saves == 2,"repeated clear cannot double reward/save")
func test_timeout_order() -> void:
	fresh(); game.step(0,{})
	game.world_three.bonus.timer_elapsed = 89.98
	game.step(0.01,{})
	check(game.mode == "play" and near(game.world_three.bonus.timer_elapsed,89.99),"timeout does not fire just before90")
	game.combat.phases.clear(); game.step(0.01,{})
	check(game.mode == "clear" and near(game.world_three.bonus.timer_elapsed,90) and game.world_three.bonus.clear_reason == "timeout","actual timer clears at inclusive90seconds")
	check(game.combat.phases[0][1] == "play" and near(game.combat.phases[0][2],89.99),"final pickups observe old timer")
	check(game.combat.phases[1][0] == "boss" and game.combat.phases[1][1] == "clear" and near(game.combat.phases[1][2],90) and game.combat.phases[1][3] == 0 and game.combat.phases[2][0] == "jar" and game.combat.phases[2][1] == "clear" and near(game.combat.phases[2][2],90) and game.combat.phases[2][3] == 0,"timer completion precedes base boss/jar callbacks")
	check(game.score == 179 and SaveStore.read_save().kitty == 192 and game.status == "Time's up!. £0 for the jar","real timeout banks distant surviving inventory with old banner")
	check(game.audio.effects.count("win") == 1 and not game.audio.music_requested and game.observed_saves == 1,"actual completion saves/celebrates exactly once and stops music")
	fresh(); game.step(0,{})
	game.world_three.bonus.timer_elapsed = 89.99; game.hearts = 1
	game.bullets.append({"p":game.player-Vector2(0,40),"v":Vector2.ZERO,"enemy":true,"age":0.0,"gravity":0.0})
	game.step(0.01,{})
	check(game.audio.effects.count("hurt") == 1,"final-frame lethal projectile actually hit")
	check(game.mode == "clear" and game.hearts == 1 and game.world_three.bonus.clear_reason == "timeout","late source timeout precedes global knockout and revives celebration")
	check(SaveStore.read_save().cleared.get("3-S",false) and game.score == 179,"lethal final frame still banks actual source sweep")
func test_camera_cull_and_no_end() -> void:
	fresh(); game.step(0,{})
	stand(Vector2(9190,482),8462); game.world_three.bonus.timer_elapsed = 15
	game.step(0,{})
	check(game.mode == "play" and game.world_three.end_time == 0 and game.score == 0,"right-edge source noEnd prevents ordinary ending")
	check(game.coins.size() == 10,"camera culled169 coins without banking")
	game.step(0.01,{})
	check(game.mode == "play" and game.world_three.end_time == 0,"right edge cannot trigger clear with surviving stay coins")
	game.coins = [{"p":Vector2(8300,442),"v":Vector2.ZERO,"age":0.3,"rest":true,"stay":true}]
	var clock: float = game.world_three.bonus.timer_elapsed
	game.step(0.01,{})
	check(game.mode == "clear" and game.world_three.bonus.clear_reason == "empty" and game.score == 0,"behind-camera deletion really triggers source misleading All collected branch")
	check(near(game.world_three.bonus.timer_elapsed,clock) and SaveStore.read_save().kitty == 13,"camera-only clear skips late timer and banks nothing")
func test_lifecycle() -> void:
	fresh(); game.step(0.025,{})
	var clock: float = game.world_three.bonus.timer_elapsed
	var coins := JSON.stringify(game.coins); var position: Vector2 = game.player
	game._pause(); game.step(20,{"right":true})
	check(game.mode == "paused" and game.world_three.bonus.timer_elapsed == clock and JSON.stringify(game.coins) == coins and game.player == position,"real pause freezes bonus simulation")
	game._resume(); game.step(0.025,{})
	check(game.mode == "play" and near(game.world_three.bonus.timer_elapsed,clock+0.025),"actual resume keeps clock")
	game.hearts = 1; game.hurt_player(game.player.x+60)
	check(game.mode == "over","real hurt reaches knockout")
	clock = game.world_three.bonus.timer_elapsed; coins = JSON.stringify(game.coins); position = game.player
	game.step(20,{})
	check(game.world_three.bonus.timer_elapsed == clock and JSON.stringify(game.coins) == coins,"over freezes timer/inventory")
	game._continue_level()
	check(game.mode == "play" and game.hearts == 3 and game.invincible == 2.5 and game.player == position,"Continue revives in place")
	check(game.world_three.bonus.timer_elapsed == clock and JSON.stringify(game.coins) == coins,"Continue retains clock and coin inventory")
	var stale = Bonus.new(); stale.reset(game)
	var generation: int = game.world_three.run_generation
	game.load_level("3-S")
	check(game.world_three.run_generation > generation and game.world_three.bonus.timer_elapsed == 0 and not game.world_three.bonus.completion_reported and game.coins.is_empty(),"fresh replay resets clock/inventory/generation")
	check(stale.late_tick(100,game,game.world_three).is_empty() and stale.before_authored_coins(game,game.world_three).is_empty(),"captured older extension cannot finish replay")
	check(game.receipts.all(func(r): return not r.taken),"fresh replay resets actual finds")
	var snapshot: Dictionary = game.world_three.bonus.snapshot()
	game._show_menu(); game.step(100,{})
	check(game.world_three.bonus.late_tick(100,game,game.world_three).is_empty() and game.world_three.bonus.snapshot() == snapshot,"menu invalidation rejects late callback")
	fresh(); game.step(0,{})
	var other = load("res://main.tscn").instantiate(); root.add_child(other); other.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(other)
	other.save = {"schema":1,"receipts":{}}; other.load_level("3-S")
	check(game.world_three.bonus.late_tick(100,other,other.world_three).is_empty(),"foreign host cannot consume bonus callback")
	other.queue_free()
func test_all_receipts() -> void:
	for who in game.CHARACTERS:
		fresh(who); game.step(0,{})
		sentinel()
		for i in range(3):
			var receipt: Vector2 = game.receipts[i].position
			stand(Vector2(receipt.x-42,246),receipt.x-300); game.step(0,{})
			check(not game.receipts[i].taken,"strict receipt x42 ["+who+"/"+str(i)+"]")
			stand(Vector2(receipt.x,receipt.y+game.character_height()+10),receipt.x-300); game.step(0,{})
			check(not game.receipts[i].taken,"strict receipt upper body boundary ["+who+"/"+str(i)+"]")
			stand(Vector2(receipt.x,246),receipt.x-300); game.step(0,{})
			check(game.receipts[i].taken and game.score == 0,"real receipt pickup gives no money ["+who+"/"+str(i)+"]")
			check(SaveStore.read_save().receipts.get("3-S",[]).size() == i+1,"real receipt immediately persists ["+who+"/"+str(i)+"]")
		var saved := JSON.stringify(SaveStore.read_save()); game.step(0,{})
		check(JSON.stringify(SaveStore.read_save()) == saved and game.audio.effects.count("power") == 3,"receipts deduplicate per run ["+who+"]")
		check(game.abilities.skills.is_empty() and game.movement_skills.skills.is_empty() and game.save.get("skills",[]).is_empty(),"no bonus skill award ["+who+"]")
		game.load_level("3-S"); game.step(0,{}); sentinel(); stand(Vector2(2000,246),1700); game.step(0,{})
		check(game.receipts[0].taken and SaveStore.read_save().receipts.get("3-S",[]) == [0,1,2],"saved receipt remains replay-collectible without duplicate ["+who+"]")
func test_render() -> void:
	var painter = ProbePainter.new(); game.festival_bonus_renderer = painter
	game.festival_renderer = game.festival_field_renderer
	fresh(); game.step(0,{})
	check(game.festival_renderer == painter,"bonus renderer dispatched through actual main")
	var hud: Array = painter.build_hud(game,game.world_three)
	var timer: Array = hud.filter(func(c): return c.tag == "bonus_timer")
	check(timer.size() == 1 and timer[0].text == "90s" and timer[0].position == Vector2(480,98) and timer[0].size == 22,"actual HUD90seconds and original logical position")
	game.elapsed = 789; game.world_three.level_time = 222; game.world_three.bonus.timer_elapsed = 79.001
	hud = painter.build_hud(game,game.world_three)
	check(hud.filter(func(c): return c.tag == "bonus_timer")[0].text == "11s","HUD ceil uses bonus clock rather than host clocks")
	game.world_three.bonus.timer_elapsed = 80
	hud = painter.build_hud(game,game.world_three)
	check(hud.filter(func(c): return c.tag == "bonus_timer")[0].text == "10s" and hud.filter(func(c): return c.tag == "bonus_timer")[0].colour == Color("ffb3b3"),"actual urgent timer boundary")
	var saved := JSON.stringify(SaveStore.read_save()); var snapshot := JSON.stringify(game.world_three.snapshot()); var inventory := JSON.stringify(game.coins); var meta := JSON.stringify(game.meta)
	game.queue_redraw(); await process_frame; await process_frame
	check(painter.calls > 0 and painter.hud_calls > 0 and "bonus_stall_sign_label" in painter.tags,"actual main and overlay CanvasItem draw callbacks submitted original sign and timer commands")
	var calls: int = painter.calls
	game.queue_redraw(); await process_frame; await process_frame
	check(painter.calls > calls and JSON.stringify(game.world_three.snapshot()) == snapshot and JSON.stringify(game.coins) == inventory and JSON.stringify(game.meta) == meta and JSON.stringify(SaveStore.read_save()) == saved,"repeated actual draw callbacks are simulation/save/metadata pure")
	var signs: Array = []
	for x in [0,2300,4700,7700]:
		game.camera.x = x
		for c in painter.build_level(game,game.world_three):
			if c.tag == "bonus_stall_sign_label" and c.text == "Partner stall": signs.append(c)
	check(signs.size() == 4,"all four source Partner stall signs available through production painter")
	game._show_menu(); var prior: int = painter.hud_calls
	game.queue_redraw(); await process_frame; await process_frame
	check(painter.hud_calls == prior,"menu does not draw active timer")
func test_campaign() -> void:
	game.save = {"schema":1,"receipts":{},"skills":[],"cleared":{},"kitty":13,"seen":{"3-intro":true,"3-clue":true,"3-boss":true}}
	for world in [1,2]:
		for stage in range(1,7): game.save.cleared["%d-%d" % [world,stage]] = true
	game.save.cleared["3-1"] = true; game.save.cleared["3-2"] = true
	game._show_campaign()
	check(not game.start_campaign_level("3-S") and game.mode == "menu","actual map locks bonus before3-3")
	game.save.cleared["3-3"] = true
	check(game.start_campaign_level("3-S") and game.campaign_run and game.mode == "play","actual native bonus unlocks after3-3 without receipt quota or intro")
	check(not game.start_campaign_level("3-S"),"duplicate campaign entry rejected")
	game.step(0,{}); game.world_three.bonus.timer_elapsed = 89.99; game.step(0.01,{})
	check(game.mode == "clear" and not game.story.playing and SaveStore.read_save().cleared.get("3-S",false),"normal campaign bonus completion persists without invented story")
	game._settle_up(); game._campaign_next()
	check(game.mode == "menu" and game.campaign_target == "3-4","bonus settlement returns to next supported main stage")
	for stage in [4,5,6]: game.save.cleared["3-%d" % stage] = true
	check(game.start_campaign_level("3-S"),"completed bonus supports campaign replay")
	game.step(0,{}); game.world_three.bonus.timer_elapsed = 89.99; game.step(0.01,{})
	game._campaign_next()
	check(game.mode == "menu" and game.campaign_target == "4-1","completed World3 returns to honest World4boundary")
	check(NativeLevels.supports("4-1") and not game.save.cleared.get("4-1",false),"World4 is supported without an automatic campaign clear")
	var saved := JSON.stringify(SaveStore.read_save()); game.load_level("4-1"); game.level_id = "7-1"; game._complete_level()
	check(game.mode != "clear" and JSON.stringify(SaveStore.read_save()) == saved,"unknown-level completion cannot bank or persist")
