extends Control
# Set to true if we want the drums to react to player inputs. Else, we act as if it a boss, etc
@export var input_enabled = false
# 0 or 1, depending on if you are boss or player respectively
@export var lane_num: int = 0
@onready var dp1 = $DrumPad1
@onready var dp2 = $DrumPad2
@onready var dp3 = $DrumPad3
@onready var dp4 = $DrumPad4
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if (input_enabled == true):
		dp1.input_enabled = true
		dp2.input_enabled = true
		dp3.input_enabled = true
		dp4.input_enabled = true
	if lane_num == 1:
		dp1.lane_num = 1
		dp2.lane_num = 1
		dp3.lane_num = 1
		dp4.lane_num = 1
		
