extends PathFollow2D

@export var speed: float = 300.0 
@export var squash_speed: float = 20.0 
@export var squash_amount: float = 0.2 

var is_walking: bool = false
var has_stopped_halfway: bool = false
var time_passed: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D 

# We will store your 0.1 scale here when the game starts
@onready var base_scale: Vector2 = sprite.scale 

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		is_walking = true
		
		if progress_ratio >= 1.0:
			progress = 0.0
			has_stopped_halfway = false

func _process(delta: float) -> void:
	if is_walking:
		progress += speed * delta
		time_passed += delta
		
		var wave = sin(time_passed * squash_speed) * squash_amount
		
		# Multiply the base scale (0.1) by the wobble factor
		sprite.scale.x = base_scale.x * (1.0 + wave)
		sprite.scale.y = base_scale.y * (1.0 - wave)
		
		if progress_ratio >= 0.5 and not has_stopped_halfway:
			is_walking = false
			progress_ratio = 0.5 
			has_stopped_halfway = true
			reset_scale()
			
		elif progress_ratio >= 1.0:
			is_walking = false
			progress_ratio = 1.0 
			reset_scale()

func reset_scale() -> void:
	# Snap back to 0.1 (or whatever base_scale captured) instead of 1.0
	sprite.scale = base_scale
