extends Node2D

@onready var background = $Background
@onready var foreground = $Foreground
# The target base scale for both layers
var base_scale: Vector2 = Vector2(1.0, 1.0)
# A modifier variable that tweens back to 0
var zoom_pulse: float = 0.0

func _ready() -> void:
	# Connect to your sound node's signal
	%Song.beat_hit.connect(_on_beat_hit)
	
	# Spawn beats
	

func _process(_delta: float) -> void:
	# BACKGROUND: Multiplied by 0.3 (moves/zooms very subtly)
	background.scale = base_scale + Vector2(zoom_pulse * 0.01, zoom_pulse * 0.01)
	
	# FOREGROUND: Multiplied by 1.0 (gets the full energetic punch)
	foreground.scale = base_scale + Vector2(zoom_pulse * 0.04, zoom_pulse * 0.04)

func _on_beat_hit(current_beat: int) -> void:
	# Only pulse on the prominent downbeats (every 2nd beat)
	if current_beat % 2 == 0:
		var tween = create_tween()
		
		# 1. Instantly set pulse intensity to maximum
		zoom_pulse = 1.0
		
		# 2. Smoothly decay the pulse back down to 0 before the next beat
		tween.tween_property(self, "zoom_pulse", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
