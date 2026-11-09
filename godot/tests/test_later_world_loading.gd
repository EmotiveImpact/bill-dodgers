extends SceneTree
## Real-host loading and source phase smoke, not a full route proof.
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.save = {"schema": 1, "receipts": {}}
	for world in [4, 5, 6]:
		for stage in ["1", "2", "3", "4", "5", "6", "S"]:
			var id := "%d-%s" % [world, stage]
			game.camera = Vector2(12345, -678)
			check(game.load_level(id), id + " loads")
			check(game.is_native_supported() and game.player.is_finite(), id + " native finite spawn")
			check(game.images.size() == game.meta.imgs.size(), id + " all source images")
			check(game.receipts.size() == 3, id + " three native receipts")
			check(game.camera.x == 0, id + " no stale horizontal camera")
			if id == "4-5": check(game.player == Vector2(330,482) and game.world_four.deck.row[0] == 210, "Pedalo binds fresh deck before floor lookup")
			if id == "5-5": check(game.player.y == 420, "Moving van source high-floor query lands on deck")
			if id == "4-S": check(game.coins.size() == game.level.cfg.dash.coins.size(), "Holiday bonus coins survive shared reset")
			if world == 5: check(game.coins.size() == game.level.get("coins", []).size(), id + " authored coins survive shared reset")
			if world == 6: check(game.coins.size() == game.level.get("coinRows", []).size(), id + " authored coins survive shared reset")
			for i in 90:
				game.invincible = 999
				game.step(1.0/60,{"right": true, "shoot": true})
			check(game.player.is_finite() and game.camera.is_finite(), id + " finite after motion")
			check(game.mode == "play" and not game.save.get("cleared",{}).get(id,false), id + " no fake startup clear")
			await process_frame
			await process_frame
	game.audio.shutdown()
	await create_timer(0.15).timeout
	game.queue_free()
	await create_timer(0.15).timeout
	print("Later-world real-host loading: ", checks, " checks, ", failures, " failures; not progression proof")
	quit(0 if failures == 0 else 1)
