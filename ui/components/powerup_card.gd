class_name PowerupCard
extends PanelContainer

signal card_chosen(powerup: Dictionary, grade: int)

const ICON_PLACEHOLDER = preload("res://assets/images/material-1.png")

@onready var icon_rect:  TextureRect = $VBox/IconRect
@onready var name_label: Label = $VBox/BottomMargin/BottomVBox/NameLabel
@onready var desc_label: Label = $VBox/BottomMargin/BottomVBox/DescLabel

var _powerup: Dictionary
var _grade: int

func setup(pu: Dictionary, grade: int) -> void:
	_powerup = pu
	_grade   = grade
	
	icon_rect.texture = ICON_PLACEHOLDER
	
	var relative_grade: int = grade - pu.get("min_grade", 1) + 1
	name_label.text = "%s  +%d" % [pu["name"], relative_grade]
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	desc_label.text = pu["description"]
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	_apply_style(false)
	mouse_entered.connect(func(): _apply_style(true))
	mouse_exited.connect(func():  _apply_style(false))


func _apply_style(hovered: bool) -> void:
	var color := GameData.get_grade_color(_grade)
	var style := StyleBoxFlat.new()
	style.bg_color     = Color("#2a2a3e80") if hovered else Color("#1e1e2e80")
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color = color
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.shadow_color = Color(color.r, color.g, color.b, 0.4 if hovered else 0.2)
	style.shadow_size  = 16 if hovered else 8
	style.content_margin_left   = 8
	style.content_margin_right  = 8
	style.content_margin_top    = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		card_chosen.emit(_powerup, _grade)

