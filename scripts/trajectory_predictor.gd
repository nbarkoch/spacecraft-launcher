extends Node2D
class_name TrajectoryPredictor

# Configuration
@export var max_prediction_time: float = 4.0
@export var line_width: float = 3.0
@export var normal_color: Color = Color(1.0, 1.0, 1.0, 0.4)
@export var gravity_color: Color = Color(0.3, 0.7, 1.0, 0.6)
@export var collision_color: Color = Color(1.0, 0.2, 0.2, 0.9)

# Spacecraft properties
@export var spacecraft_collision_radius: float = 6.0

# Internal variables
var trajectory_line: Line2D
var is_predicting: bool = false

func _ready():
	create_trajectory_line()

func create_trajectory_line():
	"""Create Line2D for trajectory visualization"""
	trajectory_line = Line2D.new()
	add_child(trajectory_line)
	trajectory_line.width = line_width
	trajectory_line.default_color = normal_color
	trajectory_line.antialiased = true

func predict_trajectory(start_position: Vector2, initial_velocity: Vector2):
	"""Predict trajectory using improved manual simulation that matches RigidBody2D"""
	if trajectory_line:
		trajectory_line.clear_points()
	
	# Use much smaller time steps for better accuracy (like RigidBody2D internal steps)
	var time_step = 1.0 / 360.0  # 6x smaller steps for orbital accuracy
	var max_steps = int(max_prediction_time / time_step)
	
	# Simulation state
	var position = start_position
	var velocity = initial_velocity
	var active_gravity_planets: Array = []
	
	# Get all planets
	var planets = find_all_planets()
	
	# Simulate with higher precision
	for step in range(max_steps):
		# Add trajectory point every few steps for performance
		if step % 6 == 0:  # Sample every 6 micro-steps
			trajectory_line.add_point(to_local(position))
		
		# Update active gravity zones - proper entry/exit handling
		var currently_in_gravity: Array = []
		
		for planet in planets:
			if not planet or not is_instance_valid(planet):
				continue
			
			var distance_center_to_center = position.distance_to(planet.global_position)
			var spacecraft_edge_distance = distance_center_to_center - spacecraft_collision_radius
			
			# Check if spacecraft is in this planet's gravity zone
			if spacecraft_edge_distance <= planet.gravity_radius:
				currently_in_gravity.append(planet)
		
		# Handle zone transitions (matching planet script behavior)
		# Check for new planet entries (this triggers exit_gravity_assist + new assist)
		var new_planets = []
		for planet in currently_in_gravity:
			if not planet in active_gravity_planets:
				new_planets.append(planet)
		
		# If entering any new gravity zone, clear all previous and use the new one
		# This simulates the planet script calling exit_gravity_assist() then creating new assist
		if new_planets.size() > 0:
			active_gravity_planets.clear()
			# Use the first new planet encountered (deterministic behavior)
			active_gravity_planets.append(new_planets[0])
		
		# Remove planets that spacecraft has exited (only if no new entries)
		if new_planets.size() == 0:
			for i in range(active_gravity_planets.size() - 1, -1, -1):
				var planet = active_gravity_planets[i]
				if not planet in currently_in_gravity:
					active_gravity_planets.remove_at(i)
		
		# Apply gravity forces from the single active planet (if any)
		var total_gravity_force = Vector2.ZERO
		var in_gravity = active_gravity_planets.size() > 0
		
		# Only apply gravity from one planet at a time (matching the game logic)
		if active_gravity_planets.size() > 0:
			var planet = active_gravity_planets[0]
			var to_planet = planet.global_position - position
			var distance = to_planet.length()
			
			if distance >= 1.0:
				# EXACT formula from orbit_config.gd but with micro time step
				var force_magnitude = planet.gravity_strength * time_step * 60.0 / (distance * 0.01)
				var force_direction = to_planet.normalized()
				var gravity_force = force_direction * force_magnitude
				
				total_gravity_force += gravity_force
		
		# Set trajectory color
		if in_gravity:
			trajectory_line.default_color = gravity_color
		else:
			trajectory_line.default_color = normal_color
		
		# Apply gravity forces - EXACT like spacecraft
		velocity += total_gravity_force
		
		# Move position - EXACT like RigidBody2D but with micro steps
		position += velocity * time_step
		
		# Check for planet collision (using planet_radius, not gravity_radius)
		var collision_detected = false
		for planet in planets:
			if not planet or not is_instance_valid(planet):
				continue
			
			var distance_center_to_center = position.distance_to(planet.global_position)
			if distance_center_to_center <= (planet.planet_radius + spacecraft_collision_radius):
				trajectory_line.default_color = collision_color
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
	if trajectory_line:
		trajectory_line.clear_points()

func update_prediction(start_position: Vector2, initial_velocity: Vector2):
	"""Update prediction in real-time"""
	if is_predicting:
		predict_trajectory(start_position, initial_velocity)
