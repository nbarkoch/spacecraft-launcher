extends Area2D

@export var portal_group: String = "portal1"
var cooldown: float = 0.0
var rotation_tween: Tween
var jump_tween: Tween

func _ready():
	add_to_group(portal_group)
	start_idle_rotation()

func _process(delta):
	if cooldown > 0:
		cooldown -= delta

func _on_body_entered(body):
	if body is Spacecraft and cooldown <= 0:
		teleport_spacecraft(body)
		trigger_jump_effect()

func update_rotation(angle: float):
	$Sprite2D.rotation = angle
	
func start_idle_rotation():
	if rotation_tween:
		rotation_tween.kill()
	rotation_tween = create_tween()
	rotation_tween.set_loops()  # Infinite loop
	# Use tween_method to continuously update rotation
	rotation_tween.tween_method(update_rotation, 0.0, -2 * PI, 12.0)
	
func trigger_jump_effect():
	# Kill any existing jump tween
	if jump_tween:
		jump_tween.kill()
	
	# Create jump animation (rotation continues independently)
	jump_tween = create_tween()
	
	# Scale animation sequence
	jump_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	jump_tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.2)
	jump_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	jump_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	# Reset jumping flag
	await jump_tween.finished


func teleport_spacecraft(spacecraft: Spacecraft):
	var destination = find_other_portal()
	if not destination:
		return
	
	# Set cooldown on both portals
	cooldown = 1.0
	destination.cooldown = 1.0

	# Store state
	var vel = spacecraft.linear_velocity
	var ang_vel = spacecraft.angular_velocity
	var rot = spacecraft.rotation
	
	# Freeze and shrink
	spacecraft.freeze = true
	spacecraft.linear_velocity = Vector2.ZERO
	var tween = create_tween()
	tween.parallel().tween_property(spacecraft, "global_position", global_position, 0.1)
	tween.parallel().tween_property(spacecraft, "scale", Vector2(0.1, 0.1), 0.3)
	await tween.finished
	
	spacecraft.reset(spacecraft.rotation, destination.global_position)
	
	spacecraft.stop() # stop the trail
	destination.trigger_jump_effect()
	
	# Grow back
	tween = create_tween()
	tween.tween_property(spacecraft, "scale", Vector2(1.0, 1.0), 0.3)
	await tween.finished
	
	# Restore state
	spacecraft.freeze = false
	spacecraft.linear_velocity = vel
	spacecraft.angular_velocity = ang_vel
	spacecraft.rotation = rot
	spacecraft.release() # restart the trail

func find_other_portal():
	var portals = get_tree().get_nodes_in_group(portal_group)
	for portal in portals:
		if portal != self:
			return portal
	return null

func reset_physics_position(spacecraft, new_position: Vector2):
	var body_rid = spacecraft.get_rid()
	var new_transform = Transform2D(spacecraft.rotation, new_position)
	
	PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, new_transform)
	PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
	PhysicsServer2D.body_set_state(body_rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
	
	spacecraft.global_position = new_position
	spacecraft.linear_velocity = Vector2.ZERO
	spacecraft.angular_velocity = 0.0
