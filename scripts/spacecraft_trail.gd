extends Node2D
class_name SpacecraftTrail

var spacecraft_ref = null
var trail_points = []
var dissipating_points = []  # Separate array for dissipating trail
var max_points = 50
var trail_line: Line2D
var dissipating_line: Line2D  # Separate line for dissipating trail

var is_dissipating = false
var dissipation_timer = 0.0
var last_spacecraft_speed = 0.0
var base_dissipation_rate = 0.05

func _ready():
	global_position = Vector2.ZERO
	trail_line = setup_line()
	dissipating_line = setup_line()
	trail_line.visible = false
	dissipating_line.visible = false


func setup_line():
	var line = Line2D.new()
	add_child(line)
	# Create color gradient - FIXED: 0.0 = oldest (tail), 1.0 = newest (spacecraft)
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.3, 0.7, 1.0, 0.0))    # Transparent blue at OLD end
	gradient.add_point(0.3, Color(0.5, 0.8, 1.0, 0.4))    # Semi-transparent 
	gradient.add_point(0.7, Color(0.7, 0.9, 1.0, 0.7))    # More opaque
	gradient.add_point(1.0, Color(1.0, 1.0, 1.0, 1.0))    # Bright white at spacecraft
	line.gradient = gradient
	
	# Create width curve - FIXED: 0.0 = oldest (thin), 1.0 = newest (thick)
	var width_curve = Curve.new()
	width_curve.add_point(Vector2(0.0, 0.0))  # Thin at OLD end
	width_curve.add_point(Vector2(0.3, 0.3))  # Getting thicker
	width_curve.add_point(Vector2(0.7, 0.7))  # Much thicker
	width_curve.add_point(Vector2(1.0, 1.0))  # Full thickness at spacecraft
	line.width_curve = width_curve
	
	# Basic setup
	line.width = 10.0  # Base width (will be modified by curve)
	line.antialiased = true
	line.z_index = -1
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	
	return line
	

func _process(delta):
	if not spacecraft_ref:
		return
	
	# Handle different states
	if dissipating_line.visible:
		handle_dissipating_state(delta)
	if trail_line.visible:
		handle_moving_state(delta)
	
	# Always update both trails
	update_trail_line()
	update_dissipating_trail()
	

func start_dissipation():
	"""Begin the trail dissipation effect - MOVE points to dissipating trail"""
	dissipating_points = trail_points.duplicate()
	trail_points.clear()  # Clear active trail
	trail_line.visible = false
	
	# Show dissipating trail
	dissipating_line.visible = true
	is_dissipating = true
	dissipation_timer = 0.0
	
	# Capture the spacecraft's speed when it stops
	last_spacecraft_speed = spacecraft_ref.linear_velocity.length()

func reset_trail():
	trail_line.visible = true
	trail_points.clear()

func handle_dissipating_state(delta):
	"""Handle trail behavior when spacecraft is frozen"""
	if is_dissipating and dissipating_points.size() > 0:
		# Continue dissipation at the speed the spacecraft was moving
		dissipation_timer += delta
		
		# Calculate dissipation rate based on last spacecraft speed
		var speed_factor = max(last_spacecraft_speed / 100.0, 0.5)
		var dissipation_rate = base_dissipation_rate * speed_factor
		
		# Calculate how many points to remove this frame
		var points_to_remove = int(dissipation_timer / dissipation_rate)
		
		if points_to_remove > 0:
			# Remove points from the beginning (oldest points)
			for i in range(min(points_to_remove, dissipating_points.size())):
				if dissipating_points.size() > 0:
					dissipating_points.pop_front()
			
			# Reset timer for smooth removal
			dissipation_timer = 0.0
			
			
		# Stop dissipating when no points left
		if dissipating_points.size() == 0:
			is_dissipating = false
			dissipating_line.visible = false

func handle_moving_state(delta):
	add_trail_point(spacecraft_ref.global_position)

func add_trail_point(pos: Vector2):
	"""Add new trail point"""
	if trail_points.size() == 0 or pos.distance_to(trail_points[-1]) > 2.0:
		trail_points.append(pos)
		
		# Normal trail length limiting when moving
		if trail_points.size() > max_points:
			trail_points.pop_front()

func update_trail_line():
	"""Update the active trail"""
	trail_line.clear_points()
	for point in trail_points:
		var local_point = to_local(point)
		trail_line.add_point(local_point)

func update_dissipating_trail():
	"""Update the dissipating trail"""
	if is_dissipating and dissipating_line.visible:
		dissipating_line.clear_points()
		for point in dissipating_points:
			var local_point = to_local(point)
			dissipating_line.add_point(local_point)

func set_spacecraft(craft):
	spacecraft_ref = craft
