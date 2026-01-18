extends GutTest

const CloseApproachUtil = preload(
	"res://core/OrbitalMechanics/Hierachy/CloseApproach/CloseApproachUtil.gd"
)

const UniversalKeplerSolver = preload(
	"res://core/OrbitalMechanics/Solver/Kepler/Universal/UniversalKeplerSolver.gd"
)

# Helper: simple circular orbit
func make_circular(
	mu: float,
	radius: float,
	phase := 0.0
) -> UniversalKeplerSolver:
	
	var pos := Vector2(
		radius * cos(phase),
		radius * sin(phase)
	)
	
	var v := sqrt(mu / radius)
	var vel := Vector2(
		-v * sin(phase),
		 v * cos(phase)
	)
	
	var s := UniversalKeplerSolver.new(mu)
	s.from_cartesian(pos, vel)
	return s


func test_detects_single_minimum_simple_circular():
	var util := CloseApproachUtil.new()

	var mu := 3.986e14

	var ship := make_circular(mu, 7000e3, 0.0)
	var target := make_circular(mu, 8000e3, PI * 0.5)
	target.compute_params()
	print("[generate] %f %f" % [target.ecc, target.period()])
	var minima := util.find_closest_approaches(
		ship,
		target,
		0.0,
		2.0 * ship.period()
	)

	assert_gt(minima.size(), 0)
	_assert_sorted(minima)


func test_no_minimum_when_same_orbit_and_phase():
	var util := CloseApproachUtil.new()

	var mu := 3.986e14

	var ship := make_circular(mu, 7000e3, 0.0)
	var target := make_circular(mu, 7000e3, 0.0)

	var minima := util.find_closest_approaches(
		ship,
		target,
		0.0,
		ship.period()
	)

	assert_eq(minima.size(), 0)


func test_multiple_minima_near_coorbital():
	var util := CloseApproachUtil.new()

	var mu := 3.986e14

	var ship := make_circular(mu, 7000e3, 0.0)
	var target := make_circular(mu, 7000e3, 0.01)

	var minima := util.find_closest_approaches(
		ship,
		target,
		0.0,
		5.0 * ship.period()
	)

	assert_gt(minima.size(), 1)
	_assert_sorted(minima)
	print(minima)


func _assert_sorted(arr: Array) -> void:
	for i in range(arr.size() - 1):
		assert_true(
			arr[i] <= arr[i + 1],
			"Array not sorted at %d: %f > %f" % [i, arr[i], arr[i + 1]]
		)
