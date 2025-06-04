extends Area2D

var rotation_tween: Tween
var bodies_in_zone = []

@export var gravity_strength: float = 12000.0  # Even stronger
@export var gravity_radius: float = 25.0

func _ready():
	start_idle_rotation()
	setup_gravity_zone()
	print("Black hole ready with gravity radius: ", gravity_radius)

func _process(delta):
	# Apply gravity to all bodies in zone
	for body in bodies_in_zone:
		if is_instance_valid(body):
			apply_gravity(body, delta)

func setup_gravity_zone():
	# Create gravity detection area
	var gravity_area = Area2D.new()
	gravity_area.name = "GravityZone"
	add_child(gravity_area)
	
	# Set collision layers properly
	gravity_area.collision_layer = 0  # Don't collide with anything
	gravity_area.collision_mask = 1   # Detect bodies on layer 1
	
	var collision = CollisionShape2D.new()
	gravity_area.add_child(collision)
	
	var circle = CircleShape2D.new()
	circle.radius = gravity_radius
	collision.shape = circle
	
	# Connect signals
	gravity_area.body_entered.connect(_on_gravity_entered)
	gravity_area.body_exited.connect(_on_gravity_exited)
	
	print("Gravity zone created with radius: ", gravity_radius)

func _on_gravity_entered(body):
	print("Body entered gravity zone: ", body.name)
	if body is RigidBody2D and not body.name.contains("Planet"):  # Don't pull planets
		bodies_in_zone.append(body)
		print("Added to gravity tracking. Total bodies: ", bodies_in_zone.size())

func _on_gravity_exited(body):
	print("Body exited gravity zone: ", body.name)
	bodies_in_zone.erase(body)
	print("Removed from gravity tracking. Total bodies: ", bodies_in_zone.size())

func apply_gravity(body: RigidBody2D, delta: float):
	var direction = global_position - body.global_position
	var distance = direction.length()
	
	if distance > 15:
		# Check if moving toward or away from black hole
		var velocity_toward_blackhole = body.linear_velocity.dot(direction.normalized())
		var current_speed = body.linear_velocity.length()
		
		# If moving away from black hole, slow it down
		if velocity_toward_blackhole < 0:  # Moving away
			body.linear_velocity = body.linear_velocity.lerp(Vector2.ZERO, 0.08)
			print("Spacecraft trying to escape - slowing it down")
		
		# Calculate gravity force - MUCH stronger when moving slowly
		var base_force = gravity_strength / max(distance * 0.02, 1.0)
		
		# Boost force when spacecraft is slow (trapped)
		if current_speed < 50:  # When almost stopped
			base_force *= 5.0  # 5x stronger force
			print("Spacecraft trapped - applying strong suction!")
		
		var force = direction.normalized() * base_force * delta
		body.apply_central_force(force)
		
		# Stop any gravity assists
		if body.has_method("exit_gravity_assist"):
			body.exit_gravity_assist()
		
		print("Pulling ", body.name, " - speed: ", current_speed, " force: ", force.length())

func update_rotation(angle: float):
	$Sprite2D.rotation = angle
	
func start_idle_rotation():
	if rotation_tween:
		rotation_tween.kill()
	rotation_tween = create_tween()
	rotation_tween.set_loops()
	rotation_tween.tween_method(update_rotation, 0.0, -2 * PI, 12.0)

func _on_body_entered(body):
	print("Body hit black hole center: ", body.name)
	# Remove from gravity tracking before destroying
	bodies_in_zone.erase(body)
	
	var tween = create_tween()
	tween.parallel().tween_property(body, "global_position", global_position, 0.1)
	tween.parallel().tween_property(body, "scale", Vector2(0.1, 0.1), 0.3)
	await tween.finished
	
	if body is Spacecraft:
		body.destroy()
	else:
		body.queue_free()
