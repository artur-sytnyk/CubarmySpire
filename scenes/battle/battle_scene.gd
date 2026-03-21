class_name BattleScene
extends Node2D

@onready var army_manager: ArmyManager = $ArmyManager
@onready var arena: Node2D = $Arena
@onready var navigation_region: NavigationRegion2D = $Arena/NavigationRegion2D
@onready var player_spawn: Marker2D = $Arena/PlayerSpawnPoint
@onready var enemy_spawn: Marker2D = $Arena/EnemySpawnPoint
@onready var pause_button: Button = $UI/PauseButton
@onready var powerup_dialog = $UI/PowerupDialog
@onready var run_finalized_dialog = $UI/RunFinalizedDialog
# Pause
@onready var _pause_overlay: CanvasLayer = $UI/PauseOverlay
@onready var _resume_btn: Button = $UI/PauseOverlay/DimRect/VBox/ResumeBtn
@onready var _abandon_btn: Button = $UI/PauseOverlay/DimRect/VBox/AbandonBtn

var unit_scene: PackedScene = preload("res://objects/unit/Unit.tscn")
var loot_scene: PackedScene = preload("res://objects/loot_drop/LootDrop.tscn")

var _loot_objects: Array[Node] = []

func _ready() -> void:
	_connect_signals()
	army_manager.setup(player_spawn, enemy_spawn, unit_scene)
	army_manager.start_battle()


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
	_collect_loot()
	_show_powerup_dialog()


func _collect_loot() -> void:
	# TODO possible to accumulate from more enemy/neutral armies as game expands
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
	RunState.finalize_run()


func _on_run_finalized(results: Dictionary) -> void:
	run_finalized_dialog.show_results(results)
	pass


# --- Pause ---

func _on_pause_pressed() -> void:
	var paused: bool = !get_tree().paused
	get_tree().paused = paused
	_pause_overlay.visible = paused


func _on_resume_pressed() -> void:
	get_tree().paused = false
	_pause_overlay.visible = false


func _on_abandon_pressed() -> void:
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
	for i: int in items.size():
		var angle: float = (TAU / items.size()) * i
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * GameData.LOOT_SCATTER_RADIUS
		_spawn_single_loot(items[i], world_position + offset)


func _spawn_single_loot(item: Dictionary, spawn_position: Vector2) -> void:
	var obj: LootDrop = loot_scene.instantiate()
	if not obj:
		return
	$Arena/LootLayer.add_child(obj)
	obj.setup(item)
	obj.global_position = spawn_position
	_loot_objects.append(obj)

