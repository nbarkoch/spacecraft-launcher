# scripts/orbit_config.gd (WITH PLANET PARAMETER SUPPORT)
class_name GravityAssist
extends Resource

var planet: Planet
var is_active: bool = false

# Settings from planet
var magnet_strength: float = 1.0
var collision_safety_distance: float = 0.0
var emergency_force_multiplier: float = 12.0
var angle_correction_strength: float = 15.0
var optimal_angle_tolerance: float = 7.0

# Internal state
var spacecraft_ref: Spacecraft = null
var entry_time: float = 0.0
var entry_velocity: Vector2 = Vector2.ZERO
var entry_position: Vector2 = Vector2.ZERO
var entry_speed: float = 0.0
var entry_angle_to_center: float = 0.0
var should_exit: bool = false
var max_orbit_time: float = 4.0
var ideal_orbit_radius: float = 0.0

# Exit calculation parameters
var natural_exit_energy: float = 0.0  # "Energy" needed to escape
var accumulated_guidance: float = 0.0  # How much guidance we've given

func _init(p_planet: Planet, spacecraft_velocity: Vector2, spacecraft_position: Vector2):
	planet = p_planet
	is_active = true
	entry_velocity = spacecraft_velocity
	entry_position = spacecraft_position
	entry_speed = spacecraft_velocity.length()
	entry_time = 0.0
	should_exit = false
	accumulated_guidance = 0.0
	
	if planet:
		# Get settings from planet
		magnet_strength = planet.magnet_strength
		collision_safety_distance = planet.collision_safety_distance
		emergency_force_multiplier = planet.emergency_force_multiplier
		angle_correction_strength = planet.angle_correction_strength
		optimal_angle_tolerance = planet.optimal_angle_tolerance
		
		ideal_orbit_radius = planet.planet_radius + (planet.gravity_radius - planet.planet_radius) * 0.6
		spacecraft_ref = get_spacecraft_reference()
		
		# Calculate entry conditions for smart exit
		calculate_entry_conditions()
		calculate_natural_exit_energy()

func calculate_entry_conditions():
	"""Analyze entry conditions for smart exit calculation"""
	# Calculate angle of entry relative to planet center
	var to_planet = planet.global_position - entry_position
	entry_angle_to_center = entry_velocity.angle_to(to_planet)
	
	# Normalize angle to 0-180 degrees (how "head-on" vs "tangential" the entry is)
	entry_angle_to_center = abs(entry_angle_to_center)
	if entry_angle_to_center > PI:
		entry_angle_to_center = 2 * PI - entry_angle_to_center

func calculate_natural_exit_energy():
	"""Calculate how much 'energy' is needed for natural exit based on entry"""
	# Base energy from entry speed (faster = easier to escape)
	var speed_factor = clamp(entry_speed / 100.0, 0.3, 2.0)
	
	# Angle factor (tangential entry = easier escape, head-on = harder)
	var angle_factor = 1.0 + (entry_angle_to_center / PI) * 2.0  # 1.0-3.0
	
	# Distance factor (closer entry = more energy gained)
	var entry_distance = entry_position.distance_to(planet.global_position)
	var distance_factor = clamp(planet.gravity_radius / entry_distance, 0.5, 2.0)
	
	# Final natural exit energy (this is what we need to "accumulate" before exit)
	natural_exit_energy = 100.0 * angle_factor / (speed_factor * distance_factor)
	natural_exit_energy = clamp(natural_exit_energy, 50.0, 400.0)
	
	print("Entry analysis - Speed: ", entry_speed, " Angle: ", rad_to_deg(entry_angle_to_center), 
		  " Exit energy needed: ", natural_exit_energy)

func calculate_exit_time():
	"""Fallback time-based exit"""
	max_orbit_time = clamp(200.0 / max(entry_speed, 30.0), 2.0, 8.0)

func update_curve(delta: float, spacecraft_pos: Vector2) -> Vector2:
	if not is_active or not planet or not spacecraft_ref:
		return Vector2.ZERO
	
	entry_time += delta
	check_exit_conditions()
	
	var to_planet = planet.global_position - spacecraft_pos
	var distance = to_planet.length()
	
	if distance < 1.0:
		return Vector2.ZERO
	
	# Base gravity (unchanged)
	var gravity_force = calculate_gravity(to_planet, distance, delta)
	
	# Guidance forces (reduced when should exit)
	var guidance_force = Vector2.ZERO
	if not should_exit:
		# Collision prevention (if enabled)
		if collision_safety_distance > 0:
			guidance_force += collision_prevention(spacecraft_pos, distance, delta)
		# Strong angle correction to golden path
		guidance_force += angle_correction(spacecraft_pos, to_planet, delta)
		# Orbital magnet
		guidance_force += orbital_magnet(spacecraft_pos, distance, delta)
		
		# Track how much guidance we're giving (for exit calculation)
		accumulated_guidance += guidance_force.length() * delta
		
	else:
		# Reduce guidance when exiting
		guidance_force = angle_correction(spacecraft_pos, to_planet, delta) * 0.1
	
	return gravity_force + guidance_force

func calculate_gravity(to_planet: Vector2, distance: float, delta: float) -> Vector2:
	var force_magnitude = planet.gravity_strength * delta * 60.0 / (distance * 0.01)
	return to_planet.normalized() * force_magnitude

func collision_prevention(spacecraft_pos: Vector2, distance: float, delta: float) -> Vector2:
	var distance_from_surface = distance - planet.planet_radius
	if distance_from_surface > collision_safety_distance:
		return Vector2.ZERO
	
	var danger_factor = 1.0 - (distance_from_surface / collision_safety_distance)
	var push_direction = (spacecraft_pos - planet.global_position).normalized()
	return push_direction * emergency_force_multiplier * danger_factor * delta * 60.0

func angle_correction(spacecraft_pos: Vector2, to_planet: Vector2, delta: float) -> Vector2:
	var velocity = spacecraft_ref.linear_velocity
	var speed = velocity.length()
	
	if speed < 20.0:
		return Vector2.ZERO
	
	var radial_dir = to_planet.normalized()
	var velocity_dir = velocity.normalized()
	
	# Calculate how radial the movement is
	var radial_component = abs(radial_dir.dot(velocity_dir))
	
	# Only correct if too radial (using planet's tolerance)
	var angle_degrees = rad_to_deg(acos(clamp(1.0 - radial_component, 0.0, 1.0)))
	if angle_degrees < optimal_angle_tolerance:
		return Vector2.ZERO
	
	# Calculate ideal tangential direction
	var tangential = Vector2(-radial_dir.y, radial_dir.x)
	if velocity.dot(tangential) < 0:
		tangential = -tangential
	
	# Apply correction using planet's strength
	var correction = (tangential - velocity_dir).normalized()
	var strength = angle_correction_strength * (radial_component - 0.2) * delta * 60.0
	
	return correction * strength

func orbital_magnet(spacecraft_pos: Vector2, distance: float, delta: float) -> Vector2:
	var distance_from_ideal = distance - ideal_orbit_radius
	
	if abs(distance_from_ideal) > 30.0:
		return Vector2.ZERO
	
	var direction = Vector2.ZERO
	if distance_from_ideal > 0:
		direction = (planet.global_position - spacecraft_pos).normalized()  # Pull inward
	else:
		direction = (spacecraft_pos - planet.global_position).normalized()  # Push outward
	
	var strength = magnet_strength * (1.0 - abs(distance_from_ideal) / 30.0) * delta * 60.0
	return direction * strength

func check_exit_conditions():
	"""Smart exit based on entry conditions and accumulated guidance"""
	if should_exit:
		return
	
	# Primary exit condition: Have we given enough guidance energy?
	if accumulated_guidance >= natural_exit_energy:
		should_exit = true
		print("Smart exit triggered - guidance energy reached: ", accumulated_guidance, "/", natural_exit_energy)
		return
	
	# Secondary exit condition: Moving away at good speed
	var velocity = spacecraft_ref.linear_velocity
	var speed = velocity.length()
	var to_planet = planet.global_position - spacecraft_ref.global_position
	var moving_away = to_planet.dot(velocity) < 0
	
	# If moving away fast AND we've given at least 50% of needed guidance
	if moving_away and speed > 60.0 and accumulated_guidance >= natural_exit_energy * 0.5:
		should_exit = true
		print("Smart exit triggered - moving away with sufficient guidance")
		return
	
	# Fallback: Time-based exit (emergency)
	if entry_time >= max_orbit_time:
		should_exit = true
		print("Fallback exit triggered - time limit reached")
		return
	
	# Emergency exit: stuck too long
	if entry_time > max_orbit_time * 2.0:
		should_exit = true
		print("Emergency exit triggered - stuck too long")

func is_curve_complete() -> bool:
	return should_exit or entry_time > max_orbit_time * 1.5

func get_exit_velocity() -> Vector2:
	return Vector2.ZERO

func get_spacecraft_reference() -> Spacecraft:
	if not planet:
		return null
	var spacecrafts = planet.get_tree().get_nodes_in_group("Spacecrafts")
	return spacecrafts[0] if spacecrafts.size() > 0 else null
