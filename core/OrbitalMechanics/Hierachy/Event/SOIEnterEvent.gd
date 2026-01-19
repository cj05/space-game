class_name SOIEnterEvent

func register():
	Scheduler.detect_event.connect(_on_detect_event)
	#print("yeaaaa",Scheduler.detect_event.get_connections())

func _on_detect_event(d0: float,d1: float,events: Array):
	var dt = d1-d0
	events.append({"t":d0 + dt/4,"fn":on_soi_enter,"ghost":true})
	events.append({"t":d0 + dt*3/4,"fn":on_soi_enter,"ghost":true})
	events.append({"t":d0 + dt,"fn":on_soi_enter,"ghost":false})
	
	#print("oi")
	
func on_soi_enter(sim_snapshots:Dictionary):
	for planet in sim_snapshots.keys():
		print(planet,planet.sim_position,sim_snapshots[planet].global_r)
	
