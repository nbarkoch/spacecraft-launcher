extends Node2D
class_name TrajectoryPredictor

# Configuration
@export var max_prediction_time: float = 4.0
@export var line_width: float = 3.0
@export var normal_color: Color = Color(1.0, 1.0, 1.0, 0.4)
@export var gravity_color: Color = Color(0.3, 0.7, 1.0, 0.6)
@export var collision_color: Color = Color(1.0, 0.2, 0.2, 0.9)

# Smooth transition properties
@export var transition_speed: float = 8.0  # כמה מהר הקו "זוחל" למקום החדש
@export var point_interpolation_rate: float = 15.0  # כמה מהר כל נקודה עוקבת אחרי המטרה

# Spacecraft properties
@export var spacecraft_collision_radius: float = 6.0

# Internal variables
var trajectory_line: Line2D
var is_predicting: bool = false

# Trajectory interpolation
var current_trajectory_points: Array = []  # הנקודות הנוכחיות המוצגות
var target_trajectory_points: Array = []   # הנקודות החדשות שאליהן אנחנו רוצים להגיע
var trajectory_colors: Array = []          # צבעים לכל נקודה

func _ready():
	create_trajectory_line()

func _process(delta):
	if is_predicting:
		interpolate_trajectory_points(delta)

func create_trajectory_line():
	"""Create Line2D for trajectory visualization"""
	trajectory_line = Line2D.new()
	add_child(trajectory_line)
	trajectory_line.width = line_width
	trajectory_line.default_color = normal_color
	trajectory_line.antialiased = true

func interpolate_trajectory_points(delta):
	"""Smooth interpolation between current and target trajectory points"""
	if target_trajectory_points.size() == 0:
		return
	
	# אם אין נקודות נוכחיות, התחל עם הראשונה
	if current_trajectory_points.size() == 0:
		current_trajectory_points.append(target_trajectory_points[0])
		trajectory_colors.append(normal_color)
	
	var interpolation_speed = point_interpolation_rate * delta
	
	# הוסף או הסר נקודות לפי הצורך
	adjust_points_count()
	
	# עדכן כל נקודה בצורה חלקה
	for i in range(min(current_trajectory_points.size(), target_trajectory_points.size())):
		# החלק את המיקום
		current_trajectory_points[i] = current_trajectory_points[i].lerp(target_trajectory_points[i], interpolation_speed)
		
		# החלק את הצבע אם יש
		if i < trajectory_colors.size():
			trajectory_colors[i] = trajectory_colors[i].lerp(get_target_color_for_point(i), interpolation_speed * 2.0)
	
	update_line_display()

func adjust_points_count():
	"""Adjust the number of current points to match target points"""
	var current_count = current_trajectory_points.size()
	var target_count = target_trajectory_points.size()
	
	if target_count > current_count:
		# הוסף נקודות חדשות - התחל מהנקודה האחרונה הקיימת
		var last_point = current_trajectory_points[-1] if current_count > 0 else Vector2.ZERO
		
		for i in range(current_count, target_count):
			current_trajectory_points.append(last_point)
			trajectory_colors.append(normal_color)
	
	elif target_count < current_count:
		# הסר נקודות עודפות בהדרגה מהסוף
		var points_to_remove = current_count - target_count
		for i in range(points_to_remove):
			if current_trajectory_points.size() > target_count:
				current_trajectory_points.pop_back()
				trajectory_colors.pop_back()

func get_target_color_for_point(point_index: int) -> Color:
	"""Get the target color for a specific point based on game state"""
	# כאן תוכל להוסיף לוגיקה מורכבת יותר לצבעים
	# לעת עתה פשוט נחזיר צבע בסיסי
	return normal_color

func update_line_display():
	"""Update the Line2D with current interpolated points"""
	trajectory_line.clear_points()
	
	# הוסף את כל הנקודות הנוכחיות
	for point in current_trajectory_points:
		trajectory_line.add_point(point)
	
	# עדכן צבע - נשתמש בצבע הממוצע או בצבע של הנקודה הראשונה
	if trajectory_colors.size() > 0:
		trajectory_line.default_color = trajectory_colors[0]

func calculate_gravity_force(position: Vector2, planet: Planet, delta: float) -> Vector2:
	"""Calculate gravity force exactly like orbit_config.gd"""
	var to_planet = planet.global_position - position
	var distance = to_planet.length()
	
	if distance < 1.0:
		return Vector2.ZERO
	
	# EXACT formula from orbit_config.gd
	var force_magnitude = planet.gravity_strength * delta * 60.0 / (distance * 0.01)
	var force_direction = to_planet.normalized()
	return force_direction * force_magnitude

func find_all_planets() -> Array:
	"""Find all Planet nodes in the scene"""
	var planets = []
	
	# Use group method first
	var grouped_planets = get_tree().get_nodes_in_group("Planets")
	if grouped_planets.size() > 0:
		return grouped_planets
	
	# Fallback search
	var game_scene = get_tree().current_scene
	if game_scene:
		find_planets_recursive(game_scene, planets)
	
	return planets

func find_planets_recursive(node: Node, planets: Array):
	"""Recursively search for Planet nodes"""
	if node.has_method("_on_gravity_zone_body_entered") and node.has_method("_on_planet_area_body_entered"):
		if "gravity_radius" in node and "planet_radius" in node and "gravity_strength" in node:
			planets.append(node)
	
	for child in node.get_children():
		find_planets_recursive(child, planets)

func show_trajectory():
	"""Show trajectory prediction"""
	visible = true
	is_predicting = true

func hide_trajectory():
	"""Hide trajectory prediction"""
	visible = false
	is_predicting = false
	
	# נקה את הנקודות
	current_trajectory_points.clear()
	target_trajectory_points.clear()
	trajectory_colors.clear()
	
	if trajectory_line:
		trajectory_line.clear_points()

func update_prediction(start_position: Vector2, initial_velocity: Vector2):
	"""Update prediction in real-time with smooth transitions"""
	if is_predicting:
		predict_trajectory(start_position, initial_velocity)

func predict_trajectory(start_position: Vector2, initial_velocity: Vector2):
	"""Calculate trajectory with REALISTIC velocity degradation and orbit simulation"""
	var new_points = []
	
	var time_step = 1.0 / 60.0
	var max_steps = min(int(max_prediction_time / time_step), 120)
	
	# Simulation state
	var position = start_position
	var velocity = initial_velocity
	var in_gravity_zone: Planet = null
	var gravity_entry_time = 0.0
	var expected_orbit_duration = 0.0
	var orbit_entry_velocity: Vector2 = Vector2.ZERO
	
	# Get all planets
	var planets = find_all_planets()
	
	# Simulate trajectory
	for step in range(max_steps):
		var sim_time = step * time_step
		
		# Add trajectory point every few steps
		if step % 2 == 0:
			new_points.append(to_local(position))
		
		# Apply realistic velocity damping (same as spacecraft)
		velocity *= 0.999  # Very slight damping per frame
		
		# Check if entering/exiting gravity zones
		var current_planet = get_planet_at_position(position, planets)
		
		if current_planet != in_gravity_zone:
			if current_planet:
				# Entering new gravity zone
				in_gravity_zone = current_planet
				gravity_entry_time = sim_time
				
				# Predict ACTUAL velocity when spacecraft reaches gravity zone
				# Simple factor - spacecraft loses about 20% of speed by the time it reaches gravity zone
				orbit_entry_velocity = velocity * 0.96
				
				expected_orbit_duration = calculate_orbit_duration_like_config(orbit_entry_velocity, current_planet)
			else:
				# Exiting gravity zone
				in_gravity_zone = null
		
		# Apply appropriate forces
		if in_gravity_zone:
			# Check if should exit based on time
			var time_in_gravity = sim_time - gravity_entry_time
			if time_in_gravity >= expected_orbit_duration:
				# Force exit from gravity
				in_gravity_zone = null
			else:
				# Apply gravity + orbit stabilization forces
				var orbit_force = calculate_orbit_simulation_force(position, velocity, in_gravity_zone, time_step)
				velocity += orbit_force
		else:
			# Normal gravity simulation outside orbit
			var total_gravity_force = Vector2.ZERO
			for planet in planets:
				if not planet or not is_instance_valid(planet):
					continue
				
				var distance_to_planet = position.distance_to(planet.global_position)
				if distance_to_planet <= planet.gravity_radius:
					var force = calculate_gravity_force(position, planet, time_step)
					total_gravity_force += force
			
			velocity += total_gravity_force
		
		# Move position
		position += velocity * time_step
		
		# Check for planet collision
		var collision_detected = false
		for planet in planets:
			if not planet or not is_instance_valid(planet):
				continue
			
			var distance_center_to_center = position.distance_to(planet.global_position)
			if distance_center_to_center <= (planet.planet_radius + spacecraft_collision_radius):
				collision_detected = true
				break
		
		if collision_detected:
			break
		
		# Bounds check
		if abs(position.x) > 1000 or abs(position.y) > 1000:
			break
		
		# Velocity limit check
		if velocity.length() > 3000:
			break
	
	# Update target trajectory points
	target_trajectory_points = new_points

func calculate_orbit_duration_like_config(velocity: Vector2, planet: Planet) -> float:
	"""Calculate orbit duration using EXACT same logic as NEW orbit_config"""
	var speed = velocity.length()
	
	# Calculate orbit radius
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
		var stabilizer_control = calculate_stabilizer_control_predictor(speed)
		
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

func calculate_stabilizer_control_predictor(speed: float) -> float:
	"""Calculate how much control the stabilizer has at this speed"""
	var base_control = 1.0
	var speed_penalty = (speed - 50.0) / 200.0  # Normalize speed above 50
	speed_penalty = clamp(speed_penalty, 0.0, 3.0)
	
	# Exponential decay of control
	var control_factor = base_control * exp(-speed_penalty * 1.2)
	
	return clamp(control_factor, 0.1, 0.95)

func calculate_orbit_simulation_force(position: Vector2, velocity: Vector2, planet: Planet, delta: float) -> Vector2:
	"""Orbit forces that match the REAL spacecraft behavior more closely"""
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
	
	# Orbital magnet (similar to real GravityAssist)
	if abs(distance_from_ideal) > 2.0 and abs(distance_from_ideal) < 50.0:
		var direction = Vector2.ZERO
		if distance_from_ideal > 0:
			direction = to_planet.normalized()
		else:
			direction = -to_planet.normalized()
		
		var correction_intensity = min(abs(distance_from_ideal) / 30.0, 1.0)
		var force_strength = correction_intensity * 1.0 * delta * 60.0  # Reduced from 30.0
		guidance_force += direction * force_strength
	
	# Angle correction (similar to real GravityAssist)
	var speed = velocity.length()
	if speed > 20.0:
		var radial_dir = to_planet.normalized()
		var velocity_dir = velocity.normalized()
		var radial_component = abs(radial_dir.dot(velocity_dir))
		var angle_degrees = rad_to_deg(acos(clamp(1.0 - radial_component, 0.0, 1.0)))
		
		var optimal_angle_tolerance = 7.0
		var angle_error = max(0.0, angle_degrees - optimal_angle_tolerance)
		
		if angle_error > 0.0:
			var max_error = 90.0 - optimal_angle_tolerance
			var normalized_error = min(angle_error / max_error, 1.0)
			var correction_intensity = normalized_error * normalized_error
			
			var tangential = Vector2(-radial_dir.y, radial_dir.x)
			if velocity.dot(tangential) < 0:
				tangential = -tangential
			
			var correction = (tangential - velocity_dir).normalized()
			var strength = 15.0 * correction_intensity * delta * 60.0  # Match real angle_correction_strength
			guidance_force += correction * strength
	
	# Apply realistic damping during orbit (like real spacecraft)
	var orbital_damping = velocity * -0.001 * delta * 60.0  # Very light damping
	
	return gravity_vector + guidance_force + orbital_damping
	
func get_planet_at_position(pos: Vector2, planets: Array) -> Planet:
	"""Check if position is within any planet's gravity zone"""
	for planet in planets:
		if not planet or not is_instance_valid(planet):
			continue
		
		var distance = pos.distance_to(planet.global_position)
		if distance <= planet.gravity_radius:
			return planet
	return null
