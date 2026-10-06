class_name GameActor
extends CharacterBody2D
var kind: String = "crate"
var motion: String = "fall"
var extent: Vector2 = Vector2(100, 100)
var delay: float = 0.0
var gravity: float = 650.0
var deflected: bool = false
var secured: bool = false
var supported: bool = false
var player_tool: bool = false
var spin: float = 0.0
var sprite: Sprite2D
var collider: CollisionShape2D
var elapsed: float = 0.0
var redirect_cooldowns: Dictionary = {}

func configure(data: Dictionary) -> void:
	kind = data.get("kind", "crate")
	motion = data.get("motion", "fall")
	extent = data.get("size", Vector2(100, 100))
	position = data.get("position", Vector2.ZERO)
	velocity = data.get("velocity", Vector2.ZERO)
	delay = data.get("delay", 0.0)
	player_tool = data.get("player_tool", false)
	collision_layer = 2
	collision_mask = 1 | 2 | 4 | 8
	collider = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = extent * 0.8
	collider.shape = shape
	add_child(collider)
	sprite = Sprite2D.new()
	add_child(sprite)
	var art_path = "res://assets/art/hazard_%s.png" % kind
	sprite.texture = load(art_path) if ResourceLoader.exists(art_path) else load("res://assets/art/hazard_crate.png")
	if sprite.texture:
		sprite.scale = Vector2.ONE * minf(extent.x / sprite.texture.get_width(), extent.y / sprite.texture.get_height())
	if player_tool:
		sprite.modulate = Color("8effef")
	z_index = 8

func step(delta: float) -> KinematicCollision2D:
	elapsed += delta
	if elapsed < delay:
		return null
	if motion != "roll" or deflected:
		velocity.y += gravity * delta
	if motion == "wind" and not deflected:
		velocity.x -= 12.0 * delta
	if motion == "swing" and elapsed > 0.85 and not deflected:
		velocity.x *= 0.985
	if deflected and not secured:
		sprite.rotation += spin * delta
	var hit = move_and_collide(velocity * delta)
	supported = hit != null and hit.get_normal().y < -0.5
	if hit and hit.get_normal().y < -0.5:
		move_and_collide(hit.get_remainder().slide(hit.get_normal()))
	return hit

func redirect(prop_kind: String, direction: int = 0) -> void:
	deflected = true
	secured = false
	# Redirecting changes momentum, never the hazard's collision targets.
	var side = -1.0 if direction == 4 else 1.0
	velocity = Vector2(360 * side, -530) if prop_kind == "ramp" else Vector2(180 * side, -180)
	if prop_kind == "spring":
		velocity = Vector2(160 * side, -650)
	spin = 2.2 * side

func snapshot() -> Dictionary:
	return {"position": position, "velocity": velocity, "elapsed": elapsed, "deflected": deflected, "secured": secured, "supported": supported, "rotation": sprite.rotation, "cooldowns": redirect_cooldowns.duplicate(true)}

func restore(data: Dictionary) -> void:
	position = data.position
	velocity = data.velocity
	elapsed = data.elapsed
	deflected = data.deflected
	secured = data.secured
	supported = data.supported
	sprite.rotation = data.rotation
	redirect_cooldowns = data.cooldowns.duplicate(true)
