extends Node
## Rescue campaign uses its own save section so the original campaign is retained.
const SAVE_PATH = "user://progress.cfg"
const REPLAY_DIR = "user://replays"
var unlocked: int = 1
var completed: Array = []
var records: Dictionary = {}
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
	unlocked = clampi(int(config.get_value("rescue_sequences", "unlocked", 1)), 1, Levels.all().size())
	completed = config.get_value("rescue_sequences", "completed", [])
	records = config.get_value("rescue_sequences", "records", {})
	sound_enabled = bool(config.get_value("settings", "sound", true))
	haptics_enabled = bool(config.get_value("settings", "haptics", true))

func save_progress(path: String = SAVE_PATH) -> Error:
	if test_mode and path == SAVE_PATH:
		return OK
	var config = ConfigFile.new()
	if FileAccess.file_exists(path):
		config.load(path)
	config.set_value("rescue_sequences", "unlocked", unlocked)
	config.set_value("rescue_sequences", "completed", completed)
	config.set_value("rescue_sequences", "records", records)
	config.set_value("settings", "sound", sound_enabled)
	config.set_value("settings", "haptics", haptics_enabled)
	return config.save(path)

func finish_level(index: int) -> void:
	if index not in completed:
		completed.append(index)
	unlocked = maxi(unlocked, mini(index + 2, Levels.all().size()))
	save_progress()

func plan_signature(plan: Dictionary) -> String:
	var parts: Array[String] = []
	var keys = plan.keys()
	keys.sort()
	for kind in keys:
		var data: Dictionary = plan[kind]
		parts.append("%s:%d:%d:%d" % [kind, roundi(data.position.x / 40), roundi(data.position.y / 40), data.direction])
	return ";".join(parts)

func replay_path(id_: String) -> String:
	return ("res://build/test_replays" if test_mode else REPLAY_DIR) + "/" + id_.validate_filename() + ".replay"

func record_rescue(id_: String, data: Dictionary) -> Dictionary:
	var record: Dictionary = records.get(id_, {"signatures": [], "few_tools": false, "all_parcels": false, "different_solution": false})
	var signature = plan_signature(data.plan)
	var different = not record.signatures.is_empty() and signature not in record.signatures
	if signature not in record.signatures:
		record.signatures.append(signature)
	var goals: Dictionary = data.goals.duplicate(true)
	goals["different_solution"] = different
	for key in ["few_tools", "all_parcels", "different_solution"]:
		record[key] = record.get(key, false) or goals.get(key, false)
	records[id_] = record
	data.goals = goals
	var path = replay_path(id_)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_var(data, false)
	save_progress()
	return goals

func has_replay(id_: String) -> bool:
	return FileAccess.file_exists(replay_path(id_))

func load_replay(id_: String) -> Dictionary:
	var file = FileAccess.open(replay_path(id_), FileAccess.READ)
	if not file:
		return {}
	var data = file.get_var(false)
	if data is Dictionary and data.get("version", 0) == 1 and data.get("level_id", "") == id_:
		return data
	return {}
