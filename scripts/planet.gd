extends StaticBody2D
class_name Planet

# Config
@export var gravity_strength: float = 500.0  # Gravitational force strength
@export var gravity_radius: float = 100.0    # Maximum distance for gravity effect
@export var planet_radius: float = 40.0      # Planet surface radius (for collision)

func _ready():
	$GravityZone/GravityZoneCollision.shape.radius = gravity_radius
	$PlanetArea/Collision.shape.radius = planet_radius
	$CollisionShape.shape.radius = planet_radius
	
func _on_gravity_zone_body_entered(body):
	if body is Spacecraft and not body.gravity_assist:
		print("Spacecraft entered gravity assist zone")
		
		var spacecraft_velocity = body.linear_velocity
		print("Entry velocity: ", spacecraft_velocity, " Speed: ", spacecraft_velocity.length())
		
		# Create simple gravity assist
		var assist = GravityAssist.new(self, spacecraft_velocity)
		
		# Start gravity assist
		body.enter_gravity_assist(assist)


func _on_planet_area_body_entered(body):
	if body is Spacecraft:
		print("Spacecraft crashed into planet!")
		body.destroy()
