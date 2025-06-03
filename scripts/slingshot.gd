extends Node2D
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
var spacecraft
var trajectory_predictor
const MULTIPLIER = 6

# Snap system - עדין ולא פולשני
const ANGLE_SNAP_INTERVAL = 22.5  # כל 22.5 מעלות (16 כיוונים)
const DISTANCE_SNAP_INTERVAL = 15.0  # כל 15 פיקסלים
const SNAP_RADIUS = 8.0  # בתוך כמה פיקסלים יש משיכה
const SNAP_STRENGTH = 0.4  # עוצמת המשיכה (0-1)

# FIXED: Removed problematic mouse smoothing variables
# var raw_mouse_pos = Vector2.ZERO
# const MOUSE_SMOOTHING = 0.3

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
				# FIXED: Use direct mouse position without problematic smoothing
				var mouse_pos = get_global_mouse_position()
				var center_pos = $SlingshotCenter.global_position
				
				# FIXED: Apply constraints directly to mouse position
				var constrained_mouse_pos = mouse_pos
				constrained_mouse_pos.x = min(center_pos.x+60, max(center_pos.x-60, constrained_mouse_pos.x))
				constrained_mouse_pos.y = min(center_pos.y+60, max(center_pos.y+10, constrained_mouse_pos.y))
				
				if constrained_mouse_pos.distance_to(center_pos) > 100:
					constrained_mouse_pos = (constrained_mouse_pos - center_pos).normalized() * 100 + center_pos
				
				# FIXED: Apply snap directly to constrained position
				target_mouse_pos = apply_subtle_snap(constrained_mouse_pos, center_pos)
				
				# FIXED: Use target position directly for immediate response
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
				trajectory_predictor.update_prediction(current_mouse_pos, velocity * 0.9)
				
				# NEW: Update planet arc visualizations
				update_planet_arcs(velocity)
				
			if Input.is_action_just_released("FINGER_TAP"):
				var center_pos = $SlingshotCenter.global_position
				# FIXED: Use target position for consistent release
				var final_mouse_pos = target_mouse_pos
				
				slingshotState = SlingshotState.released
				
				# FIXED: Hide trajectory predictor and planet arcs IMMEDIATELY
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
				await get_tree().process_frame
				spacecraft.apply_impulse(velocity)
				
				GameManager.currentState = GameManager.GameState.action
				
		SlingshotState.released:
			# Reset line positions
			leftLine.points[0] = leftLine.to_local($SlingshotCenter.global_position)
			rightLine.points[0] = rightLine.to_local($SlingshotCenter.global_position)
			
			hide_all_planet_arcs()
			# Check if spacecraft is done (destroyed or out of bounds)
			if not spacecraft or not is_instance_valid(spacecraft):
				# Reset for next shot
				slingshotState = SlingshotState.idle
				GameManager.currentState = GameManager.GameState.idle
				
		SlingshotState.reset:
			pass

# NEW: Planet arc visualization methods
func update_planet_arcs(predicted_velocity: Vector2):
	"""Update arc visualizations on all planets based on predicted trajectory"""
	var spacecraft_speed = predicted_velocity.length()
	
	for planet in all_planets:
		if not planet or not is_instance_valid(planet):
			continue
			
		var distance_to_planet = global_position.distance_to(planet.global_position)
		
		# Only show arcs for planets within reasonable distance
		if distance_to_planet > max_display_distance:
			planet.gravity_visualizer.hide_orbit_prediction()
			continue
		
		# FIXED: Calculate predicted orbit parameters using the ACTUAL predicted velocity
		var predicted_duration = calculate_exact_orbit_duration(planet, predicted_velocity)
		var predicted_arc_angle = calculate_exact_arc_angle(planet, predicted_velocity, predicted_duration)
		var speed_factor = spacecraft_speed / 100.0  # Normalize for visual speed
		
		# Extended debug output to see what's happening
		if planet.name == "Planet":  # רק לכוכב אחד כדי לא להציף
			var orbital_radius = planet.planet_radius + (planet.gravity_radius - planet.planet_radius) * 0.6
			var orbital_speed = spacecraft_speed * 0.75
			var angular_velocity = orbital_speed / orbital_radius

		
		# Show/update the arc visualization
		planet.gravity_visualizer.update_orbit_prediction(predicted_arc_angle, speed_factor)

func calculate_exact_orbit_duration(planet: Planet, velocity: Vector2) -> float:
	"""Calculate EXACT orbit duration using the predicted velocity - MUST match planet calculation"""
	# קריאה ישירה לפונקציה של הכוכב כדי לוודא התאמה מלאה!
	return planet.calculate_predicted_orbit_duration(velocity)

func calculate_exact_arc_angle(planet: Planet, velocity: Vector2, duration: float) -> float:
	if duration <= 0:
		return 0.0
	
	# מהירות זוויתית קבועה בהתבסס רק על הכוכב
	var base_angular_speed = 45.0 * (planet.gravity_strength / 3.0)
	var size_factor = 50.0 / planet.gravity_radius
	var angular_speed = base_angular_speed * size_factor
	
	# זווית = מהירות זוויתית * זמן
	return clamp(angular_speed * duration, 5.0, 720.0)

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
		# Find spacecraft when starting to pull
		if not spacecraft or not is_instance_valid(spacecraft):
			var spacecrafts = get_tree().get_nodes_in_group("Spacecrafts")
			if spacecrafts.size() > 0:
				spacecraft = spacecrafts[0] as Spacecraft
		
		if spacecraft:
			slingshotState = SlingshotState.pulling
			# FIXED: Initialize target position directly with current mouse position
			target_mouse_pos = get_global_mouse_position()
			
			# NEW: Refresh planet list when starting to pull
			find_all_planets()
