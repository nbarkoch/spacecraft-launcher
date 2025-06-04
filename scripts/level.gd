extends Node2D
class_name Level

@onready var spacecraft: Spacecraft = $Spacecraft
@onready var slingshot: SlingShot = $Slingshot

# Called when the node enters the scene tree for the first time.
func _ready():
	LevelManager.set_level(self)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
