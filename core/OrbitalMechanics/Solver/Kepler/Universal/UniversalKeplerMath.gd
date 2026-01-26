# UniversalKeplerMath.gd
# Stateless helper functions for universal-variable Kepler propagation

extends RefCounted
class_name UniversalKeplerMath


# ------------------------------------------------------------
# Cartesian state from universal anomaly
# ------------------------------------------------------------
static func state_from_chi(
	r0: Vector2,
	v0: Vector2,
	mu: float,
	alpha: float,
	chi: float,
	target_t: float
) -> State2D:
	var r0mag := r0.length()
	var sqrt_mu := sqrt(mu)

	var z := alpha * chi * chi
	var C := KeplerStumpff.C(z)
	var S := KeplerStumpff.S(z)

	var f := 1.0 - (chi * chi / r0mag) * C
	var g := target_t - (chi * chi * chi / sqrt_mu) * S

	var r := f * r0 + g * v0
	var rmag := r.length()

	var fdot := (sqrt_mu / (rmag * r0mag)) * (z * S - 1.0) * chi
	var gdot := 1.0 - (chi * chi / rmag) * C

	var v := fdot * r0 + gdot * v0
	return State2D.new(r, v)


# ------------------------------------------------------------
# Orbital parameter computation
# ------------------------------------------------------------
class OrbitParams:
	var sma: float
	var ecc: float
	var periapsis_angle: float
	var orbit_direction: float


static func compute_orbit_params(
	r: Vector2,
	v: Vector2,
	mu: float,
	out: OrbitParams
) -> void:
	var r_mag := r.length()
	var v_mag_sq := v.length_squared()
	var r_dot_v := r.dot(v)

	var inv_a := (2.0 / r_mag) - (v_mag_sq / mu)
	out.sma = 1.0 / inv_a

	var inv_mu := 1.0 / mu
	var e_x := ((v_mag_sq - mu / r_mag) * r.x - r_dot_v * v.x) * inv_mu
	var e_y := ((v_mag_sq - mu / r_mag) * r.y - r_dot_v * v.y) * inv_mu

	out.ecc = sqrt(e_x * e_x + e_y * e_y)
	out.periapsis_angle = atan2(e_y, e_x)

	var h := r.x * v.y - r.y * v.x
	out.orbit_direction = sign(h)


# ------------------------------------------------------------
# True anomaly computation
# ------------------------------------------------------------
static func compute_true_anomaly(
	r: Vector2,
	periapsis_angle: float
) -> float:
	var ta := r.angle() - periapsis_angle
	if ta < 0.0:
		ta += TAU
	return ta


# ------------------------------------------------------------
# Period (elliptic only)
# ------------------------------------------------------------
static func period(mu: float, alpha: float) -> float:
	if alpha <= 0.0:
		return INF
	return TAU / (sqrt(mu) * pow(alpha, 1.5))


## Closest approach radius (always defined)
static func periapsis_radius(h:float,ecc:float,mu:float) -> float:
	return (h * h) / ((1.0 + ecc) * mu)


## Furthest distance (elliptic only)
static func apoapsis_radius(alpha:float,sma:float,ecc:float) -> float:
	if alpha <= 0.0:
		return INF
	return sma * (1.0 + ecc)
