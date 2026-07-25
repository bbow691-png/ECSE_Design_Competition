extends Sprite2D

# --- DRUM PAD VARIABLES ---
@export var input_action: String = "upp_left"
@export var scale_factor: float = 0.1
@export var lane_index: int

# Make sure this starts true, or inputs will never fire!
var input_enabled = true
# 0 or 1, for boss and player
var lane_num = 0

var o_scale: Vector2 = Vector2(.5,.5)
var active_notes: Array[Sprite2D] = []


# ---------------------------------------------------------
# INPUT & HIT DETECTION
# ---------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
		
	if event.is_action_pressed(input_action, false):
		trigger_hit_effect()

func trigger_hit_effect() -> void:
	# Removed the input_enabled check here so the bot can still bounce the pad visually!
	var tween = create_tween()
	tween.tween_property(self, "scale", o_scale + Vector2(scale_factor, scale_factor), 0.05)
	tween.tween_property(self, "scale", o_scale, 0.1)
