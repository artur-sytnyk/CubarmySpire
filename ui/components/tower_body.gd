extends Node2D
class_name TowerBody

const FACE_COLOR      := Color("#2a3444")
const DEPTH_COLOR     := Color("#1a2030")
const VEIN_COLOR      := Color("#9b4dff")
const VEIN_GLOW_COLOR := Color("#6b2dcc")

## Reminder: move tunable constants to GameData for easy balancing.
const TOWER_DEPTH  : float = 1600.0
const DEPTH_STRIP  : float = 60.0
const TAPER        : float = 40.0   # how much left/right edges angle inward at bottom

const STEPS        : int   = 20     # jagged edge subdivisions
const JAG_H        : float = 14.0   # horizontal jag range (keep small to avoid foldover)
const JAG_V        : float = 10.0   # vertical jag range

const BOTTOM_STEPS : int   = 14
const BOTTOM_BUMP  : float = 30.0

const VEIN_COUNT   : int   = 16

@onready var _vein_layer: Node2D    = $VeinsLayer

var _rng := RandomNumberGenerator.new()

const LAYERS_OFFSET: float = 100.0
const LAYER_COUNT   : int   = 9
const LAYER_STEP    : float = 160.0    # vertical offset between layers
const LAYER_JAG     : float = 12.0   # random displacement per layer vertex
const LAYER_DARK    : float = 0.07   # how much darker each layer gets

var _shader_material: ShaderMaterial
var _polygon_texture: Texture


func _ready() -> void:
	_shader_material = preload("res://assets/materials/arena_shader_material.tres")
	_polygon_texture =  preload("res://assets/textures/tower_bottom_1.png")


func build(smoothed_points: PackedVector2Array, center: Vector2, seed: int) -> void:
	print("TowerBody global_position: ", global_position)
	print("TowerBody owner: ", owner)
	print("TowerBody parent: ", get_parent().name)
	var test_poly := Polygon2D.new()
	test_poly.polygon = PackedVector2Array([
		Vector2(0, 600),
		Vector2(500, 600),
		Vector2(500, 800),
		Vector2(0, 800)
	])
	test_poly.color = Color(1, 0, 0, 1)
	test_poly.z_index = 100
	test_poly.z_as_relative = false
	add_child(test_poly)
	print("test_poly in tree: ", test_poly.is_inside_tree())
	print("test_poly visible: ", test_poly.visible)
	print("test_poly global_position: ", test_poly.global_position)
	_rng.seed = seed

	for child in get_children():
		if child is Polygon2D:
			child.queue_free()

	var front: Array[Vector2] = []
	for p in smoothed_points:
		if p.y >= center.y - 160.0:
			front.append(p)

	if front.size() < 2:
		push_warning("TowerBody: not enough front-facing points.")
		return

	front.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)

	for layer_i in LAYER_COUNT:
		var offset_y: float  = layer_i * LAYER_STEP + LAYERS_OFFSET
		var layer_seed: float = float(seed + layer_i * 17)
		var darkness: float  = 1.0 - layer_i * LAYER_DARK

		var layer_points: Array[Vector2] = []
		for p in front:
			var jag := Vector2(
				_rng.randf_range(-LAYER_JAG, LAYER_JAG),
				_rng.randf_range(-LAYER_JAG * 0.5, LAYER_JAG * 0.5)
			)
			layer_points.append(p + Vector2(0.0, offset_y) + jag)

		var bottom: Array[Vector2] = []
		for p in layer_points:
			bottom.append(p + Vector2(0.0, LAYER_STEP + LAYER_JAG))

		var poly := PackedVector2Array()
		for p in layer_points:
			poly.append(p)
		for i in range(bottom.size() - 1, -1, -1):
			poly.append(bottom[i])

		var polygon := Polygon2D.new()
		polygon.polygon = poly
		polygon.z_index = -layer_i - 1
		polygon.z_as_relative = false
		
		polygon.texture = _polygon_texture
		
		var mat: ShaderMaterial = _shader_material.duplicate()
		mat.set_shader_parameter("noise_seed_offset", layer_seed * 0.1)
		mat.set_shader_parameter("tint_color", Color(0.0, 0.3 * darkness, 0.5 * darkness, 1.0))
		#polygon.material = mat
		polygon.color = Color(1, 0, 0, 1) 
		add_child(polygon)
		
	_build_veins(front)


func _build_veins(front: Array[Vector2]) -> void:
	for child in _vein_layer.get_children():
		child.queue_free()

	var top_left:  Vector2 = front[0]
	var top_right: Vector2 = front[front.size() - 1]
	var face_width: float  = top_right.x - top_left.x
	var vein_top_y: float  = top_left.y + LAYERS_OFFSET
	print("top_left.y: ", top_left.y, " vein_top_y: ", vein_top_y)

	for _i in VEIN_COUNT:
		var vx: float     = top_left.x + _rng.randf_range(0.05, 0.95) * face_width
		var vy_top: float = top_left.y + DEPTH_STRIP + _rng.randf_range(10.0, 60.0)
		var vy_bot: float = vy_top + _rng.randf_range(60.0, 180.0)

		var pts: Array[Vector2] = []
		pts.append(Vector2(vx, vy_top))
		pts.append(Vector2(vx + _rng.randf_range(-6.0, 6.0), lerp(vy_top, vy_bot, 0.5)))
		pts.append(Vector2(vx + _rng.randf_range(-4.0, 4.0), vy_bot))

		var glow := Line2D.new()
		glow.width = _rng.randf_range(3.0, 5.0)
		glow.default_color = VEIN_GLOW_COLOR
		for pt in pts:
			glow.add_point(pt)
		_vein_layer.add_child(glow)

		var vein := Line2D.new()
		vein.width = _rng.randf_range(1.0, 2.0)
		vein.default_color = VEIN_COLOR
		for pt in pts:
			vein.add_point(pt)
		_vein_layer.add_child(vein)
