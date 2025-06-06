# scripts/planet.gd (UPDATED WITH ORBIT DURATION CONTROL)
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

# Constants for behavior calculation
const MIN_GRAVITY = 50.0
const MAX_GRAVITY = 800.0
const NEUTRAL_GRAVITY = 300.0
const BASE_ORBIT_DURATION = 3.0

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
		#await get_tree().create_timer(1.5).timeout
		body.destroy()
		
		

func get_gravity_behavior_type() -> String:
	"""Determine what type of behavior this planet has based on gravity"""
	if gravity_strength < 150.0:
		return "helpful"     # Push out + sweet spot help
	elif gravity_strength <= 400.0:
		return "normal"      # Sweet spot help only  
	elif gravity_strength <= 600.0:
		return "challenging" # Minimal help
	else:
		return "evil"        # Push IN toward planet

func get_prevention_multiplier() -> float:
	"""Calculate how much collision prevention this planet provides"""
	var behavior = get_gravity_behavior_type()
	
	match behavior:
		"helpful":
			return 2.0  # Double prevention force
		"normal":
			return 1.0  # Normal prevention
		"challenging":
			return 0.3  # Weak prevention
		"evil":
			return -0.5 # NEGATIVE = pulls spacecraft IN
		_:
			return 1.0

func calculate_approach_angle(spacecraft_pos: Vector2, spacecraft_velocity: Vector2) -> float:
	"""Calculate how perpendicular the approach is (0° = head-on, 90° = tangential)"""
	var to_planet = global_position - spacecraft_pos
	var approach_direction = spacecraft_velocity.normalized()
	
	if spacecraft_velocity.length() < 1.0:
		return 0.0  # No velocity = head-on collision
	
	# Calculate angle between velocity and direction to planet center
	var dot_product = to_planet.normalized().dot(approach_direction)
	var angle_radians = acos(clamp(abs(dot_product), 0.0, 1.0))
	var angle_degrees = rad_to_deg(angle_radians)
	
	# Return perpendicularity: 0° = head-on, 90° = tangential
	return min(angle_degrees, 90.0)

func calculate_predicted_orbit_duration(spacecraft_velocity: Vector2, spacecraft_pos: Vector2) -> float:
	"""Calculate orbit duration based on gravity, velocity, and approach angle"""
	var speed = spacecraft_velocity.length()
	var approach_angle = calculate_approach_angle(spacecraft_pos, spacecraft_velocity)
	
	if speed <= 0 or approach_angle < 5.0:  # Head-on approaches
		return 0.1  # Very short time before crash
	
	# Base duration scaling factors
	var gravity_factor = NEUTRAL_GRAVITY / gravity_strength  # Lower gravity = longer duration
	var velocity_factor = 100.0 / max(speed, 10.0)  # Higher velocity = shorter duration  
	var angle_factor = approach_angle / 90.0  # More perpendicular = longer duration
	
	# Calculate final duration
	var duration = BASE_ORBIT_DURATION * gravity_factor * velocity_factor * angle_factor
	
	# Clamp to reasonable bounds
	return clamp(duration, 0.1, 8.0)

func update_visual_feedback():
	"""Update planet appearance based on gravity behavior"""
	var behavior = get_gravity_behavior_type()
	
	# Update zone color to indicate planet behavior
	match behavior:
		"helpful":
			zone_color = Color("#7FC1CE") * 0.4  # Green = safe
		"normal":
			zone_color = Color.BLUE * 0.3   # Blue = normal
		"challenging":
			zone_color = Color.YELLOW * 0.3 # Yellow = warning
		"evil":
			zone_color = Color.RED * 0.4    # Red = danger
	
	# Update gravity visualizer if it exists
	if gravity_visualizer:
		gravity_visualizer.set_color(zone_color)

