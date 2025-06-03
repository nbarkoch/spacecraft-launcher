extends Area2D

var spacecraft_captured = false

func _ready():
	pass

func _process(delta):
	pass

func _on_body_entered(body):
	if body is Spacecraft and not spacecraft_captured:
		spacecraft_captured = true
		capture_spacecraft(body)
		$AnimationPlayer.play("enter")
		print("level complete")

func capture_spacecraft(spacecraft: Spacecraft):
	# Stop spacecraft movement immediately
	spacecraft.freeze = true
	spacecraft.linear_velocity = Vector2.ZERO
	spacecraft.angular_velocity = 0.0
	
	# Clear any gravity assists
	spacecraft.exit_gravity_assist()
	
	# Create capture animation with Tween
	var tween = create_tween()
	
	# Move spacecraft to target center
	tween.parallel().tween_property(spacecraft, "global_position", global_position, 0.1)
	tween.parallel().tween_property(spacecraft, "scale", Vector2(1.1, 1.1), 0.05)
	await tween.finished
	
	tween = create_tween()
	tween.parallel().tween_property(spacecraft, "scale", Vector2(0.0, 0.0), 0.25)
	tween.parallel().tween_property(spacecraft, "modulate", Color(1, 1, 1, 0), 0.25)
	# Delete spacecraft when animation completes
	await tween.finished
	#spacecraft.queue_free()
	spacecraft.stop()
	
	# Update game state
	GameManager.currentState = GameManager.GameState.success
	
