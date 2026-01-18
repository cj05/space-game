class_name CA_Clustering

static func estimate_cluster_dt(
	ship,
	target
) -> float:
	
	var Ts = ship.period()
	var Tt = target.period()
	
	if Ts <= 0.0 and Tt <= 0.0:
		return 600.0
	
	var T = min(Ts if Ts > 0 else INF, Tt if Tt > 0 else INF)
	return max(600.0, 0.05 * T)


static func cluster_brackets(
	brackets: Array,
	cluster_dt: float
) -> Array:
	
	var clusters := []
	
	for br in brackets:
		# --- FIX: explicit midpoint ---
		var t: float = 0.5 * (br.a + br.b)
		
		if clusters.is_empty() or abs(t - clusters[-1].t) > cluster_dt:
			clusters.append({
				"t": t,
				"brackets": [br]
			})
		else:
			clusters[-1].brackets.append(br)
	
	return clusters
