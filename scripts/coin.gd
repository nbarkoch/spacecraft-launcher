extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func play_effect():
	$CollectionEffect/StarParticles.restart()
	$CollectionEffect/LightBurst.restart()
	if $AnimatedSprite2D:
		$AnimatedSprite2D.queue_free()
	var ring_effect = $CollectionEffect/RingEffect
	if ring_effect:
		ring_effect.trigger()
	await get_tree().create_timer(1.0).timeout
	queue_free()


func _on_body_entered(body):
	if body is Spacecraft:
		play_effect()
