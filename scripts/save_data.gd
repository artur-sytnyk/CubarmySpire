class_name SaveData

var slot: int = 0
var gold: int = 0
var materials_inv: Dictionary = {}
var equipment_inv: Array = []
var army_active: Array = []
var army_barracks: Array = []
var shop_equipment: Array = []
var max_stage_reached: Dictionary = {}


static func new_game(slot: int) -> SaveData:
	var s := SaveData.new()
	s.slot = slot
	s.gold = 100
	s.army_active = [
		{ "unit_type": "warrior", "level": 1 },
		{ "unit_type": "warrior", "level": 1 },
		{ "unit_type": "warrior", "level": 1 },
		{ "unit_type": "warrior", "level": 1 },
		{ "unit_type": "ranger",  "level": 1 },
		{ "unit_type": "ranger",  "level": 1 },
		{ "unit_type": "ranger",  "level": 1 },
		{ "unit_type": "ranger",  "level": 1 },
	]
	s.max_stage_reached = { "easy": 0, "normal": 0, "hard": 0 }
	return s


func to_dict() -> Dictionary:
	return {
		"slot":              slot,
		"gold":              gold,
		"materials":         materials_inv,
		"equipment":         equipment_inv,
		"army_active":       army_active,
		"army_barracks":     army_barracks,
		"shop_equipment":    shop_equipment,
		"max_stage_reached": max_stage_reached,
	}


static func from_dict(data: Dictionary, slot: int) -> SaveData:
	var s := SaveData.new()
	s.slot               = slot
	s.gold               = data.get("gold", 0)
	var raw_materials: Dictionary = data.get("materials", {})
	for key in raw_materials:
		s.materials_inv[int(key)] = raw_materials[key]
	s.equipment_inv      = data.get("equipment", [])
	s.army_active        = data.get("army_active", [])
	s.army_barracks      = data.get("army_barracks", [])
	s.shop_equipment     = data.get("shop_equipment", [])
	s.max_stage_reached  = data.get("max_stage_reached", { "easy": 0, "normal": 0, "hard": 0 })
	return s

