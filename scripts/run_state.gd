extends Node

# Signals
signal run_finalized(results: Dictionary)

# State
var difficulty: String = "easy"    # "easy" / "normal" / "hard"
var stage: int = 1
var active_equipment: Array = []
var active_powerups: Dictionary = {} # powerup_id : accumulated_relative_grade
var gold_collected: int = 0
var loot_collected: Dictionary = {}  # tier : accumulated_count
var gold_multiplier: float = 1.0
var material_forage_multiplier: float = 1.0
var unit_defs: Array = []


func reset() -> void:
	difficulty = "easy"
	stage = 1
	active_equipment = []
	active_powerups = {}
	gold_collected = 0
	loot_collected = {}
	gold_multiplier = 1.0
	material_forage_multiplier = 1.0
	unit_defs = []


func init_from_save(save: SaveData, chosen_difficulty: String) -> void:
	reset()
	difficulty = chosen_difficulty
	unit_defs = save.army_active.duplicate(true) # deep copy = true
	active_equipment = save.equipment_inv.filter(
		func(item): return item.get("equipped_slot", "") != ""
	).duplicate()


# --- Stage ---

func on_stage_complete() -> void:
	stage += 1


# --- Loot ---

func collect_gold(amount: int) -> void:
	gold_collected += amount


func collect_materials(drops: Dictionary) -> void:
	for grade in drops:
		loot_collected[grade] = loot_collected.get(grade, 0) + drops[grade]


func finalize_run() -> void:
	print("Run finalized: %d gold " % gold_collected, loot_collected)
	gold_collected = gold_collected * gold_multiplier
	var materials_collected: Dictionary = {}
	for grade in loot_collected:
		materials_collected[grade] = int(loot_collected[grade] * material_forage_multiplier)
	
	var save := SaveManager.current_save
	save.gold += gold_collected
	for grade in materials_collected:
		save.materials_inv[grade] = save.materials_inv.get(grade, 0) + materials_collected[grade]
	
	# Update max stage reached for this difficulty.
	var is_new_max_stage: bool = SaveManager.update_max_stage(difficulty, stage)
	
	# Roll new shop equipment for next market visit.
	save.shop_equipment = RollManager.roll_shop_equipment()
	
	SaveManager.save_current()
	
	run_finalized.emit({
		"stage":  stage,
		"difficulty":  difficulty,
		"is_record": is_new_max_stage,
		"gold":   gold_collected,
		"materials":   materials_collected,
	})


# --- Powerups ---

func add_powerup(pu: Dictionary, grade: int) -> void:
	var relative_grade: int = grade - pu.get("min_grade", 1) + 1
	# All categories tracked — used for display and rebuild
	active_powerups[pu["id"]] = active_powerups.get(pu["id"], 0) + relative_grade

