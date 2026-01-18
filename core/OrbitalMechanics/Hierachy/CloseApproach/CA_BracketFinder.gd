class_name CA_BracketFinder

class Bracket:
	var a: float
	var b: float
	func _init(_a: float, _b: float):
		a = _a
		b = _b
	func mid() -> float:
		return 0.5 * (a + b)

# ------------------------------------------------------------------

const RV_EPS := 1e-6
const FLAT_COUNT_LIMIT := 50        # ~50 * dt of flatness
const MAX_STEPS := 10_000
const MAX_BRACKETS := 1_000

const DEBUG := true   # <<< turn off when stable

static func _dbg(msg: String) -> void:
	if DEBUG:
		print("[CA_BracketFinder] ", msg)

# ------------------------------------------------------------------

static func find_rv_zero_crossings(
	ship,
	target,
	t_start: float,
	t_end: float,
	dt: float
) -> Array[Bracket]:

	var out: Array[Bracket] = []

	# --- sanity checks ---
	if dt <= 0.0 or not is_finite(dt):
		push_error("CA_BracketFinder: invalid dt = %f" % dt)
		return out

	if t_end <= t_start:
		_dbg("empty interval")
		return out

	var t0 := t_start
	var rv0 := CA_Physics.radial_rate(t0, ship, target)

	if not is_finite(rv0):
		push_error("CA_BracketFinder: initial radial_rate NaN")
		return out

	var t1 := t0 + dt
	var flat_count := 0
	var steps := 0

	_dbg("scan start t=[%f, %f], dt=%f" % [t_start, t_end, dt])

	while t1 <= t_end:
		steps += 1
		if steps > MAX_STEPS:
			push_error("CA_BracketFinder: scan runaway (steps)")
			break

		var rv1 := CA_Physics.radial_rate(t1, ship, target)
		if not is_finite(rv1):
			push_error("CA_BracketFinder: radial_rate NaN at t=%f" % t1)
			break

		# --- flat / degenerate detection ---
		var flat:float = abs(rv0) < RV_EPS and abs(rv1) < RV_EPS
		var tiny_change:float = abs(rv1 - rv0) < RV_EPS

		if flat or tiny_change:
			flat_count += 1
			if flat_count == 1:
				_dbg("flat RV detected at t=%f" % t1)

			if flat_count >= FLAT_COUNT_LIMIT:
				_dbg("flat RV sustained (%d steps), stopping scan" % flat_count)
				break
		else:
			flat_count = 0

		# --- real minimum ---
		if rv0 < -RV_EPS and rv1 > RV_EPS:
			out.append(Bracket.new(t0, t1))
			_dbg("minimum bracket [%f, %f]" % [t0, t1])

			if out.size() >= MAX_BRACKETS:
				push_error("CA_BracketFinder: bracket cap reached")
				break

		t0 = t1
		rv0 = rv1
		t1 += dt

	_dbg("scan end: steps=%d, brackets=%d" % [steps, out.size()])
	return out
