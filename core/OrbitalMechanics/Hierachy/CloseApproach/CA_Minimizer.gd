class_name CA_Minimizer

const MAX_ITERS := 50
const EPS := 1e-6
const GOLD := 0.3819660112501051

static func brent_minimize(
	ship,
	target,
	a: float,
	b: float
) -> float:
	
	var x := a + GOLD * (b - a)
	var w := x
	var v := x
	
	var fx := CA_Physics.dist_sq(x, ship, target)
	var fw := fx
	var fv := fx
	
	var d := 0.0
	var e := 0.0
	
	for _i in range(MAX_ITERS):
		var m := 0.5 * (a + b)
		var tol :float = EPS * abs(x) + 1e-9
		
		# Convergence
		if abs(x - m) <= 2.0 * tol - 0.5 * (b - a):
			break
		
		var p := 0.0
		var q := 0.0
		var r := 0.0
		
		if abs(e) > tol:
			r = (x - w) * (fx - fv)
			q = (x - v) * (fx - fw)
			p = (x - v) * q - (x - w) * r
			q = 2.0 * (q - r)
			
			if q > 0.0:
				p = -p
			q = abs(q)
			
			var accept_parabolic :bool =\
				abs(p) < abs(0.5 * q * e) \
				and p > q * (a - x) \
				and p < q * (b - x)
			
			if accept_parabolic:
				d = p / q
				e = d
			else:
				e = (b - x) if x < m else (a - x)
				d = GOLD * e
		else:
			e = (b - x) if x < m else (a - x)
			d = GOLD * e
		
		var u :float = x + (d if abs(d) > tol else sign(d) * tol)
		var fu := CA_Physics.dist_sq(u, ship, target)
		
		if fu <= fx:
			if u < x:
				b = x
			else:
				a = x
			
			v = w
			fv = fw
			w = x
			fw = fx
			x = u
			fx = fu
		else:
			if u < x:
				a = u
			else:
				b = u
			
			if fu <= fw or w == x:
				v = w
				fv = fw
				w = u
				fw = fu
			elif fu <= fv or v == x or v == w:
				v = u
				fv = fu
	
	return x
static func refine_cluster_minima(
	cluster,
	ship,
	target
) -> Array[float]:
	
	var times: Array[float] = []
	var depths: Array[float] = []
	
	for br in cluster.brackets:
		var t := brent_minimize(ship, target, br.a, br.b)
		
		# --- TRUE minimum check ---
		var eps := 1.0
		var d0 := CA_Physics.dist_sq(t, ship, target)
		var dL := CA_Physics.dist_sq(t - eps, ship, target)
		var dR := CA_Physics.dist_sq(t + eps, ship, target)
		
		if not (dL > d0 and dR > d0):
			continue  # reject inflection
		
		times.append(t)
		depths.append(d0)
	
	if times.is_empty():
		return []
	
	var dmin: float = depths.min()
	var out: Array[float] = []
	
	for i in range(times.size()):
		if depths[i] <= dmin + 1e8:
			out.append(times[i])
	
	return out
