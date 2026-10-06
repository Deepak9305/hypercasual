class_name LevelDefinition
extends Resource
@export var id: String = ""
@export var title: String = ""
@export var chapter: int = 0
@export var background: String = "courtyard"
@export var courier_start: Vector2 = Vector2(170, 1040)
@export var courier_speed: float = 92.0
@export var hazards: Array[Dictionary] = []
@export var candidates: PackedStringArray = PackedStringArray(["umbrella", "ramp", "spring", "crate", "fan"])
@export var rescue_x: float = 690.0
@export var timeout: float = 13.0
@export var freeze_at: float = 0.35
@export var auto_freeze: bool = true
@export var tool_budget: int = 2
@export var par_tools: int = 2
@export var solution: Array[Dictionary] = []
@export var hints: PackedStringArray = PackedStringArray()
@export var environment: Array[Dictionary] = []
