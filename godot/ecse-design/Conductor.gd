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

# --- Count-in buffer (lets song_position go negative before audio starts,
# so early notes still get their full spawn_lead_time to travel) ---
var is_buffering: bool = false
var pending_song_name: String = ""
var pending_bpm: float = 100.0
var pending_fade_time: float = 1.0

# --- Signals ---
signal beat_hit(beat: int)
signal step_hit(step: int)
signal note_spawned(lane_index: int, hit_time: float, boss: int)
# Fires once when the currently loaded song's audio stops on its own —
# i.e. active_player.playing goes true -> false while a song is still
# considered "in progress" (is_playing). Pausing for game-over uses
# stream_paused instead of stop(), so that case never flips .playing
# and can't be confused with a real end-of-song here.
signal song_finished

var _was_audio_playing: bool = false

# --- Dynamic Audio Players (crossfade system) ---
var active_player: AudioStreamPlayer
var fading_player: AudioStreamPlayer
var fade_tween: Tween

# --- Beatmap / Note Spawning ---
var current_beatmap: Dictionary = {}
var current_note_index: int = 0
var is_playing: bool = false
var spawn_lead_time: float = 4 # Seconds before hit time to spawn the note


func _ready() -> void:
	active_player = AudioStreamPlayer.new()
	fading_player = AudioStreamPlayer.new()
	menu_music_player = AudioStreamPlayer.new()
	add_child(active_player)
	add_child(fading_player)
	add_child(menu_music_player)
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

	current_beatmap = beatmap
	current_note_index = 0

	# Figure out how much lead-in we need so the earliest note still gets
	# its full spawn_lead_time to travel, instead of starting late/short.
	var notes: Array = current_beatmap.get("notes", current_beatmap.get("beats", []))
	var first_note_time: float = 0.0
	if notes.size() > 0 and notes[0].has("time"):
		first_note_time = notes[0]["time"]

	var needed_buffer: float = max(0.0, spawn_lead_time - first_note_time)

	map_bpm(song_bpm)

	if needed_buffer <= 0.0:
		# No buffer needed — behave exactly as before.
		_play_stream_with_fade(song_name, song_bpm, fade_time, true)
		is_playing = true
	else:
		# Start the count-in: notes can spawn, audio hasn't started yet.
		pending_song_name = song_name
		pending_bpm = song_bpm
		pending_fade_time = fade_time
		song_position = -needed_buffer
		song_beat = 0
		song_step = 0
		is_buffering = true
		is_playing = true

	print("Loaded song: ", current_beatmap.get("source_file", current_beatmap.get("title", song_name)))

func play_bgm(song_name: String, new_bpm: float = 100.0, fade_time: float = 1.0) -> void:
	_play_stream_with_fade(song_name, new_bpm, fade_time, false)
# --- Pause / Menu Music ---
@export var menu_music_song: String = "mainmenu"  # folder name under res://songs/
var is_menu_paused: bool = false
var menu_music_player: AudioStreamPlayer

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
	if is_buffering:
		_process_buffer_countdown(delta)
	else:
		_process_beat_tracking()
	_process_note_spawning()
	_process_song_end_detection()


func _process_buffer_countdown(delta: float) -> void:
	song_position += delta
	_update_steps_and_beats()

	if song_position >= 0.0:
		is_buffering = false
		_play_stream_with_fade(pending_song_name, pending_bpm, pending_fade_time, true)
		is_playing = true   # _play_stream_with_fade() resets this to false internally — restore it

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


func _process_song_end_detection() -> void:
	var currently_playing: bool = active_player.playing
	if is_playing and _was_audio_playing and not currently_playing:
		song_finished.emit()
	_was_audio_playing = currently_playing


# Called by Health.gd when health hits zero — halts note spawning and
# freezes the audio in place so the failed run doesn't keep playing
# under the paused tree.
func pause_song() -> void:
	is_playing = false
	if active_player:
		active_player.stream_paused = true

# Called by the Esc pause menu: freezes gameplay song + note spawning
# (same effect as pause_song) and additionally starts menu music, since
# this pause is player-initiated rather than a death/game-over pause.
func pause_for_menu() -> void:
	if is_menu_paused:
		return
	is_menu_paused = true
	is_playing = false

	if active_player and active_player.playing:
		active_player.stream_paused = true

	var menu_stream = _load_audio(menu_music_song)
	if menu_stream:
		menu_music_player.stream = menu_stream
		menu_music_player.volume_db = 0.0
		menu_music_player.play()
	else:
		print("Menu music not found for: ", menu_music_song)


# Reverses pause_for_menu(): stops menu music and unfreezes the game song
# from exactly where it left off.
func resume_from_menu() -> void:
	if not is_menu_paused:
		return
	is_menu_paused = false

	menu_music_player.stop()

	if active_player:
		active_player.stream_paused = false

	is_playing = true

func load_and_play_song(song_folder_path: String, fade_time: float = 1.0) -> void:
	var json_path = song_folder_path + "/beatmap.json"
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

	# --- Load the mp3 ---
	var mp3_path = song_folder_path + "/song1.mp3"
	if not FileAccess.file_exists(mp3_path):
		print("MP3 not found at: ", mp3_path)
		return

	var mp3_file = FileAccess.open(mp3_path, FileAccess.READ)
	var mp3_bytes = mp3_file.get_buffer(mp3_file.get_length())
	mp3_file.close()

	var stream = AudioStreamMP3.new()
	stream.data = mp3_bytes

	# Accept either key so this works whether the beatmap was exported with
	# "bpm" or "tempo_bpm" (the beat_mapper.py script writes "tempo_bpm").
	var song_bpm: float = beatmap.get("bpm", beatmap.get("tempo_bpm", bpm))

	# Route through the same crossfade system used by play_with_fade so only
	# one song is ever audibly playing at a time (aside from the brief
	# crossfade window).
	Conductor.play_with_fade(stream, song_bpm, fade_time, true)

	# Beatmap state is set up AFTER play_with_fade so it can't be wiped out
	# by play_with_fade's own reset-on-call-without-beatmap safety above.
	current_beatmap = beatmap
	current_note_index = 0
	is_playing = true

	print("Loaded song: ", current_beatmap.get("source_file", current_beatmap.get("title", "Unknown")))
