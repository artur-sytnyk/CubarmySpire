extends Control

const GRADE_NAMES := {
	1: "Common",
	2: "Uncommon",
	3: "Rare",
	4: "Epic",
	5: "Legendary",
}
const GRADE_COLORS := {
	1: Color(0.70, 0.70, 0.70),
	2: Color(0.30, 0.75, 0.35),
	3: Color(0.30, 0.55, 0.90),
	4: Color(0.65, 0.30, 0.90),
	5: Color(0.95, 0.55, 0.15),
}

const SLOT_KEYS   :Array = ["weapon", "armor", "artifact_1", "artifact_2", "artifact_3"]
const SLOT_LABELS :Array = ["Weapon", "Armor", "Artifact I", "Artifact II", "Artifact III"]

@onready var _slots_vbox: VBoxContainer     = $NavBarMargin/HBoxContainer/LeftPanel/MarginContainer/VBoxContainer/SlotsVBox
@onready var _item_icon: ColorRect          = $NavBarMargin/HBoxContainer/RightPanel/MarginContainer/VBoxContainer/DetailPanel/MarginContainer/HBoxContainer/ItemIcon
@onready var _item_name_label: Label        = $NavBarMargin/HBoxContainer/RightPanel/MarginContainer/VBoxContainer/DetailPanel/MarginContainer/HBoxContainer/InfoVBox/TitleRow/ItemNameLabel
@onready var _item_grade_label: Label       = $NavBarMargin/HBoxContainer/RightPanel/MarginContainer/VBoxContainer/DetailPanel/MarginContainer/HBoxContainer/InfoVBox/TitleRow/ItemGradeLabel
@onready var _item_desc_label: Label        = $NavBarMargin/HBoxContainer/RightPanel/MarginContainer/VBoxContainer/DetailPanel/MarginContainer/HBoxContainer/InfoVBox/ItemDescLabel
@onready var _equip_btn: Button             = $NavBarMargin/HBoxContainer/RightPanel/MarginContainer/VBoxContainer/DetailPanel/MarginContainer/HBoxContainer/InfoVBox/ActionsRow/EquipBtn
@onready var _sell_btn: Button              = $NavBarMargin/HBoxContainer/RightPanel/MarginContainer/VBoxContainer/DetailPanel/MarginContainer/HBoxContainer/InfoVBox/ActionsRow/SellBtn
@onready var _dismantle_btn: Button             = $NavBarMargin/HBoxContainer/RightPanel/MarginContainer/VBoxContainer/DetailPanel/MarginContainer/HBoxContainer/InfoVBox/ActionsRow/DismantleBtn
@onready var _inventory_flow: FlowContainer = $NavBarMargin/HBoxContainer/RightPanel/MarginContainer/VBoxContainer/InventoryScroll/InventoryFlow

var _selected: Dictionary = {}

func _ready() -> void:
	_equip_btn.pressed.connect(_on_equip_pressed)
	_sell_btn.pressed.connect(_on_sell_pressed)
	_dismantle_btn.pressed.connect(_on_dismantle_pressed)
	_clear_detail()
	_refresh()

# ── Refresh ────────────────────────────────────────────────────────────────

func _refresh() -> void:
	var save := SaveManager.current_save
	if save == null:
		return
	_refresh_slots(save)
	_refresh_inventory(save)
	_refresh_detail(save)

func _refresh_slots(save: SaveData) -> void:
	var equipped: Dictionary = {}
	for item in save.equipment_inv:
		var s: String = item.get("equipped_slot", "")
		if s != "":
			equipped[s] = item

	var slot_panels := _slots_vbox.get_children()
	for i in range(slot_panels.size()):
		var panel: PanelContainer = slot_panels[i]
		for child in panel.get_children():
			child.queue_free()

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left",   6)
		margin.add_theme_constant_override("margin_right",  6)
		margin.add_theme_constant_override("margin_top",    6)
		margin.add_theme_constant_override("margin_bottom", 6)
		panel.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		margin.add_child(vbox)

		var slot_lbl := Label.new()
		slot_lbl.text = SLOT_LABELS[i]
		slot_lbl.add_theme_font_size_override("font_size", 11)
		slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(slot_lbl)

		var key: String = SLOT_KEYS[i]
		if equipped.has(key):
			var item: Dictionary = equipped[key]
			var def: Dictionary = GameData.get_equipment(item.get("id", ""))
			var grade: int = item.get("grade", 1)

			var name_lbl := Label.new()
			name_lbl.text = _display_name(def, grade)
			name_lbl.add_theme_font_size_override("font_size", 11)
			name_lbl.add_theme_color_override("font_color", GRADE_COLORS.get(grade, Color.WHITE))
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(name_lbl)

			var btn := Button.new()
			btn.flat = true
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.focus_mode = Control.FOCUS_NONE
			btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			btn.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
			btn.pressed.connect(_on_slot_clicked.bind(item))
			btn.mouse_entered.connect(func():
				panel.self_modulate.a = 0.6
			)
			btn.mouse_exited.connect(func():
				panel.self_modulate = Color(1, 1, 1, 1)
			)
			panel.add_child(btn)
		else:
			var empty_lbl := Label.new()
			empty_lbl.text = "— empty —"
			empty_lbl.add_theme_font_size_override("font_size", 10)
			empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(empty_lbl)

func _refresh_inventory(save: SaveData) -> void:
	for child in _inventory_flow.get_children():
		child.queue_free()
	var stacks := _stack_items(save.equipment_inv)
	var sorted_keys := stacks.keys()
	sorted_keys.sort()
	for key in sorted_keys:
		_inventory_flow.add_child(_make_item_box(stacks[key]))

func _refresh_detail(save: SaveData) -> void:
	if _selected.is_empty():
		return
	var stacks := _stack_items(save.equipment_inv)
	if not stacks.has(_stack_key(_selected)):
		_selected = {}
		_clear_detail()
		return
	_show_detail(_selected)

# ── Stacking ───────────────────────────────────────────────────────────────

func _stack_items(equipment_inv: Array) -> Dictionary:
	var stacks: Dictionary = {}
	for item in equipment_inv:
		var key := _stack_key(item)
		if not stacks.has(key):
			stacks[key] = {
				"id":            item.get("id", ""),
				"level":         item.get("level", 1),
				"grade":         item.get("grade", 1),
				"equipped_slot": item.get("equipped_slot", ""),
				"count":         0,
			}
		stacks[key].count += 1
	return stacks

func _stack_key(item: Dictionary) -> String:
	return "%s_%d_%d" % [item.get("id", ""), item.get("level", 1), item.get("grade", 1)]

# ── Helpers ────────────────────────────────────────────────────────────────

func _display_name(def: Dictionary, grade: int) -> String:
	return "%s %s" % [GRADE_NAMES.get(grade, ""), def.get("name", "?")]

func _calc_effect(def: Dictionary, level: int, grade: int) -> float:
	var base: float     = def.get("base_value", 0.0)
	var grade_mult: float = 1.0 + (grade - 1) * 0.10
	return base * level * grade_mult

# ── Item box ───────────────────────────────────────────────────────────────

func _make_item_box(stack: Dictionary) -> Control:
	var def: Dictionary  = GameData.get_equipment(stack.get("id", ""))
	var grade: int       = stack.get("grade", 1)
	var level: int       = stack.get("level", 1)
	var count: int       = stack.get("count", 1)
	var is_equipped: bool = stack.get("equipped_slot", "") != ""

	var container := Control.new()
	container.custom_minimum_size = Vector2(72, 72)
	var effect_pct := _calc_effect(def, level, grade) * 100.0
	container.tooltip_text = "%s\nLv.%d  •  %s\n+%.1f%% %s%s" % [
		_display_name(def, grade),
		level,
		GRADE_NAMES.get(grade, "?"),
		effect_pct,
		def.get("stat", ""),
		"  [Equipped]" if is_equipped else "",
	]

	var base_color: Color = GRADE_COLORS.get(grade, Color(0.4, 0.4, 0.4))

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = base_color.darkened(0.45)
	container.add_child(bg)

	if is_equipped:
		var equip_bar := ColorRect.new()
		equip_bar.color = base_color
		equip_bar.set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
		equip_bar.size = Vector2(6, 72)
		container.add_child(equip_bar)

	var level_lbl := Label.new()
	level_lbl.text = "Lv.%d" % level
	level_lbl.add_theme_font_size_override("font_size", 10)
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	level_lbl.offset_top = -18.0
	container.add_child(level_lbl)

	if count > 1:
		var badge := PanelContainer.new()
		badge.custom_minimum_size = Vector2(20, 20)
		badge.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
		badge.offset_left   = -24.0
		badge.offset_bottom =  24.0
		container.add_child(badge)

		var badge_lbl := Label.new()
		badge_lbl.text = str(count)
		badge_lbl.add_theme_font_size_override("font_size", 10)
		badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(badge_lbl)

	if not _selected.is_empty() and _stack_key(_selected) == _stack_key(stack):
		var highlight := ColorRect.new()
		highlight.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		highlight.color = Color(1.0, 0.85, 0.3, 0.22)
		container.add_child(highlight)

	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	btn.pressed.connect(_on_item_box_clicked.bind(stack))
	container.add_child(btn)

	return container

# ── Detail panel ───────────────────────────────────────────────────────────

func _show_detail(stack: Dictionary) -> void:
	var def: Dictionary  = GameData.get_equipment(stack.get("id", ""))
	var slot: String       = def.get("slot", "artifact")
	var grade: int       = stack.get("grade", 1)
	var level: int       = stack.get("level", 1)
	var is_equipped: bool = stack.get("equipped_slot", "") != ""
	var grade_color: Color = GRADE_COLORS.get(grade, Color.WHITE)
	var effect_pct        := _calc_effect(def, level, grade) * 100.0

	_item_icon.color = grade_color.darkened(0.3)
	_item_name_label.text = _display_name(def, grade)
	_item_name_label.add_theme_color_override("font_color", grade_color)

	_item_grade_label.text = "%s  •  Lv %d  •  %s" % [slot, level, GRADE_NAMES.get(grade, "?")]
	_item_grade_label.add_theme_color_override("font_color", grade_color.darkened(0.15))

	_item_desc_label.text = def.get("description", "No description.")
	_item_desc_label.text += " +%.1f%% %s" % [effect_pct, def.get("stat", "")]

	_equip_btn.text    = "Unequip" if is_equipped else "Equip"
	_equip_btn.visible = true
	_sell_btn.visible  = not is_equipped
	_dismantle_btn.visible = not is_equipped

func _clear_detail() -> void:
	_item_icon.color       = Color(0.12, 0.12, 0.16)
	_item_name_label.text  = "Select an item"
	_item_grade_label.text = ""
	_item_desc_label.text  = ""
	_equip_btn.visible     = false
	_sell_btn.visible      = false
	_dismantle_btn.visible     = false

# ── Click handlers ─────────────────────────────────────────────────────────

func _on_item_box_clicked(stack: Dictionary) -> void:
	if not _selected.is_empty() and _stack_key(_selected) == _stack_key(stack):
		_selected = {}
		_clear_detail()
	else:
		_selected = stack
		_show_detail(stack)
	call_deferred("_refresh_inventory", SaveManager.current_save)

func _on_slot_clicked(item: Dictionary) -> void:
	_selected = item
	_show_detail(item)
	call_deferred("_refresh_inventory", SaveManager.current_save)

func _on_equip_pressed() -> void:
	var save := SaveManager.current_save
	var def: Dictionary = GameData.get_equipment(_selected.get("id", ""))
	var target_slot: String = _selected.get("equipped_slot", "")

	if target_slot != "":
		# Unequip — find the matching item in equipment_inv and clear its slot.
		for item in save.equipment_inv:
			if item.get("id") == _selected.get("id") \
			and item.get("level") == _selected.get("level") \
			and item.get("grade") == _selected.get("grade") \
			and item.get("equipped_slot") == target_slot:
				item["equipped_slot"] = ""
				break
	else:
		# Equip — check same id not already equipped anywhere.
		for item in save.equipment_inv:
			if item.get("id") == _selected.get("id") and item.get("equipped_slot", "") != "":
				_show_error("This item is already equipped.")
				return
		# Find first free slot of the correct type.
		var slot := _find_free_slot(def.get("slot", ""), save)
		if slot == "":
			_show_error("No free %s slot." % def.get("slot", ""))
			return
		for item in save.equipment_inv:
			if item.get("id") == _selected.get("id") \
			and item.get("level") == _selected.get("level") \
			and item.get("grade") == _selected.get("grade") \
			and item.get("equipped_slot", "") == "":
				item["equipped_slot"] = slot
				break
	
	SaveManager.save_current()
	_selected = {}
	_clear_detail()
	call_deferred("_refresh")


func _find_free_slot(slot_type: String, save: SaveData) -> String:
	var equipped_slots: Array = []
	for item in save.equipment_inv:
		var s: String = item.get("equipped_slot", "")
		if s != "":
			equipped_slots.append(s)
	if slot_type == "artifact":
		for candidate in ["artifact_1", "artifact_2", "artifact_3"]:
			if not equipped_slots.has(candidate):
				return candidate
		return ""
	if not equipped_slots.has(slot_type):
		return slot_type
	return ""


func _on_sell_pressed() -> void:
	# TODO: sell — add gold, remove one from stack
	pass


func _on_dismantle_pressed() -> void:
	# TODO: scrap — add materials, remove one from stack
	pass


func _show_error(msg: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = msg
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)

