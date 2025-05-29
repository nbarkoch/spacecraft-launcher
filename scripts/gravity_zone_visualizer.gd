extends Node2D
class_name GravityZoneVisualizer

@export var radius: float = 0.0
@export var dash_length: float = 8.0
@export var gap_length: float = 6.0
@export var line_width: float = 2.0
@export var line_color: Color = Color(1.0, 1.0, 1.0, 0.35)  # Light blue, semi-transparent
@export var rotation_speed: float = 30.0  # degrees per second

var line2d: Line2D

func _ready():
	create_dashed_circle()

func _process(delta):
	# Rotate the visualization
	rotation_degrees += rotation_speed * delta

func create_dashed_circle():
	"""Create a dashed circle using Line2D"""
	line2d = Line2D.new()
	add_child(line2d)
	
	line2d.width = line_width
	line2d.default_color = line_color
	line2d.antialiased = true
	
	update_circle_points()

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

func set_radius(new_radius: float):
	"""Update the radius of the visualization"""
	radius = new_radius
	if line2d:
		update_circle_points()

func set_color(new_color: Color):
	"""Update the color of the visualization"""
	line_color = new_color
	if line2d:
		line2d.default_color = line_color

func set_rotation_speed(new_speed: float):
	"""Update the rotation speed"""
	rotation_speed = new_speed
