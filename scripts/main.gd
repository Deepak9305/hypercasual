extends Control
const INK = Color("101d3c")
const CREAM = Color("fff6de")
const CYAN = Color("00eeed")
const CORAL = Color("fa7854")
const GOLD = Color("ffbe40")
const PROP_NAMES = {"umbrella": "UMBRELLA", "ramp": "RAMP", "spring": "SPRING", "crate": "CRATE", "fan": "FAN"}
var title_font: Font
var ui_font: Font
var content: Control
var world: RescueWorld
var level_defs: Array[LevelDefinition] = Levels.all()
var current_level: int = 0
var screen: String = "title"
var selected: String = "umbrella"
var dragging: bool = false
var drag_pointer: int = -2
var hint_step: int = 0
var ui_layer: Control
var overlay: Control
var state_label: Label
var instruction: Label
var primary: Button
var prop_cards: Dictionary = {}
var attempts: int = 1
var outcome_pending: bool = false
var capture_mode: bool = false
var outcome_timer: Timer
var toast_panel: Panel
var quitting: bool = false
var turn_button: Button
var remove_button: Button
var plan_label: Label

func _ready() -> void:
	get_tree().auto_accept_quit = false
	outcome_timer = Timer.new()
	outcome_timer.one_shot = true
	outcome_timer.timeout.connect(finish_outcome)
	add_child(outcome_timer)
	title_font = load("res://assets/fonts/Bangers-Regular.ttf")
	ui_font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	content = Control.new()
	content.size = Vector2(780, 1688)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	world = RescueWorld.new()
	content.add_child(world)
	world.state_changed.connect(update_game_ui)
	world.rescued.connect(on_rescued)
	world.failed.connect(on_failed)
	world.object_placed.connect(func(kind):
		selected = kind
		update_game_ui())
	ui_layer = Control.new()
	ui_layer.z_index = 100
	ui_layer.size = content.size
	ui_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(ui_layer)
	get_viewport().size_changed.connect(layout_content)
	layout_content()
	show_title()
	var args = OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_mode = true
		call_deferred("capture_screens")

func layout_content() -> void:
	var visible_size = get_viewport_rect().size
	var usable = Rect2(Vector2.ZERO, visible_size)
	# Fit the whole game inside Android cutouts without hiding bottom controls.
	if OS.has_feature("android"):
		var safe = DisplayServer.get_display_safe_area()
		var display_size = DisplayServer.screen_get_size()
		if display_size.x > 0 and display_size.y > 0 and safe.size.x > 0:
			var ratio = visible_size / Vector2(display_size)
			usable = Rect2(Vector2(safe.position) * ratio, Vector2(safe.size) * ratio)
	var fit = minf(usable.size.x / 780.0, usable.size.y / 1688.0)
	content.scale = Vector2.ONE * fit
	content.position = usable.position + (usable.size - Vector2(780, 1688) * fit) * 0.5

func clear_ui() -> void:
	outcome_timer.stop()
	outcome_pending = false
	for child in ui_layer.get_children():
		ui_layer.remove_child(child)
		child.queue_free()
	prop_cards.clear()
	overlay = null
	toast_panel = null
	dragging = false
	world.hide_ghost()

func box(color: Color, radius: int = 28, border: Color = INK, width: int = 4) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.06, 0.1, 0.2, 0.14)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 6)
	return style

func label(text: String, rect: Rect2, font_size: int, color: Color = INK, parent: Node = null, title: bool = false) -> Label:
	var node = Label.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_override("font", title_font if title else ui_font)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else ui_layer).add_child(node)
	return node

func button(text: String, rect: Rect2, callback: Callable, fill: Color = CREAM, parent: Node = null, font_size: int = 38) -> Button:
	var node = Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_override("font", ui_font)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_hover_color", INK)
	node.add_theme_color_override("font_pressed_color", INK)
	node.add_theme_color_override("font_disabled_color", Color("788187"))
	node.add_theme_stylebox_override("normal", box(fill))
	node.add_theme_stylebox_override("hover", box(fill.lightened(0.08)))
	node.add_theme_stylebox_override("pressed", box(fill.darkened(0.08), 28, INK, 6))
	node.add_theme_stylebox_override("disabled", box(Color("e3ded1"), 28, Color("b3aea1"), 3))
	node.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), 28, CYAN, 5))
	node.pressed.connect(func():
		Sound.play("tap", -15)
		callback.call())
	(parent if parent else ui_layer).add_child(node)
	return node

func icon_button(icon_name: String, rect: Rect2, callback: Callable, caption: String = "") -> Button:
	var node = button("", rect, callback)
	node.name = icon_name.capitalize() + "Button"
	node.tooltip_text = "Pause" if icon_name == "pause" else caption.capitalize()
	var icon_size = Vector2(48, 48) if caption == "" else Vector2(54, 54)
	var at = rect.position + Vector2((rect.size.x - icon_size.x) * 0.5, 17 if caption == "" else 9)
	art("res://assets/icons/%s.svg" % icon_name, Rect2(at, icon_size))
	if caption != "":
		label(caption, Rect2(rect.position + Vector2(3, 64), Vector2(rect.size.x - 6, 31)), 24)
	return node

func panel(rect: Rect2, fill: Color, parent: Node = null, radius: int = 28, border: Color = INK, width: int = 4) -> Panel:
	var node = Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", box(fill, radius, border, width))
	(parent if parent else ui_layer).add_child(node)
	return node

func art(path: String, rect: Rect2, parent: Node = null) -> TextureRect:
	var node = TextureRect.new()
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture = world.texture(path)
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else ui_layer).add_child(node)
	return node

func logo(at: Vector2 = Vector2(24, 16), scale_: float = 1.0) -> void:
	if ResourceLoader.exists("res://assets/art/logo.png"):
		art("res://assets/art/logo.png", Rect2(at, Vector2(340, 160) * scale_))
		return
	var first = label("FREEZE", Rect2(at, Vector2(340, 95) * scale_), int(95 * scale_), CYAN, null, true)
	first.add_theme_font_override("font", ui_font)
	first.add_theme_font_size_override("font_size", int(76 * scale_))
	first.add_theme_color_override("font_outline_color", INK)
	first.add_theme_constant_override("outline_size", 13)
	first.rotation = -0.045
	var second = label("FRAME", Rect2(at + Vector2(20, 72) * scale_, Vector2(310, 85) * scale_), int(86 * scale_), GOLD, null, true)
	second.add_theme_font_override("font", ui_font)
	second.add_theme_font_size_override("font_size", int(72 * scale_))
	second.add_theme_color_override("font_outline_color", INK)
	second.add_theme_constant_override("outline_size", 13)
	second.rotation = -0.045

func show_title() -> void:
	screen = "title"
	clear_ui()
	world.reset(level_defs[0], 0)
	world.visible = true
	world.courier_sprite.texture = world.texture("res://assets/art/courier_happy.png")
	world.courier.position = Vector2(350, 1040)
	world.courier_sprite.scale *= 1.35
	for actor in world.actors:
		actor.visible = false
	logo(Vector2(170, 80), 1.35)
	panel(Rect2(65, 335, 650, 115), CREAM)
	label("ONE MOMENT. ENDLESS POSSIBILITIES.", Rect2(80, 345, 620, 92), 31)
	panel(Rect2(0, 1165, 780, 523), CREAM, null, 34, CREAM, 0)
	label("Build a chain.\nSave the delivery.", Rect2(65, 1185, 650, 125), 43)
	button("PLAY", Rect2(100, 1340, 580, 112), func(): begin_level(mini(SaveData.unlocked - 1, level_defs.size() - 1)), CYAN, null, 52)
	button("LEVELS", Rect2(100, 1480, 275, 84), show_levels, CREAM, null, 34)
	button("SETTINGS", Rect2(405, 1480, 275, 84), func(): show_settings(false), CREAM, null, 34)
	label("Five tools. Eight rescues. Your clever plan.", Rect2(65, 1600, 650, 50), 24, Color("52606e"))

func show_levels() -> void:
	screen = "levels"
	clear_ui()
	world.visible = false
	panel(Rect2(0, 0, 780, 1688), CREAM, null, 0, CREAM, 0)
	logo(Vector2(40, 40), 0.9)
	button("HOME", Rect2(575, 60, 150, 70), show_title, CREAM, null, 26)
	label("YOUR NEXT GOOD IDEA", Rect2(40, 235, 700, 70), 41)
	for chapter in range(Levels.CHAPTERS.size()):
		var y = 330 + chapter * 555
		label(Levels.CHAPTERS[chapter], Rect2(42, y, 696, 65), 30)
		for local_index in range(4):
			var index = chapter * 4 + local_index
			var x = 65 + local_index % 2 * 340
			var row_y = y + 85 + local_index / 2 * 195
			var done = index in SaveData.completed
			var unlocked_ = index < SaveData.unlocked
			var node = button("%02d  %s" % [index + 1, "DONE" if done else "PLAY" if unlocked_ else "LOCKED"], Rect2(x, row_y, 310, 105), func(): begin_level(index), CYAN if done else GOLD if unlocked_ else CREAM, null, 31)
			node.disabled = not unlocked_
			label(level_defs[index].title, Rect2(x, row_y + 108, 310, 42), 21)
			if SaveData.has_replay(level_defs[index].id):
				button("WATCH RESCUE", Rect2(x + 30, row_y + 153, 250, 38), func(): watch_saved_replay(index), CREAM, null, 18)
	label("Completed puzzles are always yours to replay.", Rect2(40, 1550, 700, 65), 26, Color("52606e"))

func begin_level(index: int, retry: bool = false) -> void:
	current_level = clampi(index, 0, level_defs.size() - 1)
	screen = "game"
	if not retry:
		attempts = 1
	hint_step = 0
	selected = level_defs[current_level].candidates[0]
	outcome_pending = false
	clear_ui()
	world.visible = true
	world.reset(level_defs[current_level], current_level)
	build_game_ui()
	update_game_ui()

func build_game_ui() -> void:
	logo()
	icon_button("pause", Rect2(660, 30, 84, 84), func(): show_settings(true))
	panel(Rect2(24, 178, 465, 62), CREAM, null, 32)
	label("%02d  •  %s" % [current_level + 1, level_defs[current_level].title], Rect2(30, 180, 455, 58), 28)
	state_label = label("", Rect2(480, 182, 270, 58), 26, INK)
	panel(Rect2(0, 1160, 780, 528), CREAM, null, 30, CREAM, 0)
	instruction = label("", Rect2(28, 1168, 724, 68), 28)
	var candidates = level_defs[current_level].candidates
	var width_ = 724.0 / candidates.size()
	for i in range(candidates.size()):
		var kind: String = candidates[i]
		var rect = Rect2(28 + i * width_, 1345, width_ - 10, 155)
		var card = panel(rect, CREAM, null, 22, Color("dfd4bd"), 4)
		art("res://assets/art/%s_%s.%s" % ["hazard" if kind == "crate" else "prop", kind, "svg" if kind == "fan" else "png"], Rect2(rect.position + Vector2(8, 5), Vector2(rect.size.x - 16, 105)))
		label(PROP_NAMES[kind], Rect2(rect.position + Vector2(2, 113), Vector2(rect.size.x - 4, 38)), 19 if candidates.size() == 5 else 24)
		prop_cards[kind] = {"panel": card, "rect": rect}
	plan_label = label("", Rect2(28, 1238, 330, 96), 23)
	turn_button = button("TURN", Rect2(365, 1238, 182, 96), func(): world.turn_tool(selected), GOLD, null, 21)
	remove_button = button("REMOVE", Rect2(566, 1238, 186, 96), func(): world.remove_tool(selected), CREAM, null, 21)
	icon_button("hint", Rect2(28, 1530, 138, 102), show_hint, "HINT")
	primary = button("START", Rect2(189, 1520, 402, 119), primary_action, CYAN, null, 49)
	icon_button("retry", Rect2(614, 1530, 138, 102), retry_level, "RETRY")
	var footer = "BONUS: ≤ %d tools • %snew solution" % [level_defs[current_level].par_tools, "protect parcels • " if not level_defs[current_level].hazards.is_empty() else ""] if current_level >= 4 else "%s • %d / %d" % [Levels.CHAPTERS[0], current_level + 1, level_defs.size()]
	label(footer, Rect2(35, 1645, 710, 30), 19, Color("66727b"))

func update_game_ui() -> void:
	if screen != "game" or not is_instance_valid(primary):
		return
	primary.disabled = false
	match world.state:
		RescueWorld.State.PREVIEW:
			primary.text = "START"
			instruction.text = "Watch the scene. Find your moment."
			state_label.text = "READY?"
		RescueWorld.State.RUNNING:
			primary.text = "FREEZE"
			instruction.text = "Tap FREEZE before trouble arrives!"
			state_label.text = "FREEZE NOW!" if world.freeze_cue_shown else "TIME IS MOVING"
		RescueWorld.State.FROZEN, RescueWorld.State.PLACEMENT:
			primary.text = "RESUME"
			instruction.text = "Place tools, aim them, then RESUME.\nDrag a placed tool to adjust it."
			state_label.text = "TIME FROZEN"
		RescueWorld.State.RESUMED:
			primary.text = "LET'S SEE…"
			primary.disabled = true
			instruction.text = "A little idea can change everything."
			state_label.text = "IN MOTION"
		RescueWorld.State.SUCCESS:
			primary.text = "NEXT"
			instruction.text = "Special delivery. Safely delivered!"
			state_label.text = "RESCUED!"
		RescueWorld.State.FAILURE:
			primary.text = "REWIND"
			instruction.text = "Rewind keeps your plan. Adjust one thing."
			state_label.text = "TRY AGAIN"
	var can_edit = world.state in [RescueWorld.State.FROZEN, RescueWorld.State.PLACEMENT]
	plan_label.text = "%d / %d TOOLS" % [world.placements.size(), world.definition.tool_budget]
	var direction_names = ["RIGHT", "DOWN-R", "DOWN", "DOWN-L", "LEFT", "UP-L", "UP", "UP-R"]
	turn_button.text = "TURN • " + direction_names[world.directions.get(selected, 0)]
	turn_button.disabled = not can_edit or selected == "crate"
	remove_button.disabled = not can_edit or not world.placements.has(selected)
	primary.disabled = can_edit and world.placements.is_empty() or world.state == RescueWorld.State.RESUMED
	for kind in prop_cards:
		var active = kind == selected and world.state in [RescueWorld.State.FROZEN, RescueWorld.State.PLACEMENT]
		prop_cards[kind].panel.add_theme_stylebox_override("panel", box(CREAM, 32, CYAN if active else Color("dfd4bd"), 7 if active else 4))

func primary_action() -> void:
	match world.state:
		RescueWorld.State.PREVIEW:
			world.start()
		RescueWorld.State.RUNNING:
			world.freeze()
		RescueWorld.State.FROZEN, RescueWorld.State.PLACEMENT:
			if not world.resume():
				toast("Place an object in the scene first.")
		RescueWorld.State.SUCCESS:
			if current_level < level_defs.size() - 1:
				begin_level(current_level + 1)
			else:
				show_levels()
		RescueWorld.State.FAILURE:
			retry_level()

func retry_level() -> void:
	attempts += 1
	clear_ui()
	screen = "game"
	if not world.rewind_plan():
		world.reset(level_defs[current_level], current_level)
	build_game_ui()
	update_game_ui()

func show_hint() -> void:
	if world.state == RescueWorld.State.PREVIEW:
		toast("Start the scene, then freeze time.")
		return
	if world.state == RescueWorld.State.RUNNING:
		world.freeze()
	if world.state not in [RescueWorld.State.FROZEN, RescueWorld.State.PLACEMENT]:
		return
	var hints = level_defs[current_level].hints
	toast(hints[mini(hint_step, hints.size() - 1)])
	if hint_step > 0:
		selected = level_defs[current_level].solution[0].kind
		world.hint_marker = true
		update_game_ui()
	hint_step += 1

func toast(text: String) -> void:
	if is_instance_valid(toast_panel):
		ui_layer.remove_child(toast_panel)
		toast_panel.queue_free()
	var parent = Panel.new()
	parent.position = Vector2(32, 1060)
	parent.size = Vector2(716, 95)
	parent.add_theme_stylebox_override("panel", box(CREAM, 22, INK, 3))
	parent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(parent)
	toast_panel = parent
	var banner = label(text, Rect2(15, 8, 686, 79), 27, INK, parent)
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var timer = Timer.new()
	timer.one_shot = true
	parent.add_child(timer)
	timer.timeout.connect(parent.queue_free)
	timer.start(4.5)

func local_pointer(event: InputEvent) -> Vector2:
	return (event.position - content.position) / content.scale

func _input(event: InputEvent) -> void:
	if quitting or screen != "game" or overlay != null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			world.turn_tool(selected)
		elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			world.remove_tool(selected)
		elif event.keycode == KEY_SPACE:
			primary_action()
		elif event.keycode == KEY_R:
			retry_level()
		elif event.keycode == KEY_H:
			show_hint()
		elif event.keycode == KEY_ESCAPE:
			show_settings(true)
		return
	var is_press = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	var is_release = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)
	var is_motion = event is InputEventMouseMotion or event is InputEventScreenDrag
	if not (is_press or is_release or is_motion):
		return
	if world.state not in [RescueWorld.State.FROZEN, RescueWorld.State.PLACEMENT]:
		return
	var at = local_pointer(event)
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if dragging and event.index != drag_pointer:
			return
	if is_press:
		for kind in prop_cards:
			if prop_cards[kind].rect.has_point(at):
				selected = kind
				dragging = true
				drag_pointer = event.index if event is InputEventScreenTouch else -1
				update_game_ui()
				get_viewport().set_input_as_handled()
				return
		if at.y > 250 and at.y < 1050:
			for kind in world.placements:
				if Rect2(world.tool_nodes[kind].position - RescueWorld.PROP_SIZES[kind] * 0.5, RescueWorld.PROP_SIZES[kind]).has_point(at):
					selected = kind
					update_game_ui()
					break
			dragging = true
			drag_pointer = event.index if event is InputEventScreenTouch else -1
			world.show_ghost(selected, at)
			get_viewport().set_input_as_handled()
	elif is_motion and dragging:
		if at.y < 1150:
			world.show_ghost(selected, at)
		else:
			world.hide_ghost()
		get_viewport().set_input_as_handled()
	elif is_release and dragging:
		if at.y < 1150:
			if not world.place(selected, at):
				toast("Use a clear spot. At the tool limit? Move or remove a placed tool.")
		world.hide_ghost()
		dragging = false
		drag_pointer = -2
		get_viewport().set_input_as_handled()

func show_settings(in_game: bool) -> void:
	if overlay:
		return
	world.paused = true
	dragging = false
	world.hide_ghost()
	overlay = Control.new()
	overlay.size = Vector2(780, 1688)
	ui_layer.add_child(overlay)
	var shade = ColorRect.new()
	shade.size = overlay.size
	shade.color = Color(0.04, 0.07, 0.15, 0.65)
	overlay.add_child(shade)
	panel(Rect2(70, 445, 640, 740), CREAM, overlay, 38)
	label("TAKE A BREATHER" if in_game else "MAKE IT YOURS", Rect2(95, 475, 590, 90), 54, INK, overlay, true)
	var sound_button = button("SOUND  •  ON" if SaveData.sound_enabled else "SOUND  •  OFF", Rect2(125, 600, 530, 90), func():
		SaveData.sound_enabled = not SaveData.sound_enabled
		SaveData.save_progress()
		Sound.update_music()
		rebuild_settings(in_game), CYAN if SaveData.sound_enabled else CREAM, overlay, 33)
	sound_button.name = "SoundToggle"
	button("HAPTICS  •  ON" if SaveData.haptics_enabled else "HAPTICS  •  OFF", Rect2(125, 725, 530, 90), func():
		SaveData.haptics_enabled = not SaveData.haptics_enabled
		SaveData.save_progress()
		rebuild_settings(in_game), GOLD if SaveData.haptics_enabled else CREAM, overlay, 33)
	button("KEEP PLAYING" if in_game else "BACK", Rect2(125, 870, 530, 98), close_overlay, CYAN, overlay, 36)
	if in_game:
		button("LEVEL SELECT", Rect2(125, 1000, 530, 80), func():
			world.paused = false
			show_levels(), CREAM, overlay, 31)

func rebuild_settings(in_game: bool) -> void:
	close_overlay()
	show_settings(in_game)

func close_overlay() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null
	world.paused = false

func on_rescued() -> void:
	var goals = SaveData.record_rescue(level_defs[current_level].id, world.replay_data())
	world.last_goals = goals
	SaveData.finish_level(current_level)
	if outcome_pending:
		return
	outcome_pending = true
	outcome_timer.start(0.65)

func on_failed(reason: String) -> void:
	if outcome_pending:
		return
	outcome_pending = true
	outcome_timer.set_meta("reason", reason)
	outcome_timer.start(0.55)

func finish_outcome() -> void:
	if screen != "game" or not outcome_pending:
		return
	if overlay != null or world.paused:
		outcome_timer.start(0.1)
		return
	if world.state == RescueWorld.State.SUCCESS:
		show_result(true, "")
	elif world.state == RescueWorld.State.FAILURE:
		show_result(false, outcome_timer.get_meta("reason", "New plan?"))

func quit_game() -> void:
	if quitting:
		return
	quitting = true
	world.paused = true
	outcome_timer.stop()
	SaveData.save_progress()
	Sound.shutdown()
	# Give the audio mixing thread time to release its playback references.
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()

func show_result(success: bool, reason: String) -> void:
	if overlay:
		return
	overlay = Control.new()
	overlay.size = Vector2(780, 1688)
	ui_layer.add_child(overlay)
	panel(Rect2(70, 425, 640, 800), CREAM, overlay, 40)
	label("TIME WELL SPENT!" if success else "NEW PLAN?", Rect2(95, 455, 590, 100), 64, INK, overlay, true)
	art("res://assets/art/courier_happy.png" if success else "res://assets/art/courier_worried.png", Rect2(310, 555, 160, 180), overlay)
	var summary = "Courier rescued!" if success else reason + "\nYour placements are kept."
	# Failure stays highlighted behind the panel until the plan is rewound.
	var summary_label = label(summary, Rect2(100, 745, 580, 100), 28, INK, overlay)
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if success:
		var goals = world.last_goals
		var bonus = "Rescue recorded. Try another idea!"
		if current_level >= 4:
			bonus = "%s Efficient" % ("✓" if goals.get("few_tools", false) else "○")
			if not level_defs[current_level].hazards.is_empty():
				bonus += " • %s Parcels safe" % ("✓" if goals.get("all_parcels", false) else "○")
			bonus += " • %s New solution" % ("✓" if goals.get("different_solution", false) else "○")
		label(bonus, Rect2(90, 856, 600, 42), 19, INK, overlay)
		button("WATCH SAVED RESCUE", Rect2(125, 905, 530, 62), func(): watch_saved_replay(current_level), GOLD, overlay, 26)
	button("NEXT DELIVERY" if success and current_level < level_defs.size() - 1 else "ALL DELIVERED!" if success else "REWIND & ADJUST", Rect2(125, 990, 530, 90), func():
		if success:
			if current_level < level_defs.size() - 1:
				begin_level(current_level + 1)
			else:
				show_levels()
		else:
			retry_level(), CYAN, overlay, 33)
	button("TRY ANOTHER SOLUTION" if success else "LEVELS", Rect2(125, 1110, 530, 58), retry_level if success else show_levels, CREAM, overlay, 25)

func watch_saved_replay(index: int) -> void:
	var data = SaveData.load_replay(level_defs[index].id)
	if data.is_empty():
		toast("Complete this rescue to save a replay.")
		return
	begin_level(index)
	clear_ui()
	screen = "replay"
	world.watch_replay(data)
	logo()
	panel(Rect2(24, 180, 730, 64), CREAM)
	label("SAVED RESCUE • " + level_defs[index].title, Rect2(30, 182, 720, 58), 28)
	panel(Rect2(0, 1160, 780, 528), CREAM, null, 30, CREAM, 0)
	label("YOUR RESCUE, REPLAYED", Rect2(40, 1190, 700, 70), 40)
	var chain: Array[String] = []
	for event in data.events:
		if event.text not in chain:
			chain.append(event.text)
	var caption = label(" → ".join(chain), Rect2(50, 1280, 680, 115), 27)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button("WATCH AGAIN", Rect2(75, 1425, 630, 85), func(): watch_saved_replay(index), GOLD, null, 34)
	button("TRY ANOTHER SOLUTION", Rect2(75, 1530, 630, 85), func(): begin_level(index), CYAN, null, 31)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		SaveData.save_progress()
		if screen in ["game", "replay"] and overlay == null:
			show_settings(true)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if overlay:
			close_overlay()
		elif screen == "game":
			show_settings(true)
		elif screen != "title":
			show_title()
		else:
			quit_game()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()

func capture_screens() -> void:
	await get_tree().process_frame
	begin_level(0)
	world.start()
	while world.state == RescueWorld.State.RUNNING:
		await get_tree().physics_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/gameplay.png")
	show_title()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/title.png")
	show_levels()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/levels.png")
	print("CAPTURE_COMPLETE")
	quit_game()
