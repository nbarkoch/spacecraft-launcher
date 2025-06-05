# scripts/music_manager.gd
extends Node

var audio_player1: AudioStreamPlayer
var audio_player2: AudioStreamPlayer
var current_player: AudioStreamPlayer
var fade_tween: Tween
var song_timer: Timer

const default_volume = -25.0
const SWITCH_DURATION: float = 8.0  # Switch before song ends
const FADE_DELAY: float = 2.5  # Delay before old song starts fading out

# Room music - sequence of songs
var room_songs: Array[String] = [
	"res://music/room_song1.mp3",
	"res://music/room_song2.mp3", 
	"res://music/room_song3.mp3"
]
var current_room_song: int = 0
var is_room_music_playing: bool = false

# Menu music - single track
var menu_song: String = "res://music/menu_music.mp3"
var is_menu_music_playing: bool = false

func _ready():
	# Create two audio players for crossfading
	audio_player1 = AudioStreamPlayer.new()
	audio_player2 = AudioStreamPlayer.new()
	add_child(audio_player1)
	add_child(audio_player2)
	
	# Create timer for song switching
	song_timer = Timer.new()
	add_child(song_timer)
	song_timer.timeout.connect(_on_song_should_switch)
	song_timer.one_shot = true
	
	audio_player1.volume_db = default_volume
	audio_player2.volume_db = -60.0  # Start silent
	
	current_player = audio_player1

func play_room_music():
	if is_room_music_playing:
		return
	
	is_room_music_playing = true
	is_menu_music_playing = false
	
	# Randomize starting song
	current_room_song = randi() % room_songs.size()
	
	# Switch immediately
	switch_to_song(room_songs[current_room_song])

func play_menu_music():
	if is_menu_music_playing:
		return
	
	is_menu_music_playing = true
	is_room_music_playing = false
	
	# Switch immediately (menu music loops, so no timer needed)
	switch_to_song(menu_song)
	song_timer.stop()  # Stop timer for menu music

func stop_music():
	is_room_music_playing = false
	is_menu_music_playing = false
	song_timer.stop()
	
	if fade_tween:
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.parallel().tween_property(audio_player1, "volume_db", -60.0, 0.2)
	fade_tween.parallel().tween_property(audio_player2, "volume_db", -60.0, 0.2)
	fade_tween.finished.connect(func(): 
		audio_player1.stop()
		audio_player2.stop()
		audio_player1.volume_db = default_volume
		audio_player2.volume_db = -60.0
	)

func switch_to_song(song_path: String):
	var song = load(song_path)
	if not song:
		print("Failed to load: ", song_path)
		return
	
	# Check if this is the first time playing (no music currently playing)
	var is_first_play = not (audio_player1.playing or audio_player2.playing)
	
	# Get the other player (not currently playing)
	var new_player = audio_player2 if current_player == audio_player1 else audio_player1
	
	# Start new song on the other player
	new_player.stream = song
	new_player.volume_db = -60.0  # Start silent
	new_player.play()
	
	print("Playing: ", song_path.get_file())
	
	# Crossfade between players
	if fade_tween:
		fade_tween.kill()
	
	fade_tween = create_tween()
	
	if is_first_play:
		# First time playing - start immediately at full volume, no fade
		new_player.volume_db = default_volume
	else:
		# Crossfade with delay - new song fades in immediately, old song fades out after delay
		fade_tween.parallel().tween_property(new_player, "volume_db", default_volume, SWITCH_DURATION)  # New song fades in immediately
		fade_tween.parallel().tween_property(current_player, "volume_db", -60.0, SWITCH_DURATION).set_delay(FADE_DELAY)  # Old song fades out after delay
	
	# Switch current player reference
	current_player = new_player
	
	# Set timer for next song (only for room music)
	if is_room_music_playing:
		var song_length = song.get_length()
		var switch_time = song_length - SWITCH_DURATION - FADE_DELAY  # Account for the delay
		song_timer.start(max(switch_time, 1.0))  # Minimum 1 second

func _on_song_should_switch():
	# Only advance to next song if we're playing room music
	if is_room_music_playing:
		current_room_song += 1
		if current_room_song >= room_songs.size():
			current_room_song = 0  # Loop back to first song
		switch_to_song(room_songs[current_room_song])
	elif is_menu_music_playing:
		# Loop menu music
		switch_to_song(menu_song)
