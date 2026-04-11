class_name PowerupCard
extends PanelContainer

signal card_chosen(powerup: Dictionary, grade: int)

const ICON_PLACEHOLDER = preload("res://assets/images/loot/material-1.png")

@onready var icon_rect:  TextureRect = $MarginContainer/VBox/IconSizeBox/IconRect
@onready var name_label: Label = $MarginContainer/VBox/BottomMargin/BottomVBox/NameLabel
@onready var count_label: Label = $MarginContainer/VBox/BottomMargin/BottomVBox/CountLabel
@onready var desc_label: Label = $MarginContainer/VBox/BottomMargin/BottomVBox/DescLabel

var _powerup: Dictionary
var _grade: int

func setup(pu: Dictionary, grade: int) -> void:
	_powerup = pu
	_grade   = grade
	
	icon_rect.texture = ICON_PLACEHOLDER
	
	var relative_grade: int = grade - pu.get("min_grade", 1) + 1
	name_label.text = "%s  +%d" % [pu["name"], relative_grade]
	
	var powerupId: String = pu.get("id", "")
	var current_count: int = 0
	if RunState.active_powerups.has(powerupId):
		current_count = RunState.active_powerups.get(powerupId, 0)
	count_label.text = "Currently: %s" % current_count
	
	desc_label.text = pu["description"]
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	_apply_style(false)
	mouse_entered.connect(func(): _apply_style(true))
	mouse_exited.connect(func():  _apply_style(false))


func _apply_style(hovered: bool) -> void:
	var color := GameData.get_grade_color(_grade)
	var style := StyleBoxFlat.new()
	style.bg_color     = Color("#234146c0")
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color = color
	style.corner_radius_bottom_left  = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_top_left     = 16
	style.corner_radius_top_right    = 16
	style.shadow_color = Color(color.r, color.g, color.b, 0.4 if hovered else 0.2)
	style.shadow_size  = 12 if hovered else 8
	add_theme_stylebox_override("panel", style)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			SoundManager.play_ui("pu_select")
			card_chosen.emit(_powerup, _grade)


func _ready() -> void:
	mouse_entered.connect(func(): SoundManager.play_ui("pu_hover"))

