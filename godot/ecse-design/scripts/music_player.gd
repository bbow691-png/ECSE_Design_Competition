extends AudioStreamPlayer
@onready var music_bus_idx = AudioServer.get_bus_index("Music")
@onready var eq_effect: AudioEffectEQ = AudioServer.get_bus_effect(music_bus_idx, 0)
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	play()	
	
func _unhandled_input(event: InputEvent) -> void:
	# Check if THIS specific pad's action was pressed
	#if event.is_action_pressed("upp_left"):
	trigger_bass_punch()

func trigger_bass_punch() -> void:
	# Create a tween to handle the smooth bass fade-out
	var tween = create_tween()
	
	# Band 0 (32Hz) and Band 1 (100Hz) represent the heavy bass/kick frequencies.
	# Godot EQ values range roughly from -60 (muted) to 24 (max boost).
	
	# 1. Instantly spike the bass bands up to +12dB on impact
	eq_effect.set_band_gain_db(0, 6.0)
	eq_effect.set_band_gain_db(1, 6.0)
	
	# 2. Smoothly ease the bass back down to baseline (0.0 dB) over 0.2 seconds
	# This keeps the rhythm tracking feeling punchy without ruining the mix!
	tween.tween_method(
		func(val: float): 
			eq_effect.set_band_gain_db(0, val)
			eq_effect.set_band_gain_db(1, val),
		12.0, # Start value
		0.0,  # End value
		0.2   # Duration in seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
