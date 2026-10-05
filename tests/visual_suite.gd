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
	var at = control.get_global_rect().get_center()
	var event = InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event, true)
	await get_tree().process_frame
	event = InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	get_viewport().push_input(event, true)
	await get_tree().process_frame

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

func run() -> void:
	SaveData.test_mode = true
	SaveData.sound_enabled = false
	Sound.update_music()
	app = load("res://scenes/game.tscn").instantiate()
	add_child(app)
	await frames(5)
	await capture("title")
	await click(find_button(app.ui_layer, "PLAY"))
	check(app.screen == "game", "pointer clicks title Play")
	await click(app.primary)
	check(app.world.state == RescueWorld.State.RUNNING, "pointer clicks Start")
	while app.world.state == RescueWorld.State.RUNNING:
		await get_tree().process_frame
	check(app.world.state == RescueWorld.State.FROZEN, "tutorial automatically freezes")
	await capture("gameplay")
	# Select umbrella and drag with actual viewport input routing.
	var start = app.content.position + Vector2(120, 1350) * app.content.scale
	var end = app.content.position + Vector2(320, 750) * app.content.scale
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	get_viewport().push_input(press, true)
	await frames(1)
	var motion = InputEventMouseMotion.new()
	motion.position = end
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(motion, true)
	await frames(1)
	var release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = end
	get_viewport().push_input(release, true)
	await frames(2)
	check(app.world.prop_kind == "umbrella", "viewport drag places umbrella")
	await capture("placement")
	await click(app.primary)
	check(app.world.state == RescueWorld.State.RESUMED, "pointer clicks Resume")
	while app.world.state == RescueWorld.State.RESUMED:
		await get_tree().process_frame
	check(app.world.state == RescueWorld.State.SUCCESS, "complete rendered rescue succeeds")
	await get_tree().create_timer(0.85).timeout
	check(app.overlay != null, "success result opens")
	await capture("success")
	await click(find_button(app.overlay, "NEXT DELIVERY"))
	check(app.current_level == 1 and app.world.state == RescueWorld.State.PREVIEW, "pointer clicks Next Delivery")
	await click(app.primary)
	while app.world.state == RescueWorld.State.RUNNING:
		await get_tree().process_frame
	app.world.place("umbrella", Vector2(650, 400))
	await click(app.primary)
	while app.world.state == RescueWorld.State.RESUMED:
		await get_tree().process_frame
	check(app.world.state == RescueWorld.State.FAILURE, "rendered incorrect placement fails")
	await get_tree().create_timer(0.75).timeout
	check(app.overlay != null, "failure result opens")
	await capture("failure")
	await click(find_button(app.overlay, "TRY AGAIN"))
	check(app.world.state == RescueWorld.State.PREVIEW and app.overlay == null, "pointer clicks retry")
	await click(app.primary)
	await click(app.ui_layer.get_node("PauseButton"))
	check(app.world.paused and app.overlay != null, "pointer opens pause")
	var sound_state = SaveData.sound_enabled
	await click(find_button(app.overlay, "SOUND  •  OFF"))
	check(SaveData.sound_enabled != sound_state, "pointer toggles sound")
	await capture("settings")
	await click(find_button(app.overlay, "KEEP PLAYING"))
	check(not app.world.paused, "pointer continues game")
	app.show_levels()
	await capture("levels")
	check(find_button(app.ui_layer, "03  LOCKED").disabled, "locked level cannot be clicked")
	await click(find_button(app.ui_layer, "01  DONE"))
	check(app.current_level == 0, "pointer replays completed level")
	app.begin_level(8)
	app.world.start()
	app.world.freeze()
	app.world.place("spring", Vector2(340, 1020))
	await capture("platform")
	# New puzzles are played through their real Freeze / drag / Resume controls.
	for index in [3, 6, 10]:
		app.begin_level(index)
		await click(app.primary)
		while app.world.sim_time < app.level_defs[index].freeze_at:
			await frames(1)
		check(app.state_label.text == "FREEZE NOW!", "level %d signals manual freeze timing" % (index + 1))
		await click(app.primary)
		check(app.world.state == RescueWorld.State.FROZEN, "level %d manual freeze works" % (index + 1))
		await drag_prop(app.level_defs[index].solution_prop, app.level_defs[index].solution_position)
		check(app.world.prop_kind == app.level_defs[index].solution_prop, "level %d pointer places new solution" % (index + 1))
		await capture({3: "branch_office", 6: "art_attack", 10: "rolling_chain"}[index])
		await click(app.primary)
		var captured_feedback = false
		while app.world.state == RescueWorld.State.RESUMED:
			if not captured_feedback and index == 6 and app.world.spring_used and not app.world.courier_grounded and absf(app.world.courier.velocity.y) < 80:
				await capture("courier_jump")
				captured_feedback = true
			elif not captured_feedback and index == 10 and app.world.impact_life > 0:
				await capture("ramp_feedback")
				captured_feedback = true
			await frames(1)
		check(app.world.state == RescueWorld.State.SUCCESS, "level %d rendered rescue succeeds" % (index + 1))
		if index == 10:
			check(app.world.actors.all(func(actor): return actor.deflected), "one ramp deflects both rolling hazards")
	app.show_title()
	await frames(30)
	var began = Time.get_ticks_usec()
	await frames(120)
	var duration = (Time.get_ticks_usec() - began) / 1000000.0
	var measured = 120.0 / duration
	var result = {"status": "passed" if failures.is_empty() else "failed", "checks": checks, "failures": failures, "desktop_render_fps": measured, "viewport": str(get_viewport().get_visible_rect().size), "android_device_tested": false}
	var output = FileAccess.open("res://build/visual_test_results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	print("VISUAL_TEST_RESULT: ", JSON.stringify(result))
	if failures.is_empty():
		# Exercise the same audio teardown as a real desktop close / Android exit.
		app.quit_game()
	else:
		Sound.shutdown()
		await get_tree().create_timer(0.1).timeout
		get_tree().quit(1)
