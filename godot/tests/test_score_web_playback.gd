extends SceneTree
## Exercise both policies on real players. This is not a browser audio test.
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var score = load("res://src/original_score.gd").new()
	root.add_child(score)
	score.set_process(false)
	var expected := AudioServer.PLAYBACK_TYPE_STREAM if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_DEFAULT
	check(score.music_player.playback_type == expected and score.spare.playback_type == expected, "Ready selects the actual platform policy on both score voices")
	score._configure_score_playback(false)
	check(score.music_player.playback_type == AudioServer.PLAYBACK_TYPE_DEFAULT and score.spare.playback_type == AudioServer.PLAYBACK_TYPE_DEFAULT, "Native score playback retains Default")
	score._configure_score_playback(true)
	check(score.music_player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM and score.spare.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "Web long-form music uses Stream on both voices")
	check(score.effect_players.size() == 24 and score.effect_players.all(func(player): return player.playback_type == AudioServer.PLAYBACK_TYPE_DEFAULT), "All short-effect players retain engine Default")
	check(score.play_cue("title"), "Title starts through score adapter")
	await create_timer(0.05).timeout
	var original = score.music_player
	check(score.play_cue("map"), "Map cue starts")
	await create_timer(0.05).timeout
	check(score.spare == original and score.fade_remaining > 0, "Existing bounded crossfade swaps the same voices")
	check(score.music_player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM and score.spare.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "Crossfade cannot swap in a Sample/default music voice")
	score.set_paused(true)
	score._process(1.0)
	check(score.music_player.stream_paused and score.spare.stream_paused, "Pause still covers both streaming voices")
	score.set_paused(false)
	score._process(1.0)
	check(score.spare.stream == null and score.fade_remaining == 0, "Completed crossfade releases the outgoing stream")
	score.shutdown()
	check(score.music_player.stream == null and score.spare.stream == null and score.score_cache.is_empty(), "Shutdown releases both streamed score voices and compressed cue cache")
	score.queue_free()
	await create_timer(0.25).timeout
	print("Score Web playback policy: ", checks, " checks, ", failures, " failures; not browser audio certification")
	quit(0 if failures == 0 else 1)
