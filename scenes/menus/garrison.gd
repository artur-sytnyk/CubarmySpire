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
@onready var _to_warband_btn: Button      = $NavBarMargin/HBoxContainer/GarrisonPanel/MarginContainer/VBoxContainer/TitleRow/ToWarbandBtn
@onready var _to_garrison_btn: Button     = $NavBarMargin/HBoxContainer/WarbandPanel/MarginContainer/VBoxContainer/TitleRow/ToGarrisonBtn
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
	_vanguard_label.text       = "Vanguard size: %d / %d"  % [vanguard, vanguard_limit]
	_reserves_label.text       = "Warband size:  %d / %d" % [total, reserves_limit]


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
	container.tooltip_text = "%s  lv %d  ×%d" % [unit_type.capitalize(), level, count]
	
	var backgroundTexture := AtlasTexture.new()
	backgroundTexture.atlas = preload("res://assets/images/sprites/unit_sprite.png")
	backgroundTexture.region = Rect2(0, 0, 64, 64)
	var background := TextureRect.new()
	background.texture = backgroundTexture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	container.add_child(background)
	
	var badge_lbl := Label.new()
	badge_lbl.text = "[%d]" % count
	badge_lbl.add_theme_font_size_override("font_size", 16)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	badge_lbl.offset_top = -18.0
	container.add_child(badge_lbl)
	
	var level_lbl := Label.new()
	level_lbl.text = "lv %d" % level
	level_lbl.add_theme_font_size_override("font_size", 16)
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	level_lbl.offset_top = -8.0
	container.add_child(level_lbl)
	
	var weaponIcon := TextureRect.new()
	weaponIcon.custom_minimum_size = Vector2(32, 32)
	weaponIcon.size = Vector2(32, 32)
	weaponIcon.pivot_offset = weaponIcon.size / 2.0
	weaponIcon.set_anchors_and_offsets_preset(PRESET_CENTER)
	match unit_type:
		"warrior":
			weaponIcon.texture = IconDatabase.get_icon("sword")
			weaponIcon.rotation_degrees = -90
		"ranger":
			weaponIcon.texture = IconDatabase.get_icon("bow")
	weaponIcon.position = Vector2(-4, -4)
	container.add_child(weaponIcon)
	
	# Click button — transparent overlay over unit container
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

