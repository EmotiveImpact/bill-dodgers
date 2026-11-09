extends SceneTree
const GameAudio = preload("res://src/game_audio.gd")
var failures := 0
var assertions := 0
func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pack="):
			if not ProjectSettings.load_resource_pack(argument.trim_prefix("--pack=")):
				printerr("Failed to mount exported audio pack")
				quit(1)
				return
	call_deferred("run")
func run() -> void:
	var audio := GameAudio.new()
	root.add_child(audio)
	var synth := GameAudio.new()
	synth.force_synthesis = true
	var prebuilt_count := 0
	for effect in ["coin","flower","bubble","plane","ball","sweet","pick","hitBot","pop","hurt","jump","throw","stomp","power","warn","win","select","honk","revive","firework"]:
		var stream: AudioStreamWAV = audio.effect_stream(effect)
		check(stream != null, effect + " exists")
		check(stream.mix_rate == 44100 and stream.data.size() > 4000, effect + " PCM frames")
		var peak := 0
		for i in stream.data.size() / 2:
			peak = maxi(peak, absi(stream.data.decode_s16(i * 2)))
		check(peak > 20 and peak < 32767, effect + " audible data without clipping")
		check(stream == audio.effect_stream(effect), effect + " cache reuse")
		if ResourceLoader.exists(GameAudio.PREBUILT_DIR + effect + ".res"):
			prebuilt_count += 1
			check(stream.data == synth.effect_stream(effect).data, effect + " prebuilt PCM exactly matches forced synthesis")
			check(stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, effect + " prebuilt effect never loops")
	# Source: game/3-3/index.html tone/noise definitions and the night firework call.
	# noise(dur, vol, freq, when): .05 is delay, not end gain or filter Q.
	check(GameAudio.EFFECT_NAMES.size() == 20, "19 original effects plus festival firework")
	var firework_events := audio.effect_events("firework")
	check(firework_events == [["sine",200,60,0.4,0.3,0],["noise",900,900,0.4,0.15,0.05]], "Exact source firework tone and delayed noise arguments")
	var firework: AudioStreamWAV = audio.effect_stream("firework")
	check(absf(firework.get_length() - 0.47) < 0.0001, "Firework includes 50ms noise delay and 20ms release tail")
	check(firework.data == synth._render(firework_events, 0.5).data, "Firework uses unchanged source renderer with master gain 0.5")
	var tone_only: AudioStreamWAV = synth._render([firework_events[0]], 0.5)
	var noise_only: AudioStreamWAV = synth._render([firework_events[1]], 0.5)
	var delay_bytes := int(round(0.05 * GameAudio.RATE)) * 2
	check(firework.data.slice(0, delay_bytes) == tone_only.data.slice(0, delay_bytes), "First 50ms contain only descending sine")
	var silent_prefix := PackedByteArray()
	silent_prefix.resize(delay_bytes)
	check(noise_only.data.slice(0, delay_bytes) == silent_prefix, "Noise has an exactly silent 50ms prefix")
	check(firework.data.slice(tone_only.data.size()) == noise_only.data.slice(tone_only.data.size()), "After sine stops only delayed noise remains")
	var noise_after_tone := 0
	for i in range(tone_only.data.size() / 2, firework.data.size() / 2):
		noise_after_tone = maxi(noise_after_tone, absi(firework.data.decode_s16(i * 2)))
	check(noise_after_tone > 0, "Delayed noise remains audible after the sine release")
	check(audio.effect_stream("unknown") == null, "Unknown names do not invent a sound")
	check(absf(audio.effect_stream("coin").get_length() - 0.09) < 0.0001, "Coin includes source 20ms release tail")
	check(absf(audio.effect_stream("win").get_length() - 0.90) < 0.0001, "Win keeps delayed seven-note phrase")
	for boss in [false, true]:
		var music: AudioStreamWAV = audio.music_stream(boss)
		check(music.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Looping music")
		var music_name := "music_boss" if boss else "music_normal"
		if ResourceLoader.exists(GameAudio.PREBUILT_DIR + music_name + ".res"):
			prebuilt_count += 1
			check(music.data == synth.music_stream(boss).data, "Prebuilt music PCM exactly matches forced synthesis")
			check(music.loop_end == music.data.size() / 2 and music.loop_begin == 0, "Prebuilt music loop points")
		check(absf(music.get_length() - 60.0 / (150 if boss else 138) / 4 * 128) < 0.0001, "Exact eight-bar source tempo")
	if OS.get_cmdline_user_args().has("--require-prebuilt"):
		check(prebuilt_count == 22, "All 22 native resources must be packaged")
		check(audio.noise_buffer.is_empty(), "Runtime prebuilt path performed no synchronous synthesis")
	check(audio.effect_stream("pickup") == audio.effect_stream("pick"), "Aliases reuse canonical stream")
	var cached_coin: AudioStreamWAV = audio.effect_stream("coin")
	audio.force_synthesis = true
	check(audio.effect_stream("coin") != cached_coin, "Forced synthesis bypasses previously loaded cache")
	check(audio.effect_stream("coin").data == synth.effect_stream("coin").data, "Forced synthesis matches source after switching mode")
	audio.force_synthesis = false
	synth.shutdown()
	synth.free()
	print("Prebuilt assets checked: %d/22 (missing files exercise fallback synthesis)" % prebuilt_count)
	audio.start_music()
	await create_timer(0.1).timeout
	check(audio.music_requested and audio.music_player.playing, "Music starts")
	audio.set_paused(true)
	check(audio.music_player.stream_paused, "Pause freezes music")
	audio.set_paused(false)
	check(not audio.music_player.stream_paused, "Resume music")
	audio.set_enabled(false)
	check(audio.music_player.stream_paused, "Sound off silences music")
	audio.play_effect("jump")
	check(not audio.effect_players[0].playing, "Muted effect suppressed")
	audio.set_enabled(true)
	audio.play_effect("jump")
	await process_frame
	check(audio.effect_players[0].playing, "Enabled effect starts")
	audio.set_paused(true)
	check(audio.effect_players[0].stream_paused, "Pause freezes effects too")
	audio.stop_music()
	check(not audio.music_requested and not audio.music_player.playing, "Music stops")
	audio.shutdown()
	check(audio.music_player.stream == null and audio.cache.is_empty(), "Shutdown releases music and cached streams")
	check(audio.effect_players[0].stream == null, "Shutdown releases effect streams")
	audio.queue_free()
	await create_timer(0.1).timeout
	print("Audio: %d assertions, %d failures (generated PCM and state checks; no audible/device QA)" % [assertions, failures])
	quit(1 if failures else 0)
