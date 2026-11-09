extends SceneTree
var failures: Array[String] = []
var checks := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label); printerr("FAIL: ", label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	game.save = {"schema": 1, "receipts": {}}
	game.load_level("1-1")
	game.player.x = 600
	game.combat.tick(0.016, game)
	check(not game.combat.waves[0].started, "Wave waits for camera, not player's position")
	game.camera.x = 399
	game.combat.tick(0.016, game)
	check(game.combat.waves[0].started and game.camera_lock == 439, "Original first wave starts and locks camera")
	check(game.enemies.size() == 1 and game.enemies[0].hp == 3, "Original rush spawn has three hit points")
	game.combat.tick(1.5, game)
	check(game.combat.waves[0].index == 3, "Original delayed group fully spawns")
	for enemy in game.enemies: enemy.state = "pop"
	game.combat.tick(0.016, game)
	check(game.combat.waves[0].done and game.camera_lock == null, "Wave releases only after final robot is down")
	game.load_level("1-1")
	for kind in ["tiny", "mini", "fly"]: game.combat.spawn(game, "r", kind)
	check(game.enemies[0].hp == 1 and game.enemies[0].scale == 0.6, "Small Print uses source size and health")
	check(game.enemies[1].hp == 32 and game.enemies[1].volley == 2.4, "Bailiff solo health and volley timer")
	check(game.enemies[2].hp == 2 and game.enemies[2].p.y < 300, "Junk mailer spawns airborne")
	game.combat.spawn(game, "r", "rush")
	var near_enemy: Dictionary = game.enemies.back()
	near_enemy.p = game.player + Vector2(10, 0)
	game._fire({})
	game.combat.projectiles(1.0 / 60, game)
	check(near_enemy.hp == 2, "First-frame sweep hits an enemy between player and muzzle")
	game.bullets.clear()
	var tiny: Dictionary = game.enemies[0]
	game.enemies = [tiny]
	tiny.p = game.player + Vector2(100, 0)
	game.crouching = false
	game._fire({})
	game.combat.projectiles(0.1, game)
	check(tiny.hp == 1, "Standing shot passes above Small Print")
	game.bullets.clear()
	game.crouching = true
	game._fire({})
	game.combat.projectiles(0.1, game)
	check(tiny.state == "pop" and game.pop_count == 1, "Crouching shot defeats Small Print")
	check(game.coins.size() >= 4 and game.coins.size() <= 6, "Robot drops source-range recoverable coins")
	game.enemies.clear()
	game.bullets.clear()
	game.bullets.append({"p": game.player - Vector2(0,128), "v": Vector2.ZERO, "life":1.0, "enemy":true})
	game.combat.projectiles(0.016, game)
	check(game.hearts == 3, "Duck avoids flat bill")
	game.crouching = false
	game.bullets.clear()
	game.bullets.append({"p": game.player - Vector2(0,128), "v": Vector2.ZERO, "life":1.0, "enemy":true})
	game.combat.projectiles(0.016, game)
	check(game.hearts == 2 and game.invincible > 1.4, "Standing bill damage and original invulnerability")
	game.bullets.clear()
	game.bullets.append({"p": Vector2(game.player.x + 200, -50), "v": Vector2(0, -100), "gravity":1600.0, "life":3.0, "enemy":true})
	game.combat.projectiles(0.016, game)
	check(game.bullets.size() == 1, "Hostile lob survives above viewport and can fall back")
	game.load_level("1-1")
	var crate: Dictionary = game.crates[0]
	for i in range(3): game.hit_crate(crate, 1)
	check(crate.broken and game.items.size() == 1 and game.items[0].give == "split", "Three hits release original crate power")
	game.player.x = crate.p.x
	game.combat._pickups(0.31, game)
	check(game.power == "split" and game.power_time == 12, "Split shot pickup lasts twelve seconds")
	game.bullets.clear()
	game._fire({})
	check(game.bullets.size() == 3, "Split shot fires source three-projectile pattern")
	game.bullets.clear()
	game.power = ""
	game.crouching = false
	game._fire({"aim":true})
	check(absf(game.bullets[0].v.x) < 1 and game.bullets[0].v.y == -780, "Aim alone fires straight up")
	game.load_level("1-1")
	game.camera.x = float(game.level.w) - game.view_width()
	game.player.x = game.camera.x + 200
	game.combat.tick(0.016, game)
	check(game.boss == null, "Reaching end cannot skip uncleared waves")
	game.enemies.clear()
	for wave in game.combat.waves: wave.started = true; wave.done = true
	game.combat.tick(0.016, game)
	check(game.boss != null and game.boss.state.hp == 70, "Cleared full wave sequence unlocks solo boss")
	# Traverse the original boss state machine, not a direct completion shortcut.
	for i in range(90):
		game.invincible = 5
		game.step(1.0 / 60, {})
	check(game.boss.state.state == "walk", "Boss enters the arena before it is damageable")
	var target := Vector2(game.boss.state.x, game.boss.state.fy - 120)
	while game.boss.state.hp > 0:
		game.boss.hit(target, 1)
	check(game.mode == "play" and not game.save.get("cleared", {}).get("1-1", false), "Defeating boss alone does not grant completion")
	for i in range(100):
		game.invincible = 5
		game.step(1.0 / 60, {})
	check(not game.boss.state.jar.is_empty(), "Boss defeat produces the collectible jar")
	for i in range(50):
		game.player.x = game.boss.state.jar.x
		game.invincible = 5
		game.step(1.0 / 60, {})
	check(game.mode == "clear" and game.save.cleared["1-1"], "Jar pickup completes encounter and persists native clear")
	check(not game.save.cleared.has("1-2"), "Preview levels are never granted fake completion")
	game.load_level("1-1")
	game._open_story("1-intro")
	check(game.mode == "story" and game.story.playing, "Story suspends gameplay")
	var before: Vector2 = game.player
	game._physics_process(0.1)
	check(game.player == before, "Story cannot advance gameplay")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.mode == "paused" and game.story.paused, "App interruption pauses story and audio")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game.story._input(escape)
	check(game.mode == "paused" and game.story.playing, "Paused story cannot bypass pause via Escape skip")
	game._resume()
	check(game.mode == "story" and not game.story.paused, "Explicit resume returns to story")
	game.story.skip()
	check(game.mode == "play" and not game.story.playing, "Skip returns to gameplay without clearing the level")
	game._open_story("1-intro")
	game._open_story("1-intro")
	game.story.skip()
	check(game.mode == "play", "Repeated story request preserves original return mode")
	game._open_story("1-intro")
	game._pause()
	game._show_menu()
	game._open_story("1-clue")
	check(not game.story.next_button.disabled and not game.story.skip_button.disabled, "New story resets controls after stopping paused playback")
	game.story.skip()
	game.character = "jp"
	game.load_level("1-1")
	for key in game.CHARACTERS:
		check(game._up_pose_ok(key) == (key != "maya"), "Alpha size check selects source aim row for " + key)
	check(game.up_pose_cache.size() == 6, "Aim pose suitability is cached per character")
	game.step(0.016, {"aim": true})
	check(game.player_animation == "up" and game._player_frame() == 0 and game.bullets.is_empty(), "Grounded aim raises pose without shooting")
	for i in range(5): game.step(0.016, {"aim": true})
	check(game._player_frame() == 3, "Up pose holds frame three after 90 ms")
	game.step(0.016, {"aim": true, "shoot": true})
	check(game.player_animation == "up" and game._player_frame() == 1 and is_equal_approx(game.shoot_time, 0.284), "Up firing starts on frame one and consumes this frame's shoot timer")
	game.step(0.1, {"aim": true})
	check(game._player_frame() == 2, "Up firing advances after 100 ms")
	game.step(0.01, {})
	check(game.player_animation == "diag", "Released aim preserves last shot diagonal pose until shooting timer expires")
	game.character = "maya"
	game.load_level("1-1")
	game.step(0.016, {"aim": true})
	check(game.player_animation == "diag" and game._player_frame() == 0, "Undersized Maya up row falls back to nonfiring diagonal frame zero")
	game.character = "jp"
	game.load_level("1-1")
	game.step(0.1, {"right": true})
	game.step(0.1, {"right": true})
	game.step(0.016, {"right": true, "aim": true})
	check(game.player_animation == "rundiag" and is_equal_approx(game.animation_time, 0.216) and game._player_frame() == 3, "Moving aim preserves run stride at source 15 fps")
	game.step(0.016, {"right": true})
	check(game.player_animation == "run" and is_equal_approx(game.animation_time, 0.232) and game._player_frame() == 3, "Releasing moving aim preserves stride")
	game.step(0.016, {"jump": true, "shoot": true, "aim": true, "right": true})
	check(not game.grounded and game.player_animation == "jump", "Airborne aiming and firing retain jump pose")
	game.load_level("1-1")
	game.step(0.016, {"down": true, "aim": true, "shoot": true})
	check(game.player_animation == "crouch", "Crouch takes precedence over aim and shooting poses")
	game.hurt_lock = 0.4
	game.step(0.016, {"aim": true})
	check(game.player_animation == "hit" and game._player_frame() == 0, "Hurt pose overrides aiming")
	game.animation_time = 0.111
	check(game._player_frame() == 1, "Hurt animation advances on source 110 ms timing")
	game.animation_time = 0.8
	check(game._player_frame() == 3, "Hurt animation holds final frame instead of looping")
	game.character = "leo"
	game.load_level("1-1")
	game.step(0.016, {})
	game.abilities.meter = 1.0
	game.step(0.016, {"special": true})
	game.step(0.016, {})
	check(not game.grounded and game.player_animation == "up" and not game.aim_up, "Leo glider retains intentional airborne up animation without ground aim hold")
	game.animation_time = 0.21
	check(game._player_frame() == 2, "Leo glider up row uses source 10 fps")
	game.queue_free()
	await process_frame
	print("Combat integration: ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
