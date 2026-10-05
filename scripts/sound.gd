extends Node
var voices: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var voice_index: int = 0

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
		music.finished.connect(func():
			if SaveData.sound_enabled:
				music.play())
	update_music()

func update_music() -> void:
	if SaveData.sound_enabled and music.stream and not music.playing:
		music.play()
	elif not SaveData.sound_enabled:
		music.stop()
		for voice in voices:
			voice.stop()

func play(cue: String, volume: float = -8.0) -> void:
	if not SaveData.sound_enabled or voices.is_empty():
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

