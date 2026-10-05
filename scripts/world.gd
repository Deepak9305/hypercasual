class_name RescueWorld
extends Node2D
signal state_changed
signal rescued
signal failed(reason: String)
signal object_placed(kind: String)

enum State { PREVIEW, RUNNING, FROZEN, PLACEMENT, RESUMED, SUCCESS, FAILURE }
const FLOOR_Y = 1040.0
const PROP_SIZES = {"umbrella": Vector2(205, 170), "ramp": Vector2(185, 110), "spring": Vector2(150, 90)}
var state: State = State.PREVIEW
var definition: LevelDefinition
var level_index: int = 0
var sim_time: float = 0.0
var freeze_used: bool = false
var paused: bool = false
var actors: Array[GameActor] = []
var courier: CharacterBody2D
var courier_sprite: Sprite2D
var courier_grounded: bool = true
var spring_used: bool = false
var prop: StaticBody2D
var prop_kind: String = ""
var prop_position: Vector2 = Vector2.ZERO
var world_nodes: Node2D
var platform: StaticBody2D
var elapsed_visual: float = 0.0
var freeze_pulse: float = 0.0
var hint_marker: bool = false
var ghost_kind: String = ""
var ghost_pos: Vector2 = Vector2.ZERO
var ghost_valid: bool = false
var ghost_sprite: Sprite2D
var particles: Array[Dictionary] = []
var background: TextureRect
var art_cache: Dictionary = {}
var courier_base_scale: Vector2
var gait_phase: float = 0.0
var landing_pulse: float = 0.0
var celebration_time: float = 0.0
var impact_text: String = ""
var impact_position: Vector2 = Vector2.ZERO
var impact_life: float = 0.0
var freeze_cue_shown: bool = false
var impact_label: Label

func _ready() -> void:
	background = TextureRect.new()
	background.size = Vector2(780, 1165)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.show_behind_parent = true
	add_child(background)
	world_nodes = Node2D.new()
	add_child(world_nodes)
	ghost_sprite = Sprite2D.new()
	ghost_sprite.z_index = 20
	ghost_sprite.visible = false
	add_child(ghost_sprite)
	impact_label = Label.new()
	impact_label.size = Vector2(280, 60)
	impact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	impact_label.add_theme_font_override("font", load("res://assets/fonts/Bangers-Regular.ttf"))
	impact_label.add_theme_font_size_override("font_size", 36)
	impact_label.add_theme_color_override("font_color", Color("ffbe40"))
	impact_label.add_theme_color_override("font_outline_color", Color("101d3c"))
	impact_label.add_theme_constant_override("outline_size", 7)
	impact_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	impact_label.z_index = 30
	impact_label.visible = false
	add_child(impact_label)

func texture(path: String) -> Texture2D:
	if not art_cache.has(path):
		art_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return art_cache[path]

func reset(level: LevelDefinition, index: int) -> void:
	for child in world_nodes.get_children():
		world_nodes.remove_child(child)
		child.queue_free()
	actors.clear()
	prop = null
	platform = null
	prop_kind = ""
	prop_position = Vector2.ZERO
	ghost_kind = ""
	ghost_sprite.visible = false
	particles.clear()
	gait_phase = 0.0
	landing_pulse = 0.0
	celebration_time = 0.0
	impact_text = ""
	impact_life = 0.0
	impact_label.visible = false
	freeze_pulse = 0.0
	background.position = Vector2.ZERO
	definition = level
	level_index = index
	sim_time = 0.0
	freeze_used = false
	freeze_cue_shown = false
	spring_used = false
	paused = false
	hint_marker = false
	state = State.PREVIEW
	background.texture = texture("res://assets/art/background_%s.png" % definition.background)
	if definition.mechanism == "platform":
		make_static(Vector2(190, FLOOR_Y + 30), Vector2(380, 60), "ground", 1)
		make_static(Vector2(660, FLOOR_Y + 30), Vector2(240, 60), "ground", 1)
		var gap_art = Sprite2D.new()
		gap_art.texture = texture("res://assets/art/stage_gap.png")
		gap_art.position = Vector2(462, 1048)
		if gap_art.texture:
			gap_art.scale = Vector2.ONE * (205.0 / gap_art.texture.get_width())
		gap_art.z_index = 1
		world_nodes.add_child(gap_art)
		platform = make_static(Vector2(465, 1072), Vector2(100, 25), "platform", 1)
		var platform_art = Sprite2D.new()
		platform_art.texture = texture("res://assets/art/moving_platform.png")
		if platform_art.texture:
			platform_art.scale = Vector2.ONE * (110.0 / platform_art.texture.get_width())
		platform_art.z_index = 2
		platform.add_child(platform_art)
	else:
		make_static(Vector2(390, FLOOR_Y + 35), Vector2(1000, 70), "ground", 1)
	if definition.mechanism == "finale":
		var awning = make_static(Vector2(490, 735), Vector2(200, 32), "awning", 8)
		var art = Sprite2D.new()
		art.texture = texture("res://assets/art/prop_umbrella.png")
		if art.texture:
			art.scale = Vector2(225, 145) / art.texture.get_size()
		art.position.y = 45
		awning.add_child(art)
	for data in definition.hazards:
		var actor = GameActor.new()
		actor.configure(data)
		world_nodes.add_child(actor)
		actors.append(actor)
	courier = CharacterBody2D.new()
	courier.position = definition.courier_start
	courier.collision_layer = 4
	courier.collision_mask = 1 | 2
	var courier_shape = CollisionShape2D.new()
	var capsule = CapsuleShape2D.new()
	capsule.radius = 25
	capsule.height = 145
	courier_shape.shape = capsule
	courier_shape.position.y = -75
	courier.add_child(courier_shape)
	courier_sprite = Sprite2D.new()
	courier_sprite.texture = texture("res://assets/art/courier_walk.png")
	if courier_sprite.texture:
		courier_sprite.scale = Vector2(250, 335) / courier_sprite.texture.get_size()
	courier_base_scale = courier_sprite.scale
	courier_sprite.position = Vector2(0, -159)
	courier.z_index = 12
	courier.add_child(courier_sprite)
	world_nodes.add_child(courier)
	courier_grounded = true
	state_changed.emit()
	queue_redraw()

func make_static(at: Vector2, extent: Vector2, tag: String, layer: int) -> StaticBody2D:
	var body = StaticBody2D.new()
	body.position = at
	body.collision_layer = layer
	body.collision_mask = 0
	body.set_meta("kind", tag)
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = extent
	collision.shape = shape
	body.add_child(collision)
	world_nodes.add_child(body)
	return body

func start() -> void:
	if state != State.PREVIEW:
		return
	state = State.RUNNING
	state_changed.emit()

func freeze() -> bool:
	if state != State.RUNNING or freeze_used:
		return false
	freeze_used = true
	state = State.FROZEN
	freeze_pulse = 1.0
	if courier_sprite:
		courier_sprite.texture = texture("res://assets/art/courier_worried.png")
	Sound.play("freeze")
	Sound.haptic(40)
	state_changed.emit()
	return true

func resume() -> bool:
	if state not in [State.FROZEN, State.PLACEMENT] or prop == null:
		return false
	state = State.RESUMED
	ghost_kind = ""
	ghost_sprite.visible = false
	hint_marker = false
	courier_sprite.texture = texture("res://assets/art/courier_walk.png")
	Sound.play("resume")
	Sound.haptic(25)
	state_changed.emit()
	return true

func snapped_position(kind: String, at: Vector2) -> Vector2:
	if kind in ["ramp", "spring"]:
		return Vector2(clampf(at.x, 110, 665), 1020)
	return Vector2(clampf(at.x, 115, 665), clampf(at.y, 330, 935))

func valid_placement(kind: String, at: Vector2) -> bool:
	if kind not in definition.candidates or state not in [State.FROZEN, State.PLACEMENT]:
		return false
	if at.x < 100 or at.x > 680 or at.y < 300 or at.y > FLOOR_Y:
		return false
	var half: Vector2 = PROP_SIZES[kind] * 0.4
	var rect = Rect2(at - half, half * 2)
	var courier_rect = Rect2(courier.position - Vector2(28, 150), Vector2(56, 145))
	if rect.intersects(courier_rect):
		return false
	for actor in actors:
		if actor.elapsed >= actor.delay and rect.intersects(Rect2(actor.position - actor.extent * 0.4, actor.extent * 0.8)):
			return false
	return true

func show_ghost(kind: String, at: Vector2) -> void:
	ghost_kind = kind
	ghost_pos = snapped_position(kind, at)
	ghost_valid = valid_placement(kind, ghost_pos)
	ghost_sprite.texture = texture("res://assets/art/prop_%s.png" % kind)
	if ghost_sprite.texture:
		ghost_sprite.scale = PROP_SIZES[kind] / ghost_sprite.texture.get_size()
	ghost_sprite.position = ghost_pos + Vector2(0, -30) if kind != "umbrella" else ghost_pos + Vector2(0, 60)
	ghost_sprite.modulate = Color(0.3, 1, 0.95, 0.65) if ghost_valid else Color(1, 0.3, 0.2, 0.5)
	ghost_sprite.visible = true
	queue_redraw()

func place(kind: String, at: Vector2) -> bool:
	var target = snapped_position(kind, at)
	if not valid_placement(kind, target):
		Sound.play("invalid")
		return false
	if prop:
		world_nodes.remove_child(prop)
		prop.queue_free()
	prop_kind = kind
	prop_position = target
	var collision_size = Vector2(195, 28) if kind == "umbrella" else Vector2(170, 100) if kind == "ramp" else Vector2(135, 28)
	prop = make_static(target, collision_size, kind, 8)
	if kind == "spring":
		prop.collision_layer = 0
	var art = Sprite2D.new()
	art.texture = texture("res://assets/art/prop_%s.png" % kind)
	if art.texture:
		art.scale = PROP_SIZES[kind] / art.texture.get_size()
	art.position.y = 60 if kind == "umbrella" else -30
	prop.add_child(art)
	prop.z_index = 10
	state = State.PLACEMENT
	ghost_sprite.visible = false
	ghost_kind = ""
	Sound.play("place")
	Sound.haptic(20)
	emit_sparkles(target, Color("00eceb"), 9)
	object_placed.emit(kind)
	state_changed.emit()
	return true

func hide_ghost() -> void:
	ghost_kind = ""
	ghost_sprite.visible = false

func _physics_process(delta: float) -> void:
	if not definition or paused or state not in [State.RUNNING, State.RESUMED]:
		return
	sim_time += delta
	if state == State.RUNNING and level_index < 2 and sim_time >= definition.freeze_at:
		freeze()
		return
	if state == State.RUNNING and not freeze_cue_shown and sim_time >= definition.freeze_at:
		freeze_cue_shown = true
		state_changed.emit()
	if platform:
		platform.position.y = 1060 + sin(sim_time * 2.2) * 42
	for actor in actors:
		if not is_instance_valid(actor):
			continue
		var hit = actor.step(delta)
		if hit:
			var body = hit.get_collider()
			if body == courier and not actor.deflected:
				lose("Delivery interrupted!")
				return
			elif body is StaticBody2D:
				var tag: String = body.get_meta("kind", "ground")
				if tag in ["umbrella", "ramp", "awning"]:
					actor.redirect(tag)
					emit_sparkles(actor.position, Color("ffc44d"), 10)
					Sound.play("bounce", -12)
					freeze_pulse = 0.16
					show_impact("WHOOSH!" if tag == "ramp" else "BONK!", actor.position - Vector2(0, 70))
				elif not actor.deflected:
					actor.velocity.y = 0.0
					if actor.motion != "roll":
						actor.velocity.x = 0.0
				else:
					actor.velocity.y = -absf(actor.velocity.y) * 0.35
	if state == State.FAILURE:
		return
	if prop_kind == "spring" and not spring_used and absf(courier.position.x - prop_position.x) < 44 and courier_grounded:
		courier.velocity.y = -650
		spring_used = true
		courier_grounded = false
		emit_sparkles(prop_position, Color("00eceb"), 14)
		show_impact("BOING!", prop_position + Vector2(90, -160))
		Sound.play("bounce")
		Sound.haptic(30)
	courier.velocity.x = definition.courier_speed
	courier.velocity.y += 800 * delta
	var was_grounded = courier_grounded
	courier.move_and_slide()
	courier_grounded = courier.is_on_floor()
	if courier_grounded and not was_grounded and spring_used:
		landing_pulse = 1.0
		emit_sparkles(courier.position, Color("ffc44d"), 6)
	for collision_index in range(courier.get_slide_collision_count()):
		var body = courier.get_slide_collision(collision_index).get_collider()
		if body is GameActor and not body.deflected:
			lose("A little too close!")
			return
	if courier.position.y > 1200:
		lose("Mind the gap!")
	elif courier.position.x >= definition.rescue_x and courier.position.y <= FLOOR_Y + 10:
		win()
	elif sim_time > definition.timeout:
		lose("Let's try a different plan.")

func win() -> void:
	state = State.SUCCESS
	courier_sprite.texture = texture("res://assets/art/courier_happy.png")
	emit_sparkles(courier.position - Vector2(0, 150), Color("00eceb"), 35)
	Sound.play("success")
	Sound.haptic(60)
	state_changed.emit()
	rescued.emit()

func lose(reason: String) -> void:
	state = State.FAILURE
	courier_sprite.texture = texture("res://assets/art/courier_worried.png")
	Sound.play("failure")
	Sound.haptic(70)
	state_changed.emit()
	failed.emit(reason)

func emit_sparkles(at: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		var angle = float(i) / count * TAU
		particles.append({"position": at, "velocity": Vector2(cos(angle), sin(angle)) * (100 + i % 5 * 35), "life": 1.0, "color": color})

func show_impact(text_: String, at: Vector2) -> void:
	impact_text = text_
	impact_label.text = text_
	impact_position = at
	impact_life = 0.7

func animate_courier(delta: float) -> void:
	if not courier_sprite:
		return
	if state in [State.FROZEN, State.PLACEMENT]:
		# Frozen body and pose remain completely still; only the time rings move.
		return
	if state in [State.RUNNING, State.RESUMED]:
		gait_phase += delta * definition.courier_speed * 0.16
		landing_pulse = maxf(0.0, landing_pulse - delta * 5.0)
		if courier_grounded:
			var stride = sin(gait_phase)
			courier_sprite.position.y = -159 - absf(stride) * 8
			courier_sprite.rotation = stride * 0.035
			courier_sprite.scale = courier_base_scale * Vector2(1.0 + landing_pulse * 0.12 - absf(stride) * 0.025, 1.0 - landing_pulse * 0.12 + absf(stride) * 0.025)
		else:
			courier_sprite.position.y = -164
			courier_sprite.rotation = clampf(courier.velocity.y / 3000.0, -0.16, 0.12)
			courier_sprite.scale = courier_base_scale * Vector2(0.95, 1.06)
	elif state == State.SUCCESS:
		celebration_time += delta
		var hop = maxf(0.0, sin(minf(celebration_time, 0.6) / 0.6 * TAU))
		courier_sprite.position.y = -159 - hop * 20
		courier_sprite.rotation = hop * -0.06
		courier_sprite.scale = courier_base_scale * Vector2(1.0 - hop * 0.04, 1.0 + hop * 0.04)
	elif state == State.FAILURE:
		courier_sprite.rotation = lerpf(courier_sprite.rotation, -0.08, minf(1.0, delta * 8))
		courier_sprite.scale = courier_base_scale

func _process(delta: float) -> void:
	if paused:
		return
	elapsed_visual += delta
	impact_life = maxf(0.0, impact_life - delta)
	impact_label.visible = impact_life > 0
	impact_label.position = impact_position - Vector2(140, 55 + (0.7 - impact_life) * 35)
	impact_label.modulate.a = minf(1.0, impact_life * 4.0)
	freeze_pulse = maxf(0, freeze_pulse - delta * 0.8)
	# A tiny background-only impact shake leaves physics and touch coordinates intact.
	if state == State.RESUMED and freeze_pulse > 0:
		background.position = Vector2(sin(elapsed_visual * 70) * freeze_pulse * 12, cos(elapsed_visual * 58) * freeze_pulse * 7)
	else:
		background.position = Vector2.ZERO
	for particle in particles:
		particle.position += particle.velocity * delta
		particle.velocity.y += 150 * delta
		particle.life -= delta * 1.4
	particles = particles.filter(func(p): return p.life > 0)
	animate_courier(delta)
	queue_redraw()

func _draw() -> void:
	if not definition:
		return
	if courier:
		draw_set_transform(Vector2(courier.position.x, FLOOR_Y + 3), 0, Vector2(1, 0.18))
		draw_circle(Vector2.ZERO, 58, Color(0.06, 0.1, 0.18, 0.17))
		draw_set_transform(Vector2.ZERO)
	if state in [State.FROZEN, State.PLACEMENT]:
		for actor in actors:
			var r = maxf(actor.extent.x, actor.extent.y) * 0.6
			draw_arc(actor.position, r + 22 + sin(elapsed_visual * 2) * 4, 0, TAU, 72, Color(0, 0.95, 1, 0.65), 3, true)
			draw_arc(actor.position, r + 38, -elapsed_visual, PI - elapsed_visual, 48, Color(0.2, 1, 1, 0.35), 2, true)
			for j in range(5):
				var angle = j * TAU / 5 + elapsed_visual * 0.16
				draw_circle(actor.position + Vector2(cos(angle), sin(angle)) * (r + 45), 4, Color(0.1, 1, 1, 0.8))
	if freeze_pulse > 0 and courier:
		draw_arc(courier.position - Vector2(0, 130), (1.0 - freeze_pulse) * 650, 0, TAU, 90, Color(0, 1, 1, freeze_pulse * 0.4), 5, true)
	if ghost_kind != "":
		var size_: Vector2 = PROP_SIZES[ghost_kind]
		draw_rect(Rect2(ghost_pos - size_ * 0.5, size_), Color("00dad8") if ghost_valid else Color("eb6753"), false, 4)
	if hint_marker and definition:
		var center = definition.solution_position
		draw_arc(center, 70 + sin(elapsed_visual * 4) * 6, 0, TAU, 60, Color(0.05, 1, 0.95, 0.85), 5, true)
	for particle in particles:
		var color: Color = particle.color
		color.a = particle.life
		draw_circle(particle.position, 3 + particle.life * 3, color)

func snapshot() -> Dictionary:
	var bodies: Array = []
	for actor in actors:
		bodies.append({"position": actor.position, "velocity": actor.velocity, "elapsed": actor.elapsed, "deflected": actor.deflected})
	return {"time": sim_time, "courier": courier.position, "velocity": courier.velocity, "hazards": bodies, "state": state}
