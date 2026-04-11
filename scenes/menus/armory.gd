extends Control

const SLOT_KEYS   :Array = ["weapon", "armor", "artifact_1", "artifact_2", "artifact_3"]
const SLOT_LABELS :Array = ["Weapon", "Armor", "Artifact I", "Artifact II", "Artifact III"]
const SLOT_NODE_NAMES: Array = ["WeaponBox", "ArmorBox", "Artifact1Box", "Artifact2Box", "Artifact3Box"]
const ITEM_BOX_SCENE: PackedScene = preload("res://objects/item_box/ItemBox.tscn")
const ITEM_ICON_PATH: String = "res://assets/images/items/%s.png"

@onready var _slots_vbox: VBoxContainer     = $NavBarMargin/HBoxContainer/LeftPanel/MarginContainer/VBoxContainer/SlotsVBox
@onready var _weapon_box: ItemBox     = $NavBarMargin/HBoxContainer/LeftPanel/MarginContainer/VBoxContainer/SlotsVBox/WeaponBox
@onready var _item_icon: ItemBox          = $NavBarMargin/HBoxContainer/RightPanel/MarginContainer/VBoxContainer/DetailPanel/MarginContainer/HBoxContainer/ItemIcon
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
	for item: Dictionary in save.equipment_inv:
		var s: String = item.get("equipped_slot", "")
		if s != "":
			equipped[s] = item

	for i: int in range(SLOT_KEYS.size()):
		var box: ItemBox = _slots_vbox.get_node(SLOT_NODE_NAMES[i])
		var key: String = SLOT_KEYS[i]

		if equipped.has(key):
			var item: Dictionary = equipped[key]
			var item_id: String = item.get("id", "")
			var grade: int = item.get("grade", 1)
			var level: int = item.get("level", 1)
			var icon_path: String = ITEM_ICON_PATH % item_id
			var icon: Texture2D = load(icon_path) if ResourceLoader.exists(icon_path) else null
			box.setup(icon, grade, level, 0, SLOT_LABELS[i])
		else:
			box.setup(null, 1, 0, 0, SLOT_LABELS[i])


func _refresh_inventory(save: SaveData) -> void:
	for child: Node in _inventory_flow.get_children():
		child.queue_free()
	var stacks: Dictionary = _stack_items(save.equipment_inv)
	var sorted_keys: Array = stacks.keys()
	sorted_keys.sort_custom(func(a: String, b: String) -> bool:
		var sa: Dictionary = stacks[a]
		var sb: Dictionary = stacks[b]
		var a_equipped: bool = sa.get("equipped_slot", "") != ""
		var b_equipped: bool = sb.get("equipped_slot", "") != ""
		if a_equipped != b_equipped:
			return a_equipped
		return sa.get("level", 1) > sb.get("level", 1)
	)
	for key: String in sorted_keys:
		_make_item_box(stacks[key])


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
	return "%s %s" % [GameData.get_grade_name(grade), def.get("name", "?")]


func _calc_effect(def: Dictionary, level: int, grade: int) -> float:
	var base: float     = def.get("base_value", 0.0)
	var grade_mult: float = 1.0 + (grade - 1) * 0.10
	return base * level * grade_mult


# ── Item box ───────────────────────────────────────────────────────────────

func _make_item_box(stack: Dictionary) -> void:
	var def: Dictionary   = GameData.get_equipment(stack.get("id", ""))
	var grade: int        = stack.get("grade", 1)
	var level: int        = stack.get("level", 1)
	var count: int        = stack.get("count", 1)
	var is_equipped: bool = stack.get("equipped_slot", "") != ""
	var item_id: String   = stack.get("id", "")

	var box: ItemBox = ITEM_BOX_SCENE.instantiate()
	_inventory_flow.add_child(box)  # tree first, @onready populates here

	var icon_path: String = ITEM_ICON_PATH % item_id
	var icon: Texture2D = load(icon_path) if ResourceLoader.exists(icon_path) else null
	box.setup(icon, grade, level, count)

	var effect_pct: float = _calc_effect(def, level, grade) * 100.0
	box.tooltip_text = "%s\nLv.%d  •  %s\n+%.1f%% %s%s" % [
		_display_name(def, grade),
		level,
		GameData.get_grade_name(grade),
		effect_pct,
		def.get("stat", ""),
		"  [Equipped]" if is_equipped else "",
	]

	if is_equipped:
		box.set_slot("Equipped")
	if not _selected.is_empty() and _stack_key(_selected) == _stack_key(stack):
		box.show_highlight(true)

	box.pressed.connect(_on_item_box_clicked.bind(stack))


# ── Detail panel ───────────────────────────────────────────────────────────

func _show_detail(stack: Dictionary) -> void:
	var def: Dictionary  = GameData.get_equipment(stack.get("id", ""))
	var slot: String       = def.get("slot", "artifact")
	var grade: int       = stack.get("grade", 1)
	var level: int       = stack.get("level", 1)
	var is_equipped: bool = stack.get("equipped_slot", "") != ""
	var grade_color: Color = GameData.get_grade_color(grade)
	var effect_pct        := _calc_effect(def, level, grade) * 100.0

	var icon_path: String = ITEM_ICON_PATH % stack.get("id", "")
	var icon: Texture2D = load(icon_path) if ResourceLoader.exists(icon_path) else null
	_item_icon.setup(icon, grade)
	_item_name_label.text = _display_name(def, grade)
	_item_name_label.add_theme_color_override("font_color", grade_color)

	_item_grade_label.text = "Lv %d  •   %s  •  %s" % [level, GameData.get_grade_name(grade), slot.capitalize()]
	#_item_grade_label.add_theme_color_override("font_color", grade_color.darkened(0.15))

	_item_desc_label.text = def.get("description", "No description.")
	_item_desc_label.text += " +%.1f%% %s" % [effect_pct, def.get("stat", "")]

	_equip_btn.text    = "Unequip" if is_equipped else "Equip"
	_equip_btn.visible = true
	_sell_btn.visible  = not is_equipped
	_dismantle_btn.visible = not is_equipped

func _clear_detail() -> void:
	#_item_icon.color       = Color(0.12, 0.12, 0.16)
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
	var is_unequiping = target_slot != ""
	
	if is_unequiping:
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
	
	var _sound_key = "unequip" if is_unequiping else "equip"
	SoundManager.play_ui(_sound_key)
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

