extends SceneTree
## Build a minimal pack containing only 18 native score resources, this verifier
## and project settings. Then run it from an EMPTY directory with --main-pack.
const CUES := ["title", "world1", "world2", "world3", "world4", "world5", "world6", "boss", "final_boss", "bonus", "victory", "select", "map", "story", "cutscene", "party", "gameover", "ending"]
var checks := 0
var failures := 0
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(description)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--build-pack="):
			build_pack(arg.trim_prefix("--build-pack=")); return
	for cue in CUES:
		var stream := load("res://assets/music/" + cue + ".res") as AudioStreamOggVorbis
		check(stream != null, cue + " self-contained native resource")
		if stream == null: continue
		check(stream.get_length() > 5, cue + " encoded duration")
		check(stream.loop == (cue not in ["ending","victory","gameover"]), cue + " loop flag survives pack")
		var playback := stream.instantiate_playback(); playback.start()
		var samples := playback.mix_audio(1.0, 4096)
		var energy := 0.0
		for sample in samples: energy += sample.length_squared()
		check(samples.size() == 4096 and energy > 0 and is_finite(energy), cue + " packaged data decodes without original OGG")
		playback.stop()
		if OS.get_cmdline_user_args().has("--isolated"):
			check(not FileAccess.file_exists("res://assets/music/" + cue + ".ogg"), cue + " source OGG truly absent")
	if OS.get_cmdline_user_args().has("--isolated"):
		check(not FileAccess.file_exists("res://assets/music/score_manifest.json"), "source manifest truly absent")
		check(not FileAccess.file_exists("res://src/original_score.gd"), "project source truly absent")
	print("Original score isolated pack: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
func build_pack(path: String) -> void:
	var p := PCKPacker.new()
	check(p.pck_start(path) == OK, "pack opens")
	var settings := FileAccess.open("user://score_pack_project.cfg", FileAccess.WRITE)
	settings.store_string("config_version=5\n[application]\nconfig/name=\"Isolated score verification\"\n[rendering]\nrenderer/rendering_method=\"gl_compatibility\"\n")
	settings.close()
	check(p.add_file("res://project.godot", ProjectSettings.globalize_path("user://score_pack_project.cfg")) == OK, "pack project settings")
	check(p.add_file("res://tests/test_original_score_pack.gd", ProjectSettings.globalize_path("res://tests/test_original_score_pack.gd")) == OK, "pack verifier script")
	for cue in CUES:
		var source: String = "res://assets/music/" + cue + ".res"
		check(p.add_file(source, ProjectSettings.globalize_path(source)) == OK, "pack cue " + cue)
	check(p.flush() == OK, "pack flush")
	print("Built isolated18-cue score pack; ", failures, " failures")
	quit(0 if failures == 0 else 1)
