# KeplerStumpff.gd
class_name KeplerStumpff

static func C(z: float) -> float:
	if abs(z) < 1e-5:
		return 0.5 - z / 24.0 + z * z / 720.0
	if z > 0.0:
		var s := sqrt(z)
		return (1.0 - cos(s)) / z
	var s := sqrt(-z)
	return (cosh(s) - 1.0) / (-z)

static func S(z: float) -> float:
	if abs(z) < 1e-5:
		return 1.0 / 6.0 - z / 120.0 + z * z / 5040.0
	if z > 0.0:
		var s := sqrt(z)
		return (s - sin(s)) / (s * s * s)
	var s := sqrt(-z)
	return (sinh(s) - s) / (s * s * s)
