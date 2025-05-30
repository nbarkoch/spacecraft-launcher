# scripts/planet.gd (SIMPLIFIED - Real Physics)
extends StaticBody2D
class_name Planet

# Visual properties
@export var sprite_texture: Texture2D
@export var glow_color: Color = Color.TRANSPARENT
@export var glow_intensity: float = 0.0
@export var glow_radius: float = 0.0

# Physics properties
@export var planet_radius: float = 20.0
@export var gravity_radius: float = 60.0
@export var gravity_strength: float = 300.0  # Simple force strength

# Visual feedback
@export var show_gravity_zone: bool = true
@export var zone_color: Color = Color(1, 1, 1, 0.3)
@export var zone_rotation_speed: float = 15.0

var gravity_visualizer: GravityZoneVisualizer

func _ready():
	add_to_group("Planets")
	create_unique_resources()
	
	if sprite_texture and $Sprite:
		$Sprite.texture = sprite_texture
	
	setup_collision_shapes()
	if show_gravity_zone:
		setup_gravity_visualization()
	setup_shader_material()

func create_unique_resources():
	"""Create unique resources for this planet instance"""
	if $GravityZone/GravityZoneCollision.shape:
		$GravityZone/GravityZoneCollision.shape = $GravityZone/GravityZoneCollision.shape.duplicate()
	
	if $PlanetArea/Collision.shape:
		$PlanetArea/Collision.shape = $PlanetArea/Collision.shape.duplicate()
	
	if $CollisionShape.shape:
		$CollisionShape.shape = $CollisionShape.shape.duplicate()
	
	if $Sprite.material:
		$Sprite.material = $Sprite.material.duplicate()

func setup_collision_shapes():
	"""Set up collision shapes based on exported parameters"""
	if gravity_radius > 0:
		$GravityZone/GravityZoneCollision.shape.radius = gravity_radius
	if planet_radius > 0:
		$PlanetArea/Collision.shape.radius = planet_radius
		$CollisionShape.shape.radius = planet_radius

func setup_gravity_visualization():
	"""Create visual representation of gravity zone"""
	if gravity_radius <= 0 or zone_color.a == 0:
		return
		
	gravity_visualizer = GravityZoneVisualizer.new()
	add_child(gravity_visualizer)
	
	gravity_visualizer.line_color = zone_color
	gravity_visualizer.rotation_speed = zone_rotation_speed
	gravity_visualizer.set_radius(gravity_radius)
	
	move_child(gravity_visualizer, 0)

func setup_shader_material():
	"""Set up planet glow effect"""
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
	"""Handle spacecraft entering gravity zone"""
	if body is Spacecraft and not body.gravity_assist:
		# Create simple gravity assist
		var assist = GravityAssist.new(self, body.linear_velocity, body.global_position)
		body.enter_gravity_assist(assist)

func _on_gravity_zone_body_exited(body):
	"""Handle spacecraft leaving gravity zone"""
	if body is Spacecraft and body.gravity_assist:
		body.exit_gravity_assist()

func _on_planet_area_body_entered(body):
	"""Handle spacecraft collision with planet surface"""
	if body is Spacecraft:
		body.exit_gravity_assist()
		await get_tree().create_timer(1.5).timeout
		body.destroy()
