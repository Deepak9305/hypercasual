class_name RescueWorld
extends Node2D
signal state_changed
signal rescued
signal failed(reason: String)
signal object_placed(kind: String)

enum State { PREVIEW, RUNNING, FROZEN, PLACEMENT, RESUMED, SUCCESS, FAILURE }
const FLOOR_Y = 1040.0
const PROP_SIZES = {"umbrella": Vector2(205, 170), "ramp": Vector2(185, 110), "spring": Vector2(150, 90), "crate": Vector2(85, 85), "fan": Vector2(115, 115)}
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
var prop: Node2D
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
var placements: Dictionary = {}
var tool_nodes: Dictionary = {}
var directions: Dictionary = {}
var mechanisms: Array[Dictionary] = []
var frozen_snapshot: Dictionary = {}
var events: Array[Dictionary] = []
var failure_position: Vector2 = Vector2.ZERO
var failure_reason: String = ""
var focus_position: Vector2 = Vector2.ZERO
var focus_life: float = 0.0
var replay_frames: Array[Dictionary] = []
var replay_tick: int = 0
var watching_replay: bool = false
var playback_frames: Array = []
var playback_index: float = 0.0
var last_goals: Dictionary = {}
var courier_launch_x: float = 0.0
var platform_ridden: bool = false
var focus_canvas: Node2D
var focus_title: Label
var focus_actor: GameActor

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
	focus_canvas = Node2D.new()
	focus_canvas.z_index = 25
	focus_canvas.draw.connect(draw_focus)
	add_child(focus_canvas)
	focus_title = Label.new()
	focus_title.position = Vector2(506, 274)
	focus_title.size = Vector2(242, 36)
	focus_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focus_title.add_theme_font_override("font", load("res://assets/fonts/LilitaOne-Regular.ttf"))
	focus_title.add_theme_font_size_override("font_size", 20)
	focus_title.add_theme_color_override("font_color", Color("101d3c"))
	focus_canvas.add_child(focus_title)

func texture(path: String) -> Texture2D:
	if not art_cache.has(path):
		art_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return art_cache[path]

func reset(level: LevelDefinition, index: int) -> void:
	for child in world_nodes.get_children():
		world_nodes.remove_child(child)
		child.queue_free()
	actors.clear()
	placements.clear()
	tool_nodes.clear()
	directions.clear()
	mechanisms.clear()
	frozen_snapshot.clear()
	events.clear()
	replay_frames.clear()
	replay_tick = 0
	watching_replay = false
	playback_frames.clear()
	failure_reason = ""
	failure_position = Vector2.ZERO
	focus_life = 0.0
	focus_actor = null
	last_goals.clear()
	courier_launch_x = 0.0
	platform_ridden = false
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
	if definition.id == "shield":
		directions["umbrella"] = 4
	sim_time = 0.0
	freeze_used = false
	freeze_cue_shown = false
	spring_used = false
	paused = false
	hint_marker = false
	state = State.PREVIEW
	background.texture = texture("res://assets/art/background_%s.png" % definition.background)
	var gaps = definition.environment.filter(func(m): return m.kind in ["gap", "bridge"])
	if not gaps.is_empty():
		var gap = gaps[0]
		var left: float = gap.position.x - gap.size.x * 0.5
		var right: float = gap.position.x + gap.size.x * 0.5
		make_static(Vector2(left * 0.5, FLOOR_Y + 35), Vector2(left, 70), "ground", 1)
		make_static(Vector2((right + 900) * 0.5, FLOOR_Y + 35), Vector2(900 - right, 70), "ground", 1)
	else:
		make_static(Vector2(390, FLOOR_Y + 35), Vector2(1000, 70), "ground", 1)
	for data in definition.environment:
		var entry = data.duplicate(true)
		entry["active"] = false
		entry["broken"] = false
		if entry.kind in ["gate", "platform", "bridge", "shelf", "fragile_shelf", "switch"]:
			var layer = 8 if entry.kind in ["shelf", "fragile_shelf", "switch"] else 1
			entry["body"] = make_static(entry.position, entry.size, entry.kind, layer)
			if entry.kind == "platform":
				platform = entry.body
		mechanisms.append(entry)
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
	frozen_snapshot = snapshot()
	state = State.FROZEN
	freeze_pulse = 1.0
	if courier_sprite:
		courier_sprite.texture = texture("res://assets/art/courier_worried.png")
	Sound.play("freeze")
	Sound.haptic(40)
	state_changed.emit()
	return true

func resume() -> bool:
	if state not in [State.FROZEN, State.PLACEMENT] or placements.is_empty():
		return false
	state = State.RESUMED
	replay_frames.clear()
	replay_tick = 0
	events.clear()
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
	return Vector2(clampf(at.x, 115, 665), clampf(at.y, 330, 1000 if kind == "crate" else 925))

func valid_placement(kind: String, at: Vector2) -> bool:
	if kind not in definition.candidates or state not in [State.FROZEN, State.PLACEMENT]:
		return false
	if not placements.has(kind) and placements.size() >= definition.tool_budget:
		return false
	if at.x < 100 or at.x > 680 or at.y < 300 or at.y > FLOOR_Y:
		return false
	var half: Vector2 = PROP_SIZES[kind] * 0.4
	var rect = Rect2(at - half, half * 2)
	if rect.intersects(Rect2(courier.position - Vector2(28, 150), Vector2(56, 145))):
		return false
	for actor in actors:
		if actor.elapsed >= actor.delay and rect.intersects(Rect2(actor.position - actor.extent * 0.4, actor.extent * 0.8)):
			return false
	for other in placements:
		if other != kind and rect.intersects(Rect2(placements[other].position - PROP_SIZES[other] * 0.4, PROP_SIZES[other] * 0.8)):
			return false
	for entry in mechanisms:
		if entry.kind == "gate" and rect.intersects(Rect2(entry.position - entry.size * 0.5, entry.size)):
			return false
	return true

func show_ghost(kind: String, at: Vector2) -> void:
	ghost_kind = kind
	ghost_pos = snapped_position(kind, at)
	ghost_valid = valid_placement(kind, ghost_pos)
	ghost_sprite.texture = texture("res://assets/art/%s_%s.%s" % ["hazard" if kind == "crate" else "prop", kind, "svg" if kind == "fan" else "png"])
	if ghost_sprite.texture:
		ghost_sprite.scale = PROP_SIZES[kind] / ghost_sprite.texture.get_size()
	ghost_sprite.flip_h = directions.get(kind, 0) == 4
	ghost_sprite.rotation = directions.get(kind, 0) * PI / 4 if kind == "fan" else 0.0
	ghost_sprite.position = ghost_pos + Vector2(0, 60 if kind == "umbrella" else -30 if kind in ["ramp", "spring"] else 0)
	ghost_sprite.modulate = Color(0.3, 1, 0.95, 0.65) if ghost_valid else Color(1, 0.3, 0.2, 0.5)
	ghost_sprite.visible = true
	queue_redraw()

func place(kind: String, at: Vector2, direction: int = -1) -> bool:
	var target = snapped_position(kind, at)
	if not valid_placement(kind, target):
		Sound.play("invalid")
		return false
	if direction >= 0:
		directions[kind] = direction % 8
	placements[kind] = {"kind": kind, "position": target, "direction": directions.get(kind, 0)}
	create_tool(placements[kind])
	prop_kind = kind
	prop_position = target
	prop = tool_nodes[kind]
	state = State.PLACEMENT
	hide_ghost()
	Sound.play("place")
	Sound.haptic(20)
	emit_sparkles(target, Color("00eceb"), 9)
	object_placed.emit(kind)
	state_changed.emit()
	return true

func create_tool(data: Dictionary) -> void:
	var kind: String = data.kind
	if tool_nodes.has(kind):
		world_nodes.remove_child(tool_nodes[kind])
		tool_nodes[kind].queue_free()
	var node: Node2D
	if kind == "crate":
		var crate = GameActor.new()
		crate.configure({"kind": "crate", "position": data.position, "size": PROP_SIZES.crate, "player_tool": true})
		node = crate
		world_nodes.add_child(node)
	else:
		var collision_size = Vector2(195, 28) if kind == "umbrella" else Vector2(170, 100) if kind == "ramp" else Vector2(135, 28)
		node = make_static(data.position, collision_size, kind, 8 if kind in ["umbrella", "ramp", "spring"] else 0)
		node.set_meta("direction", data.direction)
		var art = Sprite2D.new()
		art.texture = texture("res://assets/art/prop_%s.%s" % [kind, "svg" if kind == "fan" else "png"])
		if art.texture:
			art.scale = PROP_SIZES[kind] / art.texture.get_size()
		art.position.y = 60 if kind == "umbrella" else -30 if kind in ["ramp", "spring"] else 0
		art.flip_h = data.direction == 4
		if kind == "fan":
			art.rotation = data.direction * PI / 4
		node.add_child(art)
	node.z_index = 10
	tool_nodes[kind] = node

func turn_tool(kind: String) -> void:
	if state not in [State.FROZEN, State.PLACEMENT] or kind == "crate":
		return
	var next: int = (directions.get(kind, 0) + 1) % 8 if kind == "fan" else 4 if directions.get(kind, 0) == 0 else 0
	directions[kind] = next
	if placements.has(kind):
		placements[kind].direction = next
		create_tool(placements[kind])
		prop = tool_nodes[kind]
	state_changed.emit()

func remove_tool(kind: String) -> void:
	if state not in [State.FROZEN, State.PLACEMENT] or not tool_nodes.has(kind):
		return
	world_nodes.remove_child(tool_nodes[kind])
	tool_nodes[kind].queue_free()
	tool_nodes.erase(kind)
	placements.erase(kind)
	prop = null if placements.is_empty() else tool_nodes[placements.keys()[-1]]
	prop_kind = "" if placements.is_empty() else placements.keys()[-1]
	state = State.FROZEN if placements.is_empty() else State.PLACEMENT
	state_changed.emit()

func rewind_plan() -> bool:
	if frozen_snapshot.is_empty() or watching_replay:
		return false
	var saved = frozen_snapshot.duplicate(true)
	var plan = placements.duplicate(true)
	var aims = directions.duplicate(true)
	reset(definition, level_index)
	frozen_snapshot = saved
	directions = aims
	sim_time = saved.time
	courier.position = saved.courier
	courier.velocity = saved.velocity
	courier_grounded = saved.grounded
	for i in range(actors.size()):
		actors[i].restore(saved.hazards[i])
	for i in range(mechanisms.size()):
		mechanisms[i].active = saved.mechanisms[i].active
		mechanisms[i].broken = saved.mechanisms[i].broken
		if mechanisms[i].has("body"):
			mechanisms[i].body.position = saved.mechanisms[i].position
			if mechanisms[i].kind == "gate":
				mechanisms[i].body.collision_layer = 0 if mechanisms[i].active else 1 | 8
	placements = plan
	for kind in placements:
		create_tool(placements[kind])
	prop = null if placements.is_empty() else tool_nodes[placements.keys()[-1]]
	prop_kind = "" if placements.is_empty() else placements.keys()[-1]
	freeze_used = true
	state = State.FROZEN if plan.is_empty() else State.PLACEMENT
	courier_sprite.texture = texture("res://assets/art/courier_worried.png")
	state_changed.emit()
	return true

func hide_ghost() -> void:
	ghost_kind = ""
	ghost_sprite.visible = false

func moving_objects() -> Array[GameActor]:
	var bodies: Array[GameActor] = actors.duplicate()
	if tool_nodes.has("crate"):
		bodies.append(tool_nodes.crate)
	return bodies

func record_event(text_: String, at: Vector2) -> void:
	events.append({"time": sim_time, "text": text_, "position": at})
	focus_position = at
	focus_actor = null
	for actor in moving_objects():
		if actor.position.distance_to(at) < 90:
			focus_actor = actor
			break
	focus_life = 1.0
	show_impact(text_, at - Vector2(0, 55))
	emit_sparkles(at, Color("ffc44d"), 10)
	Sound.play("bounce", -12)

func apply_fan(actor: GameActor, delta: float) -> void:
	if not placements.has("fan") or actor.elapsed < actor.delay:
		return
	var fan: Dictionary = placements.fan
	var aim = Vector2.RIGHT.rotated(fan.direction * PI / 4)
	var offset: Vector2 = actor.position - fan.position
	var along = offset.dot(aim)
	if along > 0 and along < 430 and absf(offset.cross(aim)) < 100:
		actor.velocity += aim * 600 * delta
		actor.secured = false
		actor.velocity.x = clampf(actor.velocity.x, -230, 230)
		actor.velocity.y = clampf(actor.velocity.y, -650, 600)
		if not actor.redirect_cooldowns.has("wind"):
			actor.redirect_cooldowns["wind"] = sim_time
			record_event("AIR MAIL!", actor.position)

func update_mechanisms() -> void:
	for entry in mechanisms:
		if entry.kind not in ["plate", "switch"]:
			continue
		var occupied = false
		for actor in moving_objects():
			if actor.elapsed < actor.delay:
				continue
			var foot = actor.position + Vector2(0, actor.extent.y * 0.4)
			if absf(foot.x - entry.position.x) < entry.size.x * 0.5 and absf(foot.y - entry.position.y) < (18 if entry.kind == "switch" else 8) and absf(actor.velocity.y) < 40:
				occupied = true
				actor.secured = true
		var was: bool = entry.active
		entry.active = (entry.active or occupied) if entry.kind == "switch" else occupied
		if entry.active and not was:
			record_event("SWITCH!" if entry.kind == "switch" else "HELD!", entry.position)
	for gate in mechanisms:
		if gate.kind != "gate":
			continue
		var open = mechanisms.any(func(m): return m.kind in ["plate", "switch"] and m.link == gate.link and m.active)
		if open != gate.active:
			gate.active = open
			gate.body.collision_layer = 0 if open else 1 | 8
			record_event("GATE OPEN!" if open else "GATE CLOSED!", gate.position)

func _physics_process(delta: float) -> void:
	if not definition or paused or watching_replay or state not in [State.RUNNING, State.RESUMED]:
		return
	sim_time += delta
	if state == State.RUNNING and definition.auto_freeze and sim_time >= definition.freeze_at:
		freeze()
		return
	if state == State.RUNNING and not freeze_cue_shown and sim_time >= definition.freeze_at:
		freeze_cue_shown = true
		state_changed.emit()
	if platform:
		platform.position.y = 990 + sin(sim_time * 2.2) * 35
	for actor in moving_objects():
		apply_fan(actor, delta)
		var hit = actor.step(delta)
		if not actor.supported and actor.velocity.y > 80:
			actor.secured = false
		if not hit:
			continue
		var body = hit.get_collider()
		if body == courier:
			if not actor.player_tool and not actor.secured:
				lose("The redirected parcel hit the courier!" if actor.deflected else "The hazard hit the courier!", actor.position)
				return
			actor.velocity.x = 0
		elif body is GameActor:
			if body.player_tool and not actor.player_tool and hit.get_normal().y < -0.5:
				if not actor.secured:
					record_event("CAUGHT!", actor.position)
				actor.secured = true
				actor.velocity = Vector2.ZERO
			else:
				actor.velocity = actor.velocity.slide(hit.get_normal())
		elif body is StaticBody2D:
			var tag: String = body.get_meta("kind", "ground")
			if tag in ["umbrella", "ramp", "spring"]:
				var key = str(body.get_instance_id())
				if not actor.redirect_cooldowns.has(key):
					actor.redirect_cooldowns[key] = sim_time
					actor.redirect(tag, body.get_meta("direction", 0))
					record_event("WHOOSH!" if tag == "ramp" else "BOING!" if tag == "spring" else "REDIRECT!", actor.position)
				else:
					actor.velocity = actor.velocity.slide(hit.get_normal())
			elif tag == "fragile_shelf" and not actor.player_tool and actor.velocity.y > 180:
				for shelf in mechanisms:
					if shelf.get("body") == body:
						shelf.broken = true
						shelf.body.collision_layer = 0
						record_event("PERCH BROKE!", actor.position)
			elif tag == "bridge" and not actor.player_tool and actor.velocity.y > 180:
				for bridge in mechanisms:
					if bridge.kind == "bridge":
						bridge.broken = true
						bridge.body.collision_layer = 0
				lose("The parcel broke the bridge. Catch it after redirecting!", actor.position)
				return
			else:
				actor.velocity = actor.velocity.slide(hit.get_normal())
				if hit.get_normal().y < -0.5:
					actor.velocity.x = move_toward(actor.velocity.x, 0.0, 100 * delta)
	update_mechanisms()
	if placements.has("spring") and not spring_used and absf(courier.position.x - placements.spring.position.x) < 44 and courier_grounded:
		courier.velocity.y = -650
		courier_launch_x = -definition.courier_speed if placements.spring.direction == 4 else definition.courier_speed
		spring_used = true
		courier_grounded = false
		record_event("BOING!", placements.spring.position)
		Sound.haptic(30)
	courier.velocity.x = courier_launch_x if spring_used and not courier_grounded else definition.courier_speed
	for entry in mechanisms:
		if entry.kind == "conveyor" and absf(courier.position.x - entry.position.x) < entry.size.x * 0.5 and courier_grounded:
			courier.velocity.x += 70
	courier.velocity.y += 800 * delta
	var was_grounded = courier_grounded
	courier.move_and_slide()
	courier_grounded = courier.is_on_floor()
	if courier_grounded and not was_grounded and spring_used:
		landing_pulse = 1.0
		emit_sparkles(courier.position, Color("ffc44d"), 6)
	for collision_index in range(courier.get_slide_collision_count()):
		var collision = courier.get_slide_collision(collision_index)
		var body = collision.get_collider()
		if body is StaticBody2D and body.get_meta("kind", "") == "platform" and collision.get_normal().y < -0.5 and not platform_ridden:
			platform_ridden = true
			record_event("ON BOARD!", platform.position)
		if body is GameActor:
			if not body.player_tool and not body.secured:
				lose("The redirected parcel blocked the exit!" if body.deflected else "The courier ran into a hazard!", body.position)
				return
			# Low, deliberately secured cargo is a step; loose parcels are always dangerous.
			if absf(collision.get_normal().x) > 0.5 and courier.position.y - (body.position.y - body.extent.y * 0.4) <= 80:
				courier.position.y = body.position.y - body.extent.y * 0.4 - 2
				courier.position.x += 4
	capture_replay_frame()
	if courier.position.y > 1200:
		lose("The courier missed the moving platform!", courier.position)
	elif courier.position.x >= definition.rescue_x and courier.position.y <= FLOOR_Y + 10:
		if mechanisms.any(func(m): return m.kind == "gate" and not m.active):
			lose("Open the exit gate before the courier arrives.", courier.position)
		elif platform and not platform_ridden:
			lose("Land on the moving platform to complete this route.", platform.position)
		else:
			win()
	elif sim_time > definition.timeout:
		lose("The gate needs a weight or a switch. Adjust your chain.", courier.position)

func win() -> void:
	last_goals = {"few_tools": placements.size() <= definition.par_tools, "all_parcels": actors.all(func(a): return a.secured and a.position.x >= 0 and a.position.x <= 780 and a.position.y <= FLOOR_Y + 10 and a.velocity.length() < 80), "tools": placements.size(), "time": sim_time}
	capture_replay_frame(true)
	state = State.SUCCESS
	courier_sprite.texture = texture("res://assets/art/courier_happy.png")
	emit_sparkles(courier.position - Vector2(0, 150), Color("00eceb"), 35)
	Sound.play("success")
	Sound.haptic(60)
	state_changed.emit()
	rescued.emit()

func lose(reason: String, at: Vector2 = Vector2.ZERO) -> void:
	failure_position = at if at != Vector2.ZERO else courier.position - Vector2(0, 100)
	failure_reason = reason
	record_event("CHAIN BROKE!", failure_position)
	capture_replay_frame(true)
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
	if watching_replay or state in [State.FROZEN, State.PLACEMENT]:
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
	focus_life = maxf(0.0, focus_life - delta)
	if watching_replay:
		playback_index += delta * 30.0
		if int(playback_index) < playback_frames.size():
			apply_replay_frame(playback_frames[int(playback_index)])
		else:
			watching_replay = false
			courier_sprite.texture = texture("res://assets/art/courier_happy.png")
			state_changed.emit()
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
	focus_canvas.queue_redraw()
	focus_title.visible = focus_life > 0 or state == State.FAILURE
	focus_title.text = "CHAIN BROKE HERE" if state == State.FAILURE else "FOLLOW THE IMPACT"
	queue_redraw()

func _draw() -> void:
	if not definition:
		return
	draw_mechanisms()
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
		var center: Vector2 = definition.solution[0].position
		draw_arc(center, 70 + sin(elapsed_visual * 4) * 6, 0, TAU, 60, Color(0.05, 1, 0.95, 0.85), 5, true)
	for particle in particles:
		var color: Color = particle.color
		color.a = particle.life
		draw_circle(particle.position, 3 + particle.life * 3, color)

func snapshot() -> Dictionary:
	var bodies: Array = []
	for actor in actors:
		bodies.append(actor.snapshot())
	var environment_state: Array = []
	for entry in mechanisms:
		environment_state.append({"active": entry.active, "broken": entry.broken, "position": entry.body.position if entry.has("body") else entry.position})
	return {"time": sim_time, "courier": courier.position, "velocity": courier.velocity, "grounded": courier_grounded, "hazards": bodies, "mechanisms": environment_state, "state": state}

func capture_replay_frame(force: bool = false) -> void:
	replay_tick += 1
	if not force and (state != State.RESUMED or replay_tick % 2 != 0):
		return
	var frame = snapshot()
	frame["pose"] = {"position": courier_sprite.position, "rotation": courier_sprite.rotation, "scale": courier_sprite.scale}
	frame["crate"] = tool_nodes.crate.snapshot() if tool_nodes.has("crate") else {}
	frame["impact"] = impact_text if impact_life > 0 else ""
	frame["impact_position"] = impact_position
	frame["focus"] = focus_actor.position if is_instance_valid(focus_actor) else focus_position
	frame["focus_life"] = focus_life
	replay_frames.append(frame)

func replay_data() -> Dictionary:
	return {"version": 1, "level_id": definition.id, "plan": placements.duplicate(true), "frames": replay_frames.duplicate(true), "events": events.duplicate(true), "goals": last_goals.duplicate(true)}

func watch_replay(data: Dictionary) -> bool:
	if data.get("version", 0) != 1 or data.get("level_id", "") != definition.id or data.get("frames", []).is_empty():
		return false
	placements = data.plan.duplicate(true)
	for kind in placements:
		create_tool(placements[kind])
	playback_frames = data.frames.duplicate(true)
	playback_index = 0
	watching_replay = true
	state = State.SUCCESS
	apply_replay_frame(playback_frames[0])
	state_changed.emit()
	return true

func apply_replay_frame(frame: Dictionary) -> void:
	courier.position = frame.courier
	courier_sprite.position = frame.pose.position
	courier_sprite.rotation = frame.pose.rotation
	courier_sprite.scale = frame.pose.scale
	for i in range(actors.size()):
		actors[i].restore(frame.hazards[i])
	if tool_nodes.has("crate") and not frame.crate.is_empty():
		tool_nodes.crate.restore(frame.crate)
	for i in range(mechanisms.size()):
		mechanisms[i].active = frame.mechanisms[i].active
		mechanisms[i].broken = frame.mechanisms[i].broken
		if mechanisms[i].has("body"):
			mechanisms[i].body.position = frame.mechanisms[i].position
	impact_text = frame.impact
	impact_label.text = frame.impact
	impact_position = frame.impact_position
	impact_life = 0.2 if frame.impact != "" else 0.0
	focus_actor = null
	focus_position = frame.get("focus", impact_position)
	focus_life = frame.get("focus_life", 0.0)

func draw_arrow(at: Vector2, direction: int, color: Color, length_: float = 50) -> void:
	var aim = Vector2.RIGHT.rotated(direction * PI / 4)
	var end = at + aim * length_
	draw_line(at, end, color, 5, true)
	draw_line(end, end - aim.rotated(0.55) * 18, color, 5, true)
	draw_line(end, end - aim.rotated(-0.55) * 18, color, 5, true)

func draw_mechanisms() -> void:
	var ink = Color("101d3c")
	for entry in mechanisms:
		var at: Vector2 = entry.body.position if entry.has("body") else entry.position
		var rect = Rect2(at - entry.size * 0.5, entry.size)
		match entry.kind:
			"gate":
				if entry.active:
					draw_rect(Rect2(rect.position - Vector2(0, 220), rect.size), Color(0, 0.9, 0.8, 0.4))
				else:
					draw_rect(rect, Color("fa7854"))
					for y in range(int(rect.position.y), int(rect.end.y), 30):
						draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y + 15), ink, 5)
					draw_rect(rect, ink, false, 4)
			"plate", "switch":
				draw_rect(rect.grow(5), ink)
				draw_rect(rect, Color("00eeed") if entry.active else Color("ffbe40"))
				for x in range(int(rect.position.x + 5), int(rect.end.x), 24):
					draw_line(Vector2(x, at.y - 6), Vector2(x + 8, at.y + 6), ink, 3)
				for gate in mechanisms:
					if gate.kind == "gate" and gate.link == entry.link:
						draw_polyline(PackedVector2Array([at + Vector2(0, 14), Vector2(at.x, 1110), Vector2(gate.position.x, 1110), gate.position + Vector2(0, 120)]), Color(0, 0.7, 0.7, 0.6), 3, true)
			"bridge", "shelf", "fragile_shelf", "platform":
				draw_rect(rect, Color("fa7854") if entry.broken else Color("ffbe40") if entry.kind == "bridge" else Color("00b9c5"))
				draw_rect(rect, ink, false, 4)
				if entry.kind == "bridge":
					for x in range(int(rect.position.x + 10), int(rect.end.x), 35):
						draw_line(Vector2(x, at.y - 12), Vector2(x + 8, at.y + 12), ink, 3)
			"gap":
				draw_rect(rect, ink)
			"conveyor":
				draw_rect(rect, ink)
				for x in range(int(rect.position.x), int(rect.end.x), 32):
						draw_arrow(Vector2(x, at.y), 0, Color("ffbe40"), 18)
	for kind in placements:
		var at: Vector2 = tool_nodes[kind].position
		if kind == "fan":
			var aim = Vector2.RIGHT.rotated(placements[kind].direction * PI / 4)
			for j in [-1, 0, 1]:
				var start = at + aim * 70 + aim.orthogonal() * j * 60
				draw_line(start, start + aim * 360, Color(0, 0.8, 0.9, 0.16), 3, true)
		if kind != "crate":
			draw_arrow(at - Vector2(0, 85), placements[kind].direction, ink)
	if ghost_kind != "" and ghost_kind != "crate":
		draw_arrow(ghost_pos - Vector2(0, 90), directions.get(ghost_kind, 0), Color("00b9c5"))
	if focus_life > 0 or state == State.FAILURE:
		var center = failure_position if state == State.FAILURE else focus_position
		draw_arc(center, 70 + sin(elapsed_visual * 8) * 6, 0, TAU, 60, Color("fa7854") if state == State.FAILURE else Color("ffbe40"), 6, true)
		if not events.is_empty():
			var recent: Dictionary = events[-1]
			draw_line(center, recent.position, Color("ffbe40"), 3, true)

func draw_focus() -> void:
	if focus_life <= 0 and state != State.FAILURE:
		return
	var center = focus_actor.position if is_instance_valid(focus_actor) and state != State.FAILURE else failure_position if state == State.FAILURE else focus_position
	var inset = Rect2(506, 310, 242, 145)
	focus_canvas.draw_rect(Rect2(506, 274, 242, 36), Color("fff6de"))
	focus_canvas.draw_rect(inset.grow(4), Color("101d3c"))
	focus_canvas.draw_rect(inset, Color("fff6de"))
	var origin = inset.get_center()
	for entry in mechanisms:
		var at: Vector2 = entry.body.position if entry.has("body") else entry.position
		var target = origin + (at - center) * 0.65
		if inset.grow(-15).has_point(target):
			focus_canvas.draw_rect(Rect2(target - entry.size * 0.325, entry.size * 0.65).intersection(inset), Color("fa7854") if entry.kind == "gate" else Color("00b9c5"))
	for actor in moving_objects():
		var target = origin + (actor.position - center) * 0.65
		var size_ = actor.extent * 0.65
		if inset.grow(-35).has_point(target) and actor.sprite.texture:
			focus_canvas.draw_texture_rect(actor.sprite.texture, Rect2(target - size_ * 0.5, size_), false, Color("8effef") if actor.player_tool else Color.WHITE)
	focus_canvas.draw_arc(origin, 37, 0, TAU, 48, Color("fa7854") if state == State.FAILURE else Color("ffbe40"), 3, true)
