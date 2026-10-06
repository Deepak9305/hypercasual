extends Node
var app: Control
var checks: int = 0
var failures: Array[String] = []

func _ready() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		print("VISUAL FAIL: ", description)

func frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame

func click(control: Control) -> void:
	if control == null:
		check(false, "requested button exists")
		return
	var at = control.get_global_rect().get_center()
	var event = InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event, true)
	await frames(1)
	event = InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	get_viewport().push_input(event, true)
	await frames(1)

func find_button(parent: Node, text: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == text:
			return child
		var found = find_button(child, text)
		if found:
			return found
	return null

func capture(name_: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/%s.png" % name_)

func drag_prop(kind: String, target: Vector2) -> void:
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = app.content.position + app.prop_cards[kind].rect.get_center() * app.content.scale
	get_viewport().push_input(press, true)
	await frames(1)
	var motion = InputEventMouseMotion.new()
	motion.position = app.content.position + target * app.content.scale
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(motion, true)
	await frames(1)
	var release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = motion.position
	get_viewport().push_input(release, true)
	await frames(2)

func freeze_level(index: int) -> void:
	app.begin_level(index)
	await frames(2)
	await click(app.primary)
	for i in range(180):
		if app.world.state != RescueWorld.State.RUNNING or app.world.sim_time >= app.level_defs[index].freeze_at:
			break
		await frames(1)
	if app.world.state == RescueWorld.State.RUNNING:
		await click(app.primary)
	check(app.world.state == RescueWorld.State.FROZEN, "%s freezes through controls" % app.level_defs[index].title)

func outcome() -> void:
	for i in range(1000):
		if app.world.state in [RescueWorld.State.SUCCESS, RescueWorld.State.FAILURE]:
			return
		await frames(1)

func run() -> void:
	SaveData.test_mode = true
	SaveData.sound_enabled = false
	SaveData.unlocked = 1
	Sound.update_music()
	app = load("res://scenes/game.tscn").instantiate()
	add_child(app)
	await frames(5)
	await capture("title")
	await click(find_button(app.ui_layer, "PLAY"))
	check(app.screen == "game", "Play opens campaign")
	await freeze_level(0)
	await capture("gameplay")
	await drag_prop("umbrella", app.level_defs[0].solution[0].position)
	check(app.world.placements.has("umbrella"), "native drag places shield")
	check(app.world.placements.umbrella.direction == 4, "teaching shield points away from courier")
	await click(app.primary)
	await outcome()
	check(app.world.state == RescueWorld.State.SUCCESS, "rendered teaching rescue succeeds")
	await get_tree().create_timer(0.8).timeout
	check(app.overlay != null, "result opens")
	await click(find_button(app.overlay, "WATCH SAVED RESCUE"))
	check(app.screen == "replay" and app.world.watching_replay, "result plays saved rescue")
	await frames(30)
	await capture("saved_replay")
	await click(find_button(app.ui_layer, "TRY ANOTHER SOLUTION"))
	check(app.screen == "game", "replay returns to experiment")
	for index in [4, 5, 6, 7]:
		await freeze_level(index)
		check(app.prop_cards.size() == 5, "chain levels expose five touch tool cards")
		for tool in app.level_defs[index].solution:
			await drag_prop(tool.kind, tool.position)
		check(app.world.placements.size() == app.level_defs[index].solution.size(), "native drag keeps combined plan")
		await capture(app.level_defs[index].id + "_plan")
		await click(app.primary)
		var impact_captured = false
		for i in range(1000):
			if app.world.state != RescueWorld.State.RESUMED:
				break
			if not impact_captured and app.world.focus_life > 0 and app.world.sim_time > 1.0:
				await capture(app.level_defs[index].id + "_impact")
				impact_captured = true
			await frames(1)
		check(app.world.state == RescueWorld.State.SUCCESS, "%s rendered chain succeeds" % app.level_defs[index].title)
		if index == 7:
			check(app.world.platform_ridden, "Express Route lands on moving platform")
		await get_tree().create_timer(0.8).timeout
		await capture(app.level_defs[index].id + "_result")
	# Intentionally omit the catcher: redirecting alone breaks the bridge.
	await freeze_level(5)
	await drag_prop("umbrella", app.level_defs[5].solution[0].position)
	await click(app.turn_button)
	check(app.world.placements.umbrella.direction == 4, "Turn changes placed tool")
	await click(app.turn_button)
	check(app.world.placements.umbrella.direction == 0, "Turn restores rightward aim")
	await click(app.primary)
	await outcome()
	check(app.world.state == RescueWorld.State.FAILURE and app.world.failure_reason.contains("bridge"), "missing catcher breaks bridge")
	await capture("chain_failure")
	await get_tree().create_timer(0.7).timeout
	var time = app.world.frozen_snapshot.time
	await click(find_button(app.overlay, "REWIND & ADJUST"))
	check(app.overlay == null and app.world.state == RescueWorld.State.PLACEMENT, "Rewind returns to planning")
	check(app.world.placements.has("umbrella") and app.world.sim_time == time, "Rewind preserves shield and frozen time")
	await drag_prop("crate", app.level_defs[5].solution[1].position)
	check(app.world.placements.size() == 2, "retry adds missing catcher to retained plan")
	await click(app.primary)
	await outcome()
	check(app.world.state == RescueWorld.State.SUCCESS, "one edit fixes chain")
	await get_tree().create_timer(0.8).timeout
	await click(find_button(app.overlay, "TRY ANOTHER SOLUTION"))
	await click(app.ui_layer.get_node("PauseButton"))
	check(app.world.paused and app.overlay != null, "pause blocks simulation")
	await click(find_button(app.overlay, "SOUND  •  OFF"))
	check(SaveData.sound_enabled, "settings toggle through pointer")
	await capture("settings")
	await click(find_button(app.overlay, "KEEP PLAYING"))
	check(not app.world.paused, "Keep Playing resumes")
	await click(app.remove_button)
	check(not app.world.placements.has(app.selected), "Remove deletes only selected tool")
	app.show_levels()
	await capture("levels")
	check(find_button(app.ui_layer, "WATCH RESCUE") != null, "saved rescues accessible from level select")
	check(find_button(app.ui_layer, "01  DONE") != null, "completion displayed")
	app.show_title()
	var began = Time.get_ticks_usec()
	await frames(120)
	var measured = 120.0 / ((Time.get_ticks_usec() - began) / 1000000.0)
	var result = {"status": "passed" if failures.is_empty() else "failed", "checks": checks, "failures": failures, "desktop_render_fps": measured, "viewport": str(get_viewport().get_visible_rect().size), "android_device_tested": false}
	FileAccess.open("res://build/visual_test_results.json", FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("VISUAL_TEST_RESULT: ", JSON.stringify(result))
	if failures.is_empty():
		app.quit_game()
	else:
		Sound.shutdown()
		await get_tree().create_timer(0.1).timeout
		get_tree().quit(1)
