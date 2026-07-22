extends TextureRect  # Or TextureRect, depending on your UI node type

# This lets us set a unique action name for each drum pad clone in the inspector
@export var input_action: String = "upp_left"
@export var sound_name:String = "highhat"
@onready var sound: AudioStreamWAV = load("res://assets/music/"+sound_name+".wav")
#@onready var hit_effect: CPUParticles2D = $HitEffect
var o_scale:Vector2 = scale
@export var scale_factor:float = 0.1
func _unhandled_input(event: InputEvent) -> void:
	# Check if THIS specific pad's action was pressed
	if event.is_action_pressed(input_action):
		trigger_hit_effect()
		#$AudioStreamPlayer.stream = sound
		#$AudioStreamPlayer.play()
func trigger_hit_effect() -> void:
	# Visual flare: Restart particle burst
	#hit_effect.restart() 
	
	
	# Visual flare: Quick juice effect using a Tween (shrinks/grows the pad slightly)
	var tween = create_tween()
	tween.tween_property(self, "scale", o_scale+Vector2(scale_factor,scale_factor), 0.05) # Pop up
	tween.tween_property(self, "scale",o_scale, 0.1)  # Snaps back
	
