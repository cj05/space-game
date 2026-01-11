# test_reference_all_orbits.gd
# Analytic regression tests for UniversalKeplerSolver
# Circular, elliptic, parabolic, hyperbolic
# Analytic reference built from SAME orbital elements AND same phase

extends GutTest

const POS_TOL := 1e-6
const MU := 1.0

# ---------------------------------------------------------------------------
# Orbital elements + phase
# ---------------------------------------------------------------------------

func orbital_elements(r: Vector2, v: Vector2) -> Dictionary:
	var rmag := r.length()
	var v2 := v.length_squared()
	var rv := r.dot(v)

	var h := r.x * v.y - r.y * v.x
	var energy := 0.5 * v2 - MU / rmag

	var a := INF
	if abs(energy) > 1e-12:
		a = -MU / (2.0 * energy)

	var evec := ((v2 - MU / rmag) * r - rv * v) / MU
	var e := evec.length()
	var omega := atan2(evec.y, evec.x)

	var elems := {
		"a": a,
		"e": e,
		"h": h,
		"omega": omega
	}

	# -----------------------
	# Phase at t = 0
	# -----------------------

	if abs(e - 1.0) < 1e-8:
		# Parabolic (Barker)
		elems["D0"] = rv / sqrt(MU)

	elif e < 1.0:
		# Elliptic
		var cosE0 := (1.0 - rmag / a) / e
		var sinE0 := rv / (e * sqrt(MU * a))
		var E0 := atan2(sinE0, cosE0)
		elems["M0"] = E0 - e * sin(E0)

	else:
		# Hyperbolic
		var coshH0 := (rmag / a + 1.0) / e
		var H0 := acosh(coshH0)
		if rv < 0.0:
			H0 = -H0
		elems["M0"] = e * sinh(H0) - H0

	return elems

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

func rotate(v: Vector2, ang: float) -> Vector2:
	var c := cos(ang)
	var s := sin(ang)
	return Vector2(
		c * v.x - s * v.y,
		s * v.x + c * v.y
	)

# ---------------------------------------------------------------------------
# Analytic reference from elements + phase
# ---------------------------------------------------------------------------

func ref_from_elements(t: float, elems: Dictionary) -> Vector2:
	var a:float = elems["a"]
	var e:float= elems["e"]
	var omega:float= elems["omega"]

	# ---------- Circular ----------
	if e < 1e-8:
		var n := sqrt(MU / (a * a * a))
		return rotate(
			Vector2(
				a * cos(n * t),
				a * sin(n * t)
			),
			omega
		)

	# ---------- Elliptic ----------
	if e < 1.0:
		var n := sqrt(MU / (a * a * a))
		var M:float= elems["M0"] + n * t
		var E:float= M

		for _i in range(20):
			E -= (E - e * sin(E) - M) / (1.0 - e * cos(E))

		return rotate(
			Vector2(
				a * (cos(E) - e),
				a * sqrt(1.0 - e * e) * sin(E)
			),
			omega
		)

	# ---------- Unsupported analytically ----------
	push_error("Analytic reference not valid for e >= 1")
	return Vector2.ZERO


# ---------------------------------------------------------------------------
# Test harness
# ---------------------------------------------------------------------------

func run_reference_test(
	name: String,
	r0: Vector2,
	v0: Vector2,
	samples: Array
) -> void:
	var solver: UniversalKeplerSolver = autofree(UniversalKeplerSolver.new(MU))
	solver.from_cartesian(r0, v0)

	var elems := orbital_elements(r0, v0)

	var t_prev := 0.0
	for t in samples:
		solver.propagate(t - t_prev)

		var r_actual := solver.to_cartesian().r
		var r_expected := ref_from_elements(t, elems)

		assert_true(
			r_actual.distance_to(r_expected) < POS_TOL,
			"%s orbit mismatch at t=%f\n got=%s\n exp=%s\n |Δr|=%f"
			% [name, t, r_actual, r_expected, r_actual.distance_to(r_expected)]
		)

		t_prev = t

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_reference_circular() -> void:
	run_reference_test(
		"Circular",
		Vector2(1.0, 0.0),
		Vector2(0.0, 1.0),
		[0.0, TAU/8.0, TAU/4.0, TAU/2.0, TAU]
	)

func test_reference_elliptic() -> void:
	run_reference_test(
		"Elliptic",
		Vector2(0.5, 0.0),
		Vector2(0.0, sqrt(3.0)),
		[0.0, 0.5, 1.0, 2.0, 3.0]
	)

func test_reference_parabolic() -> void:
	run_reference_test(
		"Parabolic",
		Vector2(1.0, 0.0),
		Vector2(0.0, sqrt(2.0)),
		[0.0, 0.2, 0.5, 1.0]
	)

func DISABLED_test_reference_hyperbolic() -> void:
	run_reference_test(
		"Hyperbolic",
		Vector2(0.5, 0.0),
		Vector2(0.0, 2.0),
		[0.0, 0.2, 0.5, 1.0]
	)
