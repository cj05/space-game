extends Node

## ---- Configuration ----
@export var enabled := true
@export var time_scale := 1.0

## ---- Internal state ----
var sim_time := 0.0
var _counter := 0

var _queue: Heap

## ---- Task structure ----
# {
#   time: float,
#   order: int,
#   fn: Callable
# }


#signal pre_step(dt: float)
#signal post_step(sim_time: float)
signal integrate(dt: float)
signal task_executed(sim_time: float)


# ------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------

func _ready():
	_queue = Heap.new(_task_less)

func _physics_process(delta: float):
	if not enabled:
		return

	step(delta * time_scale)

# ------------------------------------------------------------
# Public API
# ------------------------------------------------------------

func schedule(at_time: float, fn: Callable) -> void:
	_counter += 1
	_queue.push({
		"time": at_time,
		"order": _counter,
		"fn": fn
	})

func schedule_in(delay: float, fn: Callable) -> void:
	schedule(sim_time + delay, fn)
	
func schedule_instant(fn: Callable) -> void:
	schedule(0,fn)

func clear() -> void:
	_queue.clear()

# ------------------------------------------------------------
# Core stepping logic
# ------------------------------------------------------------

func step(dt: float) -> void:
	var target_time := sim_time + dt

	while not _queue.is_empty():
		var task = _queue.peek()
		if task.time > sim_time:
			break
		
		var sub_dt:float = task.time - sim_time
		if sub_dt > 0.0:
			sim_time += sub_dt
			emit_signal("integrate", sub_dt)
		
		task = _queue.pop()

		if task.fn.is_valid():
			task.fn.call()

		emit_signal("task_executed", sim_time)
		
	var remaining := target_time - sim_time
	if remaining > 0.0:
		sim_time += remaining
		emit_signal("integrate", remaining)

# ------------------------------------------------------------
# Heap comparator
# ------------------------------------------------------------

func _task_less(a, b) -> bool:
	if a.time == b.time:
		return a.order < b.order
	return a.time < b.time
