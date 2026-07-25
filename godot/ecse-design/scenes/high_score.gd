extends Node2D

@onready var score_label = $PanelContainer/VBoxContainer/ScoreLabel

var current_displayed_score: int = 0

func _ready():
	# Make sure we start at zero visually
	score_label.text = "0"
	Conductor.play_song("mainmenu")
	
	# Wait half a second before starting the animation so the player can process the screen
	await get_tree().create_timer(0.5).timeout
	animate_score()

func animate_score():
	var tween = create_tween()
	
	# Tween properties:
	# 1. The method to call (update_score_text)
	# 2. Start value (0)
	# 3. End value (target_score)
	# 4. Duration in seconds (2.0)
	tween.tween_method(update_score_text, 0, Highscore.current_score, 2.0) \
		.set_trans(Tween.TRANS_QUART) \
		.set_ease(Tween.EASE_OUT)

# This function is called every frame by the tween with a new interpolated value
func update_score_text(value: int):
	current_displayed_score = value
	score_label.text = str(current_displayed_score)
