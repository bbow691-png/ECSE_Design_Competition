extends Sprite2D
@export var MAX_FRAM = 3
var c_frame = 0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	c_frame += 1
	if (c_frame > MAX_FRAM):
		c_frame = 0
