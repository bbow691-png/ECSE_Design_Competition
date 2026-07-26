extends Node2D

@onready var background = $Background
@onready var foreground = $Foreground
@onready var end_screen = $UI/EndScreen
@onready var end_screen_delay: Timer = $EndScreenDelay
@onready var timer_label: Label = $UI/EndScreen/Timer 

# The target base scale for both layers
var base_scale: Vector2 = Vector2(1.0, 1.0)
# A modifier variable that tweens back to 0
var zoom_pulse: float = 0.0

var label_bounce_tween: Tween

func _ready() -> void:
	Score.reset_score()
	Conductor.song_finished.connect(_on_song_finished)
	end_screen_delay.timeout.connect(_on_end_screen_delay_timeout)
	Conductor.play_song("staffroll", 0.5)


func _process(_delta: float) -> void:
	# BACKGROUND: Multiplied by 0.3 (moves/zooms very subtly)
	background.scale = base_scale + Vector2(zoom_pulse * 0.01, zoom_pulse * 0.01)
	
	# FOREGROUND: Multiplied by 1.0 (gets the full energetic punch)
	foreground.scale = base_scale + Vector2(zoom_pulse * 0.04, zoom_pulse * 0.04)


func _on_song_finished() -> void:
	end_screen_delay.start()


func _on_end_screen_delay_timeout() -> void:
	var is_new_high: bool = Score.commit_highscore()
	end_screen.show_results(Score.score, Score.highscore, is_new_high)
	
	# Countdown from 15 down to 1 second
	for time_left in range(15, 0, -1):
		update_countdown(time_left)
		await get_tree().create_timer(1.0).timeout    
	
	# Transition back to the main menu
	SceneTransition.fade_to_scene("res://scenes/game_scene/walk_around.tscn")


func update_countdown(seconds_left: int) -> void:
	if not timer_label:
		return

	# Update text
	timer_label.text = "Returning in " + str(seconds_left) + "s..."
	
	# Set pivot to the center of the text so it pops from the center
	timer_label.pivot_offset = timer_label.size / 2.0

	# Cancel active bounce tween if it's still running
	if label_bounce_tween and label_bounce_tween.is_running():
		label_bounce_tween.kill()

	# Pop the label up to 1.25x scale instantly, then bounce back down
	timer_label.scale = Vector2(1.25, 1.25)
	
	label_bounce_tween = create_tween()
	label_bounce_tween.tween_property(timer_label, "scale", Vector2.ONE, 0.35)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
