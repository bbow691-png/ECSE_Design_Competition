extends Label

var displayed_score: int = 0
var score_tween: Tween

func _ready() -> void:
	# Connect to the Score signal
	if Score.has_signal("score_changed"):
		Score.score_changed.connect(_on_score_changed)
	else:
		push_warning("Score autoload is missing the 'score_changed' signal!")

	# Set starting value
	displayed_score = 0
	text = "Score: " + str(displayed_score)


func _on_score_changed(new_score: int) -> void:
	# Stop the previous tween if the score updates again mid-animation
	if score_tween and score_tween.is_running():
		score_tween.kill()

	score_tween = create_tween()
	
	# Smoothly interpolate the displayed number from current to new value over 0.4s
	score_tween.tween_method(
		_update_score_text,
		displayed_score,
		new_score,
		0.2
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	scale = Vector2(1.2, 1.2)
	score_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Update internal tracking variable
	displayed_score = new_score


# Helper function called on every step of the tween
func _update_score_text(value: int) -> void:
	text = "Score: " + str(value)
