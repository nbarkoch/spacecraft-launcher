extends RigidBody2D
class_name Spacecraft

# Gravity assist
var gravity_assist: GravityAssist = null
var is_dead = false
# Fire effect
@onready var fire_particles: CPUParticles2D = $FireParticles

func _ready():
	self.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	self.freeze = true
	self.gravity_scale = 0
	add_to_group("Spacecrafts")

func _physics_process(delta):
	# Only apply gravity assist if we have one
	if gravity_assist:
		apply_gravity_assist(delta)
	
	update_fire_effect()

func update_fire_effect():
	"""Update fire effect based on spacecraft movement"""
	if not fire_particles:
		return
		
	var is_moving = linear_velocity.length() > 10.0
	
	if is_moving and not freeze:
		fire_particles.emitting = true
	else:
		fire_particles.emitting = false

func release():
	"""Release spacecraft from slingshot"""
	self.freeze = false
	print("Spacecraft released from slingshot!")

func enter_gravity_assist(assist: GravityAssist):
	"""Start gravity assist"""
	gravity_assist = assist
	print("Started gravity assist")

func apply_gravity_assist(delta):
	if not gravity_assist or is_dead:
		return
	
	var gravity_force = gravity_assist.update_curve(delta, global_position)
	linear_velocity += gravity_force
	
	# Rotate spacecraft
	if linear_velocity.length() > 0:
		var movement_direction = linear_velocity.normalized()
		rotation = movement_direction.angle() + PI/2

func exit_gravity_assist():
	"""Stop gravity assist"""
	if gravity_assist:
		print("Gravity assist complete")
		gravity_assist = null

func destroy():
	"""Destroy spacecraft when it hits a planet"""
	print("Spacecraft destroyed!")
	queue_free()
	GameManager.currentState = GameManager.GameState.idle
	get_tree().reload_current_scene()
