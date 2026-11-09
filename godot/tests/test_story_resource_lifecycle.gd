extends SceneTree
## Real imported resources, weak references and public scene lifecycle.
var checks := 0
var failures := 0
var events: Array = []
var reenter := false

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func warm(player) -> WeakRef:
	var key := "bg-" + str(player.shot.bg) + ".webp"
	var texture: Texture2D = player._texture(key)
	check(texture != null, "Current scene background loads")
	return weakref(texture)

func finished(player, id: String, skipped: bool) -> void:
	events.append([id, skipped, player.textures.size(), player.playing])
	if reenter:
		reenter = false
		player.play("1-intro")
		warm(player)

func run() -> void:
	var player = load("res://src/story_player.gd").new()
	root.add_child(player)
	player.set_process(false)
	player.finished.connect(func(id, skipped): finished(player, id, skipped))
	check(player.play("1-intro"), "Load initial scene")
	var initial := warm(player)
	var initial_id: int = initial.get_ref().get_instance_id()
	check(warm(player).get_ref().get_instance_id() == initial_id, "Repeated shot lookup reuses the current scene texture")
	player.set_paused(true)
	player.skip()
	player.advance()
	check(player.playing and player.shot_index == 0 and initial.get_ref() != null, "Paused skip/advance retain active art and scene")
	check(not player.play("not-a-real-story"), "Invalid scene request fails")
	check(player.playing and player.scene_id == "1-intro" and initial.get_ref() != null and events.is_empty(), "Invalid scene does not discard current cache or emit completion")
	player.set_paused(false)
	player.skip()
	check(player.textures.is_empty() and initial.get_ref() == null, "Skip releases cached background resource")
	check(events.back() == ["1-intro", true, 0, false], "Finished listener sees stopped scene and empty old cache")
	var count := events.size()
	player.stop()
	check(events.size() == count, "Repeated stop is still idempotent")
	check(player.play("1-intro"), "Replay starts")
	var replay := warm(player)
	check(replay.get_ref() != null, "Replay reloads released original art")
	while player.playing: player.advance()
	check(replay.get_ref() == null and player.textures.is_empty(), "Natural completion releases cached resources")
	check(events.back() == ["1-intro", false, 0, false], "Natural finish reports unchanged scene identity and completion flag")
	player.play("title")
	var attract := warm(player)
	player.set_paused(true)
	player.stop()
	check(attract.get_ref() == null and events.back()[0] == "title", "Attract-style explicit stop releases art even while paused")
	player.play("1-intro")
	var replaced := warm(player)
	check(player.play("2-intro"), "Scene replacement starts normally")
	check(replaced.get_ref() == null and player.textures.is_empty(), "Scene replacement clears previous scene before lazy loading new one")
	warm(player)
	reenter = true
	player.stop()
	check(player.playing and player.scene_id == "1-intro" and not player.textures.is_empty(), "Reentrant finished listener can load another scene without its cache being cleared afterward")
	player.stop()
	player.queue_free()
	await process_frame
	await process_frame
	print("Story resource lifecycle: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
