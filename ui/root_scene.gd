extends Node

const NAV_HIDDEN_SCENES: Array[String] = [
	"res://scenes/menus/IntroMenu.tscn",
	"res://scenes/battle/Battle.tscn",
]

# Must match the PanelContainer height in NavBar.tscn.
const NAV_HEIGHT: float = 60.0

@onready var scene_container: Node = $SceneContainer
@onready var color_rect: ColorRect = $TransitionLayer/ColorRect
@onready var animation_player: AnimationPlayer = $TransitionLayer/ColorRect/AnimationPlayer
@onready var _nav_bar: CanvasLayer = $NavBar
@onready var _settings_overlay: CanvasLayer = $SettingsOverlay

func _ready() -> void:
	# Viewport resize — rebuild animations with new width.
	get_viewport().size_changed.connect(_on_viewport_size_changed)

	# Initial color_rect position and animations.
	var w: float = get_viewport().get_visible_rect().size.x
	color_rect.position = Vector2(w, 0)
	_setup_transition_animations()

	# Wire NavBar and SettingsOverlay.
	_nav_bar.visible = false
	_settings_overlay.visible = false
	_nav_bar.open_settings_requested.connect(_on_open_settings)
	_settings_overlay.close_requested.connect(_on_close_settings)
	SceneManager.scene_changed.connect(_on_scene_changed)

	# Load initial scene.
	var menu = load("res://scenes/menus/IntroMenu.tscn").instantiate()
	scene_container.add_child(menu)

# ── Viewport resize ────────────────────────────────────────────────────────

func _on_viewport_size_changed() -> void:
	var w: float = get_viewport().get_visible_rect().size.x
	color_rect.position = Vector2(w, 0)
	var library := animation_player.get_animation_library("")
	library.remove_animation("slide_in")
	library.remove_animation("slide_out")
	_setup_transition_animations()

# ── Transition animations ──────────────────────────────────────────────────

func _setup_transition_animations() -> void:
	var w: float = get_viewport().get_visible_rect().size.x

	var slide_in := Animation.new()
	slide_in.length = 0.2
	var in_track := slide_in.add_track(Animation.TYPE_VALUE)
	slide_in.track_set_path(in_track, ":position")
	slide_in.track_insert_key(in_track, 0.0, Vector2(w, 0))
	slide_in.track_insert_key(in_track, 0.2, Vector2(0, 0))
	slide_in.value_track_set_update_mode(in_track, Animation.UPDATE_CONTINUOUS)

	var slide_out := Animation.new()
	slide_out.length = 0.2
	var out_track := slide_out.add_track(Animation.TYPE_VALUE)
	slide_out.track_set_path(out_track, ":position")
	slide_out.track_insert_key(out_track, 0.0, Vector2(0, 0))
	slide_out.track_insert_key(out_track, 0.2, Vector2(-w, 0))
	slide_out.value_track_set_update_mode(out_track, Animation.UPDATE_CONTINUOUS)

	var library := animation_player.get_animation_library("")
	library.add_animation("slide_in", slide_in)
	library.add_animation("slide_out", slide_out)

# ── Scene changed ──────────────────────────────────────────────────────────

func _on_scene_changed(path: String) -> void:
	var should_show := path not in NAV_HIDDEN_SCENES
	_nav_bar.visible = should_show
	if should_show:
		_nav_bar.set_active_tab(path)
	call_deferred("_apply_scene_offset", should_show)

# Push the loaded scene's root Control down so NavBar doesn't overlap content.
func _apply_scene_offset(nav_visible: bool) -> void:
	var children := scene_container.get_children()
	if children.is_empty():
		return
	var root := children[0]
	if root is Control:
		var offset := NAV_HEIGHT if nav_visible else 0.0
		root.set_anchor_and_offset(SIDE_TOP, 0.0, offset)

# ── Settings ───────────────────────────────────────────────────────────────

func _on_open_settings() -> void:
	_settings_overlay.open()

func _on_close_settings() -> void:
	_settings_overlay.close()
