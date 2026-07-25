extends Node

# --------------------------------------------------------------------
# Conductor.gd (Autoload / Singleton)
# Combines rhythm/timing logic (Conductor) with beatmap/note-spawning
# logic (SongManager).
# --------------------------------------------------------------------

# --- Song Settings ---
var bpm: float = 100.0
var crochet: float = 0.0
var step_crochet: float = 0.0

# --- Time Tracking ---
var song_position: float = 0.0
var last_reported_playhead: float = 0.0
var song_beat: int = 0
var song_step: int = 0

# --- Signals ---
signal beat_hit(beat: int)
signal step_hit(step: int)
signal note_spawned(lane_index: int, hit_time: float, boss: int)
signal song_finished

# --- Dynamic Audio Players (crossfade system) ---
var active_player: AudioStreamPlayer
var fading_player: AudioStreamPlayer
var fade_tween: Tween

# --- Beatmap / Note Spawning ---
var current_beatmap: Dictionary = {}
var current_note_index: int = 0
var is_playing: bool = false
var spawn_lead_time: float = 2.5 # Seconds before hit time to spawn the note


func _ready() -> void:
	active_player = AudioStreamPlayer.new()
	fading_player = AudioStreamPlayer.new()
	add_child(active_player)
	add_child(fading_player)
	active_player.finished.connect(func(): 
			if is_playing: 
				is_playing = false
				song_finished.emit()
	)
	map_bpm(bpm)
	


func map_bpm(new_bpm: float) -> void:
	bpm = new_bpm
	crochet = 60.0 / bpm
	step_crochet = crochet / 4.0


func get_song_position() -> float:
	return song_position


# --------------------------------------------------------------------
# PUBLIC PLAYBACK API
# --------------------------------------------------------------------

func play_song(song_name: String, fade_time: float = 1.0) -> void:
	var folder_path = "res://songs/" + song_name
	var json_path = folder_path + "/beatmap.json"
	
	if not FileAccess.file_exists(json_path):
		print("Beatmap not found at: ", json_path)
		return

	var file = FileAccess.open(json_path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		print("JSON Parse Error: ", json.get_error_message())
		return

	var beatmap: Dictionary = json.get_data()
	var song_bpm: float = beatmap.get("bpm", beatmap.get("tempo_bpm", bpm))

	# Just pass the string now!
	_play_stream_with_fade(song_name, song_bpm, fade_time, true)

	current_beatmap = beatmap
	current_note_index = 0
	is_playing = true

	print("Loaded song: ", current_beatmap.get("source_file", current_beatmap.get("title", song_name)))


func play_bgm(song_name: String, new_bpm: float = 100.0, fade_time: float = 1.0) -> void:
	_play_stream_with_fade(song_name, new_bpm, fade_time, false)


# --------------------------------------------------------------------
# INTERNAL AUDIO LOGIC
# --------------------------------------------------------------------

# Helper function to dynamically load OGG or MP3 based on the song name
func _load_audio(song_name: String) -> AudioStream:
	var base_path = "res://songs/" + song_name + "/" + song_name
	var ogg_path = base_path + ".ogg"
	var mp3_path = base_path + ".mp3"
	
	# 1. Try finding and loading an OGG file first
	if FileAccess.file_exists(ogg_path) or FileAccess.file_exists(ogg_path + ".import"):
		if ResourceLoader.exists(ogg_path):
			return load(ogg_path) as AudioStream
		else:
			# Fallback if Godot hasn't imported it properly yet
			return AudioStreamOggVorbis.load_from_file(ogg_path)

	# 2. Try finding and loading an MP3 file
	if FileAccess.file_exists(mp3_path) or FileAccess.file_exists(mp3_path + ".import"):
		if ResourceLoader.exists(mp3_path):
			return load(mp3_path) as AudioStream
		else:
			# Fallback to manual byte reading if Godot's importer rejected it
			var mp3_file = FileAccess.open(mp3_path, FileAccess.READ)
			var mp3_bytes = mp3_file.get_buffer(mp3_file.get_length())
			mp3_file.close()

			var stream = AudioStreamMP3.new()
			stream.data = mp3_bytes
			return stream

	print("Audio file (neither .ogg nor .mp3) found for: ", song_name)
	return null


func _play_stream_with_fade(song_name: String, new_bpm: float, fade_time: float = 1.0, has_beatmap: bool = false) -> void:
	var new_stream = _load_audio(song_name)
	if not new_stream:
		return

	if fade_tween and fade_tween.is_running():
		fade_tween.kill()

	is_playing = false
	if not has_beatmap:
		current_beatmap = {}
		current_note_index = 0

	var old_player = active_player
	active_player = fading_player
	fading_player = old_player

	map_bpm(new_bpm)
	active_player.stream = new_stream
	active_player.volume_db = -80.0
	active_player.play()

	song_position = 0.0
	last_reported_playhead = 0.0
	song_beat = 0
	song_step = 0

	if fade_time <= 0.0:
		fading_player.stop()
		active_player.volume_db = 0.0
		return

	fade_tween = create_tween()
	fade_tween.set_parallel(true)

	fade_tween.tween_property(fading_player, "volume_db", -80.0, fade_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)

	fade_tween.tween_property(active_player, "volume_db", 0.0, fade_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	fade_tween.chain().tween_callback(fading_player.stop)


func _process(delta: float) -> void:
	_process_beat_tracking()
	_process_note_spawning()


func _process_beat_tracking() -> void:
	if not active_player.playing:
		return

	var raw_pos: float = active_player.get_playback_position()

	if raw_pos != last_reported_playhead:
		last_reported_playhead = raw_pos
		song_position = raw_pos
	else:
		song_position = raw_pos + AudioServer.get_time_since_last_mix()

	song_position -= AudioServer.get_output_latency()
	_update_steps_and_beats()


func _update_steps_and_beats() -> void:
	var current_step: int = floor(song_position / step_crochet)
	var current_beat: int = floor(song_position / crochet)

	if current_step > song_step:
		song_step = current_step
		step_hit.emit(song_step)

	if current_beat > song_beat:
		song_beat = current_beat
		beat_hit.emit(song_beat)


func _process_note_spawning() -> void:
	if not is_playing:
		return

	var notes: Array = current_beatmap.get("notes", current_beatmap.get("beats", []))

	while current_note_index < notes.size():
		var note = notes[current_note_index]
		if not (note.has("time") and note.has("pad")):
			current_note_index += 1
			continue

		var target_time: float = note["time"]

		if song_position >= (target_time - spawn_lead_time):
			var boss: int = int(note.get("boss", 0))
			note_spawned.emit(note["pad"], target_time, boss)
			current_note_index += 1
		else:
			break
