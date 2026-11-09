extends SceneTree
## Actual-main physical pickups. Explicit LOCAL source-surface fixtures are not
## whole-stage traversal evidence. After fixture setup: controls + invulnerability
## only. Every receipt is tested twice per character, with real disk persistence.
const SaveStore = preload("res://src/save_store.gd")
const DT := 1.0 / 60
const PRIOR_SKILLS := ["slide", "double-jump", "ground-pound", "dash"]
const FIXTURES := {
	"5-1": [Vector2(300,482), Vector2(4080,152), Vector2(9180,-508)],
	"5-2": [Vector2(200,482), Vector2(11300,482), Vector2(27580,482)],
	"5-3": [Vector2(180,-178), Vector2(440,-1828), Vector2(180,-2818)],
	"5-4": [Vector2(300,482), Vector2(5480,362), Vector2(3820,370)],
	"5-5": [Vector2(330,420), Vector2(330,420), Vector2(280,420)],
	"5-6": [Vector2(300,482), Vector2(1900,482), Vector2(3780,482)],
	"5-S": [Vector2(1850,482), Vector2(14450,482), Vector2(27050,482)],
}
var checks := 0
var failures: Array[String] = []
var game
var receipt_cases := 0
var card_cases := 0
var lift_cases := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)
func fresh(id: String, who: String) -> void:
	game.character = who
	game.save = {"schema": 1, "receipts": {}, "skills": PRIOR_SKILLS.duplicate(), "kitty": 41}
	check(SaveStore.write_save(game.save) == OK, id + " isolated save initialized")
	check(game.load_level(id), id + " loads")
func fixture(point: Vector2) -> void:
	# A source-authored standing surface, never the pickup itself. This is the
	# sole placement step and occurs before any test interaction frame.
	game.player = point; game.velocity = Vector2.ZERO
	game.grounded = true; game.on_platform = false
	game.camera = Vector2(clampf(point.x - 400, 0, maxf(0, float(game.level.w) - game.view_width())), minf(0, point.y - 482))
	game._last_floor = point.y
	for scene in game.world_five._scenes:
		if scene.to < point.x: scene.done = true
	if not game.world_five.sofa.is_empty(): game.world_five.sofa.x = point.x; game.world_five.sofa.fy = point.y
	var support: Dictionary = game.world_five.land_on(game, point.x, point.y - 1, point.y + 1)
	check(not support.is_empty(), game.level_id + " fixture starts on actual source support " + str(point))
	if not support.is_empty(): game.on_platform = support.plat
func run() -> void:
	game = load("res://main.tscn").instantiate(); root.add_child(game); game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	for who in game.CHARACTERS:
		if OS.get_cmdline_user_args().has("--quick") and who != "jp": continue
		for id in FIXTURES:
			for index in 3: receipt(id, who, index)
		card_and_wall_jump(who)
		lift_from_spawn(who)
	game.queue_free(); await process_frame; await process_frame
	print("World 5 collectibles: %d checks, %d failures; %d local receipt fixtures + %d replay pickups, %d card/use and %d input-only lift runs. Not device/difficulty proof." % [checks, failures.size(), receipt_cases, receipt_cases, card_cases, lift_cases])
	quit(0 if failures.is_empty() else 1)
func receipt(id: String, who: String, index: int) -> void:
	receipt_cases += 1
	fresh(id, who)
	var source := JSON.stringify(game.meta)
	var label := id + " " + who + " receipt " + str(index)
	var point: Vector2 = game.receipts[index].position
	var original: Array = game.level.receipts[index]
	check(point == Vector2(60 if index == 0 and id in ["5-1","5-2","5-4","5-6"] else original[0], original[1]), label + " source placement or declared first-receipt repair")
	for replay in 2:
		if replay:
			game.save = SaveStore.read_save(); game.load_level(id)
			check(game.receipts[index].previously_collected and not game.receipts[index].taken, label + " replay ghost from disk")
		fixture(FIXTURES[id][index])
		check(not game.world_five.finds_near(game, point), label + " fixture outside pickup bounds")
		var start: Vector2 = game.player
		for tick in 480:
			if game.receipts[index].taken or game.mode != "play": break
			game.invincible = 99
			game.step(DT, approach(point))
			if OS.get_cmdline_user_args().has("--trace") and tick % 30 == 0 and id == "5-S" and index == 0: print("PICKTRACE ", tick, " p=", game.player, " v=", game.velocity, " double=", game.movement_skills.double_jumped, " grounded=", game.grounded)
		if not game.receipts[index].taken: print("PICKFAIL ", label, " p=", game.player, " camera=", game.camera, " target=", point)
		check(game.receipts[index].taken, label + " physical ordinary-input pickup" + (" replay" if replay else ""))
		check(game.player.distance_to(start) > 35 and game.world_five.finds_near(game, point), label + " moved into source 36/90 pickup box")
		var physically_taken: Array = []
		for i in game.receipts.size():
			if game.receipts[i].taken: physically_taken.append(i)
		var disk_indices: Array = SaveStore.read_save().receipts.get(id, []).duplicate(); disk_indices.sort()
		var memory_indices: Array = game.save.receipts.get(id, []).duplicate(); memory_indices.sort()
		check(index in physically_taken and disk_indices == physically_taken and memory_indices == physically_taken, label + " exact physical pickup identities on disk, no duplicate")
		check(game.receipt_score == 0 and game.save.kitty == 41, label + " receipt gives no score or premature banking")
		check(JSON.stringify(game.meta) == source, label + " immutable imported META")
func approach(target: Vector2) -> Dictionary:
	var direction := signf(target.x - game.player.x) if absf(target.x - game.player.x) > 5 else 0.0
	var wall: bool = direction != 0 and absf(game._wall_clamp(game.player.x, game.player.x + direction * 35, game.player.y) - (game.player.x + direction * 35)) > 0.5
	var jump: bool = not game.jump_held and ((game.grounded and (game.player.y - target.y > 40 or wall)) or (not game.grounded and game.velocity.y >= 0 and game.player.y > target.y + 70 and not game.movement_skills.double_jumped))
	return {"left": direction < 0, "right": direction > 0, "jump": jump}
func card_and_wall_jump(who: String) -> void:
	card_cases += 1
	fresh("5-4", who)
	var source := JSON.stringify(game.meta)
	var label := who + " 5-4 wall-jump"
	check(game.level.card == [3560.0,482.0] and not game.movement_skills.has_skill("wall-jump"), label + " exact source card, initially locked")
	fixture(Vector2(3440,482))
	for tick in 90:
		game.invincible = 99; game.step(DT, {"right": true})
		if game.movement_skills.card_collected: break
	check(game.movement_skills.card_collected and game.movement_skills.has_skill("wall-jump") and absf(game.player.x - 3560) < 44 and absf(game.player.y - 482) < 110, label + " actual pickup inside 44/110 source bounds")
	check(SaveStore.read_save().skills.count("wall-jump") == 1 and game.abilities.skills.has("wall-jump"), label + " disk + abilities unlock once")
	var used := false
	# Continue directly from the pickup to the source's two-block tutorial wall.
	# No player/camera/skill rewrite between card pickup and observed wall kick.
	for tick in 600:
		game.invincible = 99
		var wall: bool = absf(game._wall_clamp(game.player.x, game.player.x + 24, game.player.y) - game.player.x - 24) > 0.5
		var jump: bool = not game.jump_held and ((game.grounded and wall) or (not game.grounded and wall))
		game.step(DT, {"right": true, "jump": jump})
		if "wall-jump" in game.movement_skills.events:
			used = true
			check(game.velocity.y < -850 and game.velocity.x < 0 and game.face == -1, label + " real wall collision produces upward outward kick")
			break
	check(used, label + " ordinary controls use newly collected card")
	check(JSON.stringify(game.meta) == source, label + " META unchanged")
	game.save = SaveStore.read_save(); game.load_level("5-4")
	check(game.movement_skills.has_skill("wall-jump") and game.abilities.skills.has("wall-jump"), label + " reload restores both skill consumers")
	fixture(Vector2(3440,482))
	for tick in 90:
		game.invincible = 99; game.step(DT, {"right": true})
		if game.movement_skills.card_collected: break
	check(game.movement_skills.card_collected and SaveStore.read_save().skills.count("wall-jump") == 1, label + " replay card remains physical and deduplicates")
	game.load_level("5-3")
	check(game.movement_skills.has_skill("wall-jump") and not game.movement_skills.CARDS.has("5-3"), label + " carried into lift stage, which has no source card")
func lift_from_spawn(who: String) -> void:
	lift_cases += 1
	fresh("5-3", who)
	var source := JSON.stringify(game.meta)
	var seen := {}; var carried := false
	for tick in 9000:
		game.invincible = 99
		var old_y: float = game.player.y
		game.step(DT, {"right": game.player.x < 655, "left": game.player.x > 665})
		var lift: Dictionary = game.world_five.lift
		seen[lift.state] = true
		if game.grounded and absf(game.player.x - 660) < 10 and absf(game.player.y - lift.surface.row[2]) < 4 and absf(game.player.y - old_y) > 0.1: carried = true
		if seen.has("shake") and seen.has("drop") and lift.state == "wait" and carried: break
	check(carried and seen.has("wait") and seen.has("move") and seen.has("shake") and seen.has("drop"), who + " walks from spawn onto lift, rides and survives full malfunction cycle")
	check(JSON.stringify(game.meta) == source and game.mode == "play", who + " lift input route keeps source and live state")
