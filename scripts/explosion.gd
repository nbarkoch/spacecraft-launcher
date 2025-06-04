
extends Node2D
class_name SpacecraftExplosion

@export_group("Explosion Properties")
@export var explosion_duration: float = 1.5
@export var debris_count: int = 8
@export var energy_burst_count: int = 12
@export var shockwave_enabled: bool = true

# Particle systems
var debris_particles: CPUParticles2D
var energy_particles: CPUParticles2D
var shockwave_particles: CPUParticles2D
var ring_effect: RingEffectComponent

# Audio (you can add this later)
# var explosion_sound: AudioStreamPlayer2D

func _ready():
	setup_explosion_effects()

func setup_explosion_effects():
	"""Create all particle systems for the explosion"""
	
	# Debris particles (spacecraft fragments)
	debris_particles = CPUParticles2D.new()
	add_child(debris_particles)
	setup_debris_particles()
	
	# Energy burst particles (bright flash)
	energy_particles = CPUParticles2D.new()
	add_child(energy_particles)
	setup_energy_particles()
	
	# Shockwave particles (expanding ring of small particles)
	if shockwave_enabled:
		shockwave_particles = CPUParticles2D.new()
		add_child(shockwave_particles)
		setup_shockwave_particles()
	
	# Ring effect (expanding circle)
	ring_effect = RingEffectComponent.new()
	ring_effect.animation_duration = 0.8
	ring_effect.ring_size = 120.0
	ring_effect.initial_width = 15.0
	ring_effect.ring_color = Color(1.0, 0.4, 0.1, 0.8)  # Orange explosion color
	ring_effect.auto_cleanup = true
	add_child(ring_effect)

func setup_debris_particles():
	"""Configure debris/fragment particles"""
	debris_particles.emitting = false
	debris_particles.amount = debris_count
	debris_particles.lifetime = 1.2
	debris_particles.one_shot = true
	debris_particles.explosiveness = 1.0
	
	# Movement
	debris_particles.direction = Vector2(0, 0)
	debris_particles.spread = 180.0
	debris_particles.initial_velocity_min = 50.0
	debris_particles.initial_velocity_max = 80.0
	debris_particles.gravity = Vector2(0, 20)  # Slight downward drift
	
	# Appearance
	debris_particles.scale_amount_min = 0.3
	debris_particles.scale_amount_max = 0.8
	
	# Create a simple square texture for debris
	var debris_texture = ImageTexture.new()
	var image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.GRAY)
	debris_texture.set_image(image)
	debris_particles.texture = debris_texture
	
	# Color variation (gray to dark gray)
	debris_particles.color = Color(0.8, 0.8, 0.8, 1.0)
	debris_particles.color_ramp = create_debris_color_ramp()
	
	# Physics
	debris_particles.damping_min = 1.0
	debris_particles.damping_max = 3.0

func setup_energy_particles():
	"""Configure bright energy burst particles"""
	energy_particles.emitting = false
	energy_particles.amount = energy_burst_count
	energy_particles.lifetime = 0.6
	energy_particles.one_shot = true
	energy_particles.explosiveness = 1.0
	
	# Movement
	energy_particles.direction = Vector2(0, 0)
	energy_particles.spread = 180.0
	energy_particles.initial_velocity_min = 70.0
	energy_particles.initial_velocity_max = 100.0
	energy_particles.gravity = Vector2(0, 0)  # No gravity for energy
	
	# Appearance
	energy_particles.scale_amount_min = 0.8
	energy_particles.scale_amount_max = 1.5
	
	# Bright colors (white to orange to red)
	energy_particles.color = Color(1.0, 1.0, 1.0, 1.0)
	energy_particles.color_ramp = create_energy_color_ramp()
	
	# Physics
	energy_particles.damping_min = 2.0
	energy_particles.damping_max = 4.0

func setup_shockwave_particles():
	"""Configure expanding shockwave particles"""
	shockwave_particles.emitting = false
	shockwave_particles.amount = 20
	shockwave_particles.lifetime = 1.0
	shockwave_particles.one_shot = true
	shockwave_particles.explosiveness = 1.0
	
	# Radial expansion
	shockwave_particles.direction = Vector2(0, 0)
	shockwave_particles.spread = 180.0
	shockwave_particles.initial_velocity_min = 200.0
	shockwave_particles.initial_velocity_max = 300.0
	shockwave_particles.gravity = Vector2(0, 0)
	
	# Small, fast-fading particles
	shockwave_particles.scale_amount_min = 0.2
	shockwave_particles.scale_amount_max = 0.5
	
	# Blue-white energy color
	shockwave_particles.color = Color(0.6, 0.8, 1.0, 0.8)
	shockwave_particles.color_ramp = create_shockwave_color_ramp()
	
	# High damping for quick fade
	shockwave_particles.damping_min = 3.0
	shockwave_particles.damping_max = 5.0

func create_debris_color_ramp() -> Gradient:
	"""Create color gradient for debris particles"""
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.9, 0.9, 0.9, 1.0))  # Light gray
	gradient.add_point(0.3, Color(0.7, 0.6, 0.5, 1.0))  # Brownish
	gradient.add_point(1.0, Color(0.3, 0.3, 0.3, 0.0))  # Dark, transparent
	return gradient

func create_energy_color_ramp() -> Gradient:
	"""Create color gradient for energy particles"""
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))  # Bright white
	gradient.add_point(0.2, Color(1.0, 0.8, 0.3, 1.0))  # Yellow-orange
	gradient.add_point(0.6, Color(1.0, 0.4, 0.1, 0.8))  # Orange
	gradient.add_point(1.0, Color(0.8, 0.2, 0.0, 0.0))  # Red, transparent
	return gradient

func create_shockwave_color_ramp() -> Gradient:
	"""Create color gradient for shockwave particles"""
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.8, 0.9, 1.0, 0.9))  # Bright blue-white
	gradient.add_point(0.4, Color(0.4, 0.6, 1.0, 0.6))  # Blue
	gradient.add_point(1.0, Color(0.2, 0.3, 0.8, 0.0))  # Dark blue, transparent
	return gradient

func trigger_explosion():
	"""Start the explosion effect"""
	# Trigger all particle systems
	debris_particles.restart()
	energy_particles.restart()
	
	if shockwave_enabled and shockwave_particles:
		shockwave_particles.restart()
	
	# Trigger ring effect
	if ring_effect:
		ring_effect.trigger()
	
	# Add screen shake effect (optional)
	add_screen_shake()
	
	# Clean up after explosion is complete
	await get_tree().create_timer(explosion_duration).timeout
	queue_free()

func add_screen_shake():
	"""Add a subtle screen shake effect"""
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	
	var original_offset = camera.offset
	var shake_tween = create_tween()
	
	# Quick shake sequence
	for i in range(6):
		var shake_amount = 3.0 * (1.0 - i / 6.0)  # Decreasing intensity
		var random_offset = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		shake_tween.tween_property(camera, "offset", original_offset + random_offset, 0.05)
	
	# Return to original position
	shake_tween.tween_property(camera, "offset", original_offset, 0.1)

# Static method to create explosion at a position
static func create_explosion_at(position: Vector2, parent: Node) -> SpacecraftExplosion:
	"""Create an explosion at the specified position"""
	var explosion = SpacecraftExplosion.new()
	parent.add_child(explosion)
	explosion.global_position = position
	explosion.trigger_explosion()
	return explosion
