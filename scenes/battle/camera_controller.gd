extends Camera2D

# Arena bounds — change these when arena size changes
var arena_size: Vector2 = Vector2(1800.0, 1100.0)
var arena_origin: Vector2 = Vector2.ZERO

# Pan speed in pixels per second
const PAN_SPEED: float = 800.0

# Zoom settings
const ZOOM_MIN: float = 0.5
const ZOOM_MAX: float = 2.0
const ZOOM_STEP: float = 0.1

var _viewport_size: Vector2


func _ready() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	_viewport_size = get_viewport_rect().size
	arena_origin = _viewport_size * 0.75
	position = arena_origin + arena_size  * 0.4 + Vector2(150.0, 0.0)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_clamp_position()


func _on_viewport_size_changed() -> void:
	_viewport_size = get_viewport_rect().size
	_clamp_position()


func _process(delta: float) -> void:
	var dir := Vector2.ZERO

	if Input.is_action_pressed("battle_camera_up"):
		dir.y -= 1
	if Input.is_action_pressed("battle_camera_down"):
		dir.y += 1
	if Input.is_action_pressed("battle_camera_left"):
		dir.x -= 1
	if Input.is_action_pressed("battle_camera_right"):
		dir.x += 1

	if dir != Vector2.ZERO:
		position += dir.normalized() * PAN_SPEED * delta
		_clamp_position()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("battle_zoom_in"):
		zoom_by(ZOOM_STEP)
	elif event.is_action_pressed("battle_zoom_out"):
		zoom_by(-ZOOM_STEP)


func zoom_by(amount: float) -> void:
	var old_zoom: float = zoom.x
	var new_zoom: float = clamp(old_zoom + amount, ZOOM_MIN, ZOOM_MAX)
	if new_zoom == old_zoom:
		return

	var mouse_world: Vector2 = get_global_mouse_position()
	zoom = Vector2(new_zoom, new_zoom)
	var mouse_world_after: Vector2 = get_global_mouse_position()
	position += mouse_world - mouse_world_after
	_clamp_position()


func _clamp_position() -> void:
	var effective_viewport: Vector2 = _viewport_size / zoom
	var half: Vector2 = effective_viewport / 2.0
	var pad: Vector2 = effective_viewport / 3.0

	var min_x: float = arena_origin.x - pad.x + half.x
	var min_y: float = arena_origin.y - pad.y + half.y
	var max_x: float = arena_origin.x + arena_size.x + pad.x - half.x
	var max_y: float = arena_origin.y + arena_size.y + pad.y - half.y

	position.x = clamp(position.x, min_x, max_x)
	position.y = clamp(position.y, min_y, max_y)
