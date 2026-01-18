class_name CA_Minimizer

static func brent_minimize(
	ship,
	target,
	a: float,
	b: float
) -> float:
	
	const EPS := 1e-6
	const GOLD := 0.3819660112501051
	
	var x := a + GOLD * (b - a)
	var w := x
	var v := x
	
	var fx := CA_Physics.dist_sq(x, ship, target)
	var fw := fx
	var fv := fx
	
	var d := 0.0
	var e := 0.0
	
	for _i in range(50):
		# Brent logic…
		pass
	
	return x



static func refine_cluster_minima(
	cluster,
	ship,
	target
) -> Array[float]:
	
	var times:Array[float]= []
	var depths:Array[float]= []
	
	for br in cluster.brackets:
		var t = brent_minimize(ship, target, br.a, br.b)
		times.append(t)
		depths.append(CA_Physics.dist_sq(t, ship, target))
	
	var dmin :float = depths.min()
	
	var out :Array[float] = []
	for i in range(times.size()):
		if depths[i] <= dmin + 1e8:
			out.append(times[i])
	
	return out
