class_name GravityAssist
extends Resource

var planet: Planet
var is_active: bool = false

# Core settings - השתמש בערכים מ-PhysicsUtils
var collision_safety_distance: float = PhysicsUtils.COLLISION_SAFETY_DISTANCE
var emergency_force_multiplier: float = PhysicsUtils.EMERGENCY_FORCE_MULTIPLIER
var angle_correction_strength: float = PhysicsUtils.ANGLE_CORRECTION_STRENGTH
var optimal_angle_tolerance: float = PhysicsUtils.OPTIMAL_ANGLE_TOLERANCE
var magnet_strength: float = PhysicsUtils.MAGNET_STRENGTH

# Duration control
var predicted_orbit_duration: float = 0.0

# Internal state
var spacecraft_ref: Spacecraft = null
var entry_time: float = 0.0
var entry_speed: float = 0.0
var should_exit: bool = false
var ideal_orbit_radius: float = 0.0

func _init(p_planet: Planet, spacecraft: Spacecraft):
	planet = p_planet
	is_active = true
	var spacecraft_velocity = spacecraft.linear_velocity
	entry_speed = spacecraft_velocity.length()
	entry_time = 0.0
	should_exit = false
	
	if planet:
		# השתמש בפונקציה המאוחדת מ-PhysicsUtils
		predicted_orbit_duration = PhysicsUtils.calculate_orbit_duration(planet, spacecraft_velocity, spacecraft.global_position)
		ideal_orbit_radius = PhysicsUtils.calculate_orbit_radius(planet)
		spacecraft_ref = spacecraft

func update_curve(delta: float, spacecraft_pos: Vector2) -> Vector2:
	if not is_active or not planet or not spacecraft_ref:
		return Vector2.ZERO
	
	entry_time += delta
	check_exit_conditions()
	
	var to_planet = planet.global_position - spacecraft_pos
	var distance = to_planet.length()
	
	if distance < PhysicsUtils.MIN_DISTANCE_FOR_FORCE:
		return Vector2.ZERO
	
	# גרביטציה בסיסית
	var gravity_force = PhysicsUtils.calculate_gravity_force(spacecraft_pos, planet, delta)
	
	# תיקונים רק אם לא יוצאים
	var guidance_force = Vector2.ZERO
	if not should_exit:
		guidance_force += PhysicsUtils.calculate_collision_prevention(spacecraft_pos, distance, delta, planet)
		guidance_force += PhysicsUtils.calculate_angle_correction(spacecraft_ref.linear_velocity, to_planet, delta)
		guidance_force += PhysicsUtils.calculate_orbital_magnet(spacecraft_pos, distance, delta, planet)
		guidance_force += PhysicsUtils.calculate_gentle_speed_boost(spacecraft_ref.linear_velocity, entry_speed, distance, ideal_orbit_radius, delta)
	
	return gravity_force + guidance_force

func check_exit_conditions():
	if should_exit:
		return
	if entry_time >= predicted_orbit_duration:
		should_exit = true

func is_curve_complete() -> bool:
	return should_exit

func get_spacecraft_reference() -> Spacecraft:
	if not planet:
		return null
	var spacecrafts = planet.get_tree().get_nodes_in_group("Spacecrafts")
	return spacecrafts[0] if spacecrafts.size() > 0 else null
