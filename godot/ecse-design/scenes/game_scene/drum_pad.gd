extends Sprite2D

# --- DRUM PAD VARIABLES ---
@export var input_action: String = "upp_left"
@export var scale_factor: float = 0.1
@export var lane_index: int

# --- RHYTHM VARIABLES ---
@export var spawn_distance: float = 500.0   # how far above the pad notes spawn (px)
@export var hit_window: float = 0.11        # seconds — outer edge of "NEAR" (matches old 110px tier)
@export var frame_num: int = 0
@onready var feedback_label: Label = $Feedback
@onready var beat_placeholder: Sprite2D = $beat
#@onready var hit_effect: CPUParticles2D = $HitEffect

var o_scale: Vector2
var active_notes: Array[Sprite2D] = []

func _ready() -> void:
	lane_index = int(name.substr(name.length() - 1, 1))

	frame = frame_num
	o_scale = scale

	# feedback_label is just the template — keep it hidden so only the
	# spawned clones are visible per hit.
	feedback_label.visible = false

	# beat_placeholder is just the template — keep it hidden so only the
	# spawned clones are visible falling down the lane.
	beat_placeholder.visible = false

	# note_spawned now carries the JSON hit time, not just the pad index,
	# so each note knows exactly when it needs to reach this pad.
	Conductor.note_spawned.connect(_on_song_manager_note_spawned)
	Conductor.load_and_play_song("res://songs/test_song/")

# ---------------------------------------------------------
# SPAWN & MOVE BEATS
# ---------------------------------------------------------
func _on_song_manager_note_spawned(pad_index: int, hit_time: float) -> void:
	# Only spawn a note if the JSON instruction matches this specific lane's index
	print("Pad ", lane_index, " got signal for pad ", pad_index)
	if pad_index == lane_index:
		spawn_beat(hit_time)

func spawn_beat(hit_time: float) -> void:
	var note = beat_placeholder.duplicate()
	note.visible = true

	# THE MAGIC TRICK: This stops the falling note from bouncing/scaling
	# when the Sprite2D drum pad gets hit!
	note.set_as_top_level(true)

	var start_pos: Vector2 = global_position + Vector2(-0, -spawn_distance)
	var target_pos: Vector2 = global_position + Vector2(-0, -18)

	note.global_position = start_pos
	note.z_index = 100 # Forces note in front of the drum pad
	note.frame_coords.x = frame_coords.x

	# Store the timing info the note needs to travel on the song's clock,
	# not on delta-time, so it lands exactly on hit_time regardless of
	# frame-rate hitches.
	note.set_meta("spawn_time", Conductor.get_song_position())
	note.set_meta("hit_time", hit_time)
	note.set_meta("start_y", start_pos.y)
	note.set_meta("target_y", target_pos.y)

	add_child(note)
	active_notes.append(note)

func _process(_delta: float) -> void:
	var song_time: float = Conductor.get_song_position()

	# Move notes using the audio clock instead of note_speed * delta.
	# progress = 0 at spawn, 1 exactly at hit_time -> the note is
	# guaranteed to be at the pad the instant the beat is due, synced
	# to the same clock the song is playing on.
	for i in range(active_notes.size() - 1, -1, -1):
		var note = active_notes[i]
		var spawn_time: float = note.get_meta("spawn_time")
		var hit_time: float = note.get_meta("hit_time")
		var start_y: float = note.get_meta("start_y")
		var target_y: float = note.get_meta("target_y")

		var duration: float = max(hit_time - spawn_time, 0.001)
		var progress: float = (song_time - spawn_time) / duration

		note.global_position.y = lerp(start_y, target_y, progress)

		# If the note is well past its hit_time and still un-hit, it's a miss.
		if song_time > hit_time + hit_window:
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

	# Check the note whose hit_time is soonest — judged against the song
	# clock, in seconds, rather than pixel distance. This ties hit
	# accuracy directly to the JSON timing instead of visual position,
	# so it stays correct even if note_speed or spawn_distance change.
	var target_note = active_notes[0]
	var hit_time: float = target_note.get_meta("hit_time")
	var song_time: float = Conductor.get_song_position()
	var time_diff: float = abs(song_time - hit_time)

	# HIT WINDOWS (seconds)
	if time_diff <= hit_window * 0.25:
		show_feedback("PERFECT!!", Color.CYAN)
		destroy_note(target_note)
	elif time_diff <= hit_window * 0.6:
		show_feedback("GOOD", Color.GREEN)
		destroy_note(target_note)
	elif time_diff <= hit_window:
		show_feedback("NEAR", Color.YELLOW)
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

	# Start slightly above the pad
	var base_y = -60
	label.position.y = base_y
	label.scale = Vector2(1.5, 1.5)

	add_child(label)

	var active_tween = create_tween().set_parallel(true)

	# Pop in, float up, and fade out
	active_tween.tween_property(label, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	active_tween.tween_property(label, "position:y", base_y - 40, 0.5)\
		.set_ease(Tween.EASE_OUT)

	active_tween.tween_property(label, "modulate:a", 0.0, 0.3)\
		.set_delay(0.2)

	# Clean up the clone once its animation finishes so labels don't pile up
	active_tween.chain().tween_callback(label.queue_free)

func get_lane_index() -> int:
	# Gets drum index from last number in the name
	var last_char = name.substr(name.length() - 1, 1)
	return int(last_char)
