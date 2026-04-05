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
	var difficulty: String = data.get("difficulty", "easy")
	var is_record: bool = data.get("is_record", false)
	var gold: int = data.get("gold", 0)
	var materials: Dictionary = data.get("materials", {})
	
	if is_record:
		_stages_label.text = "You have cleared %d stages - new highest for %s difficulty!" % [stage, difficulty]
	else:
		_stages_label.text = "You have cleared %d stages" % stage
	_gold_label.text = "%d gold collected" % gold
	
	_populate_materials(materials)
	show()


func _populate_materials(materials: Dictionary) -> void:
	for tier: int in range(1, 6):
		var row: VBoxContainer = _materials_row.get_node_or_null("MaterialT" + str(tier))
		if row == null:
			continue
		var count: int = materials.get(tier, 0)
		if count <= 0:
			row.visible = false
			continue
		row.visible = true
		row.get_node("IconSizeBox/Icon").modulate = GameData.get_grade_color(tier)
		row.get_node("Amount").text = str(count)

