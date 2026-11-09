extends RefCounted
## Deterministic simulation suites use a silent adapter. Real synthesis and mixer
## scheduling are covered independently by test_audio and the UI smoke suite.
class SilentAudio extends RefCounted:
	var enabled := false
	var paused := false
	var music_requested := false
	func set_enabled(value: bool) -> void: enabled = value
	func set_paused(value: bool) -> void: paused = value
	func play_effect(_effect: String) -> void: pass
	func start_music(_boss: bool = false) -> void: music_requested = true
	func stop_music() -> void: music_requested = false
	func shutdown() -> void: pass

static func silence(game) -> void:
	game.audio.shutdown()
	game.audio.queue_free()
	game.audio = SilentAudio.new()
