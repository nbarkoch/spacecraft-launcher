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
const MULTIPLIER = 6

# Snap system - עדין ולא פולשני
const ANGLE_SNAP_INTERVAL = 22.5  # כל 22.5 מעלות (16 כיוונים)
const DISTANCE_SNAP_INTERVAL = 15.0  # כל 15 פיקסלים
const SNAP_RADIUS = 8.0  # בתוך כמה פיקסלים יש משיכה
const SNAP_STRENGTH = 0.4  # עוצמת המשיכה (0-1)

@onready var slingshot_center: Marker2D = $SlingshotCenter

# Smooth transition for snap only
var target_mouse_pos = Vector2.ZERO
const TRANSITION_SPEED = 12.0  # מהירות המעבר החלק

# NEW: Planet arc visualization
var all_planets: Array = []
var max_display_distance: float = 400.0  # מרחק מקסימלי להצגת פלחים

func _ready():
	slingshotState = SlingshotState.idle
	leftLine = $LeftLine
	rightLine = $RightLine
	
	# Create trajectory predictor
	trajectory_predictor = TrajectoryPredictor.new()
	add_child(trajectory_predictor)
	trajectory_predictor.hide_trajectory()
	
	# NEW: Find all planets for arc visualization
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
		if planet is Planet and planet.gravity_visualizer:
			all_planets.append(planet)

func _process(delta):
	match slingshotState:
		SlingshotState.idle:
			# NEW: Hide all planet arcs when idle
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
				var initial_speed = velocity.length()
				var velocity_factor =  clamp(initial_speed / 130.0, 0.74, 1)
				var velocity_at_gravity_zone = velocity * velocity_factor * 0.9
				
				
				trajectory_predictor.update_prediction(current_mouse_pos, velocity_at_gravity_zone)
				
				# NEW: Update planet arc visualizations
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

# COPY: EXACT same functions from ORIGINAL slingshot.gd - DON'T TOUCH THE ORIGINAL!
func calculate_exact_orbit_duration(planet: Planet, velocity: Vector2) -> float:
	"""Use the EXACT same calculation as the NEW orbit_config"""
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
		var stabilizer_control = calculate_stabilizer_control_slingshot(speed)
		
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

func calculate_stabilizer_control_slingshot(speed: float) -> float:
	"""Calculate how much control the stabilizer has at this speed"""
	var base_control = 1.0
	var speed_penalty = (speed - 50.0) / 200.0  # Normalize speed above 50
	speed_penalty = clamp(speed_penalty, 0.0, 3.0)
	
	# Exponential decay of control
	var control_factor = base_control * exp(-speed_penalty * 1.2)
	
	return clamp(control_factor, 0.1, 0.95)

func calculate_exact_arc_angle(planet: Planet, velocity: Vector2, duration: float) -> float:
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
		var stabilizer_control = calculate_stabilizer_control_slingshot(speed)
		var speed_reduction_factor = (speed - 50.0) / 250.0
		speed_reduction_factor = clamp(speed_reduction_factor, 0.0, 1.0)
		
		# This is the SAME calculation used in duration - the intended angle
		var base_angle = 360.0 * (1.0 - speed_reduction_factor * 0.97)
		var final_angle = base_angle * stabilizer_control
		
		return clamp(final_angle, 5.0, 360.0)

func update_planet_arcs(predicted_velocity: Vector2):
	"""Update arc visualizations using COPIED GravityZoneVisualizer functions"""
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
		
		# Predict ACTUAL velocity when spacecraft reaches gravity zone
		var initial_speed = predicted_velocity.length()
		var velocity_factor = clamp(initial_speed / 130.0, 0.74, 1)
		var velocity_at_gravity_zone = predicted_velocity * velocity_factor
		
		if velocity_at_gravity_zone.length() == 0:
			# Won't enter gravity zone, hide arc
			if planet.gravity_visualizer and planet.gravity_visualizer.has_method("hide_orbit_prediction"):
				planet.gravity_visualizer.hide_orbit_prediction()
			continue
		
		# Use COPIED ORIGINAL slingshot functions - EXACT same calculation!
		var predicted_duration = calculate_exact_orbit_duration(planet, velocity_at_gravity_zone)
		var predicted_arc_angle = calculate_exact_arc_angle(planet, velocity_at_gravity_zone, predicted_duration)
		
		# Calculate speed factor for visual rotation based on actual entry speed
		var entry_speed = velocity_at_gravity_zone.length()
		var speed_factor = clamp(entry_speed / 100.0, 0.2, 3.0)
		
		# Show the arc visualization using existing GravityZoneVisualizer method
		if planet.gravity_visualizer and planet.gravity_visualizer.has_method("update_orbit_prediction"):
			planet.gravity_visualizer.update_orbit_prediction(predicted_arc_angle, speed_factor)

func reset():
	slingshotState = SlingshotState.idle
	if spacecraft:
		spacecraft.stop()
		spacecraft.scale = Vector2.ONE
		spacecraft.modulate =  Color(1, 1, 1, 1)
		spacecraft.reset(0, slingshot_center.global_position)
