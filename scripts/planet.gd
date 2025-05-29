extends StaticBody2D
class_name Planet

# Config
@export var gravity_strength: float = 300.0
@export var gravity_radius: float = 50.0
@export var planet_radius: float = 25.0

# Visualization
@export var show_gravity_zone: bool = true
@export var zone_color: Color = Color(0.5, 0.8, 1.0, 0.6)
@export var zone_rotation_speed: float = 30.0

var gravity_visualizer: GravityZoneVisualizer

func _ready():
	setup_collision_shapes()
	if show_gravity_zone:
		setup_gravity_visualization()
	var material = $Sprite.material as ShaderMaterial
	if material:
		# Change glow radius dynamically
		pass
		material.set_shader_parameter("glow_radius", 0.25)
		material.set_shader_parameter("glow_intensity", 0.2)
		material.set_shader_parameter("planet_size", 0.28)

func setup_collision_shapes():
	"""Set up the collision shapes based on configured radii"""
	$GravityZone/GravityZoneCollision.shape.radius = gravity_radius
	$PlanetArea/Collision.shape.radius = planet_radius
	$CollisionShape.shape.radius = planet_radius

func setup_gravity_visualization():
	"""Create and configure the gravity zone visualization"""
	gravity_visualizer = GravityZoneVisualizer.new()
	add_child(gravity_visualizer)
	
	# Configure the visualizer
	gravity_visualizer.line_color = zone_color
	gravity_visualizer.rotation_speed = zone_rotation_speed
	gravity_visualizer.set_radius(gravity_radius)
	
	# Position it behind the planet sprite
	move_child(gravity_visualizer, 0)

func _on_gravity_zone_body_entered(body):
	if body is Spacecraft and not body.gravity_assist:
		print("Spacecraft entered gravity assist zone")
		
		var spacecraft_velocity = body.linear_velocity
		print("Entry velocity: ", spacecraft_velocity, " Speed: ", spacecraft_velocity.length())
		
		# Create simple gravity assist
		var assist = GravityAssist.new(self, spacecraft_velocity)
		
		# Start gravity assist
		body.enter_gravity_assist(assist)

func _on_planet_area_body_entered(body):
	if body is Spacecraft:
		print("Spacecraft crashed into planet!")
		body.exit_gravity_assist()
		await get_tree().create_timer(1.5).timeout
		body.destroy()


func toggle_visualization(visible: bool):
	"""Show/hide the gravity zone visualization"""
	show_gravity_zone = visible
	if gravity_visualizer:
		gravity_visualizer.visible = visible

func set_visualization_color(color: Color):
	"""Change the color of the gravity zone visualization"""
	zone_color = color
	if gravity_visualizer:
		gravity_visualizer.set_color(color)
