extends Area2D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _on_body_exited(body):
	if body is Spacecraft and not body.freeze:
		body.destroy()
