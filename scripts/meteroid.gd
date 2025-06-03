extends RigidBody2D
class_name Meteroid

# Enum for available meteroid types/animations
enum MeteroidType {
	BROWN,
	DARK_BROWN,
	GREY,
	ORANGE
}

# Exported property to select meteroid type in the editor
@export var meteroid_type: MeteroidType = MeteroidType.BROWN

# Orbital movement properties
@export_group("Orbital Movement")
@export var orbit_radius: float = 30.0  # Distance from center
@export var orbit_speed: float = 10.0  # degrees per second (much slower)
@export var clockwise: bool = true
@export var start_angle: float = 0.0  # Starting position in degrees
@export var orbit_rotation: float = 0.0  # Rotate the entire orbital path (degrees)
@export var orbit_tilt: float = 0.0  # Tilt the orbit elliptically (0-1, 0=circle, 1=flat line)
@export var wobble_amplitude: float = 2.0  # Small wobble (was 5.0)
@export var wobble_frequency: float = 0.5  # Very slow wobble (was 2.0)

# Physics properties
@export_group("Physics")
@export var meteroid_mass: float = 1.0  # How heavy the meteroid feels
@export var return_to_orbit_strength: float = 2.0  # How strongly it returns to orbit
@export var collision_impulse_multiplier: float = 0.3  # How much collision affects it
@export var damping_factor: float = 0.98  # How quickly it settles down

# Internal variables for movement
var center_position: Vector2
var current_angle: float
var time_elapsed: float = 0.0
var is_disturbed: bool = false  # Whether meteroid has been knocked off course
var disturbance_timer: float = 0.0
var max_disturbance_time: float = 3.0  # How long before returning to orbit

# Reference to the animated sprite
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Mapping from enum to animation names
var animation_names = {
	MeteroidType.BROWN: "brown",
	MeteroidType.DARK_BROWN: "darkBrown",
	MeteroidType.GREY: "grey",
	MeteroidType.ORANGE: "orange"
}

func _ready():
	# IMPORTANT: Create unique resources for this instance
	create_unique_resources()
	
	# Store the initial position as the center of orbit
	center_position = global_position
	current_angle = deg_to_rad(start_angle)
	
	# Set up RigidBody2D properties for realistic physics
	mass = meteroid_mass
	gravity_scale = 0.0  # No gravity in space
	linear_damp = 0.1  # Small amount of space friction
	angular_damp = 0.2  # Slight rotational damping
	
	# Set the animation based on the selected meteroid type
	set_meteroid_animation()
	
	# Start at the correct orbital position
	update_orbital_position()

func create_unique_resources():
	"""Create unique resource instances for this meteroid to prevent sharing"""
	# Make collision shapes unique
	if $CollisionShape2D and $CollisionShape2D.shape:
		$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
	
	# Make sprite frames unique (important for animation)
	if animated_sprite and animated_sprite.sprite_frames:
		animated_sprite.sprite_frames = animated_sprite.sprite_frames.duplicate()
	
	# Make any materials unique
	if animated_sprite and animated_sprite.material:
		animated_sprite.material = animated_sprite.material.duplicate()
	



func _physics_process(delta):
	"""Handle orbital movement and physics interactions"""
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
	
	# Keep angle in 0-2π range
	current_angle = fmod(current_angle, 2 * PI)
	
	# Apply movement based on current state
	if is_disturbed:
		apply_return_to_orbit_force(delta)
	else:
		update_orbital_position()
	
	# Apply damping to settle movement
	linear_velocity *= damping_factor

func update_orbital_position():
	"""Calculate and apply gentle orbital movement when not disturbed"""
	# Calculate wobble effect for more natural movement
	var wobble_offset = sin(time_elapsed * wobble_frequency) * wobble_amplitude
	var effective_radius = orbit_radius + wobble_offset
	
	# Calculate base orbital position (before rotation and tilt)
	var base_orbit_offset = Vector2(
		cos(current_angle) * effective_radius,
		sin(current_angle) * effective_radius
	)
	
	# Apply orbital tilt (makes orbit elliptical)
	var tilted_offset = Vector2(
		base_orbit_offset.x,
		base_orbit_offset.y * (1.0 - orbit_tilt)  # Tilt compresses Y axis
	)
	
	# Apply orbital rotation (rotates the entire orbital plane)
	var rotation_rad = deg_to_rad(orbit_rotation)
	var rotated_offset = Vector2(
		tilted_offset.x * cos(rotation_rad) - tilted_offset.y * sin(rotation_rad),
		tilted_offset.x * sin(rotation_rad) + tilted_offset.y * cos(rotation_rad)
	)
	
	var target_position = center_position + rotated_offset
	
	# Apply gentle force toward orbital position
	var direction_to_orbit = target_position - global_position
	var distance_to_orbit = direction_to_orbit.length()
	
	if distance_to_orbit > 1.0:
		# Scale force based on orbit size and distance - this is the key fix!
		var orbit_scale_factor = max(1.0, orbit_radius / 30.0)  # Scale force for larger orbits
		var distance_factor = min(distance_to_orbit * 0.1, 1.0)  # Stronger force when further away
		var orbital_force = direction_to_orbit.normalized() * return_to_orbit_strength * orbit_scale_factor * distance_factor
		apply_central_force(orbital_force)
	

	# Gentle rotation for visual effect
	if animated_sprite:
		animated_sprite.rotation += deg_to_rad(5.0 * get_physics_process_delta_time())

func apply_return_to_orbit_force(delta):
	"""Apply stronger force to return to orbit after disturbance"""
	var wobble_offset = sin(time_elapsed * wobble_frequency) * wobble_amplitude
	var effective_radius = orbit_radius + wobble_offset
	
	# Apply same transformations as in update_orbital_position
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
	
	# Stronger return force when disturbed
	var direction_to_orbit = target_position - global_position
	var distance_to_orbit = direction_to_orbit.length()
	
	if distance_to_orbit > 1.0:
		# Scale return force for larger orbits too
		var orbit_scale_factor = max(1.0, orbit_radius / 30.0)
		var time_factor = (1.0 + (max_disturbance_time - disturbance_timer))
		var return_strength = return_to_orbit_strength * orbit_scale_factor * time_factor
		var return_force = direction_to_orbit.normalized() * return_strength
		apply_central_force(return_force)

func _on_collision_detected(body):
	"""Handle collision detection via Area2D"""
	if body is Spacecraft:

		# Calculate collision direction and impulse
		var collision_direction = (global_position - body.global_position).normalized()
		var spacecraft_velocity = body.linear_velocity
		
		# Calculate impulse based on spacecraft velocity and approach angle
		var velocity_magnitude = spacecraft_velocity.length()
		var collision_impulse = collision_direction * velocity_magnitude * collision_impulse_multiplier
		
		# Apply the collision force to meteroid
		apply_central_impulse(collision_impulse)
		
		# Mark as disturbed and start recovery timer
		is_disturbed = true
		disturbance_timer = max_disturbance_time
		
		# Optional: Apply reaction force to spacecraft (Newton's 3rd law)
		var reaction_force = -collision_impulse * 0.1  # Smaller reaction
		body.apply_central_impulse(reaction_force)

func set_orbit_center(new_center: Vector2):
	"""Change the center point of the orbit"""
	center_position = new_center

func set_orbit_properties(radius: float, speed: float, is_clockwise: bool = true):
	"""Change orbital properties at runtime"""
	orbit_radius = radius
	orbit_speed = speed
	clockwise = is_clockwise

func reverse_orbit_direction():
	"""Reverse the direction of orbital movement"""
	clockwise = !clockwise
func set_meteroid_animation():
	"""Set the animation based on the meteroid_type property"""
	if animated_sprite and meteroid_type in animation_names:
		var animation_name = animation_names[meteroid_type]
		animated_sprite.animation = animation_name
		animated_sprite.play()

func change_meteroid_type(new_type: MeteroidType):
	"""Change the meteroid type at runtime"""
	meteroid_type = new_type
	set_meteroid_animation()

# Called when the meteroid is destroyed (e.g., hit by spacecraft)
func destroy():
	"""Handle meteroid destruction"""
	print("Meteroid destroyed!")
	queue_free()

func get_collision_damage() -> float:
	"""Return damage value based on meteroid mass and velocity"""
	return linear_velocity.length() * meteroid_mass * 0.1
