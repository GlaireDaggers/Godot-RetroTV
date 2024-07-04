class_name CRTEffect
extends Node2D

const GENCB_SHADER = preload("res://addons/godot_crt/Shaders/gen_phase.gdshader")
const GENSIGNAL_SHADER = preload("res://addons/godot_crt/Shaders/gen_signal.gdshader")
const DECSIGNAL1_SHADER = preload("res://addons/godot_crt/Shaders/dec_signal_1.gdshader")
const DECSIGNAL2_SHADER = preload("res://addons/godot_crt/Shaders/dec_signal_2.gdshader")

const CRT_CC_LINE = 2280
const CRT_CB_FREQ = 4
const CRT_HRES = (CRT_CC_LINE * CRT_CB_FREQ / 10)
const CRT_VRES = 262
const CRT_FRAME_SIZE = (CRT_HRES * CRT_VRES)
const CRT_WHITE_LEVEL = 100
const CRT_BURST_LEVEL = 20
const CRT_BLACK_LEVEL = 7
const CRT_BLANK_LEVEL = 0
const CRT_SYNC_LEVEL = -40

const CRT_HSYNC_THRESHOLD = 4
const CRT_VSYNC_THRESHOLD = 96

const CRT_LINE_BEG = 0
const CRT_FP_NS = 1500
const CRT_SYNC_NS = 4700
const CRT_BW_NS = 600
const CRT_CB_NS = 2500
const CRT_BP_NS = 1600
const CRT_AV_NS = 52600
const CRT_HB_NS = (CRT_FP_NS + CRT_SYNC_NS + CRT_BW_NS + CRT_CB_NS + CRT_BP_NS)
const CRT_LINE_NS = (CRT_FP_NS + CRT_SYNC_NS + CRT_BW_NS + CRT_CB_NS + CRT_BP_NS + CRT_AV_NS)

const CRT_FP_BEG = 0
const CRT_SYNC_BEG = ((CRT_FP_NS) * CRT_HRES / CRT_LINE_NS)
const CRT_BW_BEG = ((CRT_FP_NS + CRT_SYNC_NS) * CRT_HRES / CRT_LINE_NS)
const CRT_CB_BEG = ((CRT_FP_NS + CRT_SYNC_NS + CRT_BW_NS) * CRT_HRES / CRT_LINE_NS)
const CRT_BP_BEG = ((CRT_FP_NS + CRT_SYNC_NS + CRT_BW_NS + CRT_CB_NS) * CRT_HRES / CRT_LINE_NS)
const CRT_AV_BEG = ((CRT_FP_NS + CRT_SYNC_NS + CRT_BW_NS + CRT_CB_NS + CRT_BP_NS) * CRT_HRES / CRT_LINE_NS)
const CRT_AV_LEN = ((CRT_AV_NS) * CRT_HRES / CRT_LINE_NS)

const CRT_TOP = 21

const CRT_VSYNC_WINDOW = 8
const CRT_HSYNC_WINDOW = 8

## Input image to be processed (usually this would be a ViewportTexture)
@export var input_texture: Texture2D

## Filter input image horizontally (smooths out artifacts)
@export var filter_input: bool = true

## Noise to add to NTSC signal
@export var noise_amount: float = 0.0

## Noise to add to NTSC signal (when simulating hsync/vsync errors)
@export var sync_noise_amount: float = 0.0

## Whether to simulate hsync errors
@export var degrade_hsync: bool = false

## Whether to simulate vsync errors
@export var degrade_vsync: bool = false

## Number of color cycles per input pixel on X dimension
@export var colorburst_cycle_length: int = 4

## Offset of color cycle phase per scanline
@export var colorburst_offset_per_scanline: float = 1.0 / 3.0

## Offset of color cycle phase per frame (at 60Hz)
@export var colorburst_offset_per_frame: float = 0.25

## Whether to apply temporal filtering to chroma artifacts
@export var temporal_chroma_filter: bool = true

## Whether to enable S-Video mode (split luma into separate signal, produces cleaner signal)
@export var s_video: bool = false

var _hsync_offset: int = 0
var _vsync_offset: int = 0
var _tick_accum: float = 0.0

var _gencb_material
var _gensignal_material
var _decsignal1_material
var _decsignal2_material

var _gencb_vp
var _gencb_canvas
var _gencb_canvas_item

var _filterchain_vp
var _filterchain_canvas
var _filterchain_canvas_blitinput
var _filterchain_canvas_gensignal
var _filterchain_canvas_decsignal1
var _filterchain_canvas_decsignal2

var _output_canvas

var _crt_field: Array[int]
var _crt_hsync: PackedByteArray
var _crt_hsync_lut: Image
var _crt_hsync_tex: ImageTexture

func _enter_tree():
	var rs = RenderingServer
	
	_crt_field = init_field()
	_crt_hsync = init_hsync()
	_crt_hsync_lut = Image.create(1, CRT_VRES, false, Image.FORMAT_RF)
	_crt_hsync_tex = ImageTexture.create_from_image(_crt_hsync_lut)
	
	_hsync_offset = randi_range(0, CRT_HRES)
	_vsync_offset = randi_range(0, CRT_VRES)
	
	# create gencb material
	_gencb_material = ShaderMaterial.new()
	_gencb_material.set_shader(GENCB_SHADER)
	
	# create gensignal material
	_gensignal_material = ShaderMaterial.new()
	_gensignal_material.set_shader(GENSIGNAL_SHADER)
	
	# create decsignal materials
	_decsignal1_material = ShaderMaterial.new()
	_decsignal1_material.set_shader(DECSIGNAL1_SHADER)
	_decsignal2_material = ShaderMaterial.new()
	_decsignal2_material.set_shader(DECSIGNAL2_SHADER)
	
	# set up viewport to draw colorburst LUT
	_gencb_vp = rs.viewport_create()
	_gencb_canvas = rs.canvas_create()
	rs.viewport_attach_canvas(_gencb_vp, _gencb_canvas)
	rs.viewport_set_active(_gencb_vp, true)
	
	_gencb_canvas_item = rs.canvas_item_create()
	rs.canvas_item_set_parent(_gencb_canvas_item, _gencb_canvas)
	
	# set up viewport to upscale input & apply filter chain (modulate & demodulate)
	_filterchain_vp = rs.viewport_create()
	_filterchain_canvas = rs.canvas_create()
	rs.viewport_attach_canvas(_filterchain_vp, _filterchain_canvas)
	rs.viewport_set_active(_filterchain_vp, true)
	
	_filterchain_canvas_blitinput = rs.canvas_item_create()
	rs.canvas_item_set_parent(_filterchain_canvas_blitinput, _filterchain_canvas)
	
	_filterchain_canvas_gensignal = rs.canvas_item_create()
	rs.canvas_item_set_parent(_filterchain_canvas_gensignal, _filterchain_canvas)
	
	_filterchain_canvas_decsignal1 = rs.canvas_item_create()
	rs.canvas_item_set_parent(_filterchain_canvas_decsignal1, _filterchain_canvas)
	
	_filterchain_canvas_decsignal2 = rs.canvas_item_create()
	rs.canvas_item_set_parent(_filterchain_canvas_decsignal2, _filterchain_canvas)
	
	# set up output canvas item
	_output_canvas = rs.canvas_item_create()
	rs.canvas_item_set_parent(_output_canvas, get_canvas_item())
	
func _exit_tree():
	var rs = RenderingServer
	rs.free_rid(_gencb_vp)
	rs.free_rid(_gencb_canvas)
	rs.free_rid(_gencb_canvas_item)
	rs.free_rid(_filterchain_vp)
	rs.free_rid(_filterchain_canvas)
	rs.free_rid(_filterchain_canvas_blitinput)
	rs.free_rid(_filterchain_canvas_gensignal)
	rs.free_rid(_filterchain_canvas_decsignal1)
	rs.free_rid(_filterchain_canvas_decsignal2)
	rs.free_rid(_output_canvas)

func randomize_hsync():
	_hsync_offset = randi_range(0, CRT_HRES)
	
func randomize_vsync():
	_vsync_offset = randi_range(0, CRT_VRES)

func init_field() -> Array[int]:
	var field: Array[int] = []
	field.resize(CRT_FRAME_SIZE)
	field.fill(0)
	return field

func init_hsync() -> PackedByteArray:
	var hsync: PackedByteArray = []
	hsync.resize(CRT_VRES * 4)
	hsync.fill(0)
	return hsync

# NTSC field generation & sync logic was adapted from https://github.com/LMP88959/NTSC-CRT

func gen_field(field: Array[int]):
	var noiserange = int(sync_noise_amount * sync_noise_amount * 100)
	for n in CRT_VRES:
		var t = 0
		var offset = n * CRT_HRES
		if n < 3 || (n >= 7 && n <= 9):
			# equalizing pulses - small blips of sync, mostly blank
			while t < (4 * CRT_HRES / 100):
				field[offset + t] = CRT_SYNC_LEVEL + randi_range(-noiserange, noiserange)
				t += 1
			while t < (50 * CRT_HRES / 100):
				field[offset + t] = CRT_BLANK_LEVEL + randi_range(-noiserange, noiserange)
				t += 1
			while t < (54 * CRT_HRES / 100):
				field[offset + t] = CRT_SYNC_LEVEL + randi_range(-noiserange, noiserange)
				t += 1
			while t < (100 * CRT_HRES / 100):
				field[offset + t] = CRT_BLANK_LEVEL + randi_range(-noiserange, noiserange)
				t += 1
		elif n >= 4 && n <= 6:
			# vertical sync pulse - small blips of blank, mostly sync
			while t < (46 * CRT_HRES / 100):
				field[offset + t] = CRT_SYNC_LEVEL + randi_range(-noiserange, noiserange)
				t += 1
			while t < (50 * CRT_HRES / 100):
				field[offset + t] = CRT_BLANK_LEVEL + randi_range(-noiserange, noiserange)
				t += 1
			while t < (96 * CRT_HRES / 100):
				field[offset + t] = CRT_SYNC_LEVEL + randi_range(-noiserange, noiserange)
				t += 1
			while t < (100 * CRT_HRES / 100):
				field[offset + t] = CRT_BLANK_LEVEL + randi_range(-noiserange, noiserange)
				t += 1
		else:
			# video line
			while t < CRT_SYNC_BEG:
				field[offset + t] = CRT_BLANK_LEVEL + randi_range(-noiserange, noiserange)
				t += 1
			while t < CRT_BW_BEG:
				field[offset + t] = CRT_SYNC_LEVEL + randi_range(-noiserange, noiserange)
				t += 1
			while t < CRT_AV_BEG:
				field[offset + t] = CRT_BLANK_LEVEL + randi_range(-noiserange, noiserange)
				t += 1
			if n < CRT_TOP:
				while t < CRT_HRES:
					field[offset + t] = CRT_BLANK_LEVEL + randi_range(-noiserange, noiserange)
					t += 1

func vsync_field(vsync: int, field: Array[int]) -> int:
	var line = 0
	for i in range(-CRT_VSYNC_WINDOW, CRT_VSYNC_WINDOW):
		line = posmod(vsync + i, CRT_VRES)
		var offset = line * CRT_HRES
		var s = 0
		for j in CRT_HRES:
			s += field[offset + j]
			if s <= (CRT_VSYNC_THRESHOLD * CRT_SYNC_LEVEL):
				return line
	return line

func hsync_line(hsync: int, field: Array[int], line: int):
	var offset = line * CRT_HRES
	var s = 0
	var new_hsync = 0
	for i in range(-CRT_HSYNC_WINDOW, CRT_HSYNC_WINDOW):
		new_hsync = posmod(hsync + i, CRT_HRES)
		s += field[(offset + hsync + i + CRT_SYNC_BEG) % CRT_FRAME_SIZE]
		if s <= (CRT_HSYNC_THRESHOLD * CRT_SYNC_LEVEL):
			return new_hsync
	return new_hsync

func _process(delta):
	if input_texture == null: return
	var rs = RenderingServer
	
	if degrade_vsync || degrade_hsync:
		_tick_accum += delta
		if _tick_accum > 0.133: _tick_accum = 0.133
		
		# only perform vsync stuff at 60hz
		while _tick_accum > (1.0 / 60.0):
			_tick_accum -= (1.0 / 60.0)
			# generate a blank NTSC field
			gen_field(_crt_field)
			# then scan for sync
			if degrade_vsync:
				_vsync_offset = vsync_field(_vsync_offset, _crt_field)
			else:
				_vsync_offset = 4
			if degrade_hsync:
				for line in CRT_VRES:
					_hsync_offset = hsync_line(_hsync_offset, _crt_field, line)
					_crt_hsync.encode_float(line * 4, float(_hsync_offset - 3) / CRT_HRES)
			else:
				_hsync_offset = 0
				_crt_hsync.fill(0)
			_crt_hsync_lut.set_data(1, CRT_VRES, false, Image.FORMAT_RF, _crt_hsync)
			_crt_hsync_tex.update(_crt_hsync_lut)
	else:
		_hsync_offset = 0
		_vsync_offset = 4
	
	var cb_width = 2
	var cb_height = input_texture.get_height()

	rs.viewport_set_size(_gencb_vp, cb_width, cb_height)
	rs.canvas_item_clear(_gencb_canvas_item)
	_gencb_material.set_shader_parameter("screen_height", float(cb_height))
	_gencb_material.set_shader_parameter("hz", 60.0)
	_gencb_material.set_shader_parameter("pps", colorburst_offset_per_scanline)
	_gencb_material.set_shader_parameter("ppf", colorburst_offset_per_frame)
	rs.canvas_item_set_material(_gencb_canvas_item, _gencb_material.get_rid())
	rs.canvas_item_add_rect(_gencb_canvas_item, Rect2(0, 0, cb_width, cb_height), Color.WHITE)
	
	var filterchain_width = input_texture.get_width() * colorburst_cycle_length
	var filterchain_height = input_texture.get_height()
	
	rs.viewport_set_size(_filterchain_vp, filterchain_width, filterchain_height)
	rs.canvas_item_set_default_texture_filter(_filterchain_canvas_blitinput,
			RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_LINEAR if filter_input else
			RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	rs.canvas_item_clear(_filterchain_canvas_blitinput)
	rs.canvas_item_add_texture_rect(_filterchain_canvas_blitinput,
			Rect2(0, 0, filterchain_width, filterchain_height),
			input_texture.get_rid())
	rs.canvas_item_clear(_filterchain_canvas_gensignal)
	_gensignal_material.set_shader_parameter("noise_amount", noise_amount)
	_gensignal_material.set_shader_parameter("hsync_noise_amount",
			(noise_amount * noise_amount * 0.05) if degrade_hsync else 0.0)
	_gensignal_material.set_shader_parameter("vsync_offset", float(_vsync_offset - 4) / CRT_VRES)
	_gensignal_material.set_shader_parameter("c", float(colorburst_cycle_length))
	_gensignal_material.set_shader_parameter("svideo", s_video)
	_gensignal_material.set_shader_parameter("output_resolution",
			Vector2(filterchain_width, filterchain_height))
	_gensignal_material.set_shader_parameter("cb_lut", rs.viewport_get_texture(_gencb_vp))
	_gensignal_material.set_shader_parameter("hsync_lut", _crt_hsync_tex.get_rid())
	rs.canvas_item_set_material(_filterchain_canvas_gensignal, _gensignal_material.get_rid())
	rs.canvas_item_add_rect(_filterchain_canvas_gensignal,
			Rect2(0, 0, filterchain_width, filterchain_height),
			Color.WHITE)
	rs.canvas_item_clear(_filterchain_canvas_decsignal1)
	if !s_video:
		_decsignal1_material.set_shader_parameter("c", colorburst_cycle_length)
		_decsignal1_material.set_shader_parameter("output_resolution",
				Vector2(filterchain_width, filterchain_height))
		rs.canvas_item_set_material(_filterchain_canvas_decsignal1, _decsignal1_material.get_rid())
		rs.canvas_item_set_copy_to_backbuffer(_filterchain_canvas_decsignal1,
				true,
				Rect2(0, 0, filterchain_width, filterchain_height))
		rs.canvas_item_add_rect(_filterchain_canvas_decsignal1,
				Rect2(0, 0, filterchain_width, filterchain_height),
				Color.WHITE)
	rs.canvas_item_clear(_filterchain_canvas_decsignal2)
	_decsignal2_material.set_shader_parameter("c", float(colorburst_cycle_length))
	_decsignal2_material.set_shader_parameter("output_resolution",
			Vector2(filterchain_width, filterchain_height))
	_decsignal2_material.set_shader_parameter("cb_lut", rs.viewport_get_texture(_gencb_vp))
	_decsignal2_material.set_shader_parameter("temporal_blend", temporal_chroma_filter)
	rs.canvas_item_set_material(_filterchain_canvas_decsignal2, _decsignal2_material.get_rid())
	rs.canvas_item_set_copy_to_backbuffer(_filterchain_canvas_decsignal2,
			true,
			Rect2(0, 0, filterchain_width, filterchain_height))
	rs.canvas_item_add_rect(_filterchain_canvas_decsignal2,
			Rect2(0, 0, filterchain_width, filterchain_height),
			Color.WHITE)
	
	rs.canvas_item_clear(_output_canvas)
	rs.canvas_item_add_texture_rect(_output_canvas,
			get_viewport_rect(),
			rs.viewport_get_texture(_filterchain_vp))
