extends Node
@onready var parent := get_parent() as RigidBody2D
@export var thrust_force := 80

var last_err = 0
func _physics_process(delta):
	
	var mouse_pos := parent.get_global_mouse_position()
	var desired_heading := mouse_pos.angle_to_point(parent.global_position)
	var angle_error = angle_difference(parent.rotation + PI/2, desired_heading)
	var error_rate = (angle_error-last_err)/delta
	var PD = angle_error * 1.0 + error_rate * 1.0
	last_err = angle_error
	parent.apply_instant_torque(PD * 500.0) 
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		
		var forward_dir = Vector2.UP.rotated(parent.rotation)
		parent.add_force(forward_dir * thrust_force)
