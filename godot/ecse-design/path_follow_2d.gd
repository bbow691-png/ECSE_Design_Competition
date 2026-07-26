extends PathFollow2D

@export var speed: float = 300.0 
@export var squash_speed: float = 20.0 
@export var squash_amount: float = 0.2 
@export var stops: Array[float] = [0.0, 0.4, 1.0] # The 3 set points on the path

# Map each stop index to its corresponding scene path and display name
var level_data: Array[Dictionary] = [
	{ "scene": "res://scenes/game_scene/scene_1.tscn", "name": "Frog battle" },
	{ "scene": "res://scenes/scene_2.tscn", "name": "Panda battle" },
	{ "scene": "res://scenes/scene_2.tscn", "name": "Panda battle" } # Fallback/3rd stop
]

var current_scene: String = ""
var current_stop_index: int = 0
var is_walking: bool = false
var time_passed: float = 0.0
var target_progress: float = 0.0

@onready var sprite: Sprite2D = $Player 
@onready var base_scale: Vector2 = sprite.scale 
@onready var level_label: Label = $Label # Make sure a Label node named "Label" exists under PathFollow2D!

func _ready() -> void:
	update_level_info()


func _input(event: InputEvent) -> void:
	# Prevent taking new inputs while the sprite is still moving
	if is_walking:
		return
		
	# Move Forward
	if event.is_action_pressed("upp_righ") and current_stop_index < stops.size() - 1:
		current_stop_index += 1
		set_movement_target()
		update_level_info()

	# Move Backward
	elif event.is_action_pressed("upp_left") and current_stop_index > 0:
		current_stop_index -= 1
		set_movement_target()
		update_level_info()

	# Select Level
	elif event.is_action_pressed("low_left") or event.is_action_pressed("low_righ"):
		_trigger_transition_to(current_scene)


func update_level_info() -> void:
	if current_stop_index < level_data.size():
		current_scene = level_data[current_stop_index]["scene"]
		if level_label:
			level_label.text = level_data[current_stop_index]["name"]


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


func _trigger_transition_to(target_scene: String) -> void:
	if target_scene == "":
		return
		
	# Call your global Autoload to handle the fade and scene swap
	SceneTransition.fade_to_scene(target_scene, 0.5)
