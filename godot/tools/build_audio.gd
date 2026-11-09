extends SceneTree
## Build deterministic source synthesis without requiring editor-imported assets.
const GameAudio = preload("res://src/game_audio.gd")

func _initialize() -> void:
	var audio := GameAudio.new()
	# Always regenerate all 20 effects (including the festival firework) and
	# two music loops from definitions, even when prior resources are present.
	audio.force_synthesis = true
	var destination := ProjectSettings.globalize_path(GameAudio.PREBUILT_DIR)
	var error := DirAccess.make_dir_recursive_absolute(destination)
	if error != OK:
		printerr("Cannot create audio output directory: ", error)
		audio.free()
		quit(1)
		return
	var failures := 0
	var count := 0
	for effect in GameAudio.EFFECT_NAMES:
		error = _save_stream(audio.effect_stream(effect), destination, effect)
		if error != OK:
			printerr("Cannot save ", effect, ": ", error)
			failures += 1
		else:
			count += 1
	for boss in [false, true]:
		var name := "music_boss" if boss else "music_normal"
		error = _save_stream(audio.music_stream(boss), destination, name)
		if error != OK:
			printerr("Cannot save ", name, ": ", error)
			failures += 1
		else:
			count += 1
	audio.shutdown()
	audio.free()
	print("Built %d native source PCM resources; %d failures" % [count, failures])
	quit(0 if failures == 0 else 1)

func _save_stream(stream: AudioStreamWAV, destination: String, name: String) -> Error:
	var error := ResourceSaver.save(stream, destination.path_join(name + ".res"))
	if error != OK:
		return error
	# Remove only this builder's known, reproducible legacy output after success.
	for suffix in [".wav", ".wav.import"]:
		var stale := destination.path_join(name + suffix)
		if FileAccess.file_exists(stale):
			error = DirAccess.remove_absolute(stale)
			if error != OK:
				printerr("Cannot remove stale generated audio: ", stale)
				return error
	return OK
