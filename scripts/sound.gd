extends Node
var voices: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var voice_index: int = 0
var shutting_down: bool = false

func _ready() -> void:
	for i in range(6):
		var player = AudioStreamPlayer.new()
		add_child(player)
		voices.append(player)
	music = AudioStreamPlayer.new()
	music.volume_db = -21.0
	add_child(music)
	var path = "res://assets/audio/ambient.wav"
	if ResourceLoader.exists(path):
		music.stream = load(path)
		music.finished.connect(restart_music)
	update_music()

func restart_music() -> void:
	if not shutting_down and is_inside_tree() and SaveData.sound_enabled:
		music.play()

func shutdown() -> void:
	# Release playback before the AudioServer is torn down, including looping music.
	shutting_down = true
	for player in voices:
		player.stop()
		player.stream = null
	if is_instance_valid(music):
		music.stop()
		music.stream = null

func _exit_tree() -> void:
	shutdown()

func update_music() -> void:
	if shutting_down:
		return
	if SaveData.sound_enabled and music.stream and not music.playing:
		music.play()
	elif not SaveData.sound_enabled:
		music.stop()
		for voice in voices:
			voice.stop()

func play(cue: String, volume: float = -8.0) -> void:
	if shutting_down or not SaveData.sound_enabled or voices.is_empty():
		return
	var path = "res://assets/audio/%s.wav" % cue
	if not ResourceLoader.exists(path):
		return
	var player = voices[voice_index % voices.size()]
	voice_index += 1
	player.stream = load(path)
	player.volume_db = volume
	player.play()

func haptic(milliseconds: int = 30) -> void:
	if SaveData.haptics_enabled and OS.has_feature("android"):
		Input.vibrate_handheld(milliseconds)
