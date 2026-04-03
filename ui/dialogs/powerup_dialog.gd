extends Control

signal powerup_chosen(powerup: Dictionary, grade: int)

const PowerupCard = preload("res://ui/components/PowerupCard.tscn")

@onready var card_container: HBoxContainer = $MarginContainer/VBox/CardContainer
@onready var title_label:    Label         = $MarginContainer/VBox/TitleLabel
@onready var dim_rect:       ColorRect     = $DimRect

func _ready() -> void:
	visible = false
	dim_rect.visible = false
	card_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_container.size_flags_stretch_ratio = 4.0


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


func _on_card_chosen(pu: Dictionary, grade: int) -> void:
	visible = false
	dim_rect.visible = false
	powerup_chosen.emit(pu, grade)

