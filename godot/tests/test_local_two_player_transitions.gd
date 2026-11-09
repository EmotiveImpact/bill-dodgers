extends SceneTree
## Source scene-midpoint fixtures through the native key polling/world frame.
## Explicit placed actors, cleared wave prerequisites and started wipes below
## are fixtures, NOT input-only route completion or physical-device acceptance.
const Keys = preload("res://tests/local_two_player_input.gd")
const DT := 1.0 / 60.0
var game
var keys = Keys.new()
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	print("ASSISTS scene fixtures: positioned actors/camera, downed P1, all wave prerequisites done, W3 checkpoint spent, W4 gate and W5 wipe explicitly started, W6 initial wipe ended. Midpoint clocks run normally; no forced midpoint callback.")
	for world in range(2, 7): transition(world)
	keys.release(); game.queue_free()
	await process_frame
	print("Local P2 native scene transitions: %d checks, %d failures. W2–W6 bounded fixtures, NOT full routes." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func place(actor, x: float, y := 482.0) -> void:
	actor.player = Vector2(x, y); actor.velocity = Vector2.ZERO
	actor.grounded = true; actor.on_platform = false
	actor.scene_state.safe_position = actor.player; actor._last_floor = y

func transition(world: int) -> void:
	var id := "5-2" if world == 5 else "%d-1" % world
	keys.release(); game._show_menu(); game.character = "jp"
	game.save = {"schema": 1, "receipts": {}, "skills": [], "seen": {}}
	check(game.configure_party("p2", "maya") and game.load_level(id), id + " real local pair loaded")
	keys.frame(game, {}, {}, 0)
	var session = game.party_session
	var p1 = session.runtime.actors[0]
	var p2 = session.runtime.actors[1]
	var scene
	var destination := 0.0
	var expected_spacing := 0.0
	for wave in game.combat.waves: wave.done = true; wave.started = true; wave.index = wave.group.size()
	match world:
		2:
			scene = game.world_two
			var edge: float = game.level.scenes[0][0]
			place(p1, edge - 230); place(p2, edge - 40)
			game.camera = Vector2(scene.camera_cap(game), 0)
			destination = edge + 420; expected_spacing = 70
		3:
			scene = game.world_three; scene.checkpoint_done = true
			# Already beyond both-actor follow target, so native camera easing
			# cannot change the source translation during the1.43s wipe.
			game.camera = Vector2(6800, 0)
			place(p1, 6900); place(p2, 7100)
			destination = 8000; expected_spacing = 200
		4:
			scene = game.world_four
			var gate: Dictionary = scene.gates[0]
			game.camera = Vector2(gate.x - game.view_width(), 0)
			place(p1, gate.x - 200); place(p2, gate.x - 100)
			destination = gate.to + 140; expected_spacing = 90
			scene._start_gate(game, gate)
		5:
			scene = game.world_five
			place(p1, 500); place(p2, 700)
			var authored: Dictionary = game.level.scenes[0]
			destination = authored.to; expected_spacing = 60
			scene._start_wipe(game, authored)
		6:
			scene = game.world_six; scene.wiping = false
			var door: Dictionary = game.level.doors[0]
			game.camera = Vector2(door.x - 200, 0)
			place(p1, door.x - 160); place(p2, door.x - 60)
			destination = door.to + 80; expected_spacing = 70
	p1.mark_down(); session.bind(game, 0)
	keys.frame(game)
	check(scene.wiping, id + " native frame has active source transition")
	var elapsed: float = game.elapsed
	var wipe: float = scene.wipe_elapsed
	var before1: Vector2 = p1.player
	var before2: Vector2 = p2.player
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	for frame in 100: keys.frame(game, {"right": true}, {"left": true})
	check(game.mode == "paused" and game.elapsed == elapsed and scene.wipe_elapsed == wipe and p1.player == before1 and p2.player == before2, id + " focus pause freezes pending transition and both actors")
	game._resume(); keys.frame(game)
	var midpoint_frames := 0
	while not scene.wipe_midpoint_done and midpoint_frames < 150:
		keys.frame(game); midpoint_frames += 1
	check(scene.wipe_midpoint_done and midpoint_frames >= 80 and midpoint_frames <= 87, id + " one source midpoint after normal60Hz native frames")
	check(absf(p1.player.x - destination) < 0.1 and absf(p2.player.x - p1.player.x - expected_spacing) < 0.1, id + " both stable slots relocate to source destination/spacing")
	if world in [2, 4]: check(not p1.down and p1.hearts == 3, id + " source transition rescues downed P1")
	else: check(p1.down, id + " source transition deliberately preserves P1 down state")
	check(game.player == p1.player and not session.bridge.shared_phase, id + " midpoint closes bridge and restores P1 facade")
	var landed1: Vector2 = p1.player
	var landed2: Vector2 = p2.player
	keys.frame(game)
	check(absf(p1.player.x - landed1.x) < 1 and absf(p2.player.x - landed2.x) < 1, id + " next frame does not relocate party again")
	var prior_x: float = p2.player.x
	keys.frame(game, {}, {"right": true})
	check(p2.player.x > prior_x and (p1.down or absf(p1.player.x - landed1.x) < 1), id + " fresh D key still independently moves P2 after midpoint")
	print("LOCAL_P2_TRANSITION ", JSON.stringify({"level": id, "midpoint_frames": midpoint_frames, "p1": str(landed1), "p2": str(landed2), "p1_down": p1.down, "p1_hearts": p1.hearts, "camera": str(game.camera)}))
