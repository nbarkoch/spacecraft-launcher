extends Node2D


var level: Level = null

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func set_level(level: Level):
	self.level = level
	
func level_started():
	if self.level:
		var spacecraft = level.spacecraft
		var slingshot = level.slingshot
		if spacecraft and slingshot and slingshot.slingshot_center:
			slingshot.reset()

func level_completed():
	pass
	
func level_failed():
	level_started()
