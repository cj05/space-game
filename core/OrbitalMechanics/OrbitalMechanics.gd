extends Node
var model: OrbitalModel
var solver: OrbitalSolver
var registry: OrbitalRegistry

func _ready():
	model = OrbitalModel.new()
	solver = OrbitalSolver.new()
	registry = OrbitalRegistry.new()
	registry.set_model(model)
	solver.set_model(model)
	Scheduler.integrate.connect(_on_integrate)

func _enter_tree():
	# initialize solvers
	pass

func _on_integrate(delta:float):
	solver.step_all(delta)
