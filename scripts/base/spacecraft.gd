extends RigidBody2D
class_name Spacecraft

const MOVE_THRESHOLD: float = 1.0    # px/frame — below this, sprite takes control of velocity
const SPEED_THRESHOLD: float = 100.0   # px/s — spacecraft aspires to reach this; above it, velocity leads sprite
const ANGLE_THRESHOLD: float = 0.75    # dot-product boundary: 0.0 = 90°, 0.5 = 60°, -0.5 = 120°
# Advanced physics system only
var physics_position: Vector2
var physics_velocity: Vector2
var physics_rotation: float = 0.0
var current_gravity_assist_planet = null
var gravity_assist_time: float = 0.0
var is_physics_active: bool = false
var propulsion_speed: float = 0.0
var thrust_rotation: float = 0.0

# Core state
var is_dead = false
var trail: SpacecraftTrail = null

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

func stop():
	"""Stop all movement and disable physics"""
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	gravity_scale = 0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	is_physics_active = false
	physics_velocity = Vector2.ZERO
	propulsion_speed = 0.0
	thrust_rotation = 0.0

	if trail:
		trail.start_dissipation()

func _physics_process(delta):
	if is_physics_active:
		simulate_advanced_physics(delta)

	update_debug_info()
	update_fire_effect()

func simulate_advanced_physics(delta):
	"""Advance one physics step using the shared static simulation."""
	if not is_physics_active:
		return

	var planets = get_tree().get_nodes_in_group("Planets")
	var meteoroids = get_tree().get_nodes_in_group("Meteoroids")
	var portals = get_tree().get_nodes_in_group("Portals")
	var black_holes = get_tree().get_nodes_in_group("BlackHoles")

	var pre_vel = physics_velocity
	var state = Spacecraft.step_physics(
		physics_position, physics_velocity,
		current_gravity_assist_planet, gravity_assist_time,
		delta, planets, meteoroids, portals, black_holes,
		thrust_rotation, propulsion_speed
	)

	if not state.alive:
		destroy()
		return

	if state.collided_meteroid and is_instance_valid(state.collided_meteroid):
		if state.collided_meteroid.has_method("apply_collision_effect"):
			# Use pre-step position to compute collision normal
			var col_dir = (physics_position - state.collided_meteroid.global_position).normalized()
			var approach = pre_vel.dot(-col_dir)
			if approach > 0:
				var mult = state.collided_meteroid.collision_impulse_multiplier if "collision_impulse_multiplier" in state.collided_meteroid else 0.5
				state.collided_meteroid.apply_collision_effect(-col_dir * approach * mult)

	physics_position = state.pos
	physics_velocity = state.vel
	thrust_rotation = state.sc_rotation
	physics_rotation = thrust_rotation
	current_gravity_assist_planet = state.assist_planet
	gravity_assist_time = state.assist_time

	global_position = physics_position
	rotation = physics_rotation
	linear_velocity = physics_velocity

# ---------------------------------------------------------------------------
# Shared static physics — called identically by spacecraft and trajectory predictor
# ---------------------------------------------------------------------------

static func step_physics(pos: Vector2, vel: Vector2, assist_planet, assist_time: float, delta: float, planets: Array, meteoroids: Array, portals: Array, black_holes: Array, sc_rotation: float, propulsion_speed: float) -> Dictionary:
	"""Single deterministic physics step. Returns the new state."""

	if abs(pos.x) > 200.0 or abs(pos.y) > 400.0:
		return {pos=pos, vel=vel, assist_planet=null, assist_time=0.0, alive=false, collided_meteroid=null, sc_rotation=sc_rotation}

	var total_force = Vector2.ZERO

	# 1. Gravity + gravity assist
	var grav = _gravity_step(pos, vel, planets, assist_planet, assist_time, delta)
	total_force += grav.force
	assist_planet = grav.assist_planet
	assist_time = grav.assist_time

	# 2. Planet collision
	for planet in planets:
		if not planet or not is_instance_valid(planet):
			continue
		if pos.distance_to(planet.global_position) <= planet.planet_radius + 6.0:
			return {pos=pos, vel=vel, assist_planet=null, assist_time=0.0, alive=false, collided_meteroid=null, sc_rotation=sc_rotation}

	# 3. Meteoroid collision — elastic reflection, glancing hits rotate sprite immediately
	var hit_meteroid = null
	for meteroid in meteoroids:
		if not meteroid or not is_instance_valid(meteroid):
			continue
		if pos.distance_to(meteroid.global_position) <= 19.0:
			var dir = (pos - meteroid.global_position).normalized()
			var approach = vel.dot(-dir)
			if approach > 0:
				var speed_before = vel.length()
				vel += dir * approach * 1.7
				var glancing = 1.0 - clamp(approach / max(speed_before, 0.001), 0.0, 1.0)
				sc_rotation = lerp_angle(sc_rotation, vel.angle() + PI / 2.0, glancing * 0.9)
			hit_meteroid = meteroid
			break

	# Rotation + propulsion — threshold is actual displacement per frame, not speed constant
	var displacement = vel.length() * delta
	var facing_fwd = Vector2(sin(sc_rotation), -cos(sc_rotation))
	var forward_speed = vel.dot(facing_fwd)

	if displacement >= MOVE_THRESHOLD and vel.length() >= SPEED_THRESHOLD and forward_speed > ANGLE_THRESHOLD * vel.length():
		# NORMAL: above SPEED_THRESHOLD, within angle, enough displacement — velocity leads sprite
		sc_rotation = lerp_angle(sc_rotation, vel.angle() + PI / 2.0, 0.3)

	elif forward_speed >= 0.0 and forward_speed < ANGLE_THRESHOLD * vel.length() and propulsion_speed > 0.0:
		# MID-RANGE (-90° to +ANGLE_THRESHOLD): both converge gradually to shared angle
		var lateral = vel - facing_fwd * forward_speed
		vel -= lateral * 0.15
		vel += facing_fwd * 1.5
		sc_rotation = lerp_angle(sc_rotation, vel.angle() + PI / 2.0, 0.1)

	elif propulsion_speed > 0.0:
		if forward_speed < 0.0:
			# OPPOSING (< -90°): cancel backward force, thrust forward, sprite locked
			vel += facing_fwd * min(-forward_speed * 0.4 + 3.0, 12.0)
		else:
			# SLOW (above threshold but not enough displacement): steer and thrust to SPEED_THRESHOLD
			var lateral = vel - facing_fwd * forward_speed
			vel -= lateral * 0.3
			vel += facing_fwd * min((SPEED_THRESHOLD - forward_speed) * 0.1 + 2.0, 8.0)

	# 4. Portal teleportation
	for portal in portals:
		if not portal or not is_instance_valid(portal):
			continue
		if pos.distance_to(portal.global_position) <= 13.0:
			var group = portal.portal_group if "portal_group" in portal else "portal1"
			for other in portals:
				if other != portal and "portal_group" in other and other.portal_group == group:
					return {pos=other.global_position, vel=vel, assist_planet=assist_planet, assist_time=assist_time, alive=true, collided_meteroid=null, sc_rotation=sc_rotation}
			break

	# 5. Black hole forces
	for black_hole in black_holes:
		if not black_hole or not is_instance_valid(black_hole):
			continue
		var dist_bh = pos.distance_to(black_hole.global_position)
		if dist_bh <= 10.0:
			return {pos=pos, vel=vel, assist_planet=null, assist_time=0.0, alive=false, collided_meteroid=null, sc_rotation=sc_rotation}
		if "gravity_radius" in black_hole and dist_bh <= black_hole.gravity_radius:
			var to_bh = black_hole.global_position - pos
			var bh_str = black_hole.gravity_strength if "gravity_strength" in black_hole else 1000.0
			total_force += to_bh.normalized() * (bh_str * 2.0 / dist_bh) * delta
			if vel.dot(to_bh.normalized()) < 0:
				total_force += -vel * 0.1
			break

	vel *= 0.999
	vel += total_force
	pos += vel * delta
	assist_time += delta

	return {pos=pos, vel=vel, assist_planet=assist_planet, assist_time=assist_time, alive=true, collided_meteroid=hit_meteroid, sc_rotation=sc_rotation}

static func _gravity_step(pos: Vector2, vel: Vector2, planets: Array, assist_planet, assist_time: float, delta: float) -> Dictionary:
	"""Compute gravity force for one step, including gravity assist logic."""
	var result = {force=Vector2.ZERO, assist_planet=assist_planet, assist_time=assist_time}

	for planet in planets:
		if not planet or not is_instance_valid(planet):
			continue
		var dist = pos.distance_to(planet.global_position)
		if dist > planet.gravity_radius or dist <= 1.0:
			continue

		var to_planet = planet.global_position - pos
		var base_force = to_planet.normalized() * ((planet.gravity_strength * delta * 60.0) / (dist * 0.01))

		if assist_planet == planet:
			var orbital = Vector2(-to_planet.y, to_planet.x).normalized()
			result.force = base_force + orbital * (50.0 * (1.0 + assist_time * 0.5)) * delta
			result.assist_time = assist_time
			if assist_time > 2.0 or dist > planet.gravity_radius * 0.8:
				result.assist_planet = null
				result.assist_time = 0.0
		else:
			var vel_dir = vel.normalized() if vel.length() > 0.0 else Vector2.ZERO
			var dot = to_planet.normalized().dot(vel_dir)
			var tangential = sqrt(max(0.0, 1.0 - dot * dot)) * vel.length()
			if dist <= planet.gravity_radius * 0.6 and tangential > 50.0:
				result.assist_planet = planet
				result.assist_time = 0.0
			result.force = base_force
		break

	return result

func exit_gravity_assist():
	"""Clear gravity assist state (called by target_area on capture)"""
	current_gravity_assist_planet = null
	gravity_assist_time = 0.0

func release():
	"""Release spacecraft from slingshot"""
	print("Releasing spacecraft with advanced physics")
	freeze = true  # Keep RigidBody2D frozen
	trail.reset_trail()

func apply_impulse_predictable(impulse: Vector2):
	"""Apply impulse with advanced physics"""
	physics_position = global_position
	physics_velocity = impulse
	physics_rotation = rotation
	thrust_rotation = rotation
	propulsion_speed = impulse.length()
	is_physics_active = true

func destroy():
	"""Destroy spacecraft"""
	var explosion_position = global_position
	var scene_parent = get_tree().current_scene

	is_physics_active = false

	# Create explosion effect
	SpacecraftExplosion.create_explosion_at(explosion_position, scene_parent)

	Input.vibrate_handheld(200)
	RuinedSpacecraft.create_at_position(explosion_position, scene_parent, rotation)

	visible = false
	freeze = true
	physics_velocity = Vector2.ZERO

	await get_tree().create_timer(0.3).timeout
	LevelManager.level_failed()

func reset(new_rotation, new_position):
	"""Reset spacecraft to initial state"""
	global_position = new_position
	rotation = new_rotation

	# Reset advanced physics
	is_physics_active = false
	physics_position = new_position
	physics_velocity = Vector2.ZERO
	physics_rotation = new_rotation
	thrust_rotation = new_rotation
	current_gravity_assist_planet = null
	gravity_assist_time = 0.0

	# Reset state
	is_dead = false
	visible = true
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0

# Debug system
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

	var canvas_layer = CanvasLayer.new()
	get_tree().current_scene.add_child(canvas_layer)
	canvas_layer.add_child(debug_label)

func update_debug_info():
	if not debug_enabled or not debug_label:
		return

	var debug_text = ""
	debug_text += "Advanced Physics Mode\n"
	debug_text += "Velocity: " + str(physics_velocity.round()) + "\n"
	debug_text += "Speed: " + str(round(physics_velocity.length())) + "\n"
	debug_text += "Position: " + str(physics_position.round()) + "\n"
	debug_text += "Gravity Assist: " + str(current_gravity_assist_planet.name if current_gravity_assist_planet else "None") + "\n"
	debug_text += "Assist Time: " + str(round(gravity_assist_time * 10) / 10.0) + "s\n"

	debug_label.text = debug_text

# Fire effect
@onready var fire_effect: SpacecraftFireEffect = $SpacecraftFireEffect

func update_fire_effect():
	"""Update fire effect based on movement"""
	var current_speed = physics_velocity.length()
	var is_moving = current_speed > 10.0
	var should_be_active = is_moving and is_physics_active

	if should_be_active and not fire_effect.is_fire_active():
		fire_effect.start_fire()
	elif not should_be_active and fire_effect.is_fire_active():
		fire_effect.stop_fire()
