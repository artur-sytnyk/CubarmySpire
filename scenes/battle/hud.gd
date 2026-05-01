class_name HUD
extends Control


# Selection visuals
const DRAG_RECT_FILL:   Color = Color(0.2, 0.6, 1.0, 0.12)
const DRAG_RECT_BORDER: Color = Color(0.2, 0.6, 1.0, 0.7)
const DRAG_RECT_WIDTH:  float = 1.5
const SELECT_CIRCLE_COLOR:  Color = Color(0.2, 0.9, 0.4, 0.85)
const SELECT_CIRCLE_RADIUS: float = 14.0
const SELECT_CIRCLE_WIDTH:  float = 1.8

# Set by BattleScene each frame while dragging
var _drag_rect_screen: Rect2 = Rect2()
var _draw_drag_rect:   bool  = false

# Set by BattleScene whenever selection changes
var _selected_screen_positions: Array[Vector2] = []


func set_drag_rect(rect: Rect2) -> void:
	_drag_rect_screen = rect
	_draw_drag_rect   = true
	queue_redraw()


func clear_drag_rect() -> void:
	_draw_drag_rect = false
	queue_redraw()


func set_selected_positions(positions: Array[Vector2]) -> void:
	_selected_screen_positions = positions
	queue_redraw()


func _draw() -> void:
	if _draw_drag_rect:
		draw_rect(_drag_rect_screen, GameData.COLOR_SELECTION_RECT_FILL)
		draw_rect(_drag_rect_screen, GameData.COLOR_SELECTION_RECT_BORDER, false, GameData.SELECTION_RECT_BORDER_WIDTH)
	
	for pos: Vector2 in _selected_screen_positions:
		draw_arc(pos, GameData.SELECTION_INDICATOR_SIZE, 0.0, TAU, 32, GameData.COLOR_UNIT_SELECTED, GameData.SELECTION_INDICATOR_WIDTH)
