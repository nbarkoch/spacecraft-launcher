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
var trajectory_predictor: TrajectoryPredictor
const MULTIPLIER = 4  # Reduced from 6 for less sensitivity

# Snap system - עדין ולא פולשני
const ANGLE_SNAP_INTERVAL = 22.5  # כל 22.5 מעלות (16 כיוונים)
const DISTANCE_SNAP_INTERVAL = 15.0  # כל 15 פיקסלים
const SNAP_RADIUS = 12.0  # Increased for easier snapping
const SNAP_STRENGTH = 0.2  # Reduced for subtler snap

@onready var slingshot_center: Marker2D = $SlingshotCenter

# Smooth transition for snap only
var target_mouse_pos = Vector2.ZERO
const TRANSITION_SPEED = 12.0  # מהירות המעבר החלק

# Planet arc visualization (simplified)
var all_planets: Array = []
var max_display_distance: float = 400.0

func _ready():
	slingshotState = SlingshotState.idle
	leftLine = $LeftLine
	rightLine = $RightLine
	
	# Create trajectory predictor
	trajectory_predictor = TrajectoryPredictor.new()
	add_child(trajectory_predictor)
	trajectory_predictor.hide_trajectory()
	
	# Find all planets
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
				
				# Apply constraints directly to mouse position
				var constrained_mouse_pos = mouse_pos
				constrained_mouse_pos.x = min(center_pos.x+60, max(center_pos.x-60, constrained_mouse_pos.x))
				constrained_mouse_pos.y = min(center_pos.y+60, max(center_pos.y+10, constrained_mouse_pos.y))
				
				if constrained_mouse_pos.distance_to(center_pos) > 100:
					constrained_mouse_pos = (constrained_mouse_pos - center_pos).normalized() * 100 + center_pos
				
				# Apply snap directly to constrained position
				target_mouse_pos = apply_subtle_snap(constrained_mouse_pos, center_pos)
				
				# Use target position directly for immediate response
				var current_mouse_pos = target_mouse_pos
				
				# Update line positions with immediate position
				leftLine.points[0] = leftLine.to_local(current_mouse_pos)
				rightLine.points[0] = rightLine.to_local(current_mouse_pos)
				
				# Center spacecraft on immediate position
				spacecraft.global_position = current_mouse_pos
				
				# Update rotation for visual feedback while aiming
				var launch_direction = center_pos - current_mouse_pos
				if launch_direction.length() > 0:
					spacecraft.rotation = launch_direction.angle() + PI/2
				
				# Calculate velocity for predictions
				var velocity = (center_pos - current_mouse_pos) * MULTIPLIER
				
				# Update trajectory prediction
				trajectory_predictor.show_trajectory()
				trajectory_predictor.update_prediction(current_mouse_pos, velocity * 0.97)
				
				# Simple planet arc visualization
				update_planet_arcs(velocity)
				
			if Input.is_action_just_released("FINGER_TAP"):
				var center_pos = slingshot_center.global_position
				var final_mouse_pos = target_mouse_pos
				
				slingshotState = SlingshotState.released
				
				# Hide trajectory predictor and planet arcs IMMEDIATELY
				trajectory_predictor.hide_trajectory()
				hide_all_planet_arcs()
				
				# Calculate velocity with final position
				var velocity = (center_pos - final_mouse_pos) * MULTIPLIER
				
				# Release spacecraft
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
				spacecraft.apply_impulse(velocity)
				GameManager.currentState = GameManager.GameState.action
				
		SlingshotState.released:
			# Reset line positions
			leftLine.points[0] = leftLine.to_local(slingshot_center.global_position)
			rightLine.points[0] = rightLine.to_local(slingshot_center.global_position)
			
			hide_all_planet_arcs()
			# Check if spacecraft is done (destroyed or out of bounds)
			if not spacecraft or not is_instance_valid(spacecraft):
				# Reset for next shot
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
	
	# Snap זווית
	var current_angle = pull_vector.angle()
	var snapped_angle = apply_angle_snap(current_angle)
	
	# Snap מרחק  
	var current_distance = pull_vector.length()
	var snapped_distance = apply_distance_snap(current_distance)
	
	# בנה וקטור חדש
	var snapped_vector = Vector2(cos(snapped_angle), sin(snapped_angle)) * snapped_distance
	var snapped_pos = center_pos + snapped_vector
	
	return snapped_pos

func apply_angle_snap(angle: float) -> float:
	"""הפעל snap עדין על זווית"""
	var angle_degrees = rad_to_deg(angle)
	
	# מצא את נקודת הsnap הקרובה ביותר
	var nearest_snap = round(angle_degrees / ANGLE_SNAP_INTERVAL) * ANGLE_SNAP_INTERVAL
	var distance_to_snap = abs(angle_degrees - nearest_snap)
	
	# טפל במקרה של חצייה של 180/-180
	if distance_to_snap > 180:
		distance_to_snap = 360 - distance_to_snap
	
	# אם קרוב מספיק, הפעל snap
	var snap_threshold = ANGLE_SNAP_INTERVAL * 0.4  # 40% מהמרווח
	if distance_to_snap <= snap_threshold:
		var snap_factor = 1.0 - (distance_to_snap / snap_threshold)
		snap_factor = snap_factor * SNAP_STRENGTH
		
		# טפל בחצייה של זוויות
		if abs(angle_degrees - nearest_snap) > 180:
			if angle_degrees > nearest_snap:
				nearest_snap += 360
			else:
				nearest_snap -= 360
		
		angle_degrees = lerp(angle_degrees, nearest_snap, snap_factor)
	
	return deg_to_rad(angle_degrees)

func apply_distance_snap(distance: float) -> float:
	"""הפעל snap עדין על מרחק"""
	# מצא את נקודת הsnap הקרובה ביותר
	var nearest_snap = round(distance / DISTANCE_SNAP_INTERVAL) * DISTANCE_SNAP_INTERVAL
	var distance_to_snap = abs(distance - nearest_snap)
	
	# אם קרוב מספיק, הפעל snap
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
			
			# Refresh planet list when starting to pull
			find_all_planets()

func update_planet_arcs(predicted_velocity: Vector2):
	"""Simple planet arc visualization"""
	var slingshot_pos = slingshot_center.global_position
	
	for planet in all_planets:
		if not planet or not is_instance_valid(planet):
			continue
		
		var distance_to_planet = slingshot_pos.distance_to(planet.global_position)
		
		# Hide arcs for distant planets
		if distance_to_planet > max_display_distance:
			if planet.gravity_visualizer and planet.gravity_visualizer.has_method("hide_orbit_prediction"):
				planet.gravity_visualizer.hide_orbit_prediction()
			continue
		
		# Simple logic: if will enter gravity zone, show basic arc
		if distance_to_planet <= planet.gravity_radius * 1.2:  # Close enough to be affected
			var speed = predicted_velocity.length()
			var arc_angle = 60.0  # Simple fixed arc
			if speed > 150:
				arc_angle = 30.0  # Smaller arc for fast speed
			
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
		spacecraft.modulate =  Color(1, 1, 1, 1)
		spacecraft.reset(0, slingshot_center.global_position)
