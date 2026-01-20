## SOIExitEvent.gd
class_name SOIExitEvent
extends Node

const EXIT_BUFFER := 1.005
const MAX_REFINE_DEPTH := 8

func register() -> void:
	Scheduler.detect_event.connect(_on_detect_event)

func _on_detect_event(d0: float, d1: float, _last_snapshots: Dictionary, events: Array) -> void:
	events.append({
		"sample_t": d1,
		"t": d0,
		"fn": probe_for_exit,
		"ghost": true,
		"body": null
	})

func probe_for_exit(state: SimulationState) -> void:
	var snaps := state.snapshots
	if snaps.is_empty():
		return

	for body:AbstractBinding in snaps.keys():
		# Skip roots / non-orbiters early
		if body.role <= OrbitalRole.Type.MOON:
			continue

		var parent := body.get_parent_binding()
		if parent == null:
			continue
		if parent.role == OrbitalRole.Type.STAR:
			continue
		if not snaps.has(parent):
			continue

		var s_body = snaps[body]
		var s_parent = snaps[parent]

		var rel_p :Vector2= s_body.global_r - s_parent.global_r
		var dist_sq := rel_p.length_squared()

		var soi := parent.get_soi_radius() * EXIT_BUFFER
		var soi_sq := soi * soi

		# Outside + hysteresis
		if dist_sq <= soi_sq:
			continue

		# Must be moving away
		var rel_v :Vector2= s_body.global_v - s_parent.global_v
		if rel_v.dot(rel_p) <= 0.0:
			continue
		
		#Performance.add_frame_marker("SOI Exit Scan Start")
		_refine_exit_and_inject(body, parent, 0.0, Scheduler.current_frame_dt, 0)

func _refine_exit_and_inject(body, parent, t_low: float, t_high: float, depth: int) -> void:
	# Bail if already transitioned
	if body.get_parent_binding() != parent:
		return

	if depth >= MAX_REFINE_DEPTH:
		_final_exit_inject(body, parent, t_high)
		return

	var t_mid := 0.5 * (t_low + t_high)

	Scheduler.schedule_task(ScheduledTask.new(
		Scheduler.sim_time + t_mid,
		Scheduler.sim_time,
		Scheduler.next_order(),
		func(state:SimulationState):
			# Parent may have changed since scheduling
			if body.get_parent_binding() != parent:
				return Scheduler.EventResult.CONTINUE

			var snaps := state.snapshots
			if not snaps.has(body) or not snaps.has(parent):
				return Scheduler.EventResult.CONTINUE

			var d :float = (snaps[body].global_r - snaps[parent].global_r).length()
			if d > parent.get_soi_radius():
				_refine_exit_and_inject(body, parent, t_low, t_mid, depth + 1)
			else:
				_refine_exit_and_inject(body, parent, t_mid, t_high, depth + 1)

			return Scheduler.EventResult.CONTINUE,
		true,
		body
	))

func _final_exit_inject(body, parent, t_offset: float) -> void:
	var t_hit := Scheduler.sim_time + t_offset
	var grand_parent :AbstractBinding = parent.get_parent_binding()

	Scheduler.schedule_task(ScheduledTask.new(
		t_hit,
		t_hit,
		Scheduler.next_order(),
		func(state):
			# Safety: already handled?
			if body.get_parent_binding() != parent:
				return Scheduler.EventResult.CONTINUE

			print("[EXIT] %s leaving %s SOI" % [body.name, parent.name])

			body.perform_soi_transition(grand_parent)

			# Snapshot sync (critical)
			if state.snapshots.has(body):
				var s = state.snapshots[body]
				s.rel_r = body.sim_position
				s.rel_v = body.sim_velocity
				s.mu = grand_parent.get_mu() if grand_parent else 0.0
				s.is_dirty = true

				s.global_r = body.get_global_position()
				s.global_v = body.get_global_velocity()

			return Scheduler.EventResult.CONTINUE,
		false,
		body
	))
