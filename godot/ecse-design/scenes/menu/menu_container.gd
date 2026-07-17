extends VBoxContainer

# --- Floating Settings ---
@export var float_speed: float = 3.0
@export var float_amplitude: float = 12.0
var time_passed: float = 0.0
var base_y_position: float = 0.0

# --- Beat Bounce Settings ---
@export var bounce_scale: Vector2 = Vector2(1.1, 1.1)
var active_tween: Tween

func _ready() -> void:
	# Store the starting Y position
	await get_tree().process_frame
	base_y_position = position.y
	
	# Center the scale pivot
	pivot_offset = size / 2.0
	
	# Connect to the global Conductor signal!
	Conductor.beat_hit.connect(_on_conductor_beat_hit)

func _process(delta: float) -> void:
	# Continuous float
	time_passed += delta
	var float_offset: float = sin(time_passed * float_speed) * float_amplitude
	position.y = base_y_position + float_offset

func _on_conductor_beat_hit(current_beat: int) -> void:
	bop_menu()

func bop_menu() -> void:
	if active_tween and active_tween.is_running():
		active_tween.kill()
		
	scale = bounce_scale
	
	active_tween = create_tween()
	# TRANS_SINE is a very clean, smooth curve
	active_tween.set_trans(Tween.TRANS_SINE) 
	# EASE_OUT makes the bounce start instantly fast, then smoothly ease to a stop
	active_tween.set_ease(Tween.EASE_OUT)
	active_tween.tween_property(self, "scale", Vector2.ONE, 0.25)
