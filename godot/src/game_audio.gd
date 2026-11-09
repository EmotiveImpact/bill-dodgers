extends Node
## Native synthesis of procedural audio in game/1-1 and game/3-3/index.html.
## Streams contain source master gain (0.5); music additionally uses 0.22.
const RATE := 44100
const EFFECT_NAMES := ["coin", "flower", "bubble", "plane", "ball", "sweet", "pick", "hitBot", "pop", "hurt", "jump", "throw", "stomp", "power", "warn", "win", "select", "honk", "revive", "firework"]
const PREBUILT_DIR := "res://assets/audio/"
## Offline builders/tests set this before requesting streams, bypassing prebuilt files.
var force_synthesis := false
const BASS := [36, 45, 41, 43]
const BPAT := [0, 0, 7, 12, 0, 0, 7, 12]
const LEAD := [
	[72,-1,76,-1,79,-1,76,-1,84,-1,79,-1,76,-1,74,-1],
	[72,-1,69,-1,72,-1,76,-1,81,-1,-1,-1,79,-1,76,-1],
	[77,-1,76,-1,74,-1,72,-1,69,-1,72,-1,77,-1,-1,-1],
	[79,-1,77,-1,76,-1,74,-1,71,-1,74,-1,79,-1,83,-1],
	[76,-1,79,-1,84,-1,83,-1,81,-1,79,-1,76,-1,79,-1],
	[81,-1,79,-1,76,-1,72,-1,76,-1,-1,-1,72,-1,69,-1],
	[77,-1,81,-1,84,-1,81,-1,79,-1,77,-1,76,-1,74,-1],
	[74,-1,76,-1,77,-1,79,-1,83,-1,-1,-1,86,-1,-1,-1],
]
var enabled := true
var paused := false
var music_requested := false
var boss_music := false
var music_player: AudioStreamPlayer
var effect_players: Array[AudioStreamPlayer] = []
var cache: Dictionary = {}
var noise_buffer := PackedFloat32Array()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	for i in 24:
		var player := AudioStreamPlayer.new()
		add_child(player)
		effect_players.append(player)

func shutdown() -> void:
	# Resume before stopping: paused playback must reach the mixer stop path.
	music_requested = false
	if is_instance_valid(music_player):
		music_player.stream_paused = false
		music_player.stop()
		music_player.stream = null
	for player in effect_players:
		if is_instance_valid(player):
			player.stream_paused = false
			player.stop()
			player.stream = null
	cache.clear()
	noise_buffer.clear()

func _exit_tree() -> void:
	shutdown()

func set_enabled(value: bool) -> void:
	enabled = value
	_sync_pause()

func set_paused(value: bool) -> void:
	paused = value
	_sync_pause()

func _sync_pause() -> void:
	if music_player:
		music_player.stream_paused = paused or not enabled
	for player in effect_players:
		player.stream_paused = paused or not enabled

func play_effect(effect: String) -> void:
	if not enabled or paused:
		return
	var stream := effect_stream(effect)
	if stream == null:
		return
	for player in effect_players:
		if not player.playing:
			player.stream = stream
			player.play()
			return
	# Bound polyphony so sustained rapid fire cannot allocate unlimited nodes.
	effect_players[0].stream = stream
	effect_players[0].play()

func start_music(boss: bool = false) -> void:
	if music_requested and boss_music == boss:
		return
	music_requested = true
	boss_music = boss
	if music_player:
		music_player.stream = music_stream(boss)
		music_player.play()
		_sync_pause()

func stop_music() -> void:
	music_requested = false
	if music_player:
		music_player.stream_paused = false
		music_player.stop()
		music_player.stream = null

# Event format: waveform, start frequency, end frequency, duration, volume, delay.
func effect_events(effect: String) -> Array:
	match effect:
		"coin": return [["square",1320,1760,0.07,0.06,0]]
		"flower": return [["triangle",700,980,0.08,0.12,0]]
		"bubble": return [["sine",380,900,0.09,0.16,0]]
		"plane": return [["noise",2400,2400,0.1,0.12,0],["triangle",900,500,0.08,0.05,0]]
		"ball": return [["square",180,90,0.08,0.14,0],["noise",700,700,0.05,0.12,0]]
		"sweet": return [["triangle",1100,1600,0.05,0.09,0],["noise",4200,4200,0.07,0.06,0.03]]
		"pick", "pickup": return [["square",988,988,0.05,0.07,0],["square",1319,1319,0.12,0.07,0.05]]
		"hitBot", "hit_bot", "hit": return [["noise",900,900,0.06,0.18,0]]
		"pop": return [["square",320,70,0.22,0.12,0],["noise",600,600,0.18,0.22,0]]
		"hurt": return [["sawtooth",420,90,0.3,0.14,0]]
		"jump": return [["square",330,660,0.12,0.06,0]]
		"throw": return [["noise",3000,3000,0.08,0.08,0]]
		"stomp": return [["sine",90,40,0.35,0.5,0],["noise",200,200,0.3,0.3,0]]
		"power": return _arpeggio([523,659,784,1047],0.1,"square",0.08,0.07)
		"warn", "boss": return [["square",880,660,0.18,0.08,0],["square",880,660,0.18,0.08,0.4],["square",880,660,0.18,0.08,0.8],["square",880,660,0.18,0.08,1.2]]
		"win": return _arpeggio([523,659,784,1047,784,1047,1319],0.16,"square",0.09,0.12)
		"select": return [["square",660,990,0.06,0.07,0]]
		"honk": return [["square",370,360,0.22,0.09,0],["square",466,455,0.22,0.07,0],["square",370,360,0.22,0.09,0.32],["square",466,455,0.22,0.07,0.32]]
		# game/3-3/index.html: noise fourth argument is a 50ms start delay.
		"firework": return [["sine",200,60,0.4,0.3,0],["noise",900,900,0.4,0.15,0.05]]
		"revive": return _arpeggio([392,523,659,784],0.1,"triangle",0.12,0.06)
	return []

func _arpeggio(notes: Array, duration: float, waveform: String, volume: float, spacing: float) -> Array:
	var events: Array = []
	for i in notes.size():
		events.append([waveform,notes[i],notes[i],duration,volume,i * spacing])
	return events

func _canonical_effect(effect: String) -> String:
	match effect:
		"pickup": return "pick"
		"hit_bot", "hit": return "hitBot"
		"boss": return "warn"
	return effect

func _prebuilt_stream(key: String, looping: bool = false) -> AudioStreamWAV:
	var path := PREBUILT_DIR + key + ".res"
	if force_synthesis or not ResourceLoader.exists(path):
		return null
	# Native resources retain PCM and loop metadata in both workspace and exports.
	# Raw WAV imports can be recompressed/remapped by the editor and are not used.
	var stream := ResourceLoader.load(path, "AudioStreamWAV") as AudioStreamWAV
	if stream == null or stream.format != AudioStreamWAV.FORMAT_16_BITS or stream.mix_rate != RATE or stream.stereo:
		push_warning("Invalid prebuilt audio: " + path + "; using synthesis")
		return null
	var expected_loop := AudioStreamWAV.LOOP_FORWARD if looping else AudioStreamWAV.LOOP_DISABLED
	if stream.loop_mode != expected_loop or (looping and (stream.loop_begin != 0 or stream.loop_end != stream.data.size() / 2)):
		push_warning("Invalid prebuilt loop metadata: " + path + "; using synthesis")
		return null
	return stream

func effect_stream(effect: String) -> AudioStreamWAV:
	var canonical := _canonical_effect(effect)
	if not EFFECT_NAMES.has(canonical):
		return null
	var key := ("synth:" if force_synthesis else "") + canonical
	if not cache.has(key):
		var stream := _prebuilt_stream(canonical)
		if stream == null:
			stream = _render(effect_events(canonical), 0.5)
		cache[key] = stream
	return cache[key] as AudioStreamWAV

func music_stream(boss: bool = false) -> AudioStreamWAV:
	var name := "music_boss" if boss else "music_normal"
	var key := ("synth:" if force_synthesis else "") + name
	if cache.has(key):
		return cache[key] as AudioStreamWAV
	var prebuilt := _prebuilt_stream(name, true)
	if prebuilt != null:
		cache[key] = prebuilt
		return prebuilt
	var step := 60.0 / (150.0 if boss else 138.0) / 4.0
	var shift := -1 if boss else 0
	var events: Array = []
	for index in 128:
		var bar := index / 16
		var beat := index % 16
		var when := index * step
		if beat % 2 == 0:
			var frequency := _midi(BASS[bar % 4] + BPAT[beat / 2] + shift)
			events.append(["triangle",frequency,frequency,step * 1.8,0.32,when])
		if LEAD[bar][beat] > 0:
			var frequency := _midi(LEAD[bar][beat] + shift)
			events.append(["square",frequency,frequency,step * 1.7,0.07,when])
		if beat % 4 == 0:
			events.append(["sine",150,45,0.12,0.5,when])
		if beat % 2 == 1:
			events.append(["noise",7000,7000,0.03,0.05,when])
		if beat == 4 or beat == 12:
			events.append(["noise",1800,1800,0.09,0.12,when])
	cache[key] = _render(events, 0.5 * 0.22, step * 128)
	return cache[key] as AudioStreamWAV

func _midi(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)

func _render(events: Array, gain: float, loop_seconds: float = 0.0) -> AudioStreamWAV:
	var duration := loop_seconds
	if duration == 0.0:
		for event in events:
			duration = maxf(duration, event[5] + event[3] + 0.02)
	var samples := PackedFloat32Array()
	samples.resize(int(ceil(duration * RATE)))
	if noise_buffer.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 1101
		noise_buffer.resize(RATE / 2)
		for i in noise_buffer.size():
			noise_buffer[i] = rng.randf_range(-1, 1)
	for event in events:
		_mix_event(samples, event, gain, loop_seconds > 0)
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	if loop_seconds > 0:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream

func _mix_event(samples: PackedFloat32Array, event: Array, gain: float, wrap: bool) -> void:
	var waveform: String = event[0]
	var f0: float = event[1]
	var f1: float = maxf(20, event[2])
	var duration: float = event[3]
	var volume: float = event[4]
	var offset := int(round(float(event[5]) * RATE))
	var phase := 0.0
	# Web Audio bandpass defaults to Q=1 (RBJ constant-peak-gain form).
	var omega := TAU * f0 / RATE
	var alpha := sin(omega) / 2.0
	var b0 := alpha / (1 + alpha)
	var a1 := -2 * cos(omega) / (1 + alpha)
	var a2 := (1 - alpha) / (1 + alpha)
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in int(ceil((duration + 0.02) * RATE)):
		var t := float(i) / RATE
		var ramp := minf(t / duration, 1.0)
		var amplitude := volume * pow(0.001 / volume, ramp) * gain
		var value := 0.0
		match waveform:
			"sine": value = sin(TAU * phase)
			"square": value = 1.0 if phase < 0.5 else -1.0
			"triangle": value = 2.0 / PI * asin(sin(TAU * phase))
			"sawtooth": value = 2.0 * (phase - floor(phase + 0.5))
			"noise":
				var x := float(noise_buffer[i % noise_buffer.size()])
				value = b0 * x - b0 * x2 - a1 * y1 - a2 * y2
				x2 = x1
				x1 = x
				y2 = y1
				y1 = value
		var target := offset + i
		if wrap:
			target %= samples.size()
		if target < samples.size():
			samples[target] += value * amplitude
		phase = fmod(phase + f0 * pow(f1 / f0, ramp) / RATE, 1.0)
