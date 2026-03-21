extends Control

const UNIT_COLORS := {
	"warrior": Color(0.55, 0.35, 0.20),
	"ranger":  Color(0.25, 0.55, 0.35),
}
const BOX_SIZE := Vector2(72, 72)

const VANGUARD_LIMIT := 10
const RESERVES_LIMIT := 20

@onready var _vanguard_label: Label       = $NavBarMargin/HBoxContainer/WarbandPanel/MarginContainer/VBoxContainer/LimitsRow/VanguardLabel
@onready var _reserves_label: Label       = $NavBarMargin/HBoxContainer/WarbandPanel/MarginContainer/VBoxContainer/LimitsRow/ReservesLabel
@onready var _warband_flow: FlowContainer = $NavBarMargin/HBoxContainer/WarbandPanel/MarginContainer/VBoxContainer/WarbandFlow
@onready var _to_warband_btn: Button      = $NavBarMargin/HBoxContainer/MarginContainer/MidColumn/MoveButtonsRow/ToWarbandBtn
@onready var _to_garrison_btn: Button     = $NavBarMargin/HBoxContainer/MarginContainer/MidColumn/MoveButtonsRow/ToGarrisonBtn
@onready var _garrison_count_label: Label  = $NavBarMargin/HBoxContainer/GarrisonPanel/MarginContainer/VBoxContainer/GarrisonCountLabel
@onready var _garrison_flow: FlowContainer = $NavBarMargin/HBoxContainer/GarrisonPanel/MarginContainer/VBoxContainer/GarrisonFlow

var _selected_key: String = ""
var _selected_source: String = ""

func _ready() -> void:
	_to_garrison_btn.pressed.connect(_on_move_to_garrison)
	_to_warband_btn.pressed.connect(_on_move_to_warband)
	_refresh()

# ── Refresh ────────────────────────────────────────────────────────────────

func _refresh() -> void:
	var save := SaveManager.current_save
	if save == null:
		return
	_update_limit_labels(save)
	_rebuild_flow(_warband_flow, save.army_active, "warband")
	_rebuild_flow(_garrison_flow, save.army_barracks, "garrison")
	_garrison_count_label.text = "Garrisoned units: %d / %d" % [save.army_barracks.size(), GameData.GARRISON_MAX]


func _get_effective_vanguard_limit() -> int:
	var limit := VANGUARD_LIMIT
	for item in SaveManager.current_save.equipment_inv:
		if item.get("equipped_slot", "") == "":
			continue
		var def: Dictionary = GameData.get_equipment(item.get("id", ""))
		if def.get("flag", "") == "leadership":
			var level: int    = item.get("level", 1)
			var grade: int    = item.get("grade", 1)
			limit += int((def.get("base_value", 0.0) + def.get("value_per_level", 0.0) * (level - 1)) * (1.0 + (grade - 1) * 0.10))
	return limit


func _get_effective_reserves_limit() -> int:
	var limit := RESERVES_LIMIT
	for item in SaveManager.current_save.equipment_inv:
		if item.get("equipped_slot", "") == "":
			continue
		var def: Dictionary = GameData.get_equipment(item.get("id", ""))
		if def.get("flag", "") == "increase_max_limit":
			var level: int    = item.get("level", 1)
			var grade: int    = item.get("grade", 1)
			limit += int((def.get("base_value", 0.0) + def.get("value_per_level", 0.0) * (level - 1)) * (1.0 + (grade - 1) * 0.10))
	return limit


func _update_limit_labels(save: SaveData) -> void:
	var total: int             = save.army_active.size()
	var vanguard_limit: int    = _get_effective_vanguard_limit()
	var reserves_limit: int    = _get_effective_reserves_limit()
	var vanguard: int          = mini(total, vanguard_limit)
	_vanguard_label.text       = "Vanguard size: %d" % vanguard_limit
	_vanguard_label.tooltip_text = "Units that fight simultaneously on the battlefield"
	_reserves_label.text       = "Warband size:  %d / %d" % [total, reserves_limit]
	_reserves_label.tooltip_text = "Total units brought into the run"


# ── Build unit boxes ───────────────────────────────────────────────────────

func _rebuild_flow(flow: FlowContainer, unit_list: Array, source: String) -> void:
	for child in flow.get_children():
		child.queue_free()
	var groups := _group_units(unit_list)
	var sorted_keys := groups.keys()
	sorted_keys.sort()
	for key in sorted_keys:
		var g: Dictionary = groups[key]
		flow.add_child(_make_unit_box(key, g.type, g.level, g.count, source))

func _group_units(unit_list: Array) -> Dictionary:
	var groups: Dictionary = {}
	for ud in unit_list:
		var t: String = ud.get("unit_type", "unknown")
		var l: int    = ud.get("level", 1)
		var key := "%s_%d" % [t, l]
		if not groups.has(key):
			groups[key] = { "type": t, "level": l, "count": 0 }
		groups[key].count += 1
	return groups

func _make_unit_box(key: String, unit_type: String, level: int, count: int, source: String) -> Control:
	var container := Control.new()
	container.custom_minimum_size = BOX_SIZE
	container.tooltip_text = "%s  Lv.%d  ×%d" % [unit_type.capitalize(), level, count]

	# Background.
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = UNIT_COLORS.get(unit_type, Color(0.3, 0.3, 0.3))
	container.add_child(bg)

	# Level label — bottom center.
	var level_lbl := Label.new()
	level_lbl.text = "Lv.%d" % level
	level_lbl.add_theme_font_size_override("font_size", 11)
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	level_lbl.offset_top = -20.0
	container.add_child(level_lbl)

	# Count badge — top-right.
	var badge_panel := PanelContainer.new()
	badge_panel.custom_minimum_size = Vector2(24, 24)
	badge_panel.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT)
	badge_panel.offset_left   = -28.0
	badge_panel.offset_bottom =  28.0
	container.add_child(badge_panel)

	var badge_lbl := Label.new()
	badge_lbl.text = str(count)
	badge_lbl.add_theme_font_size_override("font_size", 11)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	badge_panel.add_child(badge_lbl)

	# Selection highlight.
	if _selected_key == key and _selected_source == source:
		var highlight := ColorRect.new()
		highlight.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		highlight.color = Color(1.0, 0.85, 0.3, 0.25)
		container.add_child(highlight)

	# Click button — transparent overlay on top.
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	btn.pressed.connect(_on_unit_box_clicked.bind(key, source))
	container.add_child(btn)

	return container

# ── Click handlers ─────────────────────────────────────────────────────────

func _on_unit_box_clicked(key: String, source: String) -> void:
	if _selected_key == key and _selected_source == source:
		_selected_key = ""
		_selected_source = ""
		_refresh()
		return
	_selected_key = key
	_selected_source = source
	_move_units(key, source, 1)


func _on_move_to_garrison() -> void:
	var save := SaveManager.current_save
	var space := GameData.GARRISON_MAX - save.army_barracks.size()
	if space <= 0:
		return
	var to_move := mini(save.army_active.size(), space)
	for _i in range(to_move):
		save.army_barracks.append(save.army_active[0])
		save.army_active.remove_at(0)
	SaveManager.save_current()
	_selected_key = ""
	_selected_source = ""
	call_deferred("_refresh")


func _on_move_to_warband() -> void:
	var save := SaveManager.current_save
	var space := _get_effective_reserves_limit() - save.army_active.size()
	if space <= 0:
		return
	var to_move := mini(save.army_barracks.size(), space)
	for _i in range(to_move):
		save.army_active.append(save.army_barracks[0])
		save.army_barracks.remove_at(0)
	SaveManager.save_current()
	_selected_key = ""
	_selected_source = ""
	call_deferred("_refresh")


func _move_units(key: String, source: String, amount: int) -> void:
	var save := SaveManager.current_save
	if save == null:
		return
	var parts := key.split("_")
	var unit_type: String = parts[0]
	var level: int        = int(parts[1]) if parts.size() > 1 else 1
	var from_list: Array  = save.army_active   if source == "warband" else save.army_barracks
	var to_list: Array    = save.army_barracks if source == "warband" else save.army_active
	var moved := 0
	var i := 0
	while i < from_list.size() and moved < amount:
		var ud: Dictionary = from_list[i]
		if ud.get("unit_type") == unit_type and ud.get("level") == level:
			to_list.append(ud)
			from_list.remove_at(i)
			moved += 1
		else:
			i += 1
	SaveManager.save_current()
	_selected_key = ""
	_selected_source = ""
	call_deferred("_refresh")

