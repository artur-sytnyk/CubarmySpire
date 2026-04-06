class_name WeaponSprite
extends Node2D

# TODO: consider moving WEAPON_BASE_OFFSET values to GameData alongside
# other spatial constants like LOOT_SCATTER_RADIUS.

# Per-weapon rest rotation in degrees — used as fallback and for death anim base.
# Sword: icon faces up by default, -45 puts it in the natural diagonal hold.
# Bow: rotation is fully dynamic (tracks target), this value unused during combat.
# Staff — TODO when sprite is added.
const WEAPON_ROT_OFFSET: Dictionary = {
	"warrior": 0.0,
	"ranger":  0.0,
	# "mage": 0.0,  # TODO
}

# Per-weapon base position offset relative to unit centre.
# Sword X is mirrored based on movement direction.
# Bow stays fixed at centre — rotation covers direction.
const WEAPON_BASE_OFFSET: Dictionary = {
	"warrior": Vector2(10.0, 12.0),
	"ranger":  Vector2(8.0, 0.0),
	# "mage":  Vector2(10.0, -8.0),  # TODO
}


const BOW_AIM_OFFSET_DEG: float = 45.0

# Velocity X below this threshold keeps the last known facing side.
const SIDE_DEAD_ZONE: float = 30.0

# Sword diagonal angles in degrees.
# Moving right: sword points bottom-right (+45 from horizontal).
# Moving left:  sword points bottom-left  (-45 from horizontal).
const SWORD_ANGLE_RIGHT: float = -110.0
const SWORD_ANGLE_LEFT: float = -70.0

@onready var _icon: Sprite2D = $WeaponIcon

var _unit_type: String = ""
var _rest_rotation: float = 0.0
var _base_offset: Vector2 = Vector2.ZERO
var _facing_right: bool = true

var _attack_tween: Tween = null


# --- Public API ---

func setup(p_unit_type: String) -> void:
	_unit_type = p_unit_type

	if not WEAPON_ROT_OFFSET.has(p_unit_type):
		_icon.visible = false
		return

	_rest_rotation = WEAPON_ROT_OFFSET[p_unit_type]
	_base_offset = WEAPON_BASE_OFFSET.get(p_unit_type, Vector2(10.0, 0.0))

	var texture: AtlasTexture = _get_texture()
	if texture == null:
		_icon.visible = false
		return

	_icon.texture = texture
	_icon.rotation_degrees = _rest_rotation
	_icon.visible = true
	position = _base_offset
	
	match p_unit_type:
		"warrior":
			_icon.offset = Vector2(12.0, 12.0)
		"ranger":
			_icon.offset = Vector2.ZERO


func update_weapon(velocity_x: float, target_position: Vector2) -> void:
	match _unit_type:
		"warrior":
			_update_sword(velocity_x)
		"ranger":
			_update_bow(target_position)
		# "mage":
		#     _update_staff(target_position)  # TODO


func play_attack() -> void:
	_kill_attack_tween()

	match _unit_type:
		"warrior":
			_play_sword_attack()
		"ranger":
			_play_bow_attack()
		# "mage":
		#     _play_staff_attack()  # TODO


func play_death() -> void:
	if _attack_tween != null and _attack_tween.is_valid():
		_attack_tween.kill()
	_attack_tween = null
	_icon.offset = Vector2.ZERO
	
	var rand_x: float = randf_range(-40.0, 40.0)
	var rand_rot: float = randf_range(300.0, 600.0)
	if randf() < 0.5:
		rand_rot = -rand_rot
	var start_pos: Vector2 = position

	_attack_tween = create_tween()
	_attack_tween.tween_property(
		self, "position",
		Vector2(start_pos.x + rand_x * 0.4, start_pos.y - 50.0),
		0.25
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_property(
		self, "position",
		Vector2(start_pos.x + rand_x, start_pos.y + 10.0),
		0.30
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_attack_tween.tween_property(
		_icon, "modulate:a",
		0.0,
		0.20
	).set_trans(Tween.TRANS_SINE)

	var rot_tween: Tween = create_tween()
	rot_tween.tween_property(
		_icon, "rotation_degrees",
		_icon.rotation_degrees + rand_rot,
		0.55
	).set_trans(Tween.TRANS_SINE)


# --- Private: per-frame updates ---

func _update_sword(velocity_x: float) -> void:
	if abs(velocity_x) > SIDE_DEAD_ZONE:
		_facing_right = velocity_x > 0.0
	
	position.x = _base_offset.x if _facing_right else -_base_offset.x
	position.y = _base_offset.y
	_icon.flip_v = not _facing_right
	_icon.offset = Vector2(12.0, 12.0) if _facing_right else Vector2(12.0, -12.0)
	
	if _attack_tween == null or not _attack_tween.is_valid():
		_icon.rotation_degrees = SWORD_ANGLE_RIGHT if _facing_right else SWORD_ANGLE_LEFT


func _update_bow(target_position: Vector2) -> void:
	position = _base_offset
	if target_position != Vector2.ZERO:
		var dir: Vector2 = target_position - global_position
		_icon.rotation = dir.angle() + deg_to_rad(BOW_AIM_OFFSET_DEG)
		var side: float = 1.0 if dir.x >= 0.0 else -1.0
		position.x = _base_offset.x * side


# --- Private: attack animations ---

func _play_sword_attack() -> void:
	var base_angle: float = SWORD_ANGLE_RIGHT if _facing_right else SWORD_ANGLE_LEFT
	var side: float = 1.0 if _facing_right else -1.0
	_attack_tween = create_tween()
	
	_attack_tween.tween_property(_icon, "rotation_degrees", base_angle, 0.0)
	_attack_tween.tween_property(
		_icon, "rotation_degrees",
		base_angle - 45.0 * side,
		0.25
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_property(
		_icon, "rotation_degrees",
		base_angle + 80.0 * side,
		0.1
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_attack_tween.tween_interval(0.2)
	_attack_tween.tween_property(
		_icon, "rotation_degrees",
		base_angle,
		0.3
	).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)


func _play_bow_attack() -> void:
	_attack_tween = create_tween()
	_attack_tween.tween_property(_icon, "skew", 0.5, 0.3)
	_attack_tween.tween_interval(0.2)
	_attack_tween.tween_property(_icon, "skew", -0.3, 0.1)
	_attack_tween.tween_property(_icon, "skew", 0.0, 0.2)


# --- Private: helpers ---

func _kill_attack_tween() -> void:
	if _attack_tween != null and _attack_tween.is_valid():
		_attack_tween.kill()
	_attack_tween = null
	_icon.rotation_degrees = _rest_rotation
	_icon.modulate.a = 1.0


func _get_texture() -> AtlasTexture:
	match _unit_type:
		"warrior": return IconDatabase.get_icon("sword")
		"ranger":  return IconDatabase.get_icon("bow")
		# "mage":  return WeaponSprite.get_icon("staff")  # TODO
	return null


