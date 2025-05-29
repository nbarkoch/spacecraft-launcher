extends RigidBody2D
class_name Spacecraft

# Gravity assist
var gravity_assist: GravityAssist = null

# Fire effect - configured in Godot 4 IDE
@onready var fire_particles: CPUParticles2D = $FireParticles

func _ready():
	self.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	self.freeze = true
	self.gravity_scale = 0

func _physics_process(delta):
	if gravity_assist:
		apply_gravity_assist(delta)
	
	# Update fire effect based on movement
	update_fire_effect()

func update_fire_effect():
	"""Update fire effect based on spacecraft movement"""
	if not fire_particles:
		return
		
	var is_moving = linear_velocity.length() > 10.0
	
	if is_moving and not freeze:
		# Show fire when moving
		fire_particles.emitting = true
		
	else:
		# Hide fire when not moving
		fire_particles.emitting = false

func release():
	"""Release spacecraft from slingshot"""
	self.freeze = false
	print("Spacecraft released from slingshot!")

func enter_gravity_assist(assist: GravityAssist):
	"""Start gravity assist curve"""
	gravity_assist = assist
	print("Started gravity assist")

func apply_gravity_assist(delta):
	"""Apply the curved motion from gravity assist"""
	if not gravity_assist:
		return
	
	# Get updated velocity from gravity assist
	var new_velocity = gravity_assist.update_curve(delta, global_position)
	
	# Apply the new velocity
	linear_velocity = new_velocity
	
	# Rotate spacecraft to face movement direction
	var movement_direction = new_velocity.normalized()
	rotation = movement_direction.angle() + PI/2
	
	# Check if gravity assist is complete
	if gravity_assist.is_curve_complete():
		exit_gravity_assist()

func exit_gravity_assist():
	"""Complete the gravity assist"""
	if not gravity_assist:
		return
	
	print("Gravity assist complete")
	
	# Apply final velocity with boost
	linear_velocity = gravity_assist.get_exit_velocity()
	
	# Clear gravity assist
	gravity_assist = null

func destroy():
	"""Destroy spacecraft when it hits a planet"""
	print("Spacecraft destroyed!")
	queue_free()
	GameManager.currentState = GameManager.GameState.idle
	get_tree().reload_current_scene()
