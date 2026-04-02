class_name Unit
extends CharacterBody2D

# Internal refs
@onready var sprite := $Sprite2D
@onready var anim := $AnimationPlayer
@onready var nav_agent := $NavigationAgent2D
@onready var detection_area := $DetectionArea
@onready var attack_range_area := $AttackRangeArea
@onready var kite_area := $KiteArea
@onready var health_bar := $HealthBar
@onready var collision_body := $CollisionShape2D

# Signals
signal died(unit: Unit)

# Unit specific constants
const RETARGET_INTERVAL: float = 0.5     # interval to check for new targets
const SEPARATION_RADIUS: float = 30.0    # distance within which allies push each other
const SEPARATION_STRENGTH: float = 1.0   # blend weight of separation vs movement
const TARGET_OFFSET_RADIUS: float = 20.0 # max radius of random offset around target position

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

# Animation timers
const IDLE_SWAP_INTERVAL: float  = 0.6   # idle blink rate
const WALK_SWAP_INTERVAL: float  = 0.15  # walk cycle rate
const HIT_FRAME_DURATION: float  = 0.1   # each hit frame duration

var _sprite_row: int = 0             # 0 = player, 1 = enemy
var _anim_timer: float = 0.0         # general idle/walk swap timer
var _anim_phase: bool = false        # toggles between frame pairs
var _hit_timer: float = 0.0          # counts down hit animation
var _hit_phase: int = 0              # 0 = not hitting, 1 = hit_a, 2 = hit_b

# Sprite-only scale tweens — target sprite.scale, never self.scale
# so physics body shape is completely unaffected.
var _sprite_tween: Tween = null
# Neutral scale captured from the Sprite2D node at _ready().
# All tween targets are expressed as multipliers of this value so the
# animations are correct regardless of the scale set in the scene.
var _sprite_base_scale: Vector2 = Vector2.ONE
# Tracks which attack animation phase has already fired this cast cycle so
# tween triggers run once per phase, not once per frame.
# 0 = idle/cooldown, 1 = windup (CAST_A), 2 = release (CAST_B)
var _cast_phase: int = 0


# --- Stats & Setup ---

func apply_stats(stats: Dictionary) -> void:
	_update_sprite_row()
	unit_type = stats.get("unit_type", "")
	level = stats.get("level", 1)
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
	_update_collision_radii()


func _update_collision_radii() -> void:
	var attack_shape := attack_range_area.get_node("CollisionShape2D")
	var new_atk := CircleShape2D.new()
	new_atk.radius = atk_range
	attack_shape.shape = new_atk

	var kite_shape := kite_area.get_node("CollisionShape2D")
	var new_kite := CircleShape2D.new()
	new_kite.radius = kite_range
	kite_shape.shape = new_kite

	var detection_shape := detection_area.get_node("CollisionShape2D")
	var new_det := CircleShape2D.new()
	new_det.radius = detection_range
	detection_shape.shape = new_det


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


# Explosive expansion on damage deal, then spring back to neutral.
func _play_attack_release_sprite() -> void:
	if _sprite_tween:
		_sprite_tween.kill()
	_sprite_tween = create_tween()
	_sprite_tween.tween_property(
		sprite, "scale",
		_sprite_base_scale * Vector2(1.45, 0.78),
		0.07
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sprite_tween.tween_property(
		sprite, "scale",
		_sprite_base_scale,
		0.18
	).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)


# Wide-short squish on receiving a hit, then bounce back.
func _play_hit_sprite() -> void:
	if _sprite_tween:
		_sprite_tween.kill()
	_sprite_tween = create_tween()
	_sprite_tween.tween_property(
		sprite, "scale",
		_sprite_base_scale * Vector2(1.35, 0.68),
		0.06
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sprite_tween.tween_property(
		sprite, "scale",
		_sprite_base_scale,
		0.14
	).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


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
	add_to_group("units")
	detection_area.body_entered.connect(_on_detection_entered)
	detection_area.body_exited.connect(_on_detection_exited)
	attack_range_area.body_entered.connect(_on_attack_range_entered)
	attack_range_area.body_exited.connect(_on_attack_range_exited)
	kite_area.body_entered.connect(_on_kite_area_entered)
	kite_area.body_exited.connect(_on_kite_area_exited)


# --- Area callbacks ---

func _on_detection_entered(body: Node2D) -> void:
	if body is Unit and body.faction != faction:
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

func _deal_damage() -> void:
	if target == null or not is_instance_valid(target):
		return
	if not _enemies_in_attack_range.has(target):
		return
	target.take_damage(atk_damage)


func take_damage(amount: int) -> void:
	if current_state == State.DEAD:
		return
	hp_current -= amount
	health_bar.update(hp_current, hp_max)
	_trigger_hit_anim()
	if hp_current <= 0:
		_die()


func _die() -> void:
	_change_state(State.DEAD)
	remove_from_group("units")
	died.emit(self)
	set_physics_process(false)
	set_process(false)


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


func _state_knockback(_delta: float) -> void:
	pass


func _state_dead(_delta: float) -> void:
	pass


# --- Spawn animation ---

func play_spawn_anim() -> void:
	scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Victory animation ---

func play_victory_anim() -> void:
	collision_body.disabled = true
	var base_pos := position
	var delay := randf_range(1.0, 3.0)
	var tween := create_tween().set_loops()
	tween.tween_interval(delay)
	tween.tween_property(self, "scale", Vector2(1.15, 0.85), 0.1).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(0.1)
	tween.tween_property(self, "position", base_pos + Vector2(0, -30), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(0.85, 1.2), 0.12).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(0.1)
	tween.tween_property(self, "position", base_pos, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BOUNCE)
