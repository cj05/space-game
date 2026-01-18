extends GutTest

const CA_Physics = preload(
	"res://core/OrbitalMechanics/Hierachy/CloseApproach/CA_Physics.gd"
)
const UniversalKeplerSolver = preload(
	"res://core/OrbitalMechanics/Solver/Kepler/Universal/UniversalKeplerSolver.gd"
)

func test_distance_squared_monotonic_increasing() -> void:
	var mu := 1.0

	var a := UniversalKeplerSolver.new(mu)
	var b := UniversalKeplerSolver.new(mu)

	a.from_cartesian(Vector2(1, 0), Vector2(0, 0))
	b.from_cartesian(Vector2(1, 0), Vector2(0, 1))

	var util := CA_Physics.new()

	var d0 :float = util.dist_sq(0.0, a, b)
	var d1 :float = util.dist_sq(10.0, a, b)
	#print(d0,d1)

	assert_true(d1 > d0, "Distance should increase monotonically")
