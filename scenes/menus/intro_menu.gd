extends Control

@onready var start_button: Button = $StartGameBtn

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
	SaveManager.load_or_create(1)
	SceneManager.go_to("res://scenes/menus/Campaign.tscn", true)
