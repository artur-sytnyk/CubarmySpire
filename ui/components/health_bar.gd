class_name HealthBar
extends Node2D

@onready var background: ColorRect = $MaxHpBar
@onready var fill: ColorRect = $CurrentHpBar

const FULL_WIDTH: float = 28.0
const HEIGHT: float = 3.0
#const OFFSET: Vector2 = Vector2(-16.0, -24.0)

func _ready() -> void:
	#position = OFFSET
	background.size = Vector2(FULL_WIDTH, HEIGHT)
	fill.size = Vector2(FULL_WIDTH, HEIGHT)

func update(hp_current: int, hp_max: int) -> void:
	var ratio: float = float(hp_current) / float(hp_max)
	fill.size.x = FULL_WIDTH * ratio
