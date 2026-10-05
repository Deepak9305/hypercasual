extends Control
const INK = Color("101d3c")
const CREAM = Color("fff6de")
const CYAN = Color("00eeed")
const CORAL = Color("fa7854")
const GOLD = Color("ffbe40")
const PROP_NAMES = {"umbrella": "UMBRELLA", "ramp": "RAMP", "spring": "SPRING"}
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
var banner: Label
var outcome_pending: bool = false
var capture_mode: bool = false
var attempt_generation: int = 0

func _ready() -> void:
	get_tree().auto_accept_quit = false
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
	for child in ui_layer.get_children():
		ui_layer.remove_child(child)
		child.queue_free()
	prop_cards.clear()
	overlay = null
	banner = null
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
	label("Move one object.\nChange what happens.", Rect2(65, 1185, 650, 125), 43)
	button("PLAY", Rect2(100, 1340, 580, 112), func(): begin_level(mini(SaveData.unlocked - 1, 11)), CYAN, null, 52)
	button("LEVELS", Rect2(100, 1480, 275, 84), show_levels, CREAM, null, 34)
	button("SETTINGS", Rect2(405, 1480, 275, 84), func(): show_settings(false), CREAM, null, 34)
	label("12 little disasters. One clever courier.", Rect2(65, 1600, 650, 50), 24, Color("52606e"))

func show_levels() -> void:
	screen = "levels"
	clear_ui()
	world.visible = false
	panel(Rect2(0, 0, 780, 1688), CREAM, null, 0, CREAM, 0)
	logo(Vector2(40, 40), 0.9)
	button("HOME", Rect2(575, 60, 150, 70), show_title, CREAM, null, 26)
	label("YOUR NEXT GOOD IDEA", Rect2(40, 235, 700, 70), 41)
	for chapter in range(3):
		var y = 355 + chapter * 385
		label(Levels.CHAPTERS[chapter], Rect2(42, y, 696, 65), 30)
		for local_index in range(4):
			var index = chapter * 4 + local_index
			var x = 65 + local_index % 2 * 340
			var row_y = y + 85 + local_index / 2 * 130
			var done = index in SaveData.completed
			var unlocked_ = index < SaveData.unlocked
			var node = button("%02d  %s" % [index + 1, "DONE" if done else "PLAY" if unlocked_ else "LOCKED"], Rect2(x, row_y, 310, 105), func(): begin_level(index), CYAN if done else GOLD if unlocked_ else CREAM, null, 31)
			node.disabled = not unlocked_
	label("Completed puzzles are always yours to replay.", Rect2(40, 1550, 700, 65), 26, Color("52606e"))

func begin_level(index: int, retry: bool = false) -> void:
	attempt_generation += 1
	current_level = clampi(index, 0, 11)
	screen = "game"
	if not retry:
		attempts = 1
	hint_step = 0
	selected = "umbrella"
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
	instruction = label("", Rect2(28, 1175, 724, 82), 31)
	for i in range(3):
		var kind: String = ["umbrella", "ramp", "spring"][i]
		var rect = Rect2(28 + i * 246, 1275, 230, 225)
		var card = panel(rect, CREAM, null, 32, Color("dfd4bd"), 4)
		art("res://assets/art/prop_%s.png" % kind, Rect2(rect.position + Vector2(12, 10), Vector2(206, 165)))
		label(PROP_NAMES[kind], Rect2(rect.position + Vector2(5, 179), Vector2(220, 40)), 24)
		prop_cards[kind] = {"panel": card, "rect": rect}
	icon_button("hint", Rect2(28, 1530, 138, 102), show_hint, "HINT")
	primary = button("START", Rect2(189, 1520, 402, 119), primary_action, CYAN, null, 49)
	icon_button("retry", Rect2(614, 1530, 138, 102), retry_level, "RETRY")
	label("%s  •  %d / 12" % [Levels.CHAPTERS[current_level / 4], current_level + 1], Rect2(35, 1645, 710, 30), 19, Color("66727b"))

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
			state_label.text = "TIME IS MOVING"
		RescueWorld.State.FROZEN, RescueWorld.State.PLACEMENT:
			primary.text = "RESUME"
			instruction.text = "Drag one object into the scene." if world.prop == null else "Move one object. Change what happens."
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
			primary.text = "TRY AGAIN"
			instruction.text = "Another idea. Another possibility."
			state_label.text = "TRY AGAIN"
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
			if current_level < 11:
				begin_level(current_level + 1)
			else:
				show_levels()
		RescueWorld.State.FAILURE:
			retry_level()

func retry_level() -> void:
	attempts += 1
	begin_level(current_level, true)

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
		selected = level_defs[current_level].solution_prop
		world.hint_marker = true
		update_game_ui()
	hint_step += 1

func toast(text: String) -> void:
	if is_instance_valid(banner):
		banner.queue_free()
	var parent = Panel.new()
	parent.position = Vector2(32, 1060)
	parent.size = Vector2(716, 95)
	parent.add_theme_stylebox_override("panel", box(CREAM, 22, INK, 3))
	parent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(parent)
	banner = label(text, Rect2(15, 8, 686, 79), 27, INK, parent)
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var timer = get_tree().create_timer(4.5)
	timer.timeout.connect(func():
		if is_instance_valid(parent):
			parent.queue_free())

func local_pointer(event: InputEvent) -> Vector2:
	return (event.position - content.position) / content.scale

func _input(event: InputEvent) -> void:
	if screen != "game" or overlay != null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
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
				toast("Try a clear spot. Leave room for the courier.")
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
	SaveData.finish_level(current_level)
	if outcome_pending:
		return
	outcome_pending = true
	var generation = attempt_generation
	await get_tree().create_timer(0.65).timeout
	if generation == attempt_generation and screen == "game" and world.state == RescueWorld.State.SUCCESS:
		show_result(true, "")

func on_failed(reason: String) -> void:
	if outcome_pending:
		return
	outcome_pending = true
	var generation = attempt_generation
	await get_tree().create_timer(0.55).timeout
	if generation == attempt_generation and screen == "game" and world.state == RescueWorld.State.FAILURE:
		show_result(false, reason)

func show_result(success: bool, reason: String) -> void:
	if overlay:
		return
	overlay = Control.new()
	overlay.size = Vector2(780, 1688)
	ui_layer.add_child(overlay)
	panel(Rect2(70, 485, 640, 640), CREAM, overlay, 40)
	label("TIME WELL SPENT!" if success else "NEW PLAN?", Rect2(95, 515, 590, 100), 64, INK, overlay, true)
	art("res://assets/art/courier_happy.png" if success else "res://assets/art/courier_worried.png", Rect2(295, 620, 190, 230), overlay)
	label("Courier rescued!" if success else reason, Rect2(100, 845, 580, 65), 35, INK, overlay)
	button("NEXT DELIVERY" if success and current_level < 11 else "ALL DELIVERED!" if success else "TRY AGAIN", Rect2(125, 940, 530, 90), func():
		if success:
			if current_level < 11:
				begin_level(current_level + 1)
			else:
				show_levels()
		else:
			retry_level(), CYAN, overlay, 33)
	button("REPLAY" if success else "LEVELS", Rect2(235, 1045, 310, 58), retry_level if success else show_levels, CREAM, overlay, 25)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		SaveData.save_progress()
		if screen == "game" and overlay == null:
			show_settings(true)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if overlay:
			close_overlay()
		elif screen == "game":
			show_settings(true)
		elif screen != "title":
			show_title()
		else:
			get_tree().quit()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveData.save_progress()
		get_tree().quit()

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
	get_tree().quit()

