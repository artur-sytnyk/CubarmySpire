extends Area2D
class_name Projectile

signal hit_target(projectile: Projectile, hit_position: Vector2)

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D

const _PROJECTILE_TYPES: Dictionary = {
	"arrow": { "atlas_key": "arrow", "offset": PI * 0.75},
	"fireball": { "atlas_key": "fireball", "offset": 0.0 },
}

const _UNIT_PROJECTILE_TYPE: Dictionary = {
	"ranger": "arrow",
	"mage":   "fireball",
}

var damage: int = 0
var speed: float = 600.0
var shooter: Unit = null
var shooter_faction: int = -1
var target: Node = null
var target_position: Vector2 = Vector2.ZERO
var already_hit: Array[Node] = []

var is_ricochet: bool = false
var ricochet_count: int = 0
var ricochet_damage: int = 0
var ricochet_search_radius: float = 200.0

var homing: bool = false
var explodes: bool = false
var exposion_damage: int = 0
var explosion_radius: float = 80.0

var sprite_rotation_offset: float = 0.0

var enemy_army_units: Array[Unit] = []

var _direction: Vector2 = Vector2.ZERO
var _done: bool = false
var _nav_polygon_points: PackedVector2Array = []



func setup(
		unit_source: Unit,
		p_target: Node,
		p_damage: int,
		p_ricochet_count: int,
		p_ricochet_damage_ratio: float
) -> void:
	damage = p_damage
	shooter = unit_source
	shooter_faction = unit_source.faction
	global_position = unit_source.global_position
	target = p_target
	target_position = p_target.global_position
	ricochet_count = p_ricochet_count
	ricochet_damage = int(p_damage * p_ricochet_damage_ratio)
	
	var enemy_army = get_tree().get_first_node_in_group("enemy_army")
	enemy_army_units = enemy_army.get("alive_units")
	
	var proj_type: String = _UNIT_PROJECTILE_TYPE.get(unit_source.get("unit_type"), "arrow")
	var type_data: Dictionary = _PROJECTILE_TYPES.get(proj_type, _PROJECTILE_TYPES["arrow"])
	if proj_type == "fireball":
		explodes = true
		homing = true
	sprite_rotation_offset = type_data["offset"]
	_sprite.texture = IconDatabase.get_icon(type_data["atlas_key"])
	_sprite.scale = Vector2(0.5, 0.5)
	
	_direction = (target_position - global_position).normalized()
	_update_rotation()



func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var nav: NavigationRegion2D = get_tree().get_first_node_in_group("arena_nav_region")
	if nav != null and nav.navigation_polygon != null:
		if nav.navigation_polygon.get_outline_count() > 0:
			var nav_transform: Transform2D = nav.global_transform
			for p in nav.navigation_polygon.get_outline(0):
				_nav_polygon_points.append(nav_transform * p)
	else:
		push_warning("Projectile: could not find arena_nav_region group node.")


func _physics_process(delta: float) -> void:
	if _done:
		return

	if homing and target != null and is_instance_valid(target):
		target_position = target.global_position
		_direction = (target_position - global_position).normalized()
		_update_rotation()

	global_position += _direction * speed * delta

	if not _is_inside_arena():
		_finish()


# Arena bounds check

func _is_inside_arena() -> bool:
	if _nav_polygon_points.is_empty():
		return true
	return Geometry2D.is_point_in_polygon(global_position, _nav_polygon_points)


# Hit handling

func _on_body_entered(body: Node) -> void:
	if _done:
		return
	if not body.has_method("take_damage"):
		return
	if body.get("faction") == shooter_faction:
		return
	if already_hit.has(body):
		return

	already_hit.append(body)
	if is_ricochet:
		body.take_damage(ricochet_damage)
	else:
		body.take_damage(damage)
	hit_target.emit(self, global_position)

	if explodes:
		_do_explosion()

	if ricochet_count > 0:
		var bounce_target: Node = _find_ricochet_target()
		if bounce_target != null:
			_do_ricochet(bounce_target)
			return

	_finish()


func _arrive_at_destination() -> void:
	if _done:
		return
	if explodes:
		_do_explosion()
	_finish()


# Damage


func _do_explosion() -> void:
	if enemy_army_units == null:
		return
	
	for unit: Node in enemy_army_units:
		if not is_instance_valid(unit):
			continue
		if unit.get("faction") == shooter_faction:
			continue
		if already_hit.has(unit):
			continue
		if global_position.distance_to(unit.global_position) <= explosion_radius:
			already_hit.append(unit)
			unit.take_damage(exposion_damage)


# Ricochet

func _find_ricochet_target() -> Node:
	if enemy_army_units == null:
		return null

	var best: Node = null
	var best_dist: float = INF

	for unit: Node in enemy_army_units:
		if not is_instance_valid(unit):
			continue
		if unit.get("faction") == shooter_faction:
			continue
		if already_hit.has(unit):
			continue
		var d: float = global_position.distance_to(unit.global_position)
		if d < ricochet_search_radius and d < best_dist:
			best_dist = d
			best = unit

	return best


func _do_ricochet(bounce_target: Node) -> void:
	is_ricochet = true
	ricochet_count -= 1
	target = bounce_target
	target_position = bounce_target.global_position
	_direction = (target_position - global_position).normalized()
	_update_rotation()


# Finish (on unit hit)

func _finish() -> void:
	_done = true
	_disable_collision()
	
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", position + _direction * 12.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", PI / 2, 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(queue_free)


# Helpers

func _disable_collision() -> void:
	if _collision != null:
		_collision.set_deferred("disabled", true)


func _update_rotation() -> void:
	rotation = _direction.angle()
	if _sprite != null:
		_sprite.rotation = sprite_rotation_offset

