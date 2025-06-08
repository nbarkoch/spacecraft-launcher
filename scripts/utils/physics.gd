class_name PhysicsUtils

# =====================================================
# PHYSICS CONSTANTS
# =====================================================

# Basic Physics
const GRAVITY_DELTA_MULTIPLIER: float = 60.0
const GRAVITY_DISTANCE_FACTOR: float = 0.01
const MIN_DISTANCE_FOR_FORCE: float = 1.0
const MIN_VELOCITY_FOR_ANGLE: float = 20.0

# Orbit Control
const COLLISION_SAFETY_DISTANCE: float = 25.0
const EMERGENCY_FORCE_MULTIPLIER: float = 3.0
const ANGLE_CORRECTION_STRENGTH: float = 10.0
const OPTIMAL_ANGLE_TOLERANCE: float = 12.0
const MAGNET_STRENGTH: float = 1.0

# Duration and Speed
const SPEED_THRESHOLD_LOW: float = 50.0
const SPEED_REDUCTION_RANGE: float = 250.0
const SPEED_REDUCTION_MULTIPLIER: float = 0.97
const ORBITAL_SPEED_FACTOR: float = 0.6
const ORBIT_RADIUS_FACTOR: float = 0.7

# Stabilizer Control
const STABILIZER_DECAY_RATE: float = 1.2
const STABILIZER_MIN_CONTROL: float = 0.1
const STABILIZER_MAX_CONTROL: float = 0.95

# Trajectory Simulation
const TRAJECTORY_TIME_STEP: float = 1.0 / 60.0
const MAX_TRAJECTORY_STEPS: int = 140
const TRAJECTORY_POINT_INTERVAL: int = 2
const VELOCITY_DAMPING_PER_FRAME: float = 0.999
const SPACECRAFT_COLLISION_RADIUS: float = 6.0
const MAX_SIMULATION_BOUNDS: float = 1000.0
const MAX_VELOCITY_LIMIT: float = 3000.0

# Gravity Behavior
const HELPFUL_GRAVITY_THRESHOLD: float = 150.0
const NORMAL_GRAVITY_THRESHOLD: float = 400.0
const CHALLENGING_GRAVITY_THRESHOLD: float = 600.0

# =====================================================
# CORE ORBIT CALCULATIONS
# =====================================================

static func calculate_orbit_radius(planet: Planet) -> float:
	"""חישוב רדיוס המסלול הרצוי של הכדור"""
	var planet_radius = planet.planet_radius
	var gravity_radius = planet.gravity_radius
	var ideal_orbit_radius = planet_radius + ((gravity_radius - planet_radius) / 2.0)
	return planet_radius + (ideal_orbit_radius - planet_radius) * ORBIT_RADIUS_FACTOR

static func calculate_orbit_circumference(planet: Planet) -> float:
	"""חישוב היקף המסלול"""
	var orbit_radius = calculate_orbit_radius(planet)
	return 2 * PI * orbit_radius

static func calculate_stabilizer_control(speed: float) -> float:
	"""חישוב כמה שליטה יש למייצב במהירות זו"""
	var speed_penalty = (speed - SPEED_THRESHOLD_LOW) / 200.0
	speed_penalty = clamp(speed_penalty, 0.0, 3.0)
	var control_factor = exp(-speed_penalty * STABILIZER_DECAY_RATE)
	return clamp(control_factor, STABILIZER_MIN_CONTROL, STABILIZER_MAX_CONTROL)

static func calculate_orbit_duration(planet: Planet, velocity: Vector2, spacecraft_pos: Vector2 = Vector2.ZERO) -> float:
	var speed = velocity.length()
	
	# רדיוס המסלול
	var orbit_radius = calculate_orbit_radius(planet)
	
	# היקף המסלול (2πr)
	var orbit_circumference = 2 * PI * orbit_radius
	
	# מהירות במסלול (איטית יותר מכניסה)
	var orbital_speed = speed * 1.2
	
	# זמן = מרחק / מהירות
	var time_for_full_orbit = orbit_circumference / orbital_speed
	
	return time_for_full_orbit
	
static func calculate_orbit_arc_angle(planet: Planet, velocity: Vector2, duration: float) -> float:
	"""חישוב זווית הקשת על בסיס המשך"""
	var speed = velocity.length()
	
	if duration <= 0 or speed <= 0:
		return 0.0
	
	if speed <= SPEED_THRESHOLD_LOW:
		return 360.0  # מסלול מלא
	else:
		# אותו חישוב כמו במשך זמן
		var stabilizer_control = calculate_stabilizer_control(speed)
		var speed_reduction_factor = (speed - SPEED_THRESHOLD_LOW) / SPEED_REDUCTION_RANGE
		speed_reduction_factor = clamp(speed_reduction_factor, 0.0, 1.0)
		
		var base_angle = 360.0 * (1.0 - speed_reduction_factor * SPEED_REDUCTION_MULTIPLIER)
		var final_angle = base_angle * stabilizer_control
		
		return clamp(final_angle, 5.0, 360.0)

# =====================================================
# APPROACH ANGLE CALCULATIONS
# =====================================================

static func calculate_approach_angle(spacecraft_pos: Vector2, spacecraft_velocity: Vector2, planet_pos: Vector2) -> float:
	"""חישוב זווית הגישה (0° = חזיתי, 90° = משיקי)"""
	var to_planet = planet_pos - spacecraft_pos
	var approach_direction = spacecraft_velocity.normalized()
	
	if spacecraft_velocity.length() < 1.0:
		return 0.0
	
	var dot_product = to_planet.normalized().dot(approach_direction)
	var angle_radians = acos(clamp(abs(dot_product), 0.0, 1.0))
	var angle_degrees = rad_to_deg(angle_radians)
	
	return min(angle_degrees, 90.0)

# =====================================================
# FORCE CALCULATIONS
# =====================================================

static func calculate_gravity_force(position: Vector2, planet: Planet, delta: float) -> Vector2:
	"""חישוב כוח הגרביטציה"""
	var to_planet = planet.global_position - position
	var distance = to_planet.length()
	
	if distance < MIN_DISTANCE_FOR_FORCE:
		return Vector2.ZERO
	
	var force_magnitude = planet.gravity_strength * delta * GRAVITY_DELTA_MULTIPLIER / (distance * GRAVITY_DISTANCE_FACTOR)
	return to_planet.normalized() * force_magnitude

static func calculate_collision_prevention(spacecraft_pos: Vector2, distance: float, delta: float, planet: Planet) -> Vector2:
	"""מניעת התנגשות עם פני הכדור"""
	var distance_from_surface = distance - planet.planet_radius
	if distance_from_surface > COLLISION_SAFETY_DISTANCE:
		return Vector2.ZERO
	
	var danger_factor = 1.0 - (distance_from_surface / COLLISION_SAFETY_DISTANCE)
	var push_direction = (spacecraft_pos - planet.global_position).normalized()
	return push_direction * EMERGENCY_FORCE_MULTIPLIER * danger_factor * delta * 60.0

static func calculate_angle_correction(spacecraft_velocity: Vector2, to_planet: Vector2, delta: float) -> Vector2:
	"""תיקון זווית לכיוון משיקי"""
	var velocity = spacecraft_velocity
	var speed = velocity.length()
	
	if speed < MIN_VELOCITY_FOR_ANGLE:
		return Vector2.ZERO
	
	var radial_dir = to_planet.normalized()
	var velocity_dir = velocity.normalized()
	var radial_component = abs(radial_dir.dot(velocity_dir))
	var angle_degrees = rad_to_deg(acos(clamp(1.0 - radial_component, 0.0, 1.0)))
	
	var angle_error = max(0.0, angle_degrees - OPTIMAL_ANGLE_TOLERANCE)
	if angle_error <= 0.0:
		return Vector2.ZERO
	
	var max_error = 90.0 - OPTIMAL_ANGLE_TOLERANCE
	var normalized_error = min(angle_error / max_error, 1.0)
	var correction_intensity = normalized_error * normalized_error
	
	var tangential = Vector2(-radial_dir.y, radial_dir.x)
	if velocity.dot(tangential) < 0:
		tangential = -tangential
	
	var correction = (tangential - velocity_dir).normalized()
	var strength = ANGLE_CORRECTION_STRENGTH * correction_intensity * delta * 60.0
	
	return correction * strength

static func calculate_orbital_magnet(spacecraft_pos: Vector2, distance: float, delta: float, planet: Planet) -> Vector2:
	"""משיכה למסלול האידיאלי"""
	var orbit_radius = calculate_orbit_radius(planet)
	var distance_from_ideal = distance - orbit_radius
	var abs_error = abs(distance_from_ideal)
	
	if abs_error < 2.0 or abs_error > 50.0:
		return Vector2.ZERO
	
	var correction_intensity = min(abs_error / 30.0, 1.0)
	
	var direction = Vector2.ZERO
	if distance_from_ideal > 0:
		direction = (planet.global_position - spacecraft_pos).normalized()
	else:
		direction = (spacecraft_pos - planet.global_position).normalized()
	
	var strength = MAGNET_STRENGTH * correction_intensity * delta * 60.0
	return direction * strength

static func calculate_gentle_speed_boost(spacecraft_velocity: Vector2, entry_speed: float, distance: float, ideal_orbit_radius: float, delta: float) -> Vector2:
	"""דחיפת מהירות עדינה אם המהירות ירדה מדי"""
	var current_velocity = spacecraft_velocity
	var current_speed = current_velocity.length()
	
	# רק אם המהירות ירדה משמעותית
	if current_speed > entry_speed * 0.7 or current_speed < 10.0:
		return Vector2.ZERO
	
	# רק אם במסלול סביר
	if abs(distance - ideal_orbit_radius) > 30.0:
		return Vector2.ZERO
	
	var boost_strength = (entry_speed * 0.7 - current_speed) * 0.1 * delta * 60.0
	boost_strength = min(boost_strength, 8.0)
	
	return current_velocity.normalized() * boost_strength

static func calculate_orbit_simulation_force(position: Vector2, velocity: Vector2, planet: Planet, delta: float) -> Vector2:
	"""כוחות מסלול מלאים לסימולציה"""
	var to_planet = planet.global_position - position
	var distance = to_planet.length()
	
	if distance < 1.0:
		return Vector2.ZERO
	
	# גרביטציה בסיסית
	var gravity_force = calculate_gravity_force(position, planet, delta)
	
	# כוחות הנחיה
	var guidance_force = Vector2.ZERO
	var orbit_radius = calculate_orbit_radius(planet)
	var distance_from_ideal = distance - orbit_radius
	
	# מניעת התנגשות
	var distance_from_surface = distance - planet.planet_radius
	if distance_from_surface <= COLLISION_SAFETY_DISTANCE:
		var danger_factor = 1.0 - (distance_from_surface / COLLISION_SAFETY_DISTANCE)
		var push_direction = (position - planet.global_position).normalized()
		guidance_force += push_direction * EMERGENCY_FORCE_MULTIPLIER * danger_factor * delta * 60.0
	
	# מגנט מסלולי
	if abs(distance_from_ideal) > 2.0 and abs(distance_from_ideal) < 50.0:
		var direction = to_planet.normalized() if distance_from_ideal > 0 else -to_planet.normalized()
		var correction_intensity = min(abs(distance_from_ideal) / 30.0, 1.0)
		guidance_force += direction * MAGNET_STRENGTH * correction_intensity * delta * 60.0
	
	# תיקון זווית
	var speed = velocity.length()
	if speed > MIN_VELOCITY_FOR_ANGLE:
		var radial_dir = to_planet.normalized()
		var velocity_dir = velocity.normalized()
		var radial_component = abs(radial_dir.dot(velocity_dir))
		var angle_degrees = rad_to_deg(acos(clamp(1.0 - radial_component, 0.0, 1.0)))
		var angle_error = max(0.0, angle_degrees - OPTIMAL_ANGLE_TOLERANCE)
		
		if angle_error > 0.0:
			var max_error = 90.0 - OPTIMAL_ANGLE_TOLERANCE
			var normalized_error = min(angle_error / max_error, 1.0)
			var correction_intensity = normalized_error * normalized_error
			
			var tangential = Vector2(-radial_dir.y, radial_dir.x)
			if velocity.dot(tangential) < 0:
				tangential = -tangential
			
			var correction = (tangential - velocity_dir).normalized()
			guidance_force += correction * ANGLE_CORRECTION_STRENGTH * correction_intensity * delta * 60.0
	
	# דעיכה עדינה
	var orbital_damping = velocity * -0.001 * delta * 60.0
	
	return gravity_force + guidance_force + orbital_damping

# =====================================================
# PLANET UTILITIES
# =====================================================

static func find_all_planets(scene_tree: SceneTree) -> Array:
	"""מציאת כל הכדורים בסצנה"""
	var planets = scene_tree.get_nodes_in_group("Planets")
	if planets.size() > 0:
		return planets
	
	# חיפוש רקורסיבי אם אין קבוצה
	var found_planets = []
	var game_scene = scene_tree.current_scene
	if game_scene:
		find_planets_recursive(game_scene, found_planets)
	return found_planets

static func find_planets_recursive(node: Node, planets: Array):
	"""חיפוש רקורסיבי לכדורים"""
	if node.has_method("_on_gravity_zone_body_entered") and "gravity_radius" in node:
		planets.append(node)
	
	for child in node.get_children():
		find_planets_recursive(child, planets)

static func get_planet_at_position(pos: Vector2, planets: Array) -> Planet:
	"""בדיקה אם המיקום בתוך אזור הגרביטציה של כדור"""
	for planet in planets:
		if not planet or not is_instance_valid(planet):
			continue
		var distance = pos.distance_to(planet.global_position)
		if distance <= planet.gravity_radius:
			return planet
	return null

# =====================================================
# GRAVITY BEHAVIOR
# =====================================================

static func get_gravity_behavior_type(gravity_strength: float) -> String:
	"""קביעת סוג ההתנהגות של הכדור על בסיס עוצמת הגרביטציה"""
	if gravity_strength < HELPFUL_GRAVITY_THRESHOLD:
		return "helpful"
	elif gravity_strength <= NORMAL_GRAVITY_THRESHOLD:
		return "normal"
	elif gravity_strength <= CHALLENGING_GRAVITY_THRESHOLD:
		return "challenging"
	else:
		return "evil"

static func get_prevention_multiplier(gravity_strength: float) -> float:
	"""חישוב כמה מניעת התנגשות הכדור מספק"""
	var behavior = get_gravity_behavior_type(gravity_strength)
	
	match behavior:
		"helpful":
			return 2.0
		"normal":
			return 1.0
		"challenging":
			return 0.3
		"evil":
			return -0.5
		_:
			return 1.0

static func calculate_gravity_color(gravity_strength: float) -> Color:
	"""חישוב צבע על בסיס עוצמת הגרביטציה"""
	var normalized_gravity = 0.0
	
	if gravity_strength <= HELPFUL_GRAVITY_THRESHOLD:
		normalized_gravity = 0.0
	elif gravity_strength >= CHALLENGING_GRAVITY_THRESHOLD:
		normalized_gravity = 1.0
	else:
		var range = CHALLENGING_GRAVITY_THRESHOLD - HELPFUL_GRAVITY_THRESHOLD
		var position_in_range = gravity_strength - HELPFUL_GRAVITY_THRESHOLD
		normalized_gravity = position_in_range / range
	
	var result_color: Color
	if normalized_gravity <= 0.5:
		var orange_color = Color(1.0, 0.5, 0.0)
		var t = normalized_gravity * 2.0
		result_color = Color.WHITE.lerp(orange_color, t)
	else:
		var orange_color = Color(1.0, 0.5, 0.0)
		var t = (normalized_gravity - 0.5) * 2.0
		result_color = orange_color.lerp(Color.RED, t)
	
	result_color.a = 0.2
	return result_color
