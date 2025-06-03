extends Node2D
class_name SpacecraftTrail

var spacecraft_ref = null
var trail_points = []
var max_points = 30
var trail_lines = []

func _ready():
	global_position = Vector2.ZERO

func _process(_delta):
	if not spacecraft_ref:
		return
		
	var speed = spacecraft_ref.linear_velocity.length()
	if speed > 15 and not spacecraft_ref.freeze:
		if should_add_point(spacecraft_ref.global_position):
			trail_points.append(spacecraft_ref.global_position)
		
		if trail_points.size() > max_points:
			trail_points.pop_front()
		
		update_trail_segments()

func should_add_point(pos: Vector2) -> bool:
	if trail_points.size() == 0:
		return true
	return pos.distance_to(trail_points[-1]) > 2.0

func update_trail_segments():
	# מחק קווים ישנים
	for line in trail_lines:
		if is_instance_valid(line):
			line.queue_free()
	trail_lines.clear()
	
	# צור קו חדש בין כל שתי נקודות
	for i in range(trail_points.size() - 1):
		var line = Line2D.new()
		
		# חשב progress - 0 = החדש ביותר (עבה), 1 = הישן ביותר (דק)
		var progress = float(i) / max(trail_points.size() - 1, 1)
		var width = lerp(2.0, 8.0, progress)
		var alpha = lerp(0.0, 1.0, progress)
		
		line.width = width
		line.default_color = Color(1.0, 1.0, 1.0, alpha)
		line.antialiased = true
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.z_index = -1
		
		# הוסף שתי נקודות לקו
		line.add_point(trail_points[i])
		line.add_point(trail_points[i + 1])
		
		add_child(line)
		trail_lines.append(line)

func set_spacecraft(craft):
	spacecraft_ref = craft
