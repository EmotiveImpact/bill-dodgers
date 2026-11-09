extends SceneTree
const Score = preload("res://src/original_score.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var a := Score.new(); root.add_child(a); a.set_process(false)
	for cue in Score.CUES:
		var stream: AudioStreamOggVorbis = a.score_stream(cue)
		check(stream != null, cue + " packaged native Vorbis")
		if stream == null: continue
		check(stream.get_length() > 5 and stream.get_length() < 90, cue + " bounded complete composition")
		check(stream.loop == (cue not in ["victory", "gameover", "ending"]) and stream.loop_offset == 0, cue + " source-independent loop flag")
		check(a.score_stream(cue) == stream, cue + " cache identity")
		var playback := stream.instantiate_playback()
		playback.start()
		var decoded := playback.mix_audio(1.0, 1024)
		check(decoded.size() == 1024, cue + " decoder emits audio")
		var energy := 0.0
		for sample in decoded: energy += sample.length_squared()
		check(energy > 0 and is_finite(energy), cue + " non-silent finite decoded PCM")
		playback.stop()
	for world in range(1, 7):
		check(a.cue_for_level(str(world) + "-1") == "world" + str(world), "world theme selection")
		check(a.cue_for_level(str(world) + "-S") == "bonus", "bonus theme selection")
		check(a.cue_for_level(str(world) + "-6", true) == ("final_boss" if world == 6 else "boss"), "boss theme selection")
	check(a.score_stream("missing") == null and not a.play_cue("missing"), "unknown cue rejected")
	a.set_level("5-2"); a.start_music()
	await create_timer(0.06).timeout
	check(a.current_cue == "world5" and a.music_player.playing, "level theme starts")
	var current := a.music_player
	a.start_music(); check(a.music_player == current, "same cue does not restart")
	a.start_music(true)
	await create_timer(0.06).timeout
	check(a.current_cue == "boss" and a.spare == current and a.fade_remaining > 0, "bounded two-player boss crossfade")
	a.set_paused(true); a._process(1.0)
	check(a.music_player.stream_paused and a.spare.stream_paused and a.fade_remaining == Score.CROSSFADE, "pause freezes both crossfade voices and envelope")
	a.set_paused(false); a._process(1.0)
	check(a.fade_remaining == 0 and a.spare.stream == null and a.music_player.volume_db == -18, "crossfade releases old stream and preserves headroom")
	a.set_enabled(false)
	check(a.music_player.stream_paused, "sound off mutes score")
	a.set_enabled(true); a.play_cue("victory")
	await create_timer(0.06).timeout
	check(not a.music_player.stream.loop, "victory is a one-shot")
	a.start_title()
	await create_timer(0.06).timeout
	check(a.current_cue == "title", "title API chooses real title composition")
	a.start_ending()
	await create_timer(0.06).timeout
	check(a.current_cue == "ending" and not a.music_player.stream.loop, "ending API chooses actual one-shot reprise")
	a.set_level("6-6"); a.start_music(true)
	await create_timer(0.06).timeout
	check(a.current_cue == "final_boss", "rapid transitions retain final boss request")
	a.stop_music()
	check(not a.music_requested and a.music_player.stream == null and a.spare.stream == null, "stop releases both voices")
	check(a.effect_events("coin") == [["square",1320,1760,0.07,0.06,0]], "original coin SFX unchanged")
	check(a.effect_stream("coin") != null, "original effect resources retained")
	a.shutdown()
	check(a.score_cache.is_empty(), "shutdown clears score cache")
	a.queue_free(); await process_frame
	# Give the threaded mixer time to retire detached playback references.
	await create_timer(0.25).timeout
	print("Original score: ", checks, " checks, ", failures, " failures. Technical QA, not listening/device approval.")
	quit(0 if failures == 0 else 1)
