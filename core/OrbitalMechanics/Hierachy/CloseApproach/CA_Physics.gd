class_name CA_Physics

static func dist_sq(
	t: float,
	s1: UniversalKeplerSolver,
	s2: UniversalKeplerSolver
) -> float:
	var p1 = s1.to_cartesian(t)
	var p2 = s2.to_cartesian(t)
	return p1.r.distance_squared_to(p2.r)

static func radial_rate(
	t: float,
	s1: UniversalKeplerSolver,
	s2: UniversalKeplerSolver
) -> float:
	var a = s1.to_cartesian(t)
	var b = s2.to_cartesian(t)
	return (a.r - b.r).dot(a.v - b.v)
