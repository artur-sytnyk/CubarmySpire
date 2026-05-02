extends Control

const SCENE_BATTLE := "res://scenes/battle/Battle.tscn"
const DIFFICULTY_EASY   := "easy"
const DIFFICULTY_NORMAL := "normal"
const DIFFICULTY_HARD   := "hard"

const UNIT_COLORS := {
	"warrior": Color(0.55, 0.35, 0.20),
	"ranger":  Color(0.25, 0.55, 0.35),
}

const SLOT_KEYS   :Array = ["weapon", "armor", "artifact_1", "artifact_2", "artifact_3"]
const SLOT_LABELS :Array = ["Weapon", "Armor", "Artifact I", "Artifact II", "Artifact III"]
const SLOT_NODE_NAMES: Array = ["WeaponBox", "ArmorBox", "Artifact1Box", "Artifact2Box", "Artifact3Box"]
const ITEM_ICON_PATH: String = "res://assets/images/items/%s.png"

@onready var _easy_btn: Button       = $NavBarMargin/HBox/LeftPanel/Margin/VBox/EasyBtn
@onready var _normal_btn: Button     = $NavBarMargin/HBox/LeftPanel/Margin/VBox/NormalBtn
@onready var _hard_btn: Button       = $NavBarMargin/HBox/LeftPanel/Margin/VBox/HardBtn
@onready var _begin_btn: Button      = $NavBarMargin/HBox/LeftPanel/Margin/VBox/BeginRunBtn
@onready var _equip_row: HBoxContainer  = $NavBarMargin/HBox/RightPanel/Margin/VBox/EquipmentRow
@onready var _army_grid: GridContainer = $NavBarMargin/HBox/RightPanel/Margin/VBox/ArmyGrid


func _ready() -> void:
	_easy_btn.pressed.connect(_on_difficulty_selected.bind(DIFFICULTY_EASY))
	_normal_btn.pressed.connect(_on_difficulty_selected.bind(DIFFICULTY_NORMAL))
	_hard_btn.pressed.connect(_on_difficulty_selected.bind(DIFFICULTY_HARD))
	_begin_btn.pressed.connect(_on_begin_run)
	_update_difficulty_highlight()
	_refresh_loadout()


func _on_difficulty_selected(difficulty: String) -> void:
	SaveManager.get_current().selected_difficulty = difficulty
	SaveManager.save_current()
	_update_difficulty_highlight()


func _update_difficulty_highlight() -> void:
	for pair in [
		[DIFFICULTY_EASY, _easy_btn],
		[DIFFICULTY_NORMAL, _normal_btn],
		[DIFFICULTY_HARD, _hard_btn]
	]:
		var difficulty: String = pair[0]
		var btn: Button = pair[1]
		var is_active: bool = difficulty == SaveManager.get_current().selected_difficulty
		btn.toggle_mode = true
		btn.button_pressed = is_active
		btn.disabled = is_active


func _refresh_loadout() -> void:
	var save := SaveManager.current_save
	if save == null:
		return
	_refresh_equipment(save)
	_refresh_army(save)


func _refresh_equipment(save: SaveData) -> void:
	var equipped: Dictionary = {}
	for equipment: Dictionary in save.equipment_inv:
		var s: String = equipment.get("equipped_slot", "")
		if s != "":
			equipped[s] = equipment

	var boxes: Array = _equip_row.get_children()
	for i: int in range(min(boxes.size(), SLOT_KEYS.size())):
		var box: ItemBox = boxes[i]
		var key: String = SLOT_KEYS[i]

		if equipped.has(key):
			var item: Dictionary = equipped[key]
			var item_id: String = item.get("id", "")
			var grade: int = item.get("grade", 1)
			var level: int = item.get("level", 1)
			var icon_path: String = ITEM_ICON_PATH % item_id
			var icon: Texture2D = load(icon_path) if ResourceLoader.exists(icon_path) else null
			var def: Dictionary = GameData.get_equipment(item_id)
			box.setup(icon, grade)
			box.set_slot(SLOT_LABELS[i])
			box.tooltip_text = "%s %s  Lv %d" % [GameData.get_grade_name(grade), def.get("name", item_id), level]
		else:
			box.setup(null, 1)
			box.tooltip_text = SLOT_LABELS[i]


func _refresh_army(save: SaveData) -> void:
	for child in _army_grid.get_children():
		child.queue_free()
	
	var groups: Dictionary = {}
	for ud in save.army_active:
		var t: String = ud.get("unit_type", "unknown")
		var l: int    = ud.get("level", 1)
		var key := "%s_%d" % [t, l]
		if not groups.has(key):
			groups[key] = { "type": t, "level": l, "count": 0 }
		groups[key].count += 1
	
	var sorted_keys := groups.keys()
	sorted_keys.sort()
	for key in sorted_keys:
		var g: Dictionary = groups[key]
		_army_grid.add_child(_make_unit_box(g.type, g.level, g.count))


func _make_unit_box(unitType: String, level: int, count: int) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(80, 80)
	container.tooltip_text = "%s  lv %d  ×%d" % [unitType.capitalize(), level, count]
	
	var backgroundTexture := AtlasTexture.new()
	backgroundTexture.atlas = preload("res://assets/images/sprites/unit_sprite.png")
	backgroundTexture.region = Rect2(0, 0, 64, 64)
	
	var background := TextureRect.new()
	background.texture = backgroundTexture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	container.add_child(background)
	
	var weaponIcon := TextureRect.new()
	weaponIcon.custom_minimum_size = Vector2(32, 32)
	weaponIcon.size = Vector2(32, 32)
	weaponIcon.pivot_offset = weaponIcon.size / 2.0
	weaponIcon.set_anchors_and_offsets_preset(PRESET_CENTER)
	match unitType:
		"warrior":
			weaponIcon.texture = IconDatabase.get_icon("sword")
			weaponIcon.rotation_degrees = -90
		"ranger":
			weaponIcon.texture = IconDatabase.get_icon("bow")
	weaponIcon.position = Vector2(-4, -4)
	container.add_child(weaponIcon)
	
	var levelLabel := Label.new()
	levelLabel.text = "lv %d" % level
	levelLabel.add_theme_font_size_override("font_size", 16)
	levelLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	levelLabel.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	levelLabel.offset_top = -8.0
	container.add_child(levelLabel)
	
	var badge_lbl := Label.new()
	badge_lbl.text = "[%d]" % count
	badge_lbl.add_theme_font_size_override("font_size", 16)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	badge_lbl.offset_top = -18.0
	container.add_child(badge_lbl)
	
	return container


func _on_begin_run() -> void:
	var save := SaveManager.get_current()
	if save.army_active.is_empty():
		_show_error("Your warband is empty! Add units in the Garrison first.")
		return
	RunState.init_from_save(save, save.selected_difficulty)
	SceneManager.go_to(SCENE_BATTLE)


func _show_error(msg: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = msg
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)

