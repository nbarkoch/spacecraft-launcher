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
				
				# Constrain mouse position
				mouse_pos.x = min(center_pos.x+60, max(center_pos.x-60, mouse_pos.x))
				mouse_pos.y = min(center_pos.y+60, max(center_pos.y+10, mouse_pos.y))
				
				if mouse_pos.distance_to(center_pos) > 100:
					mouse_pos = (mouse_pos - center_pos).normalized() * 100 + center_pos
				
				# Update line positions
				leftLine.points[0] = leftLine.to_local(mouse_pos)
				rightLine.points[0] = rightLine.to_local(mouse_pos)
				
				# Center spacecraft on mouse position
				spacecraft.global_position = mouse_pos
				
				# Update rotation for visual feedback while aiming
				var launch_direction = center_pos - mouse_pos
				if launch_direction.length() > 0:
					spacecraft.rotation = launch_direction.angle() + PI/2
				
				# Calculate and show trajectory prediction
				var velocity = (center_pos - mouse_pos) * 10
				trajectory_predictor.show_trajectory()
				trajectory_predictor.update_prediction(mouse_pos, velocity)
				
			if Input.is_action_just_released("FINGER_TAP"):
				var mouse_pos = get_global_mouse_position()
				var center_pos = $SlingshotCenter.global_position
				mouse_pos.x = min(center_pos.x+60, max(center_pos.x-60, mouse_pos.x))
				mouse_pos.y = min(center_pos.y+60, max(center_pos.y+10, mouse_pos.y))
				slingshotState = SlingshotState.released
				
				# Hide trajectory predictor
				trajectory_predictor.hide_trajectory()
				
				# Calculate velocity
				var velocity = (center_pos - mouse_pos) * 10
				
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

func _on_touch_area_input_event(viewport, event, shape_idx):
	if slingshotState == SlingshotState.idle and Input.is_action_pressed("FINGER_TAP"):
		# Find spacecraft when starting to pull
		if not spacecraft or not is_instance_valid(spacecraft):
			var spacecrafts = get_tree().get_nodes_in_group("Spacecrafts")
			if spacecrafts.size() > 0:
				spacecraft = spacecrafts[0] as Spacecraft
		
		if spacecraft:
			slingshotState = SlingshotState.pulling
			print("Spacecraft captured and reset for new launch")
