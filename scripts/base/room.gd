extends Node2D
class_name Room
@onready var level = $Level
@onready var homeButtonAnim = $CanvasLayer/Control/HomeButton/AnimationPlayer
@onready var retryButtonAnim = $CanvasLayer/Control/RetryButton/AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready():
	LevelManager.set_room(self)
	#MusicManager.play_room_music()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_retry_button_pressed():
	retryButtonAnim.play("button_click")
	LevelManager.retry_level()


func _on_home_button_pressed():
	homeButtonAnim.play("button_click")
	LevelManager.go_home()
