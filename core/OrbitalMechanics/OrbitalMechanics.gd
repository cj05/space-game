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

func _enter_tree():
	# initialize solvers
	pass

func _physics_process(delta:float):
	solver.step_all(delta)
