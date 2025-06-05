extends Node
class_name RingEffectComponent

@export_group("Ring Properties")
@export var animation_duration: float = 1.0
@export var ring_size: float = 100.0  # Size in pixels
@export var initial_width: float = 20.0  # Initial border width
@export var ring_color: Color = Color.WHITE
@export var edge_softness: float = 0.02

@export_group("Animation")
@export var auto_start: bool = false
@export var ease_type: Tween.EaseType = Tween.EASE_OUT
@export var transition_type: Tween.TransitionType = Tween.TRANS_QUART

@export_group("Advanced")
@export var shader_path: String = "res://shaders/ring_effect.gdshader"
@export var fade_out_ratio: float = 0.3  # What portion of animation is fade out
@export var auto_cleanup: bool = true  # Remove ColorRect after animation

var color_rect: ColorRect
var shader_material: ShaderMaterial
var tween: Tween
var is_playing: bool = false

func _ready():
	# Wait a frame to ensure parent is ready
	await get_tree().process_frame
	setup_ring()
	if auto_start:
		play_ring_effect()

func setup_ring():
	# Get parent node (should be Node2D or Control)
	var parent = get_parent()
	if not parent:
		push_error("RingEffect needs a parent node")
		return
	
	# Create ColorRect for the ring
	color_rect = ColorRect.new()
	parent.add_child(color_rect)
	
	# Set size and center it
	color_rect.size = Vector2(ring_size, ring_size)
	color_rect.position = -color_rect.size / 2
	color_rect.z_index = 10  # Make sure it's on top
	
	# Load and setup shader
	var shader = load(shader_path) if ResourceLoader.exists(shader_path) else null
	if shader:
		shader_material = ShaderMaterial.new()
		shader_material.shader = shader
		
		# Set initial shader parameters
		shader_material.set_shader_parameter("ring_radius", 0.5)
		shader_material.set_shader_parameter("ring_width", initial_width / ring_size)
		shader_material.set_shader_parameter("ring_color", ring_color)
		shader_material.set_shader_parameter("edge_softness", edge_softness)
		shader_material.set_shader_parameter("animation_progress", 0.0)
		
		color_rect.material = shader_material
		color_rect.visible = false  # Hidden until triggered
	else:
		push_error("Ring effect shader not found at: " + shader_path)

func play_ring_effect():
	if is_playing or not color_rect or not shader_material:
		return
	
	is_playing = true
	color_rect.visible = true
	
	# Kill existing tween
	if tween:
		tween.kill()
	
	# Create new tween
	tween = create_tween()
	tween.set_parallel(true)  # Allow multiple properties to animate simultaneously
	
	# Animate the ring expansion and width reduction
	tween.tween_method(
		_update_animation_progress,
		0.0,
		1.0,
		animation_duration
	).set_ease(ease_type).set_trans(transition_type)
	
	# Fade out at the end
	var fade_delay = animation_duration * (1.0 - fade_out_ratio)
	var fade_duration = animation_duration * fade_out_ratio
	tween.tween_method(
		_update_fade,
		1.0,
		0.0,
		fade_duration
	).set_delay(fade_delay)
	
	# Signal when complete
	tween.finished.connect(_on_animation_finished)

func _update_animation_progress(progress: float):
	if shader_material:
		shader_material.set_shader_parameter("animation_progress", progress)

func _update_fade(fade: float):
	if shader_material:
		var current_color = ring_color
		current_color.a = fade
		shader_material.set_shader_parameter("ring_color", current_color)

func _on_animation_finished():
	is_playing = false
	color_rect.visible = false
	
	# Reset for next use
	if shader_material:
		shader_material.set_shader_parameter("animation_progress", 0.0)
		shader_material.set_shader_parameter("ring_color", ring_color)
	
	# Optional cleanup
	if auto_cleanup and color_rect:
		color_rect.queue_free()
		color_rect = null

# Public methods to control the effect
func trigger():
	"""Main method to trigger the ring effect"""
	play_ring_effect()

func set_ring_color(color: Color):
	ring_color = color
	if shader_material:
		shader_material.set_shader_parameter("ring_color", color)

func set_ring_size(size: float):
	ring_size = size
	if color_rect:
		color_rect.size = Vector2(size, size)
		color_rect.position = -color_rect.size / 2
		# Update width parameter based on new size
		if shader_material:
			shader_material.set_shader_parameter("ring_width", initial_width / size)

func stop():
	"""Stop the current animation"""
	if tween:
		tween.kill()
	if color_rect:
		color_rect.visible = false
	is_playing = false

# Cleanup when node is freed
func _exit_tree():
	if color_rect and is_instance_valid(color_rect):
		color_rect.queue_free()
