extends Node
var model: OrbitalModel
var solver: OrbitalSolver
var registry: OrbitalRegistry

func _ready():
	OrbitalHierachyResolver.initialize(model)
	Scheduler.integrate.connect(_on_integrate)

func _enter_tree():
	model = OrbitalModel.new()
	solver = OrbitalSolver.new()
	registry = OrbitalRegistry.new()
	registry.set_model(model)
	solver.set_model(model)

func _on_integrate(delta:float):
	solver.step_all(delta)
