extends Node
var checks: int = 0
var failures: Array[String] = []
var results: Array = []
var app: Control

func _ready() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		print("FAIL: ", description)

func frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame

func prepare(index: int) -> void:
	app.begin_level(index)
	await frames(2)
	app.world.start()
	while app.world.sim_time < app.level_defs[index].freeze_at and app.world.state == RescueWorld.State.RUNNING:
		await get_tree().physics_frame
	if app.world.state == RescueWorld.State.RUNNING:
		app.world.freeze()
	await frames(2)

func run_to_outcome() -> void:
	for i in range(900):
		if app.world.state in [RescueWorld.State.SUCCESS, RescueWorld.State.FAILURE]:
			return
		await get_tree().physics_frame

func run() -> void:
	SaveData.test_mode = true
	SaveData.sound_enabled = false
	Sound.update_music()
	app = load("res://scenes/game.tscn").instantiate()
	add_child(app)
	await frames(3)
	check(app.screen == "title", "title screen starts")
	check(app.level_defs.size() == 12, "12 authored levels")
	for i in range(12):
		await prepare(i)
		var world: RescueWorld = app.world
		var level: LevelDefinition = app.level_defs[i]
		check(world.state == RescueWorld.State.FROZEN, "level %d can freeze" % (i + 1))
		var frozen = world.snapshot()
		await frames(25)
		check(world.snapshot() == frozen, "level %d freeze preserves positions, velocities and timers" % (i + 1))
		check(not world.resume(), "level %d resume requires placement" % (i + 1))
		check(world.place(level.solution_prop, level.solution_position), "level %d authored placement valid" % (i + 1))
		var previous_kind = world.prop_kind
		var previous_position = world.prop_position
		check(not world.place("umbrella", world.courier.position - Vector2(0, 90)), "level %d overlapping placement rejected" % (i + 1))
		check(world.prop_kind == previous_kind and world.prop_position == previous_position, "level %d invalid placement retains prior object" % (i + 1))
		check(world.resume(), "level %d resumes once" % (i + 1))
		check(not world.freeze(), "level %d cannot refreeze" % (i + 1))
		await run_to_outcome()
		var success = world.state == RescueWorld.State.SUCCESS
		check(success, "level %d authored solution rescues courier" % (i + 1))
		print("LEVEL %02d: %s courier=%s time=%.2f" % [i + 1, "PASS" if success else "FAIL", world.courier.position, world.sim_time])
		results.append({"level": i + 1, "solution_passed": success, "time": world.sim_time, "courier": str(world.courier.position)})
		if not success:
			print("  hazards=", world.snapshot().hazards)
		await prepare(i)
		world = app.world
		check(world.prop == null and not world.spring_used and world.sim_time < 0.6, "level %d retry resets mechanisms" % (i + 1))
		check(world.snapshot().hazards == frozen.hazards, "level %d retry reproduces hazard state" % (i + 1))
		check(world.place("umbrella", Vector2(650, 400)), "level %d incorrect but legal placement" % (i + 1))
		world.resume()
		await run_to_outcome()
		check(world.state == RescueWorld.State.FAILURE, "level %d misplaced object fails" % (i + 1))
	await prepare(0)
	check(app.world.place("umbrella", Vector2(320, 750)), "initial object placed")
	check(app.world.place("ramp", Vector2(500, 1020)), "player can replace object before resume")
	check(app.world.prop_kind == "ramp", "one selected object remains after replacement")
	app.show_settings(true)
	var paused_snapshot = app.world.snapshot()
	await frames(20)
	check(app.world.snapshot() == paused_snapshot, "pause overlay preserves frozen scene")
	app.close_overlay()
	check(not app.world.paused and app.overlay == null, "pause resumes cleanly")
	app.show_hint()
	app.show_hint()
	check(app.world.hint_marker, "second hint displays solution location")
	# Native pointer flow: select a prop and drag into stage.
	var press = InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = app.content.position + Vector2(120, 1350)
	app._input(press)
	check(app.dragging and app.selected == "umbrella", "touch selects prop")
	var second_finger = InputEventScreenTouch.new()
	second_finger.index = 1
	second_finger.pressed = false
	second_finger.position = app.content.position + Vector2(600, 600)
	app._input(second_finger)
	check(app.dragging, "second finger cannot interrupt active drag")
	var release = InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = app.content.position + Vector2(320, 750)
	app._input(release)
	check(not app.dragging and app.world.prop_kind == "umbrella", "touch release places prop")
	app._notification(NOTIFICATION_APPLICATION_PAUSED)
	check(app.overlay != null and app.world.paused, "backgrounding opens pause")
	app._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	check(app.overlay == null and not app.world.paused, "Android Back dismisses pause")
	var test_save = "res://build/test_progress.cfg"
	SaveData.unlocked = 7
	SaveData.completed = [0, 1, 5]
	SaveData.sound_enabled = false
	SaveData.haptics_enabled = false
	check(SaveData.save_progress(test_save) == OK, "save writes successfully")
	SaveData.unlocked = 1
	SaveData.completed = []
	SaveData.sound_enabled = true
	SaveData.haptics_enabled = true
	SaveData.load_progress(test_save)
	check(SaveData.unlocked == 7 and SaveData.completed == [0, 1, 5], "progress survives reload")
	check(not SaveData.sound_enabled and not SaveData.haptics_enabled, "settings survive reload")
	SaveData.unlocked = 1
	SaveData.completed = []
	for i in range(12):
		SaveData.finish_level(i)
	check(SaveData.unlocked == 12 and SaveData.completed.size() == 12, "all chapters unlock and completion bounded")
	app.show_levels()
	check(app.screen == "levels", "level select opens")
	app.show_title()
	check(app.screen == "title", "home returns to title")
	var output = {"checks": checks, "failures": failures, "levels": results, "status": "passed" if failures.is_empty() else "failed", "engine": Engine.get_version_info().string}
	var file = FileAccess.open("res://build/test_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	print("TEST_RESULT: %s (%d checks, %d failures)" % [output.status, checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

