extends Node2D
class_name SpacecraftTrail

var spacecraft_ref = null
var trail_points = []
var dissipating_points = []  # Separate array for dissipating trail
var max_points = 50
var trail_line: Line2D
var trail_line2: Line2D  # Border line (wider, behind)
var dissipating_line: Line2D  # Separate line for dissipating trail
var dissipating_line2: Line2D  # Border for dissipating trail

var is_dissipating = false
var dissipation_timer = 0.0
var last_spacecraft_speed = 0.0
var base_dissipation_rate = 0.05

func _ready():
	global_position = Vector2.ZERO
	trail_line2 = setup_border_line()  # Create border first (behind)
	trail_line = setup_line()
	
	dissipating_line2 = setup_border_line()
	dissipating_line = setup_line()
	trail_line.visible = false
	trail_line2.visible = false
	dissipating_line.visible = false
	dissipating_line2.visible = false

func setup_border_line():
	var line = Line2D.new()
	add_child(line)
	# Darker border gradient - using same colors but darker
	var darkness_factor = 0.8  # How much darker (0.0 = black, 1.0 = original)
	var gradient = Gradient.new()
	
	# Take original colors and make them darker
	var color1 = Color(0.380, 0.706, 0.788, 0.0) * darkness_factor
	var color2 = Color(0.380, 0.706, 0.788, 0.3) * darkness_factor
	var color3 = Color(0.988, 0.973, 0.651, 0.5) * darkness_factor
	var color4 = Color(  1.0,     1,     1, 0.7) * darkness_factor
	
	# Keep original alpha values
	color1.a = 0.0
	color2.a = 0.4
	color3.a = 0.7
	color4.a = 0.9
	
	gradient.add_point(0.0, color1)
	gradient.add_point(0.5, color2)
	gradient.add_point(0.8, color3)
	gradient.add_point(1.0, color4)
	line.gradient = gradient
	
	var width_curve = Curve.new()
	width_curve.add_point(Vector2(0.0, 0.0))  
	width_curve.add_point(Vector2(1.0, 1.0))
	line.width_curve = width_curve
	
	# Border is wider
	line.width = 7.0  # Wider than main trail
	line.antialiased = true
	line.z_index = -1  # Behind main trail
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	
	return line

func setup_line():
	var line = Line2D.new()
	add_child(line)
	# Create color gradient - FIXED: 0.0 = oldest (tail), 1.0 = newest (spacecraft)
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.380, 0.706, 0.788, 0.0))    # Transparent blue at OLD end
	gradient.add_point(0.5, Color(0.380, 0.706, 0.788, 0.3))    # More opaque
	gradient.add_point(0.8, Color(0.988, 0.973, 0.651, 0.5)) 
	gradient.add_point(1.0, Color(  1.0,   0.8,   0.4, 0.7))   
	   # Bright white at spacecraft
	line.gradient = gradient
	var width_curve = Curve.new()
	
	width_curve.add_point(Vector2(0.3, 0.0))  
	width_curve.add_point(Vector2(1.0, 1.0))
	line.width_curve = width_curve
	
	# Basic setup
	line.width = 5.0  # Base width (will be modified by curve)
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
	await get_tree().process_frame
	trail_points.clear()  # Clear active trail
	trail_line.visible = false
	trail_line2.visible = false
	
	# Show dissipating trail
	dissipating_line.visible = true
	dissipating_line2.visible = true
	is_dissipating = true
	dissipation_timer = 0.0
	
	# Capture the spacecraft's speed when it stops
	last_spacecraft_speed = spacecraft_ref.linear_velocity.length()

func reset_trail():
	trail_line.visible = true
	trail_line2.visible = true
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
			dissipating_line2.visible = false

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
	trail_line2.clear_points()  # Border line
	
	for point in trail_points:
		var local_point = to_local(point)
		trail_line.add_point(local_point)
		trail_line2.add_point(local_point)  # Same points for border

func update_dissipating_trail():
	"""Update the dissipating trail"""
	if is_dissipating and dissipating_line.visible:
		dissipating_line.clear_points()
		dissipating_line2.clear_points()  # Border line
		
		for point in dissipating_points:
			var local_point = to_local(point)
			dissipating_line.add_point(local_point)
			dissipating_line2.add_point(local_point)  # Same points for border

func set_spacecraft(craft):
	spacecraft_ref = craft
