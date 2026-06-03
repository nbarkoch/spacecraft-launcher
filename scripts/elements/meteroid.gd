extends RigidBody2D
class_name Meteroid

# Enum for available meteroid types/animations
enum MeteroidType {
	BROWN,
	DARK_BROWN,
	GREY,
	ORANGE
}

@export var meteroid_type: MeteroidType = MeteroidType.BROWN

# Orbital movement properties
@export_group("Orbital Movement")
@export var orbit_radius: float = 30.0
@export var orbit_speed: float = 10.0  # degrees per second
@export var clockwise: bool = true
@export var start_angle: float = 0.0
@export var orbit_rotation: float = 0.0
@export var orbit_tilt: float = 0.0
@export var wobble_amplitude: float = 2.0
@export var wobble_frequency: float = 0.5

# Physics properties
@export_group("Physics")
@export var return_to_orbit_strength: float = 2.0
@export var collision_impulse_multiplier: float = 0.05
@export var damping_factor: float = 0.90

# Internal variables for movement
var center_position: Vector2
var current_angle: float
var time_elapsed: float = 0.0
var is_disturbed: bool = false
var disturbance_timer: float = 0.0
var max_disturbance_time: float = 0.6

# Advanced physics system
var meteroid_physics_position: Vector2
var meteroid_physics_velocity: Vector2
var meteroid_physics_mass: float = 5.0

# Animation mapping
var animation_names = {
	MeteroidType.BROWN: "brown",
	MeteroidType.DARK_BROWN: "darkBrown",
	MeteroidType.GREY: "grey",
	MeteroidType.ORANGE: "orange"
}

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	add_to_group("Meteoroids")
	create_unique_resources()
	
	# Store initial position as orbit center
	center_position = global_position
	current_angle = deg_to_rad(start_angle)
	
	# Use our own physics system
	freeze = true
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.0
	
	# Initialize our physics
	meteroid_physics_position = global_position
	meteroid_physics_velocity = Vector2.ZERO
	
	set_meteroid_animation()
	update_orbital_position()

func create_unique_resources():
	"""Create unique resource instances for this meteroid"""
	if $CollisionShape2D and $CollisionShape2D.shape:
		$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
	
	if animated_sprite and animated_sprite.sprite_frames:
		animated_sprite.sprite_frames = animated_sprite.sprite_frames.duplicate()
	
	if animated_sprite and animated_sprite.material:
		animated_sprite.material = animated_sprite.material.duplicate()

func _physics_process(delta):
	"""Our physics simulation"""
	time_elapsed += delta
	
	# Handle disturbance recovery
	if is_disturbed:
		disturbance_timer -= delta
		if disturbance_timer <= 0:
			is_disturbed = false
	
	# Update orbital angle
	var angle_speed = deg_to_rad(orbit_speed) * delta
	if clockwise:
		current_angle += angle_speed
	else:
		current_angle -= angle_speed
	
	current_angle = fmod(current_angle, 2 * PI)
	
	# Update physics
	meteroid_physics_velocity *= damping_factor
	
	# Calculate orbital return force
	var orbit_force = calculate_orbital_force()
	meteroid_physics_velocity += orbit_force * delta
	
	# Update position
	meteroid_physics_position += meteroid_physics_velocity * delta
	global_position = meteroid_physics_position
	
	# Visual rotation
	if animated_sprite:
		animated_sprite.rotation += deg_to_rad(5.0 * delta)

func calculate_orbital_force() -> Vector2:
	"""Calculate force to maintain orbital motion"""
	# Calculate wobble effect
	var wobble_offset = sin(time_elapsed * wobble_frequency) * wobble_amplitude
	var effective_radius = orbit_radius + wobble_offset
	
	# Calculate base orbital position
	var base_orbit_offset = Vector2(
		cos(current_angle) * effective_radius,
		sin(current_angle) * effective_radius
	)
	
	# Apply orbital tilt
	var tilted_offset = Vector2(
		base_orbit_offset.x,
		base_orbit_offset.y * (1.0 - orbit_tilt)
	)
	
	# Apply orbital rotation
	var rotation_rad = deg_to_rad(orbit_rotation)
	var rotated_offset = Vector2(
		tilted_offset.x * cos(rotation_rad) - tilted_offset.y * sin(rotation_rad),
		tilted_offset.x * sin(rotation_rad) + tilted_offset.y * cos(rotation_rad)
	)
	
	var target_position = center_position + rotated_offset
	var direction_to_orbit = target_position - meteroid_physics_position
	var distance_to_orbit = direction_to_orbit.length()
	
	if distance_to_orbit > 1.0:
		var base_strength = return_to_orbit_strength
		
		# Slightly stronger return force when disturbed
		if is_disturbed:
			base_strength *= 2.0
		
		var orbit_scale_factor = max(1.0, orbit_radius / 30.0)
		var distance_factor = min(distance_to_orbit * 0.1, 1.0)
		
		var return_strength = base_strength * orbit_scale_factor * distance_factor
		return direction_to_orbit.normalized() * return_strength
	
	return Vector2.ZERO

func apply_collision_effect(spacecraft_velocity: Vector2):
	"""Apply collision effect using our physics system"""
	# Mark as disturbed
	is_disturbed = true
	disturbance_timer = max_disturbance_time
	
	# Calculate collision force
	var spacecraft_mass = 1.0
	var momentum_transfer = (2.0 * spacecraft_mass) / (spacecraft_mass + meteroid_physics_mass)
	var collision_force = spacecraft_velocity * momentum_transfer * collision_impulse_multiplier
	
	# Apply force to meteroid
	meteroid_physics_velocity += collision_force
	
	# Ensure position is updated
	if meteroid_physics_position == Vector2.ZERO:
		meteroid_physics_position = global_position
	
	# Visual effect
	create_collision_effect()
	
	print("Meteroid hit! Disturbed for ", max_disturbance_time, " seconds. Velocity: ", meteroid_physics_velocity)

func create_collision_effect():
	"""Visual collision effect"""
	var tween = create_tween()
	var original_modulate = modulate
	
	# Quick white flash
	tween.tween_property(self, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.1)
	tween.tween_property(self, "modulate", original_modulate, 0.1)

func update_orbital_position():
	"""Calculate orbital position"""
	var wobble_offset = sin(time_elapsed * wobble_frequency) * wobble_amplitude
	var effective_radius = orbit_radius + wobble_offset
	
	var base_orbit_offset = Vector2(
		cos(current_angle) * effective_radius,
		sin(current_angle) * effective_radius
	)
	
	var tilted_offset = Vector2(
		base_orbit_offset.x,
		base_orbit_offset.y * (1.0 - orbit_tilt)
	)
	
	var rotation_rad = deg_to_rad(orbit_rotation)
	var rotated_offset = Vector2(
		tilted_offset.x * cos(rotation_rad) - tilted_offset.y * sin(rotation_rad),
		tilted_offset.x * sin(rotation_rad) + tilted_offset.y * cos(rotation_rad)
	)
	
	var target_position = center_position + rotated_offset
	global_position = target_position
	
	if animated_sprite:
		animated_sprite.rotation += deg_to_rad(5.0 * get_physics_process_delta_time())

# Collision detection for advanced physics
func _on_collision_detected(body):
	"""Handle collision detection - Advanced physics handles this automatically"""
	if body is Spacecraft:
		print("Meteroid collision detected (handled by advanced physics)")

# Utility functions
func set_orbit_center(new_center: Vector2):
	center_position = new_center

func set_orbit_properties(radius: float, speed: float, is_clockwise: bool = true):
	orbit_radius = radius
	orbit_speed = speed
	clockwise = is_clockwise

func reverse_orbit_direction():
	clockwise = !clockwise

func set_meteroid_animation():
	if animated_sprite and meteroid_type in animation_names:
		var animation_name = animation_names[meteroid_type]
		animated_sprite.animation = animation_name
		animated_sprite.play()

func change_meteroid_type(new_type: MeteroidType):
	meteroid_type = new_type
	set_meteroid_animation()

func destroy():
	print("Meteroid destroyed!")
	queue_free()

func get_collision_damage() -> float:
	return meteroid_physics_velocity.length() * meteroid_physics_mass * 0.1
