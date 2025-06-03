# scripts/orbit_config.gd (Gentle Breeze Orbital Guidance)
class_name GravityAssist
extends Resource

var planet: Planet
var is_active: bool = false
var ideal_orbit_radius: float

# Ultra-gentle, frequent nudging
var safety_distance: float = 10.0      
var orbital_zone: float = 20.0         
var breeze_strength: float = 3.0       # TINY force - like a gentle breeze
var debug_enabled: bool = true

# No timing restrictions - constant gentle nudging
var smoothing_factor: float = 0.9      # Smooth force transitions

func _init(p_planet: Planet, spacecraft_velocity: Vector2, spacecraft_position: Vector2):
	planet = p_planet
	is_active = true
	
	if planet:
		ideal_orbit_radius = planet.planet_radius + (planet.gravity_radius - planet.planet_radius) / 2.0
		if debug_enabled:
			print("DEBUG: Planet radius: ", planet.planet_radius, " Gravity radius: ", planet.gravity_radius, " Ideal orbit: ", ideal_orbit_radius)

func update_curve(delta: float, spacecraft_pos: Vector2) -> Vector2:
	"""Apply gravity + constant gentle orbital breeze"""
	if not is_active or not planet:
		return Vector2.ZERO
	
	var to_planet = planet.global_position - spacecraft_pos
	var distance = to_planet.length()
	
	if distance < 1.0:
		return Vector2.ZERO
	
	# Base gravitational force
	var force_magnitude = planet.gravity_strength * delta * 60.0 / (distance * 0.01)
	var force_direction = to_planet.normalized()
	var gravity_force = force_direction * force_magnitude
	
	# Add constant gentle breeze
	var breeze_force = calculate_orbital_breeze(spacecraft_pos, delta)
	
	# Minimal debug - only occasionally
	if debug_enabled and randf() < 0.02:
		var distance_from_surface = distance - planet.planet_radius
		var distance_from_ideal = abs(distance - ideal_orbit_radius)
		print("DEBUG: Surface=", round(distance_from_surface), " Ideal_diff=", round(distance_from_ideal), " Breeze=", breeze_force.round())
	
	return gravity_force + breeze_force

func calculate_orbital_breeze(spacecraft_pos: Vector2, delta: float) -> Vector2:
	"""Constant, ultra-gentle orbital guidance like a breeze"""
	var spacecraft = get_spacecraft_reference(spacecraft_pos)
	if not spacecraft:
		return Vector2.ZERO
	
	var to_planet = planet.global_position - spacecraft_pos
	var current_distance = to_planet.length()
	var distance_from_surface = current_distance - planet.planet_radius
	var radial_direction = to_planet.normalized()
	var velocity = spacecraft.linear_velocity
	var speed = velocity.length()
	
	# Safety breeze - gentle push away when close (ALWAYS ACTIVE when close)
	var safety_breeze = Vector2.ZERO
	if distance_from_surface < safety_distance:
		var safety_factor = 1.0 - (distance_from_surface / safety_distance)
		safety_breeze = -radial_direction * breeze_strength * 2.0 * safety_factor * delta * 60.0
	
	# Orbital guidance breeze (ALWAYS ACTIVE when in zone)
	var orbital_breeze = Vector2.ZERO
	var distance_from_ideal = abs(current_distance - ideal_orbit_radius)
	
	if distance_from_ideal <= orbital_zone and speed > 20.0:
		# Check if moving somewhat tangentially
		var velocity_direction = velocity.normalized() if speed > 0 else Vector2.ZERO
		var radial_component = abs(radial_direction.dot(velocity_direction)) if speed > 0 else 1.0
		
		# More forgiving tangential check
		if radial_component < 0.8:  # Allow more radial movement
			# Determine breeze direction
			var breeze_direction: Vector2
			if current_distance > ideal_orbit_radius:
				breeze_direction = radial_direction  # Gentle inward breeze
			else:
				breeze_direction = -radial_direction  # Gentle outward breeze
			
			# Calculate ultra-gentle breeze factors
			var distance_factor = (orbital_zone - distance_from_ideal) / orbital_zone  # 0-1
			var tangential_factor = (1.0 - radial_component) * 2.0  # Boost tangential bonus
			var speed_factor = clamp(speed / 100.0, 0.2, 1.0)  # Scale with speed
			
			# Keep factors reasonable
			var total_factor = distance_factor * tangential_factor * speed_factor
			total_factor = clamp(total_factor, 0.1, 1.0)
			
			# Apply tiny breeze force
			orbital_breeze = breeze_direction * breeze_strength * total_factor * delta * 60.0
	
	# Combine breezes
	var total_breeze = safety_breeze + orbital_breeze
	
	# Ultra-conservative force limit - much smaller than before
	var max_breeze = speed * 0.015  # Only 1.5% of current speed!
	if total_breeze.length() > max_breeze:
		total_breeze = total_breeze.normalized() * max_breeze
	
	return total_breeze

func get_spacecraft_reference(spacecraft_pos: Vector2) -> Spacecraft:
	"""Find spacecraft"""
	if not planet:
		return null
	
	var spacecrafts = planet.get_tree().get_nodes_in_group("Spacecrafts")
	if spacecrafts.size() == 0:
		return null
	
	return spacecrafts[0] as Spacecraft

func is_curve_complete() -> bool:
	return false

func get_exit_velocity() -> Vector2:
	return Vector2.ZERO

# Quick tuning functions
func make_even_gentler():
	breeze_strength = 1.5
	print("DEBUG: Made breeze even gentler!")

func make_slightly_stronger():
	breeze_strength = 5.0
	print("DEBUG: Made breeze slightly stronger!")

func set_breeze_strength(strength: float):
	breeze_strength = strength
	print("DEBUG: Set breeze strength to ", strength)
