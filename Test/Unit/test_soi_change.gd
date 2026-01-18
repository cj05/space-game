extends GutTest

const CloseApproachUtil = preload(
	"res://core/OrbitalMechanics/Hierachy/CloseApproachUtil.gd"
)

const UniversalKeplerSolver = preload(
	"res://core/OrbitalMechanics/Solver/Kepler/Universal/UniversalKeplerSolver.gd"
)

func test_closest_approach_sun_centric_earth_flyby() -> void:
	# --- REAL DATA ---
	# Sun GM (km^3 / s^2)
	var mu_sun := 1.32712440018e11
	
	# Earth heliocentric state (approx, J2000-like)
	var earth_pos := Vector2(149_597_870.7, 0.0) # 1 AU (km)
	var earth_vel := Vector2(0.0, 29.78)         # km/s
	
	var earth_solver := UniversalKeplerSolver.new(mu_sun)
	earth_solver.from_cartesian(earth_pos, earth_vel)

	# Spacecraft: slightly faster, inner orbit, trailing Earth
	var ship_pos := Vector2(149_000_000.0, -5_000_000.0)
	var ship_vel := Vector2(5.0, 32.0)
	
	var ship_solver := UniversalKeplerSolver.new(mu_sun)
	ship_solver.from_cartesian(ship_pos, ship_vel)

	var util := CloseApproachUtil.new()

	# Search window: 60 days
	var t_start := 0.0
	var t_end := 60.0 * 86400.0

	var t_ca := util.solve_time_of_closest_approach(
		ship_solver,
		earth_solver,
		t_start,
		t_end
	)

	# --- BASIC SANITY ---
	assert_true(t_ca > 0.0, "Closest approach should occur in the future")

	# --- LOCAL MINIMUM TEST ---
	var dt := 60.0 # 1 minute
	
	var d_before := ship_solver.to_cartesian(t_ca - dt).r.distance_to(
		earth_solver.to_cartesian(t_ca - dt).r
	)
	
	var d_at := ship_solver.to_cartesian(t_ca).r.distance_to(
		earth_solver.to_cartesian(t_ca).r
	)
	
	var d_after := ship_solver.to_cartesian(t_ca + dt).r.distance_to(
		earth_solver.to_cartesian(t_ca + dt).r
	)

	assert_true(
		d_at < d_before,
		"Distance before closest approach should be larger"
	)
	
	assert_true(
		d_at < d_after,
		"Distance after closest approach should be larger"
	)

func test_closest_approach_prograde_catchup() -> void:
	var mu_sun := 1.32712440018e11

	var earth_pos := Vector2(149_597_870.7, 0.0)
	var earth_vel := Vector2(0.0, 29.78)

	var earth := UniversalKeplerSolver.new(mu_sun)
	earth.from_cartesian(earth_pos, earth_vel)

	var ship := UniversalKeplerSolver.new(mu_sun)
	ship.from_cartesian(
		Vector2(149_000_000.0, -5_000_000.0),
		Vector2(5.0, 32.0)
	)

	var util := CloseApproachUtil.new()
	var t_ca := util.solve_time_of_closest_approach(
		ship, earth, 0.0, 60.0 * 86400.0
	)

	assert_true(t_ca > 0.0)

	_assert_local_minimum(ship, earth, t_ca)

func test_closest_approach_retrograde() -> void:
	var mu_sun := 1.32712440018e11

	var earth := UniversalKeplerSolver.new(mu_sun)
	earth.from_cartesian(
		Vector2(149_597_870.7, 0.0),
		Vector2(0.0, 29.78)
	)

	var ship := UniversalKeplerSolver.new(mu_sun)
	ship.from_cartesian(
		Vector2(150_000_000.0, -10_000_000.0),
		Vector2(0.0, -35.0) # retrograde
	)

	var util := CloseApproachUtil.new()
	var t_ca := util.solve_time_of_closest_approach(
		ship, earth, 0.0, 90.0 * 86400.0
	)

	assert_true(t_ca > 0.0)

	_assert_local_minimum(ship, earth, t_ca)

func test_closest_approach_near_coorbital() -> void:
	var mu_sun := 1.32712440018e11

	var earth := UniversalKeplerSolver.new(mu_sun)
	earth.from_cartesian(
		Vector2(149_597_870.7, 0.0),
		Vector2(0.0, 29.78)
	)

	var ship := UniversalKeplerSolver.new(mu_sun)
	ship.from_cartesian(
		Vector2(149_597_870.7, -20_000.0),
		Vector2(0.1, 29.75) # almost same orbit
	)

	var util := CloseApproachUtil.new()
	var t_ca := util.solve_time_of_closest_approach(
		ship, earth, 0.0, 120.0 * 86400.0
	)

	assert_true(t_ca > 0.0)

	_assert_local_minimum(ship, earth, t_ca, 300.0)

func test_closest_approach_hyperbolic_ship() -> void:
	var mu_sun := 1.32712440018e11

	var earth := UniversalKeplerSolver.new(mu_sun)
	earth.from_cartesian(
		Vector2(149_597_870.7, 0.0),
		Vector2(0.0, 29.78)
	)

	var ship := UniversalKeplerSolver.new(mu_sun)
	ship.from_cartesian(
		Vector2(100_000_000.0, -50_000_000.0),
		Vector2(20.0, 40.0) # hyperbolic excess
	)

	var util := CloseApproachUtil.new()
	var t_ca := util.solve_time_of_closest_approach(
		ship, earth, 0.0, 180.0 * 86400.0
	)

	assert_true(t_ca > 0.0)

	_assert_local_minimum(ship, earth, t_ca)

func test_closest_approach_monotonic_separation() -> void:
	var mu_sun := 1.32712440018e11

	var earth := UniversalKeplerSolver.new(mu_sun)
	earth.from_cartesian(
		Vector2(149_597_870.7, 0.0),
		Vector2(0.0, 29.78)
	)

	var ship := UniversalKeplerSolver.new(mu_sun)
	ship.from_cartesian(
		Vector2(300_000_000.0, 0.0),
		Vector2(0.0, 10.0) # moving away
	)

	var util := CloseApproachUtil.new()
	var t_ca := util.solve_time_of_closest_approach(
		ship, earth, 0.0, 60.0 * 86400.0
	)

	assert_true(t_ca >= 0.0)

	# Still must be a local min inside the bracket
	_assert_local_minimum(ship, earth, t_ca)

func _assert_local_minimum(
	ship: UniversalKeplerSolver,
	target: UniversalKeplerSolver,
	t_ca: float,
	dt: float = 60.0
) -> void:
	var d_before := ship.to_cartesian(t_ca - dt).r.distance_to(
		target.to_cartesian(t_ca - dt).r
	)
	var d_at := ship.to_cartesian(t_ca).r.distance_to(
		target.to_cartesian(t_ca).r
	)
	var d_after := ship.to_cartesian(t_ca + dt).r.distance_to(
		target.to_cartesian(t_ca + dt).r
	)

	assert_true(d_at <= d_before + 10, "Not a minimum (before) %f <= %f" % [d_at,d_before])
	assert_true(d_at <= d_after + 10, "Not a minimum (after) %f <= %f" % [d_at,d_after])
