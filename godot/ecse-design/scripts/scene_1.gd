extends Node2D

@onready var background = $Background
@onready var foreground: CanvasLayer = $Foreground
@onready var camera: Camera2D = $Camera2D

# Handheld Panning Settings
@export var pan_speed: float = 0.4         # Overall speed of the movement
@export var pan_amplitude_x: float = 60.0  # Max horizontal drift
@export var pan_amplitude_y: float = 30.0  # Max vertical drift

# Static Zoom Setting
@export var base_zoom: Vector2 = Vector2(1.05, 1.05) # Slightly zoomed in

var _time_accum: float = 0.0
var camera_base_position: Vector2

func _ready() -> void:
	Highscore.reset_score()
	if camera:
		# Establish the center resting point and apply the static zoom
		camera.global_position = get_viewport_rect().size / 2.0
		camera_base_position = camera.global_position
		camera.zoom = base_zoom
	Conductor.song_finished.connect(_on_song_finished) 
const HIGHSCORE_SCENE: String = "res://scenes/high_score.tscn"


func _on_song_finished() -> void:
	SceneTransition.fade_to_scene(HIGHSCORE_SCENE)

func _process(delta: float) -> void:
	_time_accum += delta

	if camera:
		_apply_organic_pan(delta)

func _apply_organic_pan(delta: float) -> void:
	var t := _time_accum * pan_speed
	
	# Layering sine waves at different, irregular frequencies (e.g., 1.73, 2.14).
	# This prevents the pattern from repeating too obviously and breaks the "circle".
	var sway_x := sin(t) * 0.65 + sin(t * 1.73 + 1.0) * 0.35
	var sway_y := cos(t * 0.85) * 0.65 + sin(t * 2.14 + 2.0) * 0.35
	
	var target_pos := camera_base_position + Vector2(sway_x * pan_amplitude_x, sway_y * pan_amplitude_y)
	
	# Apply the position smoothly
	camera.global_position = camera.global_position.lerp(target_pos, delta * 3.0)
