# scripts/effects/spacecraft_fire_effect.gd
extends Sprite2D
class_name SpacecraftFireEffect

var fire_tween: Tween
var glow_sprite: Sprite2D
var is_active: bool = false
var base_scale: Vector2

func _ready():
	base_scale = scale
	visible = false
	setup_glow_sprite()

func setup_glow_sprite():
	"""Create simple radial glow sprite behind fire"""
	glow_sprite = Sprite2D.new()
	add_child(glow_sprite)  # Add as child of fire sprite
	
	# Position and setup
	glow_sprite.position = Vector2.ZERO  # Centered on fire
	glow_sprite.z_index = -1  # Behind fire (relative to fire)
	glow_sprite.texture = create_radial_glow()
	glow_sprite.scale = Vector2(6.0, 6.0)  # Slightly smaller
	glow_sprite.visible = false

func create_radial_glow() -> ImageTexture:
	"""Create radial gradient texture with proper falloff"""
	var size = 64  # Bigger texture
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2, size / 2)
	var max_radius = size / 2
	
	for x in range(size):
		for y in range(size):
			var distance = Vector2(x, y).distance_to(center)
			var normalized_distance = distance / max_radius
			
			# Smooth falloff that reaches zero at edges
			var alpha = 1.0 - normalized_distance
			alpha = clamp(alpha, 0.0, 1.0)
			alpha = alpha * alpha * alpha  # Cubic falloff for smoother edges
			
			# Yellow/orange glow that fades to completely transparent
			var color = Color(1.0, 0.8, 0.4, alpha * 0.4)  # Lower alpha
			image.set_pixel(x, y, color)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func start_fire():
	if is_active:
		return
	
	is_active = true
	visible = true
	modulate = Color(1, 1, 1, 0)
	
	# Show glow with proper color
	if glow_sprite:
		glow_sprite.visible = true
		glow_sprite.modulate = Color(1.0, 0.7, 0.3, 0.8)  # Warm orange glow
	
	if fire_tween:
		fire_tween.kill()
	
	fire_tween = create_tween()
	fire_tween.parallel().tween_property(self, "modulate", Color(1, 1, 1, 1), 0.2)
	
	fire_tween.tween_callback(start_flicker_loop)

func stop_fire():
	if not is_active:
		return
	
	is_active = false
	
	if fire_tween:
		fire_tween.kill()
	
	fire_tween = create_tween()
	var tiny_scale = base_scale * 0.1
	fire_tween.parallel().tween_property(self, "scale", tiny_scale, 0.15)
	fire_tween.parallel().tween_property(self, "modulate", Color(1, 1, 1, 0), 0.15)
	
	# Fade glow
	if glow_sprite:
		fire_tween.parallel().tween_property(glow_sprite, "modulate", Color(1, 1, 1, 0), 0.15)
	
	fire_tween.tween_callback(reset_fire)

func start_flicker_loop():
	if not is_active:
		return
	
	if fire_tween:
		fire_tween.kill()
	
	fire_tween = create_tween()
	fire_tween.set_loops()
	
	var patterns = [
		Vector2(0.9, 1.1),   # Narrow/tall
		Vector2(1.1, 0.9),   # Wide/short
		Vector2(0.95, 1.05), # Slight narrow/tall
		Vector2(1.05, 0.95), # Slight wide/short
		Vector2(1.0, 1.0),   # Normal
		Vector2(0.85, 1.15), # Very narrow/tall
	]
	
	for pattern in patterns:
		var target_scale = base_scale * pattern
		var duration = randf_range(0.05, 0.1)
		
		# Fire flicker
		fire_tween.tween_property(self, "scale", target_scale, duration)
		fire_tween.tween_property(self, "scale", target_scale * Vector2(1.02, 0.98), duration * 0.3)
		
		# Glow flicker (subtle)
		if glow_sprite:
			var glow_alpha = randf_range(0.6, 1.0)
			var glow_color = Color(1.0, 0.7, 0.3, glow_alpha)
			fire_tween.parallel().tween_property(glow_sprite, "modulate", glow_color, duration)

func reset_fire():
	visible = false
	scale = base_scale
	modulate = Color(1, 1, 1, 1)
	if glow_sprite:
		glow_sprite.visible = false

func toggle_fire():
	if is_active:
		stop_fire()
	else:
		start_fire()

func is_fire_active() -> bool:
	return is_active
