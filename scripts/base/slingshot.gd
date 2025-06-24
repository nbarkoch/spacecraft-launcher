extends Node2D

class_name SlingShot

enum SlingshotState {
	idle,
	pulling,
	released,
	reset
}

# Properties
var slingshotState
var leftLine
var rightLine
var spacecraft: Spacecraft = null
var trajectory_predictor: TrajectoryPredictor  # החיזוי המלא החדש
const MULTIPLIER = 4

# Snap system
const ANGLE_SNAP_INTERVAL = 22.5
const DISTANCE_SNAP_INTERVAL = 15.0
const SNAP_RADIUS = 12.0
const SNAP_STRENGTH = 0.2

@onready var slingshot_center: Marker2D = $SlingshotCenter

var target_mouse_pos = Vector2.ZERO
const TRANSITION_SPEED = 12.0

var all_planets: Array = []
var max_display_distance: float = 400.0

func _ready():
	slingshotState = SlingshotState.idle
	leftLine = $LeftLine
	rightLine = $RightLine
	
	# צור חיזוי מסלול מדויק ומלא
	trajectory_predictor = TrajectoryPredictor.new()
	add_child(trajectory_predictor)
	trajectory_predictor.hide_trajectory()
	
	await get_tree().process_frame
	find_all_planets()
	if not spacecraft or not is_instance_valid(spacecraft):
		var spacecrafts = get_tree().get_nodes_in_group("Spacecrafts")
		if spacecrafts.size() > 0:
			spacecraft = spacecrafts[0] as Spacecraft
			reset()

func find_all_planets():
	"""Find and store references to all planets in the scene"""
	all_planets.clear()
	var planets = get_tree().get_nodes_in_group("Planets")
	
	for planet in planets:
		if planet is Planet:
			all_planets.append(planet)

func _process(delta):
	match slingshotState:
		SlingshotState.idle:
			hide_all_planet_arcs()
			
		SlingshotState.pulling:
			if Input.is_action_pressed("FINGER_TAP"):
				var mouse_pos = get_global_mouse_position()
				var center_pos = slingshot_center.global_position
				
				# Apply constraints
				var constrained_mouse_pos = mouse_pos
				constrained_mouse_pos.x = min(center_pos.x+60, max(center_pos.x-60, constrained_mouse_pos.x))
				constrained_mouse_pos.y = min(center_pos.y+60, max(center_pos.y+10, constrained_mouse_pos.y))
				
				if constrained_mouse_pos.distance_to(center_pos) > 100:
					constrained_mouse_pos = (constrained_mouse_pos - center_pos).normalized() * 100 + center_pos
				
				# Apply snap
				target_mouse_pos = apply_subtle_snap(constrained_mouse_pos, center_pos)
				var current_mouse_pos = target_mouse_pos
				
				# Update visuals
				leftLine.points[0] = leftLine.to_local(current_mouse_pos)
				rightLine.points[0] = rightLine.to_local(current_mouse_pos)
				spacecraft.global_position = current_mouse_pos
				
				# Update rotation
				var launch_direction = center_pos - current_mouse_pos
				if launch_direction.length() > 0:
					spacecraft.rotation = launch_direction.angle() + PI/2
				
				# Calculate velocity
				var velocity = (center_pos - current_mouse_pos) * MULTIPLIER
				
				# עדכן חיזוי מדויק - זה החלק החשוב!
				trajectory_predictor.show_trajectory()
				trajectory_predictor.update_prediction(current_mouse_pos, velocity)
				
				update_planet_arcs(velocity)
				
			if Input.is_action_just_released("FINGER_TAP"):
				var center_pos = slingshot_center.global_position
				var final_mouse_pos = target_mouse_pos
				
				slingshotState = SlingshotState.released
				
				trajectory_predictor.hide_trajectory()
				hide_all_planet_arcs()
				
				var velocity = (center_pos - final_mouse_pos) * MULTIPLIER
				
				# שחרר חללית עם פיזיקה מדויקת
				spacecraft.linear_velocity = Vector2.ZERO
				spacecraft.angular_velocity = 0.0
				spacecraft.gravity_assist = null
				spacecraft.freeze = true
				spacecraft.release()
				Input.vibrate_handheld(10)
				
				var launch_direction = center_pos - final_mouse_pos
				var s_rotation = launch_direction.angle() + PI/2
				spacecraft.reset(s_rotation, center_pos)
				
				await get_tree().process_frame
				
				# השתמש בפונקציה החדשה עם פיזיקה מדויקת
				spacecraft.apply_impulse_predictable(velocity)
				
				GameManager.currentState = GameManager.GameState.action
				
		SlingshotState.released:
			leftLine.points[0] = leftLine.to_local(slingshot_center.global_position)
			rightLine.points[0] = rightLine.to_local(slingshot_center.global_position)
			
			hide_all_planet_arcs()
			if not spacecraft or not is_instance_valid(spacecraft):
				slingshotState = SlingshotState.idle
				GameManager.currentState = GameManager.GameState.idle
				
		SlingshotState.reset:
			pass

func hide_all_planet_arcs():
	"""Hide arc visualization on all planets"""
	for planet in all_planets:
		if planet and is_instance_valid(planet) and planet.gravity_visualizer:
			planet.gravity_visualizer.hide_orbit_prediction()

func apply_subtle_snap(mouse_pos: Vector2, center_pos: Vector2) -> Vector2:
	"""הפעל snap עדין על המיקום"""
	var pull_vector = mouse_pos - center_pos
	
	if pull_vector.length() < 5.0:
		return mouse_pos
	
	var current_angle = pull_vector.angle()
	var snapped_angle = apply_angle_snap(current_angle)
	
	var current_distance = pull_vector.length()
	var snapped_distance = apply_distance_snap(current_distance)
	
	var snapped_vector = Vector2(cos(snapped_angle), sin(snapped_angle)) * snapped_distance
	var snapped_pos = center_pos + snapped_vector
	
	return snapped_pos

func apply_angle_snap(angle: float) -> float:
	"""הפעל snap עדין על זווית"""
	var angle_degrees = rad_to_deg(angle)
	var nearest_snap = round(angle_degrees / ANGLE_SNAP_INTERVAL) * ANGLE_SNAP_INTERVAL
	var distance_to_snap = abs(angle_degrees - nearest_snap)
	
	if distance_to_snap > 180:
		distance_to_snap = 360 - distance_to_snap
	
	var snap_threshold = ANGLE_SNAP_INTERVAL * 0.4
	if distance_to_snap <= snap_threshold:
		var snap_factor = 1.0 - (distance_to_snap / snap_threshold)
		snap_factor = snap_factor * SNAP_STRENGTH
		
		if abs(angle_degrees - nearest_snap) > 180:
			if angle_degrees > nearest_snap:
				nearest_snap += 360
			else:
				nearest_snap -= 360
		
		angle_degrees = lerp(angle_degrees, nearest_snap, snap_factor)
	
	return deg_to_rad(angle_degrees)

func apply_distance_snap(distance: float) -> float:
	"""הפעל snap עדין על מרחק"""
	var nearest_snap = round(distance / DISTANCE_SNAP_INTERVAL) * DISTANCE_SNAP_INTERVAL
	var distance_to_snap = abs(distance - nearest_snap)
	
	if distance_to_snap <= SNAP_RADIUS:
		var snap_factor = 1.0 - (distance_to_snap / SNAP_RADIUS)
		snap_factor = snap_factor * SNAP_STRENGTH
		distance = lerp(distance, nearest_snap, snap_factor)
	
	return distance

func _on_touch_area_input_event(viewport, event, shape_idx):
	if slingshotState == SlingshotState.idle and Input.is_action_pressed("FINGER_TAP"):
		if spacecraft:
			slingshotState = SlingshotState.pulling
			target_mouse_pos = get_global_mouse_position()
			find_all_planets()

func update_planet_arcs(predicted_velocity: Vector2):
	"""Simple planet arc visualization"""
	var slingshot_pos = slingshot_center.global_position
	
	for planet in all_planets:
		if not planet or not is_instance_valid(planet):
			continue
		
		var distance_to_planet = slingshot_pos.distance_to(planet.global_position)
		
		if distance_to_planet > max_display_distance:
			if planet.gravity_visualizer and planet.gravity_visualizer.has_method("hide_orbit_prediction"):
				planet.gravity_visualizer.hide_orbit_prediction()
			continue
		
		if distance_to_planet <= planet.gravity_radius * 1.2:
			var speed = predicted_velocity.length()
			var arc_angle = 60.0
			if speed > 150:
				arc_angle = 30.0
			
			var speed_factor = speed / 100.0
			if planet.gravity_visualizer and planet.gravity_visualizer.has_method("update_orbit_prediction"):
				planet.gravity_visualizer.update_orbit_prediction(arc_angle, speed_factor)
		else:
			if planet.gravity_visualizer and planet.gravity_visualizer.has_method("hide_orbit_prediction"):
				planet.gravity_visualizer.hide_orbit_prediction()

func reset():
	slingshotState = SlingshotState.idle
	if spacecraft:
		spacecraft.stop()
		spacecraft.scale = Vector2.ONE
		spacecraft.modulate = Color(1, 1, 1, 1)
		spacecraft.reset(0, slingshot_center.global_position)
