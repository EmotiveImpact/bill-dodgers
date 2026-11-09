extends SceneTree
## Isolated numeric/source-contract tests, not an input-driven stage clear.
const Bonus = preload("res://src/festival_bonus.gd")
const Combat = preload("res://src/festival_combat.gd")
const Base = preload("res://tests/test_world_three.gd")

# Only this test adapter enables an otherwise unpromoted runtime. Production
# native support and saved capabilities are deliberately not changed here.
class Runtime extends "res://src/world_three.gd":
	func supports(id: String) -> bool: return id == "3-S" or super.supports(id)

class Host extends Base.Host:
	var score := 0
	var items: Array = []
	var crates: Array = []
	var crouching := false
	var participants: Array = []
	var clear_count := 0
	var last_event: Dictionary = {}
	func _land(x: float, old_y: float, new_y: float) -> float:
		var surface: Dictionary = world_three.land_on(self, x, old_y, new_y)
		return INF if surface.is_empty() else float(surface.row[2])
	func consume_clear(event: Dictionary) -> void:
		# Completion adapter only: test the event's pre-sweep data against the
		# existing host's documented sweep contract. No production save claim.
		if event.is_empty() or mode != "play": return
		last_event = event.duplicate(true)
		score += coins.size()
		coins.clear()
		clear_count += 1
		mode = "clear"

class PairHost extends Host:
	func combat_participants() -> Array: return participants

var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func near(a: float, b: float) -> bool: return absf(a - b) < 0.000001

func fresh(h, bonus) -> void:
	h.combat = Base.StubCombat.new()
	h.world_three = Runtime.new()
	h.load_source("3-S")
	h.combat = Combat.new()
	h.combat.reset(h)
	h.score = 0
	h.clear_count = 0
	h.last_event = {}
	h.items.clear()
	bonus.reset(h)

func phase_step(dt: float, h, bonus) -> Dictionary:
	# The actual shared pickup/coin implementations are exercised. No fake
	# item collection or coin filtering is used by this isolation fixture.
	var runtime = h.world_three
	runtime.after_camera(dt, h)
	h.combat.pickups_tick(dt, h)
	h.collect_level_pickups()
	var early: Dictionary = bonus.before_authored_coins(h, runtime)
	if not early.is_empty(): return early
	runtime._authored_coins(h)
	return bonus.late_tick(dt, h, runtime)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var h := Host.new()
	var bonus := Bonus.new()
	fresh(h, bonus)
	_metadata_and_geometry(h, bonus)
	_spawn(h, bonus)
	_timeout(h, bonus)
	_empty_branch(h, bonus)
	_pickup_edges(h, bonus)
	_lifecycle(h, bonus)
	_pair_collection()
	_source_contract()
	print("Festival bonus: %d checks, %d failures (isolated; no full-run/device/save claim)" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _metadata_and_geometry(h, bonus) -> void:
	check(bonus.supports("3-S") and not bonus.supports("3-6") and not bonus.supports("2-S"), "3-S dispatch only")
	check(h.level.w == 9200 and h.level.start == 300 and h.level.fall == 882, "Exact source world/start/fall")
	check(h.meta.l3.timer == 90000 and h.meta.l3.noEnd and h.meta.l3.music == "bonus", "Ninety seconds, no width end, source music")
	check(h.combat.waves.is_empty() and h.crates.is_empty() and h.world_three.tents.is_empty() and h.boss == null, "No invented waves, crates, tents or boss")
	check(h.level.duck.is_empty() and h.level.mud.is_empty() and h.level.fires.is_empty() and h.level.spots.is_empty() and h.level.movers.is_empty(), "No bonus hazards beyond authored geometry")
	check(h.world_three.surfaces(h).size() == 28 and h.world_three.surfaces(h, true).size() == 25, "25 solid and three one-way platform rows")
	var source_meta := JSON.stringify(h.meta)
	for i in 3:
		var row: Array = h.level.plats[i]
		var roof: Dictionary = h.world_three.land_on(h, float(row[0]), 240, 246)
		check(roof.plat and roof.nospawn and roof.style == "vanroof" and roof.row == row, "Authored invisible roof %d" % i)
		check(h.world_three.land_on(h, float(row[0]), 240, 246, true).is_empty(), "Drop skips roof %d" % i)
		check(h.world_three.receipt_position(h.level.receipts[i]) == Vector2([2000,5600,7400][i],182), "Receipt exact source center %d" % i)
	check(h.world_three.receipt_reward() == 0, "Receipt adds no money")
	h.player = Vector2(2000,246)
	check(h.world_three.finds_near(h, Vector2(2000,182)), "Roof-height receipt body overlap")
	check(not h.world_three.finds_near(h, Vector2(2042,182)), "Receipt 42px x edge strict")
	check(not h.world_three.finds_near(h, Vector2(2000,56)), "Receipt body top edge strict")
	check(not h.world_three.finds_near(h, Vector2(2000,266)), "Receipt body bottom edge strict")
	h.camera.x = float(h.level.w) - h.view_width()
	check(h.world_three.objective_tick(999,h) == "" and h.world_three.end_time == 0, "Far-right boundary never starts standard ending")
	check(JSON.stringify(h.meta) == source_meta, "Geometry/objective reads keep metadata immutable")

func _spawn(h, bonus) -> void:
	fresh(h, bonus)
	check(bonus.before_authored_coins(h,h.world_three).is_empty(), "Initial empty inventory must not clear")
	check(phase_step(0.034,h,bonus).is_empty(), "First late phase starts clock without early clear")
	check(h.pickup_observations[0].coins == 0 and h.coins.size() == 179, "Finds precede all179 authored coin creation")
	check(near(bonus.timer_elapsed,0.034) and h.coins.all(func(c):return c.stay and c.rest and c.age == 0.3 and c.v == Vector2.ZERO), "Spawned coins wait until next pickup tick")
	check(h.coins.filter(func(c):return c.p.y == 442).size() == 72, "Nine low rows of eight")
	check(h.coins.filter(func(c):return c.p.y < 283 and c.p.y > 220).size() == 80, "Eight arcing rows of ten")
	check(h.coins.filter(func(c):return c.p.y == 182).size() == 27, "Three rooftop rows of nine")
	var index := 0
	for row in h.level.coinRows:
		for i in int(row[3]):
			var expected := Vector2(float(row[0])+i*float(row[2]),float(row[1])-sin(i/float(maxi(1,int(row[3])-1))*PI)*float(row[4]))
			check(h.coins[index].p.distance_to(expected) < 0.001, "Exact authored coin position %d" % index)
			index += 1
	h.world_three._authored_coins(h)
	check(h.coins.size() == 179, "Authoring pass is once per fresh run")

func _timeout(h, bonus) -> void:
	fresh(h, bonus)
	var source_meta := JSON.stringify(h.meta)
	var frames := 0
	while h.mode == "play" and frames < 2700:
		frames += 1
		var event := phase_step(0.034,h,bonus)
		if not event.is_empty(): h.consume_clear(event)
	check(frames == 2648 and near(bonus.timer_elapsed,90.032), "Idle timeout at90032ms using actual34ms steps")
	check(h.player == Vector2(300,482) and h.score == 179 and h.last_event.score_before_sweep == 0, "Preserve source defect: idle timeout banks179 uncollected coins")
	check(h.last_event.reason == "timeout" and h.last_event.remaining_coins == 179 and h.last_event.banner == "Time's up!" and h.last_event.sub == "£0 for the jar", "Timeout banner captures pre-sweep score")
	check(h.coins.is_empty() and h.clear_count == 1, "Host clears surviving inventory once")
	check(bonus.late_tick(1,h,h.world_three).is_empty() and bonus.before_authored_coins(h,h.world_three).is_empty(), "No repeat event after completion")
	check(JSON.stringify(h.meta) == source_meta, "Full timer simulation leaves source metadata unchanged")
	fresh(h,bonus)
	h.world_three._authored_coins(h)
	check(bonus.late_tick(89.999,h,h.world_three).is_empty(), "Timer remains live just below90s")
	var exact: Dictionary = bonus.late_tick(0.001,h,h.world_three)
	check(not exact.is_empty() and near(bonus.timer_elapsed,90), "Timer completes at inclusive90s")

func _empty_branch(h, bonus) -> void:
	fresh(h,bonus)
	h.world_three._authored_coins(h)
	h.coins.clear()
	h.score = 7
	bonus.timer_elapsed = 89.99
	var loose := {"p":Vector2(2000,182),"v":Vector2.ZERO,"age":0.3,"rest":true}
	h.coins.append(loose)
	var early: Dictionary = bonus.before_authored_coins(h,h.world_three)
	check(early.reason == "empty" and early.banner == "All collected!" and early.sub == "£7 for the jar", "No stay coins clears even with a loose coin left")
	check(early.remaining_coins == 1 and h.coins.size() == 1 and h.score == 7, "Rules event never sweeps or changes money itself")
	check(bonus.late_tick(1,h,h.world_three).is_empty() and near(bonus.timer_elapsed,89.99), "Early branch wins over simultaneous timeout and skips clock")
	h.consume_clear(early)
	check(h.score == 8, "Empty branch still sweeps residual non-stay coin")
	fresh(h,bonus)
	h.world_three._authored_coins(h)
	h.camera.x = 9000
	var cull_clear := phase_step(0.034,h,bonus)
	check(h.coins.is_empty() and h.score == 0 and cull_clear.reason == "empty", "Behind-camera deletion alone can satisfy All collected")
	check(bonus.timer_elapsed == 0 and cull_clear.remaining_coins == 0, "Deleted coins are not resurrected or awarded by clear")
	fresh(h,bonus)
	h.world_three._authored_coins(h)
	h.coins = [{"p":Vector2(1,182),"v":Vector2.ZERO,"age":0.3,"rest":true,"stay":true,"dead":true}]
	check(bonus.before_authored_coins(h,h.world_three).is_empty(), "Early test uses stay presence, not an invented alive-coin filter")
	h.combat.pickups_tick(0,h)
	check(not bonus.before_authored_coins(h,h.world_three).is_empty(), "Ordinary pickup filter removes dead stay before early test")

func _pickup_edges(h, bonus) -> void:
	fresh(h,bonus)
	h.world_three._authored_coins(h)
	h.coins = [{"p":Vector2(-60,442),"v":Vector2.ZERO,"age":12.0,"rest":true,"stay":true}, {"p":Vector2(-59.99,442),"v":Vector2.ZERO,"age":12.0,"rest":true,"stay":true}]
	h.combat.pickups_tick(0,h)
	check(h.coins.size() == 1 and h.coins[0].p.x > -60 and h.score == 0, "Camera-60 cull inclusive; stay coins do not expire at11s")
	h.coins = [{"p":Vector2(330,410),"v":Vector2.ZERO,"age":0.3,"rest":true,"stay":true}]
	h.combat.pickups_tick(0,h)
	check(h.score == 0 and h.coins.size() == 1, "Pickup x30 boundary strict")
	h.coins[0].p.x = 329.99
	h.combat.pickups_tick(0,h)
	check(h.score == 1 and h.coins.is_empty(), "Pickup inside x30 awards once")
	h.coins = [{"p":Vector2(300,302),"v":Vector2.ZERO,"age":0.3,"rest":true,"stay":true}]
	h.combat.pickups_tick(0,h)
	check(h.score == 1 and h.coins.size() == 1, "Pickup dy0.6height boundary strict")
	h.coins[0].p.y = 302.01
	h.combat.pickups_tick(0,h)
	check(h.score == 2 and h.coins.is_empty(), "Pickup inside body height")
	h.coins = [{"p":Vector2(300,410),"v":Vector2.ZERO,"age":0.25,"rest":true,"stay":true}]
	h.combat.pickups_tick(0,h)
	check(h.score == 2, "Pickup age250ms boundary strict")
	h.combat.pickups_tick(0.001,h)
	check(h.score == 3, "Pickup after250ms threshold")

func _lifecycle(h, bonus) -> void:
	fresh(h,bonus)
	h.world_three._authored_coins(h)
	bonus.late_tick(10,h,h.world_three)
	for state in ["paused","over","menu","clear","story"]:
		h.mode = state
		h.final_base_step = true
		check(bonus.late_tick(100,h,h.world_three).is_empty() and bonus.before_authored_coins(h,h.world_three).is_empty() and bonus.timer_elapsed == 10, "Exact source play guard: "+state)
	h.final_base_step = false
	h.mode = "play"
	bonus.late_tick(1,h,h.world_three)
	check(bonus.timer_elapsed == 11 and h.coins.size() == 179, "Continue preserves existing clock/inventory")
	var saved: Dictionary = bonus.snapshot()
	saved.timer_elapsed = 900
	check(bonus.timer_elapsed == 11, "Snapshot cannot mutate clock")
	var other := Host.new()
	var other_bonus := Bonus.new()
	fresh(other,other_bonus)
	check(bonus.late_tick(100,other,other.world_three).is_empty(), "Different host cannot advance old bonus")
	h.world_three.invalidate_run()
	check(bonus.late_tick(100,h,h.world_three).is_empty(), "Invalidated run rejects old clock")
	h.world_three.reset(h)
	check(bonus.late_tick(100,h,h.world_three).is_empty(), "Fresh generation rejects stale rules instance")
	bonus.reset(h)
	check(bonus.timer_elapsed == 0 and not bonus.completion_reported and bonus.clear_reason == "" and not h.world_three._coins_started, "Fresh reset restores initial phase")
	h.coins.clear()
	phase_step(0.034,h,bonus)
	check(h.coins.size() == 179 and near(bonus.timer_elapsed,0.034), "Fresh run recreates original coin rows")
	h.level_id = "3-1"
	check(bonus.late_tick(100,h,h.world_three).is_empty(), "Stage navigation prevents stale bonus completion")

func _pair_collection() -> void:
	var h := PairHost.new()
	var bonus := Bonus.new()
	fresh(h,bonus)
	h.participants = [{"p":Vector2(300,482),"hearts":0,"down":true,"height":180.0,"coins":0}, {"p":Vector2(500,482),"hearts":3,"down":false,"height":160.0,"coins":0}]
	h.coins = [{"p":Vector2(500,442),"v":Vector2.ZERO,"age":0.3,"rest":true,"stay":true}]
	h.combat.pickups_tick(0,h)
	check(h.score == 1 and h.participants[1].coins == 1 and h.participants[0].coins == 0, "Seeded pair uses living participant and individual pickup count")
	check(h.coins.is_empty(), "Pair pickup consumes shared coin once")
	# The production game remains solo. This fixture does not certify a pair
	# controller, split bank attribution on clear, networking or CPU behavior.

func _source_contract() -> void:
	var path := ProjectSettings.globalize_path("res://").path_join("../game/3-S/index.html")
	var source := FileAccess.get_file_as_string(path)
	for snippet in ["!coins.some((c) => c.stay)","c.x > cam - 60","(c.stay || c.t < 11000)","coins.forEach((c) => { const p = nearest(c.x) || players[0]; p.coins++; kitty++; }); coins = [];","timerT += dt; if (timerT >= L3.timer)","if (L3.noEnd || L3.boss) return false;","if (c.t > 9000 && Math.floor(c.t / 100) % 2) continue;"]:
		check(source.contains(snippet), "Original executable contract: "+snippet)
	var begin := source.find("function levelUpdate(dt)")
	var early := source.find("!coins.some((c) => c.stay)",begin)
	var spawn := source.find("if (!started3)",begin)
	var timer := source.find("timerT += dt",begin)
	check(begin < early and early < spawn and spawn < timer, "Original early test precedes spawn and late timer")
	var play := source.find("function updatePlay(dt)")
	check(source.find("updateCoins(dt); levelUpdate(dt)",play) < source.find("if (boss) updateBoss(dt)",play), "Source late bonus follows coins and precedes boss")
