extends Label


func _process(delta: float) -> void:
	set_text("FPS %f TPS %f" % [Engine.get_frames_per_second(),Engine.physics_ticks_per_second])
	scale = Vector2.ONE/get_parent().zoom
	
