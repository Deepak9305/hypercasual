class_name LevelDefinition
extends Resource
## Resource-backed authored scene data, reusable by game and solution tests.
@export var title: String = ""
@export var chapter: int = 0
@export var background: String = "courtyard"
@export var courier_start: Vector2 = Vector2(170, 1040)
@export var courier_speed: float = 92.0
@export var hazards: Array[Dictionary] = []
@export var candidates: PackedStringArray = PackedStringArray(["umbrella", "ramp", "spring"])
@export var rescue_x: float = 690.0
@export var timeout: float = 11.0
@export var freeze_at: float = 0.48
@export var solution_prop: String = "umbrella"
@export var solution_position: Vector2 = Vector2(320, 740)
@export var hints: PackedStringArray = PackedStringArray()
@export var mechanism: String = ""

