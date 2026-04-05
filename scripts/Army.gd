class_name Army
extends Node

# Signals
signal all_dead
signal loot_dropped(materials: Dictionary, gold: int, world_position: Vector2)

# Config
var faction: int
var active_limit: int = 10
var max_army_size: int = 20

# State
var unit_defs: Array = []
var active_powerups: Dictionary = {}
var alive_units: Array[Unit] = []
var reserve_queue: Array = []
var active_count: int = 0
var pending_loot: Dictionary = {}
var pending_gold: int = 0

# Spawn config
var spawn_point: Marker2D
var unit_scene: PackedScene
var arena: Node2D

const SPAWN_RADIUS: float = 50.0
const SPAWN_STAGGER_DELAY: float = 0.2


func setup(p_faction: int, p_spawn_point: Marker2D, p_unit_scene: PackedScene, p_arena: Node2D, p_unit_defs: Array = []) -> void:
	faction = p_faction
	spawn_point = p_spawn_point
	unit_scene = p_unit_scene
	arena = p_arena
	unit_defs = p_unit_defs


# --- Core rebuild ---

func rebuild(p_active_powerups: Dictionary) -> void:
	active_powerups = p_active_powerups
	_clear()
	for i in unit_defs.size():
		if i < active_limit:
			var def: Dictionary = unit_defs[i]
			get_tree().create_timer(i * SPAWN_STAGGER_DELAY).timeout.connect(
				func(): _spawn_unit(def)
			)
		else:
			reserve_queue.append(unit_defs[i])


func _clear() -> void:
	for unit in alive_units:
		unit.queue_free()
	alive_units.clear()
	reserve_queue.clear()
	active_count = 0
	pending_loot.clear()
	pending_gold = 0


# --- Spawn ---

func _spawn_unit(unit_def: Dictionary) -> void:
	var unit: Unit = unit_scene.instantiate()
	unit.faction = faction
	var stats: Dictionary
	if faction == Faction.PLAYER:
		stats = BattleStatsCalculator.calculate_player(unit_def, active_powerups)
	else:
		stats = BattleStatsCalculator.calculate_enemy(unit_def, RunState.stage)
	arena.call_deferred("add_child", unit)
	await unit.ready
	unit.apply_stats(stats)
	unit.global_position = _get_spawn_position()
	unit.died.connect(_on_unit_died)
	alive_units.append(unit)
	unit.play_spawn_anim()
	active_count += 1


func _get_spawn_position() -> Vector2:
	var offset: Vector2 = Vector2(
		randf_range(-SPAWN_RADIUS, SPAWN_RADIUS),
		randf_range(-SPAWN_RADIUS, SPAWN_RADIUS)
	)
	return spawn_point.global_position + offset


# --- Unit death ---

func _on_unit_died(unit: Unit) -> void:
	alive_units.erase(unit)
	active_count -= 1
	
	if faction == Faction.ENEMY:
		# Material drop
		var material_drop: Dictionary = RollManager.roll_materials_loot(RunState.stage, unit.level, unit.unit_type)
		for grade: int in material_drop:
			pending_loot[grade] = pending_loot.get(grade, 0) + material_drop[grade]
		# Gold drop
		var gold_drop = RollManager.roll_gold_loot(RunState.stage, unit.level, unit.unit_type)
		pending_gold += gold_drop
		loot_dropped.emit(material_drop, gold_drop, unit.global_position)
	
	unit.queue_free()
	
	if alive_units.is_empty() and reserve_queue.is_empty():
		all_dead.emit()
	elif not reserve_queue.is_empty() and active_count < active_limit:
		_spawn_unit(reserve_queue.pop_front())


# --- Public unit def helpers (called by RunState one_time_events) ---

func add_unit(unit_def: Dictionary) -> void:
	if unit_defs.size() >= max_army_size and not unit_def.get("temporary", false):
		return
	unit_defs.append(unit_def)


func spawn_temp_units(count: int) -> void:
	var lowest_level: int = _get_lowest_unit_level()
	for i in count:
		add_unit({
			"unit_type": _random_unit_type(),
			"level": lowest_level,
			"temporary": true
		})


func level_up_lowest_units(count: int) -> void:
	for i in count:
		var lowest_level: int = _get_lowest_unit_level()
		for unit_def in unit_defs:
			if unit_def.get("level", 1) == lowest_level:
				unit_def["level"] += 1
				break


# --- Private helpers ---

func _get_lowest_unit_level() -> int:
	var lowest: int = 9999
	for unit_def in unit_defs:
		if unit_def.get("level", 1) < lowest:
			lowest = unit_def["level"]
	return lowest


func _random_unit_type() -> String:
	return "warrior" if randf() < 0.5 else "ranger"
