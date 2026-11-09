extends SceneTree
const Party = preload("res://src/party_runtime.gd")
const AI = preload("res://src/companion_ai.gd")
var checks := 0
var failures: Array[String] = []
var party = Party.new()
var brain = AI.new()
var lead
var mate
var context: Dictionary = {}
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)
func reset(world := 1) -> void:
	party.configure("cpu", "jp", "maya")
	party.start("%d-1" % world, Vector2(400, 482))
	lead = party.actors[0]
	mate = party.actors[1]
	context = {"world": world, "actors": party.actors, "camera_x": 0.0, "view_width": 960.0,
		"enemies": [], "boss": {}, "floor_below": func(_x, _y): return 482.0,
		"wall_clamp": func(_x, to, _feet): return to, "inside_wall": func(_p): return false}
	brain.rng.seed = 1979
func _initialize() -> void:
	reset()
	mate.player.x = 100
	var input: Dictionary = brain.controls(0.1, mate, context)
	check(input.right and not input.jump and not input.shoot, "follows human 110 pixels behind on level ground")
	mate.player.x = 290
	input = brain.controls(0.1, mate, context)
	check(not input.right and not input.left, "within source follow deadzone")
	mate.mark_down()
	input = brain.controls(1, mate, context)
	check(not input.values().has(true), "downed companion emits no controls")
	reset()
	lead.mark_down()
	mate.player.x = 200
	context.enemies = [{"p": Vector2(300, 482), "state": "walk"}]
	input = brain.controls(0.1, mate, context)
	check(input.right and not input.shoot, "rescue overrides attacking a nearby enemy")
	reset()
	mate.player.x = 100
	context.enemies = [{"p": Vector2(600, 482), "state": "walk"}]
	input = brain.controls(0.1, mate, context)
	check(input.right and mate.face == 1, "approaches source normal enemy shooting distance")
	mate.player.x = 590
	input = brain.controls(0.1, mate, context)
	check(input.left, "backs off close target")
	context.enemies = [{"p": Vector2(2000, 482), "state": "walk"}]
	mate.player.x = 290
	input = brain.controls(0.1, mate, context)
	check(not input.shoot, "offscreen enemy not selected")
	reset()
	lead.player.x = 900
	mate.player.x = 200
	brain.controls(1.6, mate, context)
	check(brain.events.is_empty(), "catch-up waits strictly over 1.6 seconds")
	brain.controls(0.01, mate, context)
	check(mate.player == Vector2(880, 482) and brain.events.size() == 1 and brain.events[0].kind == "catch_up", "source stranded mate catch-up emits relocation event")
	reset()
	lead.player.x = 900
	mate.player.x = 200
	context.inside_wall = func(_p): return true
	brain.controls(2, mate, context)
	check(mate.player.x == 200 and brain.events.is_empty(), "catch-up refuses lead inside wall")
	context.inside_wall = func(_p): return false
	lead.grounded = false
	brain.controls(2, mate, context)
	check(mate.player.x == 200, "catch-up refuses airborne leader")
	reset(6)
	lead.player.x = 600
	mate.player.x = 250
	brain.controls(1.61, mate, context)
	check(mate.player.x == 580, "billing uses shorter 320 pixel catch-up threshold")
	reset()
	lead.player.x = 600
	mate.player.x = 250
	brain.controls(1.61, mate, context)
	check(mate.player.x == 250, "other worlds retain 460 pixel catch-up threshold")
	context.floor_below = func(_x, _y): return INF
	input = brain.controls(0.1, mate, context)
	check(input.jump and is_equal_approx(mate.ai.jump_cooldown, 0.65), "jumps ahead of gap")
	input = brain.controls(0.1, mate, context)
	check(not input.jump, "jump cooldown avoids repeated gap jumps")
	reset()
	mate.player.x = 100
	context.wall_clamp = func(from, _to, _feet): return from
	input = brain.controls(0.1, mate, context)
	check(input.jump, "jumps ahead of obstructing wall")
	reset()
	context.bills = [{"p": Vector2(400, 430), "v": Vector2(-200, 0), "flat": true}]
	input = brain.controls(0.1, mate, context)
	check(input.down, "ducks approaching flat bill")
	context.bills[0].flat = false
	input = brain.controls(0.1, mate, context)
	check(input.jump and mate.ai.jump_cooldown == 0.7, "jumps approaching low bill")
	reset()
	context.bills = [{"p": Vector2(400, 430), "v": Vector2(200, 0), "flat": true}]
	input = brain.controls(0.1, mate, context)
	check(not input.down, "does not dodge retreating bill")
	context.boss_waves = [{"x": 350.0}]
	input = brain.controls(0.1, mate, context)
	check(input.jump and mate.ai.jump_cooldown == 0.6, "jumps source boss shockwave")
	reset()
	context.enemies = [{"p": Vector2(500, 482)}, {"p": Vector2(550, 482)}]
	mate.abilities.meter = 1
	input = brain.controls(0.7, mate, context)
	check(not input.special, "CPU special waits strictly above 700 milliseconds")
	input = brain.controls(0.01, mate, context)
	check(input.special and mate.ai.special_wait == 0, "CPU special against crowd")
	context.enemies = []
	input = brain.controls(2, mate, context)
	check(not input.special and mate.ai.special_wait == 0, "CPU conserves ready special without threat")
	context.boss = {"x": 800.0, "state": "idle"}
	input = brain.controls(0.71, mate, context)
	check(input.special, "CPU special also targets boss")
	reset(2)
	context.entities = [{"kind": "trolley", "x": 220.0, "vx": 250.0}]
	input = brain.controls(0.1, mate, context)
	check(input.jump and mate.ai.jump_cooldown == 0.5, "supermarket trolley dodge")
	reset(2)
	mate.player.x = 100
	context.hazards = [{"kind": "flame", "x": 180.0, "y": 482.0, "period": 3.0}]
	input = brain.controls(0.1, mate, context)
	check(not input.right and not input.left, "waits before active oven flame")
	context.elapsed = 1.5
	input = brain.controls(0.1, mate, context)
	check(input.right, "crosses during safe flame phase")
	context.hazards = [{"kind": "low", "x": 180.0, "y": 482.0}]
	input = brain.controls(0.1, mate, context)
	check(input.down and not input.jump, "ducks low supermarket sign")
	context.hazards = [{"kind": "block", "x": 180.0, "y": 482.0}]
	input = brain.controls(0.1, mate, context)
	check(input.jump and mate.ai.jump_cooldown == 0.45, "jumps supermarket block")
	reset(2)
	lead.player.x = 500
	mate.player.x = 320
	context.gates = [{"id": 1, "x": 600.0, "open": 0.0, "held": true}]
	context.plates = [{"id": 1, "x": 300.0, "y": 482.0}]
	input = brain.controls(0.1, mate, context)
	check(input.left and not input.right and mate.ai.far_time == 0, "mate returns to pressure pad for leader")
	mate.player.x = 300
	input = brain.controls(0.1, mate, context)
	check(not input.left and not input.right, "mate holds pressure pad instead of following")
	reset(2)
	context.checkout = {"alive": true, "phase": 1, "beam": {"y": 300.0, "age": 0.8}}
	input = brain.controls(0.1, mate, context)
	check(input.down and not input.jump and not input.left and not input.right, "checkout high scanner duck")
	context.checkout.beam = {"y": 450.0, "age": 0.9}
	input = brain.controls(0.1, mate, context)
	check(input.jump, "checkout low scanner jump")
	context.checkout = {"alive": true, "phase": 2, "frozen": false, "till_left": 1000.0, "crates": [{"state": "ground", "x": 200.0}]}
	input = brain.controls(0.1, mate, context)
	check(input.left, "checkout fetches crate")
	mate.scene_state.carrying_crate = true
	input = brain.controls(0.1, mate, context)
	check(input.right, "checkout takes held crate toward till")
	mate.ai.jump_cooldown = 0
	context.checkout = {"alive": true, "phase": 3, "steps": [{"x0": 350.0, "x1": 450.0, "top": 417.0}]}
	input = brain.controls(0.1, mate, context)
	check(input.right and input.jump, "checkout climbs receipt steps")
	reset(6)
	context.scene_targets = [500.0]
	context.fliers = [{"p": Vector2(500, 200), "state": "fly"}]
	input = brain.controls(0.1, mate, context)
	check(input.aim, "billing aims at high flier")
	context.fliers[0].p.y = 400
	input = brain.controls(0.1, mate, context)
	check(not input.aim, "billing does not aim above low flier")
	context.fliers = []
	context.scene_targets = []
	context.boss = {"x": 500.0, "offset_y": -80.0, "state": "idle"}
	input = brain.controls(0.1, mate, context)
	check(input.aim, "billing aims at airborne Sir Charge")
	reset(4)
	mate.player.x = 100
	context.boss = {"x": 800.0, "aim_x": 200.0, "state": "idle"}
	input = brain.controls(0.1, mate, context)
	check(input.left, "holiday boss uses source aimX target and normal standoff")
	print("Companion decisions: %d checks, %d failures. Module tests, not integrated six-world/device acceptance." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
