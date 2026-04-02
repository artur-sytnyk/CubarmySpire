extends Node

const iconSize = 32
var weaponsTexture = preload("res://assets/images/weapons_sprite.png")

var cachedIcons = {}

var weaponIcons = {
	"sword": Vector2i(0, 19),
	"bow": Vector2i(0, 12),
	"arrow": Vector2i(0, 13)
}


func getWeaponIconById(id: String) -> AtlasTexture:
	if cachedIcons.has(id):
		return cachedIcons[id]
	if !weaponIcons.has(id):
		return null
	
	var coords = weaponIcons[id]
	
	var icon = AtlasTexture.new()
	icon.atlas = weaponsTexture
	icon.region = Rect2(
		coords.x * iconSize,
		coords.y * iconSize,
		iconSize,
		iconSize
	)

	cachedIcons[id] = icon
	return icon
