extends SceneTree
var reports: Array = []
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var player = preload("res://src/story_player.gd").new()
	root.add_child(player)
	player.finished.connect(func(id, skipped): reports.append([id, skipped]))
	assert(player.data.worlds.size() == 6)
	assert(player.data.scenes.size() == 21)
	for id in ["1-intro", "1-clue", "1-boss"]:
		assert(player.play(id))
		assert(player.playing)
		var count = player.shots.size()
		for i in range(count):
			assert(player.shot_index == i)
			assert(player.shot.has("bg") and player.shot.has("cam"))
			player.advance()
		assert(not player.playing)
		assert(reports.back() == [id, false])
	assert(player.play("1-intro"))
	player.set_paused(true)
	player._process(1)
	player.advance()
	assert(player.elapsed == 0 and player.shot_index == 0)
	player.set_paused(false)
	player.skip()
	assert(reports.back() == ["1-intro", true])
	var count = reports.size()
	player.stop()
	assert(reports.size() == count)
	var resolved = player.resolve_shots([
		{"bg":"street", "cam":[0,0,1536], "cam2":[10,20,1000], "actors":[{"id":"jp", "s":"jp", "x":0,"y":2,"to":[10,20],"a2":"idle","h2":2,"dl":100}]},
		{"keep":true,"set":{"jp":{"f":true}}},
		{"keep":true,"drop":["jp"]}])
	assert(resolved[1].actors[0].x == 10)
	assert(resolved[1].actors[0].a == "idle")
	assert(resolved[1].actors[0].hold == 2)
	assert(not resolved[1].actors[0].has("dl"))
	assert(resolved[1].cam == [10,20,1000])
	assert(resolved[2].actors.is_empty())
	# Exercise drawing on actual rendered frames, not just data/API assertions.
	for id in ["1-intro", "1-clue", "1-boss"]:
		player.play(id)
		for i in range(player.shots.size()):
			player.elapsed = 1200
			player.queue_redraw()
			await process_frame
			player.advance()
	print("Story tests passed: all World 1 shots, pause, lifecycle, carry and draw.")
	quit(0)
