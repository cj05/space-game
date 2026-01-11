class_name AbstractPerturbedSolver
extends AbstractSolver

var kepler_solver: AbstractSolver
var pert_solver: AbstractSolver

func use_pertubation(r, v) -> bool:
	return true
