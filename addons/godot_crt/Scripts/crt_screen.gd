class_name CRTScreen
extends Node2D

const SCREEN_SHADER = preload("res://addons/godot_crt/Shaders/crt_screen.gdshader")

## Amount of curvature to apply on X axis (0.0 = none)
@export_range(0.0, 1.0) var fisheye_x: float = 0.1

## Amount of curvature to apply on Y axis (0.0 = none)
@export_range(0.0, 1.0) var fisheye_y: float = 0.1

## Border image to mask off screen edges
@export var border_image: Texture2D = preload("res://addons/godot_crt/Res/bordermask.png")

## Pixel mask image
@export var mask_image: Texture2D = preload("res://addons/godot_crt/Res/shadowmask.png")

## Intensity of pixel mask
@export_range(0.0, 1.0) var mask_intensity: float = 0.2

## Number of times to tile pixel mask across screen
@export var mask_repeat: Vector2 = Vector2(640 / 6.0, 480 / 8.0)

## Intensity of scanline effect
@export_range(0.0, 1.0) var scanline_intensity: float = 0.2

## Screen brightness (can be >1.0 to compensate for pixel mask + scanlines)
@export var brightness: float = 1.2

## Whether to force a custom aspect ratio
@export var force_aspect: bool = true

## The aspect ratio override
@export var aspect_override: float = 320.0 / 240.0

var _output_canvas
var _screen_material

func _enter_tree():
	var rs = RenderingServer
	_output_canvas = rs.canvas_item_create()
	rs.canvas_item_set_parent(_output_canvas, get_canvas_item())
	_screen_material = ShaderMaterial.new()
	_screen_material.set_shader(SCREEN_SHADER)

func _exit_tree():
	var rs = RenderingServer
	rs.free_rid(_output_canvas)

func _process(_delta):
	var rs = RenderingServer
	
	var aspect_scale = 1.0
	if force_aspect:
		var w = get_viewport_rect().size.x
		var h = get_viewport_rect().size.y
		var desired_w = h * aspect_override
		aspect_scale = w / desired_w
	
	_screen_material.set_shader_parameter("scale",
			Vector2((1.0 / (1.0 - fisheye_x)) * aspect_scale, 1.0 / (1.0 - fisheye_y)))
	_screen_material.set_shader_parameter("fisheye_intensity", Vector2(fisheye_x, fisheye_y))
	_screen_material.set_shader_parameter("mask_scale", mask_repeat)
	_screen_material.set_shader_parameter("mask_intensity", mask_intensity)
	_screen_material.set_shader_parameter("scanline_intensity", scanline_intensity)
	_screen_material.set_shader_parameter("brightness", brightness)
	_screen_material.set_shader_parameter("mask_texture", mask_image)
	_screen_material.set_shader_parameter("border_texture", border_image)
	
	rs.canvas_item_clear(_output_canvas)
	rs.canvas_item_set_copy_to_backbuffer(_output_canvas, true, get_viewport_rect())
	rs.canvas_item_set_material(_output_canvas, _screen_material.get_rid())
	rs.canvas_item_add_rect(_output_canvas, get_viewport_rect(), Color.WHITE)
