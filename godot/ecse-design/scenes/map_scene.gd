extends Control

@export var map_music: AudioStream
@export var bpm: int = 120
@export var fade_time: float = 5.0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:

	Conductor.play_with_fade(map_music,bpm,fade_time)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
