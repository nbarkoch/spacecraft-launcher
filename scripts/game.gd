extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	load_intro()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
func load_intro():
	var intro_scene = load("res://scenes/ui/intro.tscn")
	var intro_screen: CanvasLayer = intro_scene.instantiate()
	await get_tree().process_frame
	add_child(intro_screen)
	await get_tree().create_timer(2).timeout
	var room_scene = load("res://scenes/base/room.tscn")
	var room = room_scene.instantiate()
	await get_tree().process_frame
	LevelManager.load_level(5)
	add_child(room)
	remove_child(intro_screen)
