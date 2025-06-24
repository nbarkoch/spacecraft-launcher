# scripts/visualizers/predictable_trajectory_predictor.gd
extends Node2D
class_name PredictableTrajectoryPredictor

@export var max_prediction_time: float = 4.0
@export var line_width: float = 3.0
@export var normal_color: Color = Color(1.0, 1.0, 1.0, 0.4)

var trajectory_line: Line2D
var is_predicting: bool = false

func _ready():
	create_trajectory_line()

func create_trajectory_line():
	trajectory_line = Line2D.new()
	add_child(trajectory_line)
	trajectory_line.width = line_width
	trajectory_line.default_color = normal_color
	trajectory_line.antialiased = true

func show_trajectory():
	visible = true
	is_predicting = true

func hide_trajectory():
	visible = false
	is_predicting = false
	if trajectory_line:
		trajectory_line.clear_points()

func update_prediction(start_position: Vector2, initial_velocity: Vector2):
	"""עדכן חיזוי - 100% מדויק!"""
	if not is_predicting:
		return
	
	# מצא כוכבי לכת
	var planets = PredictablePhysics.find_all_planets(get_tree())
	
	# חשב מסלול מדויק
	var trajectory_points = PredictablePhysics.simulate_trajectory(
		start_position, 
		initial_velocity, 
		planets, 
		max_prediction_time
	)
	
	# עדכן את הקו
	trajectory_line.clear_points()
	for point in trajectory_points:
		trajectory_line.add_point(to_local(point))
