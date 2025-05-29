class_name GravityAssist
extends Resource

var planet: Planet
var entry_velocity: Vector2
var current_velocity: Vector2
var curve_strength: float  # How much to curve each frame
var curve_duration: float  # How long the curve lasts
var curve_timer: float = 0.0

func _init(p_planet: Planet, spacecraft_velocity: Vector2):
	planet = p_planet
	entry_velocity = spacecraft_velocity
	current_velocity = spacecraft_velocity
	
	var speed = spacecraft_velocity.length()
	
	# Determine curve characteristics based on speed
	if speed > 600:
		# Fast = wide gentle curve
		curve_strength = 1.0
		curve_duration = 2.5
	elif speed > 500:
		# Medium = moderate curve  
		curve_strength = 2.0
		curve_duration = 3.0
	else:
		# Slow = tight curve
		curve_strength = 4.0
		curve_duration = 4.0
	
	#print("Gravity assist - Speed: ", speed, " Curve strength: ", curve_strength, " Duration: ", curve_duration)

func update_curve(delta: float, spacecraft_pos: Vector2) -> Vector2:
	"""Update the curved motion, returns new velocity"""
	curve_timer += delta
	
	# Calculate direction toward planet center
	var to_planet = (planet.global_position - spacecraft_pos).normalized()
	
	# Calculate curve force (gets weaker over time)
	var curve_progress = curve_timer / curve_duration
	var remaining_strength = 1.0 - curve_progress
	
	# Apply curve force to current velocity
	var curve_force = to_planet * curve_strength * remaining_strength * delta * 60.0
	current_velocity += curve_force
	
	#print("Curve progress: ", curve_progress, " Force: ", curve_force.length())
	
	return current_velocity

func is_curve_complete() -> bool:
	"""Check if the gravity assist curve is finished"""
	return curve_timer >= curve_duration

func get_exit_velocity() -> Vector2:
	"""Get final velocity when leaving gravity assist"""
	# Apply small speed boost (gravity assist effect)
	return current_velocity * 1.1
