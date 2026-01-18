extends GutTest

const CloseApproachUtil = preload(
	"res://core/OrbitalMechanics/Hierachy/CloseApproach/CloseApproachUtil.gd"
)

const UniversalKeplerSolver = preload(
	"res://core/OrbitalMechanics/Solver/Kepler/Universal/UniversalKeplerSolver.gd"
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func make_circular(mu: float, radius: float, phase := 0.0) -> UniversalKeplerSolver:
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


func separation_at_t(
	t: float,
	ship: UniversalKeplerSolver,
	target: UniversalKeplerSolver
) -> float:
	var s_state = ship.to_cartesian(t)
	var t_state = target.to_cartesian(t)
	return s_state.r.distance_to(t_state.r)


func is_local_minimum(
	t: float,
	ship: UniversalKeplerSolver,
	target: UniversalKeplerSolver,
	eps := 1.0
) -> bool:
	var d0 = separation_at_t(t, ship, target)
	return (
		separation_at_t(t - eps, ship, target) > d0 and
		separation_at_t(t + eps, ship, target) > d0
	)

# ---------------------------------------------------------------------------
# ACTUAL TESTS
# ---------------------------------------------------------------------------

func test_reported_minima_are_true_distance_minima():
	var util := CloseApproachUtil.new()
	var mu := 3.986e14

	var ship := make_circular(mu, 7000e3, 0.0)
	var target := make_circular(mu, 8000e3, PI * 0.4)

	var minima := util.find_closest_approaches(
		ship,
		target,
		0.0,
		2.0 * ship.period()
	)

	assert_gt(minima.size(), 0)

	for t_min in minima:
		assert_local_minimum_verbose(
			t_min,
			ship,
			target,
			1.0
		)

		
func assert_local_minimum_verbose(
	t: float,
	ship: UniversalKeplerSolver,
	target: UniversalKeplerSolver,
	eps := 1.0
) -> void:
	var d_prev = separation_at_t(t - eps, ship, target)
	var d_curr = separation_at_t(t, ship, target)
	var d_next = separation_at_t(t + eps, ship, target)

	var ok = d_prev > d_curr and d_next > d_curr

	if not ok:
		var slope_left = d_curr - d_prev
		var slope_right = d_next - d_curr

		push_error(
			"[INVALID MINIMUM]\n" +
			"  t        = " + str(t) + "\n" +
			"  d(t-eps) = " + str(d_prev) + "\n" +
			"  d(t)     = " + str(d_curr) + "\n" +
			"  d(t+eps) = " + str(d_next) + "\n"
		)




	assert_true(ok)
