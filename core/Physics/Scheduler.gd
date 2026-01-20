## Scheduler.gd
extends Node

@export var enabled := true
@export var time_scale := 1.0

signal detect_event(t0: float, t1: float, last_snapshots: Dictionary, events: Array)
signal integrate(dt: float, is_ghost: bool, snapshots: Dictionary)
signal post_step(t:float)

enum EventResult { CONTINUE, REQUEUE }

var sim_time := 0.0
var current_frame_dt := 0.0 # Added: Ruler for the current step
var _counter := 0
var _queue: Heap
var _last_valid_snapshots: Dictionary = {}
var _substep_cache := {}
var _substep_cache_hits := 0
var _substep_cache_misses := 0

func get_substep_cache_stats() -> Dictionary:
	return {
		"hits": _substep_cache_hits,
		"misses": _substep_cache_misses,
		"size": _substep_cache.size()
	}

func _physics_process(delta: float):
	if not enabled: return
	step(delta * time_scale)
	
	var s = get_substep_cache_stats()
	print(
		"[Scheduler] substep cache: ",
		s.hits, " hits / ",
		s.misses, " misses (",
		s.size, " entries)"
	)
	emit_signal("post_step",sim_time)

func _ready():
	_queue = Heap.new(func(a, b): 
		if a.time == b.time: return a.order < b.order
		return a.time < b.time
	)

func next_order() -> int: # Added: Helper for event priority
	_counter += 1
	return _counter

func schedule_task(task: ScheduledTask):
	_queue.push(task)

func get_substep_state(sample_time: float, is_ghost: bool) -> SimulationState:
	var key := sample_time - sim_time
	
	if _substep_cache.has(key):
		_substep_cache_hits += 1
		return _substep_cache[key]
	_substep_cache_misses += 1 # ouchie
	var state := SimulationState.new(sample_time)
	var dt := key
	
	

	if dt > 0.0:
		emit_signal("integrate", dt, is_ghost, state.snapshots)
	
	if not is_ghost:
		_substep_cache.clear()
	_substep_cache[key] = state
	return state

func step(delta: float) -> void:
	_substep_cache.clear()
	_substep_cache_hits = 0
	_substep_cache_misses = 0
	current_frame_dt = delta # Set the ruler at start of step
	var target_time := sim_time + delta
	
	_scan_for_events(sim_time, target_time)

	while not _queue.is_empty():
		var task: ScheduledTask = _queue.peek()
		if task.time > target_time: break
		
		_queue.pop()
		
		var sample_point = task.exec_t if task.ghost else task.time
		var state := get_substep_state(sample_point, task.ghost)
		if not task.ghost:
			sim_time = task.time
			_last_valid_snapshots = state.snapshots

		var result = task.fn.call(state) # Pass the full state object
		
		if result == EventResult.REQUEUE: # Cleaned up local enum access
			_queue.filter(func(t): return t.body != task.body)
			if target_time - sim_time > 0.0001:
				_scan_for_events(sim_time, target_time)

	var remaining = target_time - sim_time
	if remaining > 0.0:
		emit_signal("integrate", remaining, false, _last_valid_snapshots)
		sim_time = target_time

func _scan_for_events(t0: float, t1: float):
	var events = []
	emit_signal("detect_event", t0, t1, _last_valid_snapshots, events)
	for e in events:
		var task = ScheduledTask.new(e.sample_t, e.t, next_order(), e.fn, e.ghost, e.get("body"))
		_queue.push(task)
