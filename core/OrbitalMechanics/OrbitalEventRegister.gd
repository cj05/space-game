class_name OrbitalEventRegister

static var soi_enter_event:SOIEnterEvent
static func register():
	soi_enter_event = SOIEnterEvent.new()
	soi_enter_event.register()
