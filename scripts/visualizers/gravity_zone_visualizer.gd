extends Node2D
class_name GravityZoneVisualizer

@export var radius: float = 0.0
@export var dash_length: float = 8.0
@export var gap_length: float = 6.0
@export var line_width: float = 3.0
@export var line_color: Color = Color(1.0, 1.0, 1.0, 0.05)  # Light blue, semi-transparent
@export var rotation_speed: float = 30.0  # degrees per second

# Arc sector properties
@export_group("Arc Sector Display")
@export var show_orbit_arc: bool = false
@export var arc_color: Color = Color(1.0, 1.0, 1.0, 0.3)
@export var arc_width: float = 5.0
@export var current_arc_angle: float = 0.0  # in degrees
@export var arc_rotation_speed: float = 45.0  # degrees per second for demonstration

var line2d: Line2D
var arc_line: Line2D
var arc_tween: Tween

func _ready():
	create_dashed_circle()
	create_arc_sector()

func _process(delta):
	# Rotate the main visualization
	rotation_degrees += rotation_speed * delta
	
	# Update arc rotation if showing
	if show_orbit_arc and current_arc_angle > 0:
		update_arc_rotation(delta)

func create_dashed_circle():
	"""Create a dashed circle using Line2D"""
	line2d = Line2D.new()
	add_child(line2d)
	
	line2d.width = line_width
	line2d.default_color = line_color
	line2d.antialiased = true
	line2d.z_index = -1
	
	update_circle_points()

func create_arc_sector():
	"""Create arc sector for orbit duration visualization"""
	arc_line = Line2D.new()
	add_child(arc_line)
	
	arc_line.width = arc_width
	arc_line.default_color = arc_color
	arc_line.antialiased = true
	arc_line.z_index = 1  # Above the dashed circle
	arc_line.visible = false

func update_circle_points():
	"""Generate points for the dashed circle"""
	line2d.clear_points()
	gap_length = radius / 50
	dash_length = radius / 4
	var circumference = 2 * PI * radius
	var dash_and_gap = dash_length + gap_length
	var total_segments = int(circumference / dash_and_gap)
	
	for i in range(total_segments):
		var start_angle = (i * dash_and_gap / radius)
		var end_angle = start_angle + (dash_length / radius)
		
		# Create points for this dash segment
		var points_in_dash = max(3, int(dash_length / 3))  # At least 3 points per dash
		
		for j in range(points_in_dash + 1):
			var progress = float(j) / points_in_dash
			var angle = lerp(start_angle, end_angle, progress)
			var point = Vector2(cos(angle), sin(angle)) * radius
			line2d.add_point(point)
		
		# Add a break between dashes (Line2D will not connect distant points)
		if i < total_segments - 1:
			line2d.add_point(Vector2.INF)  # This creates a break in the line

func update_arc_points():
	"""Generate points for the orbit arc sector"""
	if not arc_line:
		return
		
	arc_line.clear_points()
	
	if current_arc_angle <= 0:
		arc_line.visible = false
		return
	
	arc_line.visible = true
	
	# Convert angle to radians
	var arc_radians = deg_to_rad(current_arc_angle)
	
	# Calculate number of points based on arc size
	var points_count = max(3, int(current_arc_angle / 3.0))  # Point every ~3 degrees
	
	# Generate arc points
	for i in range(points_count + 1):
		var progress = float(i) / points_count
		var angle = progress * arc_radians
		var point = Vector2(cos(angle), sin(angle)) * radius
		arc_line.add_point(point)

func update_arc_rotation(delta):
	"""Update arc rotation for visual movement"""
	if arc_line:
		arc_line.rotation_degrees += arc_rotation_speed * delta

func set_radius(new_radius: float):
	"""Update the radius of the visualization"""
	radius = new_radius
	if line2d:
		update_circle_points()
	if arc_line:
		update_arc_points()

func set_color(new_color: Color):
	"""Update the color of the visualization"""
	line_color = new_color
	if line2d:
		line2d.default_color = line_color

func set_rotation_speed(new_speed: float):
	"""Update the rotation speed"""
	rotation_speed = new_speed

# Arc sector control methods
func show_orbit_prediction(predicted_angle_degrees: float, speed_factor: float = 1.0):
	"""Show orbit prediction arc based on calculated angle"""
	show_orbit_arc = true
	current_arc_angle = clamp(predicted_angle_degrees, 0.0, 360.0)
	
	# Adjust rotation speed based on spacecraft speed
	arc_rotation_speed = clamp(speed_factor * 30.0, 10.0, 120.0)
	
	update_arc_points()
	
func hide_orbit_prediction():
	"""Hide orbit prediction arc"""
	show_orbit_arc = false
	current_arc_angle = 0.0
	if arc_line:
		arc_line.visible = false

func update_orbit_prediction(predicted_angle_degrees: float, speed_factor: float = 1.0):
	"""Update existing orbit prediction with smooth transition"""
	if not show_orbit_arc:
		show_orbit_prediction(predicted_angle_degrees, speed_factor)
		return
	
	var target_angle = clamp(predicted_angle_degrees, 0.0, 360.0)
	var target_speed = clamp(speed_factor * 30.0, 10.0, 120.0)
	
	# Smooth transition to new values
	if arc_tween:
		arc_tween.kill()
	
	arc_tween = create_tween()
	arc_tween.set_parallel(true)
	
	# Smooth angle transition
	arc_tween.tween_method(set_arc_angle, current_arc_angle, target_angle, 0.2)
	
	# Smooth speed transition
	arc_tween.tween_method(set_arc_speed, arc_rotation_speed, target_speed, 0.2)

func set_arc_angle(angle: float):
	"""Internal method for smooth angle transitions"""
	current_arc_angle = angle
	update_arc_points()

func set_arc_speed(speed: float):
	"""Internal method for smooth speed transitions"""
	arc_rotation_speed = speed

func set_arc_color(new_color: Color):
	"""Update arc sector color"""
	arc_color = new_color
	if arc_line:
		arc_line.default_color = arc_color
