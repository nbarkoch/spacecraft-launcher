# scripts/ruined_spacecraft.gd
extends Node2D
class_name RuinedSpacecraft

@export_group("Debris Physics")
@export var explosion_force_min: float = 5.0
@export var explosion_force_max: float = 20.0
@export var angular_velocity_min: float = -2.0
@export var angular_velocity_max: float = 2.0
@export var debris_lifetime: float = 8.0
@export var fade_duration: float = 2.0

# Internal variables
var debris_parts: Array[RigidBody2D] = []
var is_exploded: bool = false

func _ready():
	# Collect all debris parts
	collect_debris_parts()
	
	# Set up collision layer (layer 4 as specified)
	setup_collision_layers()
	
	# Don't explode automatically - wait for trigger
	pass

func collect_debris_parts():
	"""Find all RigidBody2D children that represent debris pieces"""
	debris_parts.clear()
	
	for child in get_children():
		if child is RigidBody2D:
			debris_parts.append(child)
			
			# Ensure they start frozen until explosion
			child.freeze = true
			child.gravity_scale = 0.0  # Space has no gravity
			child.linear_damp = 0.1    # Very light damping for space
			child.angular_damp = 0.05  # Minimal angular damping

func setup_collision_layers():
	"""Set all debris parts to collision layer 4"""
	for part in debris_parts:
		part.collision_layer = 4
		part.collision_mask = 0  # Don't collide with anything initially

func explode_debris():
	"""Trigger the debris explosion effect"""
	if is_exploded:
		return
	
	is_exploded = true
	
	# Calculate center point for explosion
	var explosion_center = global_position
	
	# Apply forces to each debris part
	for part in debris_parts:
		if not part or not is_instance_valid(part):
			continue
		
		# Unfreeze the part
		part.freeze = false
		
		# Calculate direction from center to this part
		var direction = (part.global_position - explosion_center).normalized()
		
		# Add some randomness to the direction
		var random_angle = randf_range(-0.3, 0.3)  # ±17 degrees
		direction = direction.rotated(random_angle)
		
		# Calculate random force magnitude
		var force_magnitude = randf_range(explosion_force_min, explosion_force_max)
		var explosion_force = direction * force_magnitude
		
		# Apply the explosion force
		part.apply_central_impulse(explosion_force)
		
		# Add random rotation
		var angular_vel = randf_range(angular_velocity_min, angular_velocity_max)
		part.angular_velocity = angular_vel
		
		# Optional: slight variation in damping for more realistic movement
		part.linear_damp = randf_range(0.05, 0.15)
		part.angular_damp = randf_range(0.02, 0.08)
	
	# Start cleanup timer
	start_cleanup_sequence()

func start_cleanup_sequence():
	"""Start the cleanup process after debris has been visible for a while"""
	# Wait for debris to float around
	await get_tree().create_timer(debris_lifetime - fade_duration).timeout
	
	# Start fading out the debris
	fade_out_debris()
	
	# Clean up after fade is complete
	await get_tree().create_timer(fade_duration).timeout
	queue_free()

func fade_out_debris():
	"""Gradually fade out all debris parts"""
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)  # Allow multiple parts to fade simultaneously
	
	for part in debris_parts:
		if not part or not is_instance_valid(part):
			continue
		
		# Find the sprite in this part
		var sprite = find_sprite_in_part(part)
		if sprite:
			fade_tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0), fade_duration)

func find_sprite_in_part(part: RigidBody2D) -> Node:
	"""Find the Sprite2D node in a debris part"""
	for child in part.get_children():
		if child is Sprite2D:
			return child
	return null

# Static method to create ruined spacecraft at explosion site
static func create_at_position(position: Vector2, parent: Node, rotation: float) -> RuinedSpacecraft:
	"""Create ruined spacecraft debris at the specified position"""
	# Load the ruined spacecraft scene
	var ruined_scene = preload("res://scenes/effects/ruined_spacecraft.tscn")
	var ruined_instance = ruined_scene.instantiate() as RuinedSpacecraft
	
	# Add to scene
	parent.add_child(ruined_instance)
	ruined_instance.global_position = position
	ruined_instance.rotation = rotation
	
	# Trigger explosion immediately
	ruined_instance.explode_debris()
	
	return ruined_instance

# Alternative static method with custom parameters
static func create_with_settings(position: Vector2, parent: Node, force_min: float = 50.0, force_max: float = 120.0, lifetime: float = 8.0) -> RuinedSpacecraft:
	"""Create ruined spacecraft with custom explosion settings"""
	var ruined_instance = create_at_position(position, parent, 0)
	
	# Override default settings
	ruined_instance.explosion_force_min = force_min
	ruined_instance.explosion_force_max = force_max
	ruined_instance.debris_lifetime = lifetime
	
	return ruined_instance

# Method to manually trigger explosion (if you want delayed explosion)
func trigger_explosion():
	"""Manually trigger the debris explosion"""
	explode_debris()

# Method to change debris behavior after creation
func set_debris_collision_mask(mask: int):
	"""Change what the debris can collide with"""
	for part in debris_parts:
		if part and is_instance_valid(part):
			part.collision_mask = mask

# Method to apply additional forces (like from nearby explosions)
func apply_external_force(force: Vector2, position: Vector2 = global_position):
	"""Apply additional force to all debris parts (useful for chain reactions)"""
	for part in debris_parts:
		if not part or not is_instance_valid(part) or part.freeze:
			continue
		
		# Calculate direction and distance-based force
		var direction = (part.global_position - position).normalized()
		var distance = part.global_position.distance_to(position)
		var force_factor = 1.0 / max(distance * 0.01, 1.0)  # Weaker at distance
		
		var applied_force = direction * force.length() * force_factor
		part.apply_central_impulse(applied_force)
