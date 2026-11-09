extends SceneTree
## Run from an empty harness project; only the mounted export supplies resources.
var failures := 0
var checks := 0
func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", label)
	return condition
func _initialize() -> void:
	var pack := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pack="): pack = argument.trim_prefix("--pack=")
	if not check(not pack.is_empty() and ProjectSettings.load_resource_pack(pack), "Mount exported resource pack"):
		quit(1)
		return
	call_deferred("run")
func run() -> void:
	if not check(FileAccess.file_exists("res://content/catalog.json"), "Catalog packaged"):
		quit(1)
		return
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/catalog.json"))
	check(catalog.levels.size() == 42, "All 42 entries packaged")
	for entry in catalog.levels: check(FileAccess.file_exists(entry.path), "Packaged level: " + entry.id)
	check(FileAccess.file_exists("res://content/story.json"), "Native story data packaged")
	for notice in ["Silkscreen-OFL.txt", "PixelifySans-OFL.txt", "FONT_NOTICES.txt"]:
		var notice_path: String = "res://legal/" + notice
		check(FileAccess.file_exists(notice_path), "Packaged font notice: " + notice)
		check(FileAccess.get_file_as_string(notice_path).length() > 1000, "Complete packaged font notice text: " + notice)
	check(not FileAccess.file_exists("res://content/reference/cutscenes.js.txt"), "Source reference excluded")
	check(not ResourceLoader.exists("res://tests/smoke.gd") and not ResourceLoader.exists("res://tools/build_audio.gd"), "Test and build tools excluded")
	var scene = load("res://main.tscn")
	if not check(scene != null, "Native main scene packaged"):
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	check(game.load_level("1-1"), "Packed native street starts")
	check(game.images.size() == game.meta.imgs.size(), "Packed street textures resolve")
	check(game.font.get_font_name() == "Silkscreen" and game.ui_font.get_font_name() == "Pixelify Sans", "Packed original fonts resolve through native imports")
	check(game.audio.noise_buffer.is_empty(), "Packed music uses prebuilt PCM, no synchronous synthesis")
	await create_timer(0.15).timeout
	game._open_story("1-intro")
	check(game.mode == "story" and game.story.playing, "Packed story playback starts")
	game.story.skip()
	await create_timer(0.15).timeout
	check(game.mode == "play", "Packed story returns to game")
	check(game.load_level("1-2"), "Packed rooftop starts")
	check(game.images.size() == game.meta.imgs.size() and game.world_one.crumbles.size() == 12, "Packed rooftop art and dynamic content resolve")
	await create_timer(0.15).timeout
	check(game.load_level("1-3") and game.bus_ride.enabled, "Packed bus ride starts")
	await create_timer(0.15).timeout
	for i in range(180):
		game.invincible = 999
		game.step(1.0 / 60, {})
	check(game.bus_ride.drive > 1000 and game.combat.waves[0].started and not game.enemies.is_empty(), "Packed bus timeline spawns its native first encounter")
	check(game.audio.noise_buffer.is_empty(), "Packed bus effects use prebuilt audio")
	await create_timer(0.15).timeout
	for id in ["1-4", "1-5", "1-S", "1-6"]:
		check(game.load_level(id) and game._native_world_one(), "Packed native street expansion starts: " + id)
		check(game.images.size() == game.meta.imgs.size() and game.street_renderer.supports(id), "Packed street art resolves: " + id)
		await create_timer(0.1).timeout
	# Isolated startup fixture, not a claim of whole-level input progression.
	game.start_boss()
	check(game.boss != null and game.boss.state.max == 260 and not game.boss.state.has("jar"), "Packed Binman starts its dedicated native encounter")
	for i in range(120):
		game.invincible = 999
		game.step(1.0 / 60, {})
	check(game.boss.state.state != "enter", "Packed Binman controller advances beyond entry")
	await create_timer(0.1).timeout
	check(game.load_level("2-1") and game._native_world_two(), "Packed supermarket runtime starts")
	check(game.images.size() == game.meta.imgs.size() and game.combat.waves.size() == 11, "Packed parking artwork and eleven waves resolve")
	# Explicit transition fixture checks packaged runtime/iris resources only.
	for wave in game.combat.waves: wave.started = true; wave.done = true
	game.camera = Vector2(7162, 0)
	game.player = Vector2(7550, 482)
	game.invincible = 999
	for i in range(95): game.step(1.0 / 60, {})
	check(game.world_two.scene_index == 1 and game.world_two.checkpoint_hit, "Packed parking lift and checkpoint execute")
	check(game.mode == "play" and game.world_two.wiping, "Packed parking transition retains live native scene")
	await create_timer(0.15).timeout
	check(game.load_level("2-2") and game._native_world_two(), "Packed aisle stage starts")
	await create_timer(0.1).timeout
	check(game.world_two.hazard_controller.gates.size() == 7 and game.world_two.hazard_controller.buttons.size() == 2, "Packed aisle gates and shot buttons load")
	check(game.supermarket_renderer.supports("2-2") and game.images.has("aisle") and game.images.has("freezer"), "Packed aisle painter and original paintings resolve")
	check(game.load_level("2-S") and game._native_world_two(), "Packed bonus shopping stage starts")
	await create_timer(0.1).timeout
	check(game.combat.waves.size() == 2 and game.world_two.hazard_controller.gates.is_empty(), "Packed bonus uses its source waves without leaked aisle gates")
	check(game.supermarket_renderer.supports("2-S") and game.images.has("street") and game.images.has("stall0"), "Packed bonus painter and original stalls resolve")
	check(game.load_level("2-3") and game._native_world_two(), "Packed stockroom starts")
	await create_timer(0.1).timeout
	check(game.combat.waves.size() == 11 and game.world_two.camera_cap(game) == 8292, "Packed stockroom uses eleven waves and correct goods-lift scene policy")
	check(game.supermarket_renderer.supports("2-3") and game.images.has("stockroom") and game.images.has("mezz"), "Packed stockroom and mezzanine paintings resolve")
	check(game.load_level("2-5") and game._native_world_two(), "Packed bakery starts")
	await create_timer(0.1).timeout
	check(game.combat.waves.size() == 11 and game.world_two.unsupported_hazards.is_empty(), "Packed bakery includes every wave and course hazard")
	check(game.supermarket_renderer.supports("2-5") and game.images.has("bakery") and game.images.has("swing"), "Packed bakery painter and original paintings resolve")
	check(game.load_level("2-4") and game._native_world_two(), "Packed trolley dash starts")
	await create_timer(0.1).timeout
	check(game.combat.waves.size() == 13 and game.world_two.course_controller.speed == 200, "Packed dash starts source waves and auto camera")
	check(game.supermarket_renderer.supports("2-4") and game.images.has("aisle5"), "Packed dash painter and all six aisles resolve")
	check(game.load_level("2-6") and game._native_world_two(), "Packed checkout stage starts")
	await create_timer(0.1).timeout
	check(game.combat.waves.size() == 3 and game.world_two.checkout != null and game.boss == null, "Packed checkout uses separate puzzle controller and three approach waves")
	check(game.supermarket_renderer.supports("2-6") and game.images.has("boss") and game.images.has("checkout") and game.images.has("crate2"), "Packed checkout art and crate assets resolve")
	# Explicit boss-entry fixture, not a substituted full progression proof.
	for wave in game.combat.waves: wave.started = true; wave.done = true
	game.camera = Vector2(4162, 0)
	game.player = Vector2(4300, 482)
	game.invincible = 999
	game.step(1.0 / 60, {})
	check(game.world_two.checkout.boss.get("state") == "enter" and game.world_two.checkout.boss.get("max") == 70, "Packed checkout starts its source puzzle encounter")
	for i in range(100): game.step(1.0 / 60, {})
	check(game.world_two.checkout.boss.get("state") == "fight" and game.boss == null, "Packed checkout advances entry without generic boss dispatch")
	check(game.mode == "play" and not game.save.get("cleared", {}).get("2-6", false), "Packed checkpoint fixture does not grant an artificial clear")
	check(game.load_level("3-1") and game._native_world_three(), "Packed fairground field starts")
	await create_timer(0.1).timeout
	check(game.images.size() == game.meta.imgs.size() and game.combat.waves.size() == 10, "Packed fairground paintings and ten waves resolve")
	check(game.festival_renderer.supports("3-1") and game.world_three.tents.size() == 16, "Packed festival painter and sixteen tent actors load")
	check(game.receipts.size() == 3 and game.receipts[0].position == Vector2(5060, 252), "Packed festival keeps authored receipt coordinates")
	# Explicit scene/boss startup fixtures, separate from all-six input routes.
	for wave in game.combat.waves: wave.started = true; wave.done = true
	game.camera = Vector2(7162, 0)
	game.player = Vector2(7550, 482)
	game.invincible = 999
	for i in range(95): game.step(1.0 / 60, {})
	check(game.world_three.scene_index == 1 and game.world_three.checkpoint_done, "Packed food-village iris and checkpoint execute")
	check(game.mode == "play" and game.world_three.wiping and game.world_three.wipe_midpoint_done, "Packed festival remains active after actual iris midpoint")
	game.camera = Vector2(8640, 0)
	game.player = Vector2(8990, 482)
	game.step(1.0 / 60, {})
	check(game.boss != null and game.boss.state.max == 60 and game.boss.state.state == "enter", "Packed Seller starts its source mini encounter")
	for i in range(100):
		game.invincible = 999
		game.step(1.0 / 60, {})
	check(game.boss != null and game.boss.state.state != "enter", "Packed Seller controller advances entry")
	check(game.mode == "play" and not game.save.get("cleared", {}).get("3-1", false), "Packed fixture cannot grant a festival clear")
	check(game.audio.noise_buffer.is_empty(), "Packed festival effects and boss music use prebuilt audio")
	await create_timer(0.1).timeout
	check(game.load_level("3-2") and game._native_world_three(), "Packed Queue jump starts")
	await create_timer(0.1).timeout
	check(game.images.size() == game.meta.imgs.size() and game.combat.waves.size() == 15, "Packed queue paints and fifteen waves resolve")
	check(game.festival_renderer.supports("3-2") and game.world_three.queue_rush.supports("3-2"), "Packed queue painter and extension dispatch")
	check(game.world_three.surfaces(game).filter(func(s): return s.get("style", "") == "crowd").size() == 5, "Packed queue has all five crowd conveyors")
	# Explicit source clock/scene fixtures, not a full input run.
	game.world_three.level_time = 1.8
	game.step(0, {})
	check(game.camera.x == 0, "Packed queue respects strict warmup")
	game.step(0.01, {})
	check(absf(game.camera.x - 1.4) < 0.002, "Packed queue scrolls at source speed after warmup")
	game.camera = Vector2(14000, 0)
	game.player = Vector2(14301, 482)
	for i in range(95):
		game.invincible = 999
		game.step(1.0 / 60, {})
	check(game.world_three.scene_index == 1 and game.world_three.checkpoint_done and game.world_three.wipe_midpoint_done, "Packed queue executes actual arena iris and checkpoint")
	check(game.world_three.stage_data.events_done == [0] and game.status.contains("Crowd surf!"), "Packed queue displays source arena notice")
	check(not game.save.get("cleared", {}).get("3-2", false), "Packed queue scene fixture does not manufacture completion")
	await create_timer(0.1).timeout
	check(game.load_level("3-3") and game._native_world_three(), "Packed after-dark stage starts")
	await create_timer(0.15).timeout
	check(game.images.size() == game.meta.imgs.size() and game.combat.waves.size() == 10, "Packed night artwork and ten waves resolve")
	check(game.festival_renderer.supports("3-3") and game.world_three.stage_data.fires.size() == 5, "Packed night painter and five fire hazards load")
	check(game.festival_night_level.show_behind_parent and not game.festival_night_front.show_behind_parent, "Packed night has ordered background/foreground material layers")
	check(game.festival_night_front.passes.any(func(p): return p.visible and p.material_pass and p.commands[0].type == "night_darkness" and p.draw_count > 0), "Packed night actual shader CanvasItem callback runs")
	game.festival_event({"type": "firework"})
	check(game.audio.noise_buffer.is_empty(), "Packed firework effect uses prebuilt resource without synthesis")
	game.camera = Vector2(7740, 0); game.player = Vector2(8050, 482)
	game.world_three._scenes[1].done = true
	game.invincible = 999; game.step(0, {})
	check(game.boss != null and game.boss.state.kind == "bailiff" and game.boss.state.max == 70, "Packed night starts dedicated Bailiff mini configuration")
	check(game.mode == "play" and not game.save.get("cleared", {}).get("3-3", false), "Packed night startup fixture does not grant a clear")
	await create_timer(0.1).timeout
	check(game.load_level("3-4") and game._native_world_three(), "Packed Big top starts")
	await create_timer(0.1).timeout
	check(game.combat.waves.size() == 9 and game.world_three.surfaces(game).size() == 64, "Packed Big top has nine waves and live ground/platform geometry")
	check(game.festival_renderer.supports("3-4") and game.images.has("backdrop") and game.images.has("pole"), "Packed interior painter and original art resolve")
	check(game.world_three.big_top.movers.size() == 4 and game.world_three.big_top.spots.size() == 6, "Packed Big top loads all trapezes and spotlights")
	game.step(0.016, {})
	check(game.world_three.big_top.movers.any(func(m): return absf(float(m.q.dx)) > 0), "Packed trapezes update their actual live collision rows")
	check(not game.movement_skills.card_collected and not game.save.get("skills", []).has("ground-pound"), "Packed Big top does not grant its card on entry")
	# Explicit two-shot spotlight fixture, not full upper-route progression.
	game.camera = Vector2(2500, -600); game.player = Vector2(2800, -278)
	game.invincible = 999
	game.bullets = [{"p": Vector2(2800, -444), "v": Vector2.ZERO, "enemy": false, "damage": 99, "life": 2.0}, {"p": Vector2(2800, -444), "v": Vector2.ZERO, "enemy": false, "damage": 1, "life": 2.0}]
	game.step(0, {})
	check(game.world_three.big_top.spots[0].on and game.world_three.big_top.spots[0].hp == 0, "Packed spotlight consumes two actual shots regardless of damage")
	check(not game.save.get("cleared", {}).get("3-4", false), "Packed Big top fixture cannot manufacture completion")
	await create_timer(0.1).timeout
	check(game.load_level("3-5") and game._native_world_three(), "Packed Hay ride starts")
	await create_timer(0.1).timeout
	check(game.images.size() == game.meta.imgs.size() and game.festival_renderer.supports("3-5"), "Packed lane, dusk, tractor and carrier artwork resolve")
	check(game.combat.waves.size() == 16 and game.world_three.surfaces(game).size() == 1 and game.player.y == 402, "Packed hayride binds its only live deck before initial floor query")
	check(game.world_three.trailer.get("nodrop", false) and game.world_three.trailer.get("nospawn", false), "Packed deck preserves authored non-droppable spawn policy")
	game.world_three.level_time = 1.8
	game.step(0.01, {})
	check(absf(game.camera.x - 1.7) < 0.002 and absf(game.world_three.trailer.row[0] - 61.7) < 0.002, "Packed auto scroll moves live trailer at source speed")
	# Isolated late-harvester fixture, not input progression or a defeat claim.
	var delta_x: float = 15000 - game.camera.x
	game.world_three.hayride.scene_translate(delta_x, game.world_three)
	game.camera.x = 15000; game.player = Vector2(15300, 402)
	game.world_three._scenes[1].done = true
	game.invincible = 999; game.step(0, {})
	check(game.boss == null and game.world_three.hayride.harvester.get("hp", 0) == 70 and game.audio.boss_music, "Packed harvester is a separate live 70-HP encounter with boss music")
	# Explicit visible-body fixture: the real spawn is cam-420, outside the
	# ordinary shot-cull range. Preserve that earlier pass, then test late hits.
	game.world_three.hayride.harvester.x = game.camera.x + 220
	var harvester_x: float = game.world_three.hayride.harvester.x
	game.bullets = [{"p": Vector2(harvester_x - 100, 200), "v": Vector2.ZERO, "enemy": false, "damage": 99, "life": 2.0}, {"p": Vector2(harvester_x - 100, 200), "v": Vector2.ZERO, "enemy": false, "damage": 1, "life": 2.0}]
	game.step(0, {})
	check(game.world_three.hayride.harvester.hp == 68, "Packed harvester consumes actual late shots for one HP each")
	check(game.mode == "play" and not game.save.get("cleared", {}).get("3-5", false), "Packed hayride fixture does not manufacture a clear")
	await create_timer(0.1).timeout
	check(game.load_level("3-6") and game._native_world_three(), "Packed Ticket Tout finale starts")
	await create_timer(0.1).timeout
	check(game.images.size() == game.meta.imgs.size() and game.festival_renderer.supports("3-6"), "Packed finale painter and all original move strips resolve")
	check(game.combat.waves.size() == 3 and game.meta.l3.toutfr.size() == 7, "Packed finale retains three approach waves and seven boss animation definitions")
	game.camera = Vector2(3662,0); game.player = Vector2(3950,482); game.invincible = 999
	game.step(0,{})
	check(game.boss == null, "Packed end camera alone cannot skip approach waves")
	for wave in game.combat.waves: wave.started = true; wave.done = true
	game.enemies.clear()
	game.step(0,{})
	check(game.boss != null and game.boss.state.max == 160 and game.boss.state.cam == 3662, "Packed finale starts actual 160-HP Ticket Tout with source lock")
	check(game.boss._stage.row[0] == 4040 and game.boss._stage.row[2] == 354, "Packed boss binds numeric stage zero rather than treating it as false")
	for i in range(60): game.step(1.0/60,{})
	check(game.boss.state.state != "enter" and game.boss.state.has("moved"), "Packed encounter advances entry and samples real movement")
	check(game.mode == "play" and game.boss.state.jar.is_empty() and not game.save.get("cleared",{}).get("3-6",false), "Packed boss startup neither creates a jar nor grants completion")
	await create_timer(0.1).timeout
	check(game.load_level("3-S") and game._native_world_three(), "Packed festival bonus starts")
	await create_timer(0.1).timeout
	check(game.images.size() == game.meta.imgs.size() and game.festival_renderer.supports("3-S"), "Packed bonus original art and painter resolve")
	check(game.world_three.bonus.timer_duration == 90 and game.combat.waves.is_empty(), "Packed bonus has actual 90-second clock and no invented fight")
	game.step(0, {})
	check(game.mode == "play" and game.coins.size() == 179, "Packed fresh bonus seeds all 179 coins without premature clear")
	check(game.receipts.size() == 3 and game.world_three.bonus.timer_elapsed == 0, "Packed bonus retains three receipts and late clock ordering")
	game.world_three.bonus.timer_elapsed = 89.99
	game.step(0.02, {})
	check(game.world_three.bonus.clear_reason == "timeout" and game.mode == "clear", "Packed bonus uses real inclusive timeout completion")
	check(game.score == 179 and game.coins.is_empty(), "Packed timeout settles surviving coins through ordinary completion")
	check(game.save.get("cleared", {}).get("3-S", false), "Packed actual bonus objective persists its clear")
	await create_timer(0.1).timeout
	# Later-family startup/render/resource fixtures, not full-route certification.
	for world in [4, 5, 6]:
		for stage in ["1", "2", "3", "4", "5", "6", "S"]:
			var id := "%d-%s" % [world,stage]
			check(game.load_level(id) and game.is_native_supported(), "Packed later-family runtime starts: " + id)
			check(game.images.size() == game.meta.imgs.size() and game.receipts.size() == 3, "Packed original artwork and all receipts: " + id)
			check(game.audio.current_cue == ("bonus" if stage == "S" else "world%d" % world), "Packed original score selects " + id)
			for tick in range(30):
				game.invincible = 999
				game.step(1.0/60,{"right":true,"shoot":true})
			check(game.player.is_finite() and game.camera.is_finite() and game.mode == "play" and not game.save.get("cleared",{}).get(id,false), "Packed startup advances without fake clear: " + id)
			await process_frame
			await create_timer(0.04).timeout
	for cue in game.audio.CUES:
		var stream = game.audio.score_stream(cue)
		check(stream != null and stream.get_length() > 0, "Packed self-contained original score: " + cue)
	check(not FileAccess.file_exists("res://assets/music/title.ogg") and not FileAccess.file_exists("res://assets/music/score_manifest.json"), "Composer intermediates excluded while native music works")
	check(game.player_hud != null and game.shared_effects_renderer != null and game.credits_roll != null, "Packed HUD, native effects and credits modules resolve")
	game._show_campaign()
	check(game.mode == "menu" and game.campaign_view, "Packed campaign view opens")
	check(game.campaign_map != null and game.campaign_map.pictures.size() > 6, "Packed original painted-map textures resolve")
	var original_party := [game.character, game.party_session.runtime.mode, game.party_session.runtime.p2]
	game.campaign_map._show_friends()
	var selector = game.campaign_map.friend_panel
	check(selector.visible and selector.cards.size() == 6 and selector.background != null, "Packed official six-door character selector and backdrop resolve")
	selector.cancel()
	check(not selector.visible and original_party == [game.character, game.party_session.runtime.mode, game.party_session.runtime.p2], "Packed selector Cancel preserves the current party")
	check(game.start_campaign_level("1-1") and game.campaign_run and game.mode == "play", "Packed campaign starts supported unlocked stage with previously seen intro")
	await create_timer(0.1).timeout
	game._return_to_map()
	check(game.mode == "menu" and game.campaign_view and not game.campaign_run, "Packed campaign returns to its map context")
	check(not game.start_campaign_level("4-1") and game.mode == "menu", "Packed campaign rejects locked destinations without prerequisite clears")
	# Explicit complete-save fixture verifies ending assets, not gameplay completion.
	game.save.cleared = {}
	for world in range(1,7):
		for stage in range(1,7): game.save.cleared["%d-%d" % [world,stage]] = true
	check(game._show_credits() and game.credits_roll.playing and game.audio.current_cue == "ending", "Packed verified-ending fixture opens original credits and ending cue")
	check(game.credits_roll.content.has("Thanks for playing") and game.credits_roll.painting != null, "Packed credit text and title painting resolve")
	game.credits_roll.skip()
	check(game.mode == "menu" and game.audio.current_cue == "title", "Packed credit return restores menu and title cue")
	# Explicit packed lifecycle/resource fixtures, not assisted full routes.
	check(game.party_session.INTEGRATING_LEVELS.size() == 42, "Packed party runtime admits every authored stage")
	for world in range(1, 7):
		game._show_menu()
		game.character = "jp"
		check(game.configure_party("cpu", "maya") and game.load_level("%d-1" % world, false), "Packed CPU party starts world %d" % world)
		check(game.party_session.active and game.party_session.runtime.actors.size() == 2, "Packed world %d retains independent actors" % world)
		for tick in range(30):
			for actor in game.party_session.runtime.actors: actor.invincible = 999
			game.step(1.0 / 60, {"right": true, "shoot": true})
		check(game.party_session.runtime.actors.all(func(actor): return actor.player.is_finite()) and game.mode == "play", "Packed world %d party advances without forced progression" % world)
		check(game.mobile_game_menu != null and game.hud_controls.size() == 1 and game.touch_control_style == "joystick", "Packed world %d uses consolidated mobile menu and chosen joystick" % world)
		await create_timer(0.05).timeout
	game._show_menu()
	game.character = "jp"
	check(game.configure_party("p2", "maya") and game.load_level("1-1", false), "Packed local P2 starts")
	var first = game.party_session.runtime.actors[0]
	var second = game.party_session.runtime.actors[1]
	var before := Vector2(first.player.x, second.player.x)
	var before_time: float = game.elapsed
	for tick in range(10):
		first.invincible = 999; second.invincible = 999
		game.party_session.step(game, 1.0 / 60, {"right": true}, {"left": true})
	check(first.player.x > before.x and second.player.x < before.y and not second.cpu, "Packed two-human slots consume independent controls")
	check(absf(game.elapsed - before_time - 10.0 / 60) < 0.00001, "Packed pair advances world clock once per frame")
	game._show_menu()
	var notices = load("res://src/legal_notices.gd").new()
	root.add_child(notices)
	notices.configure(game.ui_font)
	notices.open()
	check(notices.opened and notices.missing_notice_paths.is_empty(), "Packed licenses view opens with every font notice")
	check(notices.body.text.contains(Engine.get_license_text()) and notices.body.text.contains("SIL OPEN FONT LICENSE Version 1.1"), "Packed licenses view contains running engine and bundled font terms")
	notices.close()
	notices.queue_free()
	game.audio.shutdown()
	await create_timer(0.1).timeout
	game.queue_free()
	await create_timer(0.15).timeout
	print("Packed runtime: ", checks, " checks, ", failures, " failures; no device/rendering certification")
	quit(0 if failures == 0 else 1)
