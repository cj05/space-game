extends GutTest

const CA_Minimizer = preload(
	"res://core/OrbitalMechanics/Hierachy/CloseApproach/CA_Minimizer.gd"
)
const UniversalKeplerSolver = preload(
	"res://core/OrbitalMechanics/Solver/Kepler/Universal/UniversalKeplerSolver.gd"
)

func test_refines_to_local_minimum() -> void:
	var mu := 1.32712440018e11
	
	var earth := UniversalKeplerSolver.new(mu)
	earth.from_cartesian(Vector2(1.5e8, 0), Vector2(0, 29.78))
	
	var ship := UniversalKeplerSolver.new(mu)
	ship.from_cartesian(Vector2(1.45e8, -1e7), Vector2(5, 32))
	
	var cluster := {
		"brackets": [{ "a": 0.0, "b": 5.0 * 86400.0 }]
	}
	
	var minima := CA_Minimizer.refine_cluster_minima(
		cluster, ship, earth
	)
	
	assert_eq(minima.size(), 1)
