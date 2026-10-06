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
	while app.world.state == RescueWorld.State.RUNNING and app.world.sim_time < app.level_defs[index].freeze_at:
		await frames(1)
	if app.world.state == RescueWorld.State.RUNNING:
		app.world.freeze()
	await frames(2)

func plan(level: LevelDefinition, offset: float = 0.0) -> void:
	for tool in level.solution:
		check(app.world.place(tool.kind, tool.position + Vector2(offset, 0), tool.direction), "%s: %s placement valid (%s)" % [level.title, tool.kind, offset])

func run_to_outcome() -> void:
	for i in range(950):
		if app.world.state in [RescueWorld.State.SUCCESS, RescueWorld.State.FAILURE]:
			return
		await frames(1)

func run() -> void:
	SaveData.test_mode = true
	SaveData.sound_enabled = false
	Sound.update_music()
	app = load("res://scenes/game.tscn").instantiate()
	add_child(app)
	await frames(3)
	check(app.level_defs.size() == 8, "four lessons followed by four chains")
	for i in range(app.level_defs.size()):
		await prepare(i)
		var world: RescueWorld = app.world
		var level: LevelDefinition = app.level_defs[i]
		var frozen = world.snapshot()
		await frames(15)
		check(world.snapshot() == frozen, "%s: frozen physics stays still" % level.title)
		check(not world.resume(), "%s: empty plan cannot resume" % level.title)
		plan(level)
		var placements = world.placements.duplicate(true)
		check(not world.place(level.solution[0].kind, world.courier.position - Vector2(0, 90)), "%s: overlap rejected" % level.title)
		check(world.placements == placements, "%s: invalid edit preserves whole plan" % level.title)
		check(world.resume(), "%s: plan resumes" % level.title)
		await run_to_outcome()
		var success = world.state == RescueWorld.State.SUCCESS
		check(success, "%s: authored chain rescues courier" % level.title)
		print("LEVEL %d: %s at %.2f courier=%s reason=%s" % [i + 1, "PASS" if success else "FAIL", world.sim_time, world.courier.position, world.failure_reason])
		print("  hazards=", world.snapshot().hazards, " events=", world.events)
		results.append({"level": level.title, "passed": success, "time": world.sim_time, "events": world.events})
		check(world.rewind_plan(), "%s: rewind restores frozen moment" % level.title)
		check(world.placements == placements, "%s: rewind keeps all placements and directions" % level.title)
		var rewound = world.snapshot()
		check(rewound.time == frozen.time and rewound.hazards == frozen.hazards and rewound.courier == frozen.courier and rewound.velocity == frozen.velocity, "%s: rewind restores positions velocities and hazard timers" % level.title)
		check(not world.spring_used and world.events.is_empty(), "%s: rewind resets triggers and chain log" % level.title)
		# An incomplete chain must fail even when its first intervention works.
		if i >= 4:
			if i == 4:
				world.place("umbrella", level.solution[0].position, 4)
			elif i == 6:
				world.place("fan", level.solution[0].position, 4)
			else:
				world.remove_tool("crate")
			world.resume()
			await run_to_outcome()
			check(world.state == RescueWorld.State.FAILURE, "%s: broken chain fails" % level.title)
			check(world.failure_position != Vector2.ZERO and not world.events.is_empty(), "%s: failure identifies cause and location" % level.title)
	# Nearby placements must work outside the exact hint marker.
	for i in [4, 5, 6, 7]:
		for offset in [-12.0, 12.0]:
			await prepare(i)
			plan(app.level_defs[i], offset)
			app.world.resume()
			await run_to_outcome()
			check(app.world.state == RescueWorld.State.SUCCESS, "%s: nearby plan %s succeeds" % [app.level_defs[i].title, offset])
	# Cross-tool physics uses the same moving crate as a hazard and as a placed tool.
	var sandbox = LevelDefinition.new()
	sandbox.id = "sandbox"
	sandbox.tool_budget = 3
	sandbox.timeout = 20
	sandbox.courier_speed = 0
	app.world.reset(sandbox, 0)
	app.world.start()
	app.world.freeze()
	check(app.world.place("crate", Vector2(400, 900)), "placed crate starts above spring")
	check(app.world.place("spring", Vector2(400, 1020)), "spring fits beneath crate")
	app.world.resume()
	await frames(50)
	check(app.world.tool_nodes.crate.deflected and app.world.tool_nodes.crate.position.y < 900, "spring launches another tool")
	app.world.reset(sandbox, 0)
	app.world.start()
	app.world.freeze()
	app.world.place("crate", Vector2(400, 800))
	app.world.place("fan", Vector2(200, 820))
	app.world.resume()
	await frames(20)
	check(app.world.tool_nodes.crate.position.x > 420, "fan pushes placed crate")
	# A redirected loose parcel must still be able to hit the courier.
	var danger = LevelDefinition.new()
	danger.id = "danger"
	danger.courier_speed = 0
	danger.hazards.append(Levels.hazard("crate", Vector2(320, 750)))
	app.world.reset(danger, 0)
	app.world.start()
	app.world.freeze()
	app.world.place("fan", Vector2(600, 350))
	app.world.actors[0].redirect("umbrella", 4)
	check(app.world.actors[0].collision_mask & 4 != 0, "redirect retains courier collision mask")
	app.world.resume()
	await run_to_outcome()
	check(app.world.state == RescueWorld.State.FAILURE and app.world.failure_reason.contains("redirected"), "redirected parcel can injure courier")
	# Removing a weight must close its gate again.
	await prepare(3)
	plan(app.level_defs[3])
	app.world.resume()
	await frames(40)
	check(app.world.mechanisms[1].active, "weighted gate opens")
	app.world.tool_nodes.crate.position.x = 700
	await frames(2)
	check(not app.world.mechanisms[1].active, "gate closes when crate leaves plate")
	await prepare(5)
	app.world.place("umbrella", app.level_defs[5].solution[0].position, 4)
	app.world.resume()
	await run_to_outcome()
	check(app.world.state == RescueWorld.State.SUCCESS and app.world.last_goals.few_tools, "Fragile Delivery permits a fewer-tools solution")
	check(not app.world.last_goals.all_parcels, "discarding a parcel trades away protection goal")
	# Pausing, touch, saved results, replay and goals exercise the complete app.
	await prepare(5)
	plan(app.level_defs[5])
	check(not app.world.place("fan", Vector2(200, 500)), "tool budget rejects additional tool")
	app.world.turn_tool("umbrella")
	check(app.world.placements.umbrella.direction == 4, "turn edits an already placed tool")
	app.world.turn_tool("umbrella")
	app.show_settings(true)
	var paused = app.world.snapshot()
	await frames(20)
	check(app.world.snapshot() == paused, "pause preserves physics")
	app.close_overlay()
	app.show_hint()
	app.show_hint()
	check(app.world.hint_marker, "second hint highlights chain start")
	app.world.resume()
	await run_to_outcome()
	await get_tree().create_timer(0.8).timeout
	check(app.overlay != null, "successful chain opens results")
	var saved = SaveData.load_replay("fragile")
	check(not saved.is_empty() and saved.frames.size() > 50, "rescue replay saved with motion frames")
	check(saved.get("frames", []).any(func(f): return f.get("focus_life", 0) > 0), "saved replay retains impact tracking")
	check(saved.get("events", []).any(func(e): return e.text == "CAUGHT!"), "saved replay contains catching event")
	app.watch_saved_replay(5)
	check(app.screen == "replay" and app.world.watching_replay, "saved replay starts from result")
	await frames(15)
	check(app.world.playback_index > 0, "replay advances")
	# A slightly changed successful plan earns the different solution goal.
	await prepare(4)
	check(app.world.place("umbrella", Vector2(330, 720), 4), "alternative umbrella points left")
	check(app.world.place("crate", Vector2(555, 820)), "alternative crate holds the raised switch")
	app.world.resume()
	await run_to_outcome()
	check(app.world.state == RescueWorld.State.SUCCESS, "alternative tool combination succeeds")
	check(app.world.last_goals.get("different_solution", false), "a different successful plan earns optional goal")
	# Real touch ownership and direct manipulation of existing tools.
	await prepare(5)
	plan(app.level_defs[5])
	var press = InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = app.content.position + app.world.placements.crate.position * app.content.scale
	app._input(press)
	check(app.dragging and app.selected == "crate", "touch picks existing tool for edit")
	var second = InputEventScreenTouch.new()
	second.index = 1
	second.pressed = false
	second.position = press.position
	app._input(second)
	check(app.dragging, "second finger does not cancel drag")
	var release = InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = press.position + Vector2(8, 0) * app.content.scale
	app._input(release)
	check(not app.dragging and app.world.placements.size() == 2, "touch edits tool without deleting other placements")
	app._notification(NOTIFICATION_APPLICATION_PAUSED)
	check(app.world.paused and app.overlay != null, "backgrounding pauses")
	app._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not app.world.paused and app.overlay == null, "Back dismisses pause")
	# Old campaign data must remain available while the new campaign starts at one.
	var config = ConfigFile.new()
	config.set_value("progress", "unlocked", 12)
	config.set_value("progress", "completed", [0, 1, 2])
	config.set_value("settings", "sound", false)
	config.save("res://build/test_progress.cfg")
	SaveData.load_progress("res://build/test_progress.cfg")
	check(SaveData.unlocked == 1 and SaveData.completed.is_empty() and not SaveData.sound_enabled, "old campaign retained and settings migrate")
	SaveData.unlocked = 8
	SaveData.completed = [0, 4]
	SaveData.save_progress("res://build/test_progress.cfg")
	SaveData.unlocked = 1
	SaveData.load_progress("res://build/test_progress.cfg")
	check(SaveData.unlocked == 8 and SaveData.completed == [0, 4], "new campaign progress survives reload")
	config.load("res://build/test_progress.cfg")
	check(config.get_value("progress", "unlocked") == 12, "saving new campaign preserves original progress")
	app.begin_level(0)
	app.world.win()
	app.begin_level(1)
	await get_tree().create_timer(0.8).timeout
	check(app.overlay == null, "navigation cancels pending result")
	app.toast("first")
	var previous = weakref(app.toast_panel)
	app.toast("second")
	await frames(2)
	check(previous.get_ref() == null, "replacing hint removes previous panel and timer")
	app.show_title()
	Sound.shutdown()
	await get_tree().create_timer(0.1).timeout
	check(Sound.music.stream == null and Sound.voices.all(func(v): return v.stream == null), "shutdown releases audio")
	var output = {"checks": checks, "failures": failures, "levels": results, "status": "passed" if failures.is_empty() else "failed", "engine": Engine.get_version_info().string}
	var file = FileAccess.open("res://build/test_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	print("TEST_RESULT: %s (%d checks, %d failures)" % [output.status, checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
