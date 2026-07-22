extends Node2D

@export var input_key: String = "ui_accept" 
@export var note_speed: float = 400.0 # How fast the beats fall (pixels per second)

@onready var receptor: Sprite2D = $drumpad
@onready var feedback_label: Label = $Feedback

var active_notes: Array[ColorRect] = []

func _ready() -> void:
	# Hide the feedback text when the game starts
	feedback_label.modulate.a = 0.0
	
	# For testing: Spawn a drum beat every 1 second!
	# In a real game, you would spawn these synced to your Conductor BPM.
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(spawn_beat)
	add_child(timer)

# ---------------------------------------------------------
# SPAWN & MOVE BEATS
# ---------------------------------------------------------
func spawn_beat() -> void:
	# Create a visual block for the falling drum beat
	var note = ColorRect.new()
	note.size = Vector2(50, 50)
	note.color = Color.MAGENTA
	
	# Center it on the lane, starting off-screen at the top
	note.position = Vector2(receptor.position.x + 7, receptor.position.y-300) 
	
	add_child(note)
	active_notes.append(note)

func _process(delta: float) -> void:
	# Move all active notes down the screen
	for i in range(active_notes.size() - 1, -1, -1):
		var note = active_notes[i]
		note.position.y += note_speed * delta
		
		# If the note falls way past the receptor without being hit
		if note.position.y > receptor.position.y + 80:
			show_feedback("MISS!", Color.RED)
			active_notes.remove_at(i)
			note.queue_free()

# ---------------------------------------------------------
# HIT DETECTION
# ---------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(input_key):
		receptor_flash()
		evaluate_hit()

func evaluate_hit() -> void:
	if active_notes.is_empty():
		return # You pressed the button, but there are no beats falling!
		
	# Look at the lowest note on the screen
	var target_note = active_notes[0]
	
	# Calculate the absolute pixel distance between the Note and the Receptor
	var distance = abs(target_note.position.y - receptor.position.y)
	
	# HIT WINDOWS (Adjust these pixel distances to make the game harder/easier)
	if distance <= 25.0:
		show_feedback("PERFECT!!", Color.CYAN)
		destroy_note(target_note)
	elif distance <= 65.0:
		show_feedback("GOOD", Color.GREEN)
		destroy_note(target_note)
	elif distance <= 110.0:
		show_feedback("NEAR", Color.YELLOW)
		destroy_note(target_note)
	# If you hit the button but the note was still too far away, it ignores the input.

func destroy_note(note: ColorRect) -> void:
	active_notes.erase(note)
	note.queue_free()

# ---------------------------------------------------------
# VISUAL POPUPS & EFFECTS
# ---------------------------------------------------------
func receptor_flash() -> void:
	# Makes the receptor physically bounce when you press the key
	var tween = create_tween()
	receptor.scale = Vector2(1.2, 1.2)
	tween.tween_property(receptor, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)

func show_feedback(text: String, color: Color) -> void:
	# Stop any currently playing text animation
	var active_tween = create_tween().set_parallel(true)
	
	feedback_label.text = text
	feedback_label.modulate = color
	feedback_label.modulate.a = 1.0 # Make it fully visible
	
	# Reset position and make it pop out huge
	var base_y = receptor.position.y - 60
	feedback_label.position.y = base_y
	feedback_label.scale = Vector2(1.5, 1.5)
	
	# Animate the text shrinking to normal size, floating up, and fading out!
	active_tween.tween_property(feedback_label, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	active_tween.tween_property(feedback_label, "position:y", base_y - 40, 0.5)\
		.set_ease(Tween.EASE_OUT)
		
	active_tween.tween_property(feedback_label, "modulate:a", 0.0, 0.3)\
		.set_delay(0.2)
