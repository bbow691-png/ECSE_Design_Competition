extends Control
# Set to true if we want the drums to react to player inputs. Else, we act as if it a boss, etc
@export var input_enabled = false
# 0 or 1, depending on if you are boss or player respectively
@export var lane_num: int = 0
@onready var dp1 = $upp_left
@onready var dp2 = $low_left
@onready var dp3 = $low_righ
@onready var dp4 = $upp_righ

@onready var pl_feedback = $Feedback
# --- DRUM PAD VARIABLES ---
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

# --- SCENE GATING ---
# Names of the scene(s) considered "the game scene" — note spawning, song
# playback, and scoring only happen when the current scene's name matches
# one of these. Compared against get_tree().current_scene.name.
@export var game_scene_names: Array[String] = ["Game"]

@onready var feedback_label: Label = $Feedback
@onready var beat_placeholder: Sprite2D = $beat

var active_notes: Array[Sprite2D] = []

# Per-pad original scales and a lookup by pad index, so each pad can be
# bounced independently instead of scaling the whole lane container.
var pad_original_scale: Dictionary = {}
var pads_by_index: Dictionary = {}

# Set once in _ready() by checking the current scene's name against
# game_scene_names. When false: no note spawning, no Conductor playback,
# no scoring — but real button presses still bounce the pad.
var is_in_game_scene: bool = false

@export var PERFECT_SCORE:int = 500
@export var GOOD_SCORE:int = 250
@export var NEAR_SCORE:int = 100

func _ready() -> void:
	pads_by_index = {
		1: dp1,
		2: dp2,
		3: dp3,
		4: dp4,
	}
	for idx in pads_by_index.keys():
		var pad = pads_by_index[idx]
		pad_original_scale[idx] = pad.scale

	feedback_label.visible = false
	beat_placeholder.visible = false

	var current_scene := get_tree().current_scene
	print(current_scene.name)
	is_in_game_scene = current_scene != null and game_scene_names.has(current_scene.name)

	if not is_in_game_scene:
		# Not in the game scene: skip note spawning/song playback entirely.
		# Pads still visually bounce on real input via _unhandled_input.
		return

	Conductor.note_spawned.connect(_on_song_manager_note_spawned)


func _on_song_manager_note_spawned(pad_index: int, hit_time: float, boss: int) -> void:
	if boss != lane_num:
		return
	if not pads_by_index.has(pad_index):
		return

	var drum: Sprite2D = pads_by_index[pad_index]
	spawn_beat(hit_time, drum, pad_index)

func spawn_beat(hit_time: float, drum: Sprite2D, pad_index: int) -> void:
	var note = drum.duplicate()
	note.visible = true
	note.set_as_top_level(true)

	# Use the specific pad's own position, not the lane container's,
	# so each pad's notes travel down its own column.
	var start_pos: Vector2 = drum.global_position + Vector2(0, -spawn_distance)
	var target_pos: Vector2 = drum.global_position + target_hit_offset

	note.global_position = start_pos
	note.z_index = 100
	note.frame_coords.x = pad_index - 1

	note.set_meta("spawn_time", Conductor.get_song_position())
	note.set_meta("hit_time", hit_time)
	note.set_meta("start_y", start_pos.y)
	note.set_meta("target_y", target_pos.y)
	note.set_meta("pad_index", pad_index)
	note.set_meta("hit", false)

	add_child(note)
	active_notes.append(note)

func _process(_delta: float) -> void:
	if not is_in_game_scene:
		return

	var song_time: float = Conductor.get_song_position()

	for i in range(active_notes.size() - 1, -1, -1):
		var note = active_notes[i]

		if not is_instance_valid(note):
			active_notes.remove_at(i)
			continue

		var spawn_time: float = note.get_meta("spawn_time")
		var hit_time: float = note.get_meta("hit_time")
		var start_y: float = note.get_meta("start_y")
		var target_y: float = note.get_meta("target_y")
		var pad_index: int = note.get_meta("pad_index")

		var duration: float = max(hit_time - spawn_time, 0.001)
		var progress: float = (song_time - spawn_time) / duration

		note.global_position.y = lerp(start_y, target_y, progress)

		# --- AUTOPLAY / BOT LOGIC ---
		if not input_enabled and song_time >= hit_time:
			trigger_hit_effect(pad_index)
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
				#Health.apply_judgement("MISS!")
				Score.add_judgement("MISS!")
			active_notes.remove_at(i)
			note.queue_free()


# ---------------------------------------------------------
# INPUT & HIT DETECTION
# ---------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return

	if event.is_action_pressed("upp_left", false):
		trigger_hit_effect(1)
		if is_in_game_scene:
			evaluate_hit(1)
	elif event.is_action_pressed("low_left", false):
		trigger_hit_effect(2)
		if is_in_game_scene:
			evaluate_hit(2)
	elif event.is_action_pressed("low_righ", false):
		trigger_hit_effect(3)
		if is_in_game_scene:
			evaluate_hit(3)
	elif event.is_action_pressed("upp_righ", false):
		trigger_hit_effect(4)
		if is_in_game_scene:
			evaluate_hit(4)

func trigger_hit_effect(pad_index: int) -> void:
	# Bounces only the pad sprite that was actually hit (dp1-dp4),
	# instead of scaling the whole lane container. Runs regardless of
	# scene — pads should visually respond to input everywhere.
	if not pads_by_index.has(pad_index):
		return

	var pad: Sprite2D = pads_by_index[pad_index]
	var base_scale: Vector2 = pad_original_scale[pad_index]

	var tween = create_tween()
	tween.tween_property(pad, "scale", base_scale + Vector2(scale_factor, scale_factor), 0.05)
	tween.tween_property(pad, "scale", base_scale, 0.1)

func evaluate_hit(pad_index: int) -> void:
	if active_notes.is_empty():
		return

	var song_time: float = Conductor.get_song_position()

	var target_note = null
	var best_time_diff = 999.0

	# 1. Find the oldest note in THIS lane that is ACTUALLY inside our hit zone
	for note in active_notes:
		if not is_instance_valid(note):
			continue
		if note.get_meta("hit", false):
			continue
		if note.get_meta("pad_index") != pad_index:
			continue

		var hit_time: float = note.get_meta("hit_time")
		var time_diff: float = abs(song_time - (hit_time + input_offset))

		if time_diff <= miss_window:
			target_note = note
			best_time_diff = time_diff
			break # Found the closest valid note in this lane

	# 2. If the player pressed a button but no note in this lane is close enough
	if target_note == null:
		show_feedback("MISS!", Color.RED)
		return

	# Mark immediately so it can't be matched again before it's freed
	target_note.set_meta("hit", true)

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
