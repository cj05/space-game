class_name ScheduledTask

var exec_t: float    # The sampling/prediction point
var time: float      # The execution point
var order: int       # Tie-breaker for the Heap
var fn: Callable     # The logic to run
var ghost: bool      # Is this a side-effect-free probe?
var body: Node       # The body this task belongs to (for invalidation)
var metadata: Dictionary = {} # For any extra data like "event_type"

func _init(_exec_t: float, _time: float, _order: int, _fn: Callable, _ghost: bool, _body: Node):
	self.exec_t = _exec_t
	self.time = _time
	self.order = _order
	self.fn = _fn
	self.ghost = _ghost
	self.body = _body

func is_probe() -> bool:
	return exec_t != time or ghost
