# scripts/orbit_config.gd (SIMPLIFIED - Real Physics)
class_name GravityAssist
extends Resource

var planet: Planet
var is_active: bool = false

func _init(p_planet: Planet, spacecraft_velocity: Vector2, spacecraft_position: Vector2):
	planet = p_planet
	is_active = true

func update_curve(delta: float, spacecraft_pos: Vector2) -> Vector2:
	"""Apply simple gravitational force toward planet center"""
	if not is_active or not planet:
		return Vector2.ZERO
	
	# Calculate direction to planet center
	var to_planet = planet.global_position - spacecraft_pos
	var distance = to_planet.length()
	
	# Avoid division by zero
	if distance < 1.0:
		return Vector2.ZERO
	
	# Calculate gravitational force (inverse square law, simplified)
	var force_magnitude = planet.gravity_strength * delta * 60.0 / (distance * 0.01)
	
	# Apply force toward planet center
	var force_direction = to_planet.normalized()
	var gravity_force = force_direction * force_magnitude
	
	return gravity_force

func is_curve_complete() -> bool:
	"""Never complete - let the spacecraft exit naturally when it leaves the zone"""
	return false

func get_exit_velocity() -> Vector2:
	"""No special exit velocity - just current velocity"""
	return Vector2.ZERO
