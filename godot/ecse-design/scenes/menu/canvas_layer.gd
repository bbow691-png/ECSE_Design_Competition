extends CanvasLayer

@onready var play: Button = $Play
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	play.button_pressed(_on_button_clicked.bind(0))

func _on_button_clicked(lane_index: int) -> void:
	print("apple")
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
