extends Node2D
enum SlingshotState {
	idle,
	pulling,
	released,
	reset
}

# Properties
var slingshotState
var leftLine
var rightLine
var spacecraft
var trajectory_predictor
const MULTIPLIER = 6

# Snap system - עדין ולא פולשני
const ANGLE_SNAP_INTERVAL = 22.5  # כל 22.5 מעלות (16 כיוונים)
const DISTANCE_SNAP_INTERVAL = 15.0  # כל 15 פיקסלים
const SNAP_RADIUS = 8.0  # בתוך כמה פיקסלים יש משיכה
const SNAP_STRENGTH = 0.4  # עוצמת המשיכה (0-1)

var raw_mouse_pos = Vector2.ZERO
const MOUSE_SMOOTHING = 0.3

# Smooth transition for snap
var current_mouse_pos = Vector2.ZERO
var target_mouse_pos = Vector2.ZERO
const TRANSITION_SPEED = 12.0  # מהירות המעבר החלק

func _ready():
	slingshotState = SlingshotState.idle
	leftLine = $LeftLine
	rightLine = $RightLine
	
	# Create trajectory predictor
	trajectory_predictor = TrajectoryPredictor.new()
	add_child(trajectory_predictor)
	trajectory_predictor.hide_trajectory()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	match slingshotState:
		SlingshotState.idle:
			pass
		SlingshotState.pulling:
			if Input.is_action_pressed("FINGER_TAP"):
				var mouse_pos = get_global_mouse_position()
				var center_pos = $SlingshotCenter.global_position
				
				# החלקה בסיסית של תנועת עכבר
				var raw_mouse_pos = raw_mouse_pos.lerp(mouse_pos, MOUSE_SMOOTHING)
				
				# Constrain mouse position - כמו במקורי
				raw_mouse_pos.x = min(center_pos.x+60, max(center_pos.x-60, raw_mouse_pos.x))
				raw_mouse_pos.y = min(center_pos.y+60, max(center_pos.y+10, raw_mouse_pos.y))
				
				if raw_mouse_pos.distance_to(center_pos) > 100:
					raw_mouse_pos = (raw_mouse_pos - center_pos).normalized() * 100 + center_pos
				
				# עדכן target position עם snap
				target_mouse_pos = apply_subtle_snap(raw_mouse_pos, center_pos)
				
				# transition חלק למיקום החדש
				current_mouse_pos = current_mouse_pos.move_toward(target_mouse_pos, TRANSITION_SPEED * delta * 60.0)
				
				# Update line positions with smooth position
				leftLine.points[0] = leftLine.to_local(current_mouse_pos)
				rightLine.points[0] = rightLine.to_local(current_mouse_pos)
				
				# Center spacecraft on smooth position
				spacecraft.global_position = current_mouse_pos
				
				# Update rotation for visual feedback while aiming
				var launch_direction = center_pos - current_mouse_pos
				if launch_direction.length() > 0:
					spacecraft.rotation = launch_direction.angle() + PI/2
				
				# Calculate and show trajectory prediction
				var velocity = (center_pos - current_mouse_pos) * MULTIPLIER
				trajectory_predictor.show_trajectory()
				trajectory_predictor.update_prediction(current_mouse_pos, velocity * 0.9)
				
			if Input.is_action_just_released("FINGER_TAP"):
				var center_pos = $SlingshotCenter.global_position
				
				# השתמש במיקום הנוכחי החלק
				var final_mouse_pos = current_mouse_pos
				
				slingshotState = SlingshotState.released
				
				# Hide trajectory predictor
				trajectory_predictor.hide_trajectory()
				
				# Calculate velocity with smooth position
				var velocity = (center_pos - final_mouse_pos) * MULTIPLIER
				
				# Rotation is already set from pulling phase
				# Release spacecraft
				spacecraft.linear_velocity = Vector2.ZERO
				spacecraft.angular_velocity = 0.0
				spacecraft.gravity_assist = null  # Clear any gravity assist
				spacecraft.freeze = true  # Freeze it again
				spacecraft.release()
				await get_tree().process_frame
				spacecraft.apply_impulse(velocity)
				
				GameManager.currentState = GameManager.GameState.action
				
		SlingshotState.released:
			# Reset line positions
			leftLine.points[0] = leftLine.to_local($SlingshotCenter.global_position)
			rightLine.points[0] = rightLine.to_local($SlingshotCenter.global_position)
			
			# Check if spacecraft is done (destroyed or out of bounds)
			if not spacecraft or not is_instance_valid(spacecraft):
				# Reset for next shot
				slingshotState = SlingshotState.idle
				GameManager.currentState = GameManager.GameState.idle
				
		SlingshotState.reset:
			pass

func apply_subtle_snap(mouse_pos: Vector2, center_pos: Vector2) -> Vector2:
	"""הפעל snap עדין על המיקום"""
	var pull_vector = mouse_pos - center_pos
	
	if pull_vector.length() < 5.0:
		return mouse_pos
	
	# Snap זווית
	var current_angle = pull_vector.angle()
	var snapped_angle = apply_angle_snap(current_angle)
	
	# Snap מרחק  
	var current_distance = pull_vector.length()
	var snapped_distance = apply_distance_snap(current_distance)
	
	# בנה וקטור חדש
	var snapped_vector = Vector2(cos(snapped_angle), sin(snapped_angle)) * snapped_distance
	var snapped_pos = center_pos + snapped_vector
	
	return snapped_pos

func apply_angle_snap(angle: float) -> float:
	"""הפעל snap עדין על זווית"""
	var angle_degrees = rad_to_deg(angle)
	
	# מצא את נקודת הsnap הקרובה ביותר
	var nearest_snap = round(angle_degrees / ANGLE_SNAP_INTERVAL) * ANGLE_SNAP_INTERVAL
	var distance_to_snap = abs(angle_degrees - nearest_snap)
	
	# טפל במקרה של חצייה של 180/-180
	if distance_to_snap > 180:
		distance_to_snap = 360 - distance_to_snap
	
	# אם קרוב מספיק, הפעל snap
	var snap_threshold = ANGLE_SNAP_INTERVAL * 0.4  # 40% מהמרווח
	if distance_to_snap <= snap_threshold:
		var snap_factor = 1.0 - (distance_to_snap / snap_threshold)
		snap_factor = snap_factor * SNAP_STRENGTH
		
		# טפל בחצייה של זוויות
		if abs(angle_degrees - nearest_snap) > 180:
			if angle_degrees > nearest_snap:
				nearest_snap += 360
			else:
				nearest_snap -= 360
		
		angle_degrees = lerp(angle_degrees, nearest_snap, snap_factor)
	
	return deg_to_rad(angle_degrees)

func apply_distance_snap(distance: float) -> float:
	"""הפעל snap עדין על מרחק"""
	# מצא את נקודת הsnap הקרובה ביותר
	var nearest_snap = round(distance / DISTANCE_SNAP_INTERVAL) * DISTANCE_SNAP_INTERVAL
	var distance_to_snap = abs(distance - nearest_snap)
	
	# אם קרוב מספיק, הפעל snap
	if distance_to_snap <= SNAP_RADIUS:
		var snap_factor = 1.0 - (distance_to_snap / SNAP_RADIUS)
		snap_factor = snap_factor * SNAP_STRENGTH
		
		distance = lerp(distance, nearest_snap, snap_factor)
	
	return distance

func _on_touch_area_input_event(viewport, event, shape_idx):
	if slingshotState == SlingshotState.idle and Input.is_action_pressed("FINGER_TAP"):
		# Find spacecraft when starting to pull
		if not spacecraft or not is_instance_valid(spacecraft):
			var spacecrafts = get_tree().get_nodes_in_group("Spacecrafts")
			if spacecrafts.size() > 0:
				spacecraft = spacecrafts[0] as Spacecraft
		
		if spacecraft:
			slingshotState = SlingshotState.pulling
			# אתחל מיקומים
			var initial_pos = get_global_mouse_position()
			current_mouse_pos = initial_pos
			target_mouse_pos = initial_pos
			raw_mouse_pos = initial_pos
