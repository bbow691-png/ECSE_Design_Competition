extends Sprite2D

# --- DRUM PAD VARIABLES ---
@export var input_action: String = "upp_left"
@export var scale_factor: float = 0.1
@export var lane_index: int

# --- RHYTHM VARIABLES ---
@export var spawn_distance: float = 500.0   # how far above the pad notes spawn (px)
@export var target_hit_offset: Vector2 = Vector2.ZERO # Visually align the target center

# Expanded hit windows (in seconds) for better game feel
@export var perfect_window: float = 0.06    
@export var good_window: float = 0.10       
@export var near_window: float = 0.15       
@export var miss_window: float = 0.40       # Massively expanded to catch early "tip" hits
@export var input_offset: float = 0.0       # Adjust if audio/visual lag occurs

@onready var feedback_label: Label = $Feedback
@onready var beat_placeholder: Sprite2D = $beat

# Make sure this starts true, or inputs will never fire!
var input_enabled = true
# 0 or 1, for boss and player
var lane_num = 0

var o_scale: Vector2
var active_notes: Array[Sprite2D] = []

@export var PERFECT_SCORE:int = 500
@export var GOOD_SCORE:int = 250
@export var NEAR_SCORE:int = 100

func _ready() -> void:
	lane_index = int(name.substr(name.length() - 1, 1))
	o_scale = scale

	feedback_label.visible = false
	beat_placeholder.visible = false

	Conductor.note_spawned.connect(_on_song_manager_note_spawned)
	
	Conductor.play_song("test_song")


# ---------------------------------------------------------
# SONG END LOGIC
# ---------------------------------------------------------



# ---------------------------------------------------------
# SPAWN & MOVE BEATS
# ---------------------------------------------------------
func _on_song_manager_note_spawned(pad_index: int, hit_time: float, boss: int) -> void:
	if pad_index == lane_index and boss == lane_num:
		spawn_beat(hit_time)

func spawn_beat(hit_time: float) -> void:
	var note = beat_placeholder.duplicate()
	note.visible = true
	note.set_as_top_level(true)

	var start_pos: Vector2 = global_position + Vector2(0, -spawn_distance)
	var target_pos: Vector2 = global_position + target_hit_offset

	note.global_position = start_pos
	note.z_index = 100 
	note.frame_coords.x = frame_coords.x

	note.set_meta("spawn_time", Conductor.get_song_position())
	note.set_meta("hit_time", hit_time)
	note.set_meta("start_y", start_pos.y)
	note.set_meta("target_y", target_pos.y)

	add_child(note)
	active_notes.append(note)

func _process(_delta: float) -> void:
	var song_time: float = Conductor.get_song_position()

	for i in range(active_notes.size() - 1, -1, -1):
		var note = active_notes[i]
		var spawn_time: float = note.get_meta("spawn_time")
		var hit_time: float = note.get_meta("hit_time")
		var start_y: float = note.get_meta("start_y")
		var target_y: float = note.get_meta("target_y")

		var duration: float = max(hit_time - spawn_time, 0.001)
		var progress: float = (song_time - spawn_time) / duration

		note.global_position.y = lerp(start_y, target_y, progress)

		# --- AUTOPLAY / BOT LOGIC ---
		if not input_enabled and song_time >= hit_time:
			trigger_hit_effect()
			show_feedback("PERFECT!!", Color.CYAN)
			active_notes.remove_at(i)
			note.queue_free()
			continue # Skip the miss check below since the note is gone

		# Drop the note if it completely passes the miss window (Player logic)
		if song_time > hit_time + miss_window:
			show_feedback("MISS!", Color.RED)
			# Only the interactive pad row should cost health — the
			# non-input boss/decoration row also "misses" every note it
			# never hits, and that's expected, not a player failure.
			if input_enabled:
				Health.apply_judgement("MISS!")
				Score.add_judgement("MISS!")
			active_notes.remove_at(i)
			note.queue_free()
			

# ---------------------------------------------------------
# INPUT & HIT DETECTION
# ---------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
		
	if event.is_action_pressed(input_action, false):
		trigger_hit_effect()
		evaluate_hit()

func trigger_hit_effect() -> void:
	# Removed the input_enabled check here so the bot can still bounce the pad visually!
	var tween = create_tween()
	tween.tween_property(self, "scale", o_scale + Vector2(scale_factor, scale_factor), 0.05)
	tween.tween_property(self, "scale", o_scale, 0.1)

func evaluate_hit() -> void:
	if active_notes.is_empty():
		return 

	var song_time: float = Conductor.get_song_position()
	
	var target_note = null
	var best_time_diff = 999.0
	
	# 1. Find the oldest note that is ACTUALLY inside our hit zone
	for note in active_notes:
		var hit_time: float = note.get_meta("hit_time")
		var time_diff: float = abs(song_time - (hit_time + input_offset))
		
		if time_diff <= miss_window:
			target_note = note
			best_time_diff = time_diff
			break # Found the closest valid note
			
	# 2. If the player pressed a button but the note is STILL way too far away
	if target_note == null:
		show_feedback("MISS!", Color.RED)
		return
		
	# 3. Evaluate the note based on the expanded windows
	if best_time_diff <= perfect_window:
		show_feedback("PERFECT!!", Color.CYAN)
		Score.add_score(PERFECT_SCORE)

	elif best_time_diff <= good_window:
		show_feedback("GOOD", Color.GREEN)
		Score.add_score(GOOD_SCORE)
	elif best_time_diff <= near_window:
		show_feedback("NEAR", Color.YELLOW)
		Score.add_score(NEAR_SCORE)
	else:
		# It's within the miss_window (0.4s) but outside the near_window
		show_feedback("MISS!", Color.RED)

	destroy_note(target_note)

func destroy_note(note) -> void:
	active_notes.erase(note)
	note.queue_free()

# ---------------------------------------------------------
# FEEDBACK ANIMATION
# ---------------------------------------------------------
func show_feedback(text: String, color: Color) -> void:
	var label: Label = feedback_label.duplicate()
	label.visible = true
	label.text = text
	label.modulate = color
	label.modulate.a = 1.0

	var base_y = -60
	label.position.y = base_y
	label.scale = Vector2(1.5, 1.5)

	add_child(label)

	var active_tween = create_tween().set_parallel(true)

	active_tween.tween_property(label, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	active_tween.tween_property(label, "position:y", base_y - 40, 0.5)\
		.set_ease(Tween.EASE_OUT)

	active_tween.tween_property(label, "modulate:a", 0.0, 0.3)\
		.set_delay(0.2)

	active_tween.chain().tween_callback(label.queue_free)
