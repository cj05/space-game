## SOIEnterEvent.gd
class_name SOIEnterEvent
extends Node

func register():
	Scheduler.detect_event.connect(_on_detect_event)

func _on_detect_event(d0: float, d1: float, _last_snapshots: Dictionary, events: Array):
	events.append({
		"sample_t": d1,
		"t": d0,
		"fn": probe_for_soi,
		"ghost": true,
		"body": null
	})

func probe_for_soi(state: SimulationState):
	var snaps = state.snapshots # Extract dictionary from state object
	
	for body in snaps.keys():
		var s_end = snaps[body]
		var siblings = body.get_sibling_sois()
		
		for sibling in siblings:
			if not snaps.has(sibling): continue
			
			var s_sib_end = snaps[sibling]
			var soi_radius = sibling.get_soi_radius()
			var dist_end = (s_end.global_r - s_sib_end.global_r).length()
			
			if dist_end < soi_radius:
				_refine_and_inject(body, sibling, 0.0, Scheduler.current_frame_dt, 0)
				return 
			
			# RV Minima Check
			var rel_pos_0 = body.sim_position - sibling.sim_position
			var rel_v_0 = body.sim_velocity - sibling.sim_velocity
			var rv_0 = rel_v_0.dot(rel_pos_0)
			
			var rel_pos_1 = s_end.global_r - s_sib_end.global_r
			var rel_v_1 = s_end.global_v - s_sib_end.global_v
			var rv_1 = rel_v_1.dot(rel_pos_1)
			
			if rv_0 < 0 and rv_1 > 0:
				_refine_minima_and_inject(body, sibling, soi_radius)

func _refine_minima_and_inject(body, sibling, soi_radius):
	var t_mid = Scheduler.current_frame_dt / 2.0
	
	Scheduler.schedule_task(ScheduledTask.new(
		Scheduler.sim_time + t_mid, Scheduler.sim_time, Scheduler.next_order(),
		func(state):
			var dist = (state.snapshots[body].global_r - state.snapshots[sibling].global_r).length()
			if dist < soi_radius:
				_refine_and_inject(body, sibling, 0.0, t_mid, 0),
		true, body
	))

func _refine_and_inject(body, sibling, t_low: float, t_high: float, depth: int):
	if depth >= 10:
		_final_inject(body, sibling, t_high)
		return

	var t_mid = (t_low + t_high) / 2.0
	Scheduler.schedule_task(ScheduledTask.new(
		Scheduler.sim_time + t_mid, Scheduler.sim_time, Scheduler.next_order(),
		func(state): _on_refine_step(state, body, sibling, t_low, t_high, depth),
		true, body
	))

func _on_refine_step(state: SimulationState, body, sibling, t_low, t_high, depth):
	var snaps = state.snapshots
	var t_mid = (t_low + t_high) / 2.0
	var dist = (snaps[body].global_r - snaps[sibling].global_r).length()
	
	if dist < sibling.get_soi_radius():
		_refine_and_inject(body, sibling, t_low, t_mid, depth + 1)
	else:
		_refine_and_inject(body, sibling, t_mid, t_high, depth + 1)

func _final_inject(body, sibling, t_offset):
	var t_hit = Scheduler.sim_time + t_offset
	Scheduler.schedule_task(ScheduledTask.new(
		t_hit, t_hit, Scheduler.next_order(),
		func(_state):
			body.perform_soi_transition(sibling)
			return Scheduler.EventResult.REQUEUE,
		false, body
	))
