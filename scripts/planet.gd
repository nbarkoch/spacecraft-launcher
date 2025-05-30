# scripts/planet.gd (With orbit behavior controls)
extends StaticBody2D
class_name Planet

# Required parameters
@export var sprite_texture: Texture2D
@export var gravity_strength: float = 0.0
@export var gravity_radius: float = 0.0
@export var planet_radius: float = 0.0
@export var glow_color: Color = Color.TRANSPARENT
@export var glow_intensity: float = 0.0
@export var glow_radius: float = 0.0

# Orbit behavior configuration
@export var curve_strength_multiplier: float = 1.0  # How much to curve (higher = tighter curves)
@export var curve_duration_multiplier: float = 1.0  # How long the curve lasts (higher = longer effect)
@export var speed_boost_multiplier: float = 1.1     # Speed boost when exiting (1.0 = no boost, 2.0 = double speed)
@export var rotation_intensity: float = 1.0         # How much the planet makes ships rotate

# Visualization
@export var show_gravity_zone: bool = true
@export var zone_color: Color = Color.TRANSPARENT
@export var zone_rotation_speed: float = 15.0

var gravity_visualizer: GravityZoneVisualizer

func _ready():
	add_to_group("Planets")
	
	# IMPORTANT: Create unique resources for this instance
	create_unique_resources()
	
	if sprite_texture and $Sprite:
		$Sprite.texture = sprite_texture
	
	setup_collision_shapes()
	if show_gravity_zone:
		setup_gravity_visualization()
	setup_shader_material()

func create_unique_resources():
	"""Create unique resources for this planet instance to prevent sharing"""
	
	# Make unique collision shapes
	if $GravityZone/GravityZoneCollision.shape:
		$GravityZone/GravityZoneCollision.shape = $GravityZone/GravityZoneCollision.shape.duplicate()
	
	if $PlanetArea/Collision.shape:
		$PlanetArea/Collision.shape = $PlanetArea/Collision.shape.duplicate()
	
	if $CollisionShape.shape:
		$CollisionShape.shape = $CollisionShape.shape.duplicate()
	
	# Make unique shader material
	if $Sprite.material:
		$Sprite.material = $Sprite.material.duplicate()

func setup_collision_shapes():
	if gravity_radius > 0:
		$GravityZone/GravityZoneCollision.shape.radius = gravity_radius
	if planet_radius > 0:
		$PlanetArea/Collision.shape.radius = planet_radius
		$CollisionShape.shape.radius = planet_radius

func setup_gravity_visualization():
	if gravity_radius <= 0 or zone_color.a == 0:
		return
		
	gravity_visualizer = GravityZoneVisualizer.new()
	add_child(gravity_visualizer)
	
	gravity_visualizer.line_color = zone_color
	gravity_visualizer.rotation_speed = zone_rotation_speed
	gravity_visualizer.set_radius(gravity_radius)
	
	move_child(gravity_visualizer, 0)

func setup_shader_material():
	var material = $Sprite.material as ShaderMaterial
	if material and glow_color.a > 0 and glow_intensity > 0:
		material.set_shader_parameter("glow_color", glow_color)
		material.set_shader_parameter("glow_intensity", glow_intensity)
		material.set_shader_parameter("glow_radius", glow_radius)
		material.set_shader_parameter("planet_size", 0.28)
	
	# Scale sprite according to planet radius
	if planet_radius > 0 and $Sprite:
		var scale_factor = (planet_radius * 2.0) / 145.0
		$Sprite.scale = Vector2(scale_factor, scale_factor)

func _on_gravity_zone_body_entered(body):
	if gravity_strength <= 0:
		return
		
	if body is Spacecraft and not body.gravity_assist:
		var spacecraft_velocity = body.linear_velocity
		# Create gravity assist with this planet's specific configuration
		var assist = GravityAssist.new(self, spacecraft_velocity)
		body.enter_gravity_assist(assist)

func _on_planet_area_body_entered(body):
	if body is Spacecraft:
		body.exit_gravity_assist()
		await get_tree().create_timer(1.5).timeout
		body.destroy()

func toggle_visualization(visible: bool):
	show_gravity_zone = visible
	if gravity_visualizer:
		gravity_visualizer.visible = visible

func set_visualization_color(color: Color):
	zone_color = color
	if gravity_visualizer:
		gravity_visualizer.set_color(color)

func _on_gravity_zone_body_exited(body):
	if body is Spacecraft and body.gravity_assist:
		body.exit_gravity_assist()
