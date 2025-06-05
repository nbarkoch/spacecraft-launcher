extends Node2D
class_name Level

@onready var spacecraft: Spacecraft = $Spacecraft
@onready var slingshot: SlingShot = $Slingshot
@onready var content = $"Content"
		
		
func _ready():
	position_slingshot()

func position_slingshot():
		# Position slingshot at bottom of screen
	var viewport_height = get_viewport().get_visible_rect().size.y
	var camera_zoom = $Camera2D.zoom.y  # Should be 2.0
	var effective_height = viewport_height / camera_zoom  # 800 / 2 = 400
	# Position slingshot near bottom (40 units from bottom edge)
	slingshot.position.y = (effective_height / 2) - 30
