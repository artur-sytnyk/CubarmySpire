class_name RunFinalizedDialog
extends Control

signal confirmed

const MATERIAL_BOX_SIZE: int = 48

@onready var _stages_label: Label = $PanelContainer/MarginContainer/VBox/TitleRow/StagesLabel
@onready var _gold_label: Label = $PanelContainer/MarginContainer/VBox/GoldRow/GoldLabel
@onready var _materials_row: HBoxContainer = $PanelContainer/MarginContainer/VBox/MaterialsRow
@onready var _confirm_btn: Button = $PanelContainer/MarginContainer/VBox/ConfirmButton


func _ready() -> void:
	visible = false
	_confirm_btn.pressed.connect(func() -> void:
		confirmed.emit()
		SceneManager.go_to("res://scenes/menus/Campaign.tscn", true)
	)


func show_results(data: Dictionary) -> void:
	var stage: int = data.get("stage", 0)
	var is_record: bool = data.get("is_record", false)
	var gold: int = data.get("gold", 0)
	var materials: Dictionary = data.get("materials", {})
	
	if is_record:
		_stages_label.text = "You have cleared %d stages - new highest!" % stage
	else:
		_stages_label.text = "You have cleared %d stages" % stage
	_gold_label.text = "%d gold collected" % gold
	
	_populate_materials(materials)
	show()


func _populate_materials(materials: Dictionary) -> void:
	for child in _materials_row.get_children():
		child.queue_free()
	
	if materials.is_empty():
		return
	
	var tiers: Array = materials.keys()
	tiers.sort()
	
	for tier: int in tiers:
		var count: int = materials[tier]
		if count <= 0:
			continue
		_materials_row.add_child(_make_material_box(tier, count))


func _make_material_box(tier: int, count: int) -> Control:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(MATERIAL_BOX_SIZE, MATERIAL_BOX_SIZE + 22)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var texture_rect := TextureRect.new()
	texture_rect.texture = load("res://assets/images/material-1.png")
	texture_rect.custom_minimum_size = Vector2(MATERIAL_BOX_SIZE, MATERIAL_BOX_SIZE)
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.modulate = GameData.get_grade_color(tier)

	var amount_label := Label.new()
	amount_label.text = str(count)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_label.add_theme_font_size_override("font_size", 14)

	vbox.add_child(texture_rect)
	vbox.add_child(amount_label)
	return vbox

