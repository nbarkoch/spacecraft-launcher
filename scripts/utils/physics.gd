class_name PhysicsUtils

# =====================================================
# PHYSICS CONSTANTS
# =====================================================

# Gravity and Force Constants
const GRAVITY_DELTA_MULTIPLIER: float = 60.0
const GRAVITY_DISTANCE_FACTOR: float = 0.01
const NEUTRAL_GRAVITY: float = 300.0
const MIN_GRAVITY: float = 50.0
const MAX_GRAVITY: float = 800.0

# Orbit Control Constants
const COLLISION_SAFETY_DISTANCE: float = 25.0
const EMERGENCY_FORCE_MULTIPLIER: float = 12.0
const ANGLE_CORRECTION_STRENGTH: float = 15.0
const OPTIMAL_ANGLE_TOLERANCE: float = 7.0
const MAGNET_STRENGTH: float = 1.0

# Stabilizer Control Constants
const STABILIZER_BASE_CONTROL: float = 1.0
const STABILIZER_SPEED_PENALTY_DIVISOR: float = 200.0
const STABILIZER_DECAY_RATE: float = 1.2
const STABILIZER_MIN_CONTROL: float = 0.1
const STABILIZER_MAX_CONTROL: float = 0.95

# Orbit Duration Constants
const BASE_ORBIT_DURATION: float = 3.0
const ORBITAL_SPEED_FACTOR: float = 0.6
const SPEED_THRESHOLD_LOW: float = 50.0
const SPEED_REDUCTION_RANGE: float = 250.0
const SPEED_REDUCTION_MULTIPLIER: float = 0.97
const ORBITAL_SPEED_MIN: float = 0.7
const ORBITAL_SPEED_MAX: float = 1.0

# Angle and Arc Constants
const MAX_ANGLE_AT_50: float = 360.0
const MIN_ARC_ANGLE: float = 5.0
const MAX_ARC_ANGLE: float = 360.0
const FULL_CIRCLE_DEGREES: float = 360.0

# Speed Boost Constants
const SPEED_BOOST_THRESHOLD: float = 0.7
const SPEED_BOOST_MIN: float = 10.0
const SPEED_BOOST_MULTIPLIER: float = 0.1
const SPEED_BOOST_MAX: float = 8.0
const ORBIT_TOLERANCE: float = 30.0

# Orbital Magnet Constants
const MAGNET_MIN_DISTANCE: float = 2.0
const MAGNET_MAX_DISTANCE: float = 50.0
const MAGNET_CORRECTION_DIVISOR: float = 30.0

# Damping and Physics Constants
const ORBITAL_DAMPING_FACTOR: float = 0.001
const VELOCITY_DAMPING_PER_FRAME: float = 0.999
const SPACECRAFT_COLLISION_RADIUS: float = 6.0
const MIN_VELOCITY_FOR_ANGLE: float = 20.0
const MIN_DISTANCE_FOR_FORCE: float = 1.0

# Trajectory Prediction Constants
const TRAJECTORY_TIME_STEP: float = 1.0 / 60.0
const MAX_TRAJECTORY_STEPS: int = 120
const TRAJECTORY_POINT_INTERVAL: int = 2
const VELOCITY_FACTOR_DIVISOR: float = 130.0
const VELOCITY_FACTOR_MIN: float = 0.74
const VELOCITY_FACTOR_MAX: float = 1.0

# Gravity Behavior Thresholds
const HELPFUL_GRAVITY_THRESHOLD: float = 150.0
const NORMAL_GRAVITY_THRESHOLD: float = 400.0
const CHALLENGING_GRAVITY_THRESHOLD: float = 600.0

# Gravity Color Constants
const LOW_GRAVITY_THRESHOLD: float = 150.0
const HIGH_GRAVITY_THRESHOLD: float = 600.0

# Prevention Multipliers
const HELPFUL_PREVENTION_MULTIPLIER: float = 2.0
const NORMAL_PREVENTION_MULTIPLIER: float = 1.0
const CHALLENGING_PREVENTION_MULTIPLIER: float = 0.3
const EVIL_PREVENTION_MULTIPLIER: float = -0.5

# Arc Visualization Constants
const ARC_SPEED_RANGE_1: float = 150.0
const ARC_SPEED_RANGE_2: float = 300.0
const ARC_ANGLE_REDUCTION: float = 315.0
const ARC_TIME_MAX: float = 2.0
const ARC_TIME_MIN: float = 0.5
const ARC_TIME_REDUCTION: float = 1.5
const ARC_ORBITAL_SPEED_FACTOR: float = 0.5
const ARC_ORBITAL_SPEED_ALT: float = 0.7
const ARC_MAX_ANGLE_CAP: float = 45.0
const ARC_DEFAULT_ROTATION_SPEED: float = 30.0

# Approach Angle Constants
const HEAD_ON_ANGLE_THRESHOLD: float = 5.0
const TANGENTIAL_ANGLE_MAX: float = 90.0
const MIN_VELOCITY_FOR_APPROACH: float = 1.0

# Bounds and Limits
const MAX_SIMULATION_BOUNDS: float = 1000.0
const MAX_VELOCITY_LIMIT: float = 3000.0
const CRASH_DURATION: float = 0.1

# =====================================================
# GRAVITY AND FORCE CALCULATIONS
# =====================================================

static func calculate_gravity_force(position: Vector2, planet: Planet, delta: float) -> Vector2:
	"""Calculate gravity force exactly like orbit_config.gd"""
	var to_planet = planet.global_position - position
	var distance = to_planet.length()
	
	if distance < MIN_DISTANCE_FOR_FORCE:
		return Vector2.ZERO
	
	# EXACT formula from orbit_config.gd
	var force_magnitude = planet.gravity_strength * delta * GRAVITY_DELTA_MULTIPLIER / (distance * GRAVITY_DISTANCE_FACTOR)
	var force_direction = to_planet.normalized()
	return force_direction * force_magnitude

static func calculate_gravity(to_planet: Vector2, distance: float, delta: float, gravity_strength: float) -> Vector2:
	var force_magnitude = gravity_strength * delta * GRAVITY_DELTA_MULTIPLIER / (distance * GRAVITY_DISTANCE_FACTOR)
	return to_planet.normalized() * force_magnitude

# =====================================================
# APPROACH ANGLE CALCULATIONS
# =====================================================

static func calculate_approach_angle(spacecraft_pos: Vector2, spacecraft_velocity: Vector2, planet_pos: Vector2) -> float:
	"""Calculate how perpendicular the approach is (0° = head-on, 90° = tangential)"""
	var to_planet = planet_pos - spacecraft_pos
	var approach_direction = spacecraft_velocity.normalized()
	
	if spacecraft_velocity.length() < MIN_VELOCITY_FOR_APPROACH:
		return 0.0  # No velocity = head-on collision
	
	# Calculate angle between velocity and direction to planet center
	var dot_product = to_planet.normalized().dot(approach_direction)
	var angle_radians = acos(clamp(abs(dot_product), 0.0, 1.0))
	var angle_degrees = rad_to_deg(angle_radians)
	
	# Return perpendicularity: 0° = head-on, 90° = tangential
	return min(angle_degrees, TANGENTIAL_ANGLE_MAX)

# =====================================================
# STABILIZER CONTROL CALCULATIONS
# =====================================================

static func calculate_stabilizer_control(speed: float) -> float:
	"""Calculate how much control the stabilizer has at this speed"""
	# Stabilizer control decreases exponentially with speed
	# At speed 50: nearly full control (0.95)
	# At speed 150: good control (0.75) 
	# At speed 300: limited control (0.3)
	# At speed 500+: minimal control (0.1)
	
	var base_control = STABILIZER_BASE_CONTROL
	var speed_penalty = (speed - SPEED_THRESHOLD_LOW) / STABILIZER_SPEED_PENALTY_DIVISOR  # Normalize speed above 50
	speed_penalty = clamp(speed_penalty, 0.0, 3.0)
	
	# Exponential decay of control
	var control_factor = base_control * exp(-speed_penalty * STABILIZER_DECAY_RATE)
	
	return clamp(control_factor, STABILIZER_MIN_CONTROL, STABILIZER_MAX_CONTROL)

# =====================================================
# ORBIT DURATION CALCULATIONS
# =====================================================

static func calculate_orbit_duration(planet: Planet, velocity: Vector2) -> float:
	var speed = velocity.length()
	
	# Calculate orbit radius - between planet surface and ideal orbit
	var planet_radius = planet.planet_radius
	var gravity_radius = planet.gravity_radius
	var ideal_orbit_radius = planet_radius + ((gravity_radius - planet_radius) / 2.0)
	var orbit_radius = planet_radius + (ideal_orbit_radius - planet_radius) * ORBITAL_SPEED_MIN
	var orbit_circumference = 2 * PI * orbit_radius
	
	var base_duration = 0.0
	var orbital_speed = speed * ORBITAL_SPEED_FACTOR
	var max_duration = orbit_circumference / orbital_speed
	
	# For very low speeds (≤50) - full 360° orbit
	if speed <= SPEED_THRESHOLD_LOW:
		base_duration = max_duration
	else:
		# Calculate stabilizer control factor (decreases with speed)
		var stabilizer_control = calculate_stabilizer_control(speed)
		
		# Max angle starts at 360° for speed 50, reduces based on speed and stabilizer control
		var max_angle_at_50 = MAX_ANGLE_AT_50
		var speed_reduction_factor = (speed - SPEED_THRESHOLD_LOW) / SPEED_REDUCTION_RANGE  # Spread reduction over 250 speed units
		speed_reduction_factor = clamp(speed_reduction_factor, 0.0, 1.0)
		
		# Base angle reduces from 360° to ~10° based on speed
		var base_angle = max_angle_at_50 * (1.0 - speed_reduction_factor * SPEED_REDUCTION_MULTIPLIER)  # Down to 3% (≈10°)
		
		# Apply stabilizer control - less control = less angle
		var final_angle = base_angle * stabilizer_control
		
		# Calculate duration based on final angle
		var arc_length = orbit_circumference * (final_angle / FULL_CIRCLE_DEGREES)
		var effective_orbital_speed = speed * (ORBITAL_SPEED_MIN + speed_reduction_factor * (ORBITAL_SPEED_MAX - ORBITAL_SPEED_MIN))  # 0.7 to 1.0
		base_duration = arc_length / effective_orbital_speed
	
	# Apply gravity factor
	var gravity_factor = NEUTRAL_GRAVITY / max(planet.gravity_strength, MIN_GRAVITY)
	
	# Clamp with minimum 1.0 second and max as full orbit
	return clamp(base_duration * gravity_factor, 1.0, max_duration * gravity_factor / 2)

static func calculate_exact_orbit_duration(planet: Planet, velocity: Vector2, spacecraft_pos: Vector2 = Vector2.ZERO) -> float:
	"""Use the EXACT same calculation as the NEW orbit_config WITH approach angle consideration"""
	var speed = velocity.length()
	
	# Calculate orbit radius - same as in orbit_config
	var planet_radius = planet.planet_radius
	var gravity_radius = planet.gravity_radius
	var ideal_orbit_radius = planet_radius + ((gravity_radius - planet_radius) / 2.0)
	var orbit_radius = planet_radius + (ideal_orbit_radius - planet_radius) * 0.7
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
	
	# NEW: Apply approach angle factor if spacecraft position is provided
	var angle_factor = 1.0
	if spacecraft_pos != Vector2.ZERO:
		var approach_angle = calculate_approach_angle(spacecraft_pos, velocity, planet.global_position)
		if approach_angle < 5.0:  # Very head-on approach
			return 0.1  # Almost immediate crash
		angle_factor = approach_angle / 90.0  # Scale by approach angle
		angle_factor = max(angle_factor, 0.1)  # Minimum factor
	
	# Clamp with minimum 1.0 second and max as full orbit, modified by angle
	return clamp(base_duration * gravity_factor * angle_factor, 0.1, max_duration * gravity_factor / 2)

static func calculate_predicted_orbit_duration_with_angle(planet: Planet, spacecraft_velocity: Vector2, spacecraft_pos: Vector2) -> float:
	"""Calculate orbit duration based on gravity, velocity, and approach angle"""
	var speed = spacecraft_velocity.length()
	var approach_angle = calculate_approach_angle(spacecraft_pos, spacecraft_velocity, planet.global_position)
	
	if speed <= 0 or approach_angle < 5.0:  # Head-on approaches
		return 0.1  # Very short time before crash
	
	# Base duration scaling factors
	var gravity_factor = 300.0 / planet.gravity_strength  # Lower gravity = longer duration
	var velocity_factor = 100.0 / max(speed, 10.0)  # Higher velocity = shorter duration  
	var angle_factor = approach_angle / 90.0  # More perpendicular = longer duration
	
	# Calculate final duration
	var base_orbit_duration = 3.0  # Same as planet.gd
	var duration = base_orbit_duration * gravity_factor * velocity_factor * angle_factor
	
	# Clamp to reasonable bounds
	return clamp(duration, 0.1, 8.0)

# =====================================================
# ARC ANGLE CALCULATIONS
# =====================================================

static func calculate_exact_arc_angle(planet: Planet, velocity: Vector2, duration: float) -> float:
	"""Calculate arc angle by reconstructing the SAME logic used in duration calculation"""
	var speed = velocity.length()
	
	if duration <= 0 or speed <= 0:
		return 0.0
	
	# Use the SAME logic as in calculate_exact_orbit_duration to get the angle
	if speed <= 50.0:
		# For low speeds, the duration represents a full orbit, so show full circle
		return 360.0
	else:
		# For higher speeds, calculate the angle that was used to determine the duration
		var stabilizer_control = calculate_stabilizer_control(speed)
		var speed_reduction_factor = (speed - 50.0) / 250.0
		speed_reduction_factor = clamp(speed_reduction_factor, 0.0, 1.0)
		
		# This is the SAME calculation used in duration - the intended angle
		var base_angle = 360.0 * (1.0 - speed_reduction_factor * 0.97)
		var final_angle = base_angle * stabilizer_control
		
		return clamp(final_angle, 5.0, 360.0)

# =====================================================
# ORBITAL FORCE SIMULATIONS
# =====================================================

static func calculate_collision_prevention(spacecraft_pos: Vector2, distance: float, delta: float, planet: Planet) -> Vector2:
	var collision_safety_distance = 25.0
	var distance_from_surface = distance - planet.planet_radius
	if distance_from_surface > collision_safety_distance:
		return Vector2.ZERO
	
	var danger_factor = 1.0 - (distance_from_surface / collision_safety_distance)
	var push_direction = (spacecraft_pos - planet.global_position).normalized()
	var emergency_force_multiplier = 12.0
	return push_direction * emergency_force_multiplier * danger_factor * delta * 60.0

static func calculate_angle_correction(spacecraft_velocity: Vector2, to_planet: Vector2, delta: float) -> Vector2:
	var velocity = spacecraft_velocity
	var speed = velocity.length()
	
	if speed < 20.0:
		return Vector2.ZERO
	
	var radial_dir = to_planet.normalized()
	var velocity_dir = velocity.normalized()
	var radial_component = abs(radial_dir.dot(velocity_dir))
	var angle_degrees = rad_to_deg(acos(clamp(1.0 - radial_component, 0.0, 1.0)))
	
	# Simple graduated correction
	var optimal_angle_tolerance = 7.0
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
	var angle_correction_strength = 15.0
	var strength = angle_correction_strength * correction_intensity * delta * 60.0
	
	return correction * strength

static func calculate_orbital_magnet(spacecraft_pos: Vector2, distance: float, delta: float, planet: Planet) -> Vector2:
	var planet_radius = planet.planet_radius
	var gravity_radius = planet.gravity_radius
	var ideal_orbit_radius = planet_radius + ((gravity_radius - planet_radius) / 2.0)
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
	
	var magnet_strength = 1.0
	var strength = magnet_strength * correction_intensity * delta * 60.0
	return direction * strength

static func calculate_gentle_speed_boost(spacecraft_velocity: Vector2, entry_speed: float, distance: float, ideal_orbit_radius: float, delta: float) -> Vector2:
	var current_velocity = spacecraft_velocity
	var current_speed = current_velocity.length()
	
	# Only boost if speed dropped significantly
	if current_speed > entry_speed * 0.7 or current_speed < 10.0:
		return Vector2.ZERO
	
	# Check if reasonably in orbit
	if abs(distance - ideal_orbit_radius) > 30.0:
		return Vector2.ZERO
	
	var boost_strength = (entry_speed * 0.7 - current_speed) * 0.1 * delta * 60.0
	boost_strength = min(boost_strength, 8.0)
	
	return current_velocity.normalized() * boost_strength

static func calculate_orbit_simulation_force(position: Vector2, velocity: Vector2, planet: Planet, delta: float, predicted_arc_angle: float) -> Vector2:
	"""Orbit forces that match the REAL spacecraft behavior - COPY from orbit_config.gd"""
	var to_planet = planet.global_position - position
	var distance = to_planet.length()
	
	if distance < 1.0:
		return Vector2.ZERO
	
	# Base gravity (same as orbit_config)
	var gravity_force = planet.gravity_strength * delta * 60.0 / (distance * 0.01)
	var gravity_vector = to_planet.normalized() * gravity_force
	
	# Orbital guidance that matches the real GravityAssist behavior
	var ideal_orbit_radius = planet.planet_radius + ((planet.gravity_radius - planet.planet_radius) / 2.0)
	var orbit_radius = planet.planet_radius + (ideal_orbit_radius - planet.planet_radius) * 0.7
	var distance_from_ideal = distance - orbit_radius
	
	var guidance_force = Vector2.ZERO
	
	# 1. Collision prevention (same as orbit_config.gd)
	var collision_safety_distance = 25.0
	var distance_from_surface = distance - planet.planet_radius
	if distance_from_surface <= collision_safety_distance:
		var danger_factor = 1.0 - (distance_from_surface / collision_safety_distance)
		var push_direction = (position - planet.global_position).normalized()
		var emergency_force_multiplier = 12.0
		guidance_force += push_direction * emergency_force_multiplier * danger_factor * delta * 60.0
	
	# 2. Orbital magnet (same as orbit_config.gd)
	if abs(distance_from_ideal) > 2.0 and abs(distance_from_ideal) < 50.0:
		var direction = Vector2.ZERO
		if distance_from_ideal > 0:
			direction = to_planet.normalized()
		else:
			direction = -to_planet.normalized()
		
		var correction_intensity = min(abs(distance_from_ideal) / 30.0, 1.0)
		var magnet_strength = 1.0
		var force_strength = magnet_strength * correction_intensity * delta * 60.0
		guidance_force += direction * force_strength
	
	# 3. CRITICAL: Angle correction (same as orbit_config.gd) - THIS IS KEY!
	var speed = velocity.length()
	if speed > 20.0:
		var radial_dir = to_planet.normalized()
		var velocity_dir = velocity.normalized()
		var radial_component = abs(radial_dir.dot(velocity_dir))
		var angle_degrees = rad_to_deg(acos(clamp(1.0 - radial_component, 0.0, 1.0)))
		
		# Use same optimal angle tolerance as orbit_config.gd
		var optimal_angle_tolerance = 7.0
		var angle_error = max(0.0, angle_degrees - optimal_angle_tolerance)
		
		if angle_error > 0.0:
			var max_error = 90.0 - optimal_angle_tolerance
			var normalized_error = min(angle_error / max_error, 1.0)
			var correction_intensity = normalized_error * normalized_error
			
			# Calculate tangential direction (same as orbit_config.gd)
			var tangential = Vector2(-radial_dir.y, radial_dir.x)
			if velocity.dot(tangential) < 0:
				tangential = -tangential
			
			var correction = (tangential - velocity_dir).normalized()
			var angle_correction_strength = 15.0  # Same as orbit_config.gd
			var strength = angle_correction_strength * correction_intensity * delta * 60.0
			guidance_force += correction * strength
	
	# 4. Gentle speed boost (same as orbit_config.gd)
	var current_speed = velocity.length()
	# Approximate entry speed based on position (rough estimate)
	var entry_speed_estimate = 150.0  # Reasonable estimate for entry speed
	if current_speed < entry_speed_estimate * 0.7 and current_speed > 10.0:
		# Check if reasonably in orbit
		if abs(distance - ideal_orbit_radius) <= 30.0:
			var boost_strength = (entry_speed_estimate * 0.7 - current_speed) * 0.1 * delta * 60.0
			boost_strength = min(boost_strength, 8.0)
			guidance_force += velocity.normalized() * boost_strength
	
	# Apply realistic damping during orbit (like real spacecraft)
	var orbital_damping = velocity * -0.001 * delta * 60.0  # Very light damping
	
	return gravity_vector + guidance_force + orbital_damping

# =====================================================
# PLANET SEARCH AND UTILITIES
# =====================================================

static func find_all_planets(scene_tree: SceneTree) -> Array:
	"""Find all Planet nodes in the scene"""
	var planets = []
	
	# Use group method first
	var grouped_planets = scene_tree.get_nodes_in_group("Planets")
	if grouped_planets.size() > 0:
		return grouped_planets
	
	# Fallback search
	var game_scene = scene_tree.current_scene
	if game_scene:
		find_planets_recursive(game_scene, planets)
	
	return planets

static func find_planets_recursive(node: Node, planets: Array):
	"""Recursively search for Planet nodes"""
	if node.has_method("_on_gravity_zone_body_entered") and node.has_method("_on_planet_area_body_entered"):
		if "gravity_radius" in node and "planet_radius" in node and "gravity_strength" in node:
			planets.append(node)
	
	for child in node.get_children():
		find_planets_recursive(child, planets)

static func get_planet_at_position(pos: Vector2, planets: Array) -> Planet:
	"""Check if position is within any planet's gravity zone"""
	for planet in planets:
		if not planet or not is_instance_valid(planet):
			continue
		
		var distance = pos.distance_to(planet.global_position)
		if distance <= planet.gravity_radius:
			return planet
	return null

# =====================================================
# GRAVITY BEHAVIOR AND VISUAL FEEDBACK
# =====================================================

static func get_gravity_behavior_type(gravity_strength: float) -> String:
	"""Determine what type of behavior this planet has based on gravity"""
	if gravity_strength < 150.0:
		return "helpful"     # Push out + sweet spot help
	elif gravity_strength <= 400.0:
		return "normal"      # Sweet spot help only  
	elif gravity_strength <= 600.0:
		return "challenging" # Minimal help
	else:
		return "evil"        # Push IN toward planet

static func get_prevention_multiplier(gravity_strength: float) -> float:
	"""Calculate how much collision prevention this planet provides"""
	var behavior = get_gravity_behavior_type(gravity_strength)
	
	match behavior:
		"helpful":
			return 2.0  # Double prevention force
		"normal":
			return 1.0  # Normal prevention
		"challenging":
			return 0.3  # Weak prevention
		"evil":
			return -0.5 # NEGATIVE = pulls spacecraft IN
		_:
			return 1.0

static func calculate_gravity_color(gravity_strength: float) -> Color:
	"""Calculate zone color based on gravity strength with smooth gradient"""
	# Constants for gravity color
	var LOW_GRAVITY_COLOR = Color.WHITE      # White for low gravity
	var HIGH_GRAVITY_COLOR = Color.RED       # Red for high gravity
	var LOW_GRAVITY_THRESHOLD = 150.0        # Below this = white
	var HIGH_GRAVITY_THRESHOLD = 600.0       # Above this = red
	
	# Normalize gravity strength between 0 and 1
	var normalized_gravity = 0.0
	
	if gravity_strength <= LOW_GRAVITY_THRESHOLD:
		# Low gravity = white
		normalized_gravity = 0.0
	elif gravity_strength >= HIGH_GRAVITY_THRESHOLD:
		# High gravity = red
		normalized_gravity = 1.0
	else:
		# Between thresholds = interpolate
		var range = HIGH_GRAVITY_THRESHOLD - LOW_GRAVITY_THRESHOLD
		var position_in_range = gravity_strength - LOW_GRAVITY_THRESHOLD
		normalized_gravity = position_in_range / range
	
	# Create smooth color transition: White -> Orange -> Red
	var result_color: Color
	
	if normalized_gravity <= 0.5:
		# First half: White to Orange
		var orange_color = Color(1.0, 0.5, 0.0)  # Orange
		var t = normalized_gravity * 2.0  # Scale to 0-1 for first half
		result_color = LOW_GRAVITY_COLOR.lerp(orange_color, t)
	else:
		# Second half: Orange to Red
		var orange_color = Color(1.0, 0.5, 0.0)  # Orange
		var t = (normalized_gravity - 0.5) * 2.0  # Scale to 0-1 for second half
		result_color = orange_color.lerp(HIGH_GRAVITY_COLOR, t)
	
	# Maintain semi-transparency
	result_color.a = 0.2
	
	return result_color

# =====================================================
# ARC VISUALIZATION UTILITIES
# =====================================================

static func get_predicted_arc_angle(velocity: Vector2, radius: float) -> float:
	"""Calculate predicted arc angle using the SAME logic as orbit_config"""
	var speed = velocity.length()
	
	if speed <= 0:
		return 0.0
	
	# Use the SAME calculation as calculate_orbit_duration
	var orbit_circumference = 2 * PI * radius
	
	var angle_degrees = 0.0
	
	# Same logic as in orbit_config
	if speed <= 50.0:
		angle_degrees = 360.0  # Full orbit for slow speeds
	elif speed <= 150.0:
		var speed_factor = (speed - 50.0) / 100.0
		angle_degrees = 360.0 - (speed_factor * 315.0)  # 360° down to 45°
	else:
		# For high speeds, calculate based on time and reduced orbital speed
		var predicted_time = 0.0
		if speed <= 300.0:
			var speed_factor = (speed - 150.0) / 150.0
			predicted_time = 2.0 - (speed_factor * 1.5)  # 2.0 down to 0.5
		else:
			predicted_time = 0.5
		
		# Calculate what angle this time represents
		var orbital_speed = speed * 0.5  # Assume some orbital slowdown
		var arc_length = orbital_speed * predicted_time
		angle_degrees = (arc_length / orbit_circumference) * 360.0
		angle_degrees = min(angle_degrees, 45.0)  # Cap at 45°
	
	return clamp(angle_degrees, 5.0, 360.0)

static func get_arc_rotation_speed(velocity: Vector2, radius: float) -> float:
	"""Get visual rotation speed for arc based on current orbital motion"""
	var speed = velocity.length()
	
	if speed <= 0:
		return 30.0
	
	# Base rotation speed on the predicted time duration
	var predicted_time = 0.0
	if speed <= 50.0:
		var orbit_circumference = 2 * PI * radius
		var orbital_speed = speed * 0.7
		predicted_time = orbit_circumference / orbital_speed
	elif speed <= 150.0:
		var speed_factor = (speed - 50.0) / 100.0
		var angle_degrees = 360.0 - (speed_factor * 315.0)
		var orbit_circumference = 2 * PI * radius
		var arc_length = orbit_circumference * (angle_degrees / 360.0)
		predicted_time = arc_length / speed
	else:
		if speed <= 300.0:
			var speed_factor = (speed - 150.0) / 150.0
			predicted_time = 2.0 - (speed_factor * 1.5)
		else:
			predicted_time = 0.5
	
	# Calculate rotation speed: angle per second
	var arc_angle = get_predicted_arc_angle(velocity, radius)
	if predicted_time > 0:
		return arc_angle / predicted_time
	else:
		return 30.0
