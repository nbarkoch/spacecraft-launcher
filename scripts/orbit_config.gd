# scripts/orbit_config.gd (Updated)
class_name GravityAssist
extends Resource

var planet: Planet
var entry_velocity: Vector2
var current_velocity: Vector2
var curve_strength: float
var curve_duration: float
var curve_timer: float = 0.0
var speed_boost: float
var rotation_factor: float

func _init(p_planet: Planet, spacecraft_velocity: Vector2):
	planet = p_planet
	entry_velocity = spacecraft_velocity
	current_velocity = spacecraft_velocity
	
	var speed = spacecraft_velocity.length()
	
	# Base curve characteristics based on speed
	var base_curve_strength: float
	var base_curve_duration: float
	
	if speed > 600:
		# Fast = wide gentle curve
		base_curve_strength = 1.0
		base_curve_duration = 0.5
	elif speed > 500:
		# Medium = moderate curve  
		base_curve_strength = 2.0
		base_curve_duration = 1.0
	else:
		# Slow = tight curve
		base_curve_strength = 4.0
		base_curve_duration = 2.0
	
	# Apply planet-specific multipliers
	curve_strength = base_curve_strength * planet.curve_strength_multiplier
	curve_duration = base_curve_duration * planet.curve_duration_multiplier
	speed_boost = planet.speed_boost_multiplier
	rotation_factor = planet.rotation_intensity

func update_curve(delta: float, spacecraft_pos: Vector2) -> Vector2:
	"""Update the curved motion, returns new velocity"""
	curve_timer += delta
	
	# Calculate direction toward planet center
	var to_planet = (planet.global_position - spacecraft_pos).normalized()
	
	# Calculate curve force (gets weaker over time)
	var curve_progress = curve_timer / curve_duration
	var remaining_strength = 1.0 - curve_progress
	
	# Apply curve force to current velocity with rotation intensity
	var curve_force = to_planet * curve_strength * remaining_strength * rotation_factor * delta * 60.0
	current_velocity += curve_force
	
	return current_velocity

func is_curve_complete() -> bool:
	"""Check if the gravity assist curve is finished"""
	return curve_timer >= curve_duration

func get_exit_velocity() -> Vector2:
	"""Get final velocity when leaving gravity assist"""
	# Apply planet-specific speed boost
	return current_velocity * speed_boost
