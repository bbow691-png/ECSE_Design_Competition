extends Control

# Basic stand-in end-of-song screen. Call show_results() once the song
# is over (scene_1.gd does this ~1s after Conductor.song_finished) to
# populate the labels and reveal it.

@onready var score_label: Label = $Center/VBox/ScoreLabel
@onready var best_label: Label = $Center/VBox/BestLabel
@onready var new_high_label: Label = $Center/VBox/NewHighLabel


func _ready() -> void:
	visible = false


func show_results(final_score: int, best_score: int, is_new_high: bool) -> void:
	score_label.text = "Score: %d" % final_score
	best_label.text = "Best: %d" % best_score
	new_high_label.visible = is_new_high
	visible = true
