extends Control

signal powerup_chosen(powerup: Dictionary, grade: int)

const PowerupCard = preload("res://ui/components/PowerupCard.tscn")

@onready var card_container: HBoxContainer = $Panel/MarginContainer/VBox/CardContainer
@onready var title_label:    Label         = $Panel/MarginContainer/VBox/TitleLabel
@onready var panel:          PanelContainer = $Panel
@onready var dim_rect:       ColorRect     = $DimRect

func _ready() -> void:
	visible = false
	dim_rect.visible = false
	title_label.text = "Floor cleared - Select a powerup"
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_label.size_flags_stretch_ratio = 1.0
	
	card_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_container.size_flags_stretch_ratio = 4.0
	
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left     = 12
	style.corner_radius_top_right    = 12
	style.corner_radius_bottom_left  = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)

func show_offers(offers: Array) -> void:
	for child in card_container.get_children():
		child.queue_free()
	for offer in offers:
		var card: PowerupCard = PowerupCard.instantiate()
		card_container.add_child(card)
		card.setup(offer["powerup"], offer["grade"])
		card.card_chosen.connect(_on_card_chosen)
	dim_rect.visible = true
	visible = true
	_center_panel()

func _center_panel() -> void:
	var vp := get_viewport_rect().size
	var target_size := vp * 0.75
	panel.custom_minimum_size = target_size
	panel.size = target_size
	panel.position = (vp - target_size) / 2.0

func _on_card_chosen(pu: Dictionary, grade: int) -> void:
	visible = false
	dim_rect.visible = false
	powerup_chosen.emit(pu, grade)

