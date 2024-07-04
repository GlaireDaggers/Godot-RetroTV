extends Node

@export var crt_effect: CRTEffect
@export var randomize_sync_btn: Button
@export var signal_noise_slider: Slider
@export var enable_hsync_errors: CheckBox
@export var enable_vsync_errors: CheckBox
@export var s_video: CheckBox

# Called when the node enters the scene tree for the first time.
func _ready():
	signal_noise_slider.value_changed.connect(self._signal_noise_value_changed)
	randomize_sync_btn.pressed.connect(self._randomize_sync_pressed)
	enable_hsync_errors.toggled.connect(self._enable_hsync_errors_toggled)
	enable_vsync_errors.toggled.connect(self._enable_vsync_errors_toggled)
	s_video.toggled.connect(self._s_video_toggled)
	
	signal_noise_slider.value = crt_effect.noise_amount * 100.0
	enable_hsync_errors.button_pressed = crt_effect.degrade_hsync
	enable_vsync_errors.button_pressed = crt_effect.degrade_vsync
	s_video.button_pressed = crt_effect.s_video

func _signal_noise_value_changed(value):
	crt_effect.noise_amount = value / 100.0
	crt_effect.sync_noise_amount = value / 100.0

func _randomize_sync_pressed():
	crt_effect.randomize_hsync()
	crt_effect.randomize_vsync()

func _enable_hsync_errors_toggled(value: bool):
	crt_effect.degrade_hsync = value
	
func _enable_vsync_errors_toggled(value: bool):
	crt_effect.degrade_vsync = value
	
func _s_video_toggled(value: bool):
	crt_effect.s_video = value
