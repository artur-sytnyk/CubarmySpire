class_name Unit
extends CharacterBody2D

# Internal refs
@onready var sprite := $Sprite2D
@onready var weapon_sprite := $WeaponSprite
@onready var anim := $AnimationPlayer
@onready var nav_agent := $NavigationAgent2D
@onready var detection_area := $DetectionArea
@onready var attack_range_area := $AttackRangeArea
@onready var kite_area := $KiteArea
@onready var health_bar := $HealthBar
@onready var collision_body := $CollisionShape2D
@onready var level_lbl :Label = $LevelLabel

# Signals
signal died(unit: Unit)

# Unit specific constants
const RETARGET_INTERVAL: float = 0.5     # interval to check for new targets
const SEPARATION_RADIUS: float = 40.0    # distance within which allies push each other
const SEPARATION_STRENGTH: float = 1.0   # blend weight of separation vs movement
const TARGET_OFFSET_RADIUS: float = 45.0 # max radius of random offset around target position

# Stats
var unit_type: String
var level: int = 1
var faction: int
var hp_max: int
var hp_current: int
var atk_damage: int
var atk_cast_time: float
var _cast_timer: float = 0.0
var atk_cooldown: float
var _cooldown_timer: float = 0.0  # counts down after attack; unit can move but not attack
var atk_range: float
var kite_range: float
var is_ranged: bool
var speed: float
var detection_range: float
var current_state: State = State.IDLE
var target: Unit = null
var _retarget_timer: float = 0.0
var _enemies_in_detection: Array[Unit] = []
var _enemies_in_attack_range: Array[Unit] = []
var _enemies_in_kite_range: Array[Unit] = []

# Stable per-unit offset applied to target position while seeking.
var _target_offset: Vector2 = Vector2.ZERO
var _last_target: Unit = null

var _projectile_layer: Node2D = null
var _projectile_scene: PackedScene = preload("res://objects/projectile/Projectile.tscn")

# Unit States
enum State {
	IDLE,
	SEEKING,
	ATTACKING,
	KITING,
	KNOCKBACK,
	DEAD
}

# === ANIMATIONS ===
# Sprite frame indices (within a row of 7)
const FRAME_BASE    := 0  # idle_a / default
const FRAME_IDLE_B  := 1  # idle_b
const FRAME_WALK    := 2  # walk
const FRAME_CAST_A  := 3  # attack windup
const FRAME_CAST_B  := 4  # attack release
const FRAME_HIT_A   := 5  # hit flash a
const FRAME_HIT_B   := 6  # hit flash b

# Sprite animations
const IDLE_SWAP_INTERVAL: float  = 0.6   # idle blink rate
const WALK_SWAP_INTERVAL: float  = 0.15  # walk cycle rate
const HIT_FRAME_DURATION: float  = 0.1   # each hit frame duration

var _sprite_row: int = 0             # 0 = player, 1 = enemy
var _anim_timer: float = 0.0         # general idle/walk swap timer
var _anim_phase: bool = false        # toggles between frame pairs
var _hit_timer: float = 0.0          # counts down hit animation
var _hit_phase: int = 0              # 0 = not hitting, 1 = hit_a, 2 = hit_b

# Tween animations
var _sprite_tween: Tween = null
var _sprite_base_scale: Vector2 = Vector2.ONE
var _cast_phase: int = 0


# Behavior flags cached values
var _ricochet_count: int = 0
var _ricochet_damage_ratio: float = 0.0
var _has_flurry: bool = false
var _flurry_guaranteed: int = 0
var _flurry_bonus_chance: float = 0.0

# Shadows
const SHADOW_OFFSET:  float = 14.0
const SHADOW_WIDTH:   float = 16.0
const SHADOW_HEIGHT:  float = 12.0
const SHADOW_SKEW_X:  float = 16.0
const SHADOW_ALPHA:   float = 0.4
const SHADOW_INNER_WIDTH: float = 12.0
const SHADOW_INNER_ALPHA: float = 0.25

var _shadow: Polygon2D
var _shadow_inner: Polygon2D


# --- Stats & Setup ---

func apply_stats(stats: Dictionary) -> void:
	_update_sprite_row()
	unit_type = stats.get("unit_type", "")
	level = stats.get("level", 1)
	level_lbl.text = str(level)
	hp_max = stats.get("hp_max", 20)
	hp_current = hp_max
	health_bar.update(hp_current, hp_max)
	atk_damage = stats.get("atk_damage", 5)
	atk_cast_time = stats.get("atk_cast_time", 0.5)
	atk_cooldown = stats.get("atk_cooldown", 2.0)
	atk_range = stats.get("atk_range", 5.0)
	kite_range = atk_range * 0.5
	is_ranged = stats.get("is_ranged", false)
	speed = stats.get("speed", 50.0)
	detection_range = stats.get("detection_range", 1500.0)
	_update_behavioral_flags(stats.get("behavior_flags", {}))
	_update_collision_radii()
	weapon_sprite.setup(unit_type)


func _update_behavioral_flags(flags: Dictionary) -> void:
	if flags.has("ricochet"):
		_ricochet_count        = 1
		_ricochet_damage_ratio = flags["ricochet"]
	if flags.has("flurry"):
		var flurry_val: float  = flags["flurry"]
		_has_flurry = true
		_flurry_guaranteed     = int(flurry_val)
		_flurry_bonus_chance   = fmod(flurry_val, 1.0)


func _update_collision_radii() -> void:
	var attack_shape := attack_range_area.get_node("CollisionShape2D")
	var new_atk := CircleShape2D.new()
	new_atk.radius = atk_range
	attack_shape.set_deferred("shape", new_atk)

	var kite_shape := kite_area.get_node("CollisionShape2D")
	var new_kite := CircleShape2D.new()
	new_kite.radius = kite_range
	kite_shape.set_deferred("shape", new_kite)

	var detection_shape := detection_area.get_node("CollisionShape2D")
	var new_det := CircleShape2D.new()
	new_det.radius = detection_range
	detection_shape.set_deferred("shape", new_det)


func _update_sprite_row() -> void:
	_sprite_row = 0 if faction == Faction.PLAYER else 1
	_set_frame(FRAME_BASE)


func _set_frame(local_frame: int) -> void:
	sprite.frame = _sprite_row * 7 + local_frame


# --- Sprite scale tweens (sprite-only — physics body unaffected) ---

# Narrow squeeze during windup: unit tenses up before striking.
# Duration matches the first half of atk_cast_time so the pose holds
# naturally until the release fires.
func _play_attack_windup_sprite() -> void:
	if _sprite_tween:
		_sprite_tween.kill()
	_sprite_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sprite_tween.tween_property(
		sprite, "scale",
		_sprite_base_scale * Vector2(0.72, 1.22),
		atk_cast_time * 0.5
	)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_shadow, "scale:x", 0.85, atk_cast_time * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_shadow_inner, "scale:x", 0.85, atk_cast_time * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# Explosive expansion on damage deal, then spring back to neutral.
func _play_attack_release_sprite() -> void:
	if _sprite_tween:
		_sprite_tween.kill()
	
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_shadow, "scale:x", 1.45, atk_cast_time * 0.1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_shadow_inner, "scale:x", 1.45, atk_cast_time * 0.1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain()
	tween.tween_property(_shadow, "scale:x", 1.0, atk_cast_time * 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_shadow_inner, "scale:x", 1.0, atk_cast_time * 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	_sprite_tween = create_tween()
	_sprite_tween.tween_property(
		sprite, "scale",
		_sprite_base_scale * Vector2(1.45, 0.78),
		0.1
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sprite_tween.tween_property(
		sprite, "scale",
		_sprite_base_scale,
		0.2
	).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)


# Wide-short squish on receiving a hit, then bounce back.
func _play_hit_sprite() -> void:
	if _sprite_tween:
		_sprite_tween.kill()
	_sprite_tween = create_tween()
	_sprite_tween.tween_property(
		sprite, "scale",
		_sprite_base_scale * Vector2(1.35, 0.7),
		0.08
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sprite_tween.tween_property(
		sprite, "scale",
		_sprite_base_scale,
		0.16
	).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	# Shadow squish
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_shadow_inner, "scale", Vector2(0.6, 0.8), 0.08)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_shadow, "scale", Vector2(0.6, 0.8), 0.08)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(_shadow_inner, "scale", Vector2.ONE, 0.16)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(_shadow, "scale", Vector2.ONE, 0.16)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


# Kill any running sprite tween and snap back to neutral scale.
# Called on every state change so animations never bleed across states.
func _reset_sprite_scale() -> void:
	if _sprite_tween:
		_sprite_tween.kill()
		_sprite_tween = null
	sprite.scale = _sprite_base_scale


# --- Sprite animation ---

func _process(delta: float) -> void:
	_tick_hit_anim(delta)
	if _hit_phase > 0:
		return
	match current_state:
		State.IDLE:
			_anim_idle(delta)
		State.SEEKING:
			_anim_walk(delta)
		State.KITING:
			if _cast_timer > 0.0:
				_anim_attack(delta)
			else:
				_anim_walk(delta)
		State.ATTACKING:
			_anim_attack(delta)
		State.DEAD:
			_set_frame(FRAME_BASE)


func _anim_idle(delta: float) -> void:
	_anim_timer += delta
	if _anim_timer >= IDLE_SWAP_INTERVAL:
		_anim_timer = 0.0
		_anim_phase = not _anim_phase
		_set_frame(FRAME_IDLE_B if _anim_phase else FRAME_BASE)


func _anim_walk(delta: float) -> void:
	_anim_timer += delta
	if _anim_timer >= WALK_SWAP_INTERVAL:
		_anim_timer = 0.0
		_anim_phase = not _anim_phase
		_set_frame(FRAME_WALK if _anim_phase else FRAME_BASE)


func _anim_attack(delta: float) -> void:
	if _cooldown_timer > 0.0:
		# Attack cycle finished — reset cast phase so the next cast
		# triggers both tween phases fresh.
		_cast_phase = 0
		_anim_idle(delta)
		return
	if _cast_timer < atk_cast_time * 0.5:
		_set_frame(FRAME_CAST_A)
		# Fire windup tween only on the first frame of this phase.
		if _cast_phase != 1:
			weapon_sprite.play_attack()
			_cast_phase = 1
			_play_attack_windup_sprite()
	else:
		_set_frame(FRAME_CAST_B)
		# Fire release tween only on the first frame of this phase.
		if _cast_phase != 2:
			_cast_phase = 2
			_play_attack_release_sprite()


func _trigger_hit_anim() -> void:
	_hit_phase = 1
	_hit_timer = 0.0
	_set_frame(FRAME_HIT_A)
	_play_hit_sprite()


func _tick_hit_anim(delta: float) -> void:
	if _hit_phase == 0:
		return
	_hit_timer += delta
	if _hit_phase == 1 and _hit_timer >= HIT_FRAME_DURATION:
		_hit_phase = 2
		_hit_timer = 0.0
		_set_frame(FRAME_HIT_B)
	elif _hit_phase == 2 and _hit_timer >= HIT_FRAME_DURATION:
		_hit_phase = 0
		_hit_timer = 0.0
		_set_frame(FRAME_BASE)


# --- Ready ---

func _ready() -> void:
	# Capture before any tween or reset can touch sprite.scale.
	_sprite_base_scale = sprite.scale
	_build_shadow()
	add_to_group("units")
	_projectile_layer = get_tree().get_first_node_in_group("projectile_layer")
	detection_area.body_entered.connect(_on_detection_entered)
	detection_area.body_exited.connect(_on_detection_exited)
	attack_range_area.body_entered.connect(_on_attack_range_entered)
	attack_range_area.body_exited.connect(_on_attack_range_exited)
	kite_area.body_entered.connect(_on_kite_area_entered)
	kite_area.body_exited.connect(_on_kite_area_exited)


func _build_shadow() -> void:
	_shadow = Polygon2D.new()
	_shadow.z_index = -1
	_shadow.z_as_relative = true
	_shadow.color = Color(0.0, 0.0, 0.0, SHADOW_ALPHA)
	_shadow.polygon = PackedVector2Array([ # corners, clockwise
		Vector2(-SHADOW_WIDTH, SHADOW_OFFSET),
		Vector2( SHADOW_WIDTH, SHADOW_OFFSET),
		Vector2( SHADOW_WIDTH - SHADOW_SKEW_X, SHADOW_OFFSET + SHADOW_HEIGHT),
		Vector2(-SHADOW_WIDTH - SHADOW_SKEW_X, SHADOW_OFFSET + SHADOW_HEIGHT),
	])
	add_child(_shadow)
	
	_shadow_inner = Polygon2D.new()
	_shadow_inner.z_index = -1
	_shadow_inner.z_as_relative = true
	_shadow_inner.color = Color(0.0, 0.0, 0.0, SHADOW_ALPHA)
	_shadow_inner.polygon = PackedVector2Array([
		Vector2(-SHADOW_INNER_WIDTH + 4.0, SHADOW_OFFSET - 2.0),
		Vector2( SHADOW_INNER_WIDTH + 4.0, SHADOW_OFFSET - 2.0),
		Vector2( SHADOW_INNER_WIDTH - SHADOW_SKEW_X * 0.5, SHADOW_OFFSET + SHADOW_HEIGHT * 0.4),
		Vector2(-SHADOW_INNER_WIDTH - SHADOW_SKEW_X * 0.5, SHADOW_OFFSET + SHADOW_HEIGHT * 0.4),
	])
	add_child(_shadow_inner)


# --- Area callbacks ---

func _on_detection_entered(body: Node2D) -> void:
	if body is Unit and body.faction != faction and body.current_state != Unit.State.DEAD:
		_enemies_in_detection.append(body)
		body.died.connect(_on_enemy_died)
		if current_state == State.IDLE:
			_change_state(State.SEEKING)


func _on_detection_exited(body: Node2D) -> void:
	if body is Unit:
		_enemies_in_detection.erase(body)
		if body == target:
			_pick_target()


func _on_attack_range_entered(body: Node2D) -> void:
	if body is Unit and body.faction != faction:
		_enemies_in_attack_range.append(body)
		if current_state == State.SEEKING and _cooldown_timer <= 0.0:
			_change_state(State.ATTACKING)


func _on_attack_range_exited(body: Node2D) -> void:
	if body is Unit:
		_enemies_in_attack_range.erase(body)
		if body == target and _enemies_in_attack_range.is_empty():
			if current_state == State.KITING:
				_change_state(State.SEEKING)
			else:
				_change_state(State.SEEKING)


func _on_kite_area_entered(body: Node2D) -> void:
	if not is_ranged:
		return
	if body is Unit and body.faction != faction:
		_enemies_in_kite_range.append(body)
		_change_state(State.KITING)


func _on_kite_area_exited(body: Node2D) -> void:
	if not is_ranged:
		return
	if body is Unit and body.faction != faction:
		_enemies_in_kite_range.erase(body)
		if _enemies_in_kite_range.is_empty():
			if not _enemies_in_attack_range.is_empty():
				_change_state(State.ATTACKING)
			else:
				_change_state(State.SEEKING)


# --- Targeting ---

func _pick_target() -> void:
	if _enemies_in_detection.is_empty():
		target = null
		_change_state(State.IDLE)
		return
	var closest: Unit = null
	var closest_dist := INF
	for enemy in _enemies_in_detection:
		if enemy.current_state == Unit.State.DEAD:
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = enemy
	target = closest


func _on_enemy_died(unit: Unit) -> void:
	_enemies_in_detection.erase(unit)
	_enemies_in_attack_range.erase(unit)
	_enemies_in_kite_range.erase(unit)
	if unit == target:
		_pick_target()
	if current_state == State.ATTACKING and _enemies_in_attack_range.is_empty():
		_change_state(State.SEEKING)


func _tick_retarget(delta: float) -> void:
	_retarget_timer += delta
	if _retarget_timer >= RETARGET_INTERVAL:
		_retarget_timer = 0.0
		_pick_target()


# --- Combat ---

func _attack(delta: float) -> void:
	if _cooldown_timer > 0.0:
		return
	_cast_timer += delta
	if _cast_timer >= atk_cast_time:
		_cast_timer = 0.0
		_cast_phase = 0
		_set_frame(FRAME_BASE)
		_cooldown_timer = atk_cooldown
		_deal_damage()
		if _enemies_in_attack_range.is_empty():
			_change_state(State.SEEKING)


func _deal_damage() -> void:
	if target == null or not is_instance_valid(target):
		return
	if not _enemies_in_attack_range.has(target):
		return
	
	if unit_type == "ranger":
		SoundManager.play_sfx("bow_shoot")
		_shoot_projectile()
		return
	
	SoundManager.play_sfx("sword_swing")
	target.take_damage(atk_damage)
	
	# Flurry: 
	if _has_flurry:
		SoundManager.play_sfx("melee_flurry")
		if _flurry_guaranteed > 0:
			target.take_damage(atk_damage * _flurry_guaranteed)
		if _flurry_bonus_chance > 0.0 and randf() < _flurry_bonus_chance:
			target.take_damage(atk_damage)


func _shoot_projectile() -> void:
	if _projectile_layer == null:
		push_warning("unit_base: projectile_layer group node not found.")
		return
	
	var projectile: Projectile = _projectile_scene.instantiate()
	_projectile_layer.add_child(projectile)
	projectile.setup(
			self,
			target,
			atk_damage,
			_ricochet_count,
			_ricochet_damage_ratio
	)


func take_damage(amount: int) -> void:
	if current_state == State.DEAD:
		return
	SoundManager.play_sfx("unit_hit")
	hp_current -= amount
	health_bar.update(hp_current, hp_max)
	_trigger_hit_anim()
	if hp_current <= 0:
		_die()


func _die() -> void:
	if current_state == State.DEAD:
		return
	SoundManager.play_sfx("unit_death")
	_change_state(State.DEAD)
	remove_from_group("units")
	died.emit(self)
	set_physics_process(false)
	set_process(false)
	_play_death_anim()


# --- Separation steering ---

func _get_separation_vector() -> Vector2:
	var push := Vector2.ZERO
	for body in get_tree().get_nodes_in_group("units"):
		if body == self:
			continue
		if not body is Unit:
			continue
		if body.faction != faction:
			continue
		var diff: Vector2 = global_position - body.global_position
		var dist: float = diff.length()
		if dist < SEPARATION_RADIUS and dist > 0.0:
			push += diff.normalized() * (1.0 - dist / SEPARATION_RADIUS)
	if push.length() > 0.0:
		push = push.normalized()
	return push


# --- Target offset ---

func _get_target_offset() -> Vector2:
	if target != _last_target:
		_last_target = target
		var angle := randf() * TAU
		var radius := randf() * TARGET_OFFSET_RADIUS
		_target_offset = Vector2(cos(angle), sin(angle)) * radius
	return _target_offset


# --- Movement helper ---

func _move_toward_position(dest: Vector2) -> void:
	nav_agent.target_position = dest
	var next: Vector2 = nav_agent.get_next_path_position()
	var move_dir: Vector2 = (next - global_position).normalized()
	var sep: Vector2 = _get_separation_vector()
	velocity = (move_dir + sep * SEPARATION_STRENGTH).normalized() * speed
	move_and_slide()


func _move_toward_target() -> void:
	var dest: Vector2 = target.global_position + _get_target_offset()
	_move_toward_position(dest)

# --- Physics loop ---

func _physics_process(delta: float) -> void:
	var target_pos: Vector2 = target.global_position if target != null and is_instance_valid(target) else Vector2.ZERO
	weapon_sprite.update_weapon(target_pos)
	
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.SEEKING:
			_state_seeking(delta)
		State.ATTACKING:
			_state_attacking(delta)
		State.KITING:
			_state_kiting(delta)
		State.KNOCKBACK:
			_state_knockback(delta)
		State.DEAD:
			_state_dead(delta)


func _change_state(new_state: State) -> void:
	current_state = new_state
	_anim_timer = 0.0
	_anim_phase = false
	_cast_phase = 0
	_reset_sprite_scale()


# --- States ---

func _state_idle(_delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()


func _state_seeking(delta: float) -> void:
	_tick_retarget(delta)
	if target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if not _enemies_in_attack_range.is_empty():
		if _cooldown_timer <= 0.0:
			_change_state(State.ATTACKING)
		else:
			velocity = Vector2.ZERO
			move_and_slide()
		return
	_move_toward_target()


func _state_attacking(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		_change_state(State.SEEKING)
		return
	if _enemies_in_attack_range.is_empty():
		_change_state(State.SEEKING)
		return
	if is_ranged and not _enemies_in_kite_range.is_empty():
		_change_state(State.KITING)
		return
	var sep: Vector2 = _get_separation_vector()
	if sep.length() > 0.0:
		velocity = sep * speed * 0.8
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	
	_attack(delta)



func _state_kiting(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		_change_state(State.SEEKING)
		return
	if _enemies_in_kite_range.is_empty():
		if not _enemies_in_attack_range.is_empty():
			_change_state(State.ATTACKING)
		else:
			_change_state(State.SEEKING)
		return
	var away: Vector2 = (global_position - target.global_position).normalized()
	var away_dest: Vector2 = global_position + away * 100.0
	_move_toward_position(away_dest)
	
	_attack(delta)



func _state_knockback(_delta: float) -> void:
	pass


func _state_dead(_delta: float) -> void:
	pass


# --- Spawn animation ---

func play_spawn_anim() -> void:
	SoundManager.play_sfx("unit_spawn")
	_shadow.scale   = Vector2.ZERO
	_shadow_inner.scale   = Vector2.ZERO
	sprite.scale    = Vector2.ZERO
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(sprite, "scale", _sprite_base_scale, 1.0)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_shadow_inner, "scale", Vector2.ONE, 1.0)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_shadow, "scale", Vector2.ONE, 1.0)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Victory animation ---

func play_victory_anim() -> void:
	collision_body.set_deferred("disabled", true)
	var base_pos := position
	var shadow_base_scale := Vector2.ONE
	# Light comes from upper-left, so shadow shifts right and down on jump.
	var shadow_jump_offset := Vector2(-SHADOW_SKEW_X * 0.8, 32.0)
	var delay := randf_range(1.0, 3.0)
	var tween := create_tween().set_loops()

	tween.tween_interval(delay)

	# Squash on takeoff
	tween.tween_property(self, "scale", Vector2(1.15, 0.85), 0.1)\
		.set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_shadow, "scale", Vector2(1.15, 0.85), 0.1)\
		.set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_shadow_inner, "scale", Vector2(1.15, 0.85), 0.1)\
		.set_trans(Tween.TRANS_SINE)

	tween.tween_interval(0.1)

	# Rise — unit goes up, shadow shrinks and drifts toward light direction
	tween.tween_property(self, "position", base_pos + Vector2(0, -30), 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector2(0.85, 1.2), 0.12)\
		.set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_shadow, "scale", Vector2(0.8, 0.8), 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_shadow, "position", shadow_jump_offset, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_shadow_inner, "scale", Vector2(0.8, 0.8), 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_shadow_inner, "position", shadow_jump_offset, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.tween_interval(0.1)
	
	# Land — unit returns, shadow snaps back
	tween.tween_property(self, "position", base_pos, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.1)\
		.set_trans(Tween.TRANS_BOUNCE)
	tween.parallel().tween_property(_shadow, "scale", shadow_base_scale, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_shadow, "position", Vector2.ZERO, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_shadow_inner, "scale", shadow_base_scale, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_shadow_inner, "position", Vector2.ZERO, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _play_death_anim() -> void:
	weapon_sprite.play_death()
	if _sprite_tween:
		_sprite_tween.kill()
	
	_sprite_tween = create_tween()
	
	# Skew to simulate falling backward (isometric feel).
	_sprite_tween.tween_property(
		sprite, "skew",
		1.1,
		0.8
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Fade out while skewed.
	_sprite_tween.parallel().tween_property(
		sprite, "modulate:a",
		0.0,
		0.8
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# Also fade health bar and level label.
	_sprite_tween.parallel().tween_property(
		health_bar, "modulate:a",
		0.0,
		0.2
	).set_trans(Tween.TRANS_SINE)
	
	_sprite_tween.parallel().tween_property(
		level_lbl, "modulate:a",
		0.0,
		0.2
	).set_trans(Tween.TRANS_SINE)
	
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_shadow_inner, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_shadow, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_shadow_inner, "scale", Vector2.ZERO, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_shadow, "scale", Vector2.ZERO, 0.8).set_trans(Tween.TRANS_SINE)
	
	get_tree().create_timer(0.8).timeout.connect(queue_free)

