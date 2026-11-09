extends SceneTree
## Explicit true-host placement/clock fixtures; full routes are separate.
const SaveStore = preload("res://src/save_store.gd")
const AudioLog = preload("res://tests/test_festival_integration.gd").AudioLog
var game
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)
func near(a: float, b: float) -> bool: return absf(a - b) < 0.002
func fresh(who: String = "jp") -> void:
	game.character = who
	game.save = {"schema": 1, "receipts": {}, "skills": [], "kitty": 13}
	game.load_level("3-3")
	for wave in game.combat.waves: wave.at = INF
	game.step(0, {})
	game.coins.clear()
	game.audio.clear_log()
func stand(point: Vector2, x: float) -> void:
	game.player = point; game.camera = Vector2(x, 0)
	game.velocity = Vector2.ZERO; game.grounded = true; game.on_platform = false
	game.invincible = 0; game.hurt_lock = 0; game.jump_held = false
	game.camera_speed = 0; game._last_floor = point.y
	game.world_three._standing_surface = {}
func tick(seconds: float) -> void:
	while seconds > 0.00000001:
		var dt := minf(seconds, 0.01); game.step(dt, {}); seconds -= dt
func chance_seed(dt: float) -> int:
	var random := RandomNumberGenerator.new()
	for seed_value in range(1, 100000):
		random.seed = seed_value
		if random.randf() < dt / 7: return seed_value
	return -1
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	game.audio.shutdown(); game.audio.queue_free(); game.audio = AudioLog.new()
	test_selection()
	test_fires()
	test_fireworks()
	test_fade_and_bailiff()
	await test_render()
	test_campaign_clear()
	game.queue_free(); await process_frame
	print("Festival night integration: ", checks, " checks; ", failures.size(), " failures (explicit host fixtures)")
	quit(0 if failures.is_empty() else 1)
func test_selection() -> void:
	fresh()
	check(game._native_world_three() and game.combat.waves.size() == 10 and game.festival_renderer == game.festival_night_renderer, "Native night selects its actual shared runtime and painter")
	check(game.combat.waves.reduce(func(total, wave): return total + wave.group.size(), 0) == 48, "Ten actual groups retain all 48 solo entries")
	check(game.world_three.tents.size() == 15 and game.world_three.stage_data.fires.size() == 5 and game.world_three.stage_data.dark == 0.5, "Night owns exact tents/fires/darkness")
	check(game.world_three.tents.all(func(t): return not t.get("glow", false)), "Native does not invent ignored source tent lights")
	game.load_level("3-2")
	check(game.festival_renderer == game.festival_queue_renderer and game.world_three.stage_data.has("end_run"), "Returning to queue restores distinct extension")
	game.load_level("4-1"); game.level_id = "7-1"; game._complete_level()
	check(not game.is_native_supported() and game.mode == "play" and not game.save.get("cleared", {}).has("7-1"), "Unknown run ID cannot earn a fake clear")
func test_fires() -> void:
	for who in game.CHARACTERS:
		fresh(who)
		game.world_three._scenes[1].done = true
		game.world_three.mini_done = true
		game.world_three.checkpoint_done = true # Isolate fire damage from the separately tested full-heal checkpoint.
		var original := JSON.stringify(game.meta)
		for row in game.level.fires:
			game.abilities.reset(who); game.hearts = 3
			stand(Vector2(row[0] + 34, row[1]), row[0] - 300)
			game.step(0, {})
			check(game.hearts == 3, who + " exact fire horizontal edge is safe")
			game.player.x -= 0.01; game.step(0, {})
			check(game.hearts == 2 and game.hurt_lock > 0, who + " actual fire inside edge uses normal damage")
		check(JSON.stringify(game.meta) == original, who + " fire and mini state leave source metadata unchanged")
	fresh(); stand(Vector2(1450, 452), 1150)
	game.grounded = false; game.step(0, {})
	check(game.hearts == 3, "Exact vertical fire boundary is safe")
	game.player.y += 0.01; game.step(0, {})
	check(game.hearts == 2, "Just inside airborne fire boundary damages")
	for defense in ["invulnerability", "maya", "slide", "dash"]:
		fresh(); stand(Vector2(1450, 482), 1150)
		match defense:
			"invulnerability": game.invincible = 1
			"maya": game.abilities.active = "maya"; game.abilities.duration = 2; game.abilities.remaining = 2
			"slide": game.movement_skills.slide_remaining = 1
			"dash": game.movement_skills.dash_remaining = 1
		game.step(0, {})
		check(game.hearts == 3, "Fire respects real " + defense + " defense")
	fresh(); stand(Vector2(7000.1, 482), 6700)
	game.hearts = 1; game.world_three.night._fires.append([7000, 482])
	game.step(0, {})
	check(game.hearts == 3 and game.invincible == 1.5, "Source checkpoint health/protection precede same-frame fire")
func test_fireworks() -> void:
	fresh(); var seed_value := chance_seed(0.034)
	check(seed_value > 0, "Deterministic chance fixture found a real eligible RNG sample")
	game.world_three.rng.seed = seed_value
	game.step(0.034, {})
	check(game.world_three.night.fireworks.size() == 1 and near(game.world_three.night.fireworks[0].t, 0.034), "Actual late phase spawns and ages firework once")
	check(game.world_three.night.flash_time == 0.5 and near(game.world_three.night.darkness_alpha(), 1.0 / 12), "New flash survives earlier decay phase")
	check(game.audio.effects == ["firework"], "Actual emitted event requests source prebuilt firework sound once")
	var state: Dictionary = game.world_three.snapshot(); var rng_state: int = game.world_three.rng.state
	game._pause(); game.step(10, {})
	check(game.world_three.snapshot() == state and game.world_three.rng.state == rng_state, "Pause freezes all night clocks and chance draws")
	game._resume(); game.step(0.01, {})
	check(near(game.world_three.night.flash_time, 0.49), "Resume continues existing flash")
	game._game_over(); state = game.world_three.snapshot(); game.step(10, {})
	check(game.world_three.snapshot() == state, "Knockout also freezes night state")
	game._continue_level(); game.step(0.01, {})
	check(game.mode == "play" and near(game.world_three.night.flash_time, 0.48), "Continue retains rather than reloads fireworks")
	game.load_level("3-3")
	check(game.world_three.night.fireworks.is_empty() and game.world_three.night.flash_time == 0, "Fresh replay resets cosmetic state")
func test_fade_and_bailiff() -> void:
	fresh(); stand(Vector2(7000, 482), 6700)
	game.step(0, {})
	check(not game.world_three.wiping and not game.world_three.checkpoint_done, "Night scene threshold is strict player x")
	game.player.x += 0.01; game.step(0, {})
	check(game.world_three.wiping and game.world_three.wipe_kind == "fade", "Actual after-dark transition is fade, not iris")
	tick(1.42); game.step(0.01, {})
	check(game.world_three.wipe_midpoint_done and game.world_three.scene_index == 1 and game.camera.x == 7900, "Actual fade callback preserves destination at 1.43 seconds")
	game.step(0.01, {})
	check(game.boss != null and game.boss.state.max == 70 and game.boss.state.kind == "bailiff" and game.boss.state.cam == 8000, "Next late phase enters actual 70HP Bailiff")
	check(game.audio.starts.has(true), "Bailiff entry selects boss soundtrack")
	game.boss.state.state = "down"; game.boss.state.t = 1.79
	game.step(0.01, {})
	check(game.boss != null, "Mini remains at exact 1.8-second down boundary")
	game.step(0.001, {})
	check(game.boss == null and game.world_three.mini_done and game.camera_lock == null and game.mode == "play", "Mini dismisses after strict boundary without jar or false clear")
func test_render() -> void:
	fresh(); stand(Vector2(1450, 482), 1150); game.invincible = 999
	game.queue_redraw(); await process_frame; await process_frame
	var level = game.festival_night_level; var front = game.festival_night_front
	check(level.visible and front.visible and level.show_behind_parent and not front.show_behind_parent, "Actual scene orders level before actors and dark front afterward")
	check(level.passes.any(func(p): return p.visible and p.material_pass and p.commands[0].type == "night_additive"), "Actual level uses additive campfire material before actor layer")
	check(front.passes.any(func(p): return p.visible and p.material_pass and p.commands[0].type == "night_darkness"), "Actual front uses shader darkness")
	check(front.passes.any(func(p): return p.visible and p.material_pass and p.commands[0].type == "night_glow"), "Actual front uses separate additive fireglow")
	check(level.passes.filter(func(p): return p.visible).all(func(p): return p.draw_count > 0) and front.passes.filter(func(p): return p.visible).all(func(p): return p.draw_count > 0), "All real ordered CanvasItem batches executed")
	var state := JSON.stringify(game.world_three.snapshot()); var rng_state: int = game.world_three.rng.state
	game.queue_redraw(); await process_frame; await process_frame
	check(JSON.stringify(game.world_three.snapshot()) == state and game.world_three.rng.state == rng_state, "Repeated actual rendering never advances simulation or RNG")
	game.world_three.wiping = true; game.world_three.wipe_kind = "fade"; game.world_three.wipe_elapsed = 0.26
	var commands: Array = game.festival_renderer.build_hud(game, game.world_three)
	check(commands.any(func(c): return c.tag == "wipe_cover") and not commands.any(func(c): return c.tag == "wipe_iris"), "Actual HUD draws a uniform source fade")
	game._show_menu(); await process_frame; await process_frame
	check(not level.visible and not front.visible and level.passes.all(func(p): return not p.visible), "Menu hides night passes without ghost scenery")
func test_campaign_clear() -> void:
	game.save = {"schema": 1, "receipts": {}, "skills": [], "seen": {"3-intro": true}, "cleared": {}, "kitty": 13}
	for world in [1, 2]:
		for stage in range(1, 7): game.save.cleared["%d-%d" % [world, stage]] = true
	game.save.cleared["3-1"] = true; game.save.cleared["3-2"] = true
	game._show_campaign()
	check(game.start_campaign_level("3-3") and game.campaign_run and game.mode == "play", "Explicit prerequisite fixture starts native night campaign")
	for wave in game.combat.waves: wave.started = true; wave.done = true; wave.index = wave.group.size()
	game.world_three._scenes[1].done = true; game.world_three.mini_done = true
	game.camera = Vector2(game.level.w - game.view_width() - 2, 0)
	game.player = Vector2(game.camera.x + 350, 482); game.world_three.end_time = 2.6
	game.world_three.rng.seed = chance_seed(0.01)
	game.step(0.01, {})
	check(game.mode == "story" and game.story.playing and game._story_return_mode == "clear" and game.save.seen.get("3-clue", false), "Actual timed campaign clear opens 3-clue, never intro or gameplay")
	check(game.world_three.night.fireworks.size() == 1 and near(game.world_three.night.fireworks[0].t, 0.01), "Attested final base phase still executes after immediate clue presentation")
	var state: Dictionary = game.world_three.snapshot(); game.step(5, {})
	check(game.world_three.snapshot() == state, "Later story frames cannot continue gameplay")
	game.story.skip()
	check(game.mode == "clear" and SaveStore.read_save().cleared.get("3-3", false), "Skipping clue returns to saved settlement")
	game._campaign_next()
	check(game.mode == "menu" and game.campaign_target == "3-4" and game.start_campaign_level("3-4") and game.mode == "play", "Campaign continues from clue into actual native Big top")
