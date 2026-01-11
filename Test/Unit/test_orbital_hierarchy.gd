# res://test/unit/test_orbital_hierarchy.gd
extends GutTest

# Change these paths to match your actual file locations
const Hierarchy = preload("res://core/OrbitalMechanics/Hierachy/OrbitalHierachy.gd")
const AbstractBinding = preload("res://core/OrbitalMechanics/Binding/AbstractBinding.gd")
const OrbitalContext = preload("res://core/OrbitalMechanics/Context/OrbitalContext.gd")
const OrbitalModel = preload("res://core/OrbitalMechanics/OrbitalModel.gd")

# --- Helpers ---

func _setup_mock_body(name: String, mass: float, pos: Vector2, gravity: bool = true) -> AbstractBinding:
	var body = AbstractBinding.new()
	body.name = name
	body.mass = mass
	body.sim_position = pos
	body.produces_gravity = gravity
	# Context starts null to simulate a fresh bootstrap
	body.sim_context = null 
	return body

# --- Test Cases ---

## 1. The Root Case (The Sun)
func test_sun_bootstrap_logic() -> void:
	var model = OrbitalModel.new()
	var builder = ContextBuilder.new()
	var sun = _setup_mock_body("Sun", 1e6, Vector2.ZERO)
	model.insert(sun)
	
	builder.build(model)
	
	assert_not_null(sun.sim_context, "Sun should have a context after build")
	assert_null(sun.sim_context.primary, "The Sun (Root) primary must be null to avoid self-orbiting")
	assert_eq(sun.sim_context.escape_radius, INF, "Root bodies should never escape (INF radius)")

## 2. Automatic Deep Nesting (Sun -> Earth -> Moon -> Ship)
func test_deep_automatic_parenting() -> void:
	print("test_deep_automatic_parenting")
	var model = OrbitalModel.new()
	var builder = ContextBuilder.new()
	
	var sun = _setup_mock_body("Sun", 1e6, Vector2.ZERO)
	var earth = _setup_mock_body("Earth", 1000, Vector2(10000, 0))
	var moon = _setup_mock_body("Moon", 10, Vector2(10100, 0))
	var ship = _setup_mock_body("Ship", 0, Vector2(10105, 0), false)
	
	model.insert(sun)
	model.insert(earth)
	model.insert(moon)
	model.insert(ship)
	
	# Pass 1: Sun becomes Root, Earth finds Sun.
	builder.build(model)
	# Pass 2: Moon finds Earth (via Sun dive).
	builder.build(model)
	# Pass 3: Ship finds Moon (via Sun -> Earth dive).
	builder.build(model)
	
	assert_eq(earth.sim_context.primary, sun, "Earth orbits Sun")
	assert_eq(moon.sim_context.primary, earth, "Moon orbits Earth")
	assert_eq(ship.sim_context.primary, moon, "Ship dived all the way to Moon")

## 3. Dynamic Escape (Leaving Moon for Earth)
func test_dynamic_escape_transition() -> void:
	var model = OrbitalModel.new()
	var builder = ContextBuilder.new()
	
	var earth = _setup_mock_body("Earth", 1000, Vector2.ZERO)
	var moon = _setup_mock_body("Moon", 10, Vector2(500, 0))
	var ship = _setup_mock_body("Ship", 0, Vector2(505, 0), false)
	
	model.insert(earth)
	model.insert(moon)
	model.insert(ship)
	
	# Initial Setup: Ship orbits Moon
	builder.build(model) # Earth root
	builder.build(model) # Moon finds Earth
	builder.build(model) # Ship finds Moon
	assert_eq(ship.sim_context.primary, moon)
	
	# Teleport ship outside Moon's SOI but still near Earth
	# Moon SOI relative to Earth is ~500 * (10/1000)^0.4 ≈ 79
	ship.sim_position = Vector2(700, 0) 
	
	builder.build(model)
	
	assert_eq(ship.sim_context.primary, earth, "Ship should have escaped Moon and been caught by Earth")

## 4. Capture Prevention (Non-Gravity Bodies)
func test_ship_cannot_capture_ship() -> void:
	var model = OrbitalModel.new()
	var builder = ContextBuilder.new()
	
	var sun = _setup_mock_body("Sun", 1e6, Vector2.ZERO)
	var ship_a = _setup_mock_body("ShipA", 100, Vector2(1000, 0), false) # No gravity
	var ship_b = _setup_mock_body("ShipB", 0, Vector2(1001, 0), false)
	
	model.insert(sun)
	model.insert(ship_a)
	model.insert(ship_b)
	
	builder.build(model)
	builder.build(model)
	
	assert_eq(ship_b.sim_context.primary, sun, "ShipB should ignore ShipA even if closer, because A doesn't produce gravity")

## 5. Cycle Protection (The "A orbits B orbits A" crash)
func test_cycle_crash_prevention() -> void:
	var model = OrbitalModel.new()
	var builder = ContextBuilder.new()
	
	var body_a = _setup_mock_body("BodyA", 1000, Vector2.ZERO)
	var body_b = _setup_mock_body("BodyB", 1000, Vector2(100, 0))
	
	model.insert(body_a)
	model.insert(body_b)
	
	# Force a bad state manually
	builder.build(model)
	body_a.sim_context.primary = body_b
	body_b.sim_context.primary = body_a
	
	# This call triggers _is_descendant_of
	var caught_cycle = builder.update_context(body_a, model, body_a.sim_context)
	
	assert_null(caught_cycle.primary, "Cycle protection should have stripped the primary to break the loop")
