extends CanvasLayer

@onready var _settings_btn: Button = $DimRect/SettingsBtn

func _ready():
	visible = false
	_settings_btn.pressed.connect(_on_settings_pressed)


func _on_settings_pressed():
	SceneManager.open_settings()
