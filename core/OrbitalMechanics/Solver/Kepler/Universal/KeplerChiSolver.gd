# KeplerChiSolver.gd
class_name KeplerChiSolver

const MAX_ITERS := 80
const TOL := 1e-13

var mu: float
var alpha: float
var r0: Vector2
var v0: Vector2

var pchi := 0.0
var last_t := 0.0

func reset(r_epoch: Vector2, v_epoch: Vector2, mu_: float, alpha_: float) -> void:
	r0 = r_epoch
	v0 = v_epoch
	mu = mu_
	alpha = alpha_
	pchi = 0.0
	last_t = 0.0

func crude_guess(target_t: float) -> float:
	var r0mag := r0.length()
	var sqrt_mu := sqrt(mu)
	if alpha == 0.0:
		return sqrt_mu * target_t / r0mag
	return sqrt_mu * abs(alpha) * target_t

func solve(target_t: float) -> float:
	var r0mag := r0.length()
	var vr0 := r0.dot(v0) / r0mag
	var sqrt_mu := sqrt(mu)

	var chi := pchi if abs(target_t - last_t) < 1.0 else crude_guess(target_t)

	for _i in range(MAX_ITERS):
		var z := alpha * chi * chi
		var C := KeplerStumpff.C(z)
		var S := KeplerStumpff.S(z)

		var F := (r0mag * vr0 / sqrt_mu) * chi * chi * C \
			   + (1.0 - alpha * r0mag) * chi * chi * chi * S \
			   + r0mag * chi - sqrt_mu * target_t

		var dF := (r0mag * vr0 / sqrt_mu) * chi * (1.0 - z * S) \
				+ (1.0 - alpha * r0mag) * chi * chi * C \
				+ r0mag

		var delta := F / dF
		chi -= delta
		if abs(delta) < TOL:
			break

	pchi = chi
	last_t = target_t
	return chi
