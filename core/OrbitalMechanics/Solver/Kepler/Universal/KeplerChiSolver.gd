class_name KeplerChiSolver

const DEBUG_NEWTON_FAILURE := true


# --- Statistics ---
var calls := 0
var cache_hits := 0
var cache_misses := 0
var warm_starts := 0
var crude_starts := 0

var newton_iters_total := 0
var newton_iters_max := 0
var newton_iters_hist := {} # iters -> count

# --- Constants ---
const MAX_ITERS := 80
const TOL := 1e-13

# --- Orbit data ---
var mu: float
var alpha: float
var r0: Vector2
var v0: Vector2

# --- Warm / cache state ---
var pchi := 0.0
var last_t := INF

var _cached_t := INF
var _cached_chi := 0.0

# --- Stumpff cache ---
var _last_z := INF
var _last_C := 0.0
var _last_S := 0.0


func reset(r_epoch: Vector2, v_epoch: Vector2, mu_: float, alpha_: float) -> void:
	r0 = r_epoch
	v0 = v_epoch
	mu = mu_
	alpha = alpha_

	pchi = 0.0
	last_t = INF   # 🔴 critical: disable warm start

	_cached_t = INF
	_last_z = INF


func crude_guess(target_t: float) -> float:
	var r0mag := r0.length()
	var sqrt_mu := sqrt(mu)

	if abs(alpha) < 1e-12:
		return sqrt_mu * target_t / r0mag

	return sqrt_mu * abs(alpha) * target_t


func solve(target_t: float) -> float:
	# --- Invalid / root-body guard ---
	if r0 == Vector2.ZERO:
		# Central body or uninitialized solver
		return 0.0
		
	

	calls += 1

	# --- Exact cache hit ---
	if target_t == _cached_t:
		cache_hits += 1
		return _cached_chi

	cache_misses += 1

	# --- Parabolic guard ---
	if abs(alpha) < 1e-12:
		crude_starts += 1
		var chi_p = crude_guess(target_t)
		pchi = chi_p
		last_t = target_t
		_cached_t = target_t
		_cached_chi = chi_p
		return chi_p

	var r0mag := r0.length()
	var vr0 := r0.dot(v0) / r0mag
	var sqrt_mu := sqrt(mu)

	var chi: float
	if abs(target_t - last_t) <= 5.0:
		chi = pchi
		warm_starts += 1
	else:
		chi = crude_guess(target_t)
		crude_starts += 1

	var iters := 0
	var converged := false
	
	var last_F := 0.0
	var last_dF := 0.0
	var last_delta := 0.0
	var chi_start := chi


	for _i in range(MAX_ITERS):
		iters += 1

		var z := alpha * chi * chi
		var C: float
		var S: float

		if z == _last_z:
			C = _last_C
			S = _last_S
		else:
			C = KeplerStumpff.C(z)
			S = KeplerStumpff.S(z)
			_last_z = z
			_last_C = C
			_last_S = S

		var F := (r0mag * vr0 / sqrt_mu) * chi * chi * C \
			   + (1.0 - alpha * r0mag) * chi * chi * chi * S \
			   + r0mag * chi - sqrt_mu * target_t

		var dF := (r0mag * vr0 / sqrt_mu) * chi * (1.0 - z * S) \
				+ (1.0 - alpha * r0mag) * chi * chi * C \
				+ r0mag
				
		last_F = F
		last_dF = dF
		last_delta = F / dF
		var delta := last_delta


		chi -= delta

		if abs(delta) < TOL:
			converged = true
			break
	
	if iters == MAX_ITERS and DEBUG_NEWTON_FAILURE:

		print("\n[KeplerChiSolver] NEWTON FAILURE")
		print("  regime     :", "elliptic" if alpha > 0.0 else "hyperbolic" if alpha < 0.0 else "parabolic")
		print("  alpha      :", alpha)
		print("  target_t   :", target_t)
		print("  last_t     :", last_t)
		print("  dt         :", target_t - last_t)
		print("  warm_start :", abs(target_t - last_t) <= 5.0)
		print("  chi_start  :", chi_start)
		print("  chi_final  :", chi)
		print("  |delta|    :", abs(last_delta))
		print("  F(chi)     :", last_F)
		print("  F'(chi)    :", last_dF)
		print("  r0         :", r0, " |r0| =", r0mag)
		print("  v0         :", v0, " |v0| =", v0.length())
		print("  vr0        :", vr0)
		print("--------------------------------------------------\n")

	
	newton_iters_total += iters
	newton_iters_max = max(newton_iters_max, iters)
	newton_iters_hist[iters] = newton_iters_hist.get(iters, 0) + 1

	pchi = chi
	last_t = target_t
	_cached_t = target_t
	_cached_chi = chi

	return chi


func cache_report(label := "KeplerChiSolver") -> String:
	if calls == 0:
		return "%s: no calls" % label

	var hit_rate := 100.0 * cache_hits / calls
	var avg_iters := float(newton_iters_total) / calls

	return "%s | calls=%d hits=%d misses=%d hit_rate=%.1f%% warm=%d crude=%d iters(avg=%.2f max=%d)" % [
		label,
		calls,
		cache_hits,
		cache_misses,
		hit_rate,
		warm_starts,
		crude_starts,
		avg_iters,
		newton_iters_max
	]


func cache_stats_reset():
	calls = 0
	cache_hits = 0
	cache_misses = 0
	warm_starts = 0
	crude_starts = 0
	newton_iters_total = 0
	newton_iters_max = 0
	newton_iters_hist.clear()
