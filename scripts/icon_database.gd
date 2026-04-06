extends Node

const ICON_SIZE: int = 32

const WEAPON_COORDS: Dictionary = {
	"sword": Vector2i(0, 19),
	"bow":   Vector2i(0, 12),
	"arrow": Vector2i(0, 13),
	"fireball": Vector2i(3, 6),
}

var _texture: Texture2D
var _cache: Dictionary = {}


func _ready() -> void:
	_texture = load("res://assets/images/weapons_sprite_clean.png")


func get_icon(id: String) -> AtlasTexture:
	if _cache.has(id):
		return _cache[id]
		
	if not WEAPON_COORDS.has(id):
		push_warning("WeaponSprite.get_icon: unknown id '%s'" % id)
		return null
	
	var coords: Vector2i = WEAPON_COORDS[id]
	var icon: AtlasTexture = AtlasTexture.new()
	icon.atlas = _texture
	icon.region = Rect2(
		coords.x * ICON_SIZE,
		coords.y * ICON_SIZE,
		ICON_SIZE,
		ICON_SIZE
	)
	icon.margin = Rect2(1, 1, -1, -1)
	_cache[id] = icon
	return icon

