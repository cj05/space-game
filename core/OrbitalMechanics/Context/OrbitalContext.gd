class_name OrbitalContext
extends RefCounted

# --- identity --------------------------------------------------------------

var subject: AbstractBinding        # The body being solved

# --- dominant bodies -------------------------------------------------------

var primary: AbstractBinding = null        # Main gravity reference
var secondary: AbstractBinding = null  # Optional (Lagrange / transitions)

# --- strength metrics ------------------------------------------------------

var primary_accel: float = 0.0
var secondary_accel: float = 0.0

# --- relative state (cached) ----------------------------------------------

var r_primary: Vector2              # subject -> primary
var v_primary: Vector2              # relative velocity

var mu: float = 0.0

var escape_radius: float = 0.0

# --- orbit insertion query

var capture_candidates: Array[AbstractBinding] = []

# --- validity --------------------------------------------------------------

var is_valid: bool = true
