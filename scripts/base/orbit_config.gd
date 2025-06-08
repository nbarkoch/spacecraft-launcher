class_name GravityAssist
extends Resource

var planet: Planet
var is_active: bool = false
var spacecraft_ref: Spacecraft = null
var entry_time: float = 0.0
var orbit_duration: float = 2.0  # Fixed duration for now

func _init(p_planet: Planet, spacecraft: Spacecraft):
	planet = p_planet
	is_active = true
	spacecraft_ref = spacecraft
	entry_time = 0.0
	
	# Simple orbit duration based on speed
	if spacecraft and spacecraft.linear_velocity.length() > 0:
		var speed = spacecraft.linear_velocity.length()
		if speed < 100:
			orbit_duration = 4.0  # Slow = longer orbit
		elif speed < 200:
			orbit_duration = 2.0  # Medium speed
		else:
			orbit_duration = 1.0  # Fast = short orbit

func update_curve(delta: float, spacecraft_pos: Vector2) -> Vector2:
	"""Simple gravity with basic orbital help"""
	if not is_active or not planet or not spacecraft_ref:
		return Vector2.ZERO
	
	entry_time += delta
	
	var to_planet = planet.global_position - spacecraft_pos
	var distance = to_planet.length()
	
	if distance < 1.0:
		return Vector2.ZERO
	
	# Basic gravity force (same as before)
	var gravity_strength = planet.gravity_strength * delta * 60.0 / (distance * 0.01)
	var gravity_force = to_planet.normalized() * gravity_strength
	
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
