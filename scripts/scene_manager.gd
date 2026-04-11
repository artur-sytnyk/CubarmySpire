extends Node

signal scene_changed(path: String)

var _scene_container: Node
var _animation_player: AnimationPlayer
var _history: Array[String] = []
var _current_scene_path: String = ""
var _is_transitioning: bool = false



func _ready() -> void:
	call_deferred("_init_refs")


func _init_refs() -> void:
	_scene_container = get_tree().root.get_node("Root/SceneContainer")
	_animation_player = get_tree().root.get_node("Root/TransitionLayer/ColorRect/AnimationPlayer")
	_current_scene_path = "res://scenes/menus/IntroMenu.tscn"


func go_to(scene_path: String, clear_history: bool = false) -> void:
	if _is_transitioning:
		return
	if clear_history:
		_history.clear()
	elif _current_scene_path != "":
		_history.push_back(_current_scene_path)
	await _do_transition(scene_path)


func go_back() -> void:
	if _is_transitioning or _history.is_empty():
		return
	var previous = _history.pop_back()
	await _do_transition(previous)


func replace(scene_path: String) -> void:
	if _is_transitioning:
		return
	await _do_transition(scene_path)


func clear_history() -> void:
	_history.clear()


func _do_transition(scene_path: String) -> void:
	_is_transitioning = true
	SoundManager.play_ui("transition")

	# Reset load screen position.
	var w: float = _animation_player.get_parent().get_viewport().get_visible_rect().size.x * 1.4
	_animation_player.get_parent().position = Vector2(w, 0)

	# Slide in load screen.
	_animation_player.play("slide_in")
	await _animation_player.animation_finished

	# Load target scene.
	for child in _scene_container.get_children():
		child.queue_free()
	var new_scene = load(scene_path).instantiate()
	_scene_container.add_child(new_scene)
	_current_scene_path = scene_path
	scene_changed.emit(scene_path)

	# Minimal pause between slides, then slide out.
	await get_tree().create_timer(0.1).timeout
	_animation_player.play("slide_out")
	await _animation_player.animation_finished

	_is_transitioning = false
