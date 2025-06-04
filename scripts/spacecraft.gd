extends RigidBody2D
class_name Spacecraft

# Gravity assist
var gravity_assist: GravityAssist = null
var is_dead = false
var trail: SpacecraftTrail = null

func stop():
	self.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	self.freeze = true
	self.gravity_scale = 0
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
	trail.z_index = -1
	get_tree().current_scene.add_child(trail)
	trail.spacecraft_ref = self

	
func _physics_process(delta):
	# Store reference to avoid null issues during the frame
	var current_assist = gravity_assist
	
	# Only apply gravity assist if we have one
	if current_assist:
		apply_gravity_assist(delta)
		
		# FIXED: Check if gravity assist should be terminated (safe check)
		if current_assist == gravity_assist and current_assist.is_curve_complete():
			print("Gravity assist completed - forcing exit")
			exit_gravity_assist()
	
	update_debug_info()

func release():
	"""Release spacecraft from slingshot"""
	self.freeze = false
	trail.reset_trail()
	

func enter_gravity_assist(assist: GravityAssist):
	"""Start gravity assist"""
	gravity_assist = assist

func apply_gravity_assist(delta):
	if not gravity_assist or is_dead:
		return
	
	var gravity_force = gravity_assist.update_curve(delta, global_position)
	linear_velocity += gravity_force
	
	# Rotate spacecraft
	if linear_velocity.length() > 0:
		var movement_direction = linear_velocity.normalized()
		rotation = movement_direction.angle() + PI/2

func exit_gravity_assist():
	"""Stop gravity assist - IMPROVED VERSION"""
	if gravity_assist:
		gravity_assist.is_active = false
		gravity_assist = null

func destroy():
	"""Destroy spacecraft when it hits a planet"""
	print("Spacecraft destroyed!")
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
	
	# Add to the scene tree at canvas layer level
	var canvas_layer = CanvasLayer.new()
	get_tree().current_scene.add_child(canvas_layer)
	canvas_layer.add_child(debug_label)
	
func update_debug_info():
	if not debug_enabled or not debug_label:
		return
		
	var debug_text = ""
	debug_text += "Velocity: " + str(linear_velocity.round()) + "\n"
	debug_text += "Speed: " + str(round(linear_velocity.length())) + "\n"
	debug_text += "Position: " + str(global_position.round()) + "\n"
	
	if gravity_assist and gravity_assist.planet:
		var planet = gravity_assist.planet
		var distance_to_planet = global_position.distance_to(planet.global_position)
		var ideal_orbit = gravity_assist.ideal_orbit_radius
		var distance_from_ideal = abs(distance_to_planet - ideal_orbit)
		
		debug_text += "=== GRAVITY ASSIST ACTIVE ===\n"
		debug_text += "Time in orbit: " + str(round(gravity_assist.entry_time * 10) / 10.0) + "s\n"
		debug_text += "Initial prediction: " + str(round(gravity_assist.predicted_orbit_duration * 10) / 10.0) + "s\n"
		debug_text += "Current prediction: " + str(round(gravity_assist.get_current_predicted_duration() * 10) / 10.0) + "s\n"
		debug_text += "Time remaining: " + str(round((gravity_assist.get_current_predicted_duration() - gravity_assist.entry_time) * 10) / 10.0) + "s\n"
		debug_text += "Should exit: " + str(gravity_assist.should_exit) + "\n"
		debug_text += "Distance to planet: " + str(round(distance_to_planet)) + "\n"
		debug_text += "Ideal orbit radius: " + str(round(ideal_orbit)) + "\n"
		
		# Check tangential movement
		var to_planet = planet.global_position - global_position
		var radial_dir = to_planet.normalized()
		var vel_dir = linear_velocity.normalized() if linear_velocity.length() > 0 else Vector2.ZERO
		var dot_product = abs(radial_dir.dot(vel_dir)) if vel_dir != Vector2.ZERO else 0
		
		debug_text += "Tangential factor: " + str(round(dot_product * 100) / 100.0) + "\n"
		debug_text += "(0.0 = perfect tangential, 1.0 = radial)\n"
	else:
		debug_text += "No gravity assist active"
	
	debug_label.text = debug_text

func reset(new_rotation, new_position):
	exit_gravity_assist()
	global_position = new_position
	rotation = new_rotation
	var body_rid = get_rid()
	var new_transform = Transform2D(rotation, new_position)
	PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, new_transform)
	PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
	PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	is_dead = false
