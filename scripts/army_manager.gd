class_name ArmyManager
extends Node

@onready var player_army: Army = $PlayerArmy
@onready var enemy_army: Army = $EnemyArmy
@onready var arena: Node2D = get_parent().get_node("Arena")

signal battle_won
signal battle_lost

const INITIAL_ENEMY_COUNT_EASY: int = 4
const INITIAL_ENEMY_COUNT_NORMAL: int = 6
const INITIAL_ENEMY_COUNT_HARD: int = 10

const INITIAL_LEVEL_UPS_EASY: int = 0
const INITIAL_LEVEL_UPS_NORMAL: int = 1
const INITIAL_LEVEL_UPS_HARD: int = 2

const INITIAL_ACTIVE_COUNT: int = 10
const MAX_ACTIVE_COUNT: int = 50
const MAX_RESERVE_COUNT: int = 200

const CHANCE_INC_EASY: float = 0.3 # TODO return to 0.2, now higher for testing loses
const CHANCE_INC_NORMAL: float = 0.4
const CHANCE_INC_HARD: float = 0.6

const ACTIVE_GROWTH_EASY: int = 1
const ACTIVE_GROWTH_NORMAL: int = 2
const ACTIVE_GROWTH_HARD: int = 3


func setup(player_spawn: Marker2D, enemy_spawn: Marker2D, unit_scene: PackedScene) -> void:
	player_army.setup(Faction.PLAYER, player_spawn, unit_scene, arena, RunState.unit_defs.duplicate())
	enemy_army.setup(Faction.ENEMY, enemy_spawn, unit_scene, arena)
	_apply_powerup_events()
	_apply_equipment_events()
	enemy_army.all_dead.connect(_on_enemy_all_dead)
	player_army.all_dead.connect(_on_player_all_dead)


func _apply_powerup_events() -> void:
	for id in RunState.active_powerups:
		var pu: Dictionary = GameData.get_powerup(id)
		if pu.get("category") != "one_time_event":
			continue
		var amount: int = RunState.active_powerups[id] * pu.get("value", 1)
		match pu.get("event", ""):
			"increase_active_limit": player_army.active_limit  += amount
			"increase_max_limit":   player_army.max_army_size += amount
			"add_temp_unit":
				for _i in amount:
					_add_random_unit(RunState.unit_defs)
			"level_up_unit":
				for _i in amount:
					_level_up_lowest(RunState.unit_defs)


func _apply_equipment_events() -> void:
	for item in RunState.active_equipment:
		var def: Dictionary = GameData.get_equipment(item.get("id", ""))
		if def.get("category", "") != "one_time_event":
			continue
		var level: int    = item.get("level", 1)
		var grade: int    = item.get("grade", 1)
		var effect: float = (def.get("base_value", 0.0) + def.get("value_per_level", 0.0) * (level - 1)) * (1.0 + (grade - 1) * 0.10)
		match def.get("flag", ""):
			"leadership":         player_army.active_limit  += int(effect)
			"increase_max_limit": player_army.max_army_size += int(effect)


func start_battle() -> void:
	var enemy_defs: Array = _create_enemy_defs(RunState.stage, RunState.difficulty)
	print_debug("Enemy defs | difficulty: _%s_ | stage: _%d_ | enemies: _%d_" % [RunState.difficulty, RunState.stage, enemy_defs.size()])
	enemy_army.unit_defs = enemy_defs
	enemy_army.rebuild({})
	player_army.rebuild(RunState.active_powerups)


# --- Signals ---

func _on_enemy_all_dead() -> void:
	battle_won.emit()
	for unit in player_army.alive_units:
		unit.play_victory_anim()


func _on_player_all_dead() -> void:
	battle_lost.emit()


# --- Enemy generation ---

func _create_enemy_defs(stage: int, difficulty: String) -> Array:
	var initial_count: int = INITIAL_ENEMY_COUNT_EASY
	var initial_level_ups: int = INITIAL_LEVEL_UPS_EASY
	var chance_inc: float = CHANCE_INC_EASY
	var active_growth: int = ACTIVE_GROWTH_EASY
	var level_up_multiplier: int = 1

	match difficulty:
		"normal":
			initial_count = INITIAL_ENEMY_COUNT_NORMAL
			initial_level_ups = INITIAL_LEVEL_UPS_NORMAL
			chance_inc = CHANCE_INC_NORMAL
			active_growth = ACTIVE_GROWTH_NORMAL
			level_up_multiplier = 2
		"hard":
			initial_count = INITIAL_ENEMY_COUNT_HARD
			initial_level_ups = INITIAL_LEVEL_UPS_HARD
			chance_inc = CHANCE_INC_HARD
			active_growth = ACTIVE_GROWTH_HARD
			level_up_multiplier = 3

	return _fill_enemy_defs(stage, initial_count, initial_level_ups, chance_inc, active_growth, level_up_multiplier)


func _fill_enemy_defs(
	stage: int,
	initial_count: int,
	initial_level_ups: int,
	chance_inc: float,
	active_growth: int,
	level_up_multiplier: int
) -> Array:
	var units: Array = []
	var add_chance: float = 0.0
	var active_limit: int = INITIAL_ACTIVE_COUNT

	# Seed starting army
	for _i in initial_count:
		_add_random_unit(units)
	for _i in initial_level_ups:
		_level_up_lowest(units)
	
	for i in range(1, stage + 1):
		# Grow active cap every 5 stages
		if i % 5 == 0:
			active_limit = mini(active_limit + active_growth, MAX_ACTIVE_COUNT)
		
		# Accumulate add chance — slightly accelerates each stage
		add_chance += chance_inc * (1.0 + i * 0.05)
		
		# Overflow: guaranteed adds or level-ups
		while add_chance > 1.0:
			if units.size() >= MAX_RESERVE_COUNT:
				_level_up_lowest(units)
			else:
				_add_random_unit(units)
			add_chance -= 1.0

		# Probabilistic: one more chance this stage
		if add_chance > randf():
			if units.size() >= MAX_RESERVE_COUNT:
				_level_up_lowest(units)
			else:
				_add_random_unit(units)

		# Periodic level-ups every 5 stages, scaling with stage and difficulty
		if i % 5 == 0:
			var level_up_count: int = (i / 5) * level_up_multiplier
			for _j in level_up_count:
				_level_up_lowest(units)
	
	enemy_army.active_limit = active_limit
	
	return units


# --- Unit def helpers ---

func _add_random_unit(units: Array) -> void:
	units.append({
		"unit_type": "warrior" if randf() < 0.5 else "ranger",
		"level": 1
	})


func _level_up_lowest(units: Array) -> void:
	if units.is_empty():
		return
	var lowest_level: int = 9999
	var lowest_unit: Dictionary = {}
	for u in units:
		if u.get("level", 1) < lowest_level:
			lowest_level = u["level"]
			lowest_unit = u
	lowest_unit["level"] += 1

