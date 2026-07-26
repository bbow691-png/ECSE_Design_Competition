extends Node2D

@onready var background = $Background
@onready var foreground = $Foreground
@onready var end_screen = $UI/EndScreen
@onready var end_screen_delay: Timer = $EndScreenDelay
# The target base scale for both layers
var base_scale: Vector2 = Vector2(1.0, 1.0)
# A modifier variable that tweens back to 0
var zoom_pulse: float = 0.0

func _ready() -> void:
	# Connect to your sound node's signal
	Health.reset_health()
	Score.reset_score()
	Conductor.song_finished.connect(_on_song_finished)
	end_screen_delay.timeout.connect(_on_end_screen_delay_timeout)
	Conductor.play_song("terraria",.5)

	#Conductor.play_with_fade(level_music,bpm,fade_time)
	pass

func _on_song_finished() -> void:
	end_screen_delay.start()

func _on_end_screen_delay_timeout() -> void:
	var is_new_high: bool = Score.commit_highscore()
	end_screen.show_results(Score.score, Score.highscore, is_new_high)
	
	
func _process(_delta: float) -> void:
	# BACKGROUND: Multiplied by 0.3 (moves/zooms very subtly)
	background.scale = base_scale + Vector2(zoom_pulse * 0.01, zoom_pulse * 0.01)
	
	# FOREGROUND: Multiplied by 1.0 (gets the full energetic punch)
	foreground.scale = base_scale + Vector2(zoom_pulse * 0.04, zoom_pulse * 0.04)

#func _apply_organic_pan(delta: float) -> void:
	#var t := _time_accum * pan_speed
	#
	## Layering sine waves at different, irregular frequencies (e.g., 1.73, 2.14).
	## This prevents the pattern from repeating too obviously and breaks the "circle".
	#var sway_x := sin(t) * 0.65 + sin(t * 1.73 + 1.0) * 0.35
	#var sway_y := cos(t * 0.85) * 0.65 + sin(t * 2.14 + 2.0) * 0.35
	#
	#var target_pos := camera_base_position + Vector2(sway_x * pan_amplitude_x, sway_y * pan_amplitude_y)
	#
	## Apply the position smoothly
	#camera.global_position = camera.global_position.lerp(target_pos, delta * 3.0)
