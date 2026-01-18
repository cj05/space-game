extends GutTest

const CA_Minimizer = preload(
	"res://core/OrbitalMechanics/Hierachy/CloseApproach/CA_Minimizer.gd"
)
const CA_BracketFinder = preload(
	"res://core/OrbitalMechanics/Hierachy/CloseApproach/CA_BracketFinder.gd"
)
const UniversalKeplerSolver = preload(
	"res://core/OrbitalMechanics/Solver/Kepler/Universal/UniversalKeplerSolver.gd"
)
const CA_Physics = preload(
	"res://core/OrbitalMechanics/Hierachy/CloseApproach/CA_Physics.gd"
)

func test_refines_to_local_minimum() -> void:
	var mu := 1.32712440018e11
	
	var earth := UniversalKeplerSolver.new(mu)
	earth.from_cartesian(Vector2(1.5e8, 0), Vector2(0, 29.78))
	
	var ship := UniversalKeplerSolver.new(mu)
	ship.from_cartesian(Vector2(1.45e8, -1e7), Vector2(5, 32))
	
	# --- STEP 1: find a real bracket ---
	var brackets := CA_BracketFinder.find_rv_zero_crossings(
		ship,
		earth,
		0.0,
		120.0 * 86400.0,
		600.0
	)
	
	assert_gt(brackets.size(), 0, "Expected at least one RV bracket")
	
	# --- STEP 2: form a cluster ---
	var cluster := {
		"brackets": [brackets[0]]
	}
	
	# --- STEP 3: refine ---
	var minima := CA_Minimizer.refine_cluster_minima(
		cluster,
		ship,
		earth
	)
	
	assert_eq(minima.size(), 1)
	
	# --- STEP 4: verify true distance minimum ---
	var t := minima[0]
	var eps := 60.0
	
	var dL := CA_Physics.dist_sq(t - eps, ship, earth)
	var d0 := CA_Physics.dist_sq(t, ship, earth)
	var dR := CA_Physics.dist_sq(t + eps, ship, earth)
	
	assert_true(dL > d0)
	assert_true(dR > d0)
