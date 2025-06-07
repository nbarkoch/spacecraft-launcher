extends Node2D
class_name TrajectoryPredictor

# Configuration
@export var max_prediction_time: float = 4.0
@export var line_width: float = 3.0
@export var normal_color: Color = Color(1.0, 1.0, 1.0, 0.4)
@export var gravity_color: Color = Color(0.3, 0.7, 1.0, 0.6)
@export var collision_color: Color = Color(1.0, 0.2, 0.2, 0.9)

# Smooth transition properties
@export var transition_speed: float = 8.0
@export var point_interpolation_rate: float = 15.0

# Internal variables
var trajectory_line: Line2D
var is_predicting: bool = false

# Trajectory interpolation
var current_trajectory_points: Array = []
var target_trajectory_points: Array = []
var trajectory_colors: Array = []

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
	
	if current_trajectory_points.size() == 0:
		current_trajectory_points.append(target_trajectory_points[0])
		trajectory_colors.append(normal_color)
	
	var interpolation_speed = point_interpolation_rate * delta
	
	adjust_points_count()
	
	for i in range(min(current_trajectory_points.size(), target_trajectory_points.size())):
		current_trajectory_points[i] = current_trajectory_points[i].lerp(target_trajectory_points[i], interpolation_speed)
		
		if i < trajectory_colors.size():
			trajectory_colors[i] = trajectory_colors[i].lerp(get_target_color_for_point(i), interpolation_speed * 2.0)
	
	update_line_display()

func adjust_points_count():
	"""Adjust the number of current points to match target points"""
	var current_count = current_trajectory_points.size()
	var target_count = target_trajectory_points.size()
	
	if target_count > current_count:
		var last_point = current_trajectory_points[-1] if current_count > 0 else Vector2.ZERO
		
		for i in range(current_count, target_count):
			current_trajectory_points.append(last_point)
			trajectory_colors.append(normal_color)
	
	elif target_count < current_count:
		var points_to_remove = current_count - target_count
		for i in range(points_to_remove):
			if current_trajectory_points.size() > target_count:
				current_trajectory_points.pop_back()
				trajectory_colors.pop_back()

func get_target_color_for_point(point_index: int) -> Color:
	"""Get the target color for a specific point based on game state"""
	return normal_color

func update_line_display():
	"""Update the Line2D with current interpolated points"""
	trajectory_line.clear_points()
	
	for point in current_trajectory_points:
		trajectory_line.add_point(point)
	
	if trajectory_colors.size() > 0:
		trajectory_line.default_color = trajectory_colors[0]

func show_trajectory():
	"""Show trajectory prediction"""
	visible = true
	is_predicting = true

func hide_trajectory():
	"""Hide trajectory prediction"""
	visible = false
	is_predicting = false
	
	current_trajectory_points.clear()
	target_trajectory_points.clear()
	trajectory_colors.clear()
	
	if trajectory_line:
		trajectory_line.clear_points()

func update_prediction(start_position: Vector2, initial_velocity: Vector2):
	"""Update prediction in real-time with smooth transitions"""
	if is_predicting:
		predict_trajectory(start_position, initial_velocity)

# בתוך trajectory_predictor.gd - החלק של predict_trajectory:

func predict_trajectory(start_position: Vector2, initial_velocity: Vector2):
	"""חישוב מסלול באמצעות PhysicsUtils"""
	var new_points = []
	
	var max_steps = min(int(max_prediction_time / PhysicsUtils.TRAJECTORY_TIME_STEP), PhysicsUtils.MAX_TRAJECTORY_STEPS)
	
	# מצב סימולציה
	var position = start_position
	var velocity = initial_velocity
	var in_gravity_zone: Planet = null
	var gravity_entry_time = 0.0
	var expected_orbit_duration = 0.0
	var orbit_entry_velocity: Vector2 = Vector2.ZERO
	var predicted_arc_angle = 0.0
	
	# קבל את כל הכדורים
	var planets = PhysicsUtils.find_all_planets(get_tree())
	
	# סימולציה של המסלול
	for step in range(max_steps):
		var sim_time = step * PhysicsUtils.TRAJECTORY_TIME_STEP
		
		# הוסף נקודת מסלול כל כמה צעדים
		if step % PhysicsUtils.TRAJECTORY_POINT_INTERVAL == 0:
			new_points.append(to_local(position))
		
		# הפעל דעיכת מהירות ריאליסטית (זהה לחללית)
		velocity *= PhysicsUtils.VELOCITY_DAMPING_PER_FRAME
		
		# בדוק אם נכנס/יוצא מאזורי גרביטציה
		var current_planet = PhysicsUtils.get_planet_at_position(position, planets)
		
		if current_planet != in_gravity_zone:
			if current_planet:
				# נכנס לאזור גרביטציה חדש
				in_gravity_zone = current_planet
				gravity_entry_time = sim_time
				
				# חזה מהירות אמיתית כשהחללית מגיעה לאזור הגרביטציה
				orbit_entry_velocity = velocity * 0.9  # קירוב
				
				# השתמש בפונקציות PhysicsUtils עם התחשבות בזווית הגישה
				var predicted_duration = PhysicsUtils.calculate_orbit_duration(current_planet, orbit_entry_velocity, position)
				predicted_arc_angle = PhysicsUtils.calculate_orbit_arc_angle(current_planet, orbit_entry_velocity, predicted_duration)
				
				if predicted_duration > 0:
					expected_orbit_duration = predicted_duration
			else:
				# יוצא מאזור גרביטציה
				in_gravity_zone = null
		
		# הפעל כוחות מתאימים
		if in_gravity_zone:
			# בדוק אם צריך לצאת על בסיס משך חזוי
			var time_in_gravity = sim_time - gravity_entry_time
			if time_in_gravity >= expected_orbit_duration:
				# כפה יציאה מגרביטציה
				in_gravity_zone = null
			else:
				# הפעל כוחות גרביטציה + ייצוב מסלול
				var orbit_force = PhysicsUtils.calculate_orbit_simulation_force(position, velocity, in_gravity_zone, PhysicsUtils.TRAJECTORY_TIME_STEP)
				velocity += orbit_force
		else:
			# סימולציית גרביטציה רגילה מחוץ למסלול
			var total_gravity_force = Vector2.ZERO
			for planet in planets:
				if not planet or not is_instance_valid(planet):
					continue
				
				var distance_to_planet = position.distance_to(planet.global_position)
				if distance_to_planet <= planet.gravity_radius:
					var force = PhysicsUtils.calculate_gravity_force(position, planet, PhysicsUtils.TRAJECTORY_TIME_STEP)
					total_gravity_force += force
			
			velocity += total_gravity_force
		
		# הזז מיקום
		position += velocity * PhysicsUtils.TRAJECTORY_TIME_STEP
		
		# בדוק התנגשות עם כדור
		var collision_detected = false
		for planet in planets:
			if not planet or not is_instance_valid(planet):
				continue
			
			var distance_center_to_center = position.distance_to(planet.global_position)
			if distance_center_to_center <= (planet.planet_radius + PhysicsUtils.SPACECRAFT_COLLISION_RADIUS):
				collision_detected = true
				break
		
		if collision_detected:
			break
		
		# בדיקת גבולות
		if abs(position.x) > PhysicsUtils.MAX_SIMULATION_BOUNDS or abs(position.y) > PhysicsUtils.MAX_SIMULATION_BOUNDS:
			break
		
		# בדיקת מגבלת מהירות
		if velocity.length() > PhysicsUtils.MAX_VELOCITY_LIMIT:
			break
	
	# עדכן נקודות מסלול יעד
	target_trajectory_points = new_points
