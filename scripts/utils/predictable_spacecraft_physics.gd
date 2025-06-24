# scripts/components/predictable_spacecraft_physics.gd
extends Node
class_name PredictableSpacecraftPhysics

@export var spacecraft: Spacecraft
var physics_state: PredictablePhysics.PhysicsState
var is_active: bool = false

func _ready():
	if not spacecraft:
		spacecraft = get_parent() as Spacecraft

func _physics_process(delta):
	if not is_active:
		return
		
	if not spacecraft:
		print("No spacecraft reference!")
		return
		
	if spacecraft.freeze:
		print("Spacecraft is frozen, skipping physics")
		return
	
	# עדכן את המצב הפיזיקלי
	var planets = PredictablePhysics.find_all_planets(get_tree())
	physics_state = PredictablePhysics.calculate_physics_step(physics_state, planets)
	
	# העבר את המצב לחללית
	apply_state_to_spacecraft()
	
	# בדוק התנגשות
	var collision_planet = PredictablePhysics.check_collision(physics_state.position, planets)
	if collision_planet:
		spacecraft.destroy()

func apply_state_to_spacecraft():
	"""העבר את המצב הפיזיקלי לחללית"""
	spacecraft.global_position = physics_state.position
	spacecraft.rotation = physics_state.rotation
	
	# עדכן את ה-RigidBody2D של גודוט כדי שהוא יישאר מסונכרן
	spacecraft.linear_velocity = physics_state.velocity

func start_physics(initial_position: Vector2, initial_velocity: Vector2):
	"""התחל פיזיקה עם מצב התחלתי"""
	physics_state = PredictablePhysics.PhysicsState.new(initial_position, initial_velocity)
	is_active = true
	print("Started physics - Position: ", initial_position, " Velocity: ", initial_velocity)
	print("Physics active: ", is_active)

func stop_physics():
	"""עצור פיזיקה"""
	is_active = false

func get_current_state() -> PredictablePhysics.PhysicsState:
	"""קבל את המצב הנוכחי"""
	return physics_state.duplicate() if physics_state else null
