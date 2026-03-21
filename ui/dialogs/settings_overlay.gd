extends CanvasLayer

signal close_requested

const CONFIG_PATH := "user://settings.cfg"
const BUS_SFX     := "SFX"
const BUS_MUSIC   := "Music"

@onready var _sfx_slider: HSlider       = $DimRect/Panel/VBoxContainer/SfxRow/SfxSlider
@onready var _music_slider: HSlider     = $DimRect/Panel/VBoxContainer/MusicRow/MusicSlider
@onready var _reset_btn: Button         = $DimRect/Panel/VBoxContainer/ResetBtn
@onready var _quit_btn: Button          = $DimRect/Panel/VBoxContainer/QuitBtn
@onready var _close_btn: Button         = $DimRect/Panel/VBoxContainer/CloseBtn
@onready var _confirm_dialog: ConfirmationDialog = $ConfirmDialog

func _ready() -> void:
	_load_settings()
	
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_reset_btn.pressed.connect(_on_reset_pressed)
	_quit_btn.pressed.connect(_on_quit_pressed)
	_close_btn.pressed.connect(func(): close_requested.emit())
	
	_confirm_dialog.confirmed.connect(_on_reset_confirmed)
	# DimRect click outside panel closes overlay.
	$DimRect.gui_input.connect(_on_dim_input)

func open() -> void:
	visible = true

func close() -> void:
	visible = false

# ── Volume ─────────────────────────────────────────────────────────────────

func _on_sfx_changed(value: float) -> void:
	_set_bus_volume(BUS_SFX, value)
	_save_settings()

func _on_music_changed(value: float) -> void:
	_set_bus_volume(BUS_MUSIC, value)
	_save_settings()

func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	# Convert linear 0–1 to decibels. Mute at 0.
	if linear <= 0.0:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))

# ── Reset save ─────────────────────────────────────────────────────────────

func _on_reset_pressed() -> void:
	_confirm_dialog.dialog_text = "Reset save file?\nThis cannot be undone."
	_confirm_dialog.popup_centered()

func _on_reset_confirmed() -> void:
	SaveManager.reset_slot(1)
	close_requested.emit()
	SceneManager.go_to("res://scenes/menus/IntroMenu.tscn", true)

# ── Quit ───────────────────────────────────────────────────────────────────

func _on_quit_pressed() -> void:
	get_tree().quit()

# ── Click outside to close ─────────────────────────────────────────────────

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_requested.emit()

# ── Persist settings ───────────────────────────────────────────────────────

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx",   _sfx_slider.value)
	cfg.set_value("audio", "music", _music_slider.value)
	cfg.save(CONFIG_PATH)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		# First launch defaults.
		_sfx_slider.value   = 0.5
		_music_slider.value = 0.5
		_apply_all_volumes()
		return
	_sfx_slider.value   = cfg.get_value("audio", "sfx",   0.5)
	_music_slider.value = cfg.get_value("audio", "music", 0.5)
	_apply_all_volumes()

func _apply_all_volumes() -> void:
	_set_bus_volume(BUS_SFX,   _sfx_slider.value)
	_set_bus_volume(BUS_MUSIC, _music_slider.value)
