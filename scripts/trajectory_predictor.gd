extends Node2D
class_name TrajectoryPredictor

# Configuration
@export var max_prediction_time: float = 4.0
@export var prediction_steps: int = 150
@export var line_width: float = 3.0
@export var normal_color: Color = Color(1.0, 1.0, 1.0, 0.4)
@export var gravity_color: Color = Color(0.3, 0.7, 1.0, 0.4)
@export var collision_color: Color = Color(1.0, 0.2, 0.2, 0.9)
@export var animation_speed_multiplier: float = 0.35  # Multiplier for fine-tuning

# Internal variables
var trajectory_line: Line2D
var is_predicting: bool = false
var animation_offset: float = 0.0
var cached_points: Array = []
var cached_states: Array = []
var current_velocity: Vector2 = Vector2.ZERO  # Store the current velocity
var velocity_based_speed: float = 0.0

func _ready():
	create_trajectory_line()

func _process(delta):
	"""Animate the trajectory dashes at velocity-matched speed"""
	if is_predicting and cached_points.size() > 0:
		# Use velocity-based animation speed
		animation_offset += velocity_based_speed * delta
		
		# Reset offset to prevent overflow
		var dash_cycle = 25.0  # dash_length + gap_length
		if animation_offset > dash_cycle:
			animation_offset -= dash_cycle
		
		# Redraw with new offset every frame
		create_animated_trajectory(cached_points, cached_states)

func create_trajectory_line():
	"""Create a single Line2D for the trajectory"""
	trajectory_line = Line2D.new()
	add_child(trajectory_line)
	trajectory_line.width = line_width
	trajectory_line.default_color = normal_color
	trajectory_line.antialiased = true

func predict_trajectory(start_position: Vector2, initial_velocity: Vector2):
	"""Predict trajectory using EXACT same physics as spacecraft"""
	# Store the initial velocity for animation speed calculation
	current_velocity = initial_velocity
	
	# Calculate animation speed based on velocity magnitude
	# Scale it down since the trajectory is in local coordinates and might be smaller
	velocity_based_speed = current_velocity.length() * animation_speed_multiplier
	
	# Don't clear animation_offset here - only clear the line points
	if trajectory_line:
		trajectory_line.clear_points()
	
	# Use the same time step as the game (60 FPS)
	var time_step = 1.0 / 60.0
	var total_steps = int(max_prediction_time / time_step)
	
	# Simulation variables - match spacecraft exactly
	var sim_position = start_position
	var sim_velocity = initial_velocity
	var sim_gravity_assist = null
	
	var trajectory_points = []
	var point_states = []
	var velocity_segments = []  # Store velocity for each segment
	
	# Get planets
	var planets = find_all_planets()
	
	# Simulate using exact game physics
	for step in range(total_steps):
		# Add current position and velocity
		trajectory_points.append(to_local(sim_position))
		velocity_segments.append(sim_velocity.length())
		
		# Check planet collisions
		var collision_detected = false
		
		for planet in planets:
			if not planet or not is_instance_valid(planet):
				continue
			
			var distance_to_planet = sim_position.distance_to(planet.global_position)
			
			if distance_to_planet <= planet.planet_radius:
				collision_detected = true
				point_states.append(2)  # Mark as collision/destruction
				break
		
		if collision_detected:
			break
		
		# Check gravity assist entry (exact same logic as spacecraft)
		if not sim_gravity_assist:
			for planet in planets:
				if not planet or not is_instance_valid(planet):
					continue
				
				var distance_to_planet = sim_position.distance_to(planet.global_position)
				if distance_to_planet <= planet.gravity_radius:
					# Enter gravity assist - use your exact GravityAssist class
					sim_gravity_assist = GravityAssist.new(planet, sim_velocity)
					break
		
		# Track state
		if sim_gravity_assist:
			point_states.append(1)  # Gravity
		else:
			point_states.append(0)  # Normal
		
		# Apply gravity assist physics (exact same as spacecraft)
		if sim_gravity_assist:
			sim_velocity = sim_gravity_assist.update_curve(time_step, sim_position)
			
			# Check if gravity assist complete (exact same logic)
			if sim_gravity_assist.is_curve_complete():
				sim_velocity = sim_gravity_assist.get_exit_velocity()
				sim_gravity_assist = null
		
		# Move to next position (exact same as RigidBody2D movement)
		sim_position += sim_velocity * time_step
		
		# Check bounds
		if abs(sim_position.x) > 500 or abs(sim_position.y) > 500:
			break
		
		# Sample every few steps for performance
		if step % 2 != 0:  # Skip every other step for visualization
			continue
	
	# Cache the trajectory data for animation
	cached_points = trajectory_points
	cached_states = point_states
	
	# Create trajectory with accurate colors and animation
	create_velocity_matched_trajectory(trajectory_points, point_states, velocity_segments)

func create_velocity_matched_trajectory(points: Array, states: Array, velocities: Array):
	"""Create trajectory with velocity-matched animated moving dashes"""
	if points.size() < 2:
		return
	
	trajectory_line.clear_points()
	
	var dash_length = 15.0
	var gap_length = 10.0
	var cycle_length = dash_length + gap_length
	var current_color = normal_color
	
	# Calculate cumulative distance along path for velocity-based animation
	var path_distances = [0.0]
	var total_path_length = 0.0
	
	for i in range(points.size() - 1):
		var segment_length = points[i].distance_to(points[i + 1])
		total_path_length += segment_length
		path_distances.append(total_path_length)
	
	for i in range(points.size() - 1):
		var start_point = points[i]
		var end_point = points[i + 1]
		var segment_vector = end_point - start_point
		var segment_length = segment_vector.length()
		
		if segment_length == 0:
			continue
		
		# Determine color based on state
		var state = states[i] if i < states.size() else 0
		var segment_color = normal_color
		
		match state:
			0: segment_color = normal_color    # Normal
			1: segment_color = gravity_color   # Gravity assist
			2: segment_color = collision_color # Collision
		
		# Handle color changes
		if segment_color != current_color:
			current_color = segment_color
			trajectory_line.default_color = current_color
			if trajectory_line.get_point_count() > 0:
				trajectory_line.add_point(Vector2.INF)
		
		# Get velocity for this segment for local animation speed
		var segment_velocity = velocities[i] if i < velocities.size() else current_velocity.length()
		var local_speed_factor = segment_velocity / max(current_velocity.length(), 1.0)
		
		# Create animated dashed pattern along this segment
		var steps = int(segment_length / 2.0) + 1
		
		for step in range(steps + 1):
			var t = float(step) / steps
			var current_pos = start_point + segment_vector * t
			var distance_along_segment = segment_length * t
			var total_distance = path_distances[i] + distance_along_segment
			
			# Apply velocity-based animation with local speed adjustments
			var adjusted_animation_offset = animation_offset * local_speed_factor
			var animated_distance = total_distance - adjusted_animation_offset
			var cycle_pos = fmod(animated_distance, cycle_length)
			if cycle_pos < 0:
				cycle_pos += cycle_length
			
			var should_draw = cycle_pos < dash_length
			
			if should_draw:
				trajectory_line.add_point(current_pos)
			elif trajectory_line.get_point_count() > 0:
				# Add break when we stop drawing
				var last_point = trajectory_line.get_point_position(trajectory_line.get_point_count() - 1)
				if last_point != Vector2.INF:
					trajectory_line.add_point(Vector2.INF)

func create_animated_trajectory(points: Array, states: Array):
	"""Legacy function - now uses velocity-matched version"""
	var dummy_velocities = []
	for i in range(points.size()):
		dummy_velocities.append(current_velocity.length())
	create_velocity_matched_trajectory(points, states, dummy_velocities)

func find_all_planets() -> Array:
	"""Find all Planet nodes in the scene"""
	var planets = []
	
	# Try group first
	var grouped_planets = get_tree().get_nodes_in_group("Planets")
	if grouped_planets.size() > 0:
		return grouped_planets
	
	# Fallback search
	var root = get_tree().current_scene
	find_planets_recursive(root, planets)
	return planets

func find_planets_recursive(node: Node, planets: Array):
	"""Recursively find Planet nodes"""
	if node is Planet:
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
	clear_trajectory()
	reset_animation()

func clear_trajectory():
	"""Clear trajectory line but preserve animation state"""
	if trajectory_line:
		trajectory_line.clear_points()
	cached_points.clear()
	cached_states.clear()

func reset_animation():
	"""Reset animation completely (called when hiding trajectory)"""
	animation_offset = 0.0

func update_prediction(start_position: Vector2, initial_velocity: Vector2):
	"""Update prediction in real-time"""
	if is_predicting:
		predict_trajectory(start_position, initial_velocity)

func set_animation_speed_multiplier(multiplier: float):
	"""Adjust the animation speed multiplier for fine-tuning"""
	animation_speed_multiplier = multiplier
