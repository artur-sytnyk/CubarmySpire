class_name BattleStatsCalculator
extends Node

# Base stats that equipment and powerups can scale.
const SCALABLE_STATS := ["hp_max", "atk_damage", "atk_range", "speed"]


# ── Public API ─────────────────────────────────────────────────────────────

static func calculate_player(unit_def: Dictionary, active_powerups: Dictionary) -> Dictionary:
	var base := _get_base_stats(unit_def)
	base = get_scaled_stats(base, unit_def.get("level", 1))
	_apply_equipment(base, unit_def)
	_apply_stat_multipliers(base, unit_def, active_powerups)
	_apply_behavior_flags(base, unit_def, active_powerups)
	return base

static func calculate_enemy(unit_def: Dictionary, stage: int) -> Dictionary:
	var base := _get_base_stats(unit_def)
	base = get_scaled_stats(base, unit_def.get("level", 1))
	var stage_scale: float = pow(1.1, stage - 1)
	var stage_bonus: float = pow(1.1, stage / 3)
	base["hp_max"]     = int(base["hp_max"]     * stage_scale * stage_bonus)
	base["atk_damage"] = int(base["atk_damage"] * stage_scale * stage_bonus)
	base["speed"]      = int(base["speed"]       * stage_scale * stage_bonus)
	return base

# ── Base stats ─────────────────────────────────────────────────────────────

static func _get_base_stats(unit_def: Dictionary) -> Dictionary:
	var unit_type: String = unit_def.get("unit_type", "")
	var level: int        = unit_def.get("level", 1)
	var template: Dictionary = GameData.units.get(unit_type, {})
	var base: Dictionary = template.get("base_stats", {}).duplicate()
	var level_mult: float = 1.0 + (level - 1) * 0.1
	
	base["unit_type"] = unit_def.get("unit_type", "")
	base["hp_max"]     = int(base.get("hp_max",     0.0) * level_mult)
	base["atk_damage"] = int(base.get("atk_damage", 0.0) * level_mult)
	base["speed"]      = base.get("speed", 0.0) * level_mult
	base["behavior_flags"] = {}
	return base

# ── Equipment ──────────────────────────────────────────────────────────────

static func _apply_equipment(base: Dictionary, unit_def: Dictionary) -> void:
	var unit_type: String = unit_def.get("unit_type", "")
	
	# Accumulate all multipliers per stat first, then apply once.
	# This matches the intended order: equipment before powerups.
	var stat_bonuses: Dictionary = {}	# stat → accumulated multiplier
	
	for item in RunState.active_equipment:
		var def: Dictionary = GameData.get_equipment(item.get("id", ""))
		# CATEGORIES loot_multiplier and one_time_event are intentionally not handled here
		# They affect RunState fields, applied in finalize_run() and army_manager.setup() respectively
		var category: String = def.get("category", "")
		var filter = def.get("filter", null)
		
		# Skip if filtered to a different unit type.
		if filter != null and filter != unit_type:
			continue
		
		var level: int  = item.get("level", 1)
		var grade: int  = item.get("grade", 1)
		var effect: float = def.get("base_value", 0.0) * level * (1.0 + (grade - 1) * 0.10)
		
		if category == "stat_multiplier":
			var stat: String = def.get("stat", "")
			if stat in SCALABLE_STATS:
				stat_bonuses[stat] = stat_bonuses.get(stat, 0.0) + effect
		
		elif category == "per_stage_event":
			# Prismatic Shrooms: apply the stage-selected stat stored in RunState.
			var stats := SCALABLE_STATS.duplicate()
			stats.shuffle()
			var shroom_stat: String = stats[0]
			if shroom_stat != "" and shroom_stat in SCALABLE_STATS:
				stat_bonuses[shroom_stat] = stat_bonuses.get(shroom_stat, 0.0) + effect
	
	# Apply accumulated equipment bonuses to base stats.
	for stat in stat_bonuses:
		if stat in base:
			var val = base[stat]
			if val is int:
				base[stat] = int(val * (1.0 + stat_bonuses[stat]))
			else:
				base[stat] = val * (1.0 + stat_bonuses[stat])

# ── Powerup stat multipliers ───────────────────────────────────────────────

static func _apply_stat_multipliers(base: Dictionary, unit_def: Dictionary, active_powerups: Dictionary) -> void:
	for pu_id in active_powerups:
		var pu: Dictionary = GameData.get_powerup(pu_id)
		if pu.get("category", "") != "stat_multiplier":
			continue
		var filter = pu.get("filter", null)
		if filter != null and filter != unit_def.get("unit_type", ""):
			continue
		var stat: String  = pu.get("stat", "")
		var grade: int    = active_powerups[pu_id]
		var value: float  = pu.get("value_per_grade", 0.0) * grade
		if stat in base:
			var val = base[stat]
			if val is int:
				base[stat] = int(val * (1.0 + value))
			else:
				base[stat] = val * (1.0 + value)

# ── Behavior flags ─────────────────────────────────────────────────────────

static func _apply_behavior_flags(base: Dictionary, unit_def: Dictionary, active_powerups: Dictionary) -> void:
	var flags: Dictionary = base["behavior_flags"]
	for pu_id in active_powerups:
		var pu: Dictionary = GameData.get_powerup(pu_id)
		if pu.get("category", "") != "behavior_flag":
			continue
		var filter = pu.get("filter", null)
		if filter != null and filter != unit_def.get("unit_type", ""):
			continue
		var grade: int   = active_powerups[pu_id]
		var flag: String = pu.get("flag", "")
		flags[flag] = pu.get("base_value", 0.0) + pu.get("value_per_grade", 0.0) * grade


static func get_scaled_stats(base_stats: Dictionary, level: int) -> Dictionary:
	var scaled: Dictionary = base_stats.duplicate()
	if level > 1:
		var hp_mult: float  = pow(GameData.LEVEL_SCALE_HP, level - 1)
		var atk_mult: float  = pow(GameData.LEVEL_SCALE_ATK, level - 1)
		var speed_bonus: int = GameData.LEVEL_SCALE_SPEED * level
		var range_bonus: int = GameData.LEVEL_SCALE_RANGE * level
		scaled["hp_max"]     = int(scaled["hp_max"]     * hp_mult)
		scaled["atk_damage"] = int(scaled["atk_damage"] * atk_mult)
		scaled["speed"]      = int(scaled["speed"]      + speed_bonus)
		scaled["atk_range"]  = int(scaled["atk_range"]  + range_bonus)
	return scaled

