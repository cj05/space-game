# State2D.gd
extends RefCounted
class_name State2D

var r: Vector2
var v: Vector2

func _init(r_: Vector2, v_: Vector2):
	r = r_
	v = v_
	
func add(b:State2D)->State2D:
	return State2D.new(r+b.r,v+b.v)
