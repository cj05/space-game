extends AbstractSolver
class_name BaseSolver

var sma
var ecc
var periapsis_angle
var true_anomaly
var orbit_direction


func compute_params() -> void:
	compute_ta()
	
func get_orbit_dir()->float:
	return orbit_direction
	
func get_true_anomaly()->float:
	return true_anomaly

func get_eccentricity()->float:
	return ecc

func sample_point_at(true_anomaly: float) -> Vector2:
	var p = sma * (1.0 - ecc * ecc)
	var r_at_nu = p / (1.0 + ecc * cos(true_anomaly))
	
	var final_angle = periapsis_angle + true_anomaly
	var sampled_pos = Vector2(cos(final_angle), sin(final_angle)) * r_at_nu
	
	return sampled_pos
