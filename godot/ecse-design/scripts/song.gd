extends Node

signal beat_hit(current_beat: int)
signal bar_hit(current_bar: int)

@export var BPM: float = 120.0          # Set the exact BPM of your track
@export var beats_per_bar: int = 4      # Usually 4/4 time for rhythm games
@onready var song: AudioStreamPlayer  = $AudioStreamPlayer

var seconds_per_beat: float
var last_reported_beat: int = -1
func _ready() -> void:
	seconds_per_beat = 60.0/BPM
	song.play()

func _process(delta: float) -> void:
	if not song.playing:
		return
	var song_pos = song.get_playback_position()
	var exact_beat:float = song_pos/seconds_per_beat
	var current_beat: int = floor(exact_beat)
	
	if current_beat > last_reported_beat:
		beat_hit.emit(current_beat)
		if current_beat % beats_per_bar == 0:
			var current_bar: int = current_beat / beats_per_bar
			bar_hit.emit(current_bar)
