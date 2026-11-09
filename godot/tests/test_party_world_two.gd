extends SceneTree
## Real PartyCombat transactions with source W2 scenes/hazards/checkout.
## Deliberate geometry/phase fixtures, not claimed as input-driven full routes.
const Fixtures = preload("res://tests/test_party_combat_integration.gd")
const Party = preload("res://src/party_runtime.gd")
const Bridge = preload("res://src/party_combat.gd")
const Market = preload("res://src/supermarket_combat.gd")
const World = preload("res://src/world_two.gd")
const Hazards = preload("res://src/supermarket_hazards.gd")
const Course = preload("res://src/supermarket_course.gd")

class TraceHazards extends Hazards:
	func gates_tick(dt: float, host, runtime) -> void:
		host.trace.append("gates")
		super.gates_tick(dt, host, runtime)
	func drops_tick(dt: float, host, runtime) -> void:
		host.trace.append("drops")
		super.drops_tick(dt, host, runtime)
class TraceCourse extends Course:
	func hazards_tick(dt: float, host, runtime) -> void:
		host.trace.append("course")
		super.hazards_tick(dt, host, runtime)
class TraceCombat extends Market:
	func late_carts(dt: float, host) -> void:
		host.trace.append("carts")
		super.late_carts(dt, host)
	func late_drones(dt: float, host) -> void:
		host.trace.append("drones")
		super.late_drones(dt, host)
class TraceWorld extends World:
	func _scene_update(host) -> void:
		host.trace.append("scene")
		super._scene_update(host)
	func _repair_embedded_bots(host) -> void:
		host.trace.append("repair")
		super._repair_embedded_bots(host)
	func _checkpoint(host) -> void:
		host.trace.append("checkpoint")
		super._checkpoint(host)
	func _authored_coins(host) -> void:
		host.trace.append("coins")
		super._authored_coins(host)
	func _trolleys(dt: float, host) -> void:
		host.trace.append("trolleys")
		super._trolleys(dt, host)
class Host extends Fixtures.Host:
	var trace: Array = []
	var sounds: Array = []
	var pickups: Array = []
	var events: Array = []
	var completed := 0
	func view_width(): return 738.0
	func combat_owner_slot(): return bridge.active_slot
	func sfx(effect): sounds.append(effect)
	func party_capture_scene(actor): actor.scene_state.safe_position = world_two.safe_position
	func party_apply_scene(actor): world_two.safe_position = actor.scene_state.get("safe_position", actor.player)
	func collect_level_pickups():
		trace.append("pickups:%d" % bridge.active_slot)
		pickups.append({"slot": bridge.active_slot, "p": player, "hearts": hearts})
	func checkout_event(event): events.append(event)
	func _complete_level(): completed += 1; mode = "clear"

var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)
func near(a: float, b: float) -> bool: return absf(a - b) < 0.00001
func fresh(id := "2-1", selected_mode := "p2", source := false) -> Dictionary:
	var host := Host.new()
	host.level_id = id
	if source:
		host.meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/%s.json" % id))
		host.level = host.meta.level
	else:
		host.level = {"w": 3000, "solids": [[0, 3000, 482]], "plats": [], "hz": [], "waves": [], "crates": [], "fall": 742}
	var party = Party.new()
	party.configure(selected_mode, "jp", "maya")
	party.start(id, Vector2(300, 482))
	party.actors[1].player = Vector2(500, 482)
	for actor in party.actors: actor.scene_state.safe_position = actor.player
	party.actors[0].apply_native(host)
	host.combat = TraceCombat.new()
	host.world_two = TraceWorld.new()
	host.world_two.hazard_controller = TraceHazards.new()
	host.world_two.course_controller = TraceCourse.new()
	var bridge = Bridge.new()
	host.bridge = bridge
	bridge.configure(party, host)
	bridge.begin_shared()
	host.world_two.reset(host)
	host.combat.reset(host, 2)
	return {"host": host, "party": party, "bridge": bridge}
func _displace(host, dt: float, move: float) -> float: return host.world_two.base_displacement(dt, host, move)
func _safe(host) -> Vector2: return host.world_two.safe_position
func _remember_safe(host, p: Vector2) -> void:
	host.player = p
	host.world_two.after_motion(host)
func crate(point: Vector2, state := "ground") -> Dictionary:
	return {"p": point, "vy": 0.0, "st": state, "k": 0, "by": null}
func _initialize() -> void:
	_test_authored_levels()
	_test_ice_and_safe()
	_test_gates_and_contacts()
	_test_drops_and_clearance()
	_test_transition()
	_test_checkpoint_and_order()
	_test_course()
	_test_checkout()
	print("W2 party scenes: %d checks, %d failures. Real facade fixtures, not full input/device routes." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_authored_levels() -> void:
	for id in World.SUPPORTED_LEVELS:
		var f := fresh(id, "p2", true)
		var host = f.host
		check(host.world_two.hazards == host.level.get("hz", []) and host.world_two.unsupported_hazards.is_empty(), id + " source hazards remain complete")
		check(host.world_two.hazard_controller.gates.size() == host.world_two.hazards.filter(func(h): return h[0] == "gate").size(), id + " source gates initialized once")
		check(host.combat.waves.size() == host.level.waves.size(), id + " one authored wave roster")
		f.bridge.end_shared()

func _test_ice_and_safe() -> void:
	var f := fresh()
	var host = f.host
	var bridge = f.bridge
	host.level.hz = [["ice", 100, 900, 482]]
	host.world_two.reset(host)
	var first: float = bridge.call_for_actor(0, _displace, [host, 0.1, 1.0])
	var second: float = bridge.call_for_actor(1, _displace, [host, 0.1, -1.0])
	check(near(first, -second) and first > 27, "opposing ice controls keep independent momentum")
	check(host.world_two.hazard_controller.ice_velocity.keys().size() == 2 and host.world_two.hazard_controller.ice_velocity.has(0) and host.world_two.hazard_controller.ice_velocity.has(1), "ice identity is stable actor slot, not facade instance")
	bridge.record(0).grounded = false
	var airborne: float = bridge.call_for_actor(0, _displace, [host, 0.1, 0.0])
	check(airborne > 0 and near(host.world_two.hazard_controller.ice_velocity[1], second / 0.1), "airborne momentum decays for only its owner")
	bridge.record(0).grounded = true
	bridge.call_for_actor(0, _remember_safe, [host, Vector2(400, 482)])
	bridge.call_for_actor(1, _remember_safe, [host, Vector2(700, 482)])
	check(bridge.call_for_actor(0, _safe, [host]) == Vector2(400, 482) and bridge.call_for_actor(1, _safe, [host]) == Vector2(700, 482), "nested facade hooks restore independent safe floors")
	bridge.end_shared()
	check(f.party.actors[0].scene_state.safe_position == Vector2(400, 482) and f.party.actors[1].scene_state.safe_position == Vector2(700, 482), "safe floors persist after shared boundary")
	host.mode = "pause"
	var ice_before: Dictionary = host.world_two.hazard_controller.ice_velocity.duplicate()
	check(host.world_two.base_displacement(1, host, 1) == 0 and host.world_two.hazard_controller.ice_velocity == ice_before, "pause freezes ice history")
	host.mode = "play"
	host.world_two.reset(host)
	check(host.world_two.hazard_controller.ice_velocity.is_empty(), "new run clears both ice histories")

func _test_gates_and_contacts() -> void:
	for selected_mode in ["p2", "cpu"]:
		var f := fresh("2-2", selected_mode)
		var host = f.host
		var bridge = f.bridge
		host.level.hz = [["plate", 500, 482, "a"], ["gate", 800, 482, 230, "a"]]
		host.world_two.reset(host)
		var controller = host.world_two.hazard_controller
		controller.gates_tick(0.19, host, host.world_two)
		check(controller.plates[0].on and controller.gates[0].held and near(controller.gates[0].open, 0.5), selected_mode + " P2 alone holds pad while gate advances once")
		check(near(controller.gates[0].timer, 2.6 if selected_mode == "p2" else 5.2), selected_mode + " source participant-count hold time")
		bridge.record(1).p.x = 790
		controller.gates[0].open = 0.8
		controller.gates[0].timer = 0
		controller.gates_tick(0.1, host, host.world_two)
		check(controller.gates[0].open > 0.8, selected_mode + " P2 inside prevents closing gate")
		bridge.record(1).down = true; bridge.record(1).hearts = 0
		controller.gates_tick(0.1, host, host.world_two)
		check(controller.gates[0].open < 1 and not controller.plates[0].on, selected_mode + " downed actor cannot hold gate or pad")
		bridge.end_shared()
	var f := fresh()
	var host = f.host
	var bridge = f.bridge
	for record in bridge.participants(): record.p = Vector2(500, 482)
	host.world_two.entities = [{"k": "trolley", "p": Vector2(460, 482), "v": Vector2(400, 0), "t": 0.0, "dead": false}]
	host.world_two._trolleys(0.1, host)
	check(host.hits == [0, 1] and bridge.record(0).hearts == 2 and bridge.record(1).hearts == 2, "one trolley damages both actual victims")
	check(near(host.world_two.entities[0].p.x, 500) and near(host.world_two.entities[0].t, 0.1), "trolley motion and age tick once for two actors")
	host.world_two._trolleys(0, host)
	check(host.hits.size() == 2, "actor-specific invulnerability rejects repeat trolley hit")
	bridge.end_shared()
	check(f.party.actors[0].hearts == 2 and f.party.actors[1].hearts == 2, "trolley damage survives bridge end")

func _test_drops_and_clearance() -> void:
	var f := fresh("2-2")
	var host = f.host
	var bridge = f.bridge
	host.level.hz = [["drops", 100, 900, 200, "box"]]
	host.world_two.reset(host)
	var controller = host.world_two.hazard_controller
	controller.drops_tick(0.1, host, host.world_two)
	check(host.world_two.entities.is_empty() and near(controller.drop_counters[0], 0.1), "two occupants advance one drop-zone interval")
	controller.drops_tick(0.1, host, host.world_two)
	check(host.world_two.entities.size() == 1 and near(controller.drop_counters[0], 0) and near(host.world_two.entities[0].t, 0.1), "one new drop receives one full current-frame tick")
	for record in bridge.participants(): record.p = Vector2(500, 482)
	host.world_two.entities = [{"k": "drop", "p": Vector2(500, 400), "vy": 0.0, "top": 482.0, "t": 1.0, "warn": 0.95, "dead": false}]
	controller.drops_tick(0, host, host.world_two)
	check(host.hits == [0, 1] and host.world_two.entities[0].dead, "single falling stock hits both overlapping victims before removal")
	bridge.end_shared()
	check(f.party.actors[0].hearts == 2 and f.party.actors[1].hearts == 2, "falling stock injury remains actor-scoped after reconciliation")
	f = fresh("2-5"); host = f.host; bridge = f.bridge
	host.level.hz = [["low", 500, 482, 140]]
	host.world_two.reset(host)
	for record in bridge.participants(): record.p = Vector2(500, 482)
	bridge.record(1).crouching = true
	host.world_two.course_controller.hazards_tick(0, host, host.world_two)
	check(host.hits == [0] and bridge.record(1).hearts == 3, "low sign uses P2 own crouch and height while P1 collides")
	bridge.end_shared()
	f = fresh("2-4"); host = f.host; bridge = f.bridge
	host.level.hz = [["flame", 500, 482, 3000, 0]]
	host.world_two.reset(host)
	for record in bridge.participants(): record.p = Vector2(500, 482)
	host.elapsed = 1.0
	host.world_two.course_controller.hazards_tick(0, host, host.world_two)
	check(host.hits.is_empty(), "flame is off for both at exact source one-second boundary")
	host.elapsed = 0.999
	host.world_two.course_controller.hazards_tick(0, host, host.world_two)
	check(host.hits == [0, 1], "one shared flame phase damages both actual victims")
	bridge.end_shared()

func _test_transition() -> void:
	for id in ["2-1", "2-3"]:
		var f := fresh(id)
		var host = f.host
		var bridge = f.bridge
		host.level.scenes = [[1000, "lift", "Upstairs", "This way"]]
		host.level.solids = [[0, 3000, 482]]
		# P2's source destination lands on its own shelf, not P1's floor.
		host.level.plats = [[1470, 1520, 320]] if id == "2-1" else [[910, 950, 400]]
		host.world_two.reset(host)
		bridge.record(0).p = Vector2(1010, 482); bridge.record(0).px = 1100.0
		bridge.record(0).down = true; bridge.record(0).hearts = 0
		bridge.record(1).p = Vector2(950, 482)
		bridge.record(1).hearts = 1; bridge.record(1).invincible = 0.7
		bridge.record(1).on_platform = true
		host.combat.waves = [{"at": 0.0, "started": false, "done": false}]
		host.world_two._scene_update(host)
		check(bridge.record(0).p.x == 1000 and bridge.record(0).px == 1000 and not host.world_two.wiping, id + " clamp downed actor and px before wave gate")
		host.combat.waves[0].done = true
		host.world_two.after_pickups(0.1, host)
		check(host.world_two.wiping and host.world_two.wipe_elapsed == 0 and host.world_two.scene_index == 0, id + " living P2 triggers one deferred wipe")
		var generation: int = host.world_two.run_generation
		host.bullets = [{"enemy": true}, {"enemy": false}]
		host.world_two.after_pickups(1.43, host)
		check(host.world_two.scene_index == 0 and host.world_two._wipe_callback_due, id + " late phase queues midpoint without teleport")
		host.mode = "over"
		host.world_two.finish_frame(host)
		check(host.world_two.scene_index == 0, id + " all-down resolution freezes pending midpoint")
		host.mode = "play"
		host.world_two.finish_frame(host)
		var first := 1420.0 if id == "2-1" else 1000.0
		var second := 1490.0 if id == "2-1" else 930.0
		check(bridge.record(0).p.x == first and bridge.record(1).p.x == second and bridge.record(1).px == second, id + " midpoint relocates everyone in source slot order")
		check(bridge.record(0).hearts == 3 and not bridge.record(0).down and bridge.record(1).hearts == 1, id + " midpoint revives downed only, not injured living actor")
		check(bridge.record(1).p.y == (320 if id == "2-1" else 482), id + " per-actor floor query honors stockroom landY")
		check(bridge.record(1).on_platform and near(bridge.record(1).invincible, 0.7) and host.bullets.is_empty(), id + " source support/protection retained and projectiles cleared once")
		host.world_two.finish_frame(host)
		check(host.world_two.scene_index == 1 and not host.world_two._apply_scene_transition(host, generation), id + " midpoint cannot execute twice")
		bridge.end_shared()
		check(f.party.actors[0].player.x == first and f.party.actors[1].player.x == second and not f.party.actors[0].down, id + " transition writes survive scalar restore")
		check(f.party.actors[0].scene_state.safe_position == Vector2(300, 482) and f.party.actors[1].scene_state.safe_position == Vector2(500, 482), id + " transition preserves each source safe checkpoint")
		bridge.begin_shared()
		host.world_two.after_pickups(0.2, host)
		host.world_two.finish_frame(host)
		check(host.world_two.wipe_focus_end == host.world_two._wipe_focus(host), id + " opening iris uses current roster mean")
		host.world_two.reset(host)
		check(not host.world_two._apply_scene_transition(host, generation) and host.world_two.scene_index == 0, id + " reset invalidates stale midpoint")
		bridge.end_shared()

func _test_checkpoint_and_order() -> void:
	var f := fresh("2-2")
	var host = f.host
	var bridge = f.bridge
	host.level.check = 360
	host.world_two.reset(host)
	bridge.record(0).hearts = 1; bridge.record(0).invincible = 0.25
	bridge.record(1).hearts = 0; bridge.record(1).down = true
	host.world_two.after_pickups(0.1, host)
	check(bridge.record(0).hearts == 3 and bridge.record(1).hearts == 3 and not bridge.record(1).down, "checkpoint heals and raises complete roster")
	check(near(bridge.record(0).invincible, 0.25) and bridge.record(1).invincible == 2, "checkpoint protection granted only to downed actor")
	check(host.pickups.size() == 2 and host.pickups[0].hearts == 3 and host.pickups[1].hearts == 3, "both pickups run after checkpoint and see healed facades")
	check(host.trace == ["scene", "repair", "checkpoint", "coins", "gates", "trolleys", "drops", "course", "carts", "drones", "pickups:0", "pickups:1"], "single late-world pass preserves exact source subsystem order")
	check(near(host.world_two.elapsed, 0.1), "shared late scene clock increments once")
	bridge.record(1).hearts = 1
	host.world_two._checkpoint(host)
	check(bridge.record(1).hearts == 1 and host.sounds.count("revive") == 1, "checkpoint healing and sound are one-shot")
	host.mode = "pause"
	host.trace.clear()
	host.world_two.after_pickups(9, host)
	check(host.trace.is_empty() and near(host.world_two.elapsed, 0.1), "pause freezes all late-world phases")
	bridge.end_shared()
	check(f.party.actors[0].hearts == 3 and f.party.actors[1].hearts == 1 and not f.party.actors[1].down, "checkpoint writes survive final actor restore")

func _test_course() -> void:
	var f := fresh("2-5")
	var host = f.host
	var bridge = f.bridge
	host.level.auto = 0.18
	host.level.hz = [["boost", 0, 1000], ["block", 500, 482, 60, 70]]
	host.world_two.reset(host)
	bridge.record(0).p = Vector2(200, 482)
	bridge.record(1).p = Vector2(500, 482)
	host.elapsed = 0.7
	var displacement: float = host.world_two.auto_displacement(0.7, host)
	var expected_push := ((500.0 / 738.0) - 0.5) * 400.0
	check(near(displacement, (180 * 1.55 + expected_push) * 0.7) and host.world_two.course_controller.elapsed == 0.7, "auto course uses front P2 and shared elapsed without second clock")
	host.world_two.course_controller.hazards_tick(0.1, host, host.world_two)
	check(host.hits == [1] and bridge.record(1).velocity.y == -700 and not bridge.record(1).grounded and bridge.record(0).grounded, "block hits and bounces only P2 through refreshed victim record")
	bridge.end_shared()
	check(f.party.actors[1].velocity.y == -700 and not f.party.actors[1].grounded, "course bounce survives bridge merge")

func _test_checkout() -> void:
	var f := fresh("2-6", "cpu")
	var host = f.host
	var bridge = f.bridge
	# Model reset before fresh party setup: the temporary scalar key is replaced.
	host.world_two.checkout.players[host.get_instance_id()] = {"bag": 4.0, "crate": null, "boss_hits": 9}
	var run: int = host.world_two.run_generation
	var surfaces: int = host.world_two.surfaces(host).size()
	host.world_two.elapsed = 0.25
	host.world_two.party_start(host)
	check(host.world_two.checkout.players.keys().size() == 2 and not host.world_two.checkout.players.has(host.get_instance_id()), "party_start discards temporary scalar checkout identity")
	check(host.world_two.run_generation == run and host.world_two.surfaces(host).size() == surfaces and host.world_two.elapsed == 0.25, "party_start does not rebuild or tick shared world")
	host.camera.x = 4162
	host.world_two.checkout.ready_end(host)
	var checkout = host.world_two.checkout
	var boss: Dictionary = checkout.boss
	check(boss.hp == 90 and checkout.players.has(0) and checkout.players.has(1) and not checkout.players.has(host.get_instance_id()), "checkout uses 90 HP and stable distinct actor keys")
	boss.state = "fight"; boss.next = 100.0
	for record in bridge.participants(): record.p = Vector2(4300, 482)
	boss.beam = {"y": 448.0, "t": 0.9}
	checkout.late_tick(0.01, host, host.world_two)
	check(checkout.players[0].bag == 1.5 and checkout.players[1].bag == 1.5 and host.hits == [0, 1], "single scanner beam independently bags both actors")
	check(bridge.record(0).bag == 1.5 and bridge.record(1).bag == 1.5, "bag state published to both mutable actor records")
	boss.beam = null
	checkout.input_event(host)
	checkout.late_tick(0.1, host, host.world_two)
	check(near(checkout.players[0].bag, 1.24) and near(checkout.players[1].bag, 1.4), "human mash tears only human bag while CPU times out normally")
	check(bridge.record(0).lock_animation == "hit" and bridge.record(1).lock_animation == "hit", "bag lock carries independent animation state")
	bridge.end_shared()
	check(near(f.party.actors[0].scene_state.bag, 1.24) and near(f.party.actors[1].scene_state.bag, 1.4), "both bags survive reconciliation")
	bridge.begin_shared()
	boss.phase = 2
	for state in checkout.players.values(): state.bag = 0.0
	bridge.record(0).p.x = 4200; bridge.record(1).p.x = 4300
	boss.crates = [crate(Vector2(4200, 482)), crate(Vector2(4300, 482))]
	checkout.late_tick(0, host, host.world_two)
	check(boss.crates[0].by == 0 and boss.crates[1].by == 1 and boss.crates[0].st == "carry" and boss.crates[1].st == "carry", "two ground crates assign separate carriers in source order")
	check(is_same(bridge.record(0).crate, boss.crates[0]) and is_same(bridge.record(1).crate, boss.crates[1]), "crate references retain world object identity")
	bridge.record(1).p.x = 4370
	checkout.late_tick(0, host, host.world_two)
	check(boss.crates[1].st == "fly" and boss.placed == 1 and checkout.players[1].crate == null and checkout.players[0].crate != null, "P2 alone reaches tray and releases its own crate")
	boss.frozen = 4.0
	var hp: int = boss.hp
	checkout.intercept_shot(host, {"p": Vector2(4700, 200), "owner_slot": 1})
	check(boss.hp == hp - 3 and bridge.record(1).boss_hits == 1 and bridge.record(0).boss_hits == 0, "explicit native P2 shot credits only P2 checkout hits")
	checkout.intercept_shot(host, {"p": Vector2(4700, 200)})
	checkout.intercept_shot(host, {"p": Vector2(4700, 200), "owner_slot": 99})
	check(bridge.record(0).boss_hits == 0 and bridge.record(1).boss_hits == 1, "unowned and stale-slot hits never credit active P1")
	bridge.end_shared()
	check(f.party.actors[1].scene_state.boss_hits == 1 and is_same(f.party.actors[0].scene_state.crate, boss.crates[0]), "checkout hit count and carry identity survive actor capture")
	bridge.begin_shared()
	host.mode = "pause"
	var before: Dictionary = checkout.snapshot()
	checkout.input_event(host)
	checkout.late_tick(10, host, host.world_two)
	check(checkout.snapshot() == before, "pause freezes bags/crates/boss/mash together")
	host.mode = "play"
	bridge.record(0).hearts = 0; bridge.record(0).down = true
	checkout.jar = {"p": Vector2(4400, 452), "v": Vector2.ZERO, "t": 0.7, "got": false}
	bridge.record(1).p = Vector2(4400, 482)
	check(checkout._jar_tick(0, host) == "jar_collected" and checkout.jar.by == 1, "living P2 can finish jar while leader is down")
	check(checkout._jar_tick(0.1, host) == "", "jar emits only one completion")
	host.world_two.reset(host)
	check(host.world_two.checkout.boss.is_empty() and host.world_two.checkout.players.size() == 2 and bridge.record(0).crate == null and bridge.record(1).bag == 0 and bridge.record(1).boss_hits == 0, "new run clears both checkout identities without stale carry/hit state")
	check(not checkout._can_step(host), "old checkout reference invalidated by world generation")
	bridge.end_shared()
