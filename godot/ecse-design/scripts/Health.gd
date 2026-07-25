extends Node

# --------------------------------------------------------------------
# Health.gd (Autoload / Singleton)
# FNF-style health tracking: judged player notes push health up or
# down, and the run freezes once it hits zero.
# --------------------------------------------------------------------

signal health_changed(new_health: float)
signal game_over

const MAX_HEALTH: float = 100.0
const START_HEALTH: float = 50.0

# Point deltas per judgement tier, matched to the labels drum_pad.gd
# already shows via show_feedback() so there's one source of truth.
const JUDGEMENT_DELTAS: Dictionary = {
	"PERFECT!!": 5.0,
	"GOOD": 2.5,
	"NEAR": 1,
	"MISS!": -5.0,
}

var health: float = START_HEALTH
var is_game_over: bool = false


func reset_health() -> void:
	health = START_HEALTH
	is_game_over = false
	health_changed.emit(health)


func apply_judgement(judgement: String) -> void:
	if is_game_over:
		return
	if not JUDGEMENT_DELTAS.has(judgement):
		return
	_add(JUDGEMENT_DELTAS[judgement])


func _add(amount: float) -> void:
	health = clamp(health + amount, 0.0, MAX_HEALTH)
	health_changed.emit(health)
	if health <= 0.0:
		_trigger_game_over()


func _trigger_game_over() -> void:
	is_game_over = true
	print("Game over: health depleted")
	if Conductor and Conductor.has_method("pause_song"):
		Conductor.pause_song()
	get_tree().paused = true
	game_over.emit()
