extends SceneTree
## True main.tscn routes using only game.step controls after fresh setup.
## No invulnerability, actor/clock edits, synthetic rewards, gates or clears.
## Source culls/sweep are counted separately from physical collection.
class CountedGame extends "res://src/main.gd":
	# Observe actual persistence, then execute the production implementation.
	var observed_saves := 0
	func _save_progress() -> void:
		observed_saves += 1
		super._save_progress()
const SaveStore = preload("res://src/save_store.gd")
const DT := 1.0 / 60.0
const MAX_TICKS := 5500
const ROUTE := [
	Vector2(1100,482), Vector2(1300,428), Vector2(1500,374), Vector2(1670,482),
	Vector2(1810,428), Vector2(1940,374), Vector2(2120,246), Vector2(2290,246), Vector2(2600,482),
	Vector2(2900,482), Vector2(3100,428), Vector2(3300,374), Vector2(3550,482),
	Vector2(4700,482), Vector2(4900,428), Vector2(5100,374), Vector2(5270,482),
	Vector2(5410,428), Vector2(5540,374), Vector2(5720,246), Vector2(5890,246), Vector2(6200,482),
	Vector2(6500,482), Vector2(6700,428), Vector2(6900,374), Vector2(7070,482),
	Vector2(7210,428), Vector2(7340,374), Vector2(7520,246), Vector2(7690,246), Vector2(8000,482),
	Vector2(8300,428), Vector2(8500,374), Vector2(8720,482)]
var failures: Array[String] = []
var route_step := 0
var debug_run := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok and label not in failures: failures.append(label)
func fresh(game, character: String) -> void:
	game.character = character
	game.save = {"schema":1,"receipts":{},"skills":[],"kitty":13}
	check(SaveStore.write_save(game.save) == OK, "isolated save setup failed")
	check(game.load_level("3-S"), "bonus failed to load")
	game.observed_saves = 0
	check(game.is_native_supported() and game._native_world_three(), "actual native gate/runtime failed")
	check(game.festival_renderer == game.festival_bonus_renderer, "wrong actual painter")
	check(game.player == Vector2(300,482) and game.camera == Vector2.ZERO, "wrong initial player/camera")
	check(game.level.w == 9200 and game.level.fall == 882 and game.view_width() == 738, "source dimensions changed")
	check(game.level.solids.size() == 25 and game.level.plats.size() == 3 and game.world_three.surfaces(game).size() == 28, "authored surfaces changed")
	check(game.combat.waves.is_empty() and game.enemies.is_empty() and game.crates.is_empty() and game.world_three.tents.is_empty(), "invented bonus enemies/crates/tents")
	check(game.receipts.size() == 3 and game.receipts[0].position == Vector2(2000,182) and game.receipts[1].position == Vector2(5600,182) and game.receipts[2].position == Vector2(7400,182), "wrong actual receipts")
	check(game.meta.l3.timer == 90000 and game.meta.l3.noEnd and game.world_three.bonus.timer_elapsed == 0, "source timer/reset changed")
	check(game.movement_skills.skills.is_empty() and game.abilities.skills.is_empty(), "unearned starting skill")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.set_script(CountedGame)
	if not game.has_method("step"):
		printerr("Festival bonus main script failed to load"); game.free(); quit(1); return
	root.add_child(game); game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	var characters: Array = game.CHARACTERS
	var args := OS.get_cmdline_user_args()
	if "--jp-only" in args: characters = ["jp"]
	for arg in args:
		if arg.begins_with("--character="):
			var who := arg.trim_prefix("--character=")
			if who not in game.CHARACTERS:
				printerr("Unknown housemate: ",who); game.queue_free(); await process_frame; quit(1); return
			characters = [who]
	debug_run = "--trace" in args
	var passed := run_idle(game)
	for who in characters:
		if not run_character(game,who): passed = false
	game.queue_free(); await process_frame; quit(0 if passed else 1)
func verify_save(game, receipts: Array) -> void:
	check(game.observed_saves == receipts.size()+1, "normal persistence must run once per receipt and once per clear")
	var persisted: Dictionary = SaveStore.read_save()
	check(game.save.get("cleared",{}).get("3-S",false) and persisted.get("cleared",{}).get("3-S",false), "normal clear did not persist")
	check(persisted.get("receipts",{}).get("3-S",[]) == receipts, "actual receipt save mismatched")
	check(persisted.get("kitty",0) == 13+game.score, "normal bank did not add once")
	check(persisted.get("skills",[]).is_empty(), "unearned saved skill")
	var before := JSON.stringify(persisted); var score: int = game.score
	for i in range(180): game.step(DT,{})
	check(game.score == score and JSON.stringify(SaveStore.read_save()) == before and game.observed_saves == receipts.size()+1, "post-clear steps double-banked")
func run_idle(game) -> bool:
	failures.clear(); fresh(game,"maya")
	if not failures.is_empty(): printerr("Festival bonus idle blocked: ",failures); return false
	var ticks := 0
	for frame in range(MAX_TICKS):
		ticks = frame+1; game.step(DT,{})
		if frame == 0: check(game.coins.size() == 179 and game.coins.all(func(c): return c.stay and c.rest and c.age == 0.3), "all179 source coins were not late-seeded once")
		check(game.player == Vector2(300,482) and game.camera == Vector2.ZERO and game.hearts == 3, "idle route moved/hurt player")
		if game.mode == "clear": break
		check(game.mode == "play" and game.score == 0 and game.coins.size() == 179, "idle lost/collected/cleared coins before timeout")
	check(game.mode == "clear" and game.world_three.bonus.clear_reason == "timeout", "idle90seconds failed source timeout")
	check(game.world_three.bonus.timer_elapsed >= 90 and game.world_three.bonus.timer_elapsed < 90+DT+0.000001, "idle timer failed exact boundary")
	check(game.score == 179 and game.coins.is_empty(), "source idle sweep must bank179 without physical collection")
	check(game.status == "Time's up!. £0 for the jar", "idle banner lost source pre-sweep£0")
	verify_save(game,[])
	var passed := failures.is_empty()
	print("Festival bonus IDLE input run: ","PASS" if passed else "FAIL"," ticks=",ticks," timer=",game.world_three.bonus.timer_elapsed," physical=0 culled=0 swept=179 bank=",game.score," assists=none")
	if not passed: printerr(failures)
	return passed
func run_character(game, who: String) -> bool:
	failures.clear(); route_step = 0; fresh(game,who)
	if not failures.is_empty(): printerr("Festival bonus [",who,"] blocked: ",failures); return false
	var source := JSON.stringify(game.meta)
	var physical := 0; var culled := 0; var fallen := 0; var swept := 0; var jumps := 0; var ticks := 0
	var receipts: Array[int] = []; var bales: Array[int] = []; var roofs: Array[int] = []
	var authored: Array[Vector2] = []; var clear_score_before := -1
	for frame in range(MAX_TICKS):
		ticks = frame+1
		var controls := controls_for(game,frame)
		var before: Vector2 = game.player; var grounded_before: bool = game.grounded
		var coins_before: Array = game.coins.duplicate(); var score_before: int = game.score
		game.step(DT,controls)
		if grounded_before and not game.grounded and game.velocity.y < 0: jumps += 1
		var frame_physical := 0; var frame_culled := 0
		for c in coins_before:
			if c.get("dead",false):
				if c.p.y > game.level.fall: fallen += 1
				else: frame_physical += 1
			elif c.p.x <= game.camera.x-60: frame_culled += 1
			elif game.mode == "clear": swept += 1
		physical += frame_physical; culled += frame_culled
		if game.mode == "clear":
			clear_score_before = score_before+frame_physical
			check(game.score-score_before == frame_physical+swept, "clear score mismatches actual pickup plus sweep")
		else: check(game.score-score_before == frame_physical, "score came from a noncoin source")
		check(absf(game.player.x-before.x) < 10 and game.player.y <= game.level.fall, "unexpected actor warp/fall")
		check(game.hearts == 3 and game.invincible == 0, "route needed damage or invulnerability assist")
		check(game.combat.waves.is_empty() and game.enemies.is_empty() and game.boss == null and game.world_three.end_time == 0, "invented waves/boss/width-ending")
		for c in game.coins:
			if c.age == 0.3 and c.p not in authored: authored.append(c.p)
		if game.grounded:
			for i in range(game.level.solids.size()):
				var row: Array = game.level.solids[i]
				if row[3].style == "bales" and game.player.x >= row[0] and game.player.x <= row[1] and absf(game.player.y-row[2]) < 0.01 and i not in bales: bales.append(i)
			for i in range(game.level.plats.size()):
				var row: Array = game.level.plats[i]
				if game.player.x >= row[0] and game.player.x <= row[1] and absf(game.player.y-row[2]) < 0.01 and i not in roofs: roofs.append(i)
		for i in range(3):
			if game.receipts[i].taken and i not in receipts:
				receipts.append(i)
				var p: Vector2 = game.receipts[i].position
				check(absf(game.player.x-p.x) < 42 and p.y > game.player.y-game.character_height()-10 and p.y < game.player.y+20, "receipt lacked actual source overlap")
				if debug_run: print("Bonus receipt=",i," frame=",frame," player=",game.player)
		if debug_run and frame%600 == 0: print("Bonus trace [",who,"] frame=",frame," step=",route_step," player=",game.player," timer=",game.world_three.bonus.timer_elapsed," receipts=",receipts)
		if game.mode != "play": break
	check(game.mode == "clear", "ordinary-input route failed to clear")
	check(route_step >= ROUTE.size()-1, "did not traverse all authored route surfaces")
	check(receipts == [0,1,2] and roofs == [0,1,2], "did not obtain all actual receipts and land on all three roofs")
	check(bales.size() == 16 and jumps >= 19, "not all16 real bale surfaces or required jumps traversed")
	check(authored.size() == 179 and source_coins_match(game.level.coinRows,authored), "source179coin positions changed")
	check(physical > 0 and physical+culled+fallen+swept == 179, "physical/cull/fall/sweep accounting does not reconcile179")
	check(game.score == physical+swept, "culled coins incorrectly banked")
	check(game.status.ends_with("£%d for the jar" % clear_score_before), "banner did not capture actual pre-sweep kitty")
	check(JSON.stringify(game.meta) == source, "imported source mutated")
	check(game.abilities.skills.is_empty() and game.movement_skills.skills.is_empty(), "unearned run skill")
	verify_save(game,receipts)
	var passed := failures.is_empty()
	print("Festival bonus input run [",who,"]: ","PASS" if passed else "FAIL"," ticks=",ticks," timer=",game.world_three.bonus.timer_elapsed," reason=",game.world_three.bonus.clear_reason," route=",route_step,"/",ROUTE.size()," receipts=",receipts," bales=",bales.size(),"/16 roofs=",roofs," jumps=",jumps," physical=",physical," culled=",culled," fallen=",fallen," swept=",swept," bank=",game.score," assists=none")
	if not passed: printerr(failures)
	return passed
func source_coins_match(rows: Array, points: Array[Vector2]) -> bool:
	var count := 0
	for row in rows:
		for i in range(int(row[3])):
			var p := Vector2(float(row[0])+i*float(row[2]),float(row[1])-sin(i/float(maxi(1,int(row[3])-1))*PI)*float(row[4]))
			if not points.any(func(actual): return actual.distance_to(p) < 0.002): return false
			count += 1
	return count == points.size()
func controls_for(game, frame: int) -> Dictionary:
	var controls := {"left":false,"right":false,"jump":false,"down":false,"shoot":false,"aim":false,"special":false}
	if route_step < ROUTE.size():
		var goal: Vector2 = ROUTE[route_step]
		if game.grounded and absf(game.player.x-goal.x) < 13 and absf(game.player.y-goal.y) < 1:
			route_step += 1
			if debug_run: print("Bonus waypoint=",route_step," frame=",frame," player=",game.player)
	if route_step >= ROUTE.size(): return controls
	var goal: Vector2 = ROUTE[route_step]
	var dx: float = goal.x-game.player.x
	controls.right = dx > 3; controls.left = dx < -3
	if not game.grounded or game.jump_held: return controls
	var direction := 1 if dx >= 0 else -1
	if goal.y < game.player.y-6 and absf(dx) < (220 if goal.y == 246 else 110): controls.jump = true
	for row in game.level.solids:
		if row[2] >= game.player.y-6: continue
		var edge: float = row[0] if direction > 0 else row[1]
		var distance: float = (edge-game.player.x)*direction
		if distance >= 0 and distance < 65 and absf(dx) > distance: controls.jump = true
	return controls
