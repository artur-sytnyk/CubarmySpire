extends Node

var units: Dictionary = {}
var powerups: Dictionary = {}
var equipment: Dictionary = {}

# Game Mechanic constants
const GARRISON_MAX: int = 200
const MAX_ITEM_STACK: int = 30
const LEVEL_SCALE_ATK: float = 1.2
const LEVEL_SCALE_HP: float = 1.2
const LEVEL_SCALE_SPEED: int = 1
const LEVEL_SCALE_RANGE: int = 1

# Constant Arrays and Dictionaries
const DIFFICULTY_MULTIPLIERS := { "easy": 1, "normal": 2, "hard": 3 }
const GRADE_NAMES: Dictionary = { 1: "Common", 2: "Uncommon", 3: "Rare", 4: "Epic", 5: "Legendary" }
const GRADE_COLORS: Dictionary = {
	1: Color("#D4D4D4"),  # 1 Common    — grey
	2: Color("#4DCC00"),  # 2 Uncommon  — green
	3: Color("#0070DD"),  # 3 Rare      — blue
	4: Color("#A335EE"),  # 4 Epic      — purple
	5: Color("#FF8000"),  # 5 Legendary — gold/yellow
}
const COLOR_GOLD: Color = Color("#FFD94D")
const MAT_SELL_PRICE: Dictionary = { 1: 1, 2: 5, 3: 10, 4: 44, 5: 99}

# Animation constants
const LOOT_BOB_HEIGHT: float = 4.0
const LOOT_BOB_DURATION: float = 1.2
const LOOT_COLLECT_RISE: float = 80.0
const LOOT_COLLECT_DURATION: float = 0.6
const LOOT_SCATTER_RADIUS: float = 30.0
const LOOT_CAP: int = 120

func _ready() -> void:
	_load_units()
	_load_powerups()
	_load_equipment()

# --- Loads ---
func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("GameData: missing file %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	var result = JSON.parse_string(file.get_as_text())
	file.close()
	if result == null:
		push_error("GameData: failed to parse %s" % path)
	return result


func _load_units() -> void:
	units = _load_json("res://data/units.json")


func _load_powerups() -> void:
	var arr: Array = _load_json("res://data/powerups.json")
	for pu in arr:
		powerups[pu["id"]] = pu


func _load_equipment() -> void:
	var arr: Array = _load_json("res://data/equipment.json")
	for e in arr:
		equipment[e["id"]] = e


# --- Getter ---
func get_unit(unit_type: String) -> Dictionary:
	return units.get(unit_type, {})


func get_powerup(id: String) -> Dictionary:
	return powerups.get(id, {})


func get_equipment(id: String) -> Dictionary:
	return equipment.get(id, { "name": id, "slot": "", "category": "", "description": "" })


func get_calibrated_progress() -> int:
	var save :SaveData = SaveManager.get_current()
	var total := 0
	for diff in save.max_stage_reached:
		total += save.max_stage_reached[diff] * DIFFICULTY_MULTIPLIERS.get(diff, 1)
	return total


func get_grade_name(grade: int) -> String:
	return GRADE_NAMES.get(grade, "")


func get_grade_color(grade: int) -> Color:
	return GRADE_COLORS.get(grade, Color("#ff4f52"))


func get_mat_price(grade: int) -> int:
	return MAT_SELL_PRICE.get(grade, 0)



static func format_number(n: int) -> String:
	if n >= 1_000_000_000_000:
		return "%.1fT" % (n / 1_000_000_000_000.0)
	if n >= 1_000_000_000:
		return "%.1fB" % (n / 1_000_000_000.0)
	if n >= 1_000_000:
		return "%.1fM" % (n / 1_000_000.0)
	if n >= 1_000:
		return "%.1fK" % (n / 1_000.0)
	return str(n)

