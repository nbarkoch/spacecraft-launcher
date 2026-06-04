extends Node2D
class_name TrajectoryPredictor

# Configuration
@export var max_prediction_time: float = 4.0
@export var line_width: float = 3.0
@export var normal_color: Color = Color(1.0, 1.0, 1.0, 0.4)
@export var gravity_color: Color = Color(0.3, 0.7, 1.0, 0.6)
@export var collision_color: Color = Color(1.0, 0.2, 0.2, 0.9)

# Smooth transition properties
@export var transition_speed: float = 8.0
@export var point_interpolation_rate: float = 15.0

# Internal variables
var trajectory_line: Line2D
var is_predicting: bool = false

# Trajectory interpolation
var current_trajectory_points: Array = []
var target_trajectory_points: Array = []
var trajectory_colors: Array = []

func _ready():
	create_trajectory_line()

func _process(delta):
	if is_predicting:
		interpolate_trajectory_points(delta)

func create_trajectory_line():
	"""Create Line2D for trajectory visualization"""
	trajectory_line = Line2D.new()
	add_child(trajectory_line)
	trajectory_line.width = line_width
	trajectory_line.default_color = normal_color
	trajectory_line.antialiased = true

func interpolate_trajectory_points(delta):
	"""Smooth interpolation between current and target trajectory points"""
	if target_trajectory_points.size() == 0:
		return

	if current_trajectory_points.size() == 0:
		current_trajectory_points.append(target_trajectory_points[0])
		trajectory_colors.append(normal_color)

	var interpolation_speed = point_interpolation_rate * delta

	adjust_points_count()

	for i in range(min(current_trajectory_points.size(), target_trajectory_points.size())):
		current_trajectory_points[i] = current_trajectory_points[i].lerp(target_trajectory_points[i], interpolation_speed)

		if i < trajectory_colors.size():
			trajectory_colors[i] = trajectory_colors[i].lerp(get_target_color_for_point(i), interpolation_speed * 2.0)

	update_line_display()

func adjust_points_count():
	"""Adjust the number of current points to match target points"""
	var current_count = current_trajectory_points.size()
	var target_count = target_trajectory_points.size()

	if target_count > current_count:
		var last_point = current_trajectory_points[-1] if current_count > 0 else Vector2.ZERO

		for i in range(current_count, target_count):
			current_trajectory_points.append(last_point)
			trajectory_colors.append(normal_color)

	elif target_count < current_count:
		var points_to_remove = current_count - target_count
		for i in range(points_to_remove):
			if current_trajectory_points.size() > target_count:
				current_trajectory_points.pop_back()
				trajectory_colors.pop_back()

func get_target_color_for_point(point_index: int) -> Color:
	"""Get the target color for a specific point based on game state"""
	return normal_color

func update_line_display():
	"""Update the Line2D with current interpolated points"""
	trajectory_line.clear_points()

	for point in current_trajectory_points:
		trajectory_line.add_point(point)

	if trajectory_colors.size() > 0:
		trajectory_line.default_color = trajectory_colors[0]

func show_trajectory():
	"""Show trajectory prediction"""
	visible = true
	is_predicting = true

func hide_trajectory():
	"""Hide trajectory prediction"""
	visible = false
	is_predicting = false

	current_trajectory_points.clear()
	target_trajectory_points.clear()
	trajectory_colors.clear()

	if trajectory_line:
		trajectory_line.clear_points()

func update_prediction(start_position: Vector2, initial_velocity: Vector2, drag_origin: Vector2 = Vector2.INF):
	"""Update prediction using the spacecraft's own physics simulation.
	   drag_origin: if provided, prepends the drag position so the line starts there."""
	if is_predicting:
		predict_trajectory(start_position, initial_velocity, drag_origin)

func predict_trajectory(start_position: Vector2, initial_velocity: Vector2, drag_origin: Vector2 = Vector2.INF):
	"""
	Run the same step_physics used by Spacecraft, guaranteeing the predicted
	path is identical to the actual flight path.
	"""
	var planets    = get_tree().get_nodes_in_group("Planets")
	var meteoroids = get_tree().get_nodes_in_group("Meteoroids")
	var portals    = get_tree().get_nodes_in_group("Portals")
	var black_holes = get_tree().get_nodes_in_group("BlackHoles")

	var new_points: Array = []
	var delta: float = 1.0 / 60.0
	var time: float = 0.0
	var step: int = 0

	var pos             = start_position
	var vel             = initial_velocity
	var assist_planet   = null
	var assist_time     = 0.0
	var alive           = true
	var sc_rotation     = initial_velocity.angle() + PI / 2.0
	var propulsion_speed = initial_velocity.length()

	while time < max_prediction_time and alive:
		if step % 2 == 0:
			new_points.append(to_local(pos))

		var state = Spacecraft.step_physics(
			pos, vel, assist_planet, assist_time,
			delta, planets, meteoroids, portals, black_holes,
			sc_rotation, propulsion_speed
		)

		pos           = state.pos
		vel           = state.vel
		assist_planet = state.assist_planet
		assist_time   = state.assist_time
		alive         = state.alive
		sc_rotation   = state.sc_rotation

		time += delta
		step += 1

	# Prepend the drag position so the line starts from where the spacecraft is held
	if drag_origin != Vector2.INF:
		new_points.push_front(to_local(drag_origin))

	target_trajectory_points = new_points
