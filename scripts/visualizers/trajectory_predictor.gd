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
	"""Update prediction using COMPLETE PHYSICS SIMULATION"""
	if is_predicting:
		predict_trajectory_complete(start_position, initial_velocity)

func predict_trajectory_complete(start_position: Vector2, initial_velocity: Vector2):
	"""חיזוי מלא עם כל האינטראקציות - מטאורים, פורטלים, חורים שחורים"""
	var new_points = []
	var position = start_position
	var velocity = initial_velocity
	var time = 0.0
	var step_count = 0
	var is_alive = true
	var current_gravity_assist = null
	var gravity_assist_time = 0.0
	
	# קבועים
	var physics_fps = 60.0
	var delta = 1.0 / physics_fps
	var damping = 0.999
	
	# איסוף כל האובייקטים
	var planets = get_tree().get_nodes_in_group("Planets")
	var meteoroids = collect_meteoroids()
	var portals = collect_portals()
	var black_holes = collect_black_holes()
	
	while time < max_prediction_time and is_alive:
		# הוסף נקודה
		if step_count % 2 == 0:
			new_points.append(to_local(position))
		
		# בדוק גבולות - בדיוק כמו בחללית!
		if abs(position.x) > 200.0 or abs(position.y) > 400.0:
			break
		
		# חשב כוחות מכל המקורות
		var total_force = Vector2.ZERO
		
		# 1. כוחי כבידה עם gravity assist
		var gravity_result = calculate_gravity_forces(position, velocity, planets, current_gravity_assist, gravity_assist_time, delta)
		total_force += gravity_result.force
		current_gravity_assist = gravity_result.current_assist
		gravity_assist_time = gravity_result.assist_time
		
		# בדוק התנגשות עם כוכבי לכת
		if check_planet_collision(position, planets):
			is_alive = false
			break
		
		# 2. אינטראקציה עם מטאורים
		var meteroid_result = calculate_meteroid_interactions(position, velocity, meteoroids, delta)
		total_force += meteroid_result.force
		
		# 3. בדוק פורטלים
		var portal_result = check_portal_teleportation(position, portals)
		if portal_result.teleported:
			position = portal_result.new_position
		
		# 4. חורים שחורים
		var blackhole_result = calculate_blackhole_forces(position, velocity, black_holes, delta)
		total_force += blackhole_result.force
		if not blackhole_result.is_alive:
			is_alive = false
			break
		
		# עדכן פיזיקה
		velocity *= damping
		velocity += total_force
		position += velocity * delta
		
		# בדוק גבולות אחרי העדכון גם
		if abs(position.x) > 200.0 or abs(position.y) > 400.0:
			break
		
		time += delta
		step_count += 1
		gravity_assist_time += delta
		
		if step_count > 300:
			break
	
	target_trajectory_points = new_points

# פונקציות עזר לחישובי פיזיקה מלאים

func collect_meteoroids() -> Array:
	return get_tree().get_nodes_in_group("Meteoroids")

func collect_portals() -> Array:
	return get_tree().get_nodes_in_group("Portals")

func collect_black_holes() -> Array:
	return get_tree().get_nodes_in_group("BlackHoles")

func calculate_gravity_forces(pos: Vector2, vel: Vector2, planets: Array, current_assist, assist_time: float, delta: float) -> Dictionary:
	var result = {"force": Vector2.ZERO, "current_assist": current_assist, "assist_time": assist_time}
	
	for planet in planets:
		if not planet or not is_instance_valid(planet):
			continue
		
		var distance = pos.distance_to(planet.global_position)
		if distance <= planet.gravity_radius and distance > 1.0:
			var to_planet = planet.global_position - pos
			
			# כוח כבידה בסיסי
			var base_force_magnitude = (planet.gravity_strength * delta * 60.0) / (distance * 0.01)
			var base_force = to_planet.normalized() * base_force_magnitude
			
			# gravity assist logic
			if current_assist == planet:
				# המשך gravity assist
				var orbital_direction = Vector2(-to_planet.y, to_planet.x).normalized()
				var assist_strength = 50.0 * (1.0 + assist_time * 0.5)
				var assist_force = orbital_direction * assist_strength * delta
				result.force = base_force + assist_force
				result.assist_time = assist_time
				
				# סיום gravity assist - בדיוק כמו בחללית
				if assist_time > 2.0 or distance > planet.gravity_radius * 0.8:
					result.current_assist = null
					result.assist_time = 0.0
			else:
				# בדוק התחלת gravity assist - בדיוק כמו בחללית
				var tangential_velocity = calculate_tangential_velocity_for_planet(pos, vel, planet)
				if distance <= planet.gravity_radius * 0.6 and tangential_velocity > 50.0:
					result.current_assist = planet
					result.assist_time = 0.0
				
				result.force = base_force
			
			break
	
	return result

func calculate_tangential_velocity_for_planet(pos: Vector2, vel: Vector2, planet) -> float:
	var to_planet = planet.global_position - pos
	var radial_direction = to_planet.normalized()
	var velocity_direction = vel.normalized() if vel.length() > 0 else Vector2.ZERO
	var dot_product = radial_direction.dot(velocity_direction)
	var tangential_component = sqrt(max(0, 1.0 - dot_product * dot_product))
	return tangential_component * vel.length()

func check_planet_collision(pos: Vector2, planets: Array) -> bool:
	for planet in planets:
		if not planet or not is_instance_valid(planet):
			continue
		var distance = pos.distance_to(planet.global_position)
		if distance <= (planet.planet_radius + 6.0):
			return true
	return false

func calculate_meteroid_interactions(pos: Vector2, vel: Vector2, meteoroids: Array, delta: float) -> Dictionary:
	var result = {"force": Vector2.ZERO}
	
	for meteroid in meteoroids:
		if not meteroid or not is_instance_valid(meteroid):
			continue
		
		# חישוב התנגשות - בדיוק כמו בחללית!
		var distance = pos.distance_to(meteroid.global_position)
		if distance <= (13.0 + 6.0):  # התנגשות
			var collision_direction = (pos - meteroid.global_position).normalized()
			
			# השתמש במסה שלנו של המטאור
			var spacecraft_mass = 1.0
			var meteroid_mass_actual = meteroid.meteroid_physics_mass  # המסה שלנו
			var momentum_transfer = (2.0 * meteroid_mass_actual) / (spacecraft_mass + meteroid_mass_actual)
			var collision_strength = 200.0 * momentum_transfer
			
			result.force += collision_direction * collision_strength
			break
	
	return result

func check_portal_teleportation(pos: Vector2, portals: Array) -> Dictionary:
	var result = {"teleported": false, "new_position": pos}
	
	for portal in portals:
		if not portal or not is_instance_valid(portal):
			continue
		
		var distance = pos.distance_to(portal.global_position)
		if distance <= 13.0:
			var target_portal = find_target_portal(portal, portals)
			if target_portal:
				result.teleported = true
				result.new_position = target_portal.global_position
			break
	
	return result

func find_target_portal(source_portal, all_portals: Array):
	var portal_group = source_portal.portal_group if "portal_group" in source_portal else "portal1"
	for portal in all_portals:
		if portal != source_portal and portal.portal_group == portal_group:
			return portal
	return null

func calculate_blackhole_forces(pos: Vector2, vel: Vector2, black_holes: Array, delta: float) -> Dictionary:
	var result = {"force": Vector2.ZERO, "is_alive": true}
	
	for black_hole in black_holes:
		if not black_hole or not is_instance_valid(black_hole):
			continue
		
		var distance = pos.distance_to(black_hole.global_position)
		
		if distance <= 10.0:  # נפילה לחור
			result.is_alive = false
			return result
		
		if distance <= black_hole.gravity_radius:
			var to_blackhole = black_hole.global_position - pos
			var blackhole_force = (black_hole.gravity_strength * 2.0) / distance
			result.force += to_blackhole.normalized() * blackhole_force * delta
			
			# עצירת בריחה
			var velocity_toward = vel.dot(to_blackhole.normalized())
			if velocity_toward < 0:
				result.force += -vel * 0.1
			
			break
	
	return result

# Keep the old prediction method as fallback
func predict_trajectory(start_position: Vector2, initial_velocity: Vector2):
	"""OLD METHOD - kept for compatibility"""
	predict_trajectory_complete(start_position, initial_velocity)
