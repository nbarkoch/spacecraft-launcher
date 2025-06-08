class_name PhysicsUtils

# Basic Constants
const TRAJECTORY_TIME_STEP: float = 1.0 / 60.0
const MAX_TRAJECTORY_STEPS: int = 140
const TRAJECTORY_POINT_INTERVAL: int = 2
const VELOCITY_DAMPING_PER_FRAME: float = 0.999
const MAX_SIMULATION_BOUNDS: float = 1000.0
const MAX_VELOCITY_LIMIT: float = 3000.0
const SPACECRAFT_COLLISION_RADIUS: float = 6.0

# =====================================================
# BASIC GRAVITY CALCULATION (same as original)
# =====================================================

static func apply_basic_gravity(position: Vector2, planet: Planet, delta: float) -> Vector2:
	"""Apply basic gravitational force - EXACT same as original"""
	var to_planet = planet.global_position - position
	var distance = to_planet.length()
	
	if distance < 1.0:
		return Vector2.ZERO
	
	# EXACT formula from original code
	var force_magnitude = planet.gravity_strength * delta * 60.0 / (distance * 0.01)
	var force_direction = to_planet.normalized()
	return force_direction * force_magnitude

# =====================================================
# PLANET UTILITIES (unchanged)
# =====================================================

static func find_all_planets(scene_tree: SceneTree) -> Array:
	"""Find all Planet nodes in the scene"""
	var planets = []
	var grouped_planets = scene_tree.get_nodes_in_group("Planets")
	if grouped_planets.size() > 0:
		return grouped_planets
	
	var game_scene = scene_tree.current_scene
	if game_scene:
		find_planets_recursive(game_scene, planets)
	
	return planets

static func find_planets_recursive(node: Node, planets: Array):
	"""Recursively search for Planet nodes"""
	if node.has_method("_on_gravity_zone_body_entered") and node.has_method("_on_planet_area_body_entered"):
		if "gravity_radius" in node and "planet_radius" in node and "gravity_strength" in node:
			planets.append(node)
	
	for child in node.get_children():
		find_planets_recursive(child, planets)

static func get_planet_at_position(pos: Vector2, planets: Array) -> Planet:
	"""Check if position is within any planet's gravity zone"""
	for planet in planets:
		if not planet or not is_instance_valid(planet):
			continue
		
		var distance = pos.distance_to(planet.global_position)
		if distance <= planet.gravity_radius:
			return planet
	return null

# =====================================================
# TRAJECTORY PREDICTION (simplified)
# =====================================================

static func simulate_physics_step(position: Vector2, velocity: Vector2, planets: Array, delta: float) -> Dictionary:
	"""Simulate one physics step - BASIC VERSION"""
	var new_velocity = velocity * VELOCITY_DAMPING_PER_FRAME
	var total_force = Vector2.ZERO
	var current_planet = null
	
	# Find planet affecting this position
	for planet in planets:
		if not planet or not is_instance_valid(planet):
			continue
		
		var distance = position.distance_to(planet.global_position)
		if distance <= planet.gravity_radius:
			current_planet = planet
			# Use basic gravity only
			total_force += apply_basic_gravity(position, planet, delta)
			break
	
	# Apply forces
	new_velocity += total_force
	var new_position = position + new_velocity * delta
	
	# Check for collision
	var collision = false
	if current_planet:
		var collision_distance = new_position.distance_to(current_planet.global_position)
		if collision_distance <= (current_planet.planet_radius + SPACECRAFT_COLLISION_RADIUS):
			collision = true
	
	return {
		"position": new_position,
		"velocity": new_velocity,
		"collision": collision,
		"planet": current_planet
	}
