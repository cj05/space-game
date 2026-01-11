# test_basic.gd
# Basic sanity test for Solvers

extends GutTest

const VerletSolver = preload(
	"res://core/OrbitalMechanics/Solver/Integrator/Symplectic/Verlet/VerletSolver.gd"
)

func test_circular_orbit() -> void:
	var mu := 1.0

	# Circular orbit: r = 1, v = sqrt(mu / r) = 1
	var r0 := Vector2(1.0, 0.0)
	var v0 := Vector2(0.0, 1.0)

	var solver: VerletSolver = autofree(VerletSolver.new(mu))
	solver.from_cartesian(r0, v0)

	var energy0 := solver.energy()
	var h0 := solver.angular_momentum()

	# Propagate one full period ~ 2π
	var dt := 0.001
	var steps := int(round(TAU / dt))

	for i in range(steps):
		solver.propagate(dt)

	var state := solver.to_cartesian()
	var r: Vector2 = state.r

	# --- Assertions ----------------------------------------------------------

	assert_true(
		abs(r.length() - 1.0) < 1e-3,
		"Radius drift too large: got=%f expected≈1.0" % r.length()
	)

	assert_true(
		abs(solver.energy() - energy0) < 1e-4,
		"Energy not conserved: Δε=%f" % abs(solver.energy() - energy0)
	)

	assert_true(
		abs(solver.angular_momentum() - h0) < 1e-4,
		"Angular momentum not conserved: Δh=%f" % abs(solver.angular_momentum() - h0)
	)
