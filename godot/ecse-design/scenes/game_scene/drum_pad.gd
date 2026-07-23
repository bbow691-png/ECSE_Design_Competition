extends Sprite2D 

# --- DRUM PAD VARIABLES ---
@export var input_action: String = "upp_left"
@export var scale_factor: float = 0.1
@export var lane_index: int 

# --- RHYTHM VARIABLES ---
@export var note_speed: float = 200.0
@export var frame_num: int = 0
@onready var feedback_label: Label = $Feedback
#@onready var hit_effect: CPUParticles2D = $HitEffect
@onready var beat_placeholder: Sprite2D = $beat

var o_scale: Vector2
var active_notes: Array[Sprite2D] = []

func _ready() -> void:
	lane_index = int(name.substr(name.length() - 1, 1))
	
	frame = frame_num
	o_scale = scale
	
	# Hide feedback text on start
	feedback_label.modulate.a = 0.0
	
	# beat_placeholder is just the template — keep it hidden so only the
	# spawned clones are visible falling down the lane.
	beat_placeholder.visible = false
	
	Conductor.connect("note_spawned", Callable(self, "_on_song_manager_note_spawned"))

	Conductor.load_and_play_song("res://songs/test_song")
	
	# ---------------------------------------------------------
	# TEST SPAWNER: Spawns a beat every 1 second.
	# Replace this with your Conductor/Song logic later!
	# ---------------------------------------------------------
	#var timer = Timer.new()
	#timer.wait_time = 1.0
	#timer.autostart = true
	#timer.timeout.connect(spawn_beat)
	#add_child(timer)

# ---------------------------------------------------------
# SPAWN & MOVE BEATS
# ---------------------------------------------------------
func _on_song_manager_note_spawned(pad_index: int) -> void:
	# Only spawn a note if the JSON instruction matches this specific lane's index
	if pad_index == lane_index:
		spawn_beat()

func spawn_beat() -> void:
	var note = beat_placeholder.duplicate()
	note.visible = true
	
	# THE MAGIC TRICK: This stops the falling note from bouncing/scaling 
	# when the Sprite2D drum pad gets hit!
	note.set_as_top_level(true)
	
	# Center it on the pad, but start it 500 pixels higher up the screen
	note.global_position = global_position + Vector2(-20, -500) 
	note.z_index = 100 # Forces note in front of the drum pad
	note.frame = frame
	
	add_child(note)
	active_notes.append(note)

func _process(delta: float) -> void:
	# Move notes down using global coordinates
	for i in range(active_notes.size() - 1, -1, -1):
		var note = active_notes[i]
		note.global_position.y += note_speed * delta
		
		# If the note falls past the drum pad (missed)
		if note.global_position.y > global_position.y + 80:
			show_feedback("MISS!", Color.RED)
			active_notes.remove_at(i)
			note.queue_free()

# ---------------------------------------------------------
# INPUT & HIT DETECTION
# ---------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	# Check if THIS specific pad's action was pressed
	if event.is_action_pressed(input_action):
		trigger_hit_effect()
		evaluate_hit()
		
		#$AudioStreamPlayer.stream = sound
		#$AudioStreamPlayer.play()

func trigger_hit_effect() -> void:
	# Visual flare: Restart particle burst
	# hit_effect.restart() 
	
	# Visual flare: Quick juice effect using a Tween
	var tween = create_tween()
	tween.tween_property(self, "scale", o_scale + Vector2(scale_factor, scale_factor), 0.05)
	tween.tween_property(self, "scale", o_scale, 0.1) 

func evaluate_hit() -> void:
	if active_notes.is_empty():
		return # Pressed the pad, but no notes are falling
		
	# Check the lowest note falling towards this specific pad
	var target_note = active_notes[0]
	var distance = abs(target_note.global_position.y - global_position.y)
	
	# HIT WINDOWS
	if distance <= 25.0:
		show_feedback("PERFECT!!", Color.CYAN)
		destroy_note(target_note)
	elif distance <= 65.0:
		show_feedback("GOOD", Color.GREEN)
		destroy_note(target_note)
	elif distance <= 110.0:
		show_feedback("NEAR", Color.YELLOW)
		destroy_note(target_note)

func destroy_note(note) -> void:
	active_notes.erase(note)
	note.queue_free()

# ---------------------------------------------------------
# FEEDBACK ANIMATION
# ---------------------------------------------------------
func show_feedback(text: String, color: Color) -> void:
	var active_tween = create_tween().set_parallel(true)
	
	feedback_label.text = text
	feedback_label.modulate = color
	feedback_label.modulate.a = 1.0 
	
	# Start slightly above the pad
	var base_y = -60 
	feedback_label.position.y = base_y
	feedback_label.scale = Vector2(1.5, 1.5)
	
	# Pop in, float up, and fade out
	active_tween.tween_property(feedback_label, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	active_tween.tween_property(feedback_label, "position:y", base_y - 40, 0.5)\
		.set_ease(Tween.EASE_OUT)
		
	active_tween.tween_property(feedback_label, "modulate:a", 0.0, 0.3)\
		.set_delay(0.2)

func get_lane_index() -> int:
	# Gets drum index from last number in the name
	var last_char = name.substr(name.length() - 1, 1)
	return int(last_char)
