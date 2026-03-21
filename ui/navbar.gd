extends CanvasLayer

signal open_settings_requested

const SCENE_CAMPAIGN  := "res://scenes/menus/Campaign.tscn"
const SCENE_ARMORY    := "res://scenes/menus/Armory.tscn"
const SCENE_GARRISON  := "res://scenes/menus/Garrison.tscn"
const SCENE_MARKET      := "res://scenes/menus/Market.tscn"

# Map button name → destination scene path.
const _NAV_MAP: Dictionary = {
	"CampaignBtn": SCENE_CAMPAIGN,
	"ArmoryBtn":   SCENE_ARMORY,
	"BarracksBtn": SCENE_GARRISON,
	"ShopBtn":     SCENE_MARKET,
}

@onready var _campaign_btn: Button = $PanelContainer/MarginContainer/HBoxContainer/CampaignBtn
@onready var _armory_btn: Button    = $PanelContainer/MarginContainer/HBoxContainer/ArmoryBtn
@onready var _garrison_btn: Button  = $PanelContainer/MarginContainer/HBoxContainer/GarrisonBtn
@onready var _market_btn: Button      = $PanelContainer/MarginContainer/HBoxContainer/MarketBtn
@onready var _settings_btn: Button  = $PanelContainer/MarginContainer/HBoxContainer/SettingsBtn

# All nav buttons in order — used for active-tab iteration.
var _nav_buttons: Array[Button]

func _ready() -> void:
	_nav_buttons = [_campaign_btn, _armory_btn, _garrison_btn, _market_btn]
	_settings_btn.icon = load("res://assets/images/cog.png")
	_campaign_btn.pressed.connect(func(): SceneManager.go_to(SCENE_CAMPAIGN))
	_armory_btn.pressed.connect(func():    SceneManager.go_to(SCENE_ARMORY))
	_garrison_btn.pressed.connect(func():  SceneManager.go_to(SCENE_GARRISON))
	_market_btn.pressed.connect(func():      SceneManager.go_to(SCENE_MARKET))
	_settings_btn.pressed.connect(func():  open_settings_requested.emit())


# Called by root_scene.gd after each scene transition.
func set_active_tab(current_path: String) -> void:
	for btn in _nav_buttons:
		var is_active: bool = _NAV_MAP.get(btn.name, "") == current_path
		# Toggle a custom StyleBox or a simple flat property to show active state.
		btn.flat = not is_active
		btn.add_theme_color_override(
			"font_color",
			Color(1.0, 0.85, 0.3) if is_active else Color(0.9, 0.9, 0.9)
		)

