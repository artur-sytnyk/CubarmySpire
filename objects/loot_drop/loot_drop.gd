class_name LootDrop
extends Node2D


func setup(item: Dictionary) -> void:
	var icon: TextureRect = $Icon
	if item.get("type") == "gold":
		icon.texture = load("res://assets/images/coin.png" if randf() < 0.5 else "res://assets/images/coins.png")
		icon.modulate = GameData.COLOR_GOLD
	else:
		icon.texture = load("res://assets/images/material-1.png")
		icon.modulate = GameData.get_grade_color(item.get("grade", 1))

