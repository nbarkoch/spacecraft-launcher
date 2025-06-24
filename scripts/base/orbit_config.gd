class_name GravityAssist
extends Resource

var planet: Planet
var is_active: bool = false
var spacecraft_ref: Spacecraft = null
var entry_time: float = 0.0
var orbit_duration: float = 2.0  # Fixed duration for now
var ideal_orbit_radius: float = 0.0
var predicted_orbit_duration: float = 0.0
var should_exit: bool = false

func _init(p_planet: Planet, spacecraft: Spacecraft):
	planet = p_planet
	is_active = true
	spacecraft_ref = spacecraft
	entry_time = 0.0
	
	# Calculate ideal orbit radius
	if planet:
		ideal_orbit_radius = planet.planet_radius + 30.0
	
	# Simple orbit duration based on speed
	if spacecraft and spacecraft.linear_velocity.length() > 0:
		var speed = spacecraft.linear_velocity.length()
		if speed < 100:
			orbit_duration = 4.0  # Slow = longer orbit
			predicted_orbit_duration = 4.0
		elif speed < 200:
			orbit_duration = 2.0  # Medium speed
			predicted_orbit_duration = 2.0
		else:
			orbit_duration = 1.0  # Fast = short orbit
			predicted_orbit_duration = 1.0

func update_curve(delta: float, spacecraft_pos: Vector2) -> Vector2:
	"""אל תשנה כלום! הפיזיקה החדשה מנהלת הכל"""
	# אם החללית משתמשת בפיזיקה החדשה, אל תתערב!
	if spacecraft_ref and spacecraft_ref.use_advanced_physics:
		entry_time += delta
		return Vector2.ZERO  # אל תפעיל שום כוח נוסף!
	
	# הפיזיקה הישנה - רק אם לא משתמשים בפיזיקה החדשה
	if not is_active or not planet or not spacecraft_ref:
		return Vector2.ZERO
	
	entry_time += delta
	
	var to_planet = planet.global_position - spacecraft_pos
	var distance = to_planet.length()
	
	if distance < 1.0:
		return Vector2.ZERO
	
	# Use the original gravity calculation (same as AccuratePhysics)
	var force_magnitude = planet.gravity_strength * delta * 60.0 / (distance * 0.01)
	var force_direction = to_planet.normalized()
	var gravity_force = force_direction * force_magnitude
	
	# Simple collision prevention - only if very close
	var collision_prevention = Vector2.ZERO
	if distance < planet.planet_radius + 25.0:
		var push_direction = (spacecraft_pos - planet.global_position).normalized()
		var danger = 1.0 - ((distance - planet.planet_radius) / 25.0)
		collision_prevention = push_direction * danger * 100.0 * delta
	
	return gravity_force + collision_prevention

func is_curve_complete() -> bool:
	"""Exit after simple time duration"""
	return entry_time >= orbit_duration

func get_current_predicted_duration() -> float:
	"""Get current predicted duration"""
	return predicted_orbit_duration
