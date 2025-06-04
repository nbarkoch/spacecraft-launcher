extends Node2D
class_name Level

@onready var spacecraft: Spacecraft = $Spacecraft
@onready var slingshot: SlingShot = $Slingshot
@onready var content = $"../Content"

# Called when the node enters the scene tree for the first time.
func _ready():
	LevelManager.set_level(self)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
func reset():
	slingshot.reset()
	if content:
		var content_scene = preload("res://scenes/levels/level1.tscn")
		var new_content = content_scene.instantiate()
		self.content.queue_free()
		self.get_parent().add_child(new_content)
		self.content = new_content
		
		
