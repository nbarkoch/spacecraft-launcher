extends RigidBody2D
class_name Spacecraft

# Gravity assist (לפיזיקה ישנה)
var gravity_assist: GravityAssist = null
var is_dead = false
var trail: SpacecraftTrail = null

# פיזיקה מתקדמת
var use_advanced_physics: bool = true
var physics_position: Vector2
var physics_velocity: Vector2
var physics_rotation: float = 0.0
var current_gravity_assist_planet = null
var gravity_assist_time: float = 0.0
var is_physics_active: bool = false

func stop():
	self.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	self.freeze = true
	self.gravity_scale = 0
	is_physics_active = false
	physics_velocity = Vector2.ZERO  # עצור מהירות מיידית
	linear_velocity = Vector2.ZERO   # עצור גם את ה-RigidBody2D
	
	if trail:
		trail.start_dissipation()

func _ready():
	stop()
	add_to_group("Spacecrafts")
	await get_tree().process_frame
	setup_trail()
	setup_debug_overlay()

func setup_trail():
	trail = SpacecraftTrail.new()
	get_tree().current_scene.add_child(trail)
	trail.spacecraft_ref = self

func _physics_process(delta):
	if use_advanced_physics and is_physics_active:
		# פיזיקה מתקדמת עם כל האינטראקציות
		simulate_advanced_physics(delta)
	
	update_debug_info()
	update_fire_effect()

func simulate_advanced_physics(delta):
	"""סימולציה פיזיקה מתקדמת עם כל האינטראקציות"""
	if not is_physics_active:
		return
	
	# בדוק גבולות לפני כל החישובים
	if abs(physics_position.x) > 200.0 or abs(physics_position.y) > 400.0:
		destroy()
		return
	
	# איסוף אובייקטים
	var planets = get_tree().get_nodes_in_group("Planets")
	var meteoroids = collect_meteoroids()
	var portals = collect_portals()
	var black_holes = collect_black_holes()
	
	var total_force = Vector2.ZERO
	
	# 1. כוחי כבידה עם gravity assist
	var gravity_result = calculate_gravity_forces_for_spacecraft(planets, delta)
	total_force += gravity_result.force
	current_gravity_assist_planet = gravity_result.current_assist
	gravity_assist_time = gravity_result.assist_time
	
	# בדוק התנגשות עם כוכבי לכת
	if check_planet_collision_for_spacecraft(planets):
		destroy()
		return
	
	# 2. מטאורים
	var meteroid_result = calculate_meteroid_interactions_for_spacecraft(meteoroids, delta)
	total_force += meteroid_result.force
	
	# 3. פורטלים
	var portal_result = check_portal_teleportation_for_spacecraft(portals)
	if portal_result.teleported:
		physics_position = portal_result.new_position
		global_position = physics_position
		return
	
	# 4. חורים שחורים
	var blackhole_result = calculate_blackhole_forces_for_spacecraft(black_holes, delta)
	total_force += blackhole_result.force
	if not blackhole_result.is_alive:
		destroy()
		return
	
	# עדכן פיזיקה
	physics_velocity *= 0.999  # damping
	physics_velocity += total_force
	physics_position += physics_velocity * delta
	
	# עדכן סיבוב - תיקון הזוית!
	if physics_velocity.length() > 5.0:  # רק אם יש מהירות מינימלית
		var target_rotation = physics_velocity.angle() + PI/2
		# שנה מהר יותר את הזוית אבל לא מיידי
		physics_rotation = lerp_angle(physics_rotation, target_rotation, 0.3)
	
	# העבר לחללית
	global_position = physics_position
	rotation = physics_rotation
	linear_velocity = physics_velocity

func collect_meteoroids() -> Array:
	return get_tree().get_nodes_in_group("Meteoroids")

func collect_portals() -> Array:
	return get_tree().get_nodes_in_group("Portals")

func collect_black_holes() -> Array:
	return get_tree().get_nodes_in_group("BlackHoles")

func calculate_gravity_forces_for_spacecraft(planets: Array, delta: float) -> Dictionary:
	var result = {"force": Vector2.ZERO, "current_assist": current_gravity_assist_planet, "assist_time": gravity_assist_time}
	
	for planet in planets:
		if not planet or not is_instance_valid(planet):
			continue
		
		var distance = physics_position.distance_to(planet.global_position)
		if distance <= planet.gravity_radius and distance > 1.0:
			var to_planet = planet.global_position - physics_position
			
			# כוח כבידה בסיסי
			var base_force_magnitude = (planet.gravity_strength * delta * 60.0) / (distance * 0.01)
			var base_force = to_planet.normalized() * base_force_magnitude
			
			# gravity assist logic
			if current_gravity_assist_planet == planet:
				# המשך gravity assist
				var orbital_direction = Vector2(-to_planet.y, to_planet.x).normalized()
				var assist_strength = 50.0 * (1.0 + gravity_assist_time * 0.5)
				var assist_force = orbital_direction * assist_strength * delta
				result.force = base_force + assist_force
				result.assist_time = gravity_assist_time + delta
				
				# סיום gravity assist
				if gravity_assist_time > 2.0 or distance > planet.gravity_radius * 0.8:
					result.current_assist = null
					result.assist_time = 0.0
			else:
				# בדוק התחלת gravity assist
				var tangential_velocity = calculate_tangential_velocity_for_spacecraft(planet)
				if distance <= planet.gravity_radius * 0.6 and tangential_velocity > 50.0:
					result.current_assist = planet
					result.assist_time = 0.0
				
				result.force = base_force
			
			break
	
	return result

func calculate_tangential_velocity_for_spacecraft(planet) -> float:
	var to_planet = planet.global_position - physics_position
	var radial_direction = to_planet.normalized()
	var velocity_direction = physics_velocity.normalized() if physics_velocity.length() > 0 else Vector2.ZERO
	var dot_product = radial_direction.dot(velocity_direction)
	var tangential_component = sqrt(max(0, 1.0 - dot_product * dot_product))
	return tangential_component * physics_velocity.length()

func check_planet_collision_for_spacecraft(planets: Array) -> bool:
	for planet in planets:
		if not planet or not is_instance_valid(planet):
			continue
		var distance = physics_position.distance_to(planet.global_position)
		if distance <= (planet.planet_radius + 6.0):
			return true
	return false

func calculate_meteroid_interactions_for_spacecraft(meteoroids: Array, delta: float) -> Dictionary:
	var result = {"force": Vector2.ZERO}
	
	for meteroid in meteoroids:
		if not meteroid or not is_instance_valid(meteroid):
			continue
		
		# חישוב התנגשות
		var distance = physics_position.distance_to(meteroid.global_position)
		if distance <= (13.0 + 6.0):  # התנגשות
			# חשב כוח התנגשות על החללית
			var collision_direction = (physics_position - meteroid.global_position).normalized()
			
			# המסה של החללית קטנה יותר - היא מקבלת יותר כוח
			var spacecraft_mass = 1.0
			var meteroid_mass_actual = meteroid.meteroid_physics_mass  # השתמש במסה שלנו
			var momentum_transfer = (2.0 * meteroid_mass_actual) / (spacecraft_mass + meteroid_mass_actual)
			var collision_strength = 200.0 * momentum_transfer
			
			result.force += collision_direction * collision_strength
			
			# הפעל אפקט על המטאור עם הפיזיקה שלנו
			meteroid.apply_collision_effect(physics_velocity)
			print("Spacecraft collided with meteroid! Both objects affected by our physics.")
			break
	
	return result

func check_portal_teleportation_for_spacecraft(portals: Array) -> Dictionary:
	var result = {"teleported": false, "new_position": physics_position}
	
	for portal in portals:
		if not portal or not is_instance_valid(portal):
			continue
		
		var distance = physics_position.distance_to(portal.global_position)
		if distance <= 13.0:
			var target_portal = find_target_portal_for_spacecraft(portal, portals)
			if target_portal:
				result.teleported = true
				result.new_position = target_portal.global_position
			break
	
	return result

func find_target_portal_for_spacecraft(source_portal, all_portals: Array):
	var portal_group = source_portal.portal_group if "portal_group" in source_portal else "portal1"
	for portal in all_portals:
		if portal != source_portal and "portal_group" in portal and portal.portal_group == portal_group:
			return portal
	return null

func calculate_blackhole_forces_for_spacecraft(black_holes: Array, delta: float) -> Dictionary:
	var result = {"force": Vector2.ZERO, "is_alive": true}
	
	for black_hole in black_holes:
		if not black_hole or not is_instance_valid(black_hole):
			continue
		
		var distance = physics_position.distance_to(black_hole.global_position)
		
		if distance <= 10.0:  # נפילה לחור
			result.is_alive = false
			return result
		
		if "gravity_radius" in black_hole and distance <= black_hole.gravity_radius:
			var to_blackhole = black_hole.global_position - physics_position
			var blackhole_strength = black_hole.gravity_strength if "gravity_strength" in black_hole else 1000.0
			var blackhole_force = (blackhole_strength * 2.0) / distance
			result.force += to_blackhole.normalized() * blackhole_force * delta
			
			# עצירת בריחה
			var velocity_toward = physics_velocity.dot(to_blackhole.normalized())
			if velocity_toward < 0:
				result.force += -physics_velocity * 0.1
			
			break
	
	return result

func release():
	"""Release spacecraft from slingshot"""
	print("Releasing spacecraft, advanced physics: ", use_advanced_physics)
	
	if use_advanced_physics:
		# הכן פיזיקה מתקדמת
		self.freeze = true
		physics_position = global_position
		physics_velocity = linear_velocity
		physics_rotation = rotation
		is_physics_active = true
	else:
		# הפיזיקה הישנה
		self.freeze = false
	
	trail.reset_trail()

func apply_impulse_predictable(impulse: Vector2):
	"""הפעל דחף עם פיזיקה מתקדמת"""
	if use_advanced_physics:
		physics_position = global_position
		physics_velocity = impulse
		physics_rotation = rotation
		is_physics_active = true
		print("Started advanced physics with impulse: ", impulse)
	else:
		apply_impulse(impulse)

func enter_gravity_assist(assist: GravityAssist):
	"""Start gravity assist - רק לפיזיקה ישנה"""
	if not use_advanced_physics:
		gravity_assist = assist

func apply_gravity_assist(delta):
	"""Apply gravity assist - רק לפיזיקה ישנה"""
	if not gravity_assist or is_dead or use_advanced_physics:
		return
	
	var gravity_force = gravity_assist.update_curve(delta, global_position)
	linear_velocity += gravity_force
	
	# Rotate spacecraft
	if linear_velocity.length() > 0:
		var movement_direction = linear_velocity.normalized()
		rotation = movement_direction.angle() + PI/2

func exit_gravity_assist():
	"""Stop gravity assist"""
	if gravity_assist:
		gravity_assist.is_active = false
		gravity_assist = null

func destroy():
	"""Destroy spacecraft when it hits a planet"""
	if is_dead:
		return
	var explosion_position = global_position
	var scene_parent = get_tree().current_scene
	
	# עצור פיזיקה
	is_physics_active = false
	is_dead = true
	# Create explosion effect
	SpacecraftExplosion.create_explosion_at(explosion_position, scene_parent)
	
	Input.vibrate_handheld(200)
	RuinedSpacecraft.create_at_position(explosion_position, scene_parent, rotation)
	
	visible = false
	freeze = true
	linear_velocity = Vector2.ZERO

	await get_tree().create_timer(0.3).timeout
	LevelManager.level_failed()

var debug_label: Label
var debug_enabled: bool = false

func setup_debug_overlay():
	if not debug_enabled:
		return
		
	debug_label = Label.new()
	debug_label.position = Vector2(10, 10)
	debug_label.size = Vector2(300, 200)
	debug_label.add_theme_color_override("font_color", Color.WHITE)
	debug_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	debug_label.add_theme_constant_override("shadow_offset_x", 1)
	debug_label.add_theme_constant_override("shadow_offset_y", 1)
	
	var canvas_layer = CanvasLayer.new()
	get_tree().current_scene.add_child(canvas_layer)
	canvas_layer.add_child(debug_label)
	
func update_debug_info():
	if not debug_enabled or not debug_label:
		return
		
	var debug_text = ""
	debug_text += "Physics Mode: " + ("Advanced" if use_advanced_physics else "Godot") + "\n"
	
	if use_advanced_physics and is_physics_active:
		debug_text += "Velocity: " + str(physics_velocity.round()) + "\n"
		debug_text += "Speed: " + str(round(physics_velocity.length())) + "\n"
		debug_text += "Position: " + str(physics_position.round()) + "\n"
		debug_text += "Gravity Assist: " + str(current_gravity_assist_planet.name if current_gravity_assist_planet else "None") + "\n"
		debug_text += "Assist Time: " + str(round(gravity_assist_time * 10) / 10.0) + "s\n"
	else:
		debug_text += "Velocity: " + str(linear_velocity.round()) + "\n"
		debug_text += "Speed: " + str(round(linear_velocity.length())) + "\n"
		debug_text += "Position: " + str(global_position.round()) + "\n"
	
	debug_label.text = debug_text

func reset(new_rotation, new_position):
	exit_gravity_assist()
	global_position = new_position
	rotation = new_rotation
	
	# איפוס פיזיקה מתקדמת
	is_physics_active = false
	physics_position = new_position
	physics_velocity = Vector2.ZERO
	physics_rotation = new_rotation
	current_gravity_assist_planet = null
	gravity_assist_time = 0.0
	
	var body_rid = get_rid()
	var new_transform = Transform2D(rotation, new_position)
	PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, new_transform)
	PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
	PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	is_dead = false
	visible = true

@onready var fire_effect: SpacecraftFireEffect = $SpacecraftFireEffect

func update_fire_effect():
	"""Update fire effect based on spacecraft movement"""
	var current_speed = 0.0
	
	if use_advanced_physics and is_physics_active:
		current_speed = physics_velocity.length()
	else:
		current_speed = linear_velocity.length()
	
	var is_moving = current_speed > 10.0
	var should_be_active = is_moving and (is_physics_active or not freeze)
	
	if should_be_active and not fire_effect.is_fire_active():
		fire_effect.start_fire()
	elif not should_be_active and fire_effect.is_fire_active():
		fire_effect.stop_fire()

# Toggle physics mode for testing
func toggle_physics_mode():
	use_advanced_physics = !use_advanced_physics
	print("Spacecraft physics mode: ", "Advanced" if use_advanced_physics else "Godot")
