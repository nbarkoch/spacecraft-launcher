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
@export_range(50.0, 800.0, 10.0) var gravity_strength: float = 300.0

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
	
	update_visual_feedback()

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
	if body is Spacecraft:
		body.exit_gravity_assist()
		body.enter_gravity_assist(GravityAssist.new(self, body))

func _on_gravity_zone_body_exited(body):
	"""Handle spacecraft leaving gravity zone"""
	if body is Spacecraft and body.gravity_assist and body.gravity_assist.planet == self:
		body.exit_gravity_assist()

func _on_planet_area_body_entered(body):
	"""Handle spacecraft collision with planet surface"""
	if body is Spacecraft:
		body.exit_gravity_assist()
		body.is_dead = true
		body.destroy()

# בתוך planet.gd - רק החלקים שצריכים עדכון:

func get_gravity_behavior_type() -> String:
	"""קביעת סוג ההתנהגות של הכדור"""
	return PhysicsUtils.get_gravity_behavior_type(gravity_strength)

func get_prevention_multiplier() -> float:
	"""חישוב כמה מניעת התנגשות הכדור מספק"""
	return PhysicsUtils.get_prevention_multiplier(gravity_strength)

func calculate_approach_angle(spacecraft_pos: Vector2, spacecraft_velocity: Vector2) -> float:
	"""חישוב זווית הגישה"""
	return PhysicsUtils.calculate_approach_angle(spacecraft_pos, spacecraft_velocity, global_position)

func calculate_predicted_orbit_duration(spacecraft_velocity: Vector2, spacecraft_pos: Vector2) -> float:
	"""חישוב משך המסלול החזוי"""
	return PhysicsUtils.calculate_orbit_duration(self, spacecraft_velocity, spacecraft_pos)

func update_visual_feedback():
	"""עדכון צבע הכדור על בסיס עוצמת הגרביטציה"""
	zone_color = PhysicsUtils.calculate_gravity_color(gravity_strength)
	
	if gravity_visualizer:
		gravity_visualizer.set_color(zone_color)
		
