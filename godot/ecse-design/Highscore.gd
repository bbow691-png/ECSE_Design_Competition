extends Node

var current_score: int = 0
var high_score: int = 0
signal score_change
func reset_score() -> void:
	current_score = 0
		
func add_score(points:int) -> void:
	current_score += points
	if current_score > high_score:
		high_score = current_score
	score_change.emit()
