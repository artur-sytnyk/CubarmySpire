# market.gd — Market scene
# Scene tree: see previous version comments — node structure unchanged.
extends Control

const ITEM_BOX_SCENE: PackedScene = preload("res://objects/item_box/ItemBox.tscn")
const ITEM_ICON_PATH: String = "res://assets/images/items/%s.png"

# ── Refs ───────────────────────────────────────────────────────────────────

@onready var _recruit_btn: Button          = $NavBarMargin/VBoxContainer/HBoxContainer/LeftPanel/MarginContainer/VBoxContainer/RecruitBtn
@onready var _equip_btn: Button            = $NavBarMargin/VBoxContainer/HBoxContainer/LeftPanel/MarginContainer/VBoxContainer/EquipBtn
@onready var _alchemy_btn: Button          = $NavBarMargin/VBoxContainer/HBoxContainer/LeftPanel/MarginContainer/VBoxContainer/AlchemyBtn
@onready var _recruit_pane: VBoxContainer  = $NavBarMargin/VBoxContainer/HBoxContainer/RightPanel/MarginContainer/VBoxContainer/RecruitPane
@onready var _equip_pane: VBoxContainer    = $NavBarMargin/VBoxContainer/HBoxContainer/RightPanel/MarginContainer/VBoxContainer/EquipPane
@onready var _alchemy_pane: VBoxContainer  = $NavBarMargin/VBoxContainer/HBoxContainer/RightPanel/MarginContainer/VBoxContainer/AlchemyPane
@onready var _gold_label: Label            = $NavBarMargin/VBoxContainer/BottomBar/MarginContainer/HBoxContainer/GoldVBox/GoldLabel
@onready var _materials_row: HBoxContainer = $NavBarMargin/VBoxContainer/BottomBar/MarginContainer/HBoxContainer/MaterialsRow
@onready var _unit_level_input: SpinBox    = $NavBarMargin/VBoxContainer/HBoxContainer/RightPanel/MarginContainer/VBoxContainer/RecruitPane/LevelRow/UnitLevelInput
@onready var _gold_burst: CPUParticles2D   = $GoldBurstParticles

# ── State ──────────────────────────────────────────────────────────────────

var _active_pane: String = "recruit"
var _selected_equip_idx: int = -1
var _selected_alchemy_grade: int = -1

func _ready() -> void:
	_recruit_btn.pressed.connect(func(): _switch_pane("recruit"))
	_equip_btn.pressed.connect(func():   _switch_pane("equip"))
	_alchemy_btn.pressed.connect(func(): _switch_pane("alchemy"))
	_unit_level_input.value_changed.connect(_on_unit_level_changed)
	_build_recruit_pane()
	_build_equip_pane()
	_build_alchemy_pane()
	_switch_pane("recruit")
	_refresh_bottom_bar()

# ── Pane switching ─────────────────────────────────────────────────────────

func _switch_pane(pane: String) -> void:
	_active_pane = pane
	_recruit_pane.visible = pane == "recruit"
	_equip_pane.visible   = pane == "equip"
	_alchemy_pane.visible = pane == "alchemy"
	_update_nav_highlight()


func _update_nav_highlight() -> void:
	for pair in [["recruit", _recruit_btn], ["equip", _equip_btn], ["alchemy", _alchemy_btn]]:
		var btn: Button = pair[1]
		var is_active: bool = pair[0] == _active_pane
		btn.toggle_mode = true
		btn.button_pressed = is_active
		btn.disabled = is_active


# ── Any buy / sell action ──────────────────────────────────────────────────
func _play_gold_burst(btn: Button) -> void:
	_gold_burst.global_position = btn.global_position + btn.size * 0.5
	_gold_burst.restart()


# ── Recruit pane ───────────────────────────────────────────────────────────

func _build_recruit_pane() -> void:
	_refresh_unit_rows()


func _refresh_unit_rows() -> void:
	var children: Array = _recruit_pane.get_children()
	for i in range(children.size() - 1, 0, -1):
		children[i].queue_free()
	var level: int = int(_unit_level_input.value)
	for unit_type: String in ["warrior", "ranger"]:
		_recruit_pane.add_child(_make_unit_row(unit_type, level))


func _make_unit_row(unit_type: String, level: int) -> Control:
	var def: Dictionary    = GameData.units.get(unit_type, {})
	var stats: Dictionary  = def.get("base_stats", {})
	var base_price: int    = def.get("shop_price", 100)
	var cost: int = int(base_price * pow(1.3, level - 1))

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)

	var unitTexture := AtlasTexture.new()
	unitTexture.atlas = preload("res://assets/images/sprites/unit_sprite.png")
	unitTexture.region = Rect2(0, 0, 64, 64)
	var unitIcon := TextureRect.new()
	unitIcon.texture = unitTexture
	unitIcon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	unitIcon.stretch_mode = TextureRect.STRETCH_SCALE
	unitIcon.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	unitIcon.custom_minimum_size = Vector2(64, 64)
	
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
	weaponIcon.position = Vector2(-8, -8)
	
	unitIcon.add_child(weaponIcon)
	hbox.add_child(unitIcon)
	
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	hbox.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = unit_type.capitalize()
	name_lbl.add_theme_font_size_override("font_size", 14)
	info.add_child(name_lbl)

	var is_ranged: bool = stats.get("is_ranged", false)
	var stats_lbl := Label.new()
	var base_stats: Dictionary = GameData.get_unit(unit_type).get("base_stats", {})
	var scaled: Dictionary = BattleStatsCalculator.get_scaled_stats(base_stats, level)
	stats_lbl.text = "HP %d  ·  DMG %d  ·  %s  ·  SPD %d" % [
		int(scaled.get("hp_max", 0)),
		int(scaled.get("atk_damage", 0)),
		"Ranged" if scaled.get("is_ranged", false) else "Melee",
		int(scaled.get("speed", 0)),
	]
	stats_lbl.add_theme_font_size_override("font_size", 11)
	stats_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	info.add_child(stats_lbl)

	var buy_col := VBoxContainer.new()
	buy_col.add_theme_constant_override("separation", 4)
	hbox.add_child(buy_col)

	var cost_lbl := Label.new()
	cost_lbl.text = "%dg" % cost
	cost_lbl.add_theme_font_size_override("font_size", 14)
	cost_lbl.add_theme_color_override("font_color", GameData.COLOR_GOLD)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	buy_col.add_child(cost_lbl)

	var buy_btn := Button.new()
	buy_btn.text = "Buy"
	buy_btn.pressed.connect(_on_buy_unit.bind(unit_type, level, cost, buy_btn))
	buy_col.add_child(buy_btn)

	return panel


func _on_unit_level_changed(_val: float) -> void:
	_refresh_unit_rows()


func _on_buy_unit(unit_type: String, level: int, cost: int, btn: Button) -> void:
	var save: SaveData = SaveManager.get_current()
	if save.gold < cost:
		_show_error("Not enough gold.")
		return
	_play_gold_burst(btn)
	SoundManager.play_ui("purchase")
	save.gold -= cost
	var target: Array = save.army_active if save.army_active.size() < 20 else save.army_barracks
	target.append({ "unit_type": unit_type, "level": level })
	SaveManager.save_current()
	_refresh_bottom_bar()

# ── Equipment pane ─────────────────────────────────────────────────────────

func _build_equip_pane() -> void:
	var detail := PanelContainer.new()
	detail.name = "EquipDetail"
	detail.custom_minimum_size = Vector2(0, 120)
	_equip_pane.add_child(detail)

	var detail_margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		detail_margin.add_theme_constant_override("margin_" + side, 10)
	detail.add_child(detail_margin)

	var placeholder := Label.new()
	placeholder.name = "Placeholder"
	placeholder.text = "Select an item below to see details"
	placeholder.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	detail_margin.add_child(placeholder)

	var slots_label := Label.new()
	slots_label.text = "Available this run — 5 slots"
	slots_label.add_theme_font_size_override("font_size", 11)
	slots_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_equip_pane.add_child(slots_label)

	var slots_flow := HBoxContainer.new()
	slots_flow.name = "SlotsFlow"
	slots_flow.add_theme_constant_override("separation", 10)
	_equip_pane.add_child(slots_flow)

	_refresh_equip_slots()


func _refresh_equip_slots() -> void:
	var flow: HBoxContainer = _equip_pane.find_child("SlotsFlow", true, false)
	if flow == null:
		return
	for child in flow.get_children():
		child.queue_free()
	var save: SaveData = SaveManager.get_current()
	for i: int in save.shop_equipment.size():
		_make_equip_slot_box(save.shop_equipment[i], i, flow)


func _make_equip_slot_box(item: Dictionary, idx: int, flow: HBoxContainer) -> void:
	var def: Dictionary   = GameData.get_equipment(item.get("id", ""))
	var grade: int        = item.get("grade", 1)
	var grade_color: Color = GameData.get_grade_color(grade)
	var level: int        = item.get("level", 1)
	var count: int        = item.get("count", 1)
	var is_equipped: bool = item.get("equipped_slot", "") != ""
	var item_id: String   = item.get("id", "")

	var box: ItemBox = ITEM_BOX_SCENE.instantiate()
	flow.add_child(box)
	
	var icon_path: String = ITEM_ICON_PATH % item_id
	var icon: Texture2D = load(icon_path) if ResourceLoader.exists(icon_path) else null

	box.setup(icon, grade, level, count)
	box.pressed.connect(_on_equip_slot_clicked.bind(item, idx))



#func _make_empty_slot_box() -> Control:
	#var panel := PanelContainer.new()
	#panel.custom_minimum_size = Vector2(120, 80)
	#panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
#
	#var lbl := Label.new()
	#lbl.text = "— empty —"
	#lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	#lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	#lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	#panel.add_child(lbl)
#
	#return panel


func _on_equip_slot_clicked(item: Dictionary, idx: int) -> void:
	_selected_equip_idx = idx
	_show_equip_detail(item)


func _show_equip_detail(item: Dictionary) -> void:
	var detail: PanelContainer = _equip_pane.find_child("EquipDetail", true, false)
	if detail == null:
		return
	var margin: MarginContainer = detail.get_child(0)
	for child in margin.get_children():
		child.queue_free()

	var def: Dictionary    = GameData.get_equipment(item.get("id", ""))
	var grade: int         = item.get("grade", 1)
	var level: int         = item.get("level", 1)
	var grade_color: Color = GameData.get_grade_color(grade)
	var effect_pct: float  = float(def.get("base_value", 0.0)) * level * (1.0 + (grade - 1) * 0.10) * 100.0
	var cost: int          = GameData.item_buy_price(level, grade)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var item_icon: ItemBox = ITEM_BOX_SCENE.instantiate()
	hbox.add_child(item_icon)
	
	var icon_path: String = ITEM_ICON_PATH % item.get("id", "")
	var icon: Texture2D = load(icon_path) if ResourceLoader.exists(icon_path) else null
	item_icon.setup(icon, grade)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	hbox.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = "%s %s" % [GameData.get_grade_name(grade), def.get("name", "?")]
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", grade_color)
	info.add_child(name_lbl)

	var filter: String = def.get("filter", "")
	var sub_lbl := Label.new()
	sub_lbl.text = "%s  ·  Lv.%d  ·  +%.0f%% %s" % [
		filter.capitalize() if filter != "" else "All units",
		level, effect_pct, def.get("stat", ""),
	]
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info.add_child(sub_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = def.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_lbl)

	var buy_col := VBoxContainer.new()
	buy_col.add_theme_constant_override("separation", 6)
	hbox.add_child(buy_col)

	var cost_lbl := Label.new()
	cost_lbl.text = "%dg" % cost
	cost_lbl.add_theme_font_size_override("font_size", 16)
	cost_lbl.add_theme_color_override("font_color", GameData.COLOR_GOLD)
	buy_col.add_child(cost_lbl)

	var buy_btn := Button.new()
	buy_btn.text = "Buy"
	buy_btn.pressed.connect(_on_buy_equipment.bind(item, cost, buy_btn))
	buy_col.add_child(buy_btn)


func _on_buy_equipment(item: Dictionary, cost: int, btn: Button) -> void:
	var save: SaveData = SaveManager.get_current()
	if save.gold < cost:
		_show_error("Not enough gold.")
		return
	if not SaveManager.has_equipment_space():
		_show_error("Inventory is full!")
		return
	_play_gold_burst(btn)
	SoundManager.play_ui("purchase")
	save.gold -= cost
	SaveManager.try_add_equipment(item.duplicate())
	if _selected_equip_idx >= 0 and _selected_equip_idx < save.shop_equipment.size():
		save.shop_equipment.remove_at(_selected_equip_idx)
	SaveManager.save_current()
	_selected_equip_idx = -1
	_refresh_equip_slots()
	_refresh_bottom_bar()

# ── Alchemy pane ───────────────────────────────────────────────────────────

func _get_alchemy_cost(grade: int) -> Dictionary:
	var prev_tier: int = grade - 1
	return {
		"same_tier":  grade,
		"same_count": 30,
		"prev_tier":  prev_tier,
		"prev_count": 20 if prev_tier >= 1 else 0,
	}


func _get_alchemy_level_range() -> Array:
	var base: int = RollManager.get_calibrated_progress() / 5
	if base <= 1:
		return [1, 1]
	return [maxi(1, base - 2), base + 2]


func _build_alchemy_pane() -> void:
	var detail := PanelContainer.new()
	detail.name = "AlchemyDetail"
	detail.custom_minimum_size = Vector2(0, 120)
	_alchemy_pane.add_child(detail)

	var detail_margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		detail_margin.add_theme_constant_override("margin_" + side, 10)
	detail.add_child(detail_margin)

	var placeholder := Label.new()
	placeholder.name = "Placeholder"
	placeholder.text = "Select a crafting grade below"
	placeholder.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	detail_margin.add_child(placeholder)

	var grade_label := Label.new()
	grade_label.text = "Choose grade — guaranteed result, cost scales with progress"
	grade_label.add_theme_font_size_override("font_size", 11)
	grade_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_alchemy_pane.add_child(grade_label)

	var grades_vbox := VBoxContainer.new()
	grades_vbox.name = "GradesVBox"
	grades_vbox.add_theme_constant_override("separation", 6)
	_alchemy_pane.add_child(grades_vbox)

	for i: int in range(5):
		grades_vbox.add_child(_make_grade_row(i))


func _make_grade_row(grade_idx: int) -> Control:
	var grade: int         = grade_idx + 1
	var grade_color: Color = GameData.get_grade_color(grade)
	var cost: Dictionary   = _get_alchemy_cost(grade)
	var lvl_range: Array   = _get_alchemy_level_range()

	var cost_parts: Array = []
	if cost.same_count > 0:
		cost_parts.append("%d× T%d" % [cost.same_count, cost.same_tier])
	if cost.prev_count > 0:
		cost_parts.append("%d× T%d" % [cost.prev_count, cost.prev_tier])
	var cost_str: String = "  ·  ".join(cost_parts)

	var panel := PanelContainer.new()

	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(12, 12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.color = grade_color
	hbox.add_child(dot)

	var name_lbl := Label.new()
	name_lbl.text = GameData.get_grade_name(grade)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", grade_color)
	name_lbl.custom_minimum_size.x = 80
	hbox.add_child(name_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = cost_str
	cost_lbl.add_theme_font_size_override("font_size", 11)
	cost_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	cost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(cost_lbl)

	var lvl_lbl := Label.new()
	lvl_lbl.text = "Lv.%d – Lv.%d" % [lvl_range[0], lvl_range[1]]
	lvl_lbl.add_theme_font_size_override("font_size", 11)
	lvl_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	hbox.add_child(lvl_lbl)

	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	btn.pressed.connect(_on_grade_row_clicked.bind(grade_idx))
	panel.add_child(btn)

	return panel


func _on_grade_row_clicked(grade_idx: int) -> void:
	_selected_alchemy_grade = grade_idx
	_show_alchemy_detail(grade_idx)


func _show_alchemy_detail(grade_idx: int) -> void:
	var detail: PanelContainer = _alchemy_pane.find_child("AlchemyDetail", true, false)
	if detail == null:
		return
	var margin: MarginContainer = detail.get_child(0)
	for child in margin.get_children():
		child.queue_free()

	var grade: int         = grade_idx + 1
	var grade_color: Color = GameData.get_grade_color(grade)
	var cost: Dictionary   = _get_alchemy_cost(grade)
	var lvl_range: Array   = _get_alchemy_level_range()

	var cost_parts: Array = []
	if cost.same_count > 0:
		cost_parts.append("%d× Tier %d" % [cost.same_count, cost.same_tier])
	if cost.prev_count > 0:
		cost_parts.append("%d× Tier %d" % [cost.prev_count, cost.prev_tier])

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)

	var grade_lbl := Label.new()
	grade_lbl.text = GameData.get_grade_name(grade)
	grade_lbl.add_theme_font_size_override("font_size", 15)
	grade_lbl.add_theme_color_override("font_color", grade_color)
	header.add_child(grade_lbl)

	var pool_lbl := Label.new()
	pool_lbl.text = "Random artifact — guaranteed %s grade" % GameData.get_grade_name(grade)
	pool_lbl.add_theme_font_size_override("font_size", 12)
	pool_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	pool_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(pool_lbl)

	var ranges := HBoxContainer.new()
	ranges.add_theme_constant_override("separation", 12)
	vbox.add_child(ranges)

	for pair: Array in [
		["Level range", "Lv.%d – Lv.%d" % [lvl_range[0], lvl_range[1]]],
		["Cost",        "  ·  ".join(cost_parts)],
	]:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ranges.add_child(card)
		var card_vbox := VBoxContainer.new()
		card.add_child(card_vbox)
		var card_label := Label.new()
		card_label.text = pair[0]
		card_label.add_theme_font_size_override("font_size", 10)
		card_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		card_vbox.add_child(card_label)
		var card_val := Label.new()
		card_val.text = pair[1]
		card_val.add_theme_font_size_override("font_size", 13)
		card_vbox.add_child(card_val)

	var craft_btn := Button.new()
	craft_btn.text = "Request Crafting"
	craft_btn.pressed.connect(_on_request_crafting.bind(grade_idx, craft_btn))
	vbox.add_child(craft_btn)


func _on_request_crafting(grade_idx: int, btn: Button) -> void:
	var save: SaveData   = SaveManager.get_current()
	var grade: int       = grade_idx + 1
	var cost: Dictionary = _get_alchemy_cost(grade)

	# Check materials.
	var has_same: bool = save.materials_inv.get(cost.same_tier, 0) >= cost.same_count
	var has_prev: bool = cost.prev_count == 0 or save.materials_inv.get(cost.prev_tier, 0) >= cost.prev_count
	if not has_same or not has_prev:
		_show_error("Not enough materials.")
		return
	
	_play_gold_burst(btn)
	SoundManager.play_ui("equip")
	# Deduct materials.
	save.materials_inv[cost.same_tier] = save.materials_inv.get(cost.same_tier, 0) - cost.same_count
	if cost.prev_count > 0:
		save.materials_inv[cost.prev_tier] = save.materials_inv.get(cost.prev_tier, 0) - cost.prev_count

	# Roll artifact.
	var lvl_range: Array = _get_alchemy_level_range()
	var rolled_level: int = randi_range(lvl_range[0], lvl_range[1])
	var artifact: Dictionary = RollManager.roll_artifact(grade)
	if artifact.is_empty():
		_show_error("No artifacts available at this grade.")
		return

	var result: Dictionary = {
		"id":            artifact["id"],
		"level":         rolled_level,
		"grade":         grade,
		"equipped_slot": "",
	}

	SaveManager.save_current()
	_show_craft_result(result)
	_refresh_bottom_bar()


func _show_craft_result(item: Dictionary) -> void:
	if not SaveManager.has_equipment_space():
		_show_error("Inventory is full!")
		return
	var def: Dictionary    = GameData.get_equipment(item.get("id", ""))
	var grade: int         = item.get("grade", 1)
	var level: int         = item.get("level", 1)
	var grade_color: Color = GameData.get_grade_color(grade)
	var effect_pct: float  = float(def.get("base_value", 0.0)) * level * (1.0 + (grade - 1) * 0.10) * 100.0

	var dialog := AcceptDialog.new()
	dialog.title = "Crafting result"
	dialog.dialog_text = "%s %s\nLv.%d  ·  +%.0f%% %s\n\n%s" % [
		GameData.get_grade_name(grade),
		def.get("name", "?"),
		level,
		effect_pct,
		def.get("stat", ""),
		def.get("description", ""),
	]
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		SaveManager.try_add_equipment(item.duplicate())
		SaveManager.save_current()
		dialog.queue_free()
	)

# ── Bottom bar ─────────────────────────────────────────────────────────────

func _refresh_bottom_bar() -> void:
	var save: SaveData = SaveManager.get_current()
	_gold_label.text = "%dg" % save.gold
	_rebuild_materials_row(save)


func _rebuild_materials_row(save: SaveData) -> void:
	for child in _materials_row.get_children():
		child.queue_free()
	for grade: int in [1, 2, 3, 4, 5]:
		var count: int = save.materials_inv.get(grade, 0)
		_materials_row.add_child(_make_material_item(grade, count))


func _make_material_item(grade: int, count: int) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	
	# Left — icon only
	var icon := TextureRect.new()
	icon.texture = load("res://assets/images/loot/material-1.png")
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = GameData.get_grade_color(grade)
	hbox.add_child(icon)
	
	# Right — count on top, price + button on bottom
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 2)
	hbox.add_child(right)
	
	var count_lbl := Label.new()
	count_lbl.text = str(count)
	count_lbl.add_theme_font_size_override("font_size", 16)
	right.add_child(count_lbl)
	
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 8)
	right.add_child(bottom_row)
	
	var price_lbl := Label.new()
	price_lbl.text = "%dg" % GameData.get_mat_price(grade)
	price_lbl.add_theme_font_size_override("font_size", 12)
	price_lbl.add_theme_color_override("font_color", GameData.COLOR_GOLD)
	price_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(price_lbl)
	
	var sell_btn := Button.new()
	sell_btn.text = "Sell"
	sell_btn.custom_minimum_size = Vector2(48, 0)
	sell_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sell_btn.tooltip_text = "Hold [SHIFT] to sell x10, [CTRL] for x100"
	var empty_style := StyleBoxEmpty.new()
	var font_color := Color("#1D3033")
	sell_btn.add_theme_color_override("font_color", font_color)
	sell_btn.add_theme_color_override("font_hover_color", font_color)
	sell_btn.add_theme_color_override("font_pressed_color", font_color)
	sell_btn.add_theme_color_override("font_focus_color", font_color)
	sell_btn.add_theme_stylebox_override("normal", load("res://ui/styles/btn_normal.tres"))
	sell_btn.add_theme_stylebox_override("hover", load("res://ui/styles/btn_hover.tres"))
	sell_btn.add_theme_stylebox_override("pressed", load("res://ui/styles/btn_pressed.tres"))
	sell_btn.add_theme_stylebox_override("focus", empty_style)
	sell_btn.pressed.connect(_on_sell_materials.bind(grade, sell_btn))
	bottom_row.add_child(sell_btn)
	
	return hbox


func _on_sell_materials(grade: int, btn: Button) -> void:
	var save: SaveData = SaveManager.get_current()
	var shift_held: bool = Input.is_key_pressed(KEY_SHIFT)
	var ctrl_held: bool = Input.is_key_pressed(KEY_CTRL)
	var amount: int      = 100 if ctrl_held else 10 if shift_held else 1
	var count: int       = save.materials_inv.get(grade, 0)
	var to_sell: int     = mini(count, amount)
	if to_sell <= 0:
		return
	_play_gold_burst(btn)
	SoundManager.play_ui("purchase")
	save.materials_inv[grade] = count - to_sell
	save.gold += to_sell * GameData.get_mat_price(grade)
	SaveManager.save_current()
	_refresh_bottom_bar()

# ── Helpers ────────────────────────────────────────────────────────────────

func _show_error(msg: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = msg
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)

func _make_glow_texture(color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color.r, color.g, color.b, 0.6))
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex

