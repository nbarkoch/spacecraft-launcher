# scripts/gravity_assist_tuner.gd
# Add this script to a Node in your scene to easily tune gravity assist parameters
extends Node
class_name GravityAssistTuner

@export_group("Global Magnet Settings")
@export_range(0.0, 5.0, 0.1) var global_magnet_strength: float = 1.0
@export_range(5.0, 100.0, 5.0) var global_orbit_zone_size: float = 25.0
@export_range(20.0, 150.0, 10.0) var global_magnet_max_distance: float = 80.0

@export_group("Collision Prevention")
@export_range(5.0, 30.0, 1.0) var global_safety_distance: float = 15.0
@export_range(1.0, 15.0, 0.5) var global_emergency_force: float = 8.0
@export_range(0.5, 3.0, 0.1) var global_prediction_time: float = 1.0

@export_group("Angle Guidance")
@export_range(0.0, 10.0, 0.1) var global_angle_correction: float = 2.0
@export_range(5.0, 60.0, 5.0) var global_angle_tolerance: float = 30.0
@export_range(0.0, 5.0, 0.1) var global_angle_magnet: float = 1.5

@export_group("Fine Tuning")
@export_range(1.0, 10.0, 0.1) var global_base_force: float = 3.0
@export_range(0.01, 0.1, 0.001) var global_speed_influence: float = 0.02
@export_range(0.1, 1.0, 0.05) var global_smoothing: float = 0.85

@export_group("Debug & Testing")
@export var enable_debug: bool = false
@export var apply_to_all_planets: bool = true
@export var test_current_settings: bool = false : set = _apply_settings

var current_gravity_assists: Array[GravityAssist] = []

func _ready():
	if apply_to_all_planets:
		await get_tree().process_frame
		_apply_settings(true)

func _apply_settings(apply: bool):
	if not apply:
		return
		
	print("GravityAssistTuner: Applying settings to all active gravity assists...")
	
	# Apply to any existing gravity assists
	update_existing_assists()
	
	# Apply to all planets for future assists
	update_planet_defaults()
	
	print("GravityAssistTuner: Settings applied!")

func update_existing_assists():
	"""Update any currently active gravity assists"""
	var spacecrafts = get_tree().get_nodes_in_group("Spacecrafts")
	
	for spacecraft in spacecrafts:
		if spacecraft.has_method("get") and spacecraft.gravity_assist:
			var assist = spacecraft.gravity_assist as GravityAssist
			if assist:
				apply_settings_to_assist(assist)
				current_gravity_assists.append(assist)

func update_planet_defaults():
	"""Update default settings that will be used for new gravity assists"""
	# This is a bit tricky since the settings are in the GravityAssist class
	# We'll store these as autoload or static variables that get picked up
	# For now, we'll just print them for manual application
	
	var planets = get_tree().get_nodes_in_group("Planets")
	print("GravityAssistTuner: Found ", planets.size(), " planets")
	
	# You can extend this to modify planet properties if needed
	for planet in planets:
		if planet.has_method("set_gravity_assist_defaults"):
			planet.set_gravity_assist_defaults(get_current_settings())

func apply_settings_to_assist(assist: GravityAssist):
	"""Apply current settings to a specific gravity assist"""
	if not assist:
		return
	
	# Apply magnet settings
	assist.magnet_strength = global_magnet_strength
	assist.optimal_orbit_zone = global_orbit_zone_size
	assist.magnet_max_distance = global_magnet_max_distance
	
	# Apply collision prevention
	assist.collision_safety_distance = global_safety_distance
	assist.emergency_force_multiplier = global_emergency_force
	assist.collision_prediction_time = global_prediction_time
	
	# Apply angle guidance
	assist.angle_correction_strength = global_angle_correction
	assist.optimal_angle_tolerance = global_angle_tolerance
	assist.angle_magnet_strength = global_angle_magnet
	
	# Apply fine tuning
	assist.base_force_strength = global_base_force
	assist.speed_influence = global_speed_influence
	assist.smoothing_factor = global_smoothing
	
	# Apply debug
	assist.debug_enabled = enable_debug

func get_current_settings() -> Dictionary:
	"""Get current settings as a dictionary"""
	return {
		"magnet_strength": global_magnet_strength,
		"optimal_orbit_zone": global_orbit_zone_size,
		"magnet_max_distance": global_magnet_max_distance,
		"collision_safety_distance": global_safety_distance,
		"emergency_force_multiplier": global_emergency_force,
		"collision_prediction_time": global_prediction_time,
		"angle_correction_strength": global_angle_correction,
		"optimal_angle_tolerance": global_angle_tolerance,
		"angle_magnet_strength": global_angle_magnet,
		"base_force_strength": global_base_force,
		"speed_influence": global_speed_influence,
		"smoothing_factor": global_smoothing,
		"debug_enabled": enable_debug
	}

# === QUICK PRESET FUNCTIONS ===

func apply_gentle_preset():
	"""Gentle, forgiving orbital assistance"""
	global_magnet_strength = 0.5
	global_safety_distance = 20.0
	global_emergency_force = 5.0
	global_angle_correction = 1.0
	global_angle_tolerance = 45.0
	_apply_settings(true)
	print("Applied GENTLE preset")

func apply_normal_preset():
	"""Balanced orbital assistance"""
	global_magnet_strength = 1.0
	global_safety_distance = 15.0
	global_emergency_force = 8.0
	global_angle_correction = 2.0
	global_angle_tolerance = 30.0
	_apply_settings(true)
	print("Applied NORMAL preset")

func apply_strong_preset():
	"""Strong orbital guidance - easier gameplay"""
	global_magnet_strength = 2.0
	global_safety_distance = 12.0
	global_emergency_force = 12.0
	global_angle_correction = 4.0
	global_angle_tolerance = 20.0
	_apply_settings(true)
	print("Applied STRONG preset")

func apply_challenge_preset():
	"""Minimal assistance - for skilled players"""
	global_magnet_strength = 0.2
	global_safety_distance = 8.0
	global_emergency_force = 3.0
	global_angle_correction = 0.5
	global_angle_tolerance = 15.0
	_apply_settings(true)
	print("Applied CHALLENGE preset")

# === INPUT HANDLING FOR RUNTIME TUNING ===

func _input(event):
	if not enable_debug:
		return
		
	# Quick hotkeys for testing (only in debug mode)
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				apply_gentle_preset()
			KEY_2:
				apply_normal_preset()
			KEY_3:
				apply_strong_preset()
			KEY_4:
				apply_challenge_preset()
			KEY_R:
				print("=== CURRENT GRAVITY ASSIST STATUS ===")
				print_debug_info()

func print_debug_info():
	"""Print debug information about current gravity assists"""
	var spacecrafts = get_tree().get_nodes_in_group("Spacecrafts")
	
	for spacecraft in spacecrafts:
		if spacecraft.gravity_assist:
			var assist = spacecraft.gravity_assist as GravityAssist
			var debug_info = assist.get_debug_info()
			
			print("Spacecraft Debug Info:")
			for key in debug_info:
				print("  ", key, ": ", debug_info[key])
			print("---")
