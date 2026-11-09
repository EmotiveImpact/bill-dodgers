extends SceneTree
## Actual-host source wrapper seam. Explicit positions isolate passive nudges;
## these fixtures do not claim whole-stage traversal.
var checks := 0
var failures := 0
var game
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: ", label)
func setup(id: String, at: Vector2) -> void:
	game.character = "mei"
	game.save = {"schema":1,"receipts":{},"skills":[]}
	game.load_level(id)
	game.player = at; game.camera = Vector2(maxf(0,at.x-300),at.y-482)
	game.grounded = true; game._pre_grounded = true; game.crouching = false
	game.hearts = 3; game.hurt_lock = 0; game.velocity = Vector2.ZERO
func run() -> void:
	game = load("res://main.tscn").instantiate(); root.add_child(game)
	game.set_physics_process(false); preload("res://tests/test_support.gd").silence(game)
	setup("2-5",Vector2(11200,482))
	var key: int = game.get_instance_id()
	game.world_two.hazard_controller.ice_velocity[key] = 148.5
	var old: Vector2 = game.player
	game.ability_post_motion(0.016,{"right":true})
	check(is_equal_approx(game.world_two.hazard_controller.ice_velocity[key],148.5), "W2 post wrapper cannot overwrite base flour velocity")
	check(absf(game.player.x-old.x-270*0.12*0.016)<0.001, "W2 passive nudge is source unslowed270 multiplier")
	setup("2-2",Vector2(11500,482))
	game.world_two.hazard_controller.ice_velocity[key] = -70.0
	old = game.player
	game.ability_post_motion(0.016,{"right":true})
	check(game.world_two.hazard_controller.ice_velocity[key] == -70, "W2 wrapper cannot run a second ice recurrence")
	check(absf(game.player.x-old.x-270*0.12*0.016)<0.001, "W2 passive moves independently of stored ice drift")
	setup("5-2",Vector2(420,482))
	game.world_five.carrying = true
	check(is_equal_approx(game.world_five.base_displacement(.016,game,1),270*.78*.016), "Sofa retains0.78 base-motion factor")
	old = game.player; game.ability_post_motion(.016,{"right":true})
	check(absf(game.player.x-old.x-270*.12*.016)<.001, "W5 carry does not multiply source passive nudge")
	check(game.world_five.carrying, "Passive does not change carrying state")
	game.hurt_lock = .1; old = game.player; game.ability_post_motion(.016,{"right":true})
	check(game.player == old, "Hurt-lock suppresses passive nudge")
	game.hurt_lock = 0; game.crouching = true; game.ability_post_motion(.016,{"right":true})
	check(game.player == old, "Crouch suppresses passive nudge")
	setup("3-1",Vector2(500,482))
	game.world_three.tied = .5
	old = game.player
	var source_delta: float = game.world_three.base_displacement(.016,game,1)*.12
	game.ability_post_motion(.016,{"right":true})
	check(absf(game.player.x-old.x-source_delta)<.001, "Only W3 retains source spdMul tie/mud policy")
	game.queue_free(); await process_frame
	print("Passive wrapper phase: %d checks, %d failures" % [checks,failures]); quit(0 if failures == 0 else 1)
