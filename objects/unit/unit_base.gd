class_name Unit
extends CharacterBody2D


# ── Internal refs ────────────────────────────────────────────────────────────
@onready var sprite:            Sprite2D          = $Sprite2D
@onready var weapon_sprite:     Node2D            = $WeaponSprite
@onready var anim:              AnimationPlayer   = $AnimationPlayer
@onready var nav_agent:         NavigationAgent2D = $NavigationAgent2D
@onready var detection_area:    Area2D            = $DetectionArea
@onready var attack_range_area: Area2D            = $AttackRangeArea
@onready var kite_area:         Area2D            = $KiteArea
@onready var health_bar:        Node              = $HealthBar
@onready var collision_body:    CollisionShape2D  = $CollisionShape2D
@onready var level_lbl:         Label             = $LevelLabel


# ── Signals ──────────────────────────────────────────────────────────────────
signal died(unit: Unit)


# ── Tuning constants (candidates for GameData) ───────────────────────────────
const RETARGET_INTERVAL:    float = 0.5
const SEPARATION_RADIUS:    float = 40.0
const SEPARATION_STRENGTH:  float = 1.0
const TARGET_OFFSET_RADIUS: float = 45.0
const MOVE_ARRIVAL_RADIUS:  float = 16.0   # distance at which move command is considered done


# ── Stats ─────────────────────────────────────────────────────────────────────
var unit_type:       String = ""
var level:           int    = 1
var faction:         int    = 0
var hp_max:          int    = 1
var hp_current:      int    = 1
var atk_damage:      int    = 1
var atk_cast_time:   float  = 0.5
var atk_cooldown:    float  = 2.0
var atk_range:       float  = 5.0
var kite_range:      float  = 0.0
var is_ranged:       bool   = false
var speed:           float  = 50.0
var detection_range: float  = 1500.0


# ── Combat state ──────────────────────────────────────────────────────────────
var _is_casting:    bool  = false
var _cast_timer:    float = 0.0
var _cooldown_timer:float = 0.0


# ── RTS move command ──────────────────────────────────────────────────────────
var _has_move_command:  bool    = false
var _move_target_pos:   Vector2 = Vector2.ZERO


# ── Targeting ─────────────────────────────────────────────────────────────────
var target:                    Unit         = null
var _retarget_timer:           float        = 0.0
var _enemies_in_detection:     Array[Unit]  = []
var _enemies_in_attack_range:  Array[Unit]  = []
var _enemies_in_kite_range:    Array[Unit]  = []
var _target_offset:            Vector2      = Vector2.ZERO
var _last_target:              Unit         = null


# ── Behavior flags ────────────────────────────────────────────────────────────
var _ricochet_count:       int   = 0
var _ricochet_damage_ratio:float = 0.0
var _has_flurry:           bool  = false
var _flurry_guaranteed:    int   = 0
var _flurry_bonus_chance:  float = 0.0


# ── Visual state (animation label only) ──────────────────────────────────────
enum VisualState { IDLE, WALK, ATTACK, DEAD }
var _visual_state: VisualState = VisualState.IDLE

# Needed externally (dead targeting guard, etc.)
var current_state: VisualState :
	get:
		return _visual_state


# ── Sprite frame indices ──────────────────────────────────────────────────────
const FRAME_BASE:   int = 0
const FRAME_IDLE_B: int = 1
const FRAME_WALK:   int = 2
const FRAME_CAST_A: int = 3
const FRAME_CAST_B: int = 4
const FRAME_HIT_A:  int = 5
const FRAME_HIT_B:  int = 6

const IDLE_SWAP_INTERVAL: float = 0.6
const WALK_SWAP_INTERVAL: float = 0.15
const HIT_FRAME_DURATION: float = 0.1

var _sprite_row:        int     = 0
var _anim_timer:        float   = 0.0
var _anim_phase:        bool    = false
var _hit_timer:         float   = 0.0
var _hit_phase:         int     = 0
var _sprite_tween:      Tween   = null
var _sprite_base_scale: Vector2 = Vector2.ONE
var _cast_phase:        int     = 0


# ── Shadows ───────────────────────────────────────────────────────────────────
const SHADOW_OFFSET:       float = 14.0
const SHADOW_WIDTH:        float = 16.0
const SHADOW_HEIGHT:       float = 12.0
const SHADOW_SKEW_X:       float = 16.0
const SHADOW_ALPHA:        float = 0.4
const SHADOW_INNER_WIDTH:  float = 12.0
const SHADOW_INNER_ALPHA:  float = 0.25

var _shadow:       Polygon2D = null
var _shadow_inner: Polygon2D = null


# ── Projectile ────────────────────────────────────────────────────────────────
var _projectile_layer: Node2D    = null
var _projectile_scene: PackedScene = preload("res://objects/projectile/Projectile.tscn")


# ═════════════════════════════════════════════════════════════════════════════
# SETUP
# ═════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
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


func apply_stats(stats: Dictionary) -> void:
	_sprite_row = 0 if faction == Faction.PLAYER else 1
	_set_frame(FRAME_BASE)
	unit_type       = stats.get("unit_type", "")
	level           = stats.get("level", 1)
	level_lbl.text  = str(level)
	hp_max          = stats.get("hp_max", 20)
	hp_current      = hp_max
	health_bar.update(hp_current, hp_max)
	atk_damage      = stats.get("atk_damage", 5)
	atk_cast_time   = stats.get("atk_cast_time", 0.5)
	atk_cooldown    = stats.get("atk_cooldown", 2.0)
	atk_range       = stats.get("atk_range", 5.0)
	kite_range      = atk_range * 0.5
	is_ranged       = stats.get("is_ranged", false)
	speed           = stats.get("speed", 50.0)
	detection_range = stats.get("detection_range", 1500.0)
	_update_behavioral_flags(stats.get("behavior_flags", {}))
	_update_collision_radii()
	weapon_sprite.setup(unit_type)


func _update_behavioral_flags(flags: Dictionary) -> void:
	if flags.has("ricochet"):
		_ricochet_count        = 1
		_ricochet_damage_ratio = flags["ricochet"]
	if flags.has("flurry"):
		var v: float       = flags["flurry"]
		_has_flurry        = true
		_flurry_guaranteed = int(v)
		_flurry_bonus_chance = fmod(v, 1.0)


func _update_collision_radii() -> void:
	var atk_col: CollisionShape2D = attack_range_area.get_node("CollisionShape2D")
	var s_atk := CircleShape2D.new()
	s_atk.radius = atk_range
	atk_col.set_deferred("shape", s_atk)

	var kite_col: CollisionShape2D = kite_area.get_node("CollisionShape2D")
	var s_kite := CircleShape2D.new()
	s_kite.radius = kite_range
	kite_col.set_deferred("shape", s_kite)

	var det_col: CollisionShape2D = detection_area.get_node("CollisionShape2D")
	var s_det := CircleShape2D.new()
	s_det.radius = detection_range
	det_col.set_deferred("shape", s_det)


# ═════════════════════════════════════════════════════════════════════════════
# MAIN LOOP
# ═════════════════════════════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	if _visual_state == VisualState.DEAD:
		return

	# Timers tick regardless of what the unit is doing.
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

	# Cast ticks unconditionally — nothing interrupts a committed swing.
	_tick_cast(delta)

	var target_pos: Vector2 = target.global_position \
		if target != null and is_instance_valid(target) \
		else Vector2.ZERO
	weapon_sprite.update_weapon(target_pos)

	# ── Priority stack ───────────────────────────────────────────────────────
	# Evaluate top-to-bottom; first match wins for movement + visual.

	# 1. Mid-cast: unit stands still (separation drift only), animation locked.
	if _is_casting:
		_apply_separation_only()
		_set_visual(VisualState.ATTACK)
		return

	# 2. RTS move command overrides autonomous behaviour.
	if _has_move_command:
		_tick_retarget(delta)
		_try_start_attack()   # still attacks targets of opportunity while marching
		var dist: float = global_position.distance_to(_move_target_pos)
		if dist <= MOVE_ARRIVAL_RADIUS:
			_has_move_command = false
		else:
			_move_toward_position(_move_target_pos)
			_set_visual(VisualState.WALK)
		return

	# 3. Kiting: ranged unit backs away from close enemy.
	if is_ranged and not _enemies_in_kite_range.is_empty():
		_tick_retarget(delta)
		_try_start_attack()
		var away: Vector2 = (global_position - target.global_position).normalized()
		_move_toward_position(global_position + away * 100.0)
		_set_visual(VisualState.WALK)
		return

	# 4. Seeking: enemy detected, close in.
	if not _enemies_in_detection.is_empty():
		_tick_retarget(delta)
		if target == null:
			_set_visual(VisualState.IDLE)
			return
		if not _enemies_in_attack_range.is_empty():
			# In range — try to start an attack, drift only.
			_try_start_attack()
			_apply_separation_only()
			_set_visual(VisualState.ATTACK)
		else:
			_move_toward_target()
			_set_visual(VisualState.WALK)
		return

	# 5. Idle: nothing to do.
	velocity = Vector2.ZERO
	move_and_slide()
	_set_visual(VisualState.IDLE)


# ═════════════════════════════════════════════════════════════════════════════
# RTS COMMAND (called externally by selection/input system)
# ═════════════════════════════════════════════════════════════════════════════

func issue_move_command(world_pos: Vector2) -> void:
	_has_move_command = true
	_move_target_pos  = world_pos


# ═════════════════════════════════════════════════════════════════════════════
# COMBAT
# ═════════════════════════════════════════════════════════════════════════════

# Gate: only starts a cast, never interrupts one.
func _try_start_attack() -> void:
	if _is_casting:
		return
	if _cooldown_timer > 0.0:
		return
	if target == null or not is_instance_valid(target):
		return
	if not _enemies_in_attack_range.has(target):
		return
	_is_casting  = true
	_cast_timer  = 0.0
	_cast_phase  = 0


# Advances the committed cast. Lives outside the priority stack.
func _tick_cast(delta: float) -> void:
	if not _is_casting:
		return
	_cast_timer += delta
	if _cast_timer >= atk_cast_time:
		_is_casting = false
		_cast_timer = 0.0
		_cast_phase = 0
		_cooldown_timer = atk_cooldown
		_on_cast_complete()


func _on_cast_complete() -> void:
	_reset_sprite_scale()
	
	if unit_type == "ranger":
		SoundManager.play_sfx("bow_shoot")
		_shoot_projectile()
		return
	
	if target == null or not is_instance_valid(target):
		return
	
	SoundManager.play_sfx("sword_swing")
	target.take_damage(atk_damage)
	
	if _has_flurry:
		SoundManager.play_sfx("melee_flurry")
		for _i: int in _flurry_guaranteed:
			target.take_damage(atk_damage)
		if _flurry_bonus_chance > 0.0 and randf() < _flurry_bonus_chance:
			target.take_damage(atk_damage)


func _shoot_projectile() -> void:
	if _projectile_layer == null:
		push_warning("unit_base: projectile_layer not found.")
		return
	var proj: Projectile = _projectile_scene.instantiate()
	_projectile_layer.add_child(proj)
	proj.setup(self, target, atk_damage, _ricochet_count, _ricochet_damage_ratio)


func take_damage(amount: int) -> void:
	if _visual_state == VisualState.DEAD:
		return
	SoundManager.play_sfx("unit_hit")
	hp_current -= amount
	health_bar.update(hp_current, hp_max)
	_trigger_hit_anim()
	if hp_current <= 0:
		_die()


func _die() -> void:
	if _visual_state == VisualState.DEAD:
		return
	SoundManager.play_sfx("unit_death")
	_is_casting   = false
	_cast_timer   = 0.0
	_has_move_command = false
	_set_visual(VisualState.DEAD)
	remove_from_group("units")
	died.emit(self)
	set_physics_process(false)
	set_process(false)
	_play_death_anim()


# ═════════════════════════════════════════════════════════════════════════════
# MOVEMENT HELPERS
# ═════════════════════════════════════════════════════════════════════════════

func _move_toward_position(dest: Vector2) -> void:
	nav_agent.target_position = dest
	var next: Vector2    = nav_agent.get_next_path_position()
	var dir: Vector2     = (next - global_position).normalized()
	var sep: Vector2     = _get_separation_vector()
	velocity = (dir + sep * SEPARATION_STRENGTH).normalized() * speed
	move_and_slide()


func _move_toward_target() -> void:
	_move_toward_position(target.global_position + _get_target_offset())


func _apply_separation_only() -> void:
	var sep: Vector2 = _get_separation_vector()
	velocity = sep * speed * 0.8 if sep.length() > 0.0 else Vector2.ZERO
	move_and_slide()


func _get_separation_vector() -> Vector2:
	var push := Vector2.ZERO
	for body: Node in get_tree().get_nodes_in_group("units"):
		if body == self or not body is Unit:
			continue
		if (body as Unit).faction != faction:
			continue
		var diff: Vector2 = global_position - body.global_position
		var dist: float   = diff.length()
		if dist < SEPARATION_RADIUS and dist > 0.0:
			push += diff.normalized() * (1.0 - dist / SEPARATION_RADIUS)
	if push.length() > 0.0:
		push = push.normalized()
	return push


func _get_target_offset() -> Vector2:
	if target != _last_target:
		_last_target    = target
		var angle: float  = randf() * TAU
		var radius: float = randf() * TARGET_OFFSET_RADIUS
		_target_offset  = Vector2(cos(angle), sin(angle)) * radius
	return _target_offset


# ═════════════════════════════════════════════════════════════════════════════
# TARGETING
# ═════════════════════════════════════════════════════════════════════════════

func _pick_target() -> void:
	if _enemies_in_detection.is_empty():
		target = null
		return
	var closest: Unit  = null
	var best:    float = INF
	for enemy: Unit in _enemies_in_detection:
		if enemy._visual_state == VisualState.DEAD:
			continue
		var d: float = global_position.distance_to(enemy.global_position)
		if d < best:
			best    = d
			closest = enemy
	target = closest


func _tick_retarget(delta: float) -> void:
	_retarget_timer += delta
	if _retarget_timer >= RETARGET_INTERVAL:
		_retarget_timer = 0.0
		_pick_target()


func _on_enemy_died(unit: Unit) -> void:
	_enemies_in_detection.erase(unit)
	_enemies_in_attack_range.erase(unit)
	_enemies_in_kite_range.erase(unit)
	if unit == target:
		_pick_target()


# ═════════════════════════════════════════════════════════════════════════════
# AREA CALLBACKS
# ═════════════════════════════════════════════════════════════════════════════

func _on_detection_entered(body: Node2D) -> void:
	if body is Unit \
			and (body as Unit).faction != faction \
			and (body as Unit)._visual_state != VisualState.DEAD:
		var u: Unit = body as Unit
		_enemies_in_detection.append(u)
		u.died.connect(_on_enemy_died)


func _on_detection_exited(body: Node2D) -> void:
	if body is Unit:
		_enemies_in_detection.erase(body as Unit)
		if body == target:
			_pick_target()


func _on_attack_range_entered(body: Node2D) -> void:
	if body is Unit and (body as Unit).faction != faction:
		_enemies_in_attack_range.append(body as Unit)


func _on_attack_range_exited(body: Node2D) -> void:
	if body is Unit:
		_enemies_in_attack_range.erase(body as Unit)


func _on_kite_area_entered(body: Node2D) -> void:
	if is_ranged and body is Unit and (body as Unit).faction != faction:
		_enemies_in_kite_range.append(body as Unit)


func _on_kite_area_exited(body: Node2D) -> void:
	if is_ranged and body is Unit:
		_enemies_in_kite_range.erase(body as Unit)


# ═════════════════════════════════════════════════════════════════════════════
# VISUAL STATE
# ═════════════════════════════════════════════════════════════════════════════

# Sets the visual label. Does NOT reset animations if casting — the attack
# animation must run to completion uninterrupted.
func _set_visual(vs: VisualState) -> void:
	if vs == _visual_state:
		return
	_visual_state = vs
	_anim_timer   = 0.0
	_anim_phase   = false
	if not _is_casting:
		_cast_phase = 0
		_reset_sprite_scale()


func _process(delta: float) -> void:
	_tick_hit_anim(delta)
	if _hit_phase > 0:
		return
	match _visual_state:
		VisualState.IDLE:
			_anim_idle(delta)
		VisualState.WALK:
			_anim_walk(delta)
		VisualState.ATTACK:
			_anim_attack(delta)
		VisualState.DEAD:
			_set_frame(FRAME_BASE)


func _set_frame(local_frame: int) -> void:
	sprite.frame = _sprite_row * 7 + local_frame


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
	if not _is_casting:
		_cast_phase = 0
		_anim_idle(delta)
		return
	if _cast_timer < atk_cast_time * 0.5:
		_set_frame(FRAME_CAST_A)
		if _cast_phase != 1:
			weapon_sprite.play_attack()
			_cast_phase = 1
			_play_attack_windup_sprite()
	else:
		_set_frame(FRAME_CAST_B)
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


func _reset_sprite_scale() -> void:
	if _sprite_tween:
		_sprite_tween.kill()
		_sprite_tween = null
	sprite.scale = _sprite_base_scale


# ── Sprite squish tweens (identical to before) ────────────────────────────────

func _play_attack_windup_sprite() -> void:
	if _sprite_tween:
		_sprite_tween.kill()
	_sprite_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sprite_tween.tween_property(sprite, "scale", _sprite_base_scale * Vector2(0.72, 1.22), atk_cast_time * 0.5)
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(_shadow,       "scale:x", 0.85, atk_cast_time * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_shadow_inner, "scale:x", 0.85, atk_cast_time * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _play_attack_release_sprite() -> void:
	if _sprite_tween:
		_sprite_tween.kill()
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(_shadow,       "scale:x", 1.45, atk_cast_time * 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_shadow_inner, "scale:x", 1.45, atk_cast_time * 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.chain()
	t.tween_property(_shadow,       "scale:x", 1.0, atk_cast_time * 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_shadow_inner, "scale:x", 1.0, atk_cast_time * 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sprite_tween = create_tween()
	_sprite_tween.tween_property(sprite, "scale", _sprite_base_scale * Vector2(1.45, 0.78), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sprite_tween.tween_property(sprite, "scale", _sprite_base_scale, 0.2).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)


func _play_hit_sprite() -> void:
	if _sprite_tween:
		_sprite_tween.kill()
	_sprite_tween = create_tween()
	_sprite_tween.tween_property(sprite, "scale", _sprite_base_scale * Vector2(1.35, 0.7),  0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sprite_tween.tween_property(sprite, "scale", _sprite_base_scale,                        0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(_shadow_inner, "scale", Vector2(0.6, 0.8), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_shadow,       "scale", Vector2(0.6, 0.8), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(_shadow_inner, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(_shadow,       "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


# ═════════════════════════════════════════════════════════════════════════════
# SPAWN / VICTORY / DEATH ANIMATIONS (unchanged)
# ═════════════════════════════════════════════════════════════════════════════

func play_spawn_anim() -> void:
	SoundManager.play_sfx("unit_spawn")
	_shadow.scale       = Vector2.ZERO
	_shadow_inner.scale = Vector2.ZERO
	sprite.scale        = Vector2.ZERO
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(sprite,        "scale", _sprite_base_scale, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_shadow_inner, "scale", Vector2.ONE,        1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_shadow,       "scale", Vector2.ONE,        1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func play_victory_anim() -> void:
	collision_body.set_deferred("disabled", true)
	var base_pos:          Vector2 = position
	var shadow_base_scale: Vector2 = Vector2.ONE
	var shadow_jump_offset:Vector2 = Vector2(-SHADOW_SKEW_X * 0.8, 32.0)
	var delay:             float   = randf_range(1.0, 3.0)
	var tween: Tween = create_tween().set_loops()
	tween.tween_interval(delay)
	tween.tween_property(self, "scale", Vector2(1.15, 0.85), 0.1).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_shadow,       "scale", Vector2(1.15, 0.85), 0.1).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_shadow_inner, "scale", Vector2(1.15, 0.85), 0.1).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(0.1)
	tween.tween_property(self, "position", base_pos + Vector2(0, -30), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self,          "scale",    Vector2(0.85, 1.2),    0.12).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_shadow,       "scale",    Vector2(0.8, 0.8),     0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_shadow,       "position", shadow_jump_offset,    0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_shadow_inner, "scale",    Vector2(0.8, 0.8),     0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_shadow_inner, "position", shadow_jump_offset,    0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.1)
	tween.tween_property(self, "position", base_pos, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self,          "scale",    Vector2.ONE,        0.1).set_trans(Tween.TRANS_BOUNCE)
	tween.parallel().tween_property(_shadow,       "scale",    shadow_base_scale,  0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_shadow,       "position", Vector2.ZERO,       0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_shadow_inner, "scale",    shadow_base_scale,  0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_shadow_inner, "position", Vector2.ZERO,       0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _play_death_anim() -> void:
	weapon_sprite.play_death()
	if _sprite_tween:
		_sprite_tween.kill()
	_sprite_tween = create_tween()
	_sprite_tween.tween_property(sprite,      "skew",       1.1, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sprite_tween.parallel().tween_property(sprite,      "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_sprite_tween.parallel().tween_property(health_bar,  "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	_sprite_tween.parallel().tween_property(level_lbl,   "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(_shadow_inner, "modulate:a", 0.0,          0.8).set_trans(Tween.TRANS_SINE)
	t.tween_property(_shadow,       "modulate:a", 0.0,          0.8).set_trans(Tween.TRANS_SINE)
	t.tween_property(_shadow_inner, "scale",      Vector2.ZERO, 0.8).set_trans(Tween.TRANS_SINE)
	t.tween_property(_shadow,       "scale",      Vector2.ZERO, 0.8).set_trans(Tween.TRANS_SINE)
	get_tree().create_timer(0.8).timeout.connect(queue_free)


# ═════════════════════════════════════════════════════════════════════════════
# SHADOW BUILD
# ═════════════════════════════════════════════════════════════════════════════

func _build_shadow() -> void:
	_shadow             = Polygon2D.new()
	_shadow.z_index     = -1
	_shadow.z_as_relative = true
	_shadow.color       = Color(0.0, 0.0, 0.0, SHADOW_ALPHA)
	_shadow.polygon     = PackedVector2Array([
		Vector2(-SHADOW_WIDTH,              SHADOW_OFFSET),
		Vector2( SHADOW_WIDTH,              SHADOW_OFFSET),
		Vector2( SHADOW_WIDTH  - SHADOW_SKEW_X, SHADOW_OFFSET + SHADOW_HEIGHT),
		Vector2(-SHADOW_WIDTH  - SHADOW_SKEW_X, SHADOW_OFFSET + SHADOW_HEIGHT),
	])
	add_child(_shadow)

	_shadow_inner           = Polygon2D.new()
	_shadow_inner.z_index   = -1
	_shadow_inner.z_as_relative = true
	_shadow_inner.color     = Color(0.0, 0.0, 0.0, SHADOW_INNER_ALPHA)
	_shadow_inner.polygon   = PackedVector2Array([
		Vector2(-SHADOW_INNER_WIDTH + 4.0,               SHADOW_OFFSET - 2.0),
		Vector2( SHADOW_INNER_WIDTH + 4.0,               SHADOW_OFFSET - 2.0),
		Vector2( SHADOW_INNER_WIDTH - SHADOW_SKEW_X * 0.5, SHADOW_OFFSET + SHADOW_HEIGHT * 0.4),
		Vector2(-SHADOW_INNER_WIDTH - SHADOW_SKEW_X * 0.5, SHADOW_OFFSET + SHADOW_HEIGHT * 0.4),
	])
	add_child(_shadow_inner)

