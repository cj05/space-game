class_name OrbitalEventRegister

static var soi_enter_event:SOIEnterEvent
static var soi_exit_event:SOIExitEvent
static func register():
	soi_enter_event = SOIEnterEvent.new()
	soi_enter_event.register()
	soi_exit_event = SOIExitEvent.new()
	soi_exit_event.register()
