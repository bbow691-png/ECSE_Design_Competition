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
# Now carries the JSON hit_time along with the lane, so pads know
# exactly when their note is due instead of just which lane to use.
signal note_spawned(lane_index: int, hit_time: float)

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
	# Create two audio players inside the Conductor so they persist across scenes
	active_player = AudioStreamPlayer.new()
	fading_player = AudioStreamPlayer.new()
	add_child(active_player)
	add_child(fading_player)

	map_bpm(bpm)


func map_bpm(new_bpm: float) -> void:
	bpm = new_bpm
	crochet = 60.0 / bpm
	step_crochet = crochet / 4.0


# Public getter so other scripts (pads, UI, etc.) read the same clock
# that beat/step tracking and note spawning both use internally.
func get_song_position() -> float:
	return song_position


# CALL THIS from any scene's script to change music with a smooth fade!
# has_beatmap should be true only when the caller is about to follow up
# with load_and_play_song's beatmap setup; any other caller (e.g. plain
# background music for a menu) leaves note spawning switched off so a
# stale beatmap can't keep firing notes against the new track.
func play_with_fade(new_stream: AudioStream, new_bpm: float, fade_time: float = 1.0, has_beatmap: bool = false) -> void:
	# If a fade is already happening, stop it to prevent overlapping bugs
	if fade_tween and fade_tween.is_running():
		fade_tween.kill()

	# Stop note spawning until (if) the caller re-enables it below with a
	# freshly loaded beatmap. Prevents an old song's notes from spawning
	# against the new song's audio position.
	is_playing = false
	if not has_beatmap:
		current_beatmap = {}
		current_note_index = 0

	# 1. Swap the players (the current active player becomes the fading player)
	var old_player = active_player
	active_player = fading_player
	fading_player = old_player

	# 2. Setup and start the NEW song completely silent
	map_bpm(new_bpm)
	active_player.stream = new_stream
	active_player.volume_db = -80.0 # Silent
	active_player.play()

	# Reset beat counts and the shared clock — song_position is what both
	# beat tracking and note spawning read, so this is the single reset
	# point for "the song just (re)started."
	song_position = 0.0
	last_reported_playhead = 0.0
	song_beat = 0
	song_step = 0

	# If no fade time was given, swap instantly instead of tweening so there's
	# never a window where two players are audible at once.
	if fade_time <= 0.0:
		fading_player.stop()
		active_player.volume_db = 0.0
		return

	# 3. Animate the crossfade
	fade_tween = create_tween()
	fade_tween.set_parallel(true)

	# Fade out the old player and then stop it
	fade_tween.tween_property(fading_player, "volume_db", -80.0, fade_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)

	# Fade in the new player to full volume (0.0 dB)
	fade_tween.tween_property(active_player, "volume_db", 0.0, fade_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	# When done, shut down the fading player so it doesn't waste CPU
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

	# Uses song_position (the same latency-compensated audio clock used for
	# beat/step tracking) instead of a separate delta-accumulated timer, so
	# note scheduling can't drift out of sync with what the pads read.
	# Accepts either "notes" or "beats" as the array key, since exported
	# beatmaps have used both names.
	var notes: Array = current_beatmap.get("notes", current_beatmap.get("beats", []))

	while current_note_index < notes.size():
		var note = notes[current_note_index]
		if not (note.has("time") and note.has("pad")):
			# Skip malformed entries instead of crashing on missing keys.
			current_note_index += 1
			continue

		var target_time: float = note["time"]

		# Spawn early so it has time to fall down the screen to the hit line
		if song_position >= (target_time - spawn_lead_time):
			note_spawned.emit(note["pad"], target_time)
			current_note_index += 1
		else:
			break


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
	play_with_fade(stream, song_bpm, fade_time, true)

	# Beatmap state is set up AFTER play_with_fade so it can't be wiped out
	# by play_with_fade's own reset-on-call-without-beatmap safety above.
	current_beatmap = beatmap
	current_note_index = 0
	is_playing = true

	print("Loaded song: ", current_beatmap.get("source_file", current_beatmap.get("title", "Unknown")))
