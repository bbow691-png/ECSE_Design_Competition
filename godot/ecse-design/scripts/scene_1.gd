extends Node2D

@onready var background = $Background
@onready var foreground = $Foreground
@onready var end_screen = $UI/EndScreen
@onready var end_screen_delay: Timer = $EndScreenDelay
# The target base scale for both layers
var base_scale: Vector2 = Vector2(1.0, 1.0)
# A modifier variable that tweens back to 0
var zoom_pulse: float = 0.0

@export var level_music:AudioStream 
@export var bpm:int = 128
@export var fade_time:float = 1.0
func _ready() -> void:
	# Connect to your sound node's signal
	Health.reset_health()
	Score.reset_score()
	Conductor.song_finished.connect(_on_song_finished)
	end_screen_delay.timeout.connect(_on_end_screen_delay_timeout)

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

func _on_beat_hit(current_beat: int) -> void:
	# Only pulse on the prominent downbeats (every 2nd beat)
	if current_beat % 2 == 0:
		var tween = create_tween()
		
		# 1. Instantly set pulse intensity to maximum
		zoom_pulse = 1.0
		
		# 2. Smoothly decay the pulse back down to 0 before the next beat
		tween.tween_property(self, "zoom_pulse", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
