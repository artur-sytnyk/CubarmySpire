extends NavigationRegion2D

@onready var _floor: Polygon2D = $"../ArenaFloor"
@onready var _border: Polygon2D = $"../ArenaBorder"
@onready var _shadow: Polygon2D = $"../ArenaShadow"

const BASE_SIZE: float = 1000.0
const CORNER_CUT: float = BASE_SIZE / (2.0 + sqrt(2.0))
const MAX_DISPLACEMENT: float = 60.0
const MIN_INSET: float = 40.0

# Visual settings
const BORDER_WIDTH: float = 12.0
const SHADOW_OFFSET: Vector2 = Vector2(2.0, 15.0)

var _rng := RandomNumberGenerator.new()


func _get_base_points() -> PackedVector2Array:
	var c := CORNER_CUT
	var s := BASE_SIZE
	var corners := [
		Vector2(c, 0),
		Vector2(s - c, 0),
		Vector2(s, c),
		Vector2(s, s - c),
		Vector2(s - c, s),
		Vector2(c, s),
		Vector2(0, s - c),
		Vector2(0, c),
	]
	var points := PackedVector2Array()
	for i in corners.size():
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % corners.size()]
		points.append(a)
		points.append(a.lerp(b, 1.0 / 3.0))
		points.append(a.lerp(b, 2.0 / 3.0))
	return points


func _ready() -> void:
	regenerate(RunState.stage)


func regenerate(seed: int) -> void:
	_rng.seed = seed
	
	var base_points := _get_base_points()
	var center := Vector2(BASE_SIZE, BASE_SIZE) / 2.0
	var points := PackedVector2Array()
	
	for base_point in base_points:
		var outward: Vector2 = (base_point - center).normalized()
		var displacement: float = _rng.randf_range(-MAX_DISPLACEMENT, MAX_DISPLACEMENT)
		var new_point: Vector2 = base_point + outward * displacement
		
		var min_dist: float = (base_point - center).length() - MIN_INSET
		if (new_point - center).length() < min_dist:
			new_point = center + outward * min_dist
		points.append(new_point)
		
	# Floor
	_floor.polygon = points
	
	# Border — expand each point outward from center by BORDER_WIDTH
	var border_points := PackedVector2Array()
	for p in points:
		var outward: Vector2 = (p - center).normalized()
		border_points.append(p + outward * BORDER_WIDTH)
	_border.polygon = border_points
	
	# Shadow — same as border but offset
	var shadow_points := PackedVector2Array()
	for p in border_points:
		shadow_points.append(p + SHADOW_OFFSET)
	_shadow.polygon = shadow_points
	
	# Navigation
	var nav_poly := NavigationPolygon.new()
	nav_poly.add_outline(points)
	nav_poly.make_polygons_from_outlines()
	navigation_polygon = nav_poly

