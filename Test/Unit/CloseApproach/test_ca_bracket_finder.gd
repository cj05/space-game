extends GutTest

const CA_BracketFinder = preload(
	"res://core/OrbitalMechanics/Hierachy/CloseApproach/CA_BracketFinder.gd"
)
const UniversalKeplerSolver = preload(
	"res://core/OrbitalMechanics/Solver/Kepler/Universal/UniversalKeplerSolver.gd"
)

const CA_Physics = preload(
	"res://core/OrbitalMechanics/Hierachy/CloseApproach/CA_Physics.gd"
)

func test_detects_single_physical_extremum() -> void:
	var mu := 1.32712440018e11
	
	var earth := UniversalKeplerSolver.new(mu)
	earth.from_cartesian(Vector2(1.5e8, 0), Vector2(0, 29.78))
	
	var ship := UniversalKeplerSolver.new(mu)
	ship.from_cartesian(Vector2(1.45e8, -1e7), Vector2(5, 32))
	
	var brackets := CA_BracketFinder.find_rv_zero_crossings(
		ship, earth, 0.0, 60.0 * 86400.0, 600.0
	)
	
	assert_gt(brackets.size(), 0)
	
	for br in brackets:
		var rv_a := CA_Physics.radial_rate(br.a, ship, earth)
		var rv_b := CA_Physics.radial_rate(br.b, ship, earth)
		
		assert_true(
			rv_a <= 0.0 and rv_b >= 0.0
			or
			rv_a >= 0.0 and rv_b <= 0.0,
			"Bracket does not straddle RV=0"
		)
