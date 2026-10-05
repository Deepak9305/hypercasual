class_name GameActor
extends CharacterBody2D
var kind: String = "crate"
var motion: String = "fall"
var extent: Vector2 = Vector2(135, 135)
var delay: float = 0.0
var gravity: float = 650.0
var deflected: bool = false
var spin: float = 0.0
var sprite: Sprite2D
var collider: CollisionShape2D
var elapsed: float = 0.0

func configure(data: Dictionary) -> void:
	kind = data.get("kind", "crate")
	motion = data.get("motion", "fall")
	extent = data.get("size", Vector2(135, 135))
	position = data.get("position", Vector2.ZERO)
	velocity = data.get("velocity", Vector2.ZERO)
	delay = data.get("delay", 0.0)
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	collider = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = extent * 0.8
	collider.shape = shape
	add_child(collider)
	sprite = Sprite2D.new()
	add_child(sprite)
	var art_path = "res://assets/art/hazard_%s.png" % kind
	if ResourceLoader.exists(art_path):
		sprite.texture = load(art_path)
	elif ResourceLoader.exists("res://assets/art/hazard_crate.png"):
		sprite.texture = load("res://assets/art/hazard_crate.png")
	if sprite.texture:
		var fit = minf(extent.x / sprite.texture.get_width(), extent.y / sprite.texture.get_height())
		sprite.scale = Vector2.ONE * fit
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
	if deflected:
		sprite.rotation += spin * delta
	return move_and_collide(velocity * delta)

func redirect(prop_kind: String) -> void:
	deflected = true
	collision_mask = 1
	if prop_kind == "ramp":
		velocity = Vector2(360, -530)
	elif prop_kind == "awning":
		velocity = Vector2(300, -280)
	else:
		velocity = Vector2(270, -320)
	spin = 2.2

