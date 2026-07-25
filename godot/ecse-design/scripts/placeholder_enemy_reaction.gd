extends Sprite2D

# --------------------------------------------------------------------
# Generic placeholder reaction for an enemy that only has a single
# static image (no spritesheet/AnimationPlayer yet). Pulses and
# flashes in time with its own boss-lane notes so there's something
# on screen immediately. Swap this script out for a frog_char.gd-style
# AnimationPlayer state machine once real animated art exists for the
# character — the Conductor.note_spawned wiring is the same either way.
# --------------------------------------------------------------------

@export var pulse_scale: float = 1.15
@export var pulse_time: float = 0.12
@export var flash_color: Color = Color(1.4, 1.4, 1.4)

var base_scale: Vector2
var base_modulate: Color
var boss_hit_queue: Array[float] = []


func _ready() -> void:
	base_scale = scale
	base_modulate = modulate
	Conductor.note_spawned.connect(_on_song_manager_note_spawned)


func _on_song_manager_note_spawned(_pad_index: int, hit_time: float, boss: int) -> void:
	if boss == 0:
		boss_hit_queue.append(hit_time)


func _process(_delta: float) -> void:
	while boss_hit_queue.size() > 0 and Conductor.get_song_position() >= boss_hit_queue[0]:
		boss_hit_queue.pop_front()
		_react()


func _react() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	scale = base_scale * pulse_scale
	modulate = flash_color
	tween.tween_property(self, "scale", base_scale, pulse_time)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", base_modulate, pulse_time)
