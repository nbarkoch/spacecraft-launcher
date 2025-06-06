class_name GravityAssist
extends Resource

var planet: Planet
var is_active: bool = false

# Core settings
var collision_safety_distance: float = 25.0
var emergency_force_multiplier: float = 12.0
var angle_correction_strength: float = 12.0
var optimal_angle_tolerance: float = 7.0
var magnet_strength: float = 1.0

# Duration control
var predicted_orbit_duration: float = 0.0

# Internal state
var spacecraft_ref: Spacecraft = null
var entry_time: float = 0.0
var entry_speed: float = 0.0
var should_exit: bool = false
var ideal_orbit_radius: float = 0.0

func _init(p_planet: Planet, spacecraft: Spacecraft):
	planet = p_planet
	is_active = true
	var spacecraft_velocity = spacecraft.linear_velocity
	entry_speed = spacecraft_velocity.length()
	entry_time = 0.0
	should_exit = false
	
	if planet:
		predicted_orbit_duration = calculate_orbit_duration(spacecraft_velocity)
		ideal_orbit_radius = planet.planet_radius + ((planet.gravity_radius - planet.planet_radius) / 2.0)
		spacecraft_ref = spacecraft


func calculate_orbit_duration(velocity: Vector2) -> float:
	var speed = velocity.length()
	
	# Calculate orbit radius - between planet surface and ideal orbit
	var orbit_radius = planet.planet_radius + (ideal_orbit_radius - planet.planet_radius) * 0.7
	var orbit_circumference = 2 * PI * orbit_radius
	
	var base_duration = 0.0
	var orbital_speed = speed * 0.6
	var max_duration = orbit_circumference / orbital_speed
	
	# For very low speeds (≤50) - full 360° orbit
	if speed <= 50.0:
		base_duration = max_duration
	else:
		# Calculate stabilizer control factor (decreases with speed)
		var stabilizer_control = calculate_stabilizer_control(speed)
		
		# Max angle starts at 360° for speed 50, reduces based on speed and stabilizer control
		var max_angle_at_50 = 360.0
		var speed_reduction_factor = (speed - 50.0) / 250.0  # Spread reduction over 250 speed units
		speed_reduction_factor = clamp(speed_reduction_factor, 0.0, 1.0)
		
		# Base angle reduces from 360° to ~10° based on speed
		var base_angle = max_angle_at_50 * (1.0 - speed_reduction_factor * 0.97)  # Down to 3% (≈10°)
		
		# Apply stabilizer control - less control = less angle
		var final_angle = base_angle * stabilizer_control
		
		# Calculate duration based on final angle
		var arc_length = orbit_circumference * (final_angle / 360.0)
		var effective_orbital_speed = speed * (0.7 + speed_reduction_factor * 0.3)  # 0.7 to 1.0
		base_duration = arc_length / effective_orbital_speed
	
	# Apply gravity factor
	var gravity_factor = 300.0 / max(planet.gravity_strength, 50.0)
	
	# Clamp with minimum 1.0 second and max as full orbit
	return clamp(base_duration * gravity_factor, 1.0, max_duration * gravity_factor / 2)

func calculate_stabilizer_control(speed: float) -> float:
	"""Calculate how much control the stabilizer has at this speed"""
	# Stabilizer control decreases exponentially with speed
	# At speed 50: nearly full control (0.95)
	# At speed 150: good control (0.75) 
	# At speed 300: limited control (0.3)
	# At speed 500+: minimal control (0.1)
	
	var base_control = 1.0
	var speed_penalty = (speed - 50.0) / 200.0  # Normalize speed above 50
	speed_penalty = clamp(speed_penalty, 0.0, 3.0)
	
	# Exponential decay of control
	var control_factor = base_control * exp(-speed_penalty * 1.2)
	
	return clamp(control_factor, 0.1, 0.95)
	
func update_curve(delta: float, spacecraft_pos: Vector2) -> Vector2:
	if not is_active or not planet or not spacecraft_ref:
		return Vector2.ZERO
	
	entry_time += delta
	check_exit_conditions()
	
	var to_planet = planet.global_position - spacecraft_pos
	var distance = to_planet.length()
	
	if distance < 1.0:
		return Vector2.ZERO
	
	# Base gravity
	var gravity_force = calculate_gravity(to_planet, distance, delta)
	
	# Corrections only if not exiting
	var guidance_force = Vector2.ZERO
	if not should_exit:
		guidance_force += collision_prevention(spacecraft_pos, distance, delta)
		guidance_force += angle_correction(spacecraft_pos, to_planet, delta)
		guidance_force += orbital_magnet(spacecraft_pos, distance, delta)
		guidance_force += gentle_speed_boost(delta)
	
	return gravity_force + guidance_force

func calculate_gravity(to_planet: Vector2, distance: float, delta: float) -> Vector2:
	var force_magnitude = planet.gravity_strength * delta * 60.0 / (distance * 0.01)
	return to_planet.normalized() * force_magnitude

func collision_prevention(spacecraft_pos: Vector2, distance: float, delta: float) -> Vector2:
	var distance_from_surface = distance - planet.planet_radius
	if distance_from_surface > collision_safety_distance:
		return Vector2.ZERO
	
	var danger_factor = 1.0 - (distance_from_surface / collision_safety_distance)
	var push_direction = (spacecraft_pos - planet.global_position).normalized()
	return push_direction * emergency_force_multiplier * danger_factor * delta * 60.0

func angle_correction(spacecraft_pos: Vector2, to_planet: Vector2, delta: float) -> Vector2:
	var velocity = spacecraft_ref.linear_velocity
	var speed = velocity.length()
	
	if speed < 20.0:
		return Vector2.ZERO
	
	var radial_dir = to_planet.normalized()
	var velocity_dir = velocity.normalized()
	var radial_component = abs(radial_dir.dot(velocity_dir))
	var angle_degrees = rad_to_deg(acos(clamp(1.0 - radial_component, 0.0, 1.0)))
	
	# Simple graduated correction
	var angle_error = max(0.0, angle_degrees - optimal_angle_tolerance)
	if angle_error <= 0.0:
		return Vector2.ZERO
	
	var max_error = 90.0 - optimal_angle_tolerance
	var normalized_error = min(angle_error / max_error, 1.0)
	var correction_intensity = normalized_error * normalized_error  # קבוע במקום pow()
	
	var tangential = Vector2(-radial_dir.y, radial_dir.x)
	if velocity.dot(tangential) < 0:
		tangential = -tangential
	
	var correction = (tangential - velocity_dir).normalized()
	var strength = angle_correction_strength * correction_intensity * delta * 60.0
	
	return correction * strength

func orbital_magnet(spacecraft_pos: Vector2, distance: float, delta: float) -> Vector2:
	var distance_from_ideal = distance - ideal_orbit_radius
	var abs_error = abs(distance_from_ideal)
	
	if abs_error < 2.0 or abs_error > 50.0:
		return Vector2.ZERO
	
	var correction_intensity = min(abs_error / 30.0, 1.0)
	
	var direction = Vector2.ZERO
	if distance_from_ideal > 0:
		direction = (planet.global_position - spacecraft_pos).normalized()
	else:
		direction = (spacecraft_pos - planet.global_position).normalized()
	
	var strength = magnet_strength * correction_intensity * delta * 60.0
	return direction * strength

func gentle_speed_boost(delta: float) -> Vector2:
	var current_velocity = spacecraft_ref.linear_velocity
	var current_speed = current_velocity.length()
	
	# Only boost if speed dropped significantly
	if current_speed > entry_speed * 0.7 or current_speed < 10.0:
		return Vector2.ZERO
	
	# Check if reasonably in orbit
	var distance_to_planet = spacecraft_ref.global_position.distance_to(planet.global_position)
	if abs(distance_to_planet - ideal_orbit_radius) > 30.0:
		return Vector2.ZERO
	
	var boost_strength = (entry_speed * 0.7 - current_speed) * 0.1 * delta * 60.0
	boost_strength = min(boost_strength, 8.0)
	
	return current_velocity.normalized() * boost_strength

func check_exit_conditions():
	if should_exit:
		return
	print("entry_time", entry_time, " ", predicted_orbit_duration)
	if entry_time >= predicted_orbit_duration:
		should_exit = true

func is_curve_complete() -> bool:
	return should_exit

func get_spacecraft_reference() -> Spacecraft:
	if not planet:
		return null
	var spacecrafts = planet.get_tree().get_nodes_in_group("Spacecrafts")
	return spacecrafts[0] if spacecrafts.size() > 0 else null
