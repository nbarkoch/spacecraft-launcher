extends Node2D


var level: Level = null
var dialog: Dialog = null

# timer
var game_start_time: float = 0.0	
var game_duration: float = 0.0
var is_timer_running: bool = false
var score = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	level_started()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if is_timer_running:
		game_duration = Time.get_unix_time_from_system() - game_start_time

func set_level(level: Level):
	self.level = level
	
func level_started():
	start_timer()
	if self.level:
		var slingshot = level.slingshot
		if slingshot:
			slingshot.reset()

func level_completed():
	stop_timer()
	var formatted_duration = format_time(game_duration)
	dialog = Dialog.create_dilaog(self.level, formatted_duration, formatted_duration, score)
	self.level.add_child(dialog)
	await get_tree().process_frame
	dialog.enter()
	
func format_time(seconds: float) -> String:
	var total_seconds = int(seconds)
	var minutes = total_seconds / 60
	var remaining_seconds = total_seconds % 60
	
	# Format as "MM:SS"
	return "%02d:%02d" % [minutes, remaining_seconds]
	
func level_failed():
	level_started()
	
	
func dialogAnimationExitFinished():
	get_tree().paused = false
	dialog.queue_free()

func to_next_level():
	pass
	
func retry_level():
	dialog.exit()
	self.level.reset()


func start_timer():
	game_start_time = Time.get_unix_time_from_system()
	game_duration = 0.0
	is_timer_running = true

func stop_timer():
	is_timer_running = false
	if game_start_time > 0:
		game_duration = Time.get_unix_time_from_system() - game_start_time
