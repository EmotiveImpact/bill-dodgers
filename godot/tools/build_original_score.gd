extends SceneTree
## Wrap composed Vorbis data in self-contained native resources. No editor import,
## network, synthesis or hidden original MP3 dependency is needed at runtime.
const CUES := ["title", "world1", "world2", "world3", "world4", "world5", "world6", "boss", "final_boss", "bonus", "victory", "select", "map", "story", "cutscene", "party", "gameover", "ending"]
func _initialize() -> void:
	var failures := 0
	for cue in CUES:
		var base: String = "res://assets/music/" + cue
		var stream := AudioStreamOggVorbis.load_from_file(base + ".ogg")
		if stream == null:
			push_error("Missing composed score: " + base)
			failures += 1
			continue
		stream.loop = cue not in ["victory", "gameover", "ending"]
		stream.loop_offset = 0
		stream.resource_name = "Bill Dodgers original score: " + cue
		var error := ResourceSaver.save(stream, base + ".res")
		if error != OK:
			push_error("Could not save score: " + base)
			failures += 1
	print("Original soundtrack: ", CUES.size(), " native resources, ", failures, " failures")
	quit(0 if failures == 0 else 1)
