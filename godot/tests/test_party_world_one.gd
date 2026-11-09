extends SceneTree
const Fixtures = preload("res://tests/test_party_combat_integration.gd")
const Party = preload("res://src/party_runtime.gd")
const Bridge = preload("res://src/party_combat.gd")
const Combat = preload("res://src/combat.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)
func setup(id: String = "1-2") -> Dictionary:
	var host = Fixtures.Host.new()
	host.level_id = id
	host.combat = Combat.new()
	var party = Party.new()
	party.configure("p2", "jp", "maya")
	party.start(id, Vector2(500, 482))
	party.actors[1].player = Vector2(650, 482)
	party.actors[0].apply_native(host)
	host.world_one.reset(host)
	var bridge = Bridge.new()
	host.bridge = bridge
	bridge.configure(party, host)
	bridge.begin_shared()
	return {"host": host, "party": party, "bridge": bridge}
func _initialize() -> void:
	var f := setup()
	var host = f.host
	var bridge = f.bridge
	host.world_one.crumbles = [{"row": [400, 800, 250], "t": 0.0, "fall": 0.0}]
	for record in bridge.participants(): record.p.y = 250
	host.world_one.crumble_step(0.4, host)
	check(is_equal_approx(host.world_one.crumbles[0].t, 0.4), "two standing actors advance one slate clock once")
	host.world_one.crumble_step(0.3, host)
	check(host.world_one.crumbles[0].fall > 0 and not bridge.record(0).grounded and not bridge.record(1).grounded, "collapsed slate releases both supported actors")
	check(bridge.record(0).velocity.y == 50 and bridge.record(1).velocity.y == 50, "each actor starts source downward velocity")
	bridge.end_shared()
	check(not f.party.actors[0].grounded and not f.party.actors[1].grounded, "collapse mutations survive facade reconciliation")
	f = setup("1-5"); host = f.host; bridge = f.bridge
	host.level.auto = 0.14
	for record in bridge.participants(): record.p.y = 600; record.grounded = false
	host.world_one.after_pickups(host)
	check(bridge.record(0).p.y == 482 and bridge.record(1).p.y == 482 and bridge.record(1).grounded, "forced-scroll anti-crush corrects both actors")
	bridge.record(0).hearts = 0
	bridge.record(0).down = true
	host.hearts = 0
	host.camera_speed = 0.0
	host.world_one.after_camera(0.1, host)
	check(is_equal_approx(host.camera.x, 14), "forced-scroll continues when only P2 alive")
	host.camera.x = 1040
	host.combat.waves = [{"done": true}]
	check(host.world_one.objective_tick(0.1, host) == "ending", "world objective accepts surviving P2")
	bridge.end_shared()
	f = setup(); host = f.host; bridge = f.bridge
	host.level.solids = [[0, 1000, 300], [1000, 2000, 482]]
	bridge.record(0).p = Vector2(500, 300)
	bridge.record(1).p = Vector2(1500, 482)
	check(host.world_one.flyer_floor(host) == 482, "flyer floor takes lowest grounded actor support")
	bridge.record(1).grounded = false
	check(host.world_one.flyer_floor(host) == 300, "falling second actor does not lower flyer altitude")
	bridge.end_shared()
	f = setup("1-3"); host = f.host; bridge = f.bridge
	host.level.solids = [[0, 2000, 150]]
	host.level.drive = 0.24
	host.level.camY = -200.0
	host.level.bus = [0, 150, 1000, 250]
	host.bus_ride.reset(host)
	for record in bridge.participants(): record.p = Vector2(500, 150); record.player_animation = "idle"
	host.bus_ride.obstacles = [{"k": "bridge", "x": 450.0, "w": 330.0, "hit": false}]
	host.bus_ride.tick(0.1, host)
	check(host.hits == [0, 1] and bridge.record(0).hearts == 2 and bridge.record(1).hearts == 2, "one bus obstacle can injure both actors independently")
	check(host.bus_ride.obstacles[0].hit_slots.size() == 2, "obstacle records stable per-actor hit identities")
	check(is_equal_approx(host.bus_ride.drive, 24) and is_equal_approx(host.bus_ride.obstacles[0].x, 426), "shared bus and obstacle movement advances once")
	host.bus_ride.tick(0.1, host)
	check(host.hits == [0, 1], "same obstacle never repeats contact on either actor")
	bridge.record(0).hearts = 0; bridge.record(0).down = true
	host.hearts = 0
	host.camera.x = 1040
	host.combat.waves = [{"done": true}]
	check(host.bus_ride.objective_tick(0.1, host) == "ending", "bus objective continues with surviving P2")
	bridge.end_shared()
	f = setup("1-3"); host = f.host; bridge = f.bridge
	host.level.solids = [[0, 2000, 150]]
	host.level.drive = 0.24
	host.level.camY = -200.0
	host.level.bus = [0, 150, 1000, 250]
	host.bus_ride.reset(host)
	for record in bridge.participants(): record.p = Vector2(500, 150)
	bridge.record(1).player_animation = "crouch"
	host.bus_ride.obstacles = [{"k": "branch", "x": 450.0, "w": 150.0, "hit": false}]
	host.bus_ride.tick(0.1, host)
	check(host.hits == [0] and not host.bus_ride.obstacles[0].hit_slots.has(1), "P2 crouch and own height determine clearance independently")
	bridge.end_shared()
	print("W1 party scenes: %d checks, %d failures. Shared scene fixtures, not full party progression." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
