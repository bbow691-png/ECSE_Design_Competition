extends Sprite2D

@onready var anim_player: AnimationPlayer = $AnimationPlayer
var combo_timer: Timer
func _unhandled_input(event: InputEvent) -> void:
	# Check if THIS specific pad's action was pressed
	if event.is_action_pressed("low_left") or event.is_action_pressed("low_righ") or event.is_action_pressed("upp_left") or event.is_action_pressed("upp_righ"):
		play_hit_sequence()

func _ready() -> void:
	# 1. Create a timer in code to handle our "return to idle" window
	combo_timer = Timer.new()
	combo_timer.wait_time = 0.5 # How long to wait after the last hit before resting
	combo_timer.one_shot = true
	combo_timer.timeout.connect(_on_combo_timeout)
	add_child(combo_timer)
	
	# 2. Globally speed up this AnimationPlayer so the whole sequence is incredibly fast
	# You can tweak this multiplier to perfectly fit that 0.5s window!
	anim_player.speed_scale = 2.5 
	
	anim_player.play("idle")

func play_hit_sequence() -> void:
	# 1. Reset the combo timer every single time a hit registers
	combo_timer.start()
	
	var current_anim = anim_player.current_animation
	
	# 2. If we are currently resting (or trying to), snap into action!
	if current_anim == "idle" or current_anim == "transition_back":
		anim_player.clear_queue()
		anim_player.play("transition")
		anim_player.queue("stuff")
		

func _on_combo_timeout() -> void:
	# 4. The player stopped pressing buttons. Time to go back to idle.
	anim_player.clear_queue()
	anim_player.play("transition_2") 
	anim_player.queue("idle")
