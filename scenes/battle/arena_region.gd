extends NavigationRegion2D

@onready var _floor: Polygon2D = $"../ArenaFloor"
@onready var _border: Polygon2D = $"../ArenaBorder"

const BASE_SIZE: float = 1000.0
const CORNER_CUT: float = BASE_SIZE / (2.0 + sqrt(2.0))
const MAX_DISPLACEMENT: float = 80.0
const MIN_INSET: float = 40.0

# Visual settings
const BORDER_WIDTH: float = 24.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	#regenerate(RunState.stage)
	pass


func regenerate(p_seed: int) -> void:
	_rng.seed = p_seed
	
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
	
	var smoothed_points := _smooth_polygon(points, 2)
	
	_floor.polygon = smoothed_points

	var border_points := PackedVector2Array()
	for p in smoothed_points:
		var outward: Vector2 = (p - center).normalized()
		border_points.append(p + outward * BORDER_WIDTH)
	_border.polygon = _smooth_polygon(border_points, 2)

	var nav_poly := NavigationPolygon.new()
	nav_poly.add_outline(smoothed_points)
	var source_geometry := NavigationMeshSourceGeometryData2D.new()
	NavigationServer2D.parse_source_geometry_data(nav_poly, source_geometry, self)
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, source_geometry)
	navigation_polygon = nav_poly
	


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


func _smooth_polygon(polygon: PackedVector2Array, iterations: int) -> PackedVector2Array:
	var pts := polygon
	for _i in iterations:
		var smoothed := PackedVector2Array()
		var count := pts.size()
		for j in count:
			var a: Vector2 = pts[j]
			var b: Vector2 = pts[(j + 1) % count]
			smoothed.append(a.lerp(b, 0.25))
			smoothed.append(a.lerp(b, 0.75))
		pts = smoothed
	return pts


