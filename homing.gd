extends Node

@onready var parent := get_parent() as RigidBody2D

@export var target: Node2D
@export var thrust_force := 80.0
@export var nav_gain := 50.0 # The "N" in ProNav (3.0-5.0 is sweet spot)

var last_los_angle := 0.0
var last_range := 0.0
var last_err := 0.0
func _physics_process(delta):
	if not target: return
	
	var relative_pos = target.global_position - parent.global_position
	var current_los_angle = relative_pos.angle()
	var current_range = relative_pos.length()

	# 1. Calculate LOS Rate
	var los_rate = angle_difference(last_los_angle, current_los_angle) / delta
	
	# 2. The Intercept Heading
	# ProNav says: Your velocity should change at N * LOS_Rate.
	# We simplify this: Target Heading = Current LOS + (Gain * LOS_Rate)
	var desired_heading = current_los_angle + (nav_gain * los_rate * delta)
	
	# 3. Torque Logic (The "Turning" part)
	# How far is our nose from the desired intercept heading?
	
	var angle_error = angle_difference(parent.rotation - PI/2, desired_heading)
	var error_rate = (angle_error-last_err)/delta
	var PD = angle_error * 1.0 + error_rate * 1.0
	last_err = angle_error
	parent.apply_instant_torque(PD * 500.0) 
	# Apply torque to rotate the nose (adjust 500.0 to change turn speed)
	parent.apply_instant_torque(angle_error * 500.0) 
	# Add damping to stop the nose from wobbling/oscillating

	# 4. Constant Forward Thrust
	# Now the engine actually pushes where the nose is pointing!
	var forward_dir = Vector2.UP.rotated(parent.rotation)
	parent.add_force(forward_dir * thrust_force)

	last_los_angle = current_los_angle
	last_range = current_range
