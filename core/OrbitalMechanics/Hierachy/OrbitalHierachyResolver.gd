class_name OrbitalHierachyResolver

static func initialize_roots(model: OrbitalModel) -> void:
	var bodies := model.values()
	for body:AbstractBinding in bodies:
		if not body.produces_gravity:
			continue

		var parent = OrbitalHierarchy.find_best_primary(body, model)
		if parent:
			print("Gravity",body,parent)
			body.assign_parent(parent)
			body.solver_dirty = true

static func initialize_dependents(model: OrbitalModel) -> void:
	for body:AbstractBinding in model.values():
		if body.produces_gravity:
			continue

		var parent = OrbitalHierarchy.find_best_primary(body, model)
		if parent:
			body.assign_parent(parent)
			print("Non gravity",body,parent)
			body.solver_dirty = true



static func initialize(model: OrbitalModel) -> void:
	initialize_roots(model)
	initialize_dependents(model)

func evaluate(body: AbstractBinding, model: OrbitalModel) -> void:
	var current = body.get_parent_binding()
	var target = OrbitalHierarchy.find_best_primary(body, model)

	if target != current and _is_valid_transition(body, target):
		body._on_exit_soi(current)
		apply(body, target)
		body._on_enter_soi(target)

		body.context_dirty = true
		
func _is_valid_transition(body, target) -> bool:
	if target == body:
		return false
	if target and OrbitalHierarchy.is_descendant_of(target, body):
		return false
	return true
func apply(body: AbstractBinding, parent: AbstractBinding) -> void:
	body.assign_parent(parent)
