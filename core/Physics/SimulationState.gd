class_name SimulationState
extends RefCounted

# Map of AbstractBinding -> SimulationSnapshot
var snapshots: Dictionary = {}
var timestamp: float = 0.0

func _init(_timestamp: float):
	timestamp = _timestamp

func get_snapshot(body: Node) -> SimulationSnapshot:
	return snapshots.get(body)

func has_body(body: Node) -> bool:
	return snapshots.has(body)

# Helper to get global positions without string keys
func get_global_pos(body: Node) -> Vector2:
	var s = snapshots.get(body)
	return s.global_r if s else Vector2.ZERO
