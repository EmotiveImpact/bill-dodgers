extends SceneTree
## Low-memory engine prerequisites for Web export. This is NOT a browser,
## IndexedDB, Web Audio, WebGL, Safari, or physical touchscreen acceptance test.
const Save = preload("res://src/save_store.gd")
const Touch = preload("res://src/touch_controls.gd")
const PartyInput = preload("res://src/party_input.gd")
const Audio = preload("res://src/original_score.gd")
const PATH := "user://web-runtime-fixture.json"
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)

func run() -> void:
	# FileAccess/DirAccess atomic replacement works in the virtual filesystem;
	# only the exported browser can prove that it syncs into persistent IndexedDB.
	check(Save.PATH.begins_with("user://") and not "bd-save" in Save.PATH, "preview save is app-local and separate from original browser save")
	var first := {"schema": 1, "receipts": {"1-1": [0]}, "cleared": {"1-1": true}, "skills": [], "friend": "jp", "kitty": 10}
	check(Save.write_save(first, PATH) == OK, "fresh virtual-filesystem save")
	check(Save.read_save(PATH).kitty == 10, "fresh saved value readable")
	var second := first.duplicate(true)
	second.kitty = 27
	second.friend = "maya"
	check(Save.write_save(second, PATH) == OK, "same-path atomic replacement")
	var reopened := Save.read_save(PATH)
	check(reopened.kitty == 27 and reopened.friend == "maya" and reopened.receipts["1-1"] == [0], "replacement retains exact progress")
	check(not FileAccess.file_exists(PATH + ".tmp"), "successful rename leaves no temporary save")
	check(Save.write_save(first, "user://web-fixture-missing-parent/save.json") != OK, "missing destination parent reports failure")
	check(Save.read_save(PATH).kitty == 27, "unrelated write failure leaves prior save intact")
	var corrupt := FileAccess.open(PATH, FileAccess.WRITE)
	corrupt.store_string('{"schema":'); corrupt.close()
	check(Save.read_save(PATH) == {"schema": 1, "receipts": {}}, "interrupted malformed save safely defaults")
	check(Save.write_save(second, PATH) == OK and Save.read_save(PATH).kitty == 27, "write repairs invalid fixture without external storage")
	DirAccess.remove_absolute(PATH)
	# Coordinates here are canvas-local. CSS safe-area bounds must be applied by
	# the Web shell BEFORE canvas scaling; this does not prove Safari env values.
	for visible in [Vector2(960, 540), Vector2(844, 390), Vector2(568, 320), Vector2(390, 844)]:
		var scale := minf(visible.x / 960, visible.y / 540)
		var layout := Touch.layout(Vector2(960, 540), Vector2(18, 14), true)
		var bounds := Rect2(Vector2.ZERO, Vector2(960, 540))
		check(bounds.encloses(layout.pad), "pad stays inside logical canvas " + str(visible))
		for action in ["jump", "shoot", "special", "dash"]:
			var rect: Rect2 = layout.buttons[action]
			check(bounds.encloses(rect) and not rect.intersects(layout.pad), "action separate from steering " + str(visible) + "/" + action)
			# Portrait requires the shell's rotate guidance. Do not pretend a
			# letterboxed 390px-wide landscape canvas has full-size phone targets.
			if visible.x > visible.y: check(rect.size.x * scale >= 44 and rect.size.y * scale >= 44, "reference landscape target at least44 CSSpx " + str(visible) + "/" + action)
	var input := PartyInput.new()
	var touching := {"right": true, "shoot": true, "jump": true}
	var p1: Dictionary = input.from_snapshot(0, "p2", {}, touching)
	var p2: Dictionary = input.from_snapshot(1, "p2", {}, touching)
	check(p1.right and p1.shoot and p1.jump, "P1 simultaneous touch actions")
	check(not p2.right and not p2.shoot and not p2.jump, "touch never silently becomes player2 controls")
	input.release_all()
	check(not input.from_snapshot(0, "p2", {}, touching).right, "focus/pause suppression blocks held touch")
	input.from_snapshot(0, "p2")
	check(input.from_snapshot(0, "p2", {}, touching).right, "neutral then fresh input rearms")
	# Prebuilt resources avoid synchronous procedural generation on the iPhone
	# browser's main thread. Playback state here uses the native dummy driver.
	var audio := Audio.new()
	root.add_child(audio)
	audio.set_process(false)
	for cue in Audio.CUES: check(audio.score_stream(cue) != null, "prebuilt compressed score exists: " + cue)
	for effect in audio.EFFECT_NAMES: check(audio.effect_stream(effect) != null, "prebuilt effect exists: " + effect)
	check(audio.noise_buffer.is_empty(), "normal effect resource path performed no synthesis")
	audio.start_title()
	await create_timer(0.06).timeout
	check(audio.music_requested and audio.current_cue == "title", "title audio requested")
	audio.start_music(false)
	await create_timer(0.06).timeout
	check(audio.music_player.playing and audio.spare.playing, "both crossfade channels have active playback")
	audio.set_paused(true)
	check(audio.music_player.stream_paused and audio.spare.stream_paused, "both crossfade channels pause")
	audio.set_paused(false)
	audio.set_enabled(false)
	check(audio.music_player.stream_paused and audio.spare.stream_paused, "sound-off remains effective after resume")
	audio.set_enabled(true)
	check(not audio.music_player.stream_paused and not audio.spare.stream_paused, "sound-on resumes both channels")
	audio.shutdown()
	check(audio.score_cache.is_empty() and audio.cache.is_empty() and audio.music_player.stream == null and audio.spare.stream == null, "audio shutdown releases streams/caches")
	audio.queue_free()
	await create_timer(0.25).timeout
	print("Web runtime foundation: %d checks, %d failures. Native engine prerequisites only; browser/device acceptance remains separate." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
