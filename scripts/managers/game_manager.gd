extends Node

	
enum GameState {
	idle,
	action,
	pause,
	success,
	failure,
	dialog,
}

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
var currentState = GameState.idle


