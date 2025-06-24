# scripts/physics/predictable_physics.gd
class_name PredictablePhysics

# קבועים דטרמיניסטיים - אלה הם הכללים המוחלטים
const PHYSICS_TIMESTEP: float = 1.0 / 60.0  # תמיד 60 FPS
const BASE_DAMPING: float = 0.998           # דמפינג קבוע
const SPACECRAFT_RADIUS: float = 6.0        # רדיוס החללית

# מבנה נתונים למצב פיזיקלי
class PhysicsState:
	var position: Vector2
	var velocity: Vector2
	var rotation: float
	var angular_velocity: float
	
	func _init(pos: Vector2 = Vector2.ZERO, vel: Vector2 = Vector2.ZERO, rot: float = 0.0, ang_vel: float = 0.0):
		position = pos
		velocity = vel
		rotation = rot
		angular_velocity = ang_vel
	
	func duplicate() -> PhysicsState:
		return PhysicsState.new(position, velocity, rotation, angular_velocity)

# חישוב צעד פיזיקה יחיד - פונקציה טהורה לחלוטין
static func calculate_physics_step(state: PhysicsState, planets: Array) -> PhysicsState:
	var new_state = state.duplicate()
	
	# 1. חשב כוחי כבידה
	var gravity_force = calculate_gravity_force(state.position, planets)
	
	# 2. עדכן מהירות
	new_state.velocity += gravity_force
	new_state.velocity *= BASE_DAMPING
	
	# 3. עדכן מיקום
	new_state.position += new_state.velocity * PHYSICS_TIMESTEP
	
	# 4. עדכן סיבוב (החללית מסתובבת לכיוון התנועה)
	if new_state.velocity.length() > 1.0:
		var target_rotation = new_state.velocity.angle() + PI/2
		new_state.rotation = lerp_angle(new_state.rotation, target_rotation, 0.1)
	
	return new_state

# חישוב כוח כבידה - פונקציה טהורה
static func calculate_gravity_force(position: Vector2, planets: Array) -> Vector2:
	var total_force = Vector2.ZERO
	
	for planet in planets:
		if not planet or not is_instance_valid(planet):
			continue
		
		var to_planet = planet.global_position - position
		var distance = to_planet.length()
		
		# בדוק אם בתוך אזור הכבידה
		if distance <= planet.gravity_radius and distance > 1.0:
			# נוסחה פשוטה ודטרמיניסטית
			var force_magnitude = (planet.gravity_strength * PHYSICS_TIMESTEP * 60.0) / (distance * 0.01)
			var force_direction = to_planet.normalized()
			total_force += force_direction * force_magnitude
			break  # רק כוכב אחד בכל פעם
	
	return total_force

# בדיקת התנגשות - פונקציה טהורה
static func check_collision(position: Vector2, planets: Array) -> Planet:
	for planet in planets:
		if not planet or not is_instance_valid(planet):
			continue
		
		var distance = position.distance_to(planet.global_position)
		if distance <= (planet.planet_radius + SPACECRAFT_RADIUS):
			return planet
	return null

# סימולציה מלאה של מסלול - זה מה שהחיזוי ישתמש בו
static func simulate_trajectory(start_position: Vector2, start_velocity: Vector2, planets: Array, max_time: float = 4.0) -> Array:
	var trajectory_points = []
	var state = PhysicsState.new(start_position, start_velocity)
	var time_elapsed = 0.0
	var step_count = 0
	
	while time_elapsed < max_time:
		# הוסף נקודה כל כמה צעדים
		if step_count % 2 == 0:
			trajectory_points.append(state.position)
		
		# חשב צעד פיזיקה
		state = calculate_physics_step(state, planets)
		
		# בדוק התנגשות
		var collision_planet = check_collision(state.position, planets)
		if collision_planet:
			break
		
		# בדוק גבולות
		if abs(state.position.x) > 1000.0 or abs(state.position.y) > 1000.0:
			break
		
		time_elapsed += PHYSICS_TIMESTEP
		step_count += 1
		
		# מגבלת בטיחות
		if step_count > 300:
			break
	
	return trajectory_points

# מצא כל כוכבי הלכת בסצנה
static func find_all_planets(scene_tree: SceneTree) -> Array:
	return scene_tree.get_nodes_in_group("Planets")
