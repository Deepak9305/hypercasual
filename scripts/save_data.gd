extends Node
## Local-only progress. Test saves never touch the player's save.
const SAVE_PATH = "user://progress.cfg"
var unlocked: int = 1
var completed: Array = []
var sound_enabled: bool = true
var haptics_enabled: bool = true
var test_mode: bool = false

func _ready() -> void:
	test_mode = "--test" in OS.get_cmdline_user_args()
	if not test_mode:
		load_progress()

func load_progress(path: String = SAVE_PATH) -> void:
	var config = ConfigFile.new()
	if config.load(path) != OK:
		return
	unlocked = clampi(int(config.get_value("progress", "unlocked", 1)), 1, 12)
	completed = config.get_value("progress", "completed", [])
	sound_enabled = bool(config.get_value("settings", "sound", true))
	haptics_enabled = bool(config.get_value("settings", "haptics", true))

func save_progress(path: String = SAVE_PATH) -> Error:
	if test_mode and path == SAVE_PATH:
		return OK
	var config = ConfigFile.new()
	config.set_value("progress", "unlocked", unlocked)
	config.set_value("progress", "completed", completed)
	config.set_value("settings", "sound", sound_enabled)
	config.set_value("settings", "haptics", haptics_enabled)
	return config.save(path)

func finish_level(index: int) -> void:
	if index not in completed:
		completed.append(index)
	unlocked = maxi(unlocked, mini(index + 2, 12))
	save_progress()

