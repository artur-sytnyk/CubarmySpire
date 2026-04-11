# SaveManager — autoload
extends Node

const SAVE_DIR: String = "user://saves_cubarmy_spire/"
const SLOT_COUNT: int = 3

var current_save: SaveData = null


func _ready() -> void:
	DirAccess.make_dir_absolute(SAVE_DIR)


func get_slot_path(slot: int) -> String:
	return SAVE_DIR + "save_%d.json" % slot


func load_all_slots() -> Array:
	var slots := []
	for i in range(1, SLOT_COUNT + 1):
		slots.append(load_slot(i))
	return slots


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(get_slot_path(slot))


func load_slot(slot: int) -> SaveData:
	if not slot_exists(slot):
		return null
	var file := FileAccess.open(get_slot_path(slot), FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		push_error("SaveManager: corrupted save file for slot %d, creating new." % slot)
		return create_new_save(slot)
	return SaveData.from_dict(data, slot)


func write_slot(save_data: SaveData) -> void:
	var file := FileAccess.open(get_slot_path(save_data.slot), FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data.to_dict(), "\t"))
	file.close()


func delete_slot(slot: int) -> void:
	if slot_exists(slot):
		DirAccess.remove_absolute(get_slot_path(slot))


func create_new_save(slot: int = 1) -> SaveData:
	var save := SaveData.new_game(slot)
	write_slot(save)
	return save


func get_current(slot: int = 1) -> SaveData:
	if current_save == null:
		return create_new_save()
	return current_save


func set_current(save_data: SaveData) -> void:
	current_save = save_data


func save_current() -> void:
	#print("curr save slot: ", current_save.slot)
	#print("curr save gold: ", current_save.gold)
	#print("curr save materials_inv: ", current_save.materials_inv)
	#print("curr save equipment_inv: ", current_save.equipment_inv)
	#print("curr save army_active: ", current_save.army_active)
	#print("curr save army_barracks: ", current_save.army_barracks)
	#print("curr save shop_equipment: ", current_save.shop_equipment)
	#print("curr save max_stage_reached: ", current_save.max_stage_reached)
	if current_save:
		write_slot(current_save)


func load_or_create(slot: int) -> SaveData:
	var save: SaveData
	if slot_exists(slot):
		save = load_slot(slot)
	else:
		save = create_new_save(slot)
	_sanitize_equipment(save)
	set_current(save)
	return save


func reset_slot(slot: int) -> void:
	delete_slot(slot)
	set_current(create_new_save(slot))


func update_max_stage(difficulty: String, stage: int) -> bool:
	if stage > current_save.max_stage_reached.get(difficulty, 0):
		current_save.max_stage_reached[difficulty] = stage
		return true
	return false


# Equipment

func has_equipment_space() -> bool:
	return current_save.equipment_inv.size() < GameData.MAX_ITEM_STACK


func try_add_equipment(item: Dictionary) -> bool:
	if not has_equipment_space():
		return false
	current_save.equipment_inv.append(item)
	return true


func _sanitize_equipment(save: SaveData) -> void:
	var removed: Array[String] = []
	save.equipment_inv = save.equipment_inv.filter(func(item: Dictionary) -> bool:
		var def: Dictionary = GameData.get_equipment(item.get("id", ""))
		if def.is_empty():
			removed.append(item.get("id", "unknown"))
			return false
		return true
	)
	if removed.is_empty():
		return
	print("SANITIZED EQUIPMENT ", removed)
	save_current()
