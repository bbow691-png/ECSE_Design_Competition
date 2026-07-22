extends PathFollow2D

@export var speed: float = 300.0 
@export var squash_speed: float = 20.0 
@export var squash_amount: float = 0.2 
@export var stops: Array[float] = [0.0, 0.4, 1.0] # The 3 set points on the path

var current_stop_index: int = 0
var is_walking: bool = false
var time_passed: float = 0.0
var target_progress: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D 
@onready var base_scale: Vector2 = sprite.scale 

func _input(event: InputEvent) -> void:
	# Prevent taking new inputs while the sprite is still moving
	if is_walking:
		return
		
	# Move Forward
	if event.is_action_pressed("ui_right") and current_stop_index < stops.size() - 1:
		current_stop_index += 1
		set_movement_target()
		
	# Move Backward
	elif event.is_action_pressed("ui_left") and current_stop_index > 0:
		current_stop_index -= 1
		set_movement_target()

func set_movement_target() -> void:
	is_walking = true
	time_passed = 0.0 # Reset animation timer so squash/stretch always starts clean
	
	# Calculate the exact pixel distance for our target ratio
	var path: Path2D = get_parent() as Path2D
	if path and path.curve:
		var path_length = path.curve.get_baked_length()
		target_progress = stops[current_stop_index] * path_length

func _process(delta: float) -> void:
	if is_walking:
		# move_toward safely handles moving both up and down, preventing overshooting
		progress = move_toward(progress, target_progress, speed * delta)
		time_passed += delta
		
		var wave = sin(time_passed * squash_speed) * squash_amount
		
		# Multiply the base scale by the wobble factor
		sprite.scale.x = base_scale.x * (1.0 + wave)
		sprite.scale.y = base_scale.y * (1.0 - wave)
		
		# Check if we reached the exact target distance
		if is_equal_approx(progress, target_progress):
			is_walking = false
			reset_scale()

func reset_scale() -> void:
	sprite.scale = base_scale
