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
	
func predict_trajectory(start_position: Vector2, initial_velocity: Vector2):
	"""Calculate new target trajectory points"""
	var new_points = []
	
	var time_step = 1.0 / 60.0
	var max_steps = min(int(max_prediction_time / time_step), 120)
	
	# Simulation state
	var position = start_position
	var velocity = initial_velocity
	
	# Get all planets
	var planets = find_all_planets()
	
	# Simulate with higher precision
	for step in range(max_steps):
		# Add trajectory point every few steps for performance
		if step % 2 == 0:  # Sample every 2 steps for smoother line
			new_points.append(to_local(position))
		
		# Calculate gravity forces from all planets in range
		var total_gravity_force = Vector2.ZERO
		for planet in planets:
			if not planet or not is_instance_valid(planet):
				continue
			
			var distance_to_planet = position.distance_to(planet.global_position)
			if distance_to_planet <= planet.gravity_radius:
				var force = calculate_gravity_force(position, planet, time_step)
				total_gravity_force += force
		
		# Apply gravity forces
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
	
	# עדכן את נקודות המטרה
	target_trajectory_points = new_points

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
