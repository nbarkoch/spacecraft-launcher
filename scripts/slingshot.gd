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

func calculate_exact_orbit_duration(planet: Planet, velocity: Vector2) -> float:
	"""Use the EXACT same calculation as the planet does"""
	return planet.calculate_predicted_orbit_duration(velocity)

func calculate_exact_arc_angle(planet: Planet, velocity: Vector2, duration: float) -> float:
	"""Calculate arc angle based on actual orbit mechanics from your game"""
	if duration <= 0:
		return 0.0
	
	var speed = velocity.length()
	
	# Since predictor was showing half of actual behavior
	var base_angular_speed_deg_per_sec = 240.0  # Doubled from 120 to match full circles
	
	# Only use planet-specific factors, NOT speed
	var size_factor = clamp(60.0 / planet.gravity_radius, 0.5, 2.0)
	var gravity_factor = clamp(planet.gravity_strength / 300.0, 0.5, 2.0)
	
	# Angular speed based only on planet properties
	var angular_speed = base_angular_speed_deg_per_sec * size_factor * gravity_factor
	
	# Calculate total arc angle
	var arc_angle = angular_speed * duration
	
	return clamp(arc_angle, 10.0, 720.0)

func calculate_effective_orbital_speed(initial_speed: float, planet: Planet, orbital_radius: float) -> float:
	"""Calculate the effective orbital speed based on your game's mechanics"""
	
	# Base orbital speed is influenced by initial velocity
	# Higher initial speed = higher orbital speed
	var base_speed = initial_speed * 0.75  # Reduced by orbital mechanics
	
	# Add gravitational contribution
	# From your gravity calculation: force_magnitude = gravity_strength * delta * 60.0 / (distance * 0.01)
	var gravity_contribution = sqrt(planet.gravity_strength * orbital_radius * 0.1)
	
	# Combine initial velocity with gravitational effects
	var effective_speed = base_speed + gravity_contribution * 0.3
	
	# Apply planet-specific factors
	var size_factor = orbital_radius / 50.0  # Larger orbits = slightly higher speeds
	var strength_factor = planet.gravity_strength / 300.0  # Stronger gravity = higher speeds
	
	effective_speed *= (0.8 + size_factor * 0.2) * (0.8 + strength_factor * 0.4)
	
	return clamp(effective_speed, 20.0, 200.0)

func predict_spacecraft_trajectory(start_pos: Vector2, velocity: Vector2, planet: Planet) -> Dictionary:
	"""Predict if and when spacecraft will enter planet's gravity zone"""
	
	var time_step = 1.0 / 60.0
	var max_time = 10.0  # Maximum prediction time
	var sim_pos = start_pos
	var sim_vel = velocity
	
	# Simulate trajectory until we hit gravity zone or time runs out
	for step in range(int(max_time / time_step)):
		var time_elapsed = step * time_step
		
		# Update position
		sim_pos += sim_vel * time_step
		
		# Check if we entered gravity zone
		var distance_to_planet = sim_pos.distance_to(planet.global_position)
		if distance_to_planet <= planet.gravity_radius:
			return {
				"will_enter": true,
				"entry_time": time_elapsed,
				"entry_position": sim_pos,
				"entry_velocity": sim_vel,
				"distance_at_entry": distance_to_planet
			}
		
		# Check for collision with planet surface
		if distance_to_planet <= planet.planet_radius + 6.0:  # spacecraft radius
			return {
				"will_enter": false,
				"collision": true,
				"collision_time": time_elapsed
			}
		
		# Check if trajectory is moving away from planet
		var to_planet = planet.global_position - sim_pos
		if to_planet.dot(sim_vel) <= 0 and distance_to_planet > planet.gravity_radius * 2.0:
			break  # Moving away, won't enter
	
	return {"will_enter": false}

func update_planet_arcs(predicted_velocity: Vector2):
	"""Update arc visualizations with accurate predictions"""
	var spacecraft_speed = predicted_velocity.length()
	var slingshot_pos = $SlingshotCenter.global_position
	
	for planet in all_planets:
		if not planet or not is_instance_valid(planet):
			continue
		
		var distance_to_planet = slingshot_pos.distance_to(planet.global_position)
		
		# Hide arcs for distant planets
		if distance_to_planet > max_display_distance:
			if planet.gravity_visualizer and planet.gravity_visualizer.has_method("hide_orbit_prediction"):
				planet.gravity_visualizer.hide_orbit_prediction()
			continue
		
		# Predict if spacecraft will actually enter this planet's gravity
		var trajectory_info = predict_spacecraft_trajectory(slingshot_pos, predicted_velocity, planet)
		
		if not trajectory_info.get("will_enter", false):
			# Won't enter gravity zone, hide arc
			if planet.gravity_visualizer and planet.gravity_visualizer.has_method("hide_orbit_prediction"):
				planet.gravity_visualizer.hide_orbit_prediction()
			continue
		
		# Use the original predicted velocity for duration calculation
		# This ensures speed changes are properly reflected
		var predicted_duration = calculate_exact_orbit_duration(planet, predicted_velocity)
		var predicted_arc_angle = calculate_exact_arc_angle(planet, predicted_velocity, predicted_duration)
		
		# Calculate speed factor for visual rotation
		var speed_factor = clamp(spacecraft_speed / 100.0, 0.2, 3.0)
		
		# Show the arc visualization
		if planet.gravity_visualizer and planet.gravity_visualizer.has_method("update_orbit_prediction"):
			planet.gravity_visualizer.update_orbit_prediction(predicted_arc_angle, speed_factor)
		
		
# Alternative simplified version if the above is too complex:
func update_planet_arcs_simple(predicted_velocity: Vector2):
	"""Simplified version using direct planet calculations"""
	var speed = predicted_velocity.length()
	
	for planet in all_planets:
		if not planet or not is_instance_valid(planet):
			continue
		
		var distance_to_planet = $SlingshotCenter.global_position.distance_to(planet.global_position)
		
		# Only show arcs for planets we might hit
		if distance_to_planet > max_display_distance:
			if planet.gravity_visualizer:
				planet.gravity_visualizer.hide_orbit_prediction()
			continue
		
		# MANUAL calculation to verify speed effect
		var manual_duration = planet.base_speed_threshold / max(speed, 10.0) * planet.min_orbit_duration_factor
		manual_duration = clamp(manual_duration, 0.1, planet.max_orbit_duration_factor * 2.0)
		
		# Use the exact same duration calculation as the actual game
		var predicted_duration = planet.calculate_predicted_orbit_duration(predicted_velocity)

		# Calculate arc angle based on your game's orbital mechanics
		var ideal_orbit_radius = planet.planet_radius + (planet.gravity_radius - planet.planet_radius) * 0.6
		var orbital_speed = speed * 0.6  # Approximate speed reduction in orbit
		var angular_velocity = orbital_speed / ideal_orbit_radius
		var arc_angle = rad_to_deg(angular_velocity * predicted_duration)
		
		# Clamp and apply
		arc_angle = clamp(arc_angle, 10.0, 360.0)
		var speed_factor = clamp(speed / 100.0, 0.3, 2.0)
		
		if planet.gravity_visualizer:
			planet.gravity_visualizer.update_orbit_prediction(arc_angle, speed_factor)
