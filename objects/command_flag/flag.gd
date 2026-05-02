class_name Flag
extends Node2D

@onready var shadow: TextureRect = $TextureRect

const DROP_HEIGHT:   float = 80.0
const DROP_DURATION: float = 0.35


func spawn_at(world_pos: Vector2, lifetime: float) -> void:
	global_position = world_pos + Vector2(0.0, -DROP_HEIGHT)
	shadow.visible = false
	
	var hue: float = randf()
	modulate = Color.from_hsv(hue, 0.7, 1.0)
	
	get_tree().create_timer(DROP_DURATION).timeout.connect(
		func() -> void: SoundManager.play_ui("flag_drop")
	)
	
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", world_pos, DROP_DURATION)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	
	tween.tween_callback(func() -> void: shadow.visible = true)
	
	tween.tween_property(self, "scale", Vector2(1.3, 0.7), 0.06)\
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	var fade_start: float = maxf(lifetime - 0.5, DROP_DURATION + 0.18)
	tween.tween_interval(fade_start - DROP_DURATION - 0.18)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)\
		.set_trans(Tween.TRANS_SINE)
	tween.tween_callback(queue_free)

