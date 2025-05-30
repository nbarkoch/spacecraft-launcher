extends Node2D
class_name TrajectoryPredictor

# Configuration
@export var max_prediction_time: float = 4.0
@export var line_width: float = 3.0
@export var normal_color: Color = Color(1.0, 1.0, 1.0, 0.4)
@export var gravity_color: Color = Color(0.3, 0.7, 1.0, 0.6)
@export var collision_color: Color = Color(1.0, 0.2, 0.2, 0.9)

# Spacecraft collision radius
@export var spacecraft_collision_radius: float = 6.0

# Internal variables
var trajectory_line: Line2D
var is_predicting: bool = false

func _ready():
	create_trajectory_line()

func create_trajectory_line():
	"""Create a single Line2D for the trajectory"""
	trajectory_line = Line2D.new()
	add_child(trajectory_line)
	trajectory_line.width = line_width
	trajectory_line.default_color = normal_color
	trajectory_line.antialiased = true

func predict_trajectory(start_position: Vector2, initial_velocity: Vector2):
	"""Predict trajectory using EXACT same gravity assist system as spacecraft"""
	if trajectory_line:
		trajectory_line.clear_points()
	
	# EXACT same time step as game physics
	var time_step = 1.0 / 60.0
	var total_steps = int(max_prediction_time / time_step)
	
	# Simulation state - IDENTICAL to spacecraft
	var sim_position = start_position
	var sim_velocity = initial_velocity
	var sim_gravity_assists = []  # Track active gravity assists like spacecraft does
	
	# Find all planets once
	var planets = find_all_planets()
	
	# Simulate step by step - EXACTLY like spacecraft
	for step in range(total_steps):
		# Check collision first
		var will_collide = false
		for planet in planets:
			if not planet or not is_instance_valid(planet):
				continue
			
			var distance_to_planet = sim_position.distance_to(planet.global_position)
			if distance_to_planet <= (planet.planet_radius + spacecraft_collision_radius):
				will_collide = true
				break
		
		# Add current point
		trajectory_line.add_point(to_local(sim_position))
		
		# Stop if collision
		if will_collide:
			trajectory_line.default_color = collision_color
			break
		
		# Check for entering new gravity assists (EXACTLY like spacecraft)
		for planet in planets:
			if not planet or not is_instance_valid(planet):
				continue
			
			var distance_to_planet = sim_position.distance_to(planet.global_position)
			
			# Check if entering gravity zone (and not already affecting this planet)
			if distance_to_planet <= planet.gravity_radius:
				var already_affecting = false
				for assist in sim_gravity_assists:
					if assist.planet == planet:
						already_affecting = true
						break
				
				if not already_affecting:
					# Create NEW gravity assist - EXACTLY like spacecraft does
					var new_assist = GravityAssist.new(planet, sim_velocity, sim_position)
					sim_gravity_assists.append(new_assist)
		
		# Apply ALL active gravity assists (EXACTLY like spacecraft)
		var total_gravity_force = Vector2.ZERO
		var has_gravity_assist = false
		
		for i in range(sim_gravity_assists.size() - 1, -1, -1):  # Reverse loop for safe removal
			var assist = sim_gravity_assists[i]
			
			# Apply gravity assist force - IDENTICAL to spacecraft.apply_gravity_assist()
			var gravity_force = assist.update_curve(time_step, sim_position)
			total_gravity_force += gravity_force
			has_gravity_assist = true
			
			# Check if spacecraft left this planet's gravity zone
			var distance_to_planet = sim_position.distance_to(assist.planet.global_position)
			if distance_to_planet > assist.planet.gravity_radius:
				# Remove this gravity assist
				sim_gravity_assists.remove_at(i)
		
		# Set color based on gravity state
		if has_gravity_assist:
			trajectory_line.default_color = gravity_color
		else:
			trajectory_line.default_color = normal_color
		
		# Apply gravity forces to velocity - IDENTICAL to spacecraft
		sim_velocity += total_gravity_force
		
		# Move position - IDENTICAL to spacecraft
		sim_position += sim_velocity * time_step
		
		# Bounds check
		if abs(sim_position.x) > 1000 or abs(sim_position.y) > 1000:
			break
		
		# Sample every few frames for performance
		if step % 2 != 0:
			continue

func find_all_planets() -> Array:
	"""Find all Planet nodes in the scene"""
	var planets = []
	
	# Use group method
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
	if trajectory_line:
		trajectory_line.clear_points()

func update_prediction(start_position: Vector2, initial_velocity: Vector2):
	"""Update prediction in real-time"""
	if is_predicting:
		predict_trajectory(start_position, initial_velocity)
