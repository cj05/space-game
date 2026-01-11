extends Node
@onready var parent := get_parent() as RigidBody2D
@export var thrust_force := 1200.0
func _physics_process(delta):
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mouse_pos := parent.get_global_mouse_position()
		var dir := (mouse_pos - parent.global_position).normalized()
		parent.apply_central_impulse(dir * thrust_force)
