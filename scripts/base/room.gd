extends Node2D
class_name Room
@onready var level = $Level

# Called when the node enters the scene tree for the first time.
func _ready():
	LevelManager.set_room(self)
	MusicManager.play_room_music()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
