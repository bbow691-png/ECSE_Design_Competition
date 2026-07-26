extends Node

# --------------------------------------------------------------------
# Score.gd (Autoload / Singleton)
# Tracks the current run's score from judged player notes, plus a
# persisted highscore saved to user:// so it survives between runs.
# --------------------------------------------------------------------

signal score_changed(new_score: int)

const SAVE_PATH: String = "user://highscore.save"

# Points per judgement tier, keyed on the same labels drum_pad.gd shows
# via show_feedback() (matches Health.gd's judgement keys).
const JUDGEMENT_POINTS: Dictionary = {
	"PERFECT!!": 100,
	"GOOD": 50,
	"NEAR": 20,
	"MISS!": 0,
}

var score: int = 0
var highscore: int = 0


func _ready() -> void:
	_load_highscore()


func reset_score() -> void:
	score = 0
	score_changed.emit(score)


func add_judgement(judgement: String) -> void:
	if not JUDGEMENT_POINTS.has(judgement):
		return
	score += JUDGEMENT_POINTS[judgement]
	score_changed.emit(score)


func _load_highscore() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		highscore = 0
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	highscore = file.get_32()
	file.close()


func add_score(add: int) -> void:
	score += add
	

# Call once the song is over. Returns true if this run set a new
# highscore (and persists it to disk immediately).
func commit_highscore() -> bool:
	if score <= highscore:
		return false
	highscore = score
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_32(highscore)
	file.close()
	return true
