class_name ItemBox
extends PanelContainer


signal pressed


@onready var _bg_rect: ColorRect = $BgRect
@onready var _icon: TextureRect = $IconMargin/Icon
@onready var _level_label: Label = $LabelsMargin/LevelLabel
@onready var _count_label: Label = $LabelsMargin/CountLabel
@onready var _slot_label: Label = $LabelsMargin/SlotLabel


var _grade: int = 0


func setup(
		p_icon: Texture2D,
		p_grade: int,
		p_level: int = 0,
		p_count: int = 0,
		p_slot: String = ""
) -> void:
	_grade = p_grade
	_icon.texture = p_icon
	_bg_rect.color = GameData.get_grade_color(p_grade)

	_level_label.visible = p_level > 0
	if p_level > 0:
		_level_label.text = "lv %d" % p_level

	_count_label.visible = p_count > 1
	if p_count > 1:
		_count_label.text = "x%d" % p_count

	_slot_label.visible = p_slot != ""
	if p_slot != "":
		_slot_label.text = p_slot


func set_grade(p_grade: int) -> void:
	_grade = p_grade
	_bg_rect.color = GameData.get_grade_color(p_grade)


func set_level(p_level: int) -> void:
	_level_label.visible = p_level > 0
	if p_level > 0:
		_level_label.text = "lv %d" % p_level


func set_count(p_count: int) -> void:
	_count_label.visible = p_count > 1
	if p_count > 1:
		_count_label.text = "x%d" % p_count


func set_slot(p_slot: String) -> void:
	_slot_label.visible = p_slot != ""
	if p_slot != "":
		_slot_label.text = p_slot


func set_icon(p_icon: Texture2D) -> void:
	_icon.texture = p_icon


func show_highlight(p_visible: bool) -> void:
	var existing: Node = get_node_or_null("Highlight")
	if existing != null:
		existing.visible = p_visible
		return
	var hl := ColorRect.new()
	hl.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	hl.color = Color(1.0, 0.85, 0.3, 0.3)
	hl.name = "Highlight"
	add_child(hl)
	hl.visible = p_visible


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		pressed.emit()
