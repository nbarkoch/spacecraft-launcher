# scripts/elements/arrow_pad.gd
extends Area2D
class_name ArrowPad

@export_group("Arrow Pad Properties")
@export var boost_force: float = 100.0  # כמה חזק הדחיפה
@export var direction_tolerance: float = 45.0  # זווית סובלנות במעלות (45 = 90 מעלות סה"כ)
@export var min_speed_required: float = 30.0  # מהירות מינימלית כדי להפעיל

# הכיוון הבסיסי (0, -1) פירושו למעלה
var base_direction: Vector2 = Vector2(0, -1)
var bodies_in_area: Array = []

# Cooldown system
var spacecraft_last_boost: Dictionary = {}  # spacecraft -> time
var boost_cooldown: float = 0.5  # חצי שנייה בין boosts

# אפקטים ויזואליים
var is_boosting: bool = false
var boost_tween: Tween
@onready var sprite = $AnimatedSprite2D

func _ready():
	# התחבר לאירועים
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	sprite.modulate.a = 0.9
	
	# הגדר collision layers
	collision_layer = 2
	collision_mask = 1

func _process(delta):
	# בדוק כל הגופים באזור
	for body in bodies_in_area:
		if body is Spacecraft and not body.freeze:
			check_and_boost_spacecraft(body, delta)

func _on_body_entered(body):
	if body is Spacecraft:
		bodies_in_area.append(body)

func _on_body_exited(body):
	if body is Spacecraft:
		bodies_in_area.erase(body)
		# נקה את הcooldown כשהחללית יוצאת (אופציונלי)
		if body in spacecraft_last_boost:
			spacecraft_last_boost.erase(body)

func check_and_boost_spacecraft(spacecraft: Spacecraft, delta: float):
	# בדוק מהירות מינימלית
	var current_speed = spacecraft.linear_velocity.length()
	if current_speed < min_speed_required:
		return
	
	# חשב את כיוון החץ בעולם (עם רוטציה של ה-node)
	var world_arrow_direction = base_direction.rotated(rotation)
	
	# חשב את כיוון תנועת החללית
	var spacecraft_direction = spacecraft.linear_velocity.normalized()
	
	# חשב זווית בין הכיוונים
	var dot_product = world_arrow_direction.dot(spacecraft_direction)
	var angle_between = acos(clamp(dot_product, -1.0, 1.0))
	var angle_degrees = rad_to_deg(angle_between)
	
	
	# בדוק אם הזווית בטווח המותר
	if angle_degrees <= direction_tolerance:
		apply_boost(spacecraft, world_arrow_direction)

func apply_boost(spacecraft: Spacecraft, boost_direction: Vector2):
	var current_time = Time.get_unix_time_from_system()
	
	# בדוק cooldown לחללית הספציפית הזו
	if spacecraft in spacecraft_last_boost:
		if current_time - spacecraft_last_boost[spacecraft] < boost_cooldown:
			return
	
	spacecraft_last_boost[spacecraft] = current_time
	
	# הפעל דחיפה
	var boost_force_vector = boost_direction * boost_force
	var current_speed = spacecraft.linear_velocity.length()  # שמור רק את הגודל
	spacecraft.reset(boost_direction.angle() + PI/2, spacecraft.global_position)
	spacecraft.linear_velocity = boost_direction * current_speed  # כיוון חדש עם מהירות ישנה
	spacecraft.apply_central_impulse(boost_force_vector)
	trigger_boost_effect()
	
	# רטט
	Input.vibrate_handheld(50)

func trigger_boost_effect():
	if is_boosting:
		return
		
	is_boosting = true
	
	if boost_tween:
		boost_tween.kill()
	
	boost_tween = create_tween()
	boost_tween.set_loops(3)  # הבהוב 3 פעמים
	
	boost_tween.tween_property(sprite, "modulate", Color(1.5, 1.5, 2.0, 0.8), 0.1)
	boost_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.8), 0.1)
	
	boost_tween.finished.connect(func(): is_boosting = false)
