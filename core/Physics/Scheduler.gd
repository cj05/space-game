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
signal detect_event(t0: float,t1: float,events:Array)
signal integrate(dt: float, is_ghost:bool,snapshots:Dictionary)
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

func schedule(at_time: float, fn: Callable, ghost: bool = false) -> void:
	_counter += 1
	_queue.push({
		"time": at_time,
		"order": _counter,
		"fn": fn,
		"ghost": ghost
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
	
	detect_and_schedule_events(dt)
	
	
	var target_time := sim_time + dt

	while not _queue.is_empty():
		var task = _queue.peek()
		var ghost = task.ghost
		if task.time > target_time:
			break
		var sim_snapshots = {} # This dictionary is passed by reference
		var sub_dt: float = task.time - sim_time
		
		print(sub_dt)
		if sub_dt > 0.0:
			sim_time += sub_dt
			# Pass the dictionary as an argument
			emit_signal("integrate", sub_dt, ghost, sim_snapshots) 
			
			# This will now contain data IF the solver filled it
			#print("K",sim_snapshots)
		task = _queue.pop()

		if task.fn.is_valid():
			task.fn.call(sim_snapshots)

		emit_signal("task_executed", sim_time)
		
	var remaining := target_time - sim_time
	if remaining > 0.0:
		sim_time += remaining
		emit_signal("integrate", remaining, false, {})

func detect_and_schedule_events(dt: float):
	var t0 := sim_time
	var t1 := sim_time + dt
	
	var events := []
	#print("emittor1",detect_event.get_connections())
	emit_signal("detect_event", t0, t1, events)
	#print("emittor2",detect_event.get_connections())
	
	
	for e in events:
		schedule(e.t, e.fn, e.ghost)

# ------------------------------------------------------------
# Heap comparator
# ------------------------------------------------------------

func _task_less(a, b) -> bool:
	if a.time == b.time:
		return a.order < b.order
	return a.time < b.time
