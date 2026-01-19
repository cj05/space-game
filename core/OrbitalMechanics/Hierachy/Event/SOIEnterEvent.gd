class_name SOIEnterEvent

func register():
	Scheduler.detect_event.connect(_on_detect_event)
	#print("yeaaaa",Scheduler.detect_event.get_connections())

func _on_detect_event(d0: float,d1: float,events: Array):
	var dt = d1-d0
	events.append({"t":d0 + dt/2,"fn":on_soi_enter})
	#print("oi")
	
func on_soi_enter():
	#print("hi")
	pass
	
