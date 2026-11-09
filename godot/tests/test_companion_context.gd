extends SceneTree
## Actual runtime dictionaries and source geometry, with explicit encounter
## fixtures. This proves query adapters, not a completed co-op playthrough.
const Main = preload("res://src/main.gd")
const Party = preload("res://src/party_runtime.gd")
const Context = preload("res://src/companion_context.gd")
const AI = preload("res://src/companion_ai.gd")
const Support = preload("res://tests/test_support.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = Main.new()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	Support.silence(game)
	var party = Party.new()
	party.configure("cpu", "jp", "maya")
	var brain = AI.new()
	game.load_level("2-2")
	party.start("2-2", game.player)
	var mate = party.actors[1]
	var time: float = game.elapsed
	var world_time: float = game.world_two.elapsed
	var context: Dictionary = Context.build(game, party, mate)
	check(context.gates.size() == 7 and context.plates.size() == 5, "actual aisle gate and pad arrays")
	context.gates[0].open = 1.0
	check(game.world_two.hazard_controller.gates[0].open == 0, "query snapshot cannot mutate real gate")
	check(context.floor_below.call(game.player.x, game.player.y - 2) == game.player.y, "actual geometry callback returns supporting floor")
	check(game.elapsed == time and game.world_two.elapsed == world_time, "query construction does not tick global timers")
	game.world_two.entities.append({"k": "trolley", "p": Vector2(220, 482), "v": Vector2(400, 0)})
	context = Context.build(game, party, mate)
	check(context.entities.size() == 1 and context.entities[0].x == 220 and context.entities[0].vx == 400, "actual trolley vector schema normalized")
	game.load_level("2-5")
	context = Context.build(game, party, mate)
	check(context.hazards.filter(func(h): return h.kind == "flame").size() == 13, "actual thirteen oven hazards")
	var flame: Dictionary = context.hazards.filter(func(h): return h.kind == "flame")[0]
	check(flame.period > 1 and flame.period < 20, "source hazard milliseconds converted to seconds")
	game.load_level("2-6")
	game.world_two.checkout.ready_end(game)
	var checkout = game.world_two.checkout
	checkout.boss.state = "fight"
	checkout.boss.phase = 2
	checkout.boss.frozen = 0
	checkout.boss.crates = [{"p": Vector2(4200, 440), "st": "ground"}]
	checkout.players[1] = {"crate": {"p": Vector2(4300, 440)}}
	context = Context.build(game, party, mate)
	check(context.boss.is_empty() and context.scene_targets == [4700.0], "checkout stays source scene target rather than shared boss")
	check(context.checkout.carrying_crate and context.checkout.crates[0].x == 4200, "checkout reads correct stable actor carried-crate state")
	mate.player.x = 4300
	party.actors[0].player.x = 4350
	var input: Dictionary = brain.controls(0.01, mate, context)
	check(input.right, "real checkout carried-crate query drives CPU toward placement point")
	checkout.boss.steps = 2
	context = Context.build(game, party, mate)
	check(context.checkout.steps.size() == 2 and context.checkout.steps[0].top == 412, "real receipt-step geometry normalized")
	game.load_level("4-1")
	game.world_four.foes.entries = [{"kind": "case", "x": 200.0, "dead": false}, {"kind": "bailiff", "x": 300.0, "dead": false}, {"kind": "ring", "x": 400.0, "dead": true}]
	context = Context.build(game, party, mate)
	check(context.scene_targets == [300.0], "holiday targets omit cases and dead foes")
	game.load_level("6-1")
	game.world_six.fliers = [{"p": Vector2(500, 200), "state": "fly", "entered": true}, {"p": Vector2(400, 200), "state": "fly", "entered": false}, {"p": Vector2(300, 200), "state": "pop", "entered": true}]
	game.world_six.mini_boss = {"x": 700.0, "state": "fight"}
	context = Context.build(game, party, mate)
	check(context.scene_targets == [500.0, 700.0] and context.fliers.size() == 3, "billing targets entered fliers and fighting mini in source order")
	game.bullets = [{"p": Vector2(400, 350), "v": Vector2(-420, 0), "enemy": true, "flat": true, "life": 1.0}, {"p": Vector2(500, 300), "v": Vector2(780, 0), "enemy": false, "life": 1.0}, {"p": Vector2.ZERO, "v": Vector2.ZERO, "enemy": true, "life": 0.0}]
	context = Context.build(game, party, mate)
	check(context.bills.size() == 1 and context.bills[0].flat, "only live hostile shots reach dodge input")
	game.load_level("1-1")
	game.bullets.clear()
	game.combat._bill(game, Vector2(400, 350), Vector2(-420, 0), 0, false, true)
	game.combat._bill(game, Vector2(420, 350), Vector2(-420, 0), 0)
	check(game.bullets[0].flat and not game.bullets[1].flat, "flat metadata explicit; other zero-gravity shots not inferred")
	game.bullets.clear()
	game.enemies.clear()
	game.combat.spawn(game, "r", "flat")
	var bot: Dictionary = game.enemies[0]
	bot.state = "throw"
	bot.t = 0.44
	bot.pending = true
	bot.p = Vector2(500, 482)
	game.combat._update_enemies(0.02, game)
	check(game.bullets.size() == 1 and game.bullets[0].flat, "actual flat bot throw preserves source duck flag")
	for world in range(1, 7):
		for stage in ["1", "2", "3", "4", "5", "6", "S"]:
			var id := "%d-%s" % [world, stage]
			game.load_level(id)
			party.start(id, game.player)
			mate = party.actors[1]
			context = Context.build(game, party, mate)
			input = brain.controls(0.01, mate, context)
			check(input.has("jump") and input.has("shoot") and game.elapsed == 0, id + " actual native context and CPU intent without ticking world")
	game.queue_free()
	await process_frame
	print("Companion native context: %d checks, %d failures. Real dictionaries, fixture scenes, no co-op/device acceptance." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
