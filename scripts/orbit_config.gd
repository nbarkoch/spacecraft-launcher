# scripts/orbit_config.gd (UPDATED WITH TIME-BASED AUTO RELEASE)
class_name GravityAssist
extends Resource

var planet: Planet
var is_active: bool = false

# Settings from planet
var magnet_strength: float = 1.0
var collision_safety_distance: float = 0.0
var emergency_force_multiplier: float = 12.0
var angle_correction_strength: float = 15.0
var optimal_angle_tolerance: float = 7.0

# NEW: Time-based release system
var max_orbit_duration: float = 3.0  # מהכוכב
var predicted_orbit_duration: float = 0.0  # מחושב
var time_based_exit_enabled: bool = true

# Internal state
var spacecraft_ref: Spacecraft = null
var entry_time: float = 0.0
var entry_velocity: Vector2 = Vector2.ZERO
var entry_position: Vector2 = Vector2.ZERO
var entry_speed: float = 0.0
var entry_angle_to_center: float = 0.0
var should_exit: bool = false
var ideal_orbit_radius: float = 0.0

# Legacy exit calculation parameters (kept for fallback)
var natural_exit_energy: float = 0.0
var accumulated_guidance: float = 0.0

func _init(p_planet: Planet, spacecraft_velocity: Vector2, spacecraft_position: Vector2):
	planet = p_planet
	is_active = true
	entry_velocity = spacecraft_velocity
	entry_position = spacecraft_position
	entry_speed = spacecraft_velocity.length()
	entry_time = 0.0
	should_exit = false
	accumulated_guidance = 0.0
	
	if planet:
		# Get settings from planet
		magnet_strength = planet.magnet_strength
		collision_safety_distance = planet.collision_safety_distance
		emergency_force_multiplier = planet.emergency_force_multiplier
		angle_correction_strength = planet.angle_correction_strength
		optimal_angle_tolerance = planet.optimal_angle_tolerance
		
		# NEW: Calculate time-based exit duration
		predicted_orbit_duration = planet.calculate_predicted_orbit_duration(spacecraft_velocity)
		max_orbit_duration = predicted_orbit_duration
		
		ideal_orbit_radius = planet.planet_radius + (planet.gravity_radius - planet.planet_radius) * 0.6
		spacecraft_ref = get_spacecraft_reference()
		
		# Legacy calculations for fallback
		calculate_entry_conditions()
		calculate_natural_exit_energy()
		

func calculate_entry_conditions():
	"""Analyze entry conditions for smart exit calculation"""
	var to_planet = planet.global_position - entry_position
	entry_angle_to_center = entry_velocity.angle_to(to_planet)
	
	entry_angle_to_center = abs(entry_angle_to_center)
	if entry_angle_to_center > PI:
		entry_angle_to_center = 2 * PI - entry_angle_to_center

func calculate_natural_exit_energy():
	"""Calculate fallback exit energy"""
	var speed_factor = clamp(entry_speed / 100.0, 0.3, 2.0)
	var angle_factor = 1.0 + (entry_angle_to_center / PI) * 2.0
	var entry_distance = entry_position.distance_to(planet.global_position)
	var distance_factor = clamp(planet.gravity_radius / entry_distance, 0.5, 2.0)
	
	natural_exit_energy = 100.0 * angle_factor / (speed_factor * distance_factor)
	natural_exit_energy = clamp(natural_exit_energy, 50.0, 400.0)

func update_curve(delta: float, spacecraft_pos: Vector2) -> Vector2:
	if not is_active or not planet or not spacecraft_ref:
		return Vector2.ZERO
	
	entry_time += delta
	check_exit_conditions()
	
	var to_planet = planet.global_position - spacecraft_pos
	var distance = to_planet.length()
	
	if distance < 1.0:
		return Vector2.ZERO
	
	# Base gravity (unchanged)
	var gravity_force = calculate_gravity(to_planet, distance, delta)
	
	# Guidance forces (reduced when should exit)
	var guidance_force = Vector2.ZERO
	if not should_exit:
		if collision_safety_distance > 0:
			guidance_force += collision_prevention(spacecraft_pos, distance, delta)
		guidance_force += angle_correction(spacecraft_pos, to_planet, delta)
		guidance_force += orbital_magnet(spacecraft_pos, distance, delta)
		
		accumulated_guidance += guidance_force.length() * delta
	else:
		# Reduced guidance when exiting
		guidance_force = angle_correction(spacecraft_pos, to_planet, delta) * 0.1
	
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
	if angle_degrees < optimal_angle_tolerance:
		return Vector2.ZERO
	
	var tangential = Vector2(-radial_dir.y, radial_dir.x)
	if velocity.dot(tangential) < 0:
		tangential = -tangential
	
	var correction = (tangential - velocity_dir).normalized()
	var strength = angle_correction_strength * (radial_component - 0.2) * delta * 60.0
	
	return correction * strength

func orbital_magnet(spacecraft_pos: Vector2, distance: float, delta: float) -> Vector2:
	var distance_from_ideal = distance - ideal_orbit_radius
	
	if abs(distance_from_ideal) > 30.0:
		return Vector2.ZERO
	
	var direction = Vector2.ZERO
	if distance_from_ideal > 0:
		direction = (planet.global_position - spacecraft_pos).normalized()
	else:
		direction = (spacecraft_pos - planet.global_position).normalized()
	
	var strength = magnet_strength * (1.0 - abs(distance_from_ideal) / 30.0) * delta * 60.0
	return direction * strength

func check_exit_conditions():
	"""FIXED: Exit conditions based on ENTRY velocity, not current velocity"""
	if should_exit:
		return
	
	# FIXED: Use ENTRY velocity for consistent duration calculation!
	# The exit time should be based on the original launch velocity, not current orbital velocity
	if entry_time >= predicted_orbit_duration:
		should_exit = true
		return
	
	# SECONDARY: Early exit if moving away very fast (using current velocity for movement check)
	var current_velocity = spacecraft_ref.linear_velocity
	var speed = current_velocity.length()
	var to_planet = planet.global_position - spacecraft_ref.global_position
	var moving_away = to_planet.dot(current_velocity) < 0
	
	# Early exit only if moving VERY fast away and past 70% of predicted time
	if moving_away and speed > 120.0 and entry_time >= predicted_orbit_duration * 0.7:
		should_exit = true
		return
	


func is_curve_complete() -> bool:
	return should_exit

func get_exit_velocity() -> Vector2:
	return Vector2.ZERO

func get_spacecraft_reference() -> Spacecraft:
	if not planet:
		return null
	var spacecrafts = planet.get_tree().get_nodes_in_group("Spacecrafts")
	return spacecrafts[0] if spacecrafts.size() > 0 else null

# NEW: Methods for prediction and visualization
func get_predicted_arc_angle() -> float:
	"""Calculate predicted arc angle in degrees based on CURRENT velocity"""
	if not spacecraft_ref:
		return 0.0
	
	# Use CURRENT velocity for prediction
	var current_velocity = spacecraft_ref.linear_velocity
	var current_duration = planet.calculate_predicted_orbit_duration(current_velocity)
	var current_speed = current_velocity.length()
	
	if current_duration <= 0 or current_speed <= 0:
		return 0.0
	
	# תנועה מעגלית: זווית = (מהירות זוויתית) * זמן
	var orbital_speed = current_speed * 0.7  # הנחה שהמהירות יורדת ב-30% באורביט
	var angular_velocity = orbital_speed / ideal_orbit_radius  # רדיאנים לשנייה
	var total_angle_radians = angular_velocity * current_duration
	
	return rad_to_deg(total_angle_radians)

func get_arc_rotation_speed() -> float:
	"""Get visual rotation speed for arc based on CURRENT orbital motion"""
	if not spacecraft_ref:
		return 30.0
	
	var current_velocity = spacecraft_ref.linear_velocity
	var current_duration = planet.calculate_predicted_orbit_duration(current_velocity)
	
	if current_duration <= 0:
		return 30.0
	
	var arc_angle = get_predicted_arc_angle()
	return arc_angle / current_duration  # מעלות לשנייה

func get_current_predicted_duration() -> float:
	"""Get current predicted duration based on current velocity"""
	if not spacecraft_ref:
		return predicted_orbit_duration
	
	return planet.calculate_predicted_orbit_duration(spacecraft_ref.linear_velocity)
