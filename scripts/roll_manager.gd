extends Node


func roll_powerup_offers() -> Array:
	var result: Array = []
	var used_ids: Array = []
	for i in 3:
		var grade: int = _roll_grade()
		var pu: Dictionary = _pick_random_powerup(used_ids, grade)
		if pu.is_empty():
			continue
		result.append({ "powerup": pu, "grade": grade })
		used_ids.append(pu["id"])
	return result


func _roll_grade() -> int:
	var roll := randf() * 100.0
	if roll < 10.0: return 4
	if roll < 30.0: return 3
	if roll < 60.0: return 2
	return 1


func _pick_random_powerup(exclude_ids: Array, grade: int) -> Dictionary:
	var pool := GameData.powerups.values().filter(func(p):
		return not exclude_ids.has(p["id"]) and p["min_grade"] <= grade)
	if pool.is_empty():
		return {}
	pool.shuffle()
	return pool[0]


# TODO - not used, mark to remove later
func roll_single_stat_powerup(exclude_ids: Array) -> Dictionary:
	var pool := GameData.powerups.values().filter(func(p):
		return p.get("category") == "stat_multiplier" and not exclude_ids.has(p["id"]))
	if pool.is_empty():
		return {}
	pool.shuffle()
	return pool[0]


func roll_artifact(grade: int) -> Dictionary:
	var pool: Array = GameData.equipment.values().filter(func(e: Dictionary) -> bool:
		return e.get("slot", "") == "artifact" and e.get("min_grade", 1) <= grade)
	if pool.is_empty():
		return {}
	pool.shuffle()
	return pool[0]


func roll_shop_equipment() -> Array:
	var calibrated: int = GameData.get_calibrated_progress()
	var item_level: int = maxi(1, calibrated / 5)
	var result: Array   = []
	var used_ids: Array = []
	
	for _i in 5:
		var grade: int         = _roll_shop_grade()
		var item: Dictionary   = _pick_random_equipment(used_ids, grade)
		if item.is_empty():
			continue
		result.append({
			"id":            item["id"],
			"level":         item_level,
			"grade":         grade,
			"equipped_slot": "",
		})
		used_ids.append(item["id"])
	
	return result


func _roll_shop_grade() -> int:
	var roll := randf() * 100.0
	if roll < 5.0:   return 5
	if roll < 10.0:  return 4
	if roll < 20.0:  return 3
	if roll < 40.0:  return 2
	return 1


func _pick_random_equipment(exclude_ids: Array, grade: int) -> Dictionary:
	if grade == 0:
		return {}
	var pool := GameData.equipment.values().filter(func(e):
		return not exclude_ids.has(e["id"]) and e.get("min_grade", 1) <= grade)
	if pool.is_empty():
		return {}
	pool.shuffle()
	return pool[0]


func roll_materials_loot(stage: int, unit_level: int, unit_type: String) -> Dictionary:
	var unit_def: Dictionary = GameData.units.get(unit_type, {})
	var loot_table: Array = unit_def.get("loot_table", [])
	var result: Dictionary = {}
	
	for entry in loot_table:
		var grade: int = entry.get("grade", 1)
		var chance: float = entry.get("chance", 0.0)
		var base_rolls: int = entry.get("rolls", 1)
		var bonus_rolls: int = mini(grade - 1, stage / 20)
		
		for _i in base_rolls + bonus_rolls:
			if randf() < chance:
				result[grade] = result.get(grade, 0) + 1
	return result


func roll_gold_loot(stage: int, unit_level: int, unit_type: String) -> int:
	var rolls_float: float = stage * 0.5
	var guaranteed: int = int(rolls_float)
	var bonus_chance: float = rolls_float - guaranteed
	var total_rolls: int = guaranteed + (1 if randf() < bonus_chance else 0)
	return total_rolls * unit_level

