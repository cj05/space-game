class_name CloseApproachUtil

func find_closest_approaches(
	ship: UniversalKeplerSolver,
	target: UniversalKeplerSolver,
	t_start: float,
	t_end: float,
	dt_scan := 600.0
) -> Array[float]:
	
	var brackets = CA_BracketFinder.find_rv_zero_crossings(
		ship, target, t_start, t_end, dt_scan
	)
	
	if brackets.is_empty():
		return []
	
	var cluster_dt = CA_Clustering.estimate_cluster_dt(ship, target)
	var clusters = CA_Clustering.cluster_brackets(brackets, cluster_dt)
	
	var minima :Array[float]= []
	for c in clusters:
		minima.append_array(
			CA_Minimizer.refine_cluster_minima(c, ship, target)
		)
	
	minima.sort()
	return minima
