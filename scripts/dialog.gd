extends CanvasLayer

class_name Dialog

@onready var nextButtonAnimation = $Control/Panel/ButtonsPanel/NextButton/AnimationPlayer
@onready var retryButtonAnimation = $Control/Panel/ButtonsPanel/RetryButton/AnimationPlayer
@onready var dialogLayerAnimation = $DialogAnimationPlayer

@onready var currentResultLabel = $Control/Panel/PanelContainer/SummaryContainer/CurrentLine/Result
@onready var bestResultLabel = $Control/Panel/PanelContainer/SummaryContainer/BestLine/Result
@onready var currentScoreLabel = $Control/Panel/PanelContainer/SummaryContainer/ScoreLine/Label

var current_result: String = ""
var best_result: String = ""
var current_score: int = 0

static func create_dilaog(parent: Node, cur_res: String, best_res: String, cur_score: int) -> Dialog:
	var dialog_scene = preload("res://scenes/ui/dialog.tscn")
	var dialog = dialog_scene.instantiate() as Dialog
	dialog.current_result = cur_res
	dialog.best_result = best_res
	dialog.current_score = cur_score
	return dialog


func _ready():
	currentResultLabel.text = current_result
	bestResultLabel.text = best_result
	currentScoreLabel.text = str(current_score)
	pass 

func enter():
	dialogLayerAnimation.play("enter")
	
func exit():
	dialogLayerAnimation.play("exit")
	
func _on_next_button_pressed():
	nextButtonAnimation.play("button_click")
	
func _on_retry_button_pressed():
	retryButtonAnimation.play("button_click")

func _on_next_animation_finished(anim_name):
	LevelManager.to_next_level()

func _on_retry_animation_finished(anim_name):
	LevelManager.retry_level()


func _on_dialog_finished(anim_name):
	if anim_name == "exit":
		LevelManager.dialogAnimationExitFinished()
