extends Control

@export var map_music: AudioStream
@export var bpm: int = 120
@export var fade_time: float = 5.0

@onready var camera: Camera2D = $Camera2D
var camera_tween: Tween
# Called when the node enters the scene tree for the first time.
func _ready() -> void:

	Conductor.play_with_fade(map_music,bpm,fade_time)

func _on_conductor_beat_hit(current_beat: int) -> void:
	# Flash the background every beat!
	# (You can also change this to 'current_beat % 2 == 0' to flash only on every 2nd beat)
	bump_camera() 

func bump_camera() -> void:
	if not camera:
		return

	if camera_tween and camera_tween.is_running():
		camera_tween.kill()

	# Instantly zoom the camera slightly in (normal is Vector2(1, 1))
	camera.zoom = Vector2(1.03, 1.03)

	# Smoothly glide the zoom back to 1.0 over the course of the beat
	camera_tween = create_tween()
	camera_tween.tween_property(camera, "zoom", Vector2.ONE, 0.3)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
		
