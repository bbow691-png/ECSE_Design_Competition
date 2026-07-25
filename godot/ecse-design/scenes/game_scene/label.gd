extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Highscore.score_change.connect(punch_score_label)
	pass # Replace with function body.


func punch_score_label() -> void:
	self.text = str(Highscore.current_score)
	# Assuming 'score_label' is a reference to your Label node
	pivot_offset = size / 2.0 # Centers the scale origin
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.05)
	tween.tween_property(self, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT)
