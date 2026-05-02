class_name BattleScene
extends Node2D

@onready var army_manager: ArmyManager = $ArmyManager
# Arena
@onready var arena: Node2D = $Arena
@onready var navigation_region: NavigationRegion2D = $Arena/NavigationRegion2D
@onready var player_spawn: Marker2D = $Arena/PlayerSpawnPoint
@onready var enemy_spawn: Marker2D = $Arena/EnemySpawnPoint
# UI
@onready var pause_button: Button = $UI/PauseButton
@onready var powerup_dialog = $UI/PowerupDialog
@onready var run_finalized_dialog = $UI/RunFinalizedDialog
@onready var _hud: HUD = $UI/HUD
@onready var _camera: Camera2D = $Arena/Camera2D
@onready var stage_label = $UI/StageLabel
# Pause
@onready var _pause_overlay: CanvasLayer = $UI/PauseOverlay
@onready var _resume_btn: Button = $UI/PauseOverlay/DimRect/VBox/ResumeBtn
@onready var _abandon_btn: Button = $UI/PauseOverlay/DimRect/VBox/AbandonBtn

var unit_scene: PackedScene = preload("res://objects/unit/Unit.tscn")
var loot_scene: PackedScene = preload("res://objects/loot_drop/LootDrop.tscn")
var _flag_scene: PackedScene = preload("res://objects/command_flag/Flag.tscn")

var _active_flags:                Array[Flag] = []
var _prev_command_selection_ids:  Array[int]  = []

var _selected_units:    Array[Unit]  = []
var _drag_start_world:  Vector2      = Vector2.ZERO
var _drag_end_world:    Vector2      = Vector2.ZERO
var _is_dragging:       bool         = false
const DRAG_MIN_PIXELS:  float        = 6.0   # below this = click, not drag


var _loot_objects: Array[Node] = []


func _ready() -> void:
	SoundManager.play_music("battle")
	_connect_signals()
	army_manager.setup(player_spawn, enemy_spawn, unit_scene)
	army_manager.start_battle()
	stage_label.text = "Floor: %d" % RunState.stage
	set_process_unhandled_input(true)


func _connect_signals() -> void:
	army_manager.battle_won.connect(_on_battle_won)
	army_manager.battle_lost.connect(_on_battle_lost)
	pause_button.pressed.connect(_on_pause_pressed)
	_resume_btn.pressed.connect(_on_resume_pressed)
	_abandon_btn.pressed.connect(_on_abandon_pressed)
	powerup_dialog.powerup_chosen.connect(_on_powerup_chosen)
	army_manager.enemy_army.loot_dropped.connect(_on_loot_dropped)
	RunState.run_finalized.connect(_on_run_finalized)


# --- Battle outcomes ---

func _on_battle_won() -> void:
	SoundManager.duck_music()
	SoundManager.play_ui("stage_win")
	pause_button.disabled = true
	_abandon_btn.disabled = true
	_collect_loot()
	_show_powerup_dialog()


func _collect_loot() -> void:
	# TODO neutral armies looting as game expands
	RunState.collect_gold(army_manager.enemy_army.pending_gold)
	RunState.collect_materials(army_manager.enemy_army.pending_loot)


func _on_loot_dropped(materials: Dictionary, gold: int, world_position: Vector2) -> void:
	_spawn_loot_drops(materials, gold, world_position)

func _show_powerup_dialog() -> void:
	var offers: Array = RollManager.roll_powerup_offers()
	powerup_dialog.show_offers(offers)


func _on_powerup_chosen(pu: Dictionary, grade: int) -> void:
	RunState.add_powerup(pu, grade)
	RunState.on_stage_complete()
	await get_tree().create_timer(1.0).timeout
	SceneManager.go_to("res://scenes/battle/Battle.tscn")


func _on_battle_lost() -> void:
	get_tree().paused = false
	_pause_overlay.visible = false
	SoundManager.play_music("run_end")
	RunState.finalize_run()


func _on_run_finalized(results: Dictionary) -> void:
	get_tree().paused = false
	run_finalized_dialog.show_results(results)


# --- RTS Selection ---

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.double_click:
					_handle_double_click_select(get_global_mouse_position())
					_update_hud_selection()
					_is_dragging = false
				else:
					_drag_start_world = get_global_mouse_position()
					_drag_end_world   = _drag_start_world
					_is_dragging      = true
			else:
				if not _is_dragging:
					return
				_is_dragging = false
				_hud.clear_drag_rect()
				
				var drag_screen_dist: float = (
					_world_to_screen(_drag_end_world) - _world_to_screen(_drag_start_world)
				).length()
				
				if drag_screen_dist < DRAG_MIN_PIXELS:
					_handle_click_select(_drag_start_world)
				else:
					_handle_rect_select(_drag_start_world, _drag_end_world)
				
				_update_hud_selection()
		
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if not _selected_units.is_empty():
				SoundManager.play_ui("button_click")
				var world_pos: Vector2 = get_global_mouse_position()
				_issue_formation_move(world_pos)
				_spawn_flag(world_pos)
	
	elif event is InputEventMouseMotion and _is_dragging:
		_drag_end_world = _camera.get_global_mouse_position()
		
		var screen_a: Vector2 = _world_to_screen(_drag_start_world)
		var screen_b: Vector2 = _world_to_screen(_drag_end_world)
		_hud.set_drag_rect(Rect2(screen_a, screen_b - screen_a).abs())
		
		_update_hud_selection()


func _handle_double_click_select(world_pos: Vector2) -> void:
	# First find which unit was clicked
	var clicked: Unit = null
	var best_dist: float = 24.0
	for unit: Unit in army_manager.player_army.alive_units:
		var d: float = unit.global_position.distance_to(world_pos)
		if d < best_dist:
			best_dist = d
			clicked   = unit
	
	if clicked == null:
		return
	
	# Then select all alive units of the same type
	_selected_units.clear()
	for unit: Unit in army_manager.player_army.alive_units:
		if unit.unit_type == clicked.unit_type:
			_selected_units.append(unit)


func _handle_click_select(world_pos: Vector2) -> void:
	_selected_units.clear()
	var units: Array[Unit] = army_manager.player_army.alive_units
	var best:      Unit  = null
	var best_dist: float = 24.0
	for unit: Unit in units:
		var d: float = unit.global_position.distance_to(world_pos)
		if d < best_dist:
			best_dist = d
			best      = unit
	if best != null:
		_selected_units.append(best)


func _handle_rect_select(world_a: Vector2, world_b: Vector2) -> void:
	_selected_units.clear()
	var rect: Rect2 = Rect2(world_a, world_b - world_a).abs()
	for unit: Unit in army_manager.player_army.alive_units:
		if rect.has_point(unit.global_position):
			_selected_units.append(unit)


func _update_hud_selection() -> void:
	var positions: Array[Vector2] = []
	for unit: Unit in _selected_units:
		if is_instance_valid(unit):
			positions.append(_world_to_screen(unit.global_position))
	_hud.set_selected_positions(positions)


func _issue_formation_move(centre: Vector2) -> void:
	var count: int = _selected_units.size()
	var grid_side: int = ceili(sqrt(float(count)))
	var half: float = (grid_side - 1) * 0.5
	var index: int = 0
	
	for x: int in range(grid_side):
		for y: int in range(grid_side):
			if index >= count:
				break
			var offset: Vector2 = Vector2(
				(x - half) * GameData.FORMATION_SPACING,
				(y - half) * GameData.FORMATION_SPACING
			)
			_selected_units[index].issue_move_command(centre + offset)
			index += 1


func _spawn_flag(world_pos: Vector2) -> void:
	if not _command_selection_changed():
		for flag: Flag in _active_flags:
			if is_instance_valid(flag):
				flag.queue_free()
		_active_flags.clear()
	
	_snapshot_command_selection()
	
	var lifetime: float = 5.0
	var best_time: float = INF
	for unit: Unit in _selected_units:
		if not is_instance_valid(unit):
			continue
		var dist: float = unit.global_position.distance_to(world_pos)
		if unit.speed > 0.0:
			var t: float = (dist / unit.speed) * GameData.FLAG_TRAVEL_EXTRA
			best_time = minf(best_time, t)
	if best_time < INF:
		lifetime = best_time
	
	var flag: Flag = _flag_scene.instantiate()
	$Arena.add_child(flag)
	_active_flags.append(flag)
	flag.spawn_at(world_pos, lifetime)
	
	_active_flags.assign(_active_flags.filter(
		func(f: Variant) -> bool: return is_instance_valid(f)
	))


func _command_selection_changed() -> bool:
	if _selected_units.size() != _prev_command_selection_ids.size():
		return true
	for i: int in _selected_units.size():
		if _selected_units[i].get_instance_id() != _prev_command_selection_ids[i]:
			return true
	return false


func _snapshot_command_selection() -> void:
	_prev_command_selection_ids.clear()
	for unit: Unit in _selected_units:
		_prev_command_selection_ids.append(unit.get_instance_id())


# Converts a world-space point to screen-space for HUD drawing.
# Uses the canvas transform which accounts for camera position and zoom.
func _world_to_screen(world_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_pos


func _process(delta: float) -> void:
	# Keep selection circles tracking units that are moving
	if not _selected_units.is_empty():
		_update_hud_selection()
	
	# Prune dead units from selection
	_selected_units = _selected_units.filter(
		func(u: Unit) -> bool: return is_instance_valid(u) and u._visual_state != Unit.VisualState.DEAD
	)


# --- Pause ---

func _on_pause_pressed() -> void:
	var paused: bool = !get_tree().paused
	get_tree().paused = paused
	_pause_overlay.visible = paused


func _on_resume_pressed() -> void:
	get_tree().paused = false
	_pause_overlay.visible = false


func _on_abandon_pressed() -> void:
	SoundManager.play_ui("run_abandon")
	get_tree().paused = false
	SceneManager.go_to("res://scenes/menus/Campaign.tscn", true)


# --- Loot drop from enemies

func _spawn_loot_drops(materials: Dictionary, gold: int, world_position: Vector2) -> void:
	var items: Array = []
	for grade: int in materials:
		items.append({ "type": "material", "grade": grade, "amount": materials[grade] })
	if gold > 0:
		items.append({ "type": "gold", "amount": gold })
	
	if _loot_objects.size() >= GameData.LOOT_CAP:
		return
	
	for item in items:
		var angle: float = randf() * TAU
		var radius: float = randf_range(GameData.LOOT_SCATTER_RADIUS * 0.3, GameData.LOOT_SCATTER_RADIUS)
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * radius
		_spawn_single_loot(item, world_position, world_position + offset)


func _spawn_single_loot(item: Dictionary, from_position: Vector2, to_position: Vector2) -> void:
	var obj: LootDrop = loot_scene.instantiate()
	if not obj:
		return
	$Arena/LootLayer.add_child(obj)
	obj.setup(item)
	obj.global_position = from_position
	obj.scale = Vector2.ZERO
	_loot_objects.append(obj)

	var rand_rot: float = randf_range(-400.0, 400.0)
	var tween: Tween = obj.create_tween()
	tween.tween_property(
		obj,
		"global_position",
		to_position,
		randf_range(0.15, 0.30)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(obj, "scale", Vector2(0.5, 0.5), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(obj, "rotation_degrees", rand_rot, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

