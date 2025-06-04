# scripts/stars_background.gd
extends ColorRect

@export var star_density: float = 1
@export var star_brightness: float = 1.0
@export var twinkle_speed: float = 1.0
@export var twinkle_intensity: float = 0.75
@export var star_size: float = 1
@export var star_color: Color = Color.WHITE

func _ready():
	setup_shader()

func setup_shader():
	
	# Try to load the shader file
	var shader = load("res://shaders/small_stars.gdshader")

	
	# Create material with the loaded shader
	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	
	# Set parameters
	shader_material.set_shader_parameter("star_density", star_density)
	shader_material.set_shader_parameter("star_brightness", star_brightness)
	shader_material.set_shader_parameter("twinkle_speed", twinkle_speed)
	shader_material.set_shader_parameter("twinkle_intensity", twinkle_intensity)
	shader_material.set_shader_parameter("star_size", star_size)
	shader_material.set_shader_parameter("star_color", star_color)
	
	material = shader_material


# Methods to update parameters
func set_star_density(density: float):
	star_density = density
	if material and material is ShaderMaterial:
		material.set_shader_parameter("star_density", density)

func set_star_brightness(brightness: float):
	star_brightness = brightness
	if material and material is ShaderMaterial:
		material.set_shader_parameter("star_brightness", brightness)

func set_star_size(size: float):
	star_size = size
	if material and material is ShaderMaterial:
		material.set_shader_parameter("star_size", size)

func set_star_color(color: Color):
	star_color = color
	if material and material is ShaderMaterial:
		material.set_shader_parameter("star_color", color)
