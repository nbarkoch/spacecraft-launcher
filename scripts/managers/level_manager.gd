extends Node2D

# timer
var game_start_time: float = 0.0	
var game_duration: float = 0.0
var is_timer_running: bool = false
var score = 0

var room: Room
var dialog: Dialog = null
var current_level_num = 7

func inc_score():
	score += 1

func set_room(room):
	self.room = room
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if is_timer_running:
		game_duration = Time.get_unix_time_from_system() - game_start_time
	
func level_started():
	if self.room:
		var slingshot = self.room.level.slingshot
		if slingshot:
			slingshot.reset()

func level_completed():
	stop_timer()
	var formatted_duration = format_time(game_duration)
	dialog = Dialog.create_dilaog(formatted_duration, formatted_duration, score)
	self.room.add_child(dialog)
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
	dialog = null

func to_next_level():
	if dialog:
		dialog.exit()
	load_level(current_level_num + 1)
	
func retry_level():
	if dialog:
		dialog.exit()
	load_level(current_level_num)

func go_home():
	print("should go home")

func load_level(level_num: int):
	current_level_num = level_num
	score = 0
	start_timer()	
	level_started()
	var content_scene = load("res://scenes/levels/level_" + str(level_num) +".tscn")
	var new_content = content_scene.instantiate()
	await get_tree().process_frame
	if self.room:
		if self.room.level.content:
			self.room.level.content.queue_free()
			self.get_parent().add_child(new_content)
		self.room.level.content = new_content
	
	
func start_timer():
	game_start_time = Time.get_unix_time_from_system()
	game_duration = 0.0
	is_timer_running = true

func stop_timer():
	is_timer_running = false
	if game_start_time > 0:
		game_duration = Time.get_unix_time_from_system() - game_start_time
